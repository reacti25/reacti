<?php

namespace App\Services;

use App\Events\MessageSendEvent;
use App\Exceptions\ApiException;
use App\Models\Chat;
use App\Models\Group;
use App\Models\Room;
use App\Models\User;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Business logic for V2 1:1 (direct) chat messaging.
 *
 * Extracted from {@see \App\Http\Controllers\Api\Chat\V2\SingleChatController}
 * so the controller only validates input, resolves the authenticated user,
 * applies soft-failure guard clauses, and shapes the JSON response. This
 * service is central to the patent flow: {@see SingleChatService::send()}
 * stores media in `normal` messages with `is_blurred=true`, and
 * {@see SingleChatService::markAsViewed()} performs the `mark-viewed` unblur
 * that triggers the receiver's silent reaction recording.
 *
 * Expected business-rule failures (bad/self target, blocked pair, missing
 * record) are signalled by throwing {@see ApiException}; the controller maps
 * those onto the error envelope. Unexpected failures bubble up as plain
 * {@see Exception}s and are mapped to a 500 by the controller. All DB writes,
 * transactions, S3 uploads, Pusher broadcasts, cache invalidation, and push
 * notification fan-out are reproduced verbatim from the pre-refactor
 * controller — no behaviour change.
 */
class SingleChatService
{
    /**
     * @param  PushNotificationService  $pushNotificationService  Device push fan-out.
     * @param  BlockService             $blockService             Block-state queries.
     */
    public function __construct(
        private readonly PushNotificationService $pushNotificationService,
        private readonly BlockService $blockService
    ) {
    }

    /**
     * Send a 1:1 message with S3 media upload and real-time delivery.
     *
     * Rejects self-chat and blocked pairs (via {@see ApiException}). Media is
     * uploaded to S3 first; the `chats` row is then created inside a
     * transaction and, if that fails, the just-uploaded S3 object is deleted
     * to avoid orphans. `normal` messages with media are stored `is_blurred`
     * for the patent flow. The message is broadcast via `MessageSendEvent`, a
     * push is sent, and both users' cached chat lists are invalidated —
     * broadcast/push failures are logged, not thrown.
     *
     * The S3 upload-failure branch and the transaction-failure branch both
     * return a 500 envelope verbatim (as the original controller did) rather
     * than throwing — the controller passes those arrays straight through.
     *
     * @param  Request  $request      Body: text, file, message_type
     *                                (normal|reaction|reply), reply_to_id.
     * @param  int      $receiver_id  The user being messaged.
     * @return array{0: string, 1: \App\Models\Chat|null, 2: array|null}
     *               [outcome, the created chat (on success), a verbatim
     *               error-response array (on a 500-class failure)].
     *
     * @throws ApiException  On a self/invalid target (400) or a blocked pair (403).
     */
    public function send(Request $request, $receiver_id): array
    {
        $sender_id = Auth::guard('api')->id();
        $receiver = User::find($receiver_id);

        if (!$receiver || $receiver_id == $sender_id) {
            throw new ApiException('User not found or cannot chat with yourself', 400);
        }

        // Check if blocked (a block in either direction)
        $isBlocked = $this->blockService->blockExistsBetween($sender_id, $receiver_id);

        if ($isBlocked) {
            throw new ApiException('Cannot send message to this user', 403);
        }

        // Find or create room
        $room = Room::firstOrCreate([
            'user_one_id' => min($sender_id, $receiver_id),
            'user_two_id' => max($sender_id, $receiver_id)
        ]);

        $file = null;
        $fileType = null;
        $thumbnailPath = null;
        $filePath = null;

        // Upload file to S3 with proper error handling
        if ($request->hasFile('file')) {
            try {
                $uploadedFile = $request->file('file');
                $mimeType = $uploadedFile->getMimeType();

                Log::info('Starting file upload', [
                    'mime_type' => $mimeType,
                    'size' => $uploadedFile->getSize(),
                    'original_name' => $uploadedFile->getClientOriginalName()
                ]);

                // Determine file type
                if (Str::startsWith($mimeType, 'image/')) {
                    $fileType = 'image';
                } elseif (Str::startsWith($mimeType, 'video/')) {
                    $fileType = 'video';
                } elseif (Str::startsWith($mimeType, 'audio/')) {
                    $fileType = 'audio';
                } else {
                    $fileType = 'document';
                }

                // Generate unique filename
                $extension = $uploadedFile->getClientOriginalExtension();
                $fileName = time() . '_' . Str::random(10) . '.' . $extension;
                $filePath = "chat/{$room->id}/{$fileName}";

                Log::info('Uploading to S3', [
                    'path' => $filePath,
                    'bucket' => config('filesystems.disks.s3.bucket'),
                    'region' => config('filesystems.disks.s3.region')
                ]);

                // Upload to S3 using putFileAs (better method)
                $s3Path = Storage::disk('s3')->putFileAs(
                    "chat/{$room->id}",
                    $uploadedFile,
                    $fileName,
                    'public' // ACL
                );

                if ($s3Path) {
                    // Get the full S3 URL
                    $file = Storage::disk('s3')->url($s3Path);

                    Log::info('File uploaded successfully to S3', [
                        'path' => $s3Path,
                        'url' => $file
                    ]);
                } else {
                    throw new Exception('S3 upload failed - no path returned');
                }
            } catch (Exception $e) {
                Log::error('S3 Upload Error', [
                    'error' => $e->getMessage(),
                    'trace' => $e->getTraceAsString(),
                    'file_path' => $filePath ?? 'unknown'
                ]);

                return ['error', null, [
                    'success' => false,
                    'message' => 'Failed to upload file: ' . $e->getMessage(),
                    'code' => 500
                ]];
            }
        }

        $text = $request->text ?? '';

        // Ensure UTF-8 encoding
        if (!mb_check_encoding($text, 'UTF-8')) {
            $text = mb_convert_encoding($text, 'UTF-8', 'UTF-8');
        }

        $messageType = $request->input('message_type', 'normal');
        $isBlurred = false;

        // Blur media for normal messages
        if ($messageType === 'normal' && $file) {
            $isBlurred = true;
        }

        // Create message with transaction
        DB::beginTransaction();
        try {
            $chat = Chat::create([
                'sender_id' => $sender_id,
                'receiver_id' => $receiver_id,
                'text' => $text,
                'file' => $file,
                'file_type' => $fileType,
                'thumbnail' => $thumbnailPath,
                'room_id' => $room->id,
                'status' => 'sent',
                'is_blurred' => $isBlurred,
                'is_viewed' => false,
                'message_type' => $messageType,
                'reply_to_id' => $request->reply_to_id,
            ]);

            // Update room's last message timestamp
            $room->touch();

            DB::commit();

            Log::info('Message created successfully', [
                'message_id' => $chat->id,
                'has_file' => !is_null($file)
            ]);
        } catch (Exception $e) {
            DB::rollBack();

            Log::error('Failed to create message', [
                'error' => $e->getMessage()
            ]);

            // Delete uploaded file if message creation fails
            if ($filePath) {
                try {
                    Storage::disk('s3')->delete($filePath);
                    Log::info('Rolled back S3 file upload');
                } catch (Exception $deleteError) {
                    Log::error('Failed to delete S3 file during rollback', [
                        'error' => $deleteError->getMessage()
                    ]);
                }
            }

            return ['error', null, [
                'success' => false,
                'message' => 'Failed to send message: ' . $e->getMessage(),
                'code' => 500
            ]];
        }

        // Eager load relationships
        $chat->load([
            'sender:id,first_name,last_name,avatar,last_activity_at',
            'receiver:id,first_name,last_name,avatar,last_activity_at',
            'room:id,user_one_id,user_two_id',
            'replyTo:id,sender_id,text,file'
        ]);

        // Broadcast message via WebSocket
        try {
            broadcast(new MessageSendEvent($chat))->toOthers();
        } catch (Exception $e) {
            Log::warning('Failed to broadcast message', [
                'error' => $e->getMessage()
            ]);
        }

        // Send push notification
        try {
            $this->sendPushNotification($receiver, $sender_id, $text, $file, $fileType);
        } catch (Exception $e) {
            Log::warning('Failed to send push notification', [
                'error' => $e->getMessage()
            ]);
        }

        // Clear cache
        Cache::forget("chat_list_user_{$sender_id}");
        Cache::forget("chat_list_user_{$receiver_id}");

        return ['success', $chat, null];
    }

    /**
     * Generate a thumbnail for an image file.
     *
     * Placeholder — thumbnail generation is not yet implemented, so
     * this currently always returns null (the original is used as-is).
     *
     * @param  mixed  $file  The uploaded image file.
     * @return string|null  The thumbnail path, or null when none is produced.
     */
    private function generateThumbnail($file): ?string
    {
        try {
            // Use Intervention Image or similar library for thumbnail generation
            // For now, we'll just upload the original
            // TODO: Implement actual thumbnail generation
            return null;
        } catch (Exception $e) {
            return null;
        }
    }

    /**
     * Generate a thumbnail for a video file.
     *
     * Placeholder — intended to use FFmpeg but not yet implemented, so
     * this currently always returns null.
     *
     * @param  mixed  $file  The uploaded video file.
     * @return string|null  The thumbnail path, or null when none is produced.
     */
    private function generateVideoThumbnail($file): ?string
    {
        try {
            // Use FFmpeg to generate video thumbnail
            // TODO: Implement actual video thumbnail generation
            return null;
        } catch (Exception $e) {
            return null;
        }
    }

    /**
     * Fan out a Firebase push notification for a new message.
     *
     * Builds a short preview (an emoji label for media, or truncated
     * text) and sends it to every Firebase token registered for the
     * receiver. No-op if the receiver has no registered devices.
     *
     * @param  \App\Models\User|null  $receiver  Recipient of the push.
     * @param  int     $senderId  Id of the user who sent the message.
     * @param  string  $text      The message text (used for the preview).
     * @param  string|null  $file      The message file URL, if any.
     * @param  string|null  $fileType  image|video|audio|document, if a file.
     * @return void
     */
    private function sendPushNotification($receiver, $senderId, $text, $file, $fileType)
    {
        if (!$receiver || !$receiver->firebaseTokens->count()) {
            return;
        }

        $sender = User::select('id', 'first_name', 'last_name', 'avatar')
            ->find($senderId);

        $senderName = trim("{$sender->first_name} {$sender->last_name}");

        // Create message preview
        $messagePreview = '';
        if ($file) {
            switch ($fileType) {
                case 'image':
                    $messagePreview = '📷 Photo';
                    break;
                case 'video':
                    $messagePreview = '🎥 Video';
                    break;
                case 'audio':
                    $messagePreview = '🎵 Audio';
                    break;
                case 'document':
                    $messagePreview = '📎 Document';
                    break;
                default:
                    $messagePreview = '📁 File';
            }
        } else {
            $messagePreview = Str::limit($text, 50);
        }

        $notifyData = [
            'title' => $senderName,
            'body' => $messagePreview,
            'icon' => $sender->avatar ?? config('settings.logo'),
            'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            'sender_id' => $senderId,
        ];

        // Send to all registered devices
        $this->pushNotificationService->sendToUser($receiver, $notifyData);
    }

    /**
     * Mark a media message as viewed (unblur it for the receiver).
     *
     * The V2 patent-flow `mark-viewed` operation — flips `is_blurred`
     * off and `is_viewed` on. Scoped by `receiver_id = auth user`, so
     * only the intended recipient can unblur it; anyone else triggers a
     * 404 via {@see ApiException}.
     *
     * @param  int  $message_id  The chat row to mark viewed.
     * @return Chat  The updated chat row.
     *
     * @throws ApiException  404 when the message does not belong to the auth user.
     */
    public function markAsViewed($message_id): Chat
    {
        $user_id = Auth::guard('api')->id();

        $chat = Chat::where('id', $message_id)
            ->where('receiver_id', $user_id)
            ->first();

        if (!$chat) {
            throw new ApiException('Message not found', 404);
        }

        // Mark as viewed (unblur)
        $chat->update([
            'is_viewed' => true,
            'is_blurred' => false,
        ]);

        return $chat;
    }

    /**
     * Get the conversation with a user, paginated newest-first.
     *
     * Bulk-marks the other user's messages as read, finds or creates
     * the room, and returns a page of messages. Each is tagged with
     * `is_my_text` and `should_show_blur` (true only for unviewed media
     * the auth user received — drives the patent blur placeholder).
     * Also reports mutual block status.
     *
     * @param  int  $receiver_id  The other participant.
     * @return array  receiver, sender, room, the message paginator, and block flags.
     *
     * @throws ApiException  404 for an invalid / self target.
     */
    public function conversation($receiver_id): array
    {
        $sender_id = Auth::guard('api')->id();

        // Validate receiver exists
        $receiver = User::select('id', 'first_name', 'last_name', 'avatar', 'last_activity_at')
            ->find($receiver_id);

        if (!$receiver || $receiver_id == $sender_id) {
            throw new ApiException('User not found', 404);
        }

        // Mark messages as read in bulk
        Chat::where('receiver_id', $sender_id)
            ->where('sender_id', $receiver_id)
            ->where('status', '!=', 'read')
            ->update(['status' => 'read']);

        // Get or create room
        $room = Room::firstOrCreate([
            'user_one_id' => min($sender_id, $receiver_id),
            'user_two_id' => max($sender_id, $receiver_id)
        ]);

        // Optimized query with proper indexing
        $perPage = request()->get('per_page', 50);
        $page = request()->get('page', 1);

        $chat = Chat::where('room_id', $room->id)
            ->with([
                'sender:id,first_name,last_name,avatar,last_activity_at',
                'receiver:id,first_name,last_name,avatar,last_activity_at',
                'room:id,user_one_id,user_two_id',
                'replyTo:id,sender_id,text,file' // Load reply-to messages
            ])
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);

        // Transform messages
        $chat->getCollection()->transform(function ($message) use ($sender_id) {
            $message->is_my_text = $message->sender_id === $sender_id;
            $message->should_show_blur = false;

            if ($message->receiver_id === $sender_id && $message->is_blurred && !$message->is_viewed) {
                $message->should_show_blur = true;
            }

            return $message;
        });

        // Check block status
        $blockStatus = $this->checkBlockStatus($sender_id, $receiver_id);

        $sender = User::select('id', 'first_name', 'last_name', 'avatar', 'last_activity_at')
            ->find($sender_id);

        return [
            'receiver' => $receiver,
            'sender' => $sender,
            'room' => $room,
            'chat' => $chat,
            'is_blocked' => $blockStatus['is_blocked'],
            'block_by_me' => $blockStatus['block_by_me'],
        ];
    }

    /**
     * Determine the block relationship between two users.
     *
     * @param  int  $user_id        The auth user (the "me" perspective).
     * @param  int  $other_user_id  The other conversation participant.
     * @return array{is_blocked: bool, block_by_me: bool}  Whether a block
     *                exists in either direction, and whether the auth user
     *                is the one who created it.
     */
    private function checkBlockStatus($user_id, $other_user_id): array
    {
        $blockQuery = DB::table('user_blocks')
            ->where(function ($query) use ($user_id, $other_user_id) {
                $query->where('user_id', $user_id)->where('block_user_id', $other_user_id);
            })
            ->orWhere(function ($query) use ($user_id, $other_user_id) {
                $query->where('user_id', $other_user_id)->where('block_user_id', $user_id);
            })
            ->first();

        return [
            'is_blocked' => (bool) $blockQuery,
            'block_by_me' => $blockQuery && $blockQuery->user_id == $user_id,
        ];
    }

    /**
     * Mark every message from a given sender to the auth user as read.
     *
     * @param  int  $receiver_id  The sender whose messages get read.
     * @return int  The number of `chats` rows updated.
     *
     * @throws ApiException  400 for an invalid / self target.
     */
    public function seenAll($receiver_id): int
    {
        $sender_id = Auth::guard('api')->id();

        if (!User::find($receiver_id) || $receiver_id == $sender_id) {
            throw new ApiException('Invalid user', 400);
        }

        $updated = Chat::where('receiver_id', $sender_id)
            ->where('sender_id', $receiver_id)
            ->where('status', '!=', 'read')
            ->update(['status' => 'read']);

        return $updated;
    }

    /**
     * Mark a single received message as read.
     *
     * Scoped by `receiver_id = auth user`; a no-op or unknown id
     * yields a 404 via {@see ApiException}.
     *
     * @param  int  $chat_id  The chat row to mark read.
     * @return int  The number of `chats` rows updated (always non-zero on success).
     *
     * @throws ApiException  404 if not found / already read.
     */
    public function seenSingle($chat_id): int
    {
        $sender_id = Auth::guard('api')->id();

        $updated = Chat::where('id', $chat_id)
            ->where('receiver_id', $sender_id)
            ->where('status', '!=', 'read')
            ->update(['status' => 'read']);

        if (!$updated) {
            throw new ApiException('Message not found or already read', 404);
        }

        return $updated;
    }

    /**
     * Get (or lazily create) the 1:1 room with another user.
     *
     * @param  int  $receiver_id  The other participant.
     * @return Room  The room with both users eager-loaded.
     *
     * @throws ApiException  400 for an invalid / self target.
     */
    public function room($receiver_id): Room
    {
        $sender_id = Auth::guard('api')->id();

        if (!User::find($receiver_id) || $receiver_id == $sender_id) {
            throw new ApiException('Invalid user', 400);
        }

        $room = Room::with([
            'userOne:id,first_name,last_name,email,avatar,last_activity_at',
            'userTwo:id,first_name,last_name,email,avatar,last_activity_at'
        ])
            ->firstOrCreate([
                'user_one_id' => min($sender_id, $receiver_id),
                'user_two_id' => max($sender_id, $receiver_id)
            ]);

        return $room;
    }

    /**
     * Search users by name, email, or username (max 50 results).
     *
     * Excludes the auth user from results.
     *
     * @param  string|null  $keyword  The search keyword (required).
     * @return \Illuminate\Database\Eloquent\Collection  Matching users.
     *
     * @throws ApiException  400 if no keyword is given.
     */
    public function search($keyword)
    {
        $user_id = Auth::guard('api')->id();

        if (!$keyword) {
            throw new ApiException('Search keyword required', 400);
        }

        $users = User::select('id', 'first_name', 'last_name', 'email', 'avatar', 'last_activity_at')
            ->where('id', '!=', $user_id)
            ->where(function ($query) use ($keyword) {
                $query->where('first_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('last_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('email', 'LIKE', "%{$keyword}%")
                    ->orWhere('username', 'LIKE', "%{$keyword}%");
            })
            ->limit(50)
            ->get();

        return $users;
    }

    /**
     * Delete the entire conversation with another user.
     *
     * Inside a transaction: removes every S3-hosted file in the room,
     * soft-deletes all messages, deletes the room, and clears both
     * users' cached chat lists. The transaction-failure branch returns a
     * verbatim 500 envelope (as the original controller did) rather than
     * throwing.
     *
     * @param  int  $receiver_id  The other participant.
     * @return array|null  Null on success; a verbatim error-response array
     *                     on a 500-class transaction failure.
     *
     * @throws ApiException  404 if no conversation exists.
     */
    public function deleteChat($receiver_id): ?array
    {
        $sender_id = Auth::guard('api')->id();

        $room = Room::where(function ($query) use ($sender_id, $receiver_id) {
            $query->where('user_one_id', $sender_id)->where('user_two_id', $receiver_id);
        })->orWhere(function ($query) use ($sender_id, $receiver_id) {
            $query->where('user_one_id', $receiver_id)->where('user_two_id', $sender_id);
        })->first();

        if (!$room) {
            throw new ApiException('Conversation not found', 404);
        }

        DB::beginTransaction();
        try {
            // Get all files to delete from S3
            $messages = Chat::where('room_id', $room->id)
                ->whereNotNull('file')
                ->get(['file']);

            // Delete files from S3
            foreach ($messages as $message) {
                if ($message->file && Str::startsWith($message->file, 'https://')) {
                    $filePath = parse_url($message->file, PHP_URL_PATH);
                    Storage::disk('s3')->delete($filePath);
                }
            }

            // Soft delete messages
            Chat::where('room_id', $room->id)->delete();

            // Delete room
            $room->delete();

            DB::commit();

            // Clear cache
            Cache::forget("chat_list_user_{$sender_id}");
            Cache::forget("chat_list_user_{$receiver_id}");

            return null;
        } catch (Exception $e) {
            DB::rollBack();

            return [
                'success' => false,
                'message' => 'Failed to delete conversation',
                'code' => 500
            ];
        }
    }

    /**
     * Delete a single chat message.
     *
     * The caller must be the sender or receiver of the message
     * (otherwise 404 via {@see ApiException}). Any associated S3 file is
     * removed before the row is soft-deleted, inside a transaction. The
     * transaction-failure branch returns a verbatim 500 envelope (as the
     * original controller did) rather than throwing.
     *
     * @param  int  $message_id  The chat row to delete.
     * @return array|null  Null on success; a verbatim error-response array
     *                     on a 500-class transaction failure.
     *
     * @throws ApiException  404 if not found / not permitted.
     */
    public function deleteMessage($message_id): ?array
    {
        $authUser = Auth::guard('api')->user();

        $message = Chat::where('id', $message_id)
            ->where(function ($query) use ($authUser) {
                $query->where('sender_id', $authUser->id)
                    ->orWhere('receiver_id', $authUser->id);
            })
            ->first();

        if (!$message) {
            throw new ApiException('Message not found', 404);
        }

        DB::beginTransaction();
        try {
            // Delete file from S3 if exists
            if ($message->file && Str::startsWith($message->file, 'https://')) {
                $filePath = parse_url($message->file, PHP_URL_PATH);
                Storage::disk('s3')->delete($filePath);
            }

            $message->delete();

            DB::commit();

            return null;
        } catch (Exception $e) {
            DB::rollBack();

            return [
                'success' => false,
                'message' => 'Failed to delete message',
                'code' => 500
            ];
        }
    }

    /**
     * Build the unified chat list of 1:1 conversations and groups.
     *
     * When no search keyword is given the result is cached for 30
     * seconds per user (real-time enough, but cheap); a keyword search
     * always bypasses the cache. The merged list is then paginated
     * manually.
     *
     * @param  Request  $request   The incoming request (used for the paginator path/query).
     * @param  \App\Models\User  $authUser  The authenticated user.
     * @param  string|null  $keyword  Optional keyword filter.
     * @param  int  $perPage  Page size.
     * @return \Illuminate\Pagination\LengthAwarePaginator  The paginated combined chat list.
     */
    public function listCombined(Request $request, User $authUser, $keyword, $perPage): LengthAwarePaginator
    {
        // Cache key
        $cacheKey = "chat_list_user_{$authUser->id}_keyword_" . md5($keyword ?? '');

        // Try to get from cache (cache for 30 seconds for real-time feel)
        if (!$keyword) {
            $combined = Cache::remember($cacheKey, 30, function () use ($authUser, $keyword, $perPage) {
                return $this->getCombinedChatList($authUser, $keyword, $perPage);
            });
        } else {
            $combined = $this->getCombinedChatList($authUser, $keyword, $perPage);
        }

        // Manual pagination
        $currentPage = LengthAwarePaginator::resolveCurrentPage();
        $pagedData = $combined->slice(($currentPage - 1) * $perPage, $perPage)->values();

        $paginator = new LengthAwarePaginator(
            $pagedData,
            $combined->count(),
            $perPage,
            $currentPage,
            ['path' => $request->url(), 'query' => $request->query()]
        );

        return $paginator;
    }

    /**
     * Assemble the merged, sorted chat list for a user.
     *
     * Gathers users the auth user has chatted with plus all groups they
     * belong to, attaches each entry's last message, unread count, and
     * metadata, then merges and sorts both sets by last-message time.
     *
     * @param  \App\Models\User  $authUser  The user whose list to build.
     * @param  string|null  $keyword   Optional name/email filter.
     * @param  int          $perPage   Page size (unused here; pagination
     *                                 happens in the caller).
     * @return \Illuminate\Support\Collection  Chat entries sorted newest-first.
     */
    private function getCombinedChatList($authUser, $keyword, $perPage)
    {
        // Optimized query for one-to-one chats
        $usersQuery = User::select('users.id', 'users.first_name', 'users.last_name', 'users.email', 'users.avatar', 'users.last_activity_at')
            ->where('users.id', '!=', $authUser->id)
            ->whereExists(function ($query) use ($authUser) {
                $query->select(DB::raw(1))
                    ->from('chats')
                    ->whereColumn('chats.sender_id', 'users.id')
                    ->where('chats.receiver_id', $authUser->id)
                    ->orWhere(function ($q) use ($authUser) {
                        $q->whereColumn('chats.receiver_id', 'users.id')
                            ->where('chats.sender_id', $authUser->id);
                    });
            });

        if ($keyword) {
            $usersQuery->where(function ($q) use ($keyword) {
                $q->where('first_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('last_name', 'LIKE', "%{$keyword}%")
                    ->orWhere('email', 'LIKE', "%{$keyword}%")
                    ->orWhere('username', 'LIKE', "%{$keyword}%");
            });
        }

        $users = collect($usersQuery->get()->map(function ($user) use ($authUser) {
            // Get last message efficiently
            $lastChat = Chat::where('room_id', function ($query) use ($user, $authUser) {
                $query->select('id')
                    ->from('rooms')
                    ->where(function ($q) use ($user, $authUser) {
                        $q->where('user_one_id', min($authUser->id, $user->id))
                            ->where('user_two_id', max($authUser->id, $user->id));
                    })
                    ->limit(1);
            })
                ->latest()
                ->first(['text', 'file', 'file_type', 'created_at']);

            // Get or create room
            $room = Room::firstOrCreate([
                'user_one_id' => min($authUser->id, $user->id),
                'user_two_id' => max($authUser->id, $user->id),
            ]);

            // Get unread count
            $unreadCount = Chat::where('receiver_id', $authUser->id)
                ->where('sender_id', $user->id)
                ->where('status', '!=', 'read')
                ->count();

            return (object) [
                'type' => 'single',
                'room_id' => $room->id,
                'id' => $user->id,
                'name' => trim("{$user->first_name} {$user->last_name}"),
                'avatar' => $user->avatar ? asset($user->avatar) : asset('default/default_image.jpg'),
                'last_message' => $lastChat?->text,
                'last_message_file' => $lastChat?->file,
                'last_message_time' => $lastChat?->created_at,
                'is_active' => $user->last_activity_at && $user->last_activity_at->gt(now()->subMinutes(5)),
                'member_count' => null,
                'unread_count' => $unreadCount,
            ];
        }));

        // Optimized query for groups
        $groupsQuery = Group::whereHas('members', fn($q) => $q->where('user_id', $authUser->id));

        if ($keyword) {
            $groupsQuery->where('name', 'LIKE', "%{$keyword}%");
        }

        $groups = collect($groupsQuery->get()->map(function ($group) use ($authUser) {
            $lastMessage = $group->messages()->latest()->first(['text', 'file', 'file_type', 'created_at']);

            // Get unread count for group
            $unreadCount = $group->messages()
                ->where('sender_id', '!=', $authUser->id)
                ->whereDoesntHave('readBy', function ($query) use ($authUser) {
                    $query->where('user_id', $authUser->id);
                })
                ->count();

            return (object) [
                'type' => 'group',
                'room_id' => $group->id,
                'id' => $group->id,
                'name' => $group->name,
                'avatar' => $group->avatar ? asset($group->avatar) : asset('default/default_group.jpg'),
                'last_message' => $lastMessage?->text,
                'last_message_file' => $lastMessage?->file,
                'last_message_time' => $lastMessage?->created_at,
                'is_active' => false,
                'member_count' => $group->members()->count(),
                'unread_count' => $unreadCount,
            ];
        }));

        // Merge and sort by last message time
        return $users->merge($groups)
            ->sortByDesc(fn($chat) => $chat->last_message_time)
            ->values();
    }

    /**
     * Forward an existing message to one or more users.
     *
     * Inside a transaction, copies the original message's text/file
     * into a fresh `chats` row for each recipient (self is skipped),
     * stamps `forwarded_from`, and broadcasts each via
     * `MessageSendEvent`. The transaction-failure branch returns a
     * verbatim 500 envelope (as the original controller did) rather than
     * throwing.
     *
     * @param  Request  $request  Body: message_id, receiver_ids (array).
     * @return array{0: string, 1: int, 2: array|null}
     *               [outcome, the forwarded-message count (on success), a
     *               verbatim error-response array (on a 500-class failure)].
     *
     * @throws ApiException  404 if the original message is missing (dead
     *                       code — the `exists` validator returns 422 first).
     */
    public function forwardMessage(Request $request): array
    {
        $authUser = Auth::guard('api')->user();
        $originalMessage = Chat::with('sender', 'receiver')->find($request->message_id);

        if (!$originalMessage) {
            throw new ApiException('Message not found', 404);
        }

        $forwardedMessages = [];

        DB::beginTransaction();
        try {
            foreach ($request->receiver_ids as $receiverId) {
                if ($receiverId == $authUser->id) {
                    continue; // Skip self
                }

                // Create room
                $room = Room::firstOrCreate([
                    'user_one_id' => min($authUser->id, $receiverId),
                    'user_two_id' => max($authUser->id, $receiverId)
                ]);

                // Forward message
                $forwardedMessage = Chat::create([
                    'sender_id' => $authUser->id,
                    'receiver_id' => $receiverId,
                    'text' => $originalMessage->text,
                    'file' => $originalMessage->file,
                    'file_type' => $originalMessage->file_type,
                    'room_id' => $room->id,
                    'status' => 'sent',
                    'is_blurred' => false,
                    'is_viewed' => false,
                    'message_type' => 'normal',
                    'forwarded_from' => $originalMessage->sender_id,
                ]);

                $forwardedMessages[] = $forwardedMessage;

                // Broadcast
                broadcast(new MessageSendEvent($forwardedMessage))->toOthers();
            }

            DB::commit();

            return ['success', count($forwardedMessages), null];
        } catch (Exception $e) {
            DB::rollBack();

            return ['error', 0, [
                'success' => false,
                'message' => 'Failed to forward message',
                'code' => 500
            ]];
        }
    }

    /**
     * Broadcast the auth user's typing status to the other participant.
     *
     * Fires `UserTypingEvent` over WebSockets only — nothing is
     * persisted; it just drives the recipient's "typing…" indicator.
     *
     * NOTE: this references `\App\Events\UserTypingEvent`, a class that
     * does not exist (the real one is `\App\Events\Chat\V2\UserTypingEvent`).
     * This is a pre-existing bug — every valid call 500s. It is preserved
     * verbatim from the original controller and must not be "fixed".
     *
     * @param  Request  $request      Body: is_typing (boolean).
     * @param  int      $receiver_id  Who should see the indicator.
     * @return void
     */
    public function typingStatus(Request $request, $receiver_id): void
    {
        $authUser = Auth::guard('api')->user();

        // Broadcast typing status
        broadcast(new \App\Events\UserTypingEvent([
            'user_id' => $authUser->id,
            'receiver_id' => $receiver_id,
            'is_typing' => $request->is_typing,
        ]))->toOthers();
    }
}
