<?php

namespace App\Http\Requests\Group;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a group-message send request.
 *
 * Backs `POST /api/auth/group/{group_id}/send`.
 */
class SendGroupMessageRequest extends ApiFormRequest
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
            'reply_to_message_id' => 'nullable|exists:group_messages,id',
        ];
    }
}
