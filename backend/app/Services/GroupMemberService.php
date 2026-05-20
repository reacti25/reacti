<?php

namespace App\Services;

use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Business logic for group membership and roles.
 *
 * Extracted from {@see \App\Http\Controllers\Api\Chat\Group\GroupManageMemberController}
 * so the controller only validates input, applies the soft-failure guard
 * clauses (group missing, not an admin, creator protections), and shapes
 * the JSON response. All DB writes are reproduced verbatim from the
 * pre-refactor controller — no behaviour change.
 */
class GroupMemberService
{
    /**
     * Add one or more members to a group.
     *
     * Users already in the group are silently skipped; only the newly
     * added user ids are returned. The caller is responsible for
     * confirming the group exists and that the auth user is an admin
     * before invoking this method.
     *
     * @param  Group  $group  The target group.
     * @param  array  $memberIds  User ids to add as `member`.
     * @return array The ids of the members that were actually added.
     */
    public function addMembers(Group $group, array $memberIds): array
    {
        $addedMembers = [];
        foreach ($memberIds as $memberId) {
            if (! $group->isMember($memberId)) {
                GroupMember::create([
                    'group_id' => $group->id,
                    'user_id' => $memberId,
                    'role' => 'member',
                ]);
                $addedMembers[] = $memberId;
            }
        }

        return $addedMembers;
    }

    /**
     * Remove a member from a group.
     *
     * The caller is responsible for confirming the group exists, that the
     * auth user is an admin, and that the target is not the group creator
     * before invoking this method.
     *
     * @param  int  $group_id  The target group.
     * @param  int  $user_id  The member to remove.
     */
    public function removeMember($group_id, $user_id): void
    {
        GroupMember::where('group_id', $group_id)->where('user_id', $user_id)->delete();
    }

    /**
     * Promote an existing member to admin.
     *
     * The caller is responsible for confirming the group exists and that
     * the auth user is an admin before invoking this method.
     *
     * @param  GroupMember  $member  The membership row to promote.
     */
    public function makeAdmin(GroupMember $member): void
    {
        $member->update(['role' => 'admin']);
    }

    /**
     * Demote a group admin back to a regular member.
     *
     * The caller is responsible for confirming the group exists, that the
     * auth user is an admin, that the target is not the owner, and that
     * the target currently holds the `admin` role before invoking this
     * method.
     *
     * @param  GroupMember  $member  The membership row to demote.
     */
    public function removeAdmin(GroupMember $member): void
    {
        $member->update(['role' => 'member']);
    }

    /**
     * Remove the authenticated user from a group.
     *
     * The caller is responsible for confirming the group exists and that
     * the auth user is not the group creator before invoking this method.
     *
     * @param  int  $group_id  The group to leave.
     * @param  int  $user_id  The authenticated user's id.
     */
    public function leaveGroup($group_id, $user_id): void
    {
        GroupMember::where('group_id', $group_id)->where('user_id', $user_id)->delete();
    }

    /**
     * Delete a group entirely.
     *
     * The caller is responsible for confirming the group exists and that
     * the auth user is the group creator before invoking this method.
     *
     * @param  Group  $group  The group to delete.
     */
    public function deleteGroup(Group $group): void
    {
        $group->delete();
    }

    /**
     * List users not yet in a group (candidates to add).
     *
     * Returns every user whose id is not already a member, ordered by
     * first name — used to populate the "add members" picker.
     *
     * @param  int  $groupId  The group being added to.
     * @return Collection Users mapped to id/name/avatar entries.
     */
    public function availableUsers($groupId): Collection
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

        return $users->map(function ($user) {
            return [
                'id' => $user->id,
                'name' => $user->first_name.' '.$user->last_name,
                'avatar' => $user->avatar,
            ];
        });
    }
}
