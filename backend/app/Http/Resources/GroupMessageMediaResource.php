<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * API Resource for a media attachment within a group conversation.
 *
 * Serializes a group message that carries a file into a compact media
 * item with its sender. Returned by the group media-gallery endpoint to
 * render the shared photos/videos grid.
 */
class GroupMessageMediaResource extends JsonResource
{
    /**
     * Serialize one group media message into the API response array.
     *
     * @param  \Illuminate\Http\Request  $request  The incoming HTTP request.
     * @return array<string, mixed> Array with keys:
     *                              - `id`: message id
     *                              - `file_url`: absolute asset URL of the file
     *                              - `file_type`: `image`, `video`, or `file`
     *                              - `sent_at`: relative time the message was sent
     *                              - `sender`: nested profile (id, name, avatar)
     */
    public function toArray($request)
    {
        return [
            'id' => $this->id,
            'file_url' => asset($this->file),
            'file_type' => $this->getFileType(),
            'sent_at' => $this->created_at->diffForHumans(), // Human readable
            'sender' => [
                'id' => $this->sender->id,
                'name' => trim("{$this->sender->first_name} {$this->sender->last_name}"),
                'avatar' => $this->sender->avatar ? asset($this->sender->avatar) : null,
                // 'is_online'     => $this->sender->isOnline(), // assuming you have this method
            ],
        ];
    }

    /**
     * Detect a coarse file type from the message's file extension.
     *
     * Optional helper: maps the extension to a category the client uses
     * to pick a thumbnail/renderer.
     *
     * @return string `image`, `video`, or `file` for anything else.
     */
    // Optional: Detect file type (image, video, etc.)
    protected function getFileType()
    {
        $extension = strtolower(pathinfo($this->file, PATHINFO_EXTENSION));
        $imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
        $videoExts = ['mp4', 'avi', 'mov', 'wmv', 'mkv', 'webm'];

        if (in_array($extension, $imageExts)) {
            return 'image';
        }
        if (in_array($extension, $videoExts)) {
            return 'video';
        }

        return 'file';
    }
}
