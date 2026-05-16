<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

/**
 * Notification telling a user that someone replied to their post comment.
 *
 * Sent to the original commenter when another user posts a reply to their
 * comment on a post. Delivered through the `database` channel so it
 * appears in the recipient's in-app notification feed.
 */
class PostReplyCommentNotification extends Notification
{
    use Queueable;

    /** @var mixed The user who posted the reply. */
    protected $replyUser;

    /** @var mixed The comment that was replied to. */
    protected $comment;

    /** @var mixed The post the comment belongs to. */
    protected $post;

    /**
     * Create a new notification instance.
     *
     * @param  mixed  $replyUser  The user who replied.
     * @param  mixed  $comment    The comment being replied to.
     * @param  mixed  $post       The post the comment is on.
     */
    public function __construct($replyUser, $comment, $post)
    {
        $this->replyUser = $replyUser;
        $this->comment = $comment;
        $this->post = $post;
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
     * Builds a human-readable message that includes a truncated snippet
     * of the post content so the feed entry stays short.
     *
     * @param  object  $notifiable  The entity receiving the notification.
     * @return array  Notification payload persisted to the notifications table.
     */
    public function toArray(object $notifiable): array
    {
        $contentWords = explode(' ', strip_tags($this->post->content));
        $shortContent = implode(' ', array_slice($contentWords, 0, 3)) . (count($contentWords) > 3 ? '...' : '');

        return [
            'reply_user_id' => $this->replyUser->id,
            'reply_user_name' => $this->replyUser->name,
            'reply_user_avatar' => $this->replyUser->avatar,
            'message'           => "{$this->replyUser->name} replied to your comment on '{$shortContent}'",
            'post_id' => $this->post->id,
            'comment_id' => $this->comment->id,
            'created_at' => now()->toDateTimeString(),
        ];
    }
}
