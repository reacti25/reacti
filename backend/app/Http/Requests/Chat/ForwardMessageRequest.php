<?php

namespace App\Http\Requests\Chat;

use App\Http\Requests\ApiFormRequest;

/**
 * Validates a forward-message request.
 *
 * Backs `POST /api/auth/chat/forward`. Forwards one source message (a 1:1
 * chat message or a group message) to one or more recipients, each a 1:1 chat
 * (`single`, id = peer user) or a `group` (id = group). Source visibility and
 * per-recipient membership are enforced in the controller.
 */
class ForwardMessageRequest extends ApiFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'message_id' => 'required|integer',
            'source_type' => 'required|in:single,group',
            'recipients' => 'required|array|min:1',
            'recipients.*.type' => 'required|in:single,group',
            'recipients.*.id' => 'required|integer',
        ];
    }
}
