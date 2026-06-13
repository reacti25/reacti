<?php

namespace App\Http\Requests\Group;

use App\Http\Requests\ApiFormRequest;
use Illuminate\Validation\Rule;

/**
 * Validates a group-message send request.
 *
 * Backs `POST /api/auth/group/{group_id}/send`.
 */
class SendGroupMessageRequest extends ApiFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $groupId = $this->route('group_id');

        return [
            'text' => 'nullable|string|max:1000',
            // Reject any upload that isn't an image or short video; a
            // .php / .svg with no mime check is stored XSS / RCE.
            'file' => 'nullable|file|mimes:jpg,jpeg,png,gif,mp4,mov,webm|max:51200',
            'message_type' => 'nullable|in:normal,reaction',
            // Scope the reply target to THIS group: the replied message must
            // belong to the group being posted to. Without this an unscoped
            // `exists:group_messages,id` lets a member reply-to a message in a
            // different group (IDOR). Group membership itself is enforced by
            // the controller's not-a-member guard.
            'reply_to_message_id' => [
                'nullable',
                Rule::exists('group_messages', 'id')->where('group_id', $groupId),
            ],
        ];
    }
}
