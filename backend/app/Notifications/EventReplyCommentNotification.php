<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

/**
 * Notification telling a user that someone replied to their event comment.
 *
 * Sent to the original commenter when another user posts a reply to their
 * comment on an event. Delivered through the `database` channel so it
 * appears in the recipient's in-app notification feed.
 */
class EventReplyCommentNotification extends Notification
{
    use Queueable;

    /** @var mixed The user who posted the reply. */
    protected $replyUser;

    /** @var mixed The comment that was replied to. */
    protected $comment;

    /** @var mixed The event the comment belongs to. */
    protected $event;

    /**
     * Create a new notification instance.
     *
     * @param  mixed  $replyUser  The user who replied.
     * @param  mixed  $comment    The comment being replied to.
     * @param  mixed  $event      The event the comment is on.
     */
    public function __construct($replyUser, $comment, $event)
    {
        $this->replyUser = $replyUser;
        $this->comment = $comment;
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
        return ['database'];
    }


    /**
     * Get the array representation of the notification (stored in DB).
     *
     * Builds a human-readable message that includes a truncated event
     * title so the feed entry stays short.
     *
     * @param  object  $notifiable  The entity receiving the notification.
     * @return array  Notification payload persisted to the notifications table.
     */
    public function toArray(object $notifiable): array
    {
        // Get first 2–3 words of the event title
        $titleWords = explode(' ', strip_tags($this->event->title));
        $shortTitle = implode(' ', array_slice($titleWords, 0, 3)) . (count($titleWords) > 3 ? '...' : '');

        return [
            'reply_user_id' => $this->replyUser->id,
            'reply_user_name' => $this->replyUser->name,
            'reply_user_avatar' => $this->replyUser->avatar,
            'message'           => "{$this->replyUser->name} replied to your comment on '{$shortTitle}'",
            'event_id' => $this->event->id,
            'comment_id' => $this->comment->id,
            'created_at' => now()->toDateTimeString(),
        ];
    }
}
