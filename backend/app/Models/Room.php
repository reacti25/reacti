<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Eloquent model for a 1:1 conversation room between two users.
 *
 * Backs the `rooms` table. A room is the container that groups all
 * `Chat` messages exchanged between `user_one_id` and `user_two_id`;
 * exactly one room exists per pair of users.
 */
class Room extends Model
{
    use HasFactory;

    /** Attributes mass-assignable when creating a room. */
    protected $fillable = ['user_one_id', 'user_two_id'];

    /**
     * Attribute cast definitions.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'user_one_id' => 'integer',
        'user_two_id' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Relationship: the first participant (`user_one_id`).
     */
    public function userOne(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_one_id');
    }

    /**
     * Relationship: the second participant (`user_two_id`).
     */
    public function userTwo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_two_id');
    }

    /**
     * Relationship: every `Chat` message exchanged in this room.
     */
    public function chats(): HasMany
    {
        return $this->hasMany(Chat::class, 'room_id');
    }

    /**
     * Resolve the participant who is not the given user.
     *
     * Used to render the "other person" in a 1:1 conversation.
     *
     * @param  int  $currentUserId  The viewing user.
     * @return User|null The other participant.
     */
    public function getOtherUser($currentUserId)
    {
        if ($this->user_one_id == $currentUserId) {
            return $this->userTwo;
        }

        return $this->userOne;
    }

    /**
     * Determine whether a user is one of the room's two participants.
     *
     * @param  int  $userId  User to check.
     */
    public function hasUser($userId): bool
    {
        return $this->user_one_id == $userId || $this->user_two_id == $userId;
    }

    /**
     * Relationship: the most recent `Chat` message in this room.
     *
     * Used to render the conversation preview in chat-list views.
     *
     * @return \Illuminate\Database\Eloquent\Relations\HasOne
     */
    public function lastMessage()
    {
        return $this->hasOne(Chat::class, 'room_id')->latest();
    }

    /**
     * Count messages in this room the given user has not yet read.
     *
     * @param  int  $userId  The recipient whose unread count is wanted.
     */
    public function unreadCountFor($userId): int
    {
        return $this->chats()
            ->where('receiver_id', $userId)
            ->where('status', '!=', 'read')
            ->count();
    }

    /**
     * Query scope for every room a given user participates in,
     * on either side of the conversation.
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @param  int  $userId  The participant.
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeForUser($query, $userId)
    {
        return $query->where('user_one_id', $userId)
            ->orWhere('user_two_id', $userId);
    }

    /**
     * Query scope for the unique room shared by two users.
     *
     * The user IDs are normalised (min into `user_one_id`, max into
     * `user_two_id`) so a single deterministic lookup matches the room
     * regardless of argument order.
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @param  int  $userId1  One participant.
     * @param  int  $userId2  The other participant.
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeBetweenUsers($query, $userId1, $userId2)
    {
        $minId = min($userId1, $userId2);
        $maxId = max($userId1, $userId2);

        return $query->where('user_one_id', $minId)
            ->where('user_two_id', $maxId);
    }
}
