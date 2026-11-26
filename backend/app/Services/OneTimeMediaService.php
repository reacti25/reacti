<?php

namespace App\Services;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsEvents;
use App\Events\MessageDeletedEvent;
use App\Events\OneTimeScreenshotEvent;
use App\Models\Chat;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * One-time ("view once") media in 1:1 chats.
 *
 * The exchange has two messages: the photo or video the sender marked
 * one-time, and the reaction recorded while its recipient watched it (the
 * reaction inherits the flag). Both live until the original sender has
 * watched the reaction; then {@see erase()} removes the reaction and both
 * files, and leaves the media's row empty as a trace: both chats show one
 * quiet line where it was ("One-time photo · reacted").
 *
 * Why the files are private: ordinary chat media sits under `public/uploads`
 * behind the CDN, which keeps its own copy after the server deletes the file.
 * One-time files are stored on the private `local` disk and streamed by
 * {@see resolvePath()} with `no-store`, so deleting the file really is the end
 * of it.
 *
 * Why the link is signed instead of needing a login token: the app's image
 * and video widgets load plain URLs. The first attempt at this feature
 * (July 2026) used a bearer-token endpoint and every widget that forgot the
 * header showed a broken tile. The link carries an HMAC of the message id and
 * is only ever handed to the two people in the chat; the open window below,
 * not the link, is what makes it one-time.
 *
 * Groups later: the rules live in this one class, not in ChatService, so a
 * group version is the same three pieces keyed per recipient (an opened stamp
 * per member, erase once every member's reaction was watched).
 */
class OneTimeMediaService
{
    /** Folder on the private `local` disk; also the stored-path prefix. */
    public const DIR = 'one-time';

    /**
     * Minutes a file stays fetchable after its recipient opened it. Long
     * enough to finish a video on a slow connection; after it the link is dead
     * even if the app never said "done" (force-quit, lost signal).
     */
    public const OPEN_WINDOW_MINUTES = 10;

    /** Days an exchange may wait unfinished before it is erased anyway. */
    public const TTL_DAYS = 14;

    public function __construct(private readonly Analytics $analytics) {}

    /**
     * Store an upload on the private disk under an unguessable name.
     *
     * @param  UploadedFile  $file  The validated photo or video.
     * @return string Stored path, e.g. `one-time/chat/<40 chars>.jpg`.
     */
    public function store(UploadedFile $file): string
    {
        $ext = strtolower($file->getClientOriginalExtension()) ?: ($file->guessExtension() ?? 'bin');

        return $file->storeAs(self::DIR.'/chat', Str::random(40).'.'.$ext, 'local');
    }

    /** Whether [$path] (a stored `file` value) is a private one-time file. */
    public static function isOneTimePath(?string $path): bool
    {
        return $path !== null && str_starts_with($path, self::DIR.'/');
    }

    /**
     * The link the app loads this message's media from, or null once it can
     * no longer be fetched.
     *
     * The link deliberately has no file name or extension. The live web server
     * answers any URL ending in `.jpg`, `.mp4` and the like as a static file
     * (and the CDN caches it), so such a link would never reach this app:
     * checked on staging 2026-11-24. The app takes the type from `media_type`
     * and the players from the response's Content-Type.
     */
    public static function url(Chat $chat): ?string
    {
        if (! self::isFetchable($chat)) {
            return null;
        }

        return route('chat.one-time-media', [
            'message_id' => $chat->id,
            'signature' => self::signature($chat->id),
        ]);
    }

    /**
     * Absolute path of the file to stream for a link, or null when the
     * signature is wrong, the window has closed, or the file is gone.
     *
     * @param  int  $messageId  The chat row the link names.
     * @param  string  $signature  The HMAC from the link.
     */
    public function resolvePath(int $messageId, string $signature): ?string
    {
        if (! hash_equals(self::signature($messageId), $signature)) {
            return null;
        }

        $chat = Chat::where('id', $messageId)->where('one_time', true)->first();
        if (! $chat || ! self::isFetchable($chat) || ! Storage::disk('local')->exists($chat->file)) {
            return null;
        }

        return Storage::disk('local')->path($chat->file);
    }

    /**
     * The original sender finished watching the reaction: erase the exchange.
     *
     * Only the reaction's recipient (the person who sent the one-time media)
     * may call this, so the person who was recorded cannot use it to make an
     * unwatched reaction disappear.
     *
     * @param  int  $reactionId  The one-time reaction row.
     * @param  int  $userId  The authenticated caller.
     * @return bool False when there is no such reaction for this caller.
     */
    public function finish(int $reactionId, int $userId): bool
    {
        $reaction = Chat::where('id', $reactionId)
            ->where('receiver_id', $userId)
            ->where('one_time', true)
            ->where('message_type', 'reaction')
            ->first();

        return $reaction !== null && $this->erase($reaction, 'watched');
    }

    /**
     * The person viewing a one-time message took a screenshot of it: stamp
     * the message and tell its sender, whose tile then says so.
     *
     * Only an iPhone reports this: Android blocks the screen while one-time
     * media is open. Only the message's recipient (who can see it) may report
     * it; the first report is kept and a repeat changes nothing.
     *
     * @param  int  $messageId  The one-time media or reaction that was on screen.
     * @param  int  $userId  The authenticated caller.
     * @return bool False when there is no such message for this caller.
     */
    public function recordScreenshot(int $messageId, int $userId): bool
    {
        $message = Chat::where('id', $messageId)
            ->where('receiver_id', $userId)
            ->where('one_time', true)
            ->first();
        if ($message === null) {
            return false;
        }
        if ($message->one_time_screenshot_at !== null) {
            return true;
        }

        $message->update(['one_time_screenshot_at' => now()]);
        try {
            broadcast(new OneTimeScreenshotEvent($message->id, $message->room_id));
        } catch (\Throwable $e) {
            Log::error('One-time screenshot broadcast failed', ['message_id' => $message->id, 'error' => $e->getMessage()]);
        }

        return true;
    }

    /**
     * Erase every exchange between two people that is past its time, so a
     * phone that never reported "done" cannot keep an exchange alive.
     *
     * Runs when either of them loads the conversation. With no pair it sweeps
     * every chat (the `chat:prune-one-time` command).
     *
     * ponytail: swept on conversation load, not on a timer, because the
     * servers run no scheduler today. An exchange nobody comes back to keeps
     * its (already unfetchable) files on disk until the command runs; put the
     * command on a cron when one exists.
     *
     * @param  array{0: int, 1: int}|null  $pair  The two user ids, or null for all chats.
     * @return int How many exchanges were erased.
     */
    public function sweep(?array $pair = null): int
    {
        $scoped = fn () => Chat::where('one_time', true)->whereNull('one_time_erased_at')->when($pair, function (Builder $query) use ($pair) {
            $query->whereIn('sender_id', $pair)->whereIn('receiver_id', $pair);
        });

        // A reaction the original sender started watching: its window is over.
        $watched = $scoped()->where('message_type', 'reaction')
            ->where('one_time_opened_at', '<', now()->subMinutes(self::OPEN_WINDOW_MINUTES))
            ->get();
        // Anything still here after the TTL: never opened, no reaction came
        // back, or the reaction was never watched.
        $stale = $scoped()->where('created_at', '<', now()->subDays(self::TTL_DAYS))->get();

        // filter(), not each(): an exchange can match twice (two stale rows),
        // and the first erase takes both, so only real erasures are counted.
        return $watched->filter(fn (Chat $chat) => $this->erase($chat, 'window_lapsed'))->count()
            + $stale->filter(fn (Chat $chat) => $this->erase($chat, 'expired'))->count();
    }

    /**
     * Remove a whole exchange for good: the reaction and both files, and the
     * bubbles on both phones. Safe to call with either message of the exchange.
     *
     * The reaction is hard deleted, not soft deleted like ordinary messages:
     * "gone from the server" is the feature. The media's row stays as the
     * exchange's trace, stamped erased and emptied of its caption; its file
     * name is kept only so the trace can still say photo or video.
     *
     * @param  Chat  $message  The one-time media or its reaction.
     * @param  string  $reason  `watched`, `window_lapsed` or `expired` (analytics only).
     * @return bool False when another call already erased it.
     */
    public function erase(Chat $message, string $reason): bool
    {
        $rows = $this->exchangeOf($message);
        if ($rows->isEmpty()) {
            return false;
        }

        [$reactions, $media] = $rows->partition(fn (Chat $row) => $row->message_type === 'reaction');
        Chat::whereIn('id', $reactions->pluck('id'))->forceDelete();
        Chat::whereIn('id', $media->pluck('id'))->update(['one_time_erased_at' => now(), 'text' => null]);
        Storage::disk('local')->delete(
            $rows->pluck('file')->filter(fn ($file) => self::isOneTimePath($file))->values()->all()
        );

        foreach ($rows as $row) {
            // To everyone on the room channel, the caller included: the phone
            // that reported "done" removes its bubbles on the same signal.
            // `one_time_erased` tells the app to show the trace instead; an
            // older app removes the bubble and shows the trace after a reload.
            $type = $row->message_type === 'reaction' ? 'for_everyone' : 'one_time_erased';
            try {
                broadcast(new MessageDeletedEvent($row->id, $row->room_id, $type));
            } catch (\Throwable $e) {
                Log::error('One-time erase broadcast failed', ['message_id' => $row->id, 'error' => $e->getMessage()]);
            }
        }

        $this->analytics->track(
            AnalyticsEvents::ONE_TIME_ERASED,
            ['reason' => $reason, 'scope' => 'private'],
            (string) $rows->first()->sender_id,
        );

        return true;
    }

    /**
     * Every row of the exchange [$message] belongs to that is not erased yet:
     * the one-time media and the one-time reactions that reply to it.
     *
     * @return Collection<int, Chat>
     */
    private function exchangeOf(Chat $message): Collection
    {
        $mediaId = $message->message_type === 'reaction' ? $message->reply_to_id : $message->id;

        return Chat::where('one_time', true)
            ->whereNull('one_time_erased_at')
            ->where(function (Builder $query) use ($message, $mediaId) {
                $query->whereIn('id', array_filter([$message->id, $mediaId]));
                if ($mediaId !== null) {
                    $query->orWhere('reply_to_id', $mediaId);
                }
            })
            ->get();
    }

    /** A file is fetchable until its open window has closed or it was erased. */
    private static function isFetchable(Chat $chat): bool
    {
        return $chat->file !== null
            && $chat->one_time_erased_at === null
            && ($chat->one_time_opened_at === null
                || $chat->one_time_opened_at->gt(now()->subMinutes(self::OPEN_WINDOW_MINUTES)));
    }

    /** HMAC that proves a link was issued by this server for this message. */
    private static function signature(int $messageId): string
    {
        return hash_hmac('sha256', 'one-time-media:'.$messageId, config('app.key'));
    }
}
