<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

/**
 * Notification telling a user that someone started following them.
 *
 * Sent to the followed user when another user follows them. Delivered
 * through the `database` channel so it appears in the recipient's in-app
 * notification feed.
 */
class FollowNotification extends Notification
{
    use Queueable;

    /** @var mixed The user who performed the follow action. */
    protected $authUser;

    /**
     * Create a new notification instance.
     *
     * @param  mixed  $authUser  The user who started following.
     */
    public function __construct($authUser)
    {
        $this->authUser = $authUser;
    }

    /**
     * Get the notification delivery channels.
     *
     * @param  object  $notifiable  The entity receiving the notification.
     * @return array Delivery channels (database only).
     */
    public function via(object $notifiable): array
    {
        return ['database'];
    }

    /**
     * Get the array representation of the notification (stored in DB).
     *
     * @param  object  $notifiable  The entity receiving the notification.
     * @return array Notification payload persisted to the notifications table.
     */
    public function toArray(object $notifiable): array
    {
        return [
            'follower_id' => $this->authUser->id,
            'follower_name' => $this->authUser->f_name.' '.$this->authUser->l_name,
            'follower_avatar' => $this->authUser->avatar,
            'message' => "{$this->authUser->f_name} started following you.",
            'created_at' => now()->toDateTimeString(),
        ];
    }
}
