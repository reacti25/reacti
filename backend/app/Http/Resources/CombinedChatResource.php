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
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `type`: `chat` or `group`
     *                              - `id`, `room_id`, `name`, `avatar`
     *                              - `last_message`: text, or a typed media/
     *                              reaction label, or null
     *                              - `last_message_time`: short relative time or null
     *                              - `is_active`: presence flag (false default)
     *                              - `member_count`: group size, null for direct chats
     *                              - `unread_count`: unseen messages, 0 default
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
            // Prefer message text; otherwise a typed media/reaction label; then null.
            'last_message' => $this->previewLabel($data),
            'last_message_time' => $data->last_message_time
                ? Carbon::parse($data->last_message_time)->diffForHumans(short: true)
                : null,
            'is_active' => $data->is_active ?? false,
            'member_count' => $data->member_count ?? null,
            // Additive (Phase 4): unseen-message count per conversation. Old
            // clients ignore it; new clients default a missing value to 0.
            'unread_count' => $data->unread_count ?? 0,
        ];
    }

    /**
     * Derive the chat-list subtitle for a conversation's last message.
     *
     * Text messages preview their text; media and reactions get a label that
     * reflects the message's open/viewed state for this viewer:
     *   - received media not opened → "📷 New photo" / "🎬 New video"
     *   - opened, or the viewer's own media → "📷 Photo" / "🎬 Video"
     *   - received reaction not viewed → "New reaction"
     *   - reaction viewed → "Reaction viewed"
     * Non-image/video attachments keep the generic file placeholder. Returns
     * null when there is no last message.
     *
     * ponytail: no "· M:SS" duration suffix — video duration isn't stored
     * on the message. Add it here once a duration column lands.
     *
     * @param  object  $data  The normalized last-message row.
     * @return string|null The subtitle label, or null when empty.
     */
    private function previewLabel($data): ?string
    {
        if ($data->last_message && $data->last_message !== '') {
            return $data->last_message;
        }

        $file = $data->last_message_file ?? null;
        if (! $file) {
            return null;
        }

        $received = (bool) ($data->last_message_received ?? false);
        $viewed = (bool) ($data->last_message_viewed ?? false);

        // A silently-captured reaction upload: "New reaction" until the
        // recipient watches it, then "Reaction viewed".
        if (($data->last_message_type ?? 'normal') === 'reaction') {
            if (! $received) {
                return '🤭 Reaction';
            }

            return $viewed ? '🤭 Reaction viewed' : '🫣 New reaction';
        }

        $extension = strtolower(pathinfo(parse_url($file, PHP_URL_PATH) ?? $file, PATHINFO_EXTENSION));
        $videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm', '3gp', 'mpeg'];
        $imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'heic', 'heif'];

        $isVideo = in_array($extension, $videoExtensions, true);
        $isImage = in_array($extension, $imageExtensions, true);
        if (! $isVideo && ! $isImage) {
            return '📎 File attachment';
        }

        // Unopened incoming media announces what's waiting; once opened (or if
        // it's the viewer's own) it drops the "New".
        $fresh = $received && ! $viewed;
        if ($isVideo) {
            return $fresh ? '🎬 New video' : '🎬 Video';
        }

        return $fresh ? '📷 New photo' : '📷 Photo';
    }

    /**
     * Format a timestamp into a compact human-readable string.
     *
     * Currently unused by `toArray()`; kept as a helper that yields a
     * terse label (e.g. `3h`) with the trailing `ago`/`from now` stripped.
     *
     * @param  mixed  $time  A parseable timestamp, or null.
     * @return string|null The compact relative time, or null when no input.
     */
    private function getShortTime($time)
    {
        if (! $time) {
            return null;
        }

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
