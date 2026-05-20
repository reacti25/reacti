<?php

namespace App\Http\Controllers\Api\Chat\Group;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\ChatGroupResource;
use App\Http\Resources\GroupDetailsResource;
use App\Http\Resources\MessageResource;
use App\Models\Group;
use App\Services\GroupService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

/**
 * Handles group lifecycle and group metadata for the API.
 *
 * Backs the authenticated `auth/chat/group` routes for creating groups,
 * listing the auth user's groups, fetching group details, and updating
 * a group's info or avatar. Membership operations live in
 * GroupManageMemberController; messaging lives in GroupMessageController.
 * Info/avatar updates broadcast `GroupUpdatedEvent` for live refresh.
 *
 * This is a thin controller — it validates input, applies soft-failure
 * guard clauses, and shapes responses; all business logic lives in
 * {@see GroupService}.
 */
class GroupCreateController extends Controller
{
    /**
     * @param  GroupService  $groupService  Group lifecycle/metadata business logic.
     */
    public function __construct(private readonly GroupService $groupService)
    {
        parent::__construct();
    }

    /**
     * Create a new group with the auth user as admin.
     *
     * Validates the request, then delegates to
     * {@see GroupService::createGroup()}, which uploads the optional
     * avatar and — inside a DB transaction — writes the group, the
     * creator's `admin` membership, and each other member's `member`
     * membership together (the creator id is filtered out of `members`
     * so it is not added twice).
     *
     * @param  Request  $request  Body: name, description, avatar (image),
     *                            members (array of user ids)
     * @return JsonResponse  Created group as ChatGroupResource, or
     *                       422 on validation failure, 500 on error
     */
    public function createGroup(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'description' => 'nullable|string|max:1000',
            'avatar' => 'nullable|max:5120',
            'members' => 'required|array|min:1',
            'members.*' => 'exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $authUser = Auth::guard('api')->user();

        try {
            $group = $this->groupService->createGroup($request, $authUser);

            return response()->json([
                'success' => true,
                'message' => 'Group created successfully',
                'data' => new ChatGroupResource($group),
                'code' => 200
            ]);
        } catch (\Exception $e) {
            // Don't leak exception messages, file paths or line numbers
            // to the client — log them.
            \Log::error('Create group error: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Failed to create group. Please try again.',
                'code' => 500,
            ], 500);
        }
    }

    /**
     * List every group the authenticated user belongs to.
     *
     * Delegates to {@see GroupService::listGroups()}, which decorates each
     * group with its last message, the auth user's unread count, and
     * member count for the chat-list UI.
     *
     * @param  Request  $request  Query: keyword (optional name filter)
     * @return JsonResponse  Groups as a ChatGroupResource collection
     */
    public function listGroups(Request $request): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $keyword = $request->get('keyword');

        $groups = $this->groupService->listGroups($authUser, $keyword);

        return response()->json([
            'success' => true,
            'message' => 'Groups retrieved successfully',
            'groups' => ChatGroupResource::collection($groups),
            'code' => 200
        ]);
    }

    /**
     * Get full details of a single group.
     *
     * Delegates to {@see GroupService::groupDetails()}, which returns the
     * decorated group when it exists and the caller is a member, or throws
     * an {@see ApiException} carrying the distinct status — 404 for a
     * missing group, 403 for a non-member — so the soft-failure envelopes
     * are byte-identical to the pre-refactor controller. Unexpected errors
     * are deliberately not caught and bubble to Laravel's handler unchanged.
     *
     * @param  int  $group_id  URL param: the group to inspect
     * @return JsonResponse  GroupDetailsResource, 404 if missing,
     *                       403 if the caller is not a member
     */
    public function groupDetails($group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();

        try {
            $group = $this->groupService->groupDetails($group_id, $authUser);

            return response()->json([
                'success' => true,
                'message' => 'Group details retrieved successfully',
                'data' => [
                    'group' => new GroupDetailsResource($group)
                ],
                'code' => 200
            ]);
        } catch (ApiException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => $e->status()
            ], $e->status());
        }
    }

    /**
     * Update group info — name, description, and/or avatar.
     *
     * Validates the request and applies the missing-group (404) and
     * admin-only (403) guard clauses, then delegates persistence to
     * {@see GroupService::updateGroup()}, which uploads any new avatar
     * and broadcasts `GroupUpdatedEvent($group_id, 'info', $data)` so
     * listening clients re-render the group header without polling.
     *
     * Validation:
     *   name         nullable, string, max:255
     *   description  nullable, string, max:1000
     *   avatar       nullable, image, max:5120 KB
     *
     * @param  Request  $request   Body: name, description, avatar
     * @param  int      $group_id  URL param: target group
     */
    public function updateGroup(Request $request, $group_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'nullable|string|max:255',
            'description' => 'nullable|string|max:1000',
            'avatar' => 'nullable|image|max:5120',
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
            return response()->json(['success' => false, 'message' => 'Only admins can update group', 'code' => 403], 403);
        }

        $group = $this->groupService->updateGroup($request, $group, $authUser);

        return response()->json([
            'success' => true,
            'message' => 'Group updated successfully',
            'data' =>  new MessageResource($group),
            'code' => 200
        ]);
    }

    /**
     * Replace a group's avatar image.
     *
     * Validates the request and applies the missing-group (404) and
     * admin-only (403) guard clauses, then delegates to
     * {@see GroupService::updateAvatar()}, which uploads the new file,
     * deletes the old avatar from disk, updates the column, and
     * broadcasts `GroupUpdatedEvent($group_id, 'avatar', $data)`.
     *
     * Validation:
     *   avatar  required, max:5120 KB
     *
     * @param  Request  $request   Body: avatar (image)
     * @param  int      $group_id  URL param: target group
     */
    public function updateAvatar(Request $request, $group_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'avatar' => 'required|max:5120', // Max 5MB
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'code' => 422
            ], 422);
        }

        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group) {
            return response()->json([
                'success' => false,
                'message' => 'Group not found',
                'code' => 404
            ], 404);
        }

        // Only admins or group creator can update avatar
        if (!$group->isAdmin($authUser->id)) {
            return response()->json([
                'success' => false,
                'message' => 'Only admins can update group avatar',
                'code' => 403
            ], 403);
        }

        $group = $this->groupService->updateAvatar($request, $group, $authUser);

        return response()->json([
            'success' => true,
            'message' => 'Group avatar updated successfully',
            'data' => new MessageResource($group),
            'code' => 200
        ]);
    }
}
