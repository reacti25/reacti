<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Eloquent model for a message posted inside a group chat.
 *
 * Backs the `group_messages` table — the group-chat counterpart of
 * {@see Chat}. Media messages relevant to the patent flow are stored
 * with `is_blurred=true`; per-recipient view/blur state is tracked
 * separately in `GroupMessageUserStatus`. Uses soft deletes.
 */
class GroupMessage extends Model
{
    use HasFactory, SoftDeletes;

    /** Attributes mass-assignable when creating a group message. */
    protected $fillable = [
        'group_id',
        'sender_id',
        'text',
        'file',
        'status',
        'is_blurred',
        'is_viewed',
        'message_type',
        'reply_to_message_id',
        'edited_at',
    ];

    /**
     * Attribute cast definitions.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'edited_at' => 'datetime',
    ];

    /**
     * Relationship: the `Group` this message was posted to.
     *
     * @return BelongsTo
     */
    public function group()
    {
        return $this->belongsTo(Group::class);
    }

    /**
     * Relationship: the `User` who sent this message.
     *
     * @return BelongsTo
     */
    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    /**
     * Relationship: per-user read receipts for this message.
     *
     * @return HasMany
     */
    public function reads()
    {
        return $this->hasMany(GroupMessageRead::class);
    }

    /**
     * Determine whether a specific user has read this message.
     *
     * @param  int  $userId  User to check.
     * @return bool
     */
    public function isReadBy($userId)
    {
        return $this->reads()->where('user_id', $userId)->exists();
    }

    /**
     * Relationship: per-recipient view/blur status rows for this message.
     *
     * Unlike {@see reads()}, this tracks the blur state that drives the
     * patent flow on each member's client.
     *
     * @return HasMany
     */
    public function messageStatus()
    {
        return $this->hasMany(GroupMessageUserStatus::class, 'message_id');
    }

    /**
     * Relationship: the `GroupMessage` this one is a reply to.
     */
    public function replyTo(): BelongsTo
    {
        return $this->belongsTo(GroupMessage::class, 'reply_to_message_id');
    }

    /**
     * Relationship: every `GroupMessage` that replies to this one.
     */
    public function replies(): HasMany
    {
        return $this->hasMany(GroupMessage::class, 'reply_to_message_id');
    }

    // public function currentUserStatus()
    // {
    //     return $this->hasOne(GroupMessageUserStatus::class, 'message_id');
    // }
}
