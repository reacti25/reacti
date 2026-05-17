<?php

namespace App\Http\Controllers\Web\Backend;

use App\Http\Controllers\Controller;
use App\Http\Resources\ChatGroupResource;
use App\Http\Resources\GroupDetailsResource;
use App\Http\Resources\MessageResource;
use App\Services\AdminGroupChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

/**
 * Powers the admin panel's group-chat area (web guard).
 *
 * Backs the admin group-chat routes in routes/backend.php: it renders the
 * group-chat interface and exposes JSON endpoints (consumed by the panel's
 * JavaScript) for creating groups, listing them, sending and reading
 * messages, updating group info, and leaving/deleting groups. The only
 * Blade view rendered is `backend.layouts.chat.group_chat`; every other
 * action returns JSON. All actions operate against the `web`-guard admin
 * user as the acting group member.
 *
 * This is a thin controller: it validates input, resolves the acting admin,
 * applies the guard clauses (404/403), and shapes the JSON responses. All
 * DB work, the create transaction, the file uploads, and the
 * `GroupMessageSendEvent` broadcast live in {@see AdminGroupChatService}.
 */
class AdminGroupChatController extends Controller
{
    /**
     * @param  AdminGroupChatService  $groupChatService  Group-chat business logic.
     */
    public function __construct(private readonly AdminGroupChatService $groupChatService)
    {
        parent::__construct();
    }

    /**
     * Show group chat page (for web interface)
     *
     * @return \Illuminate\View\View  The `backend.layouts.chat.group_chat` Blade view.
     */
    public function index()
    {
        return view('backend.layouts.chat.group_chat');
    }

    /**
     * Get users list for group creation
     *
     * Returns every user except the current admin, so they can be picked as
     * members when creating a new group.
     *
     * @param  Request  $request  The current request (unused beyond guard resolution).
     * @return JsonResponse  JSON list of selectable users.
     */
    public function getUsersList(Request $request): JsonResponse
    {
        $authUser = Auth::guard('web')->user();

        $users = $this->groupChatService->selectableUsers($authUser);

        return response()->json([
            'success' => true,
            'users' => $users,
            'code' => 200
        ]);
    }

    /**
     * Create a new group
     *
     * Validates the payload, optionally uploads an avatar, then creates the
     * group and its membership rows inside a transaction — the creator is
     * added as `admin` and every other selected user as `member`.
     *
     * @param  Request  $request  Body: name, description, avatar (file), members[] (user ids).
     * @return JsonResponse  The created group resource, or a 422/500 error payload.
     */
    public function createGroup(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            // name is required; avatar is an optional image capped at 5 MB.
            'name' => 'required|string|max:255',
            'description' => 'nullable|string|max:1000',
            'avatar' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:5120',
            // at least one member must be selected and each must exist.
            'members' => 'required|array|min:1',
            'members.*' => 'exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $authUser = Auth::guard('web')->user();

        try {
            $group = $this->groupChatService->createGroup($request, $authUser);

            return response()->json([
                'success' => true,
                'message' => 'Group created successfully',
                'data' => new ChatGroupResource($group),
                'code' => 200
            ]);
        } catch (\Exception $e) {
            // Any failure rolls back the whole group + membership insert.
            return response()->json([
                'success' => false,
                'message' => 'Failed to create group: ' . $e->getMessage(),
                'code' => 500
            ], 500);
        }
    }

    /**
     * Get all groups for authenticated user - FIXED VERSION
     *
     * Returns every group the current admin belongs to, each enriched with
     * its last message, unread count, and member count. Supports an
     * optional `keyword` query filter on the group name.
     *
     * @param  Request  $request  Query: keyword (optional group-name search term).
     * @return JsonResponse  JSON collection of the user's groups, or a 500 error payload.
     */
    public function listGroups(Request $request): JsonResponse
    {
        try {
            $authUser = Auth::guard('web')->user();
            $keyword = $request->get('keyword');

            $groups = $this->groupChatService->listGroups($authUser, $keyword);

            return response()->json([
                'success' => true,
                'message' => 'Groups retrieved successfully',
                'groups' => ChatGroupResource::collection($groups),
                'code' => 200
            ]);
        } catch (\Exception $e) {
            Log::error('Error loading groups: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to load groups',
                'code' => 500
            ], 500);
        }
    }

    /**
     * Get group details
     *
     * @param  int|string  $group_id  URL param: the group to inspect.
     * @return JsonResponse  Group details with creator/members, or a 403/404 error payload.
     */
    public function groupDetails($group_id): JsonResponse
    {
        $authUser = Auth::guard('web')->user();

        $group = $this->groupChatService->findGroupWithDetails($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // Only members may view a group's details.
        if (!$group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $group = $this->groupChatService->decorateGroupDetails($group, $authUser);

        return response()->json([
            'success' => true,
            'message' => 'Group details retrieved successfully',
            'data' => [
                'group' => new GroupDetailsResource($group)
            ],
            'code' => 200
        ]);
    }

    /**
     * Send message to group - FIXED VERSION
     *
     * Validates the payload, ensures the sender is a group member, stores
     * the message (with optional file upload), marks it read by the sender,
     * and broadcasts `GroupMessageSendEvent` to the other members.
     *
     * @param  Request  $request   Body: text, file (optional attachment).
     * @param  int|string  $group_id  URL param: the target group.
     * @return JsonResponse  The created message resource, or a 403/404/422 error payload.
     */
    public function sendMessage(Request $request, $group_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            // text is optional; attachment is capped at 50 MB.
            'text' => 'nullable|string|max:1000',
            'file' => 'nullable|file|mimes:jpeg,png,jpg,gif,svg,mp3,wav,mp4,mov,avi,txt,pdf,doc,docx,xls,xlsx,zip,rar|max:51200'
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $authUser = Auth::guard('web')->user();
        $group = $this->groupChatService->findGroup($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // Non-members cannot post into the group.
        if (!$group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
        }

        $message = $this->groupChatService->sendMessage($request, $group_id, $authUser);

        return response()->json([
            'success' => true,
            'message' => 'Message sent successfully',
            'data' => ['message' => new MessageResource($message)],
            'code' => 200
        ]);
    }

    /**
     * Get group messages - FIXED VERSION
     *
     * Returns every message in the group ordered oldest-first, eager-loading
     * sender and read-receipt data. Only members may fetch the history.
     *
     * @param  int|string  $group_id  URL param: the group whose messages to load.
     * @return JsonResponse  JSON collection of messages, or a 403/404/500 error payload.
     */
    public function getMessages($group_id): JsonResponse
    {
        try {
            $authUser = Auth::guard('web')->user();
            $group = $this->groupChatService->findGroup($group_id);

            if (!$group) {
                return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
            }

            if (!$group->isMember($authUser->id)) {
                return response()->json(['success' => false, 'message' => 'You are not a member of this group', 'code' => 403], 403);
            }

            $messages = $this->groupChatService->getMessages($group_id);

            return response()->json([
                'success' => true,
                'message' => 'Messages retrieved successfully',
                'data' => [
                    'messages' => MessageResource::collection($messages),
                ],
                'code' => 200
            ]);
        } catch (\Exception $e) {
            Log::error('Error loading messages: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to load messages',
                'code' => 500
            ], 500);
        }
    }

    /**
     * Mark messages as read
     *
     * Creates a read receipt for the current user against every group
     * message they have not yet read (excluding their own messages).
     *
     * @param  int|string  $group_id  URL param: the group being opened/read.
     * @return JsonResponse  Success payload, or a 403 error when not a member.
     */
    public function markAsRead($group_id): JsonResponse
    {
        $authUser = Auth::guard('web')->user();
        $group = $this->groupChatService->findGroup($group_id);

        // Treat a missing group or a non-member the same way: access denied.
        if (!$group || !$group->isMember($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Group not found or access denied', 'code' => 403], 403);
        }

        $this->groupChatService->markAsRead($group_id, $authUser);

        return response()->json([
            'success' => true,
            'message' => 'Messages marked as read',
            'code' => 200
        ]);
    }

    /**
     * Update group info (Admin only)
     *
     * Updates the name, description, and/or avatar of a group. Restricted
     * to users who hold the `admin` role within that group.
     *
     * @param  Request  $request   Body: name, description, avatar (all optional).
     * @param  int|string  $group_id  URL param: the group to update.
     * @return JsonResponse  The updated group resource, or a 403/404/422 error payload.
     */
    public function updateGroup(Request $request, $group_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            // All fields optional — only supplied ones are applied below.
            'name' => 'nullable|string|max:255',
            'description' => 'nullable|string|max:1000',
            'avatar' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:5120',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $authUser = Auth::guard('web')->user();
        $group = $this->groupChatService->findGroup($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // Editing group info is an admin-only privilege.
        if (!$group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can update group', 'code' => 403], 403);
        }

        $group = $this->groupChatService->updateGroup($request, $group);

        return response()->json([
            'success' => true,
            'message' => 'Group updated successfully',
            'data' => new ChatGroupResource($group),
            'code' => 200
        ]);
    }

    /**
     * Leave group
     *
     * Removes the current user's membership row. The group creator cannot
     * leave their own group — they must delete it instead.
     *
     * @param  int|string  $group_id  URL param: the group to leave.
     * @return JsonResponse  Success payload, or a 403/404 error payload.
     */
    public function leaveGroup($group_id): JsonResponse
    {
        $authUser = Auth::guard('web')->user();
        $group = $this->groupChatService->findGroup($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // The creator owns the group and cannot simply leave it.
        if ($authUser->id == $group->created_by) {
            return response()->json(['success' => false, 'message' => 'Group creator cannot leave. Delete the group instead.', 'code' => 403], 403);
        }

        $this->groupChatService->leaveGroup($group_id, $authUser);

        return response()->json([
            'success' => true,
            'message' => 'Left group successfully',
            'code' => 200
        ]);
    }

    /**
     * Delete group (Creator only)
     *
     * Permanently removes the group. Restricted to the user who created it.
     *
     * @param  int|string  $group_id  URL param: the group to delete.
     * @return JsonResponse  Success payload, or a 403/404 error payload.
     */
    public function deleteGroup($group_id): JsonResponse
    {
        $authUser = Auth::guard('web')->user();
        $group = $this->groupChatService->findGroup($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // Only the original creator may delete the group.
        if ($authUser->id != $group->created_by) {
            return response()->json(['success' => false, 'message' => 'Only group creator can delete the group', 'code' => 403], 403);
        }

        $this->groupChatService->deleteGroup($group);

        return response()->json([
            'success' => true,
            'message' => 'Group deleted successfully',
            'code' => 200
        ]);
    }
}
