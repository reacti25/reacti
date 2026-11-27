<?php

namespace App\Http\Controllers\Api\Chat\Group;

use App\Http\Controllers\Controller;
use App\Services\GroupOneTimeMediaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * One-time media in group chats: the file link, "watched to the end" and
 * screenshot reports. The rules live in {@see GroupOneTimeMediaService}; these
 * are the 1:1 actions of ChatController, per member.
 */
class GroupOneTimeController extends Controller
{
    public function __construct(private readonly GroupOneTimeMediaService $oneTimeMedia) {}

    /**
     * Stream a one-time photo or video to the member the link was made for.
     *
     * Public route guarded by the signature in the link, not a login, like
     * the 1:1 one. `no-store` keeps the CDN and any proxy from holding a copy.
     *
     * @param  int  $message_id  The group message the link names.
     * @param  int  $user_id  The member the link was made for.
     * @param  string  $signature  The HMAC from the link.
     * @return BinaryFileResponse|JsonResponse The file, or a 404 envelope.
     */
    public function media($message_id, $user_id, string $signature)
    {
        $path = $this->oneTimeMedia->resolvePath((int) $message_id, (int) $user_id, $signature);
        if ($path === null) {
            return $this->answer(false, 'Media not available');
        }

        $response = response()->file($path);
        $response->setPrivate();
        $response->headers->addCacheControlDirective('no-store');

        return $response;
    }

    /**
     * The caller watched this one-time media or reaction to the end.
     *
     * @param  int  $message_id  The one-time message.
     */
    public function finish($message_id): JsonResponse
    {
        $done = $this->oneTimeMedia->finish((int) $message_id, (int) Auth::guard('api')->id());

        return $this->answer($done, $done ? 'Marked as watched' : 'Message not found');
    }

    /**
     * The caller took a screenshot while this one-time message was on screen.
     *
     * @param  int  $message_id  The one-time media or reaction.
     */
    public function screenshot($message_id): JsonResponse
    {
        $recorded = $this->oneTimeMedia->recordScreenshot((int) $message_id, (int) Auth::guard('api')->id());

        return $this->answer($recorded, $recorded ? 'Screenshot recorded' : 'Message not found');
    }

    /** The standard envelope: 200 on success, 404 otherwise. */
    private function answer(bool $ok, string $message): JsonResponse
    {
        return response()->json([
            'success' => $ok,
            'message' => $message,
            'data' => null,
            'code' => $ok ? 200 : 404,
        ], $ok ? 200 : 404);
    }
}
