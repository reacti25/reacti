<?php

namespace App\Http\Controllers\Api\Notification;

use Exception;
use App\Traits\ApiResponse;
use Illuminate\Support\Facades\Log;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Auth;
use App\Exceptions\ApiException;
use App\Services\NotificationService;

/**
 * Exposes the authenticated user's database notifications.
 *
 * Backs the authenticated notification routes: listing unread
 * notifications and marking one or all of them as read. Notifications
 * are Laravel database notifications; the raw class names are mapped
 * to short type labels for the client. This is a thin controller — it
 * resolves the auth user and delegates to {@see NotificationService}.
 *
 * Note: this controller is currently unrouted dead code — no
 * notification routes are registered.
 */
class NotificationController extends Controller
{
    use ApiResponse;

    /**
     * @param  NotificationService  $notificationService  Notification business logic.
     */
    public function __construct(private readonly NotificationService $notificationService)
    {
        parent::__construct();
    }

    /**
     * List the auth user's unread notifications, newest first.
     *
     * The fully-qualified notification class name is mapped to a short
     * `type` label the client can switch on. Delegates to
     * {@see NotificationService::allNotifications()}.
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

            $result = $this->notificationService->allNotifications($user);

            return $this->success($result, 'Unread notifications retrieved successfully.', 200);
        } catch (Exception $e) {
            Log::error('Notification fetch error: ' . $e->getMessage());
            return $this->error([], 'Something went wrong.', 500);
        }
    }

    /**
     * Mark a single notification as read.
     *
     * Scoped to the auth user's own notifications, so a foreign id
     * yields 404. Delegates to {@see NotificationService::readNotification()}.
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

            $this->notificationService->readNotification($user, $id);

            return $this->success([], 'Notification marked as read successfully.', 200);
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            Log::info($e->getMessage());
            return $this->error([], $e->getMessage(), 500);
        }
    }

    /**
     * Mark every one of the auth user's notifications as read.
     *
     * Delegates to {@see NotificationService::readAllNotifications()}.
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

            $this->notificationService->readAllNotifications($user);

            return $this->success([], 'All notifications marked as read successfully.', 200);
        } catch (Exception $e) {
            Log::error('Notification mark-all error: ' . $e->getMessage());
            return $this->error([], 'Something went wrong.', 500);
        }
    }
}
