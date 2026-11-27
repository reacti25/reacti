<?php

namespace App\Http\Controllers\Api\Chat\Group;

use App\Http\Controllers\Controller;
use App\Http\Requests\Group\DeleteGroupMessagesRequest;
use App\Http\Requests\Group\EditGroupMessageRequest;
use App\Http\Requests\Group\SendGroupMessageRequest;
use App\Http\Resources\GroupMessageMediaResource;
use App\Http\Resources\MessageResource;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Services\GroupMessageService;
use App\Services\GroupOneTimeMediaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/**
 * Handles group chat messaging for the API.
 *
 * Backs the authenticated `auth/chat/group` message routes: sending,
 * editing, listing, and deleting group messages, plus media listing and
 * read/viewed receipts. Group media participates in the patent flow —
 * per-recipient blur state is tracked in `group_message_user_status`
 * rows so each member's view/unblur is independent, and `markAsViewed()`
 * is the per-user `mark-viewed` equivalent for groups.
 *
 * This is a thin controller — it validates input, applies soft-failure
 * guard clauses, and shapes responses; all business logic lives in
 * {@see GroupMessageService}.
 */
class GroupMessageController extends Controller
{
    /**
     * @param  GroupMessageService  $groupMessageService  Group messaging business logic.
     */
    public function __construct(private readonly GroupMessageService $groupMessageService)
    {
        parent::__construct();
    }

    /**
     * Send a message to a group.
     *
     * Validates the request and applies the missing-group (404) and
     * not-a-member (403) guard clauses, then delegates to
     * {@see GroupMessageService::sendMessage()}. A `normal` message
     * carrying media is blurred for recipients but not for the sender —
     * the service bulk-inserts a `group_message_user_status` row for
     * every member, broadcasts `GroupMessageSendEvent`, and fans out a
     * Firebase push to every member except the sender.
     *
     * @param  SendGroupMessageRequest  $request  Body: text, file,
     *                                            message_type (normal|reaction), reply_to_message_id
     * @param  int  $group_id  URL param: the target group
     * @return JsonResponse The created message as MessageResource, or
     *                      404/403 if group missing or caller not a member,
     *                      422 on validation failure
     */
    public function sendMessage(SendGroupMessageRequest $request, $group_id): JsonResponse
    {

        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404]);
        }

        if (! $group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403]);
        }

        // A reaction that arrives after its one-timer was erased (a late
        // upload) would outlive the exchange: refuse it, so the app drops it.
        if ($request->input('message_type') === 'reaction'
            && ! GroupOneTimeMediaService::acceptsReactionTo($request->integer('reply_to_message_id') ?: null)) {
            return response()->json(['success' => false, 'message' => 'This one-time media is gone', 'code' => 422], 422);
        }

        $message = $this->groupMessageService->sendMessage($request, $group_id, $group, $authUser);

        return response()->json([
            'success' => true,
            'message' => 'Message sent successfully',
            'data' => ['message' => new MessageResource($message)],
            'code' => 200,
        ]);
    }

    /**
     * Edit the text of a group message.
     *
     * Validates the request and applies the missing-group (404) and
     * not-a-member (403) guard clauses, then delegates to
     * {@see GroupMessageService::editMessage()}, which only edits the
     * caller's own message in that group — any other case returns 404.
     *
     * @param  EditGroupMessageRequest  $request  Body: text (required, new content)
     * @param  int  $group_id  URL param: the group
     * @param  int  $message_id  URL param: the message to edit
     * @return JsonResponse Updated message as MessageResource, 404/403 if
     *                      group/message missing or caller not a member,
     *                      422 on validation failure
     */
    public function editMessage(EditGroupMessageRequest $request, $group_id, $message_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (! $group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $message = $this->groupMessageService->editMessage($request, $group_id, $message_id, $authUser);

        if ($message === 'expired') {
            return response()->json(['success' => false, 'message' => 'You can only edit a message within 10 minutes of sending it.', 'code' => 422], 422);
        }

        if ($message === 'not_found') {
            return response()->json(['success' => false, 'message' => 'Message not found or you cannot edit this message', 'code' => 404], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Message updated successfully',
            'data' => ['message' => new MessageResource($message)],
            'code' => 200,
        ]);
    }

    /**
     * Get a group's messages, paginated, for a member.
     *
     * Applies the missing-group (404) and not-a-member (403) guard
     * clauses, then delegates to {@see GroupMessageService::getMessages()},
     * which eager-loads the caller's own `group_message_user_status` and
     * backfills legacy messages that predate per-user status tracking.
     *
     * @param  Request  $request  Query: `limit` (+ optional `before=<id>`) for
     *                            cursor lazy-load (newest page, then older);
     *                            omit for the full thread (back-compat default).
     * @param  int  $group_id  URL param: the group
     * @return JsonResponse Messages as MessageResource collection + pagination
     *                      (full: total/current_page/last_page/per_page;
     *                      cursor: has_more/before/limit) + is_admin (whether
     *                      the caller is a group admin), or 404/403
     */
    public function getMessages(Request $request, $group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (! $group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $result = $this->groupMessageService->getMessages($request, $group_id, $authUser);

        // Full mode keeps the exact pagination keys the live app/contract expect
        // (total/current_page/last_page/per_page); cursor mode adds before/limit.
        // has_more is additive (contract is additive-safe) and present in both.
        $pagination = ['has_more' => $result['has_more']];
        if ($result['mode'] === 'cursor') {
            $pagination['before'] = $result['before'];
            $pagination['limit'] = $result['limit'];
        } else {
            $paginator = $result['paginator'];
            $pagination['total'] = $paginator->total();
            $pagination['current_page'] = $paginator->currentPage();
            $pagination['last_page'] = $paginator->lastPage();
            $pagination['per_page'] = $paginator->perPage();
        }

        return response()->json([
            'success' => true,
            'message' => 'Messages retrieved successfully',
            'data' => [
                'messages' => MessageResource::collection($result['messages']),
                'pagination' => $pagination,
                // Lets the app offer "Delete for everyone" on other members'
                // messages to a group admin only.
                'is_admin' => $group->isAdmin($authUser->id),
            ],
            'code' => 200,
        ]);
    }

    /**
     * List all media (file) messages in a group, newest first.
     *
     * Applies the missing-group (404) and not-a-member (403) guard
     * clauses, then delegates to {@see GroupMessageService::messageMedia()}.
     * Used by the group's shared-media gallery.
     *
     * @param  int  $group_id  URL param: the group
     * @return JsonResponse Paginated media as
     *                      GroupMessageMediaResource, or
     *                      404/403 if missing / not a member
     */
    public function messageMedia($group_id)
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (! $group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $messages = $this->groupMessageService->messageMedia($group_id);

        return response()->json([
            'success' => true,
            'message' => 'Media files retrieved successfully',
            'data' => [
                'media' => GroupMessageMediaResource::collection($messages->items()),
                'pagination' => [
                    'total' => $messages->total(),
                    'current_page' => $messages->currentPage(),
                    'last_page' => $messages->lastPage(),
                    'per_page' => $messages->perPage(),
                ],
            ],
            'code' => 200,
        ]);
    }

    /**
     * Mark all of a group's unread messages as read for the auth user.
     *
     * Applies the combined missing-group / not-a-member (403) guard
     * clause, then delegates to {@see GroupMessageService::markAsRead()},
     * which creates a `GroupMessageRead` row per previously-unread message
     * (skipping the user's own messages).
     *
     * @param  int  $group_id  URL param: the group
     * @return JsonResponse Success, or 403 if group missing / not a member
     */
    public function markAsRead($group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group || ! $group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Group not found or access denied', 'code' => 403], 403);
        }

        $this->groupMessageService->markAsRead($group_id, $authUser);

        return response()->json([
            'success' => true,
            'message' => 'Messages marked as read',
            'code' => 200,
        ]);
    }

    /**
     * Mark a group media message as viewed (unblur) for the auth user.
     *
     * The per-group leg of the patent flow. Applies the missing-message
     * (404) and not-a-member (403) guard clauses, then delegates to
     * {@see GroupMessageService::markAsViewed()}, which updates only the
     * caller's own `group_message_user_status` row (`is_viewed=true`,
     * `is_blurred=false`) so unblurring is independent per member.
     *
     * @param  Request  $request  Unused; present for route signature.
     * @param  int  $message_id  URL param: the group message viewed
     * @return JsonResponse The updated status row, or 404/403 if the
     *                      message is missing or the caller is not a member
     */
    public function markAsViewed(Request $request, $message_id): JsonResponse
    {
        $userId = Auth::guard('api')->id();
        $message = GroupMessage::find($message_id);

        if (! $message) {
            return response()->json(['success' => false, 'message' => 'Message not found', 'code' => 404]);
        }

        if (! $message->group->isMember($userId)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403]);
        }

        $status = $this->groupMessageService->markAsViewed($message_id, $userId);

        return response()->json([
            'success' => true,
            'message' => 'Message marked as viewed',
            'data' => ['status' => $status],
            'code' => 200,
        ]);
    }

    /**
     * Soft-delete group messages for everyone.
     *
     * A group admin may delete any message of the group. Any other member
     * may delete only their own: ids of other members' messages are left
     * alone, and when none of the ids is theirs the answer is 403.
     *
     * Validates the request and applies the missing-group (404) and
     * not-a-member (403) guard clauses, then delegates to
     * {@see GroupMessageService::deleteMessages()}. Deletion is scoped to
     * the group, so ids belonging to other groups are ignored.
     *
     * @param  Request  $request  Body: message_ids (array of ids)
     * @param  DeleteGroupMessagesRequest  $request  Body: message_ids (array of ids)
     * @param  int  $group_id  URL param: the group
     * @return JsonResponse Success, 404 if group missing, 403 if the caller
     *                      is not a member or may delete none of the
     *                      messages, 422 on validation
     */
    public function deleteMessages(DeleteGroupMessagesRequest $request, $group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (! $group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $ownOnly = ! $group->isAdmin($authUser->id);
        $deleted = $this->groupMessageService->deleteMessages(
            $request->message_ids,
            $group_id,
            $ownOnly ? $authUser->id : null,
        );

        if ($ownOnly && $deleted === 0) {
            return response()->json(['success' => false, 'message' => 'You can only delete your own messages', 'code' => 403], 403);
        }

        return response()->json([
            'success' => true,
            'message' => 'Messages deleted successfully',
            'code' => 200,
        ]);
    }

    /**
     * Hide a single group message for the auth user only ("delete for me").
     *
     * Unlike {@see deleteMessages()} (delete for everyone), this hides the
     * message for the caller alone; it stays for the rest of the group.
     *
     * @param  int  $message_id  URL param: the message to hide.
     */
    public function deleteForMe($message_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();

        $hidden = $this->groupMessageService->deleteForMe((int) $message_id, $authUser);

        if (! $hidden) {
            return response()->json(['success' => false, 'message' => 'Message not found', 'code' => 404], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Message deleted for you',
            'code' => 200,
        ]);
    }
}
