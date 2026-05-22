<?php

namespace App\Http\Requests\Chat;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a delete-single-chat-message request.
 *
 * Backs `DELETE /api/auth/chat/delete/chat/messages`.
 */
class DeleteChatMessageRequest extends ApiFormRequest
{
    /**
     * @return array<string, string>
     */
    public function rules(): array
    {
        return [
            'message_id' => 'required|exists:chats,id',
        ];
    }
}
