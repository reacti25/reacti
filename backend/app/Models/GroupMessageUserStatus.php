<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Eloquent model for a recipient's per-message view/blur state.
 *
 * Backs the `group_message_user_statuses` table. Because a group
 * message reaches many members, each member needs an independent
 * `is_viewed` / `is_blurred` flag — this row holds that state and is
 * what the patent blur/unblur flow reads and updates for group chats.
 */
class GroupMessageUserStatus extends Model
{
    /** Attributes mass-assignable when tracking per-user message state. */
    protected $fillable = [
        'message_id',
        'user_id',
        'is_viewed',
        'is_blurred',
    ];

    /**
     * Relationship: the `GroupMessage` this status row refers to.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function message()
    {
        return $this->belongsTo(GroupMessage::class);
    }

    /**
     * Relationship: the `User` whose view/blur state this row tracks.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
