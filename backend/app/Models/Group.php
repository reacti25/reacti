<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Eloquent model for a group chat.
 *
 * Backs the `groups` table. A group has a creator/owner, a roster of
 * members (with per-member roles via the `group_members` pivot) and a
 * stream of `GroupMessage` records. Uses soft deletes so a removed
 * group's history remains referable.
 */
class Group extends Model
{
    use HasFactory, SoftDeletes;

    /** Attributes mass-assignable when creating or editing a group. */
    protected $fillable = [
        'name',
        'description',
        'avatar',
        'created_by',
    ];

    /**
     * Attribute cast definitions.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Relationship: the `User` who created and owns the group.
     *
     * @return BelongsTo
     */
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * Relationship: every `GroupMember` roster row for this group.
     *
     * @return HasMany
     */
    public function members()
    {
        return $this->hasMany(GroupMember::class);
    }

    /**
     * Relationship: the member `User`s, with their pivot role and
     * join timestamp exposed for convenience.
     *
     * @return BelongsToMany
     */
    public function users()
    {
        return $this->belongsToMany(User::class, 'group_members', 'group_id', 'user_id')
            ->withPivot('role', 'joined_at')
            ->withTimestamps();
    }

    /**
     * Relationship: every `GroupMessage` posted to this group.
     *
     * @return HasMany
     */
    public function messages()
    {
        return $this->hasMany(GroupMessage::class);
    }

    /**
     * Relationship: the subset of `GroupMember` rows with the admin role.
     *
     * @return HasMany
     */
    public function admins()
    {
        return $this->hasMany(GroupMember::class)->where('role', 'admin');
    }

    /**
     * Determine whether a user is an admin of this group.
     *
     * @param  int  $userId  User to check.
     * @return bool
     */
    public function isAdmin($userId)
    {
        return $this->members()->where('user_id', $userId)->where('role', 'admin')->exists();
    }

    /**
     * Determine whether a user belongs to this group at all.
     *
     * @param  int  $userId  User to check.
     * @return bool
     */
    public function isMember($userId)
    {
        return $this->members()->where('user_id', $userId)->exists();
    }

    /**
     * Determine whether a user is the group's creator/owner.
     *
     * @param  int  $userId  User to check.
     * @return bool
     */
    public function isOwner($userId)
    {
        return $this->created_by == $userId;
    }
}
