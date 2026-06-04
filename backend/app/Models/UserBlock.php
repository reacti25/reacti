<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Eloquent model for a user-to-user block.
 *
 * Backs the `user_blocks` table. `user_id` is the user who created the
 * block and `block_user_id` is the user who has been blocked, used to
 * suppress chats and contact between the two.
 */
class UserBlock extends Model
{
    /** Attributes mass-assignable when creating a block. */
    protected $fillable = [
        'user_id',
        'block_user_id',
    ];

    /**
     * Relationship: the `User` who has been blocked.
     *
     * @return BelongsTo
     */
    public function blockedUser()
    {
        return $this->belongsTo(User::class, 'block_user_id');
    }
}
