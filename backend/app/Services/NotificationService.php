<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\User;

/**
 * Business logic for the authenticated user's database notifications.
 *
 * Extracted from {@see \App\Http\Controllers\Api\Notification\NotificationController}
 * so the controller only resolves the user and shapes responses. Expected
 * business-rule failures are raised as {@see ApiException} with the same
 * status code the controller previously returned inline.
 *
 * Note: the source controller is currently *unrouted dead code* — no
 * notification routes are registered — so the runtime behaviour of these
 * methods is moot. They are refactored verbatim purely for consistency with
 * the rest of the service layer.
 */
class NotificationService
{
    /**
     * List the user's unread notifications, newest first.
     *
     * The fully-qualified notification class name is mapped to a short
     * `type` label the client can switch on.
     *
     * @param  User  $user  The authenticated user.
     * @return array ['count' => int, 'notifications' => \Illuminate\Support\Collection].
     */
    public function allNotifications(User $user): array
    {
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
                'id' => $notification->id,
                'data' => $notification->data,
                'type' => $typeLabel,
                'read_at' => $notification->read_at,
                'created_at' => $notification->created_at->diffForHumans(),
            ];
        });

        return [
            'count' => $count,
            'notifications' => $notifications,
        ];
    }

    /**
     * Mark a single notification as read.
     *
     * Scoped to the user's own notifications, so a foreign id yields a
     * 404 {@see ApiException}.
     *
     * @param  User  $user  The authenticated user.
     * @param  string  $id  The notification id (UUID).
     *
     * @throws ApiException 404 when the notification is not found.
     */
    public function readNotification(User $user, $id): void
    {
        $notification = $user->notifications()->where('id', $id)->first();

        if (! $notification) {
            throw new ApiException('Notification not found.', 404);
        }

        $notification->markAsRead();
    }

    /**
     * Mark every one of the user's notifications as read.
     *
     * @param  User  $user  The authenticated user.
     */
    public function readAllNotifications(User $user): void
    {
        $user->unreadNotifications->markAsRead();
    }
}
