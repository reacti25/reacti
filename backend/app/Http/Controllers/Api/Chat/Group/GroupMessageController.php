<?php

namespace App\Http\Controllers\Api\Chat\Group;

use App\Events\GroupMessageSendEvent;
use App\Helper\Helper;
use App\Http\Controllers\Controller;
use App\Http\Resources\GroupMessageMediaResource;
use App\Http\Resources\MessageResource;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\GroupMessageRead;
use App\Models\GroupMessageUserStatus;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

/**
 * Handles group chat messaging for the API.
 *
 * Backs the authenticated `auth/chat/group` message routes: sending,
 * editing, listing, and deleting group messages, plus media listing and
 * read/viewed receipts. Group media participates in the patent flow —
 * per-recipient blur state is tracked in `group_message_user_status`
 * rows so each member's view/unblur is independent, and `markAsViewed()`
 * is the per-user `mark-viewed` equivalent for groups.
 */
class GroupMessageController extends Controller
{
    /**
     * Send message to group
     */
    // public function sendMessage(Request $request, $group_id): JsonResponse
    // {
    //     $validator = Validator::make($request->all(), [
    //         'text' => 'nullable|string|max:1000',
    //         'file' => 'nullable|max:51200',
    //         'message_type' => 'nullable|in:normal,reaction',
    //         'reply_to_message_id' => 'nullable|exists:group_messages,id',
    //     ]);

    //     if ($validator->fails()) {
    //         return response()->json(['message' => $validator->errors()->first()], 422);
    //     }

    //     $authUser = Auth::guard('api')->user();
    //     $group = Group::find($group_id);

    //     if (!$group) {
    //         return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404]);
    //     }

    //     if (!$group->isMember($authUser->id)) {
    //         return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403]);
    //     }

    //     // ---------------------------
    //     // FILE UPLOAD
    //     // ---------------------------
    //     $file = null;
    //     if ($request->hasFile('file')) {
    //         $file = Helper::fileUpload($request->file('file'), 'group_message', time() . 'group_chat_image' . $request->file('file'));
    //     }

    //     // ---------------------------
    //     // DETERMINE MESSAGE TYPE
    //     // ---------------------------
    //     $messageType = $request->input('message_type', 'normal');
    //     $isBlurred = false;

    //     // If it's a normal message with media, it should be blurred
    //     if ($messageType === 'normal' && $file) {
    //         $isBlurred = true;
    //     }

    //     // ---------------------------
    //     // SAVE MESSAGE (only message-level data)
    //     // ---------------------------
    //     $message = GroupMessage::create([
    //         'group_id' => $group_id,
    //         'sender_id' => $authUser->id,
    //         'text' => $request->text,
    //         'file' => $file,
    //         'status' => 'sent',
    //         'message_type' => $messageType,
    //         'reply_to_message_id' => $request->reply_to_message_id,
    //     ]);

    //     // ---------------------------
    //     // SAVE USER-SPECIFIC STATUS FOR SENDER
    //     // ---------------------------
    //     // sender's own message → always unblurred
    //     GroupMessageUserStatus::create([
    //         'message_id' => $message->id,
    //         'user_id' => $authUser->id,
    //         'is_viewed' => false,
    //         'is_blurred' => $isBlurred,
    //     ]);

    //     // ---------------------------
    //     // PRE-LOAD RELATIONS
    //     // ---------------------------
    //     // $message->load([
    //     //     'sender:id,first_name,last_name,avatar,last_activity_at',
    //     //     'group:id,name,avatar'
    //     // ]);

    //     $message->load([
    //         'sender:id,first_name,last_name,avatar,last_activity_at',
    //         'group:id,name,avatar',
    //         'replyTo.sender:id,first_name,last_name,avatar',
    //     ]);

    //     // ---------------------------
    //     // BROADCAST TO GROUP MEMBERS
    //     // ---------------------------
    //     broadcast(new GroupMessageSendEvent($message))->toOthers();

    //     // ---------------------------
    //     // RETURN SAME RESPONSE FORMAT
    //     // ---------------------------
    //     return response()->json([
    //         'success' => true,
    //         'message' => 'Message sent successfully',
    //         'data' => ['message' => new MessageResource($message)],
    //         'code' => 200
    //     ]);
    // }

    /**
     * Send a message to a group.
     *
     * Only members may post (non-members are rejected with 403). A
     * `normal` message carrying media is blurred for recipients but not
     * for the sender — so a `group_message_user_status` row is bulk
     * inserted for every member up front (`is_blurred=false` for the
     * sender, `true` for others), making each member's blur/unblur
     * independent. The message is broadcast via `GroupMessageSendEvent`
     * and a Firebase push is fanned out to every member except the
     * sender (best-effort).
     *
     * @param  Request  $request   Body: text, file, message_type
     *                             (normal|reaction), reply_to_message_id
     * @param  int      $group_id  URL param: the target group
     * @return JsonResponse  The created message as MessageResource, or
     *                       404/403 if group missing or caller not a member,
     *                       422 on validation failure
     */
    public function sendMessage(Request $request, $group_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'text'               => 'nullable|string|max:1000',
            'file'               => 'nullable|max:51200',
            'message_type'       => 'nullable|in:normal,reaction',
            'reply_to_message_id' => 'nullable|exists:group_messages,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $authUser = Auth::guard('api')->user();
        $group    = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404]);
        }

        if (!$group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403]);
        }

        // FILE UPLOAD
        $file = null;
        if ($request->hasFile('file')) {
            $file = Helper::fileUpload(
                $request->file('file'),
                'group_message',
                time() . 'group_chat_image' . $request->file('file')
            );
        }

        // DETERMINE MESSAGE TYPE & BLUR FLAG
        $messageType = $request->input('message_type', 'normal');

        // Only normal + media messages are blurred for recipients
        $isBlurredForRecipients = ($messageType === 'normal' && $file !== null);

        // SAVE MESSAGE
        $message = GroupMessage::create([
            'group_id'            => $group_id,
            'sender_id'           => $authUser->id,
            'text'                => $request->text,
            'file'                => $file,
            'status'              => 'sent',
            'message_type'        => $messageType,
            'reply_to_message_id' => $request->reply_to_message_id,
        ]);

        // -------------------------------------------------------
        // FIX #1 + FIX #2:
        // Message send হওয়ার সাথে সাথেই সব member-এর status create করো।
        // Sender: is_blurred = false (সে নিজের message দেখতে পাবে)
        // Others: is_blurred = true যদি normal+media হয়, নাহলে false
        // -------------------------------------------------------
        $memberIds = $group->members()->pluck('user_id');
        $now       = now();

        $statusRows = $memberIds->map(function ($memberId) use ($message, $authUser, $isBlurredForRecipients, $now) {
            $isSender = ($memberId == $authUser->id);
            return [
                'message_id' => $message->id,
                'user_id'    => $memberId,
                'is_viewed'  => false,
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
            'replyTo.messageStatus' => fn($q) => $q->where('user_id', $authUser->id),
            'messageStatus' => fn($q) => $q->where('user_id', $authUser->id),
        ]);

        // BROADCAST TO GROUP MEMBERS
        broadcast(new GroupMessageSendEvent($message))->toOthers();

        // FIREBASE NOTIFICATION (সব member except sender)
        $senderName     = $authUser->first_name . ' ' . $authUser->last_name;
        $groupName      = $group->name;
        $messagePreview = '';

        if ($file) {
            $ext             = strtolower(pathinfo($file, PATHINFO_EXTENSION));
            $imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
            $videoExtensions = ['mp4', 'mov', 'avi', 'mkv'];

            if (in_array($ext, $imageExtensions))      $messagePreview = '📷 Photo';
            elseif (in_array($ext, $videoExtensions))  $messagePreview = '🎥 Video';
            else                                        $messagePreview = '📎 File';
        } else {
            $messagePreview = Str::limit($request->text ?? '', 50);
        }

        $groupMembers = $group->members()
            ->where('user_id', '!=', $authUser->id)
            ->with('user.firebaseTokens')
            ->get();

        foreach ($groupMembers as $member) {
            if (!$member->user || $member->user->firebaseTokens->isEmpty()) {
                continue;
            }

            $notifyData = [
                'title' => $groupName . ' • ' . $senderName,
                'body'  => $messagePreview,
                'icon'  => $authUser->avatar ?? config('settings.logo'),
            ];

            foreach ($member->user->firebaseTokens as $firebaseToken) {
                Helper::sendNotifyMobile($firebaseToken->token, $notifyData);
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Message sent successfully',
            'data'    => ['message' => new MessageResource($message)],
            'code'    => 200,
        ]);
    }

    /**
     * Edit the text of a group message.
     *
     * Only the original sender may edit, and only their own message in
     * that group — any other caller gets 404.
     *
     * @param  Request  $request     Body: text (required, new content)
     * @param  int      $group_id    URL param: the group
     * @param  int      $message_id  URL param: the message to edit
     * @return JsonResponse  Updated message as MessageResource, 404/403 if
     *                       group/message missing or caller not a member,
     *                       422 on validation failure
     */
    public function editMessage(Request $request, $group_id, $message_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'text' => 'required|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (!$group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $message = GroupMessage::where('id', $message_id)
            ->where('group_id', $group_id)
            ->where('sender_id', $authUser->id)
            ->first();

        if (!$message) {
            return response()->json(['success' => false, 'message' => 'Message not found or you cannot edit this message', 'code' => 404], 404);
        }

        $message->text = $request->text;
        $message->save();

        $message->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'group:id,name,avatar'
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Message updated successfully',
            'data' => ['message' => new MessageResource($message)],
            'code' => 200
        ]);
    }

    /**
     * Get a group's messages, paginated, for a member.
     *
     * Each message is eager-loaded with the caller's own
     * `group_message_user_status` (their blur/viewed state). Legacy
     * messages predating per-user status tracking are backfilled with
     * an `insertOrIgnore` and reloaded, so the blur logic works for old
     * data too.
     *
     * @param  Request  $request   Query: per_page (default 50)
     * @param  int      $group_id  URL param: the group
     * @return JsonResponse  Messages as MessageResource collection +
     *                       pagination, or 404/403 if missing / not a member
     */
    public function getMessages(Request $request, $group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group    = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (!$group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $authUserId = $authUser->id;
        $perPage    = $request->input('per_page', 50); // FIX #5: reasonable pagination

        $messages = GroupMessage::where('group_id', $group_id)
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
                'reads.user:id,first_name,last_name',
                'messageStatus'    => fn($q) => $q->where('user_id', $authUserId),
                'replyTo.sender:id,first_name,last_name,avatar',
                // eager-load blur status for the replied message too
                'replyTo.messageStatus' => fn($q) => $q->where('user_id', $authUserId),
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
            $now  = now();
            $rows = $missingStatusMessageIds->map(function ($msgId) use ($authUserId, $messages, $now) {
                $msg      = $messages->firstWhere('id', $msgId);
                $isSender = ($msg->sender_id == $authUserId);
                $isMedia  = !is_null($msg->file);

                return [
                    'message_id' => $msgId,
                    'user_id'    => $authUserId,
                    'is_viewed'  => $isSender,
                    'is_blurred' => !$isSender && $isMedia && $msg->message_type === 'normal',
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

        return response()->json([
            'success' => true,
            'message' => 'Messages retrieved successfully',
            'data'    => [
                'messages'   => MessageResource::collection($messages),
                'pagination' => [
                    'total'        => $messages->total(),
                    'current_page' => $messages->currentPage(),
                    'last_page'    => $messages->lastPage(),
                    'per_page'     => $messages->perPage(),
                ],
            ],
            'code' => 200,
        ]);
    }


    /**
     * List all media (file) messages in a group, newest first.
     *
     * Used by the group's shared-media gallery. Members only.
     *
     * @param  int  $group_id  URL param: the group
     * @return \Illuminate\Http\JsonResponse  Paginated media as
     *                                        GroupMessageMediaResource, or
     *                                        404/403 if missing / not a member
     */
    public function messageMedia($group_id)
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (!$group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $perPage = 50;
        $messages = GroupMessage::where('group_id', $group_id)
            ->whereNotNull('file')
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
            ])
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'message' => 'Media files retrieved successfully',
            'data' => [
                'media' => GroupMessageMediaResource::collection($messages->items()),
                'pagination' => [
                    'total'       => $messages->total(),
                    'current_page' => $messages->currentPage(),
                    'last_page'   => $messages->lastPage(),
                    'per_page'    => $messages->perPage(),
                ],
            ],
            'code' => 200
        ]);
    }

    /**
     * Mark all of a group's unread messages as read for the auth user.
     *
     * Creates a `GroupMessageRead` row per previously-unread message
     * (skipping the user's own messages).
     *
     * @param  int  $group_id  URL param: the group
     * @return JsonResponse  Success, or 403 if group missing / not a member
     */
    public function markAsRead($group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group || !$group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Group not found or access denied', 'code' => 403], 403);
        }

        $unreadMessages = GroupMessage::where('group_id', $group_id)
            ->whereDoesntHave('reads', function ($q) use ($authUser) {
                $q->where('user_id', $authUser->id);
            })
            ->where('sender_id', '!=', $authUser->id)
            ->pluck('id');

        foreach ($unreadMessages as $messageId) {
            GroupMessageRead::firstOrCreate([
                'group_message_id' => $messageId,
                'user_id' => $authUser->id
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Messages marked as read',
            'code' => 200
        ]);
    }

    /**
     * Mark a group media message as viewed (unblur) for the auth user.
     *
     * The per-group leg of the patent flow — it updates only the
     * caller's own `group_message_user_status` row (`is_viewed=true`,
     * `is_blurred=false`), so unblurring is independent per member and
     * does not reveal the media to anyone else.
     *
     * @param  Request  $request     Unused; present for route signature.
     * @param  int      $message_id  URL param: the group message viewed
     * @return JsonResponse  The updated status row, or 404/403 if the
     *                       message is missing or the caller is not a member
     */
    public function markAsViewed(Request $request, $message_id): JsonResponse
    {
        $userId  = Auth::guard('api')->id();
        $message = GroupMessage::find($message_id);

        if (!$message) {
            return response()->json(['success' => false, 'message' => 'Message not found', 'code' => 404]);
        }

        if (!$message->group->isMember($userId)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403]);
        }

        // শুধু এই user-এর নিজের status update হবে — অন্য কারো না
        $status = GroupMessageUserStatus::updateOrCreate(
            [
                'message_id' => $message_id,
                'user_id'    => $userId,       // শুধু এই user-এর record
            ],
            [
                'is_viewed'  => true,
                'is_blurred' => false,
            ]
        );

        // FIX #6: Real-time broadcast — অন্য সবাই জানুক কে viewed করল
        // (GroupMessageViewedEvent তৈরি করতে হবে — নিচে দেখো)
        // broadcast(new GroupMessageViewedEvent($message_id, $userId))->toOthers();

        return response()->json([
            'success' => true,
            'message' => 'Message marked as viewed',
            'data'    => ['status' => $status],
            'code'    => 200,
        ]);
    }

    /**
     * Bulk soft-delete group messages (admin only).
     *
     * Deletion is scoped to the given group, so ids belonging to other
     * groups are ignored.
     *
     * @param  Request  $request   Body: message_ids (array of ids)
     * @param  int      $group_id  URL param: the group
     * @return JsonResponse  Success, 404 if group missing,
     *                       403 if caller not an admin, 422 on validation
     */
    public function deleteMessages(Request $request, $group_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'message_ids' => 'required|array|min:1',
            'message_ids.*' => 'exists:group_messages,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (!$group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can delete messages', 'code' => 403], 403);
        }

        GroupMessage::whereIn('id', $request->message_ids)
            ->where('group_id', $group_id)
            ->delete();

        return response()->json([
            'success' => true,
            'message' => 'Messages deleted successfully',
            'code' => 200
        ]);
    }
}
