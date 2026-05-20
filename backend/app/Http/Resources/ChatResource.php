<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a single 1:1 `Chat` message (V1, UTF-8 hardened).
 *
 * Like `ChatMessageResource`, but every string value is passed through a
 * `safe()` helper to guard against invalid UTF-8 corrupting the JSON
 * response. Returned by the V1 direct-chat controllers; carries the
 * `is_blurred`/`is_viewed` flags central to the patent-protected blur flow.
 */
class ChatResource extends JsonResource
{
    /**
     * Sanitize a value so it is safe to embed in a UTF-8 JSON response.
     *
     * Non-strings pass through untouched; strings that are not valid
     * UTF-8 are re-encoded so JSON serialization does not fail.
     *
     * @param  mixed  $value  The raw attribute value.
     * @return mixed The original value, or a UTF-8-corrected string.
     */
    private function safe($value)
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            if (! mb_check_encoding($value, 'UTF-8')) {
                return utf8_encode($value);
            }

            return $value;
        }

        return $value;
    }

    /**
     * Transform the chat message into the API response array.
     *
     * @param  Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `id`, `sender_id`, `receiver_id`, `room_id`
     *                              - `text`/`file`: sanitized message body and asset URL
     *                              - `status`
     *                              - `is_blurred`/`is_viewed`: blur-flow state (cast to bool)
     *                              - `message_type`: normal vs reaction (default `normal`)
     *                              - `media_type`: detected from file extension
     *                              - `humanize_date`: relative created time (`just now` fallback)
     *                              - `short_text`: text truncated to ~30 chars, `Media` for files
     *                              - `type`: `sent` or `received` relative to the auth user
     *                              - `reply_to`: nested replied message (only when loaded)
     *                              - `sender`/`receiver`: nested user profiles
     *                              - `room`: room id and both participant ids
     */
    public function toArray($request): array
    {
        // Resolve viewer identity to derive the `type` (sent/received) field.
        $authId = auth('api')->id();
        $isSent = $this->sender_id == $authId;

        // Safe short text — preview shown in chat lists; `Media` for file-only messages.
        $shortText = '';
        if ($this->text) {
            $shortText = mb_strlen($this->text) > 30
                ? mb_substr($this->text, 0, 27).'...'
                : $this->text;
        } elseif ($this->file) {
            $shortText = 'Media';
        }

        return [
            'id' => $this->id,
            'sender_id' => $this->sender_id,
            'receiver_id' => $this->receiver_id,
            'text' => $this->safe($this->text ?? ''),
            'file' => $this->file ? $this->safe(asset($this->file)) : null,
            'room_id' => $this->room_id,
            'status' => $this->status,
            'is_blurred' => (bool) $this->is_blurred,
            'is_viewed' => (bool) $this->is_viewed,
            'message_type' => $this->message_type ?? 'normal',
            'media_type' => $this->getMediaType(),
            'humanize_date' => $this->created_at ? $this->safe($this->created_at->diffForHumans()) : 'just now',
            'short_text' => $this->safe($shortText),
            'type' => $isSent ? 'sent' : 'received',

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

                    // Use the replied message's own is_blurred value directly
                    // In single chat, is_blurred lives on the Chat model itself
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
                'first_name' => $this->safe($this->sender->first_name),
                'last_name' => $this->safe($this->sender->last_name),
                'avatar' => $this->safe(
                    $this->sender->avatar
                        ? asset($this->sender->avatar)
                        : asset('default/default_image.jpg')
                ),
                'last_activity_at' => $this->safe($this->sender->last_activity_at ?? ''),
            ],

            'receiver' => [
                'id' => $this->receiver->id,
                'first_name' => $this->safe($this->receiver->first_name),
                'last_name' => $this->safe($this->receiver->last_name),
                'avatar' => $this->safe(
                    $this->receiver->avatar
                        ? asset($this->receiver->avatar)
                        : asset('default/default_image.jpg')
                ),
                'last_activity_at' => $this->safe($this->receiver->last_activity_at ?? ''),
            ],

            'room' => [
                'id' => $this->room->id,
                'user_one_id' => $this->room->user_one_id,
                'user_two_id' => $this->room->user_two_id,
            ],
        ];
    }

    /**
     * Detect the media category of this message's attached file.
     *
     * @return string|null One of `image`, `video`, `audio`, `document`,
     *                     `archive`, or `file`; null when no file is set.
     */
    private function getMediaType(): ?string
    {
        if (! $this->file) {
            return null;
        }

        $extension = strtolower(pathinfo($this->file, PATHINFO_EXTENSION));

        $image = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico'];
        $video = ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm', '3gp', 'mpeg', 'mpg'];
        $audio = ['mp3', 'wav', 'ogg', 'aac', 'm4a', 'flac', 'wma'];
        $doc = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv'];
        $zip = ['zip', 'rar', '7z', 'tar', 'gz'];

        return match (true) {
            in_array($extension, $image) => 'image',
            in_array($extension, $video) => 'video',
            in_array($extension, $audio) => 'audio',
            in_array($extension, $doc) => 'document',
            in_array($extension, $zip) => 'archive',
            default => 'file'
        };
    }
}
