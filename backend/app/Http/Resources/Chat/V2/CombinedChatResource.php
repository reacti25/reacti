<?php

namespace App\Http\Resources\Chat\V2;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single entry in the unified chat list (V2).
 *
 * The V2 variant of `App\Http\Resources\CombinedChatResource`. Adds an
 * `unread_count` field and renders file-only last messages with a richer,
 * type-specific label (Photo/Video/Audio/Document). Represents either a
 * direct chat or a group chat as a uniform list item.
 */
class CombinedChatResource extends JsonResource
{
    /**
     * Serialize one unified chat-list entry into the V2 API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed>  Array with keys:
     *                               - `type`: `chat` or `group`
     *                               - `id`, `room_id`, `name`, `avatar`
     *                               - `last_message`: text, a type-specific file
     *                                 label, or null
     *                               - `last_message_time`: short relative time or null
     *                               - `is_active`: presence flag (false default)
     *                               - `member_count`: group size, null for direct chats
     *                               - `unread_count`: unread message count (0 default)
     */
    public function toArray(Request $request): array
    {
        // Handle array and object — normalize raw query rows into objects.
        $data = is_array($this->resource) ? (object) $this->resource : $this->resource;

        return [
            'type' => $data->type,
            'id' => $data->id,
            'room_id' => $data->room_id ?? null,
            'name' => $data->name,
            'avatar' => $data->avatar,

            // Last message handling
            'last_message' => $this->formatLastMessage($data),
            'last_message_time' => $data->last_message_time
                ? Carbon::parse($data->last_message_time)->diffForHumans(['short' => true])
                : null,

            // Status info
            'is_active' => $data->is_active ?? false,
            'member_count' => $data->member_count ?? null,
            'unread_count' => $data->unread_count ?? 0,
        ];
    }

    /**
     * Build the last-message preview label for a chat-list entry.
     *
     * Prefers actual message text; for file-only messages it derives a
     * type-specific label via {@see getFileTypeText()}.
     *
     * @param  object  $data  The normalized chat-list row.
     * @return string|null  The preview text/label, or null when empty.
     */
    private function formatLastMessage($data): ?string
    {
        // If there's text, return it
        if ($data->last_message && $data->last_message !== '') {
            return $data->last_message;
        }

        // If there's a file, return appropriate icon/text
        if ($data->last_message_file ?? null) {
            return $this->getFileTypeText($data->last_message_file);
        }

        return null;
    }

    /**
     * Derive an emoji-prefixed label for a file-only last message.
     *
     * @param  string  $file  The stored file path.
     * @return string  One of `📷 Photo`, `🎥 Video`, `🎵 Audio`,
     *                  `📄 Document`, or `📎 File` for anything else.
     */
    private function getFileTypeText($file): string
    {
        $extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));

        $imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'heic', 'heif'];
        if (in_array($extension, $imageExtensions)) {
            return '📷 Photo';
        }

        $videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm', '3gp', 'mpeg'];
        if (in_array($extension, $videoExtensions)) {
            return '🎥 Video';
        }

        $audioExtensions = ['mp3', 'wav', 'ogg', 'aac', 'm4a', 'flac', 'wma'];
        if (in_array($extension, $audioExtensions)) {
            return '🎵 Audio';
        }

        $documentExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv'];
        if (in_array($extension, $documentExtensions)) {
            return '📄 Document';
        }

        return '📎 File';
    }
}
