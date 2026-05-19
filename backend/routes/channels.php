<?php

use App\Models\Room;
use Illuminate\Support\Facades\Broadcast;

/*
 * Single Chat Channels
 *
 * Authorisation callbacks intentionally do NOT log on success — every
 * websocket subscription is a successful auth attempt in normal use,
 * so logging each one floods logs and (when the payload included
 * `user_email`) wrote PII to disk. Errors surface through the
 * Broadcasting framework's own logging.
 */

Broadcast::channel('chat-room.{room_id}', function ($user, $room_id) {
    $room = Room::find($room_id);
    return (int) $user->id === (int) $room?->user_one_id || (int) $user->id === (int) $room?->user_two_id;
});

Broadcast::channel('chat-receiver.{receiver_id}', function ($user, $receiver_id) {
    return (int) $user->id === (int) $receiver_id;
});

Broadcast::channel('chat-sender.{sender_id}', function ($user, $sender_id) {
    return (int) $user->id === (int) $sender_id;
});

/*
 * Group Chat Channel
 */
Broadcast::channel('group-message.{userId}', function ($user, $userId) {
    if ((int) $user->id !== (int) $userId) {
        return false;
    }

    // Returning user data (not just true) makes the subscriber's
    // presence info available to other listeners.
    return ['id' => $user->id, 'name' => $user->first_name];
});

/*
 * Notification Channels
 */
Broadcast::channel('notify.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

Broadcast::channel('test-notify.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});
