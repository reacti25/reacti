<?php

namespace App\Http\Requests\Chat;

use App\Http\Requests\ApiFormRequest;
use App\Services\ChatService;

/**
 * Validates a one-to-one chat message edit request.
 *
 * Backs `POST /api/auth/chat/edit/{message_id}`. Only the text is editable;
 * ownership and the edit-time window are enforced in {@see ChatService::editMessage()}.
 */
class EditChatMessageRequest extends ApiFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'text' => 'required|string|max:1000',
        ];
    }
}
