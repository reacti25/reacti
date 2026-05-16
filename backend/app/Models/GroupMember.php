<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

/**
 * Eloquent model for a single membership in a group chat.
 *
 * Backs the `group_members` pivot table, linking a `User` to a `Group`
 * together with that user's `role` (e.g. admin/member) and the time
 * they joined.
 */
class GroupMember extends Model
{
    use HasFactory;

    /** Attributes mass-assignable when adding a member to a group. */
    protected $fillable = [
        'group_id',
        'user_id',
        'role',
        'joined_at'
    ];

    /**
     * Attribute cast definitions.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'joined_at' => 'datetime',
    ];

    /**
     * Relationship: the `Group` this membership belongs to.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function group()
    {
        return $this->belongsTo(Group::class);
    }

    /**
     * Relationship: the `User` this membership represents.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
