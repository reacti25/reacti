<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Eloquent model for an accepted friendship between two users.
 *
 * Backs the `friends` pivot table. A friendship is stored as a single
 * directed row (`user_id` -> `friend_id`); the `User::friends()` query
 * unions both directions so the relationship reads as mutual.
 */
class Friend extends Model
{
    /** Attributes mass-assignable when recording a friendship. */
    protected $fillable = [
        'user_id',
        'friend_id',
        'became_friends_at',
    ];

    /**
     * Relationship: the `User` on the `friend_id` side of the pair.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function friendUser()
    {
        return $this->belongsTo(User::class, 'friend_id');
    }

    /**
     * Relationship: the `User` on the `user_id` (owning) side of the pair.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
