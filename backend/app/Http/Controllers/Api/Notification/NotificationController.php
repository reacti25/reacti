<?php

namespace App\Http\Controllers\Api\Notification;

use Exception;
use App\Traits\ApiResponse;
use Illuminate\Support\Facades\Log;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Auth;

/**
 * Exposes the authenticated user's database notifications.
 *
 * Backs the authenticated notification routes: listing unread
 * notifications and marking one or all of them as read. Notifications
 * are Laravel database notifications; the raw class names are mapped
 * to short type labels for the client.
 */
class NotificationController extends Controller
{
    use ApiResponse;

    /**
     * List the auth user's unread notifications, newest first.
     *
     * The fully-qualified notification class name is mapped to a short
     * `type` label the client can switch on.
     *
     * @return \Illuminate\Http\JsonResponse  Unread count + notifications,
     *                                        or 401 if unauthenticated, 500 on error
     */
    // get all notifications
    public function allNotifications()
    {
        try {
            $user = Auth::user();
            if (!$user) {
                return $this->error([], 'User not authenticated.', 401);
            }

            // Fetch unread notifications
            $notifications = $user->notifications()
                ->whereNull('read_at')
                ->orderBy('created_at', 'desc')
                ->get();

            $count = $notifications->count();

            $notifications = $notifications->map(function ($notification) {
                $typeMap = [
                    'App\\Notifications\\PostCreateNotification' => 'post',
                    'App\\Notifications\\EventCreateNotification' => 'event',
                    'App\\Notifications\\EventReplyCommentNotification' => 'event_comment_reply',
                    'App\\Notifications\\FollowNotification' => 'follow',
                    'App\\Notifications\\PostReplyCommentNotification' => 'post_comment_reply',
                ];

                $typeLabel = $typeMap[$notification->type] ?? 'unknown';

                return [
                    'id'          => $notification->id,
                    'data'        => $notification->data,
                    'type'        => $typeLabel,
                    'read_at'     => $notification->read_at,
                    'created_at'  => $notification->created_at->diffForHumans(),
                ];
            });

            return $this->success([
                'count'         => $count,
                'notifications' => $notifications,
            ], 'Unread notifications retrieved successfully.', 200);
        } catch (Exception $e) {
            Log::error('Notification fetch error: ' . $e->getMessage());
            return $this->error([], 'Something went wrong.', 500);
        }
    }

    /**
     * Mark a single notification as read.
     *
     * Scoped to the auth user's own notifications, so a foreign id
     * yields 404.
     *
     * @param  string  $id  URL param: the notification id (UUID)
     * @return \Illuminate\Http\JsonResponse  Success, 401 if unauthenticated,
     *                                        404 if not found, 500 on error
     */
    //mark as read specific notification
    public function readNotification($id)
    {
        try {
            $user = Auth::user();
            if (!$user) {
                return $this->error([], 'User not authenticated.', 401);
            }

            $notification = $user->notifications()->where('id', $id)->first();

            if (!$notification) {
                return $this->error([], 'Notification not found.', 404);
            }

            $notification->markAsRead();

            return $this->success([], 'Notification marked as read successfully.', 200);
        } catch (Exception $e) {
            Log::info($e->getMessage());
            return $this->error([], $e->getMessage(), 500);
        }
    }

    /**
     * Mark every one of the auth user's notifications as read.
     *
     * @return \Illuminate\Http\JsonResponse  Success, 401 if unauthenticated,
     *                                        500 on error
     */
    //mark as read all notification
    public function readAllNotifications()
    {
        try {
            $user = Auth::user();
            if (!$user) {
                return $this->error([], 'User not authenticated.', 401);
            }

            $user->unreadNotifications->markAsRead();

            return $this->success([], 'All notifications marked as read successfully.', 200);
        } catch (Exception $e) {
            Log::error('Notification mark-all error: ' . $e->getMessage());
            return $this->error([], 'Something went wrong.', 500);
        }
    }
}
