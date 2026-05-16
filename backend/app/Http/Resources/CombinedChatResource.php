<?php

namespace App\Http\Resources;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single entry in the unified chat list (V1).
 *
 * Represents either a direct chat or a group chat as a uniform list item.
 * The underlying resource may be a raw query-result array or an object;
 * both are normalized. Used as the item resource inside
 * `CombinedChatCollection`.
 */
class CombinedChatResource extends JsonResource
{
    /**
     * Serialize one unified chat-list entry into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed>  Array with keys:
     *                               - `type`: `chat` or `group`
     *                               - `id`, `room_id`, `name`, `avatar`
     *                               - `last_message`: text, or a file-attachment
     *                                 placeholder, or null
     *                               - `last_message_time`: short relative time or null
     *                               - `is_active`: presence flag (false default)
     *                               - `member_count`: group size, null for direct chats
     */
    public function toArray($request)
    {
        // Handle array and object — normalize raw query rows into objects.
        $data = is_array($this->resource) ? (object) $this->resource : $this->resource;

        return [
            'type' => $data->type,
            'id' => $data->id,
            'room_id' => $data->room_id ?? null,
            'name' => $data->name,
            'avatar' => $data->avatar,
            // Prefer message text; fall back to a generic file label, then null.
            'last_message' => ($data->last_message && $data->last_message !== '')
                ? $data->last_message
                : (($data->last_message_file ?? null)
                    ? '📎 File attachment'
                    : null),
            'last_message_time' => $data->last_message_time
                ? Carbon::parse($data->last_message_time)->diffForHumans(short: true)
                : null,
            'is_active' => $data->is_active ?? false,
            'member_count' => $data->member_count ?? null,
        ];
    }



    /**
     * Format a timestamp into a compact human-readable string.
     *
     * Currently unused by `toArray()`; kept as a helper that yields a
     * terse label (e.g. `3h`) with the trailing `ago`/`from now` stripped.
     *
     * @param  mixed  $time  A parseable timestamp, or null.
     * @return string|null  The compact relative time, or null when no input.
     */
    private function getShortTime($time)
    {
        if (!$time) return null;

        $carbonTime = Carbon::parse($time);

        // Return compact human-readable time
        $diff = $carbonTime->diffForHumans([
            'parts' => 1,     // show only 1 part (e.g., "3h" instead of "3 hours 2 minutes")
            'short' => true,  // use short format like "3h" instead of "3 hours ago"
        ]);

        // Remove "ago"/"from now" if you want even shorter
        return str_replace([' ago', ' from now'], '', $diff);
    }
}
