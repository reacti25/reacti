<?php

namespace App\Http\Controllers\Api\Chat\Group;

use App\Http\Controllers\Controller;
use App\Models\Group;
use App\Models\GroupMember;
use App\Services\GroupMemberService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

/**
 * Manages group membership and roles for the API.
 *
 * Backs the authenticated `auth/chat/group` membership routes: adding
 * and removing members, promoting/demoting admins, leaving a group, and
 * deleting a group. Most actions are admin-gated; the group creator
 * (owner) has extra protections — they cannot be removed, demoted, or
 * leave, and only they may delete the group.
 *
 * This is a thin controller — it validates input, applies soft-failure
 * guard clauses, and shapes responses; all business logic lives in
 * {@see GroupMemberService}.
 */
class GroupManageMemberController extends Controller
{
    /**
     * @param  GroupMemberService  $groupMemberService  Group membership/role business logic.
     */
    public function __construct(private readonly GroupMemberService $groupMemberService)
    {
        parent::__construct();
    }

    /**
     * Add one or more members to a group (admin only).
     *
     * Validates the request and applies the missing-group (404) and
     * admin-only (403) guard clauses, then delegates to
     * {@see GroupMemberService::addMembers()}, which skips users already
     * in the group and returns only the newly added ids.
     *
     * @param  Request  $request  Body: members (array of user ids)
     * @param  int  $group_id  URL param: the target group
     * @return JsonResponse Added member ids, 404 if group missing,
     *                      403 if the caller is not an admin, 422 on validation
     */
    public function addMembers(Request $request, $group_id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'members' => 'required|array|min:1',
            'members.*' => 'exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (! $group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can add members', 'code' => 403], 403);
        }

        $addedMembers = $this->groupMemberService->addMembers($group, $request->members);

        return response()->json([
            'success' => true,
            'message' => 'Members added successfully',
            'data' => ['added_members' => $addedMembers],
            'code' => 200,
        ]);
    }

    /**
     * Remove a member from a group (admin only).
     *
     * Applies the missing-group (404), admin-only (403), and
     * cannot-remove-creator (403) guard clauses, then delegates the
     * delete to {@see GroupMemberService::removeMember()}.
     *
     * @param  int  $group_id  URL param: the target group
     * @param  int  $user_id  URL param: the member to remove
     * @return JsonResponse Success, 404 if group missing,
     *                      403 if caller is not admin or target is the creator
     */
    public function removeMember($group_id, $user_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (! $group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can remove members', 'code' => 403], 403);
        }

        // Cannot remove creator
        if ($user_id == $group->created_by) {
            return response()->json(['success' => false, 'message' => 'Cannot remove group creator', 'code' => 403], 403);
        }

        $this->groupMemberService->removeMember($group_id, $user_id);

        return response()->json([
            'success' => true,
            'message' => 'Member removed successfully',
            'code' => 200,
        ]);
    }

    /**
     * Promote an existing member to admin (admin only).
     *
     * Applies the missing-group (404), admin-only (403), and
     * not-a-member (404) guard clauses, then delegates the role update to
     * {@see GroupMemberService::makeAdmin()}.
     *
     * @param  int  $group_id  URL param: the target group
     * @param  int  $user_id  URL param: the member to promote
     * @return JsonResponse Success, 404 if group missing or user is not
     *                      a member, 403 if the caller is not an admin
     */
    public function makeAdmin($group_id, $user_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (! $group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can promote members', 'code' => 403], 403);
        }

        $member = GroupMember::where('group_id', $group_id)->where('user_id', $user_id)->first();

        if (! $member) {
            return response()->json(['success' => false, 'message' => 'User is not a member', 'code' => 404], 404);
        }

        $this->groupMemberService->makeAdmin($member);

        return response()->json([
            'success' => true,
            'message' => 'Member promoted to admin',
            'code' => 200,
        ]);
    }

    /**
     * Demote a group admin back to a regular member (admin only).
     *
     * Applies the missing-group (404), admin-only (403), owner-protection
     * (403), not-a-member (404), and not-actually-an-admin (400) guard
     * clauses, then delegates the role update to
     * {@see GroupMemberService::removeAdmin()}.
     *
     * @param  int  $group_id  URL param: the target group
     * @param  int  $user_id  URL param: the admin to demote
     * @return JsonResponse Success, 404 if group/member missing,
     *                      403 if caller not admin or target is owner,
     *                      400 if the target is not actually an admin
     */
    public function removeAdmin($group_id, $user_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        // Check if group exists
        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // Only admins can demote others
        if (! $group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can demote members', 'code' => 403], 403);
        }

        // Only owner can remove admin
        if ($group->isOwner($user_id)) {
            return response()->json(['success' => false, 'message' => 'Group owner cannot be demoted', 'code' => 403], 403);
        }

        // Fetch the target member
        $member = GroupMember::where('group_id', $group_id)
            ->where('user_id', $user_id)
            ->first();

        if (! $member) {
            return response()->json(['success' => false, 'message' => 'User is not a member of this group', 'code' => 404], 404);
        }

        // Prevent demoting the group owner
        if ($group->created_by == $user_id) {
            return response()->json(['success' => false, 'message' => 'Group owner cannot be demoted', 'code' => 403], 403);
        }

        // Check if user is actually an admin before demotion
        if ($member->role !== 'admin') {
            return response()->json(['success' => false, 'message' => 'User is not an admin', 'code' => 400], 400);
        }

        // Demote admin to member
        $this->groupMemberService->removeAdmin($member);

        return response()->json([
            'success' => true,
            'message' => 'Admin demoted to member successfully',
            'code' => 200,
        ]);
    }

    /**
     * Remove the authenticated user from a group.
     *
     * Applies the missing-group (404) and creator-cannot-leave (403)
     * guard clauses, then delegates the delete to
     * {@see GroupMemberService::leaveGroup()}.
     *
     * @param  int  $group_id  URL param: the group to leave
     * @return JsonResponse Success, 404 if group missing,
     *                      403 if the caller is the group creator
     */
    public function leaveGroup($group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // Creator cannot leave, must delete group
        if ($authUser->id == $group->created_by) {
            return response()->json(['success' => false, 'message' => 'Group creator cannot leave. Delete the group instead.', 'code' => 403], 403);
        }

        $this->groupMemberService->leaveGroup($group_id, $authUser->id);

        return response()->json([
            'success' => true,
            'message' => 'Left group successfully',
            'code' => 200,
        ]);
    }

    /**
     * Delete a group entirely (creator only).
     *
     * Applies the missing-group (404) and creator-only (403) guard
     * clauses, then delegates the delete to
     * {@see GroupMemberService::deleteGroup()}.
     *
     * @param  int  $group_id  URL param: the group to delete
     * @return JsonResponse Success, 404 if group missing,
     *                      403 if the caller is not the creator
     */
    public function deleteGroup($group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (! $group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if ($authUser->id != $group->created_by) {
            return response()->json(['success' => false, 'message' => 'Only group creator can delete the group', 'code' => 403], 403);
        }

        $this->groupMemberService->deleteGroup($group);

        return response()->json([
            'success' => true,
            'message' => 'Group deleted successfully',
            'code' => 200,
        ]);
    }

    /**
     * List users not yet in a group (candidates to add).
     *
     * Delegates to {@see GroupMemberService::availableUsers()}, which
     * returns every user not already a member, ordered by first name —
     * used to populate the "add members" picker.
     *
     * @param  int  $groupId  URL param: the group being added to
     * @return \Illuminate\Http\JsonResponse Users as id/name/avatar entries
     */
    public function availableUsers($groupId)
    {
        $users = $this->groupMemberService->availableUsers($groupId);

        return response()->json([
            'success' => true,
            'message' => 'Available users fetched successfully.',
            'data' => [
                'users' => $users,
            ],
            'code' => 200,
        ]);
    }
}
