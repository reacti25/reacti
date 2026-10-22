<?php

namespace App\Http\Resources\Group;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a group message including its full per-user status set.
 *
 * Serializes a `GroupMessage` with its sender and group, plus the complete
 * `messageStatus` collection — every recipient's `is_viewed`/`is_blurred`
 * row. Unlike `MessageResource` (which collapses status to the viewer's
 * own state), this resource exposes per-member delivery state and is used
 * where the full status breakdown is needed.
 */
class GroupMessageFormatResource extends JsonResource
{
    /**
     * Serialize the group message into the API response array.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `id`, `group_id`, `sender_id`
     *                              - `text`, `file` (absolute URL), `status`
     *                              - `is_blurred`/`is_viewed`: message-level flags (bool)
     *                              - `message_type`: normal vs reaction (default `normal`)
     *                              - `created_at`: relative timestamp
     *                              - `sender`: nested sender profile
     *                              - `group`: nested group (id, name, avatar)
     *                              - `message_status`: list of per-user status rows
     *                              (id, message_id, user_id, is_viewed, is_blurred,
     *                              created_at, updated_at)
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'group_id' => (int) $this->group_id,
            'sender_id' => (int) $this->sender_id,
            'text' => $this->text,
            'file' => $this->file ? asset($this->file) : null,
            'status' => $this->status,
            'is_blurred' => (bool) $this->is_blurred,
            'is_viewed' => (bool) $this->is_viewed,
            'message_type' => $this->message_type ?? 'normal',
            // React-to-unlock (Feature 6): whether the viewer has unlocked this
            // original's reactions, and how many are still hidden ("N waiting").
            // Additive — old clients ignore them. getAttribute (not the magic
            // property) so static analysis doesn't flag an undefined property.
            'viewer_has_reacted' => (bool) $this->resource->getAttribute('viewer_has_reacted'),
            'reactions_waiting' => (int) $this->resource->getAttribute('reactions_waiting'),
            'created_at' => $this->created_at?->diffForHumans(),

            'sender' => [
                'id' => $this->sender->id ?? null,
                'first_name' => $this->sender->first_name ?? null,
                'last_name' => $this->sender->last_name ?? null,
                'avatar' => isset($this->sender->avatar) && $this->sender->avatar ?
                    asset($this->sender->avatar) : asset('default/default_image.jpg'),
            ],

            'group' => [
                'id' => $this->group->id ?? null,
                'name' => $this->group->name ?? null,
                'avatar' => isset($this->group->avatar) && $this->group->avatar ?
                    asset($this->group->avatar) : asset('default/default_image.jpg'),
            ],

            // Adding statuses — per-recipient view/blur breakdown for this message.
            'message_status' => $this->messageStatus->map(function ($status) {
                return [
                    'id' => $status->id,
                    'message_id' => $status->message_id,
                    'user_id' => $status->user_id,
                    'is_viewed' => (bool) $status->is_viewed,
                    'is_blurred' => (bool) $status->is_blurred,
                    'created_at' => $status->created_at->diffForHumans(),
                    'updated_at' => $status->updated_at->diffForHumans,
                ];
            }),
        ];
    }
}
