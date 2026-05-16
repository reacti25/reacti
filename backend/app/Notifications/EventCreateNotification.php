<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\BroadcastMessage;

/**
 * Notification confirming that a user's event was created successfully.
 *
 * Sent to the event owner immediately after they create an event.
 * Implements {@see ShouldQueue} so delivery is processed off-request via
 * the queue. Delivered through the `database` channel only, so it shows
 * up in the user's in-app notification feed.
 */
class EventCreateNotification extends Notification implements ShouldQueue
{
    use Queueable;

    /** @var mixed The event that was created. */
    protected $event;

    /**
     * Create a new notification instance.
     *
     * @param  mixed  $event  The newly created event model.
     */
    public function __construct($event)
    {
        $this->event = $event;
    }

    /**
     * Get the notification delivery channels.
     *
     * @param  object  $notifiable  The entity receiving the notification.
     * @return array  Delivery channels (database only).
     */
    public function via(object $notifiable): array
    {
        return ['database']; // You can also add 'broadcast', 'mail', etc.
    }

    /**
     * Get the array representation of the notification (stored in DB).
     *
     * @param  object  $notifiable  The entity receiving the notification.
     * @return array  Notification payload persisted to the notifications table.
     */
    public function toArray(object $notifiable): array
    {
        return [
            'event_id'     => $this->event->id,
            'event_title'  => $this->event->title,
            'banner'       => $this->event->banner,
            'message'      => 'Your event has been created successfully!',
            'created_at'   => now()->toDateTimeString(),
        ];
    }
}
