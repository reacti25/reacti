<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

/**
 * Notification confirming that a user's post was created successfully.
 *
 * Sent to the post author immediately after they create a post.
 * Implements {@see ShouldQueue} so delivery is processed off-request via
 * the queue. Delivered through the `database` channel only, so it shows
 * up in the user's in-app notification feed.
 */
class PostCreateNotification extends Notification implements ShouldQueue
{
    use Queueable;

    /** @var mixed The post that was created. */
    protected $post;

    /**
     * Create a new notification instance.
     *
     * @param  mixed  $post  The newly created post model.
     */
    public function __construct($post)
    {
        $this->post = $post;
    }

    /**
     * Get the notification delivery channels.
     *
     * @param  object  $notifiable  The entity receiving the notification.
     * @return array Delivery channels (database only).
     */
    public function via(object $notifiable): array
    {
        return ['database']; // You can also add 'broadcast', 'mail', etc.
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
            'post_id' => $this->post->id,
            'message' => 'Your post has been created successfully!',
            'created_at' => now()->toDateTimeString(),
        ];
    }
}
