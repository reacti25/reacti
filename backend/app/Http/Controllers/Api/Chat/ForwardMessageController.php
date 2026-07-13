<?php

namespace App\Http\Controllers\Api\Chat;

use App\Http\Controllers\Controller;
use App\Http\Requests\Chat\ForwardMessageRequest;
use App\Models\Chat;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\User;
use App\Services\ChatService;
use App\Services\GroupMessageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

/**
 * Forwards a message to one or more recipients (1:1 chats and/or groups).
 *
 * Thin controller: it resolves and authorizes the source message, then loops
 * the recipients, delegating each create to {@see ChatService::forwardToUser()}
 * or {@see GroupMessageService::forwardToGroup()}. Invalid recipients (a group
 * the caller isn't in, a missing/self user) are skipped rather than failing the
 * whole batch; the response reports how many were forwarded.
 */
class ForwardMessageController extends Controller
{
    /**
     * @param  ChatService  $chatService  1:1 forwarding.
     * @param  GroupMessageService  $groupMessageService  Group forwarding.
     */
    public function __construct(
        private readonly ChatService $chatService,
        private readonly GroupMessageService $groupMessageService,
    ) {
        parent::__construct();
    }

    /**
     * Forward the source message to every valid recipient.
     *
     * @param  ForwardMessageRequest  $request  Body: message_id, source_type, recipients[]
     */
    public function forward(ForwardMessageRequest $request): JsonResponse
    {
        $authUser = Auth::guard('api')->user();

        // Resolve + authorize the source message, extracting the text/file to copy.
        $source = $this->resolveSource($request->source_type, (int) $request->message_id, $authUser);
        if (! $source) {
            return response()->json([
                'success' => false,
                'message' => 'Message not found or you cannot forward it',
                'data' => null,
                'code' => 404,
            ], 404);
        }

        [$text, $file, $forwardedFrom] = $source;

        // Fan out to each valid recipient; skip ones the caller can't reach.
        $forwarded = 0;
        foreach ($request->recipients as $recipient) {
            $recipientId = (int) $recipient['id'];

            if ($recipient['type'] === 'single') {
                if ($recipientId === $authUser->id || ! User::whereKey($recipientId)->exists()) {
                    continue;
                }
                $this->chatService->forwardToUser($recipientId, $authUser, $text, $file, $forwardedFrom);
                $forwarded++;
            } else { // group
                $group = Group::find($recipientId);
                if (! $group || ! $group->isMember($authUser->id)) {
                    continue;
                }
                $this->groupMessageService->forwardToGroup($group, $authUser, $text, $file, $forwardedFrom);
                $forwarded++;
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Message forwarded successfully',
            'data' => ['forwarded_count' => $forwarded],
            'code' => 200,
        ]);
    }

    /**
     * Resolve the source message and confirm the caller may forward it.
     *
     * @param  string  $sourceType  `single` (a Chat) or `group` (a GroupMessage).
     * @param  int  $messageId  The source message id.
     * @param  User  $authUser  The forwarding user.
     * @return array{0: string|null, 1: string|null, 2: int}|null
     *                                                            [text, stored-file-path, original-author-id], or null when the
     *                                                            message is missing or not visible to the caller.
     */
    private function resolveSource(string $sourceType, int $messageId, User $authUser): ?array
    {
        if ($sourceType === 'single') {
            $chat = Chat::where('id', $messageId)
                ->where(function ($q) use ($authUser) {
                    $q->where('sender_id', $authUser->id)->orWhere('receiver_id', $authUser->id);
                })
                ->first();

            if (! $chat) {
                return null;
            }

            // Preserve the original author when re-forwarding an already-forwarded message.
            return [$chat->text, $chat->getRawOriginal('file'), $chat->forwarded_from ?? $chat->sender_id];
        }

        $message = GroupMessage::find($messageId);
        if (! $message) {
            return null;
        }

        $group = Group::find($message->group_id);
        if (! $group || ! $group->isMember($authUser->id)) {
            return null;
        }

        return [$message->text, $message->getRawOriginal('file'), $message->forwarded_from ?? $message->sender_id];
    }
}
