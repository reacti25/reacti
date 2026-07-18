<?php

namespace App\Services;

use App\Events\GroupMessageReadEvent;
use App\Events\GroupMessageSendEvent;
use App\Events\GroupMessageViewedEvent;
use App\Helpers\Helper;
use App\Http\Controllers\Api\Chat\Group\GroupMessageController;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\GroupMessageDeletion;
use App\Models\GroupMessageRead;
use App\Models\GroupMessageUserStatus;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Business logic for group chat messaging.
 *
 * Extracted from {@see GroupMessageController}
 * so the controller only validates input, applies soft-failure guard
 * clauses (group missing, not a member, not an admin), and shapes the
 * JSON response. This service is central to the patent flow for groups:
 * {@see GroupMessageService::sendMessage()} stores group media with
 * per-recipient `is_blurred=true` rows in `group_message_user_status`,
 * and {@see GroupMessageService::markAsViewed()} performs the per-user
 * `mark-viewed` unblur. All DB writes, the `GroupMessageSendEvent`
 * broadcast, and the Firebase notification fan-out are reproduced
 * verbatim from the pre-refactor controller — no behaviour change.
 */
class GroupMessageService
{
    /** Minutes after sending during which the sender may still edit a message. */
    private const EDIT_WINDOW_MINUTES = 10;

    /**
     * @param  PushNotificationService  $pushNotificationService  Device push fan-out.
     */
    public function __construct(
        private readonly PushNotificationService $pushNotificationService,
        private readonly ChatService $chatService
    ) {}

    /**
     * Send a message to a group.
     *
     * A `normal` message carrying media is blurred for recipients but not
     * for the sender — so a `group_message_user_status` row is bulk
     * inserted for every member up front (`is_blurred=false` for the
     * sender, `true` for others), making each member's blur/unblur
     * independent. The message is broadcast via `GroupMessageSendEvent`
     * and a Firebase push is fanned out to every member except the sender
     * (best-effort).
     *
     * The caller is responsible for confirming the group exists and that
     * the auth user is a member before invoking this method.
     *
     * @param  Request  $request  The incoming request (text, file, message_type, reply_to_message_id).
     * @param  int  $group_id  The target group.
     * @param  Group  $group  The resolved target group.
     * @param  User  $authUser  The authenticated sender.
     * @return GroupMessage The created message with relations eager-loaded.
     */
    public function sendMessage(Request $request, $group_id, Group $group, User $authUser): GroupMessage
    {
        // FILE UPLOAD
        $file = null;
        if ($request->hasFile('file')) {
            $file = Helper::fileUpload(
                $request->file('file'),
                'group_message',
                time().'group_chat_image'.$request->file('file')
            );
        }

        // DETERMINE MESSAGE TYPE & BLUR FLAG
        $messageType = $request->input('message_type', 'normal');

        // Only normal + media messages are blurred for recipients
        $isBlurredForRecipients = ($messageType === 'normal' && $file !== null);

        // View-once applies only to normal media sends, same gate as blur.
        $oneTime = $isBlurredForRecipients && $request->boolean('one_time');

        // SAVE MESSAGE
        $message = GroupMessage::create([
            'group_id' => $group_id,
            'sender_id' => $authUser->id,
            'text' => $request->text,
            'file' => $file,
            'status' => 'sent',
            'message_type' => $messageType,
            'one_time' => $oneTime,
            'reply_to_message_id' => $request->reply_to_message_id,
        ]);

        // -------------------------------------------------------
        // FIX #1 + FIX #2:
        // Message send হওয়ার সাথে সাথেই সব member-এর status create করো।
        // Sender: is_blurred = false (সে নিজের message দেখতে পাবে)
        // Others: is_blurred = true যদি normal+media হয়, নাহলে false
        // -------------------------------------------------------
        $memberIds = $group->members()->pluck('user_id');
        $now = now();

        $statusRows = $memberIds->map(function ($memberId) use ($message, $authUser, $isBlurredForRecipients, $now) {
            $isSender = ($memberId == $authUser->id);

            return [
                'message_id' => $message->id,
                'user_id' => $memberId,
                'is_viewed' => false,
                'is_blurred' => $isSender ? false : $isBlurredForRecipients,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        })->toArray();

        GroupMessageUserStatus::insert($statusRows); // Bulk insert — একটাই query

        // PRE-LOAD RELATIONS
        $message->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'group:id,name,avatar',
            'replyTo.sender:id,first_name,last_name,avatar',
            'replyTo.messageStatus' => fn ($q) => $q->where('user_id', $authUser->id),
            'messageStatus' => fn ($q) => $q->where('user_id', $authUser->id),
        ]);

        // BROADCAST TO GROUP MEMBERS
        // The message is already persisted above, so a realtime fan-out failure
        // (Pusher down/misconfigured, transport error) must NOT fail the send:
        // an uncaught throw here 500s the request, and the sender's client then
        // drops its optimistic bubble — the message vanishes for the sender even
        // though it was saved and others may have received it. Log and move on.
        try {
            broadcast(new GroupMessageSendEvent($message))->toOthers();
        } catch (\Throwable $e) {
            Log::error('GroupMessageSendEvent broadcast failed', [
                'message_id' => $message->id,
                'group_id' => $group_id,
                'error' => $e->getMessage(),
            ]);
        }

        // FIREBASE NOTIFICATION (all members except sender), best-effort.
        $messagePreview = '';

        if ($file) {
            $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
            $imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
            $videoExtensions = ['mp4', 'mov', 'avi', 'mkv'];

            if (in_array($ext, $imageExtensions)) {
                $messagePreview = '📷 Photo';
            } elseif (in_array($ext, $videoExtensions)) {
                $messagePreview = '🎥 Video';
            } else {
                $messagePreview = '📎 File';
            }
        } else {
            $messagePreview = Str::limit($request->text ?? '', 50);
        }

        $this->pushToGroupMembers($group, $authUser, $messagePreview);

        return $message;
    }

    /**
     * Fan out a Firebase push to every group member except the sender.
     *
     * Shared by {@see sendMessage()} and {@see forwardToGroup()} so the member
     * loop and its per-member token lookup live in one place. Best-effort:
     * members without a device token are skipped, and the group deep-link
     * routes tapers to the group inbox.
     *
     * @param  Group  $group  The group whose members to notify.
     * @param  User  $authUser  The sender to exclude and attribute the push to.
     * @param  string  $preview  The already-formatted notification body.
     */
    private function pushToGroupMembers(Group $group, User $authUser, string $preview): void
    {
        $senderName = $authUser->first_name.' '.$authUser->last_name;

        $groupMembers = $group->members()
            ->where('user_id', '!=', $authUser->id)
            ->with('user.firebaseTokens')
            ->get();

        foreach ($groupMembers as $member) {
            if (! $member->user || $member->user->firebaseTokens->isEmpty()) {
                continue;
            }

            $notifyData = [
                'title' => $group->name.' • '.$senderName,
                'body' => $preview,
                'icon' => $authUser->avatar ?? config('settings.logo'),
                // Deep-link routing (all strings, per FCM). On tap the member
                // opens this group; GroupInboxScreen keys on the group id.
                'data' => [
                    'type' => 'chat_group',
                    'roomId' => (string) $group->id,
                    'name' => (string) $group->name,
                    'groupImage' => (string) ($group->avatar ?? ''),
                ],
            ];

            $badge = $this->chatService->unseenConversationCountForUser($member->user->id);
            $this->pushNotificationService->sendToUser($member->user, $notifyData, $badge);
        }
    }

    /**
     * Forward a message's text/media into [$group].
     *
     * Mirrors {@see sendMessage()} but reuses the original message's stored file
     * path (no re-upload) and stamps `forwarded_from` with the original author.
     * Forwarded media stays sealed per-recipient (patent flow); the message is
     * always stored as `normal`. Broadcasts and pushes like a normal send. The
     * caller must confirm the forwarder is a group member first.
     *
     * @param  Group  $group  The destination group.
     * @param  User  $authUser  The user doing the forwarding.
     * @param  string|null  $text  The original message text.
     * @param  string|null  $file  The original stored file path (or null).
     * @param  int|null  $forwardedFrom  The original author's id.
     * @return GroupMessage The created forwarded message.
     */
    public function forwardToGroup(Group $group, User $authUser, ?string $text, ?string $file, ?int $forwardedFrom): GroupMessage
    {
        // Forwarded normal media stays sealed for recipients (patent flow).
        $isBlurredForRecipients = $file !== null;

        $message = GroupMessage::create([
            'group_id' => $group->id,
            'sender_id' => $authUser->id,
            'forwarded_from' => $forwardedFrom,
            'text' => $text,
            'file' => $file,
            'status' => 'sent',
            'message_type' => 'normal',
        ]);

        // Per-member blur/view status rows (the forwarder sees it unblurred).
        $memberIds = $group->members()->pluck('user_id');
        $now = now();
        $statusRows = $memberIds->map(function ($memberId) use ($message, $authUser, $isBlurredForRecipients, $now) {
            $isSender = ($memberId == $authUser->id);

            return [
                'message_id' => $message->id,
                'user_id' => $memberId,
                'is_viewed' => false,
                'is_blurred' => $isSender ? false : $isBlurredForRecipients,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        })->toArray();
        GroupMessageUserStatus::insert($statusRows);

        $message->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'group:id,name,avatar',
            'messageStatus' => fn ($q) => $q->where('user_id', $authUser->id),
        ]);

        try {
            broadcast(new GroupMessageSendEvent($message))->toOthers();
        } catch (\Throwable $e) {
            Log::error('GroupMessageSendEvent (forward) broadcast failed', [
                'message_id' => $message->id,
                'group_id' => $group->id,
                'error' => $e->getMessage(),
            ]);
        }

        // Best-effort push to members except the forwarder.
        $preview = $file ? '📎 Forwarded media' : Str::limit($text ?? '', 50);
        $this->pushToGroupMembers($group, $authUser, $preview);

        return $message;
    }

    /**
     * Edit the text of a group message.
     *
     * Only the original sender may edit, and only their own message in
     * that group — any other caller gets a `null` result so the
     * controller can respond with a 404 envelope. The caller is
     * responsible for confirming the group exists and that the auth user
     * is a member before invoking this method.
     *
     * Only the sender may edit, only within {@see self::EDIT_WINDOW_MINUTES}
     * minutes of sending, and reaction clips (no editable body) are refused.
     * On success the text is replaced and `edited_at` is stamped.
     *
     * @param  Request  $request  The incoming request (text).
     * @param  int  $group_id  The group.
     * @param  int  $message_id  The message to edit.
     * @param  User  $authUser  The authenticated user.
     * @return GroupMessage|string The updated message, or a failure reason:
     *                             `'not_found'` (missing / not sender / reaction)
     *                             or `'expired'` (past the edit window).
     */
    public function editMessage(Request $request, $group_id, $message_id, User $authUser): GroupMessage|string
    {
        $message = GroupMessage::where('id', $message_id)
            ->where('group_id', $group_id)
            ->where('sender_id', $authUser->id)
            ->first();

        // Missing, not the sender's, or a reaction clip (no editable text).
        if (! $message || $message->message_type === 'reaction') {
            return 'not_found';
        }

        if ($message->created_at->lt(now()->subMinutes(self::EDIT_WINDOW_MINUTES))) {
            return 'expired';
        }

        $message->text = $request->text;
        $message->edited_at = now();
        $message->save();

        $message->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'group:id,name,avatar',
        ]);

        return $message;
    }

    /**
     * Hide a group message for the auth user only ("delete for me").
     *
     * Records a per-user deletion so the message is excluded from this user's
     * group fetches on every device, while it stays for everyone else. The
     * caller must be a member of the message's group. This is the group
     * counterpart of {@see ChatService::deleteForMe()}; group "delete for
     * everyone" is a separate, admin-only path.
     *
     * @param  int  $message_id  The group message to hide.
     * @param  User  $authUser  The authenticated user.
     * @return bool True when the message existed and was hidden.
     */
    public function deleteForMe(int $message_id, User $authUser): bool
    {
        $message = GroupMessage::find($message_id);
        if (! $message) {
            return false;
        }

        $group = Group::find($message->group_id);
        if (! $group || ! $group->isMember($authUser->id)) {
            return false;
        }

        GroupMessageDeletion::firstOrCreate([
            'message_id' => $message->id,
            'user_id' => $authUser->id,
        ]);

        return true;
    }

    /**
     * Get a group's messages, paginated, for a member.
     *
     * Each message is eager-loaded with the caller's own
     * `group_message_user_status` (their blur/viewed state). Legacy
     * messages predating per-user status tracking are backfilled with an
     * `insertOrIgnore` and reloaded, so the blur logic works for old data
     * too. The caller is responsible for confirming the group exists and
     * that the auth user is a member before invoking this method.
     *
     * Supports two modes: cursor lazy-load when the request carries `limit`
     * (newest page, then older via `before=<id>`), and the backward-compatible
     * full thread otherwise.
     *
     * @param  Request  $request  Query: `limit` (+ optional `before`) for cursor mode; else `per_page`.
     * @param  int  $group_id  The group.
     * @param  User  $authUser  The authenticated member.
     * @return array<string, mixed> Keys: `mode` (`cursor`|`full`), `messages`
     *                              (Collection of GroupMessage), `has_more`
     *                              (bool); full mode also has `paginator`,
     *                              cursor mode also has `before` and `limit`.
     */
    public function getMessages(Request $request, $group_id, User $authUser): array
    {
        $authUserId = $authUser->id;

        $base = GroupMessage::where('group_id', $group_id)
            // Hide messages the viewer has "deleted for me".
            ->whereDoesntHave('deletions', fn ($q) => $q->where('user_id', $authUserId))
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
                'reads.user:id,first_name,last_name',
                'messageStatus' => fn ($q) => $q->where('user_id', $authUserId),
                'replyTo.sender:id,first_name,last_name,avatar',
                // eager-load blur status for the replied message too
                'replyTo.messageStatus' => fn ($q) => $q->where('user_id', $authUserId),
            ]);

        // --- Cursor (lazy-load) mode: the app opts in by sending `limit`. ---
        // Returns the newest `limit` messages (id desc); `before=<id>` fetches
        // the next older page. One extra row is read to compute `has_more`, then
        // dropped. id is the cursor (monotonic, stable) so paging stays correct
        // even as new messages arrive. See
        // docs/PLAN-chat-lazy-load-pagination-2026-06-22.md.
        if ($request->filled('limit')) {
            $limit = max(1, min((int) $request->input('limit'), 100)); // clamp 1..100
            $before = $request->input('before');
            $hasBefore = $before !== null && $before !== '';

            $query = $base->orderBy('id', 'desc');
            if ($hasBefore) {
                $query->where('id', '<', (int) $before);
            }

            $rows = $query->limit($limit + 1)->get();
            $hasMore = $rows->count() > $limit;
            $messages = $rows->take($limit)->values(); // newest-first

            $this->backfillMissingStatus($messages, $authUserId);

            return [
                'mode' => 'cursor',
                'paginator' => null,
                'messages' => $messages,
                'has_more' => $hasMore,
                'before' => $hasBefore ? (int) $before : null,
                'limit' => $limit,
            ];
        }

        // --- Full-thread mode (default): UNCHANGED, so the live app and the
        // existing response contract are untouched. Returns the whole
        // conversation (matches the 1:1 endpoint's per_page=100000). This is the
        // safety net; new clients use the cursor mode above. ---
        $perPage = $request->input('per_page', 100000);

        $paginator = $base->orderBy('created_at', 'asc')->paginate($perPage);

        $this->backfillMissingStatus($paginator->getCollection(), $authUserId);

        return [
            'mode' => 'full',
            'paginator' => $paginator,
            'messages' => $paginator->getCollection(),
            'has_more' => false,
        ];
    }

    /**
     * Backfill the caller's missing `group_message_user_status` rows for the
     * given [$messages] (legacy data predating per-user status tracking), then
     * re-attach the freshly created rows so each message's blur/view state is
     * correct. Shared by the cursor and full-thread fetch paths.
     *
     * @param  Collection  $messages  Loaded GroupMessage models.
     */
    private function backfillMissingStatus($messages, int $authUserId): void
    {
        $missingStatusMessageIds = $messages->filter(function ($message) {
            return $message->messageStatus->isEmpty();
        })->pluck('id');

        if ($missingStatusMessageIds->isEmpty()) {
            return;
        }

        $now = now();
        $rows = $missingStatusMessageIds->map(function ($msgId) use ($authUserId, $messages, $now) {
            $msg = $messages->firstWhere('id', $msgId);
            $isSender = ($msg->sender_id == $authUserId);
            $isMedia = ! is_null($msg->file);

            return [
                'message_id' => $msgId,
                'user_id' => $authUserId,
                'is_viewed' => $isSender,
                'is_blurred' => ! $isSender && $isMedia && $msg->message_type === 'normal',
                'created_at' => $now,
                'updated_at' => $now,
            ];
        })->toArray();

        // insertOrIgnore — a concurrent insert just gets skipped, never errors.
        GroupMessageUserStatus::insertOrIgnore($rows);

        // Re-attach the freshly created status rows.
        $messages->each(function ($message) use ($authUserId) {
            if ($message->messageStatus->isEmpty()) {
                $message->setRelation(
                    'messageStatus',
                    GroupMessageUserStatus::where('message_id', $message->id)
                        ->where('user_id', $authUserId)
                        ->get()
                );
            }
        });
    }

    /**
     * List all media (file) messages in a group, newest first.
     *
     * Used by the group's shared-media gallery. The caller is responsible
     * for confirming the group exists and that the auth user is a member
     * before invoking this method.
     *
     * @param  int  $group_id  The group.
     * @return LengthAwarePaginator The paginated media messages.
     */
    public function messageMedia($group_id): LengthAwarePaginator
    {
        $perPage = 50;
        $messages = GroupMessage::where('group_id', $group_id)
            ->whereNotNull('file')
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
            ])
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);

        return $messages;
    }

    /**
     * Mark all of a group's unread messages as read for the auth user.
     *
     * Creates a `GroupMessageRead` row per previously-unread message
     * (skipping the user's own messages). The caller is responsible for
     * confirming the group exists and that the auth user is a member
     * before invoking this method.
     *
     * @param  int  $group_id  The group.
     * @param  User  $authUser  The authenticated member.
     */
    public function markAsRead($group_id, User $authUser): void
    {
        $unreadMessages = GroupMessage::where('group_id', $group_id)
            ->whereDoesntHave('reads', function ($q) use ($authUser) {
                $q->where('user_id', $authUser->id);
            })
            ->where('sender_id', '!=', $authUser->id)
            ->get(['id', 'sender_id']);

        if ($unreadMessages->isEmpty()) {
            return;
        }

        // Reciprocal: only reveal this member's read to senders when the reader
        // keeps read receipts on. Total membership is constant across the
        // group, so "other members" for any message is (total - 1) — its own
        // sender excluded.
        // ponytail: one reads-count query per newly-read message — fine at
        // group sizes; batch by sender if a huge unread backlog feels slow.
        $readerReceiptsOn = (bool) ($authUser->read_receipts ?? true);
        $totalMembers = $readerReceiptsOn
            ? GroupMember::where('group_id', $group_id)->count()
            : 0;

        foreach ($unreadMessages as $msg) {
            GroupMessageRead::firstOrCreate([
                'group_message_id' => $msg->id,
                'user_id' => $authUser->id,
            ]);

            if (! $readerReceiptsOn) {
                continue;
            }

            // Live text double-check: if this read completes "all other
            // members", tell the sender so their double-check greens without a
            // re-fetch. Non-fatal on broadcast failure.
            $otherMembers = $totalMembers - 1; // exclude the message's sender
            if ($otherMembers <= 0) {
                continue;
            }
            $reads = GroupMessageRead::where('group_message_id', $msg->id)
                ->where('user_id', '!=', $msg->sender_id)
                ->distinct()
                ->count('user_id');
            if ($reads >= $otherMembers) {
                try {
                    broadcast(new GroupMessageReadEvent($msg->id, $msg->sender_id));
                } catch (\Throwable $e) {
                    Log::error('GroupMessageReadEvent broadcast failed', [
                        'message_id' => $msg->id,
                        'sender_id' => $msg->sender_id,
                        'error' => $e->getMessage(),
                    ]);
                }
            }
        }
    }

    /**
     * Mark a group media message as viewed (unblur) for the auth user.
     *
     * The per-group leg of the patent flow — it updates only the caller's
     * own `group_message_user_status` row (`is_viewed=true`,
     * `is_blurred=false`), so unblurring is independent per member and
     * does not reveal the media to anyone else.
     *
     * The caller is responsible for confirming the message exists and
     * that the auth user is a member of its group before invoking this
     * method.
     *
     * @param  int  $message_id  The group message viewed.
     * @param  int  $userId  The authenticated user's id.
     * @return GroupMessageUserStatus The updated/created per-user status row.
     */
    public function markAsViewed($message_id, $userId): GroupMessageUserStatus
    {
        // শুধু এই user-এর নিজের status update হবে — অন্য কারো না
        $status = GroupMessageUserStatus::updateOrCreate(
            [
                'message_id' => $message_id,
                'user_id' => $userId,       // শুধু এই user-এর record
            ],
            [
                'is_viewed' => true,
                'is_blurred' => false,
            ]
        );

        // Tell the message's sender (live) that a member viewed it, so their
        // reaction "watched" dot turns green. Skipped when the viewer is the
        // sender, and withheld when the viewer has read receipts off
        // (reciprocal). Broadcast failure is non-fatal — the view is persisted.
        $message = GroupMessage::select('id', 'group_id', 'sender_id', 'message_type', 'reply_to_message_id')->find($message_id);
        if ($message && (int) $message->sender_id !== (int) $userId) {
            // The reaction "watched" dot must green ONLY when the ORIGINAL
            // media sender watches it — not just any member (any member opening
            // the chat used to mark the reaction viewed, greening the dot
            // falsely). A reaction replies to the media message, so the media
            // sender is that message's sender. Non-reaction media shows no dot,
            // so keep notifying (harmless).
            $notify = true;
            if ($message->message_type === 'reaction') {
                $mediaSenderId = $message->reply_to_message_id
                    ? GroupMessage::whereKey($message->reply_to_message_id)->value('sender_id')
                    : null;
                $notify = $mediaSenderId !== null && (int) $userId === (int) $mediaSenderId;
            }

            $viewerReceiptsOn = (bool) (User::whereKey($userId)->value('read_receipts') ?? true);
            if ($notify && $viewerReceiptsOn) {
                try {
                    broadcast(new GroupMessageViewedEvent(
                        $message->id,
                        $message->group_id,
                        $message->sender_id,
                    ));
                } catch (\Throwable $e) {
                    Log::error('GroupMessageViewedEvent broadcast failed', [
                        'message_id' => $message_id,
                        'viewer_id' => $userId,
                        'error' => $e->getMessage(),
                    ]);
                }
            }
        }

        return $status;
    }

    /**
     * Bulk soft-delete group messages.
     *
     * Deletion is scoped to the given group, so ids belonging to other
     * groups are ignored. The caller is responsible for confirming the
     * group exists and that the auth user is an admin before invoking
     * this method.
     *
     * @param  array  $messageIds  The message ids to delete.
     * @param  int  $group_id  The group the deletion is scoped to.
     */
    public function deleteMessages(array $messageIds, $group_id): void
    {
        GroupMessage::whereIn('id', $messageIds)
            ->where('group_id', $group_id)
            ->delete();
    }
}
