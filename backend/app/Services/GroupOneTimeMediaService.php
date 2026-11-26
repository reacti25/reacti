<?php

namespace App\Services;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsEvents;
use App\Events\GroupOneTimeChangedEvent;
use App\Models\GroupMessage;
use App\Models\GroupMessageUserStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * One-time ("view once") media in group chats.
 *
 * The group version of {@see OneTimeMediaService} (1:1), kept apart so the
 * 1:1 rules stay as they are. What differs:
 *
 * - **Once per person.** Each member opens the photo or video once, and each
 *   member plays each reaction to it once (the media's sender included). A
 *   member's `group_message_user_statuses` row carries their own `opened_at`
 *   and `done_at`, and every member gets their own signed link, so one
 *   person opening it does not close it for the others.
 * - **Everyone sees the reactions**, once each. Others' reactions stay hidden
 *   until the member reacted themselves (the existing react-to-unlock gate in
 *   {@see GroupMessageService}).
 * - **Erased after 24 hours**, for everyone, seen or not; sooner once every
 *   member is done with the media and with every reaction. The media's row
 *   stays as the trace ("One-time photo · 5 of 7 reacted").
 *
 * Only members who were in the group when it was sent have a status row, so
 * someone who joins later never sees it.
 *
 * Files are stored and served exactly like the 1:1 ones: private `local`
 * disk, `no-store`, a signed link with no extension.
 */
class GroupOneTimeMediaService
{
    /** Hours an exchange lives before it is erased for everyone. */
    public const TTL_HOURS = 24;

    public function __construct(private readonly Analytics $analytics) {}

    /**
     * The link [$viewerId] loads [$message]'s media from, or null when they
     * may not (any more): erased, past 24 hours, not a member when it was
     * sent, or already watched.
     *
     * @param  GroupMessage  $message  A one-time media or reaction message.
     * @param  int  $viewerId  The member the link is for.
     */
    public static function url(GroupMessage $message, int $viewerId): ?string
    {
        $status = GroupMessageUserStatus::where('message_id', $message->id)->where('user_id', $viewerId)->first();
        if (! self::isFetchable($message, $status)) {
            return null;
        }

        return route('group.one-time-media', [
            'message_id' => $message->id,
            'user_id' => $viewerId,
            'signature' => self::signature($message->id, $viewerId),
        ]);
    }

    /**
     * Absolute path of the file to stream for a link, or null when the
     * signature is wrong, the link is spent, or the file is gone.
     */
    public function resolvePath(int $messageId, int $userId, string $signature): ?string
    {
        if (! hash_equals(self::signature($messageId, $userId), $signature)) {
            return null;
        }

        $message = GroupMessage::where('id', $messageId)->where('one_time', true)->first();
        if (! $message) {
            return null;
        }
        $status = GroupMessageUserStatus::where('message_id', $messageId)->where('user_id', $userId)->first();
        if (! self::isFetchable($message, $status) || ! Storage::disk('local')->exists($message->file)) {
            return null;
        }

        return Storage::disk('local')->path($message->file);
    }

    /**
     * Whether a reaction may still be sent to [$mediaId]: false once that
     * one-time media is erased or past its 24 hours (a late upload would
     * outlive the exchange).
     */
    public static function acceptsReactionTo(?int $mediaId): bool
    {
        $media = $mediaId ? GroupMessage::find($mediaId) : null;

        return $media === null || ! $media->one_time || ! self::isOver($media);
    }

    /**
     * [$userId] opened this one-time media or started playing this reaction:
     * stamp their row once. From now on their link works for
     * {@see OneTimeMediaService::OPEN_WINDOW_MINUTES} only.
     */
    public function markOpened(int $messageId, int $userId): void
    {
        GroupMessageUserStatus::where('message_id', $messageId)
            ->where('user_id', $userId)
            ->whereNull('opened_at')
            ->update(['opened_at' => now()]);
    }

    /**
     * [$userId]'s app watched this one-time media or reaction to the end:
     * their link dies now, and the exchange is erased if that was the last
     * one anybody had left.
     *
     * @return bool False when it is not a one-time message this member was sent.
     */
    public function finish(int $messageId, int $userId): bool
    {
        $message = GroupMessage::where('id', $messageId)->where('one_time', true)->first();
        $updated = $message === null ? 0 : GroupMessageUserStatus::where('message_id', $messageId)
            ->where('user_id', $userId)
            ->where('user_id', '!=', $message->sender_id)
            ->update(['done_at' => now()]);
        if ($updated === 0) {
            return false;
        }
        $this->markOpened($messageId, $userId);

        $this->sweep($message->group_id);

        return true;
    }

    /**
     * A member took a screenshot while this one-time message was on their
     * screen (iPhone): stamp it, so its sender's tile says so. The first
     * report is kept; only someone it was sent to may report it.
     *
     * @return bool False when it is not a one-time message this member was sent.
     */
    public function recordScreenshot(int $messageId, int $userId): bool
    {
        $message = GroupMessage::where('id', $messageId)->where('one_time', true)->first();
        $isRecipient = $message !== null && (int) $message->sender_id !== $userId
            && GroupMessageUserStatus::where('message_id', $messageId)->where('user_id', $userId)->exists();
        if (! $isRecipient) {
            return false;
        }
        if ($message->one_time_screenshot_at === null) {
            $message->update(['one_time_screenshot_at' => now()]);
            $this->announce($message->group_id);
        }

        return true;
    }

    /**
     * Erase every exchange in [$groupId] (every group when null) that is past
     * 24 hours or that every member is done with.
     *
     * ponytail: runs when a member loads the group (and from the prune
     * command), not on a timer, because the servers run no scheduler; until
     * then an expired file is already unfetchable. A member who left the group
     * without finishing keeps an exchange until its 24 hours are up.
     *
     * @return int How many exchanges were erased.
     */
    public function sweep(?int $groupId = null): int
    {
        // withTrashed: a one-timer its sender deleted for everyone still has
        // reactions and files to erase.
        $live = GroupMessage::withTrashed()->where('one_time', true)
            ->where('message_type', '!=', 'reaction')
            ->whereNull('one_time_erased_at')
            ->when($groupId, fn (Builder $q) => $q->where('group_id', $groupId))
            ->get();

        return $live->filter(function (GroupMessage $media) {
            if (self::isOver($media)) {
                return $this->erase($media, 'expired');
            }

            return $this->everyoneIsDone($media) && $this->erase($media, 'watched');
        })->count();
    }

    /**
     * Remove a whole exchange for good: every reaction and every file. The
     * media's row stays as the trace, emptied of its caption, with how many of
     * its members reacted. Members' open chats reload on the signal.
     *
     * @param  string  $reason  `watched` or `expired` (analytics only).
     * @return bool False when it was erased already.
     */
    public function erase(GroupMessage $media, string $reason): bool
    {
        $reactions = $this->reactionsTo($media);
        $recipients = GroupMessageUserStatus::where('message_id', $media->id)
            ->where('user_id', '!=', $media->sender_id)
            ->count();

        $erased = GroupMessage::withTrashed()->whereKey($media->id)->whereNull('one_time_erased_at')->update([
            'one_time_erased_at' => now(),
            'text' => null,
            'one_time_reacted' => $reactions->pluck('sender_id')->unique()->count(),
            'one_time_recipients' => $recipients,
        ]);
        if ($erased === 0) {
            return false;
        }

        // Hard delete, not the soft delete of ordinary messages: "gone from the
        // server" is the feature. Their status rows go with them (cascade).
        GroupMessage::whereIn('id', $reactions->pluck('id'))->forceDelete();
        Storage::disk('local')->delete(
            $reactions->pluck('file')->push($media->file)
                ->filter(fn ($file) => OneTimeMediaService::isOneTimePath($file))->values()->all()
        );

        $this->announce($media->group_id);
        $this->analytics->track(
            AnalyticsEvents::ONE_TIME_ERASED,
            ['reason' => $reason, 'scope' => 'group'],
            (string) $media->sender_id,
        );

        return true;
    }

    /**
     * Whether every member is done with [$media] and with every reaction to it.
     * A member is done once their app said so or their open window has passed.
     */
    private function everyoneIsDone(GroupMessage $media): bool
    {
        foreach ($this->reactionsTo($media)->push($media) as $message) {
            $pending = GroupMessageUserStatus::where('message_id', $message->id)
                ->where('user_id', '!=', $message->sender_id)
                ->where(fn (Builder $q) => $q->whereNull('opened_at')->orWhere(
                    fn (Builder $q) => $q->whereNull('done_at')
                        ->where('opened_at', '>=', now()->subMinutes(OneTimeMediaService::OPEN_WINDOW_MINUTES))
                ))
                ->exists();
            if ($pending) {
                return false;
            }
        }

        return true;
    }

    /** @return Collection<int, GroupMessage> The reactions sent to [$media]. */
    private function reactionsTo(GroupMessage $media): Collection
    {
        return GroupMessage::where('reply_to_message_id', $media->id)
            ->where('message_type', 'reaction')
            ->withTrashed()
            ->get();
    }

    /** Tell every member's open chat to reload: a one-time message changed. */
    private function announce(int $groupId): void
    {
        try {
            broadcast(new GroupOneTimeChangedEvent($groupId));
        } catch (\Throwable $e) {
            Log::error('Group one-time broadcast failed', ['group_id' => $groupId, 'error' => $e->getMessage()]);
        }
    }

    /** Whether [$media] (or the media a reaction answers) is erased or past 24 hours. */
    private static function isOver(GroupMessage $message): bool
    {
        /** @var GroupMessage|null $media */
        $media = $message->message_type === 'reaction' ? $message->replyTo : $message;

        return $media === null
            || $media->one_time_erased_at !== null
            || $media->created_at->lt(now()->subHours(self::TTL_HOURS));
    }

    /**
     * A member may fetch until they are done with it: their row exists (they
     * were in the group when it was sent), it is not their own message (its
     * sender's app shows a label instead, as in 1:1), and they have not
     * finished it or opened it longer ago than the open window.
     */
    private static function isFetchable(GroupMessage $message, ?GroupMessageUserStatus $status): bool
    {
        return $message->file !== null
            && $status !== null
            && (int) $status->user_id !== (int) $message->sender_id
            && ! self::isOver($message)
            && $status->done_at === null
            && ($status->opened_at === null
                || $status->opened_at->gt(now()->subMinutes(OneTimeMediaService::OPEN_WINDOW_MINUTES)));
    }

    /** HMAC proving this server issued the link for this message and member. */
    private static function signature(int $messageId, int $userId): string
    {
        return hash_hmac('sha256', 'group-one-time-media:'.$messageId.':'.$userId, config('app.key'));
    }
}
