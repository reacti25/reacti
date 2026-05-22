<?php

namespace App\Http\Requests\Chat;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a one-to-one chat send request.
 *
 * Backs `POST /api/auth/chat/send/{receiver_id}`.
 */
class SendChatMessageRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'text' => 'nullable|string|max:1000',
            // Reject any upload that isn't an image or short video; a
            // .php / .svg with no mime check is stored XSS / RCE.
            'file' => 'nullable|file|mimes:jpg,jpeg,png,gif,mp4,mov,webm|max:51200',
            'message_type' => 'nullable|in:normal,reaction',
            'reply_to_id' => 'nullable|exists:chats,id',
        ];
    }
}
