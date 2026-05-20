<?php

namespace App\Services;

use App\Events\GroupUpdatedEvent;
use App\Exceptions\ApiException;
use App\Helper\Helper;
use App\Http\Controllers\Api\Chat\Group\GroupCreateController;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Business logic for group lifecycle and group metadata.
 *
 * Extracted from {@see GroupCreateController}
 * so the controller only validates input, applies soft-failure guard
 * clauses, and shapes the JSON response. All DB writes, the create
 * transaction, the avatar uploads via {@see Helper}, and the
 * `GroupUpdatedEvent` broadcasts are reproduced verbatim from the
 * pre-refactor controller — no behaviour change.
 */
class GroupService
{
    /**
     * Create a new group with the auth user as admin.
     *
     * Uploads the optional avatar via {@see Helper::fileUpload()} before
     * the transaction. Inside the transaction the group, the creator's
     * `admin` membership, and each other member's `member` membership are
     * written together (the creator id is filtered out of `members` so it
     * is not added twice). On failure the transaction is rolled back, the
     * error logged, and the exception re-thrown for the controller's 500
     * handler.
     *
     * @param  Request  $request  The incoming request (name, description, avatar, members).
     * @param  User  $authUser  The authenticated user (group creator/admin).
     * @return Group The created group with `creator` and `members.user` eager-loaded.
     *
     * @throws \Exception on any unexpected transaction failure.
     */
    public function createGroup(Request $request, User $authUser): Group
    {
        // Upload avatar if exists
        $avatar = null;
        if ($request->hasFile('avatar')) {
            $file = $request->file('avatar');
            $fileName = time().'_group_avatar.'.$file->getClientOriginalExtension();
            $avatar = Helper::fileUpload($file, 'groups', $fileName);
        }

        DB::beginTransaction();
        try {
            // Create group
            $group = Group::create([
                'name' => $request->name,
                'description' => $request->description,
                'avatar' => $avatar,
                'created_by' => $authUser->id,
            ]);

            // Add creator as admin
            GroupMember::create([
                'group_id' => $group->id,
                'user_id' => $authUser->id,
                'role' => 'admin',
            ]);

            // Add other members
            $members = array_filter($request->members, fn ($id) => $id != $authUser->id);
            foreach ($members as $memberId) {
                GroupMember::create([
                    'group_id' => $group->id,
                    'user_id' => $memberId,
                    'role' => 'member',
                ]);
            }

            DB::commit();

            $group->load(['creator:id,first_name,last_name,avatar', 'members.user:id,first_name,last_name,avatar,last_activity_at']);

            return $group;
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Group creation failed: '.$e->getMessage());
            throw $e;
        }
    }

    /**
     * List every group the authenticated user belongs to.
     *
     * Each group is decorated with its last message, the auth user's
     * unread count, and member count for the chat-list UI.
     *
     * @param  User  $authUser  The authenticated user.
     * @param  string|null  $keyword  Optional name filter.
     * @return Collection The auth user's groups, decorated for the chat list.
     */
    public function listGroups(User $authUser, $keyword): Collection
    {
        $groupsQuery = Group::whereHas('members', function ($query) use ($authUser) {
            $query->where('user_id', $authUser->id);
        });

        if ($keyword) {
            $groupsQuery->where('name', 'LIKE', "%{$keyword}%");
        }

        $groups = $groupsQuery->with([
            'creator:id,first_name,last_name,avatar',
            'members.user:id,first_name,last_name,avatar,last_activity_at',
        ])->get();

        // Add last message and unread count
        $groups->map(function ($group) use ($authUser) {
            $group->last_message = $group->messages()->latest()->first();
            $group->unread_count = $group->messages()
                ->whereDoesntHave('reads', function ($q) use ($authUser) {
                    $q->where('user_id', $authUser->id);
                })
                ->where('sender_id', '!=', $authUser->id)
                ->count();
            $group->member_count = $group->members->count();

            return $group;
        });

        return $groups;
    }

    /**
     * Get full details of a single group.
     *
     * Only members may view a group. When the group is missing an
     * {@see ApiException} with status 404 is thrown; when the caller is not
     * a member one with status 403 is thrown — preserving the distinct
     * status codes and messages of the pre-refactor controller. On success
     * the group is decorated with `is_admin`, `member_count`, and (when set)
     * an absolute `avatar_url`.
     *
     * @param  int  $group_id  The group to inspect.
     * @param  User  $authUser  The authenticated user.
     * @return Group The decorated group.
     *
     * @throws ApiException 404 when the group is missing, 403 when the
     *                      caller is not a member of the group.
     */
    public function groupDetails($group_id, User $authUser): Group
    {
        $group = Group::with([
            'creator:id,first_name,last_name,avatar,email',
            'members.user:id,first_name,last_name,avatar,email,last_activity_at',
        ])->find($group_id);

        if (! $group) {
            throw new ApiException('Group not found', 404);
        }

        // Check if user is member
        if (! $group->isMember($authUser->id)) {
            throw new ApiException('You are not a member of this group', 403);
        }

        $group->is_admin = $group->isAdmin($authUser->id);
        $group->member_count = $group->members->count();

        // Add full path for avatar
        if ($group->avatar) {
            $group->avatar_url = url('/'.$group->avatar);
        }

        return $group;
    }

    /**
     * Update group info — name, description, and/or avatar.
     *
     * Each field is nullable, so callers can update one field at a time.
     * The new avatar (when present) is uploaded via {@see Helper}. After
     * persistence, broadcasts `GroupUpdatedEvent($group_id, 'info', $data)`
     * with the new fields plus the admin who made the change so listening
     * clients re-render the group header without polling.
     *
     * The caller is responsible for confirming the group exists and that
     * the auth user is an admin before invoking this method.
     *
     * @param  Request  $request  The incoming request (name, description, avatar).
     * @param  Group  $group  The group to update.
     * @param  User  $authUser  The authenticated admin making the change.
     * @return Group The updated group.
     */
    public function updateGroup(Request $request, Group $group, User $authUser): Group
    {
        if ($request->name) {
            $group->name = $request->name;
        }

        if ($request->has('description')) {
            $group->description = $request->description;
        }

        if ($request->hasFile('avatar')) {
            $file = $request->file('avatar');
            $fileName = time().'_group_avatar.'.$file->getClientOriginalExtension();
            $avatar = Helper::fileUpload($file, 'groups', $fileName);
            $group->avatar = $avatar;
        }

        $group->save();

        broadcast(new GroupUpdatedEvent(
            roomId: $group->id,
            updateType: 'info',
            data: [
                'group_id' => $group->id,
                'name' => $group->name,
                'description' => $group->description,
                'avatar' => $group->avatar,
                'updated_by' => $authUser->id,
            ],
        ))->toOthers();

        return $group;
    }

    /**
     * Replace a group's avatar image.
     *
     * Uploads the new file via {@see Helper}, deletes the old avatar file
     * from disk if one was set, then updates the `groups.avatar` column.
     * On success broadcasts `GroupUpdatedEvent($group_id, 'avatar', $data)`
     * so listening clients refresh the avatar without polling.
     *
     * The upload/broadcast only runs when the request actually carries an
     * `avatar` file, exactly as the pre-refactor controller did.
     *
     * The caller is responsible for confirming the group exists and that
     * the auth user is an admin before invoking this method.
     *
     * @param  Request  $request  The incoming request (avatar file).
     * @param  Group  $group  The group whose avatar to replace.
     * @param  User  $authUser  The authenticated admin making the change.
     * @return Group The group (avatar updated when a file was present).
     */
    public function updateAvatar(Request $request, Group $group, User $authUser): Group
    {
        // Upload new avatar
        if ($request->hasFile('avatar')) {
            $file = $request->file('avatar');
            $fileName = time().'_group_avatar.'.$file->getClientOriginalExtension();
            $newAvatar = Helper::fileUpload($file, 'groups', $fileName);

            // Delete old avatar if exists
            if (! empty($group->avatar)) {
                Helper::fileDelete($group->avatar);
            }

            // Update database
            $group->update(['avatar' => $newAvatar]);

            broadcast(new GroupUpdatedEvent(
                roomId: $group->id,
                updateType: 'avatar',
                data: [
                    'group_id' => $group->id,
                    'avatar' => $group->avatar,
                    'updated_by' => $authUser->id,
                ],
            ))->toOthers();
        }

        return $group;
    }
}
