<?php

namespace App\Providers;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsConsent;
use App\Analytics\Contracts\AnalyticsTransport;
use App\Analytics\Transports\NullTransport;
use App\Analytics\Transports\PostHogTransport;
use App\Models\Chat;
use App\Models\GroupMessage;
use Illuminate\Support\ServiceProvider;

/**
 * Wires the server-side analytics emitter.
 *
 * Binds {@see Analytics} as a singleton with a {@see PostHogTransport} when
 * analytics is enabled (a key is configured — config/analytics.php) and a
 * {@see NullTransport} otherwise, so the server behaves identically when
 * analytics is off (the default). Registers the domain hooks that emit
 * `message_persisted` when a 1:1 or group message is saved.
 */
class AnalyticsServiceProvider extends ServiceProvider
{
    /** Bind the analytics emitter and its transport. */
    public function register(): void
    {
        $this->app->singleton(AnalyticsTransport::class, function () {
            if (! config('analytics.enabled')) {
                return new NullTransport;
            }

            return new PostHogTransport(
                (string) config('analytics.posthog.key'),
                (string) config('analytics.posthog.host'),
            );
        });

        $this->app->singleton(Analytics::class, function ($app) {
            return new Analytics(
                $app->make(AnalyticsTransport::class),
                (string) config('analytics.env'),
                (string) (config('analytics.hash_salt') ?? ''),
            );
        });
    }

    /** Emit `message_persisted` on message creation (metadata only). */
    public function boot(): void
    {
        Chat::created(function (Chat $chat) {
            // Honour the sender's opt-out: no message_persisted with their id.
            if (AnalyticsConsent::isOptedOut()) {
                return;
            }
            $analytics = app(Analytics::class);
            $analytics->messagePersisted(
                $this->messageType($chat->message_type, $chat->file),
                'private',
                (string) $chat->sender_id,
            );

            // Companion to message_persisted: only for messages that carry
            // media, record the seal state as stored so Branch C can tell a
            // backend send-path bug from a client parse bug.
            if ($chat->file) {
                $analytics->mediaPersistedSealState(
                    (bool) $chat->is_blurred,
                    $this->messageType($chat->message_type, $chat->file),
                    'private',
                    (string) $chat->sender_id,
                );
            }
        });

        GroupMessage::created(function (GroupMessage $message) {
            if (AnalyticsConsent::isOptedOut()) {
                return;
            }
            $analytics = app(Analytics::class);
            $analytics->messagePersisted(
                $this->messageType($message->message_type, $message->file),
                'group',
                (string) $message->sender_id,
            );

            // Group seal intent is not stored on the message row (it lives
            // per-recipient in group_message_user_statuses, default sealed).
            // A normal media message is sealed for recipients at persist time —
            // the same condition the private path's is_blurred column records.
            if ($message->file) {
                $analytics->mediaPersistedSealState(
                    $message->message_type === 'normal',
                    $this->messageType($message->message_type, $message->file),
                    'group',
                    (string) $message->sender_id,
                );
            }
        });
    }

    /**
     * Maps a stored message to the catalog `message_type` enum
     * (`text` | `media` | `reaction`).
     */
    private function messageType(?string $type, ?string $file): string
    {
        if ($type === 'reaction') {
            return 'reaction';
        }

        return $file ? 'media' : 'text';
    }
}
