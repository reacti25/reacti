<?php

namespace App\Services;

use App\Events\GroupMessageSendEvent;
use App\Helper\Helper;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\GroupMessageRead;
use App\Models\GroupMessageUserStatus;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * Business logic for group chat messaging.
 *
 * Extracted from {@see \App\Http\Controllers\Api\Chat\Group\GroupMessageController}
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
    /**
     * @param  PushNotificationService  $pushNotificationService  Device push fan-out.
     */
    public function __construct(
        private readonly PushNotificationService $pushNotificationService
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

        // SAVE MESSAGE
        $message = GroupMessage::create([
            'group_id' => $group_id,
            'sender_id' => $authUser->id,
            'text' => $request->text,
            'file' => $file,
            'status' => 'sent',
            'message_type' => $messageType,
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
        broadcast(new GroupMessageSendEvent($message))->toOthers();

        // FIREBASE NOTIFICATION (সব member except sender)
        $senderName = $authUser->first_name.' '.$authUser->last_name;
        $groupName = $group->name;
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

        $groupMembers = $group->members()
            ->where('user_id', '!=', $authUser->id)
            ->with('user.firebaseTokens')
            ->get();

        foreach ($groupMembers as $member) {
            if (! $member->user || $member->user->firebaseTokens->isEmpty()) {
                continue;
            }

            $notifyData = [
                'title' => $groupName.' • '.$senderName,
                'body' => $messagePreview,
                'icon' => $authUser->avatar ?? config('settings.logo'),
            ];

            $this->pushNotificationService->sendToUser($member->user, $notifyData);
        }

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
     * @param  Request  $request  The incoming request (text).
     * @param  int  $group_id  The group.
     * @param  int  $message_id  The message to edit.
     * @param  User  $authUser  The authenticated user.
     * @return GroupMessage|null The updated message, or null when not found / not the sender.
     */
    public function editMessage(Request $request, $group_id, $message_id, User $authUser): ?GroupMessage
    {
        $message = GroupMessage::where('id', $message_id)
            ->where('group_id', $group_id)
            ->where('sender_id', $authUser->id)
            ->first();

        if (! $message) {
            return null;
        }

        $message->text = $request->text;
        $message->save();

        $message->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'group:id,name,avatar',
        ]);

        return $message;
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
     * @param  Request  $request  The incoming request (per_page).
     * @param  int  $group_id  The group.
     * @param  User  $authUser  The authenticated member.
     * @return LengthAwarePaginator The paginated group messages.
     */
    public function getMessages(Request $request, $group_id, User $authUser): LengthAwarePaginator
    {
        $authUserId = $authUser->id;
        $perPage = $request->input('per_page', 50); // FIX #5: reasonable pagination

        $messages = GroupMessage::where('group_id', $group_id)
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
                'reads.user:id,first_name,last_name',
                'messageStatus' => fn ($q) => $q->where('user_id', $authUserId),
                'replyTo.sender:id,first_name,last_name,avatar',
                // eager-load blur status for the replied message too
                'replyTo.messageStatus' => fn ($q) => $q->where('user_id', $authUserId),
            ])
            ->orderBy('created_at', 'asc')
            ->paginate($perPage);

        // FIX #3: firstOrCreate loop সরিয়ে ফেলা হয়েছে।
        // sendMessage এখন সব member-এর status একসাথে create করে।
        // শুধু edge case handle করো: পুরনো message যার status নেই (migration-এর আগের data)
        $missingStatusMessageIds = $messages->filter(function ($message) {
            return $message->messageStatus->isEmpty();
        })->pluck('id');

        if ($missingStatusMessageIds->isNotEmpty()) {
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

            // insertOrIgnore — duplicate থাকলে skip করবে, error দেবে না
            GroupMessageUserStatus::insertOrIgnore($rows);

            // Re-load missing statuses after insert
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

        return $messages;
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
            ->pluck('id');

        foreach ($unreadMessages as $messageId) {
            GroupMessageRead::firstOrCreate([
                'group_message_id' => $messageId,
                'user_id' => $authUser->id,
            ]);
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

        // FIX #6: Real-time broadcast — অন্য সবাই জানুক কে viewed করল
        // (GroupMessageViewedEvent তৈরি করতে হবে — নিচে দেখো)
        // broadcast(new GroupMessageViewedEvent($message_id, $userId))->toOthers();

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
