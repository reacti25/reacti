<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Carbon;

/**
 * API Resource for a single 1:1 `Chat` message (V1).
 *
 * Serializes a direct-chat message with its sender, receiver, room and an
 * optional eager-loaded reply chain. Returned by the V1 chat controllers
 * when fetching or sending direct messages; carries the `is_blurred` /
 * `should_show_blur` flags that drive the patent-protected blur flow.
 *
 * @property Carbon|null $edited_at Proxied from the wrapped Chat model.
 */
class ChatMessageResource extends JsonResource
{
    /**
     * Transform the chat message into the API response array.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `id`, `sender_id`, `receiver_id`, `room_id`
     *                              - `text`, `file`, `status`
     *                              - `is_blurred`/`is_viewed`: blur-flow state
     *                              - `message_type`: normal vs reaction
     *                              - `is_my_text`/`should_show_blur`: per-viewer flags
     *                              - `humanize_date`: relative created time
     *                              - `short_text`: text truncated to 20 chars
     *                              - `type`: `sent` or `received`
     *                              - `media_type`: detected from file extension
     *                              - `reply_to`: nested replied message (only when loaded)
     *                              - `sender`/`receiver`: nested user profiles
     *                              - `room`: room id and both participant ids
     */
    public function toArray(Request $request): array
    {

        return [
            'id' => $this->id,
            'sender_id' => $this->sender_id,
            'receiver_id' => $this->receiver_id,
            'room_id' => $this->room_id,
            'text' => $this->text,
            // Wrap in asset() to return an absolute URL, matching every other
            // serializer (ChatResource, MessageResource) and this resource's own
            // reply_to.file. The client feeds `file` straight to the image loader,
            // which cannot resolve a bare relative path — a raw value here left
            // sent images blank when the conversation history was re-fetched.
            'file' => $this->file ? asset($this->file) : null,
            'status' => $this->status,
            // Additive: true once the sender has edited this message. Derived
            // from edited_at; old apps ignore the unknown key.
            'is_edited' => $this->edited_at !== null,
            // Additive: true when this message was forwarded (drives the
            // "Forwarded" label). Old apps ignore the unknown key.
            'is_forwarded' => $this->forwarded_from !== null,
            'is_blurred' => $this->is_blurred,
            // INTEGER, not boolean — the live v1.0.9 app parses is_viewed into a
            // strict int? (a boolean crashes its private-chat parse). Explicit
            // cast (the Chat model also casts it to integer); see the
            // backwards-compat suite.
            'is_viewed' => (int) $this->is_viewed,
            'message_type' => $this->message_type,
            // Per-viewer flags attached by the controller; default false.
            'is_my_text' => $this->is_my_text ?? false,
            'should_show_blur' => $this->should_show_blur ?? false,
            'humanize_date' => $this->created_at->diffForHumans(),
            // 'short_text' => $this->text ? (strlen($this->text) > 20 ? substr($this->text, 0, 20) . '...' : $this->text) : null,
            'short_text' => $this->text
                ? (mb_strlen($this->text, 'UTF-8') > 20
                    ? mb_substr($this->text, 0, 20, 'UTF-8').'...'
                    : $this->text)
                : null,
            'type' => $this->is_my_text ? 'sent' : 'received',

            // Media Type Detection
            'media_type' => $this->getMediaType(),

            // Reply block — only emitted when the `replyTo` relation is loaded.
            'reply_to' => $this->whenLoaded('replyTo', function () {
                $replied = $this->replyTo;

                if (! $replied) {
                    return null;
                }

                $mediaType = null;
                if ($replied->file) {
                    $ext = strtolower(pathinfo($replied->file, PATHINFO_EXTENSION));
                    if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'])) {
                        $mediaType = 'image';
                    } elseif (in_array($ext, ['mp4', 'mov', 'avi', 'mkv', 'webm'])) {
                        $mediaType = 'video';
                    } elseif (in_array($ext, ['mp3', 'wav', 'ogg', 'aac', 'm4a'])) {
                        $mediaType = 'audio';
                    } elseif (in_array($ext, ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'])) {
                        $mediaType = 'document';
                    } else {
                        $mediaType = 'file';
                    }
                }

                return [
                    'id' => $replied->id,
                    'sender_id' => (int) $replied->sender_id,
                    'text' => $replied->text,
                    'file' => $replied->file ? asset($replied->file) : null,
                    'media_type' => $mediaType,

                    // replied message's own blur state — NOT derived from parent
                    'is_blurred' => (bool) $replied->is_blurred,

                    'parent_message_id' => $replied->reply_to_id,
                    'parent_message' => $replied->parentReply ? [
                        'id' => $replied->parentReply->id,
                        'text' => $replied->parentReply->text,
                        'file' => $replied->parentReply->file ? asset($replied->parentReply->file) : null,
                    ] : null,
                    'sender' => [
                        'id' => $replied->sender->id ?? null,
                        'first_name' => $replied->sender->first_name ?? null,
                        'last_name' => $replied->sender->last_name ?? null,
                        'avatar' => isset($replied->sender->avatar) && $replied->sender->avatar
                            ? asset($replied->sender->avatar)
                            : asset('default/default_image.jpg'),
                    ],
                ];
            }),

            'sender' => [
                'id' => $this->sender->id,
                'first_name' => $this->sender->first_name,
                'last_name' => $this->sender->last_name,
                'avatar' => $this->sender->avatar,
                'last_activity_at' => $this->sender->last_activity_at,
            ],
            'receiver' => [
                'id' => $this->receiver->id,
                'first_name' => $this->receiver->first_name,
                'last_name' => $this->receiver->last_name,
                'avatar' => $this->receiver->avatar,
                'last_activity_at' => $this->receiver->last_activity_at,
            ],
            'room' => [
                'id' => $this->room->id,
                'user_one_id' => $this->room->user_one_id,
                'user_two_id' => $this->room->user_two_id,
            ],
        ];
    }

    /**
     * Detect media type from file extension
     *
     * Inspects the message's `file` attribute and maps its extension to a
     * coarse media category used by the client to choose a renderer.
     *
     * @return string|null One of `image`, `video`, `audio`, `document`,
     *                     `archive`, or `file`; null when no file is set.
     */
    private function getMediaType(): ?string
    {
        if (! $this->file) {
            return null;
        }

        // Extract file extension
        $extension = strtolower(pathinfo($this->file, PATHINFO_EXTENSION));

        // Image types
        $imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico', 'heic', 'tiff', 'psd', 'raw', 'ai', 'heif'];
        if (in_array($extension, $imageExtensions)) {
            return 'image';
        }

        // Video types
        $videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm', '3gp', 'mpeg', 'mpg'];
        if (in_array($extension, $videoExtensions)) {
            return 'video';
        }

        // Audio types
        $audioExtensions = ['mp3', 'wav', 'ogg', 'aac', 'm4a', 'flac', 'wma'];
        if (in_array($extension, $audioExtensions)) {
            return 'audio';
        }

        // Document types
        $documentExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv'];
        if (in_array($extension, $documentExtensions)) {
            return 'document';
        }

        // Archive types
        $archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz'];
        if (in_array($extension, $archiveExtensions)) {
            return 'archive';
        }

        // Default for unknown types
        return 'file';
    }
}
