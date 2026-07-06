<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Eloquent model for a single 1:1 chat message.
 *
 * Backs the `chats` table and represents one message exchanged between
 * two users inside a `Room`. A message may carry text, a media file, or
 * both, and supports replies (`reply_to_id`) and forwarding
 * (`forwarded_from`). Media messages central to the patent flow are
 * stored with `is_blurred=true` so the receiver's client knows to keep
 * the media obscured until it is opened.
 *
 * Uses soft deletes so a deleted message can still be referenced (for
 * example by a reply that points at it).
 */
class Chat extends Model
{
    use HasFactory, SoftDeletes;

    /** Attributes mass-assignable when creating or updating a message. */
    protected $fillable = [
        'sender_id',
        'receiver_id',
        'text',
        'file',
        'file_type',
        'thumbnail',
        'room_id',
        'status',
        'is_blurred',
        'is_viewed',
        'message_type',
        'reply_to_id',
        'forwarded_from',
    ];

    /** Attributes hidden from array/JSON output (the soft-delete timestamp). */
    protected $hidden = [
        'deleted_at',
    ];

    /**
     * Attribute cast definitions.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'sender_id' => 'integer',
            'receiver_id' => 'integer',
            'room_id' => 'integer',
            'text' => 'string',
            'is_blurred' => 'boolean',
            // is_viewed is emitted as an INTEGER (0/1), not a JSON boolean: the
            // live App Store app (v1.0.9) parses `is_viewed` into a strict
            // `int?` field, so a boolean here crashes its private-chat parse —
            // the 2026-05-23 incident class. The current/new app parses it as
            // `dynamic`, so int is safe for both. Guarded by the backwards-compat
            // suite. (is_blurred stays boolean: both apps parse it dynamically.)
            'is_viewed' => 'integer',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
        ];
    }

    /** Computed accessors appended to every serialized message. */
    protected $appends = [
        'humanize_date',
        'short_text',
        'type',
        'media_type',
    ];

    /**
     * Accessor for the `file` attribute.
     *
     * Files are persisted as fully-qualified S3 URLs, so the raw stored
     * value is returned unchanged (no path rewriting needed).
     *
     * @param  string|null  $value  Raw stored file URL.
     * @return string|null The media URL, or null when the message has no file.
     */
    public function getFileAttribute($value): ?string
    {
        return $value;
    }

    /**
     * Accessor producing a truncated preview of the message text.
     *
     * Used in chat-list views where only a snippet is shown. Text longer
     * than 50 characters is cut and suffixed with an ellipsis.
     *
     * @return string|null The preview text, or null when there is no text.
     */
    public function getShortTextAttribute(): ?string
    {
        if (! $this->text) {
            return null;
        }

        return mb_strlen($this->text, 'UTF-8') > 50
            ? mb_substr($this->text, 0, 50, 'UTF-8').'...'
            : $this->text;
    }

    /**
     * Accessor returning the creation time as a relative phrase.
     *
     * @return string A human-friendly date such as "5 minutes ago".
     */
    public function getHumanizeDateAttribute(): string
    {
        return $this->created_at->diffForHumans();
    }

    /**
     * Accessor classifying the message relative to the current viewer.
     *
     * Resolves the viewer from the `api` guard for API requests and the
     * `web` guard otherwise, so the same model serializes correctly for
     * both the mobile app and the admin panel.
     *
     * @return string Either "sent" (viewer is the sender) or "received".
     */
    public function getTypeAttribute(): string
    {
        $currentUserId = null;

        // Pick the guard based on the current route group (api vs. web).
        if (request()->is('api/*')) {
            $currentUserId = auth('api')->id();
        } else {
            $currentUserId = auth('web')->id();
        }

        return $this->sender_id == $currentUserId ? 'sent' : 'received';
    }

    /**
     * Accessor resolving a coarse media category for the attached file.
     *
     * Prefers the explicitly stored `file_type` column; when absent it
     * falls back to inferring the category from the file extension.
     *
     * @return string|null One of image|video|audio|document|file, or
     *                     null when the message carries no file.
     */
    public function getMediaTypeAttribute(): ?string
    {
        if (! $this->file) {
            return null;
        }

        // If file_type is already stored, use it
        if ($this->attributes['file_type'] ?? null) {
            return $this->attributes['file_type'];
        }

        // Otherwise detect from extension
        $extension = strtolower(pathinfo($this->file, PATHINFO_EXTENSION));

        $imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'heic', 'heif'];
        if (in_array($extension, $imageExtensions)) {
            return 'image';
        }

        $videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm', '3gp', 'mpeg'];
        if (in_array($extension, $videoExtensions)) {
            return 'video';
        }

        $audioExtensions = ['mp3', 'wav', 'ogg', 'aac', 'm4a', 'flac', 'wma'];
        if (in_array($extension, $audioExtensions)) {
            return 'audio';
        }

        $documentExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv'];
        if (in_array($extension, $documentExtensions)) {
            return 'document';
        }

        return 'file';
    }

    /**
     * Relationship: the `User` who sent this message.
     */
    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    /**
     * Relationship: the `User` this message was sent to.
     */
    public function receiver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    /**
     * Relationship: the `Room` (conversation) this message belongs to.
     */
    public function room(): BelongsTo
    {
        return $this->belongsTo(Room::class, 'room_id');
    }

    /**
     * Relationship: the original `Chat` message this one replies to.
     */
    public function replyTo(): BelongsTo
    {
        return $this->belongsTo(Chat::class, 'reply_to_id');
    }

    /**
     * Relationship: alias of {@see replyTo()} kept for API resources that
     * reference the parent message under the `parentReply` key.
     *
     * @return BelongsTo
     */
    public function parentReply()
    {
        return $this->belongsTo(Chat::class, 'reply_to_id');
    }

    /**
     * Relationship: the `User` this message was originally forwarded from.
     */
    public function forwardedFromUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'forwarded_from');
    }

    /**
     * Query scope limiting results to a single conversation room.
     *
     * @param  Builder  $query
     * @param  int  $roomId  Room whose messages should be returned.
     * @return Builder
     */
    public function scopeForRoom($query, $roomId)
    {
        return $query->where('room_id', $roomId);
    }

    /**
     * Query scope for messages a given user has received but not read.
     *
     * @param  Builder  $query
     * @param  int  $userId  The recipient whose unread mail is wanted.
     * @return Builder
     */
    public function scopeUnreadFor($query, $userId)
    {
        return $query->where('receiver_id', $userId)
            ->where('status', '!=', 'read');
    }

    /**
     * Query scope for the full conversation between two users,
     * regardless of which of them was the sender.
     *
     * @param  Builder  $query
     * @param  int  $userId1  One participant.
     * @param  int  $userId2  The other participant.
     * @return Builder
     */
    public function scopeBetweenUsers($query, $userId1, $userId2)
    {
        return $query->where(function ($q) use ($userId1, $userId2) {
            $q->where('sender_id', $userId1)->where('receiver_id', $userId2);
        })->orWhere(function ($q) use ($userId1, $userId2) {
            $q->where('sender_id', $userId2)->where('receiver_id', $userId1);
        });
    }

    /**
     * Set the message status to "read".
     *
     * @return bool True when the update persisted.
     */
    public function markAsRead(): bool
    {
        return $this->update(['status' => 'read']);
    }

    /**
     * Set the message status to "delivered".
     *
     * @return bool True when the update persisted.
     */
    public function markAsDelivered(): bool
    {
        return $this->update(['status' => 'delivered']);
    }

    /**
     * Determine whether the current authenticated user sent this message.
     *
     * Resolves the viewer from the `api` or `web` guard depending on the
     * active route group.
     */
    public function isMine(): bool
    {
        $currentUserId = request()->is('api/*')
            ? auth('api')->id()
            : auth('web')->id();

        return $this->sender_id == $currentUserId;
    }

    /**
     * Determine whether the message carries a media file attachment.
     */
    public function hasMedia(): bool
    {
        return ! is_null($this->file);
    }

    /**
     * Determine whether the message is a reply to another message.
     */
    public function isReply(): bool
    {
        return ! is_null($this->reply_to_id);
    }

    /**
     * Determine whether the message was forwarded from another user.
     */
    public function isForwarded(): bool
    {
        return ! is_null($this->forwarded_from);
    }
}
