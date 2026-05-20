<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Eloquent model for a pending or resolved friend request.
 *
 * Backs the `friend_requests` table. A request moves through `status`
 * states (e.g. pending -> accepted); once accepted a corresponding
 * `Friend` row is created and `accepted_at` is stamped.
 */
class FriendRequest extends Model
{
    use HasFactory;

    /** Attributes mass-assignable when creating or updating a request. */
    protected $fillable = [
        'sender_id',
        'receiver_id',
        'status',
        'accepted_at',
    ];

    /**
     * Relationship: the `User` who initiated the friend request.
     *
     * @return BelongsTo
     */
    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    /**
     * Relationship: the `User` the friend request was sent to.
     *
     * @return BelongsTo
     */
    public function receiver()
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }
}
