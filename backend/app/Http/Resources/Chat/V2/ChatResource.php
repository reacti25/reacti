<?php

namespace App\Http\Resources\Chat\V2;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single 1:1 `Chat` message (V2).
 *
 * The V2 variant of `App\Http\Resources\ChatResource`. Adds `file_type`,
 * `thumbnail`, `forwarded_from`/`forwarded_from_user` and an ISO-8601
 * `created_at`. Unlike `ChatMessageResource` (V2) it omits the
 * `is_my_text`/`should_show_blur` computed flags. Returned by the V2
 * direct-chat controllers.
 */
class ChatResource extends JsonResource
{
    /**
     * Transform the chat message into the V2 API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed>  Array with keys:
     *                               - `id`, `sender_id`, `receiver_id`, `room_id`
     *                               - `text`, `file`, `file_type`, `thumbnail`, `status`
     *                               - `is_blurred`/`is_viewed`: blur-flow state
     *                               - `message_type`, `reply_to_id`, `forwarded_from`
     *                               - `humanize_date`: relative created time
     *                               - `short_text`, `type`, `media_type`
     *                               - `created_at`: ISO-8601 timestamp
     *                               - `sender`/`receiver`: nested user profiles
     *                               - `room`: room id and both participant ids
     *                               - `reply_to`: nested replied message (only when present)
     *                               - `forwarded_from_user`: original sender (only when present)
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'sender_id' => $this->sender_id,
            'receiver_id' => $this->receiver_id,
            'room_id' => $this->room_id,
            'text' => $this->text,
            'file' => $this->file,
            'file_type' => $this->file_type,
            'thumbnail' => $this->thumbnail,
            'status' => $this->status,
            'is_blurred' => $this->is_blurred,
            'is_viewed' => $this->is_viewed,
            'message_type' => $this->message_type,
            'reply_to_id' => $this->reply_to_id,
            'forwarded_from' => $this->forwarded_from,
            'humanize_date' => $this->created_at->diffForHumans(),
            'short_text' => $this->short_text,
            'type' => $this->type,
            'media_type' => $this->media_type,
            'created_at' => $this->created_at->toISOString(),

            // Sender info
            'sender' => [
                'id' => $this->sender->id,
                'first_name' => $this->sender->first_name,
                'last_name' => $this->sender->last_name,
                'avatar' => $this->sender->avatar,
                'last_activity_at' => $this->sender->last_activity_at,
            ],

            // Receiver info
            'receiver' => [
                'id' => $this->receiver->id,
                'first_name' => $this->receiver->first_name,
                'last_name' => $this->receiver->last_name,
                'avatar' => $this->receiver->avatar,
                'last_activity_at' => $this->receiver->last_activity_at,
            ],

            // Room info
            'room' => [
                'id' => $this->room->id,
                'user_one_id' => $this->room->user_one_id,
                'user_two_id' => $this->room->user_two_id,
            ],

            // Reply-to message — only emitted when a replyTo record exists.
            'reply_to' => $this->when($this->replyTo, function () {
                return [
                    'id' => $this->replyTo->id,
                    'sender_id' => $this->replyTo->sender_id,
                    'text' => $this->replyTo->text,
                    'file' => $this->replyTo->file,
                    'file_type' => $this->replyTo->file_type,
                ];
            }),

            // Forwarded-from user — only emitted for forwarded messages.
            'forwarded_from_user' => $this->when($this->forwardedFromUser, function () {
                return [
                    'id' => $this->forwardedFromUser->id,
                    'first_name' => $this->forwardedFromUser->first_name,
                    'last_name' => $this->forwardedFromUser->last_name,
                ];
            }),
        ];
    }
}
