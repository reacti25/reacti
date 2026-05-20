<?php

namespace App\Services;

use App\Events\GroupMessageSendEvent;
use App\Helper\Helper;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\GroupMessageRead;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Business logic for the admin panel's group-chat area.
 *
 * Extracted from {@see \App\Http\Controllers\Web\Backend\AdminGroupChatController}
 * so the controller only resolves the acting admin, applies the soft-failure
 * guard clauses (404/403), and shapes the JSON responses. The service
 * returns plain data (models, collections) or throws for the controller's
 * 500 handler. All DB reads/writes, the create transaction, the file
 * uploads, and the `GroupMessageSendEvent` broadcast are reproduced verbatim
 * from the pre-refactor controller — no behaviour change.
 */
class AdminGroupChatService
{
    /**
     * List every user except the given admin (selectable group members).
     *
     * @param  User  $authUser  The authenticated admin (excluded from results).
     * @return Collection Users ordered by first name ascending.
     */
    public function selectableUsers(User $authUser): Collection
    {
        return User::where('id', '!=', $authUser->id)
            ->select('id', 'first_name', 'last_name', 'email', 'avatar')
            ->orderBy('first_name', 'asc')
            ->get();
    }

    /**
     * Create a new group with the given admin as its admin member.
     *
     * Optionally uploads an avatar (under the `groups` directory), then
     * inside a transaction creates the group, the creator's `admin`
     * membership, and each other selected user's `member` membership (the
     * creator is filtered out of `members` so they are not added twice).
     * On failure the transaction is rolled back, the error logged, and the
     * exception re-thrown for the controller's 500 handler.
     *
     * @param  Request  $request  The incoming request (name, description, avatar, members).
     * @param  User  $authUser  The authenticated admin (group creator).
     * @return Group The created group with `creator` and `members.user` eager-loaded.
     *
     * @throws \Exception on any unexpected transaction failure.
     */
    public function createGroup(Request $request, User $authUser): Group
    {
        // Upload avatar if exists; stored under the `groups` directory.
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

            // Add other members, skipping the creator so they are not
            // inserted twice (they were already added as admin above).
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
            // Any failure rolls back the whole group + membership insert.
            DB::rollBack();
            Log::error('Group creation failed: '.$e->getMessage());
            throw $e;
        }
    }

    /**
     * List every group the given admin belongs to.
     *
     * Each group is enriched with its last message, the admin's unread
     * count, and member count. Supports an optional `keyword` filter on the
     * group name. Any exception is re-thrown for the controller's 500 handler.
     *
     * @param  User  $authUser  The authenticated admin.
     * @param  string|null  $keyword  Optional group-name search term.
     * @return Collection The admin's groups, decorated for the chat list.
     *
     * @throws \Exception on any unexpected failure.
     */
    public function listGroups(User $authUser, $keyword): Collection
    {
        $groupsQuery = Group::whereHas('members', function ($query) use ($authUser) {
            $query->where('user_id', $authUser->id);
        });

        // Narrow the result set to groups whose name matches the search.
        if ($keyword) {
            $groupsQuery->where('name', 'LIKE', "%{$keyword}%");
        }

        $groups = $groupsQuery->with([
            'creator:id,first_name,last_name,avatar',
            'members.user:id,first_name,last_name,avatar,last_activity_at',
            'messages' => function ($query) {
                $query->latest()->first();
            },
        ])->get();

        // Add last message and unread count
        $groups->each(function ($group) use ($authUser) {
            // Get last message
            $lastMessage = $group->messages()->latest()->first();

            if ($lastMessage) {
                $group->last_message = [
                    'id' => $lastMessage->id,
                    'text' => $lastMessage->text,
                    'file' => $lastMessage->file,
                    'created_at' => $lastMessage->created_at->toISOString(),
                    'relative_time' => $lastMessage->created_at->diffForHumans(),
                ];
            } else {
                $group->last_message = null;
            }

            // Unread = messages this user has no read record for and
            // that were not sent by themselves.
            $group->unread_count = $group->messages()
                ->whereDoesntHave('reads', function ($q) use ($authUser) {
                    $q->where('user_id', $authUser->id);
                })
                ->where('sender_id', '!=', $authUser->id)
                ->count();

            $group->member_count = $group->members->count();
        });

        return $groups;
    }

    /**
     * Get full details of a single group.
     *
     * Eager-loads creator and members and decorates the group with
     * `is_admin` and `member_count`. The caller is responsible for
     * confirming the group exists and that the auth user is a member.
     *
     * @param  Group  $group  The group to inspect (already resolved).
     * @param  User  $authUser  The authenticated admin.
     * @return Group The decorated group.
     */
    public function decorateGroupDetails(Group $group, User $authUser): Group
    {
        $group->is_admin = $group->isAdmin($authUser->id);
        $group->member_count = $group->members->count();

        return $group;
    }

    /**
     * Resolve a group with its creator and members eager-loaded.
     *
     * Used by the controller's `groupDetails` action; returns null when no
     * group matches so the controller can emit its 404 payload.
     *
     * @param  int|string  $groupId  The group to load.
     * @return Group|null The group with relations, or null when missing.
     */
    public function findGroupWithDetails($groupId): ?Group
    {
        return Group::with([
            'creator:id,first_name,last_name,avatar,email',
            'members.user:id,first_name,last_name,avatar,email,last_activity_at',
        ])->find($groupId);
    }

    /**
     * Resolve a bare group by id.
     *
     * Used by the controller's guard clauses; returns null when missing so
     * the controller can emit its 404/403 payloads.
     *
     * @param  int|string  $groupId  The group to load.
     * @return Group|null The group, or null when missing.
     */
    public function findGroup($groupId): ?Group
    {
        return Group::find($groupId);
    }

    /**
     * Send a message into a group from the given admin.
     *
     * Stores the message (with optional file upload under `group_chat`),
     * marks it read by the sender, eager-loads the relations, and broadcasts
     * `GroupMessageSendEvent` to the other members. A broadcast failure is
     * logged but does not fail the send. The caller is responsible for
     * confirming the group exists and the sender is a member.
     *
     * @param  Request  $request  The incoming request (text, file).
     * @param  int|string  $groupId  The target group's id.
     * @param  User  $authUser  The authenticated admin (sender).
     * @return GroupMessage The created message with relations loaded.
     */
    public function sendMessage(Request $request, $groupId, User $authUser): GroupMessage
    {
        $file = null;
        if ($request->hasFile('file')) {
            $uploadedFile = $request->file('file');
            $fileName = time().'_group_message.'.$uploadedFile->getClientOriginalExtension();
            $file = Helper::fileUpload($uploadedFile, 'group_chat', $fileName);
        }

        $message = GroupMessage::create([
            'group_id' => $groupId,
            'sender_id' => $authUser->id,
            'text' => $request->text,
            'file' => $file,
        ]);

        // The sender's own message counts as already read by them.
        GroupMessageRead::create([
            'group_message_id' => $message->id,
            'user_id' => $authUser->id,
        ]);

        $message->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'group:id,name,avatar',
        ]);

        // Push the message live to other members; broadcast failure is
        // logged but must not fail the request (the message is saved).
        try {
            broadcast(new GroupMessageSendEvent($message))->toOthers();
            Log::info('Message broadcasted successfully', ['message_id' => $message->id]);
        } catch (\Exception $e) {
            Log::error('Broadcasting failed: '.$e->getMessage());
        }

        return $message;
    }

    /**
     * Get every message in a group, ordered oldest-first.
     *
     * Eager-loads sender and read-receipt data. Any exception is re-thrown
     * for the controller's 500 handler. The caller is responsible for
     * confirming the group exists and the auth user is a member.
     *
     * @param  int|string  $groupId  The group whose messages to load.
     * @return Collection The group's messages.
     *
     * @throws \Exception on any unexpected failure.
     */
    public function getMessages($groupId): Collection
    {
        return GroupMessage::where('group_id', $groupId)
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
                'reads.user:id,first_name,last_name',
            ])
            ->orderBy('created_at', 'asc')
            ->get();
    }

    /**
     * Create read receipts for the admin against every unread group message.
     *
     * Collects messages the admin has no read record for (excluding ones
     * they sent themselves) and inserts a read receipt for each, using
     * `firstOrCreate` to guard against duplicates. The caller is responsible
     * for confirming the group exists and the auth user is a member.
     *
     * @param  int|string  $groupId  The group being opened/read.
     * @param  User  $authUser  The authenticated admin.
     */
    public function markAsRead($groupId, User $authUser): void
    {
        // Collect messages this user has no read record for, excluding ones
        // they sent themselves.
        $unreadMessages = GroupMessage::where('group_id', $groupId)
            ->whereDoesntHave('reads', function ($q) use ($authUser) {
                $q->where('user_id', $authUser->id);
            })
            ->where('sender_id', '!=', $authUser->id)
            ->pluck('id');

        foreach ($unreadMessages as $messageId) {
            // firstOrCreate guards against duplicate read receipts.
            GroupMessageRead::firstOrCreate([
                'group_message_id' => $messageId,
                'user_id' => $authUser->id,
            ]);
        }
    }

    /**
     * Update a group's name, description, and/or avatar.
     *
     * Each field is applied only when present so partial updates work; the
     * description uses `has` so it can be cleared to empty. The new avatar
     * (when present) is uploaded under the `groups` directory. The caller is
     * responsible for confirming the group exists and the auth user is an
     * admin of it.
     *
     * @param  Request  $request  The incoming request (name, description, avatar).
     * @param  Group  $group  The group to update (already resolved).
     * @return Group The updated group.
     */
    public function updateGroup(Request $request, Group $group): Group
    {
        // Apply each field only when present so partial updates work.
        if ($request->name) {
            $group->name = $request->name;
        }

        // `has` (not truthiness) so the description can be cleared to empty.
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

        return $group;
    }

    /**
     * Remove the given admin's membership from a group.
     *
     * The caller is responsible for confirming the group exists and that
     * the auth user is not the creator before calling.
     *
     * @param  int|string  $groupId  The group to leave.
     * @param  User  $authUser  The authenticated admin leaving the group.
     */
    public function leaveGroup($groupId, User $authUser): void
    {
        GroupMember::where('group_id', $groupId)->where('user_id', $authUser->id)->delete();
    }

    /**
     * Permanently delete a group.
     *
     * The caller is responsible for confirming the group exists and that
     * the auth user is its creator before calling.
     *
     * @param  Group  $group  The group to delete (already resolved).
     */
    public function deleteGroup(Group $group): void
    {
        $group->delete();
    }
}
