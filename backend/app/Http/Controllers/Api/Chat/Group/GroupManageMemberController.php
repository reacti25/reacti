<?php

namespace App\Http\Controllers\Api\Chat\Group;

use App\Models\User;
use App\Models\Group;
use App\Models\GroupMember;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;
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
 */
class GroupManageMemberController extends Controller
{
    /**
     * Add one or more members to a group (admin only).
     *
     * Users already in the group are silently skipped; only the newly
     * added user ids are returned.
     *
     * @param  Request  $request   Body: members (array of user ids)
     * @param  int      $group_id  URL param: the target group
     * @return JsonResponse  Added member ids, 404 if group missing,
     *                       403 if the caller is not an admin, 422 on validation
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

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (!$group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can add members', 'code' => 403], 403);
        }

        $addedMembers = [];
        foreach ($request->members as $memberId) {
            if (!$group->isMember($memberId)) {
                GroupMember::create([
                    'group_id' => $group_id,
                    'user_id' => $memberId,
                    'role' => 'member'
                ]);
                $addedMembers[] = $memberId;
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Members added successfully',
            'data' => ['added_members' => $addedMembers],
            'code' => 200
        ]);
    }

    /**
     * Remove a member from a group (admin only).
     *
     * The group creator can never be removed, even by another admin.
     *
     * @param  int  $group_id  URL param: the target group
     * @param  int  $user_id   URL param: the member to remove
     * @return JsonResponse  Success, 404 if group missing,
     *                       403 if caller is not admin or target is the creator
     */
    public function removeMember($group_id, $user_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (!$group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can remove members', 'code' => 403], 403);
        }

        // Cannot remove creator
        if ($user_id == $group->created_by) {
            return response()->json(['success' => false, 'message' => 'Cannot remove group creator', 'code' => 403], 403);
        }

        GroupMember::where('group_id', $group_id)->where('user_id', $user_id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Member removed successfully',
            'code' => 200
        ]);
    }

    /**
     * Promote an existing member to admin (admin only).
     *
     * @param  int  $group_id  URL param: the target group
     * @param  int  $user_id   URL param: the member to promote
     * @return JsonResponse  Success, 404 if group missing or user is not
     *                       a member, 403 if the caller is not an admin
     */
    public function makeAdmin($group_id, $user_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if (!$group->isAdmin($authUser->id)) {
            return response()->json(['success' => false, 'message' => 'Only admins can promote members', 'code' => 403], 403);
        }

        $member = GroupMember::where('group_id', $group_id)->where('user_id', $user_id)->first();

        if (!$member) {
            return response()->json(['success' => false, 'message' => 'User is not a member', 'code' => 404], 404);
        }

        $member->update(['role' => 'admin']);

        return response()->json([
            'success' => true,
            'message' => 'Member promoted to admin',
            'code' => 200
        ]);
    }

    /**
     * Demote a group admin back to a regular member (admin only).
     *
     * The group owner (creator) can never be demoted. The target must
     * currently hold the `admin` role, otherwise the request is a no-op
     * 400.
     *
     * @param  int  $group_id  URL param: the target group
     * @param  int  $user_id   URL param: the admin to demote
     * @return JsonResponse  Success, 404 if group/member missing,
     *                       403 if caller not admin or target is owner,
     *                       400 if the target is not actually an admin
     */
    public function removeAdmin($group_id, $user_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        // Check if group exists
        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // Only admins can demote others
        if (!$group->isAdmin($authUser->id)) {
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

        if (!$member) {
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
        $member->update(['role' => 'member']);

        return response()->json([
            'success' => true,
            'message' => 'Admin demoted to member successfully',
            'code' => 200
        ]);
    }

    /**
     * Remove the authenticated user from a group.
     *
     * The creator cannot leave their own group — they must delete it
     * instead.
     *
     * @param  int  $group_id  URL param: the group to leave
     * @return JsonResponse  Success, 404 if group missing,
     *                       403 if the caller is the group creator
     */
    public function leaveGroup($group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        // Creator cannot leave, must delete group
        if ($authUser->id == $group->created_by) {
            return response()->json(['success' => false, 'message' => 'Group creator cannot leave. Delete the group instead.', 'code' => 403], 403);
        }

        GroupMember::where('group_id', $group_id)->where('user_id', $authUser->id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Left group successfully',
            'code' => 200
        ]);
    }

    /**
     * Delete a group entirely (creator only).
     *
     * Only the original creator may delete the group — even other
     * admins are rejected with 403.
     *
     * @param  int  $group_id  URL param: the group to delete
     * @return JsonResponse  Success, 404 if group missing,
     *                       403 if the caller is not the creator
     */
    public function deleteGroup($group_id): JsonResponse
    {
        $authUser = Auth::guard('api')->user();
        $group = Group::find($group_id);

        if (!$group) {
            return response()->json(['success' => false, 'message' => 'Group not found', 'code' => 404], 404);
        }

        if ($authUser->id != $group->created_by) {
            return response()->json(['success' => false, 'message' => 'Only group creator can delete the group', 'code' => 403], 403);
        }

        $group->delete();

        return response()->json([
            'success' => true,
            'message' => 'Group deleted successfully',
            'code' => 200
        ]);
    }

    /**
     * List users not yet in a group (candidates to add).
     *
     * Returns every user whose id is not already a member, ordered by
     * first name — used to populate the "add members" picker.
     *
     * @param  int  $groupId  URL param: the group being added to
     * @return \Illuminate\Http\JsonResponse  Users as id/name/avatar entries
     */
    public function availableUsers($groupId)
    {
        // All users already in the group
        $existingUserIds = DB::table('group_members')
            ->where('group_id', $groupId)
            ->pluck('user_id');

        // Users NOT in the group
        $users = User::whereNotIn('id', $existingUserIds)
            ->select('id', 'first_name', 'last_name', 'avatar')
            ->orderBy('first_name')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Available users fetched successfully.',
            'data' => [
                'users' => $users->map(function ($user) {
                    return [
                        'id' => $user->id,
                        'name' => $user->first_name . ' ' . $user->last_name,
                        'avatar' => $user->avatar
                    ];
                })
            ],
            'code' => 200
        ]);
    }
}
