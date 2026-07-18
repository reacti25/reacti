<?php

namespace App\Http\Requests\Chat;

use App\Http\Requests\ApiFormRequest;
use Illuminate\Validation\Rule;

/**
 * Validates a one-to-one chat send request.
 *
 * Backs `POST /api/auth/chat/send/{receiver_id}`.
 */
class SendChatMessageRequest extends ApiFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $userId = auth('api')->id();
        $receiverId = $this->route('receiver_id');

        return [
            'text' => 'nullable|string|max:1000',
            // Reject any upload that isn't an image or short video; a
            // .php / .svg with no mime check is stored XSS / RCE.
            'file' => 'nullable|file|mimes:jpg,jpeg,png,gif,mp4,mov,webm|max:51200',
            'message_type' => 'nullable|in:normal,reaction',
            // View-once toggle. Accepts 1/0/true/false; only honoured for a
            // normal media send (the service re-gates it).
            'one_time' => 'nullable|boolean',
            // Scope the reply target to THIS conversation: the replied message
            // must be between the auth user and the receiver. Without this an
            // unscoped `exists:chats,id` lets a user reply-to any message id in
            // the table — including conversations they are not part of (IDOR).
            'reply_to_id' => [
                'nullable',
                Rule::exists('chats', 'id')->where(function ($query) use ($userId, $receiverId) {
                    $query->whereIn('sender_id', [$userId, $receiverId])
                        ->whereIn('receiver_id', [$userId, $receiverId]);
                }),
            ],
        ];
    }
}
