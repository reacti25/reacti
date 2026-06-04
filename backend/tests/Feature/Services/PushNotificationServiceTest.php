<?php

namespace Tests\Feature\Services;

use App\Models\FirebaseTokens;
use App\Models\User;
use App\Services\PushNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * PushNotificationService — the shared device push fan-out extracted
 * from ChatService / GroupMessageService / SingleChatService /
 * FirebaseTokenService.
 *
 * The actual FCM delivery (`Helper::sendNotifyMobile` →
 * `Firebase::messaging()`) swallows and logs every failure, so the only
 * directly observable contract of `sendToUser` is that it iterates the
 * user's tokens and never throws. These tests pin that contract;
 * asserting the per-token call count would require making the FCM
 * helper injectable — tracked in `docs/code-quality-backlog.md`.
 */
class PushNotificationServiceTest extends TestCase
{
    use RefreshDatabase;

    /**
     * `sendToUser` is a safe no-op when the user has registered no
     * devices — the fan-out loop has nothing to iterate.
     */
    #[Test]
    public function send_to_user_does_nothing_when_the_user_has_no_tokens(): void
    {
        $user = User::factory()->create();

        $this->expectNotToPerformAssertions();

        app(PushNotificationService::class)->sendToUser($user, [
            'title' => 'Hi',
            'body' => 'there',
            'icon' => null,
        ]);
    }

    /**
     * `sendToUser` iterates every one of the user's device tokens and
     * completes cleanly — FCM delivery failures (no credentials in CI)
     * are swallowed inside `Helper::sendNotifyMobile`, so the call never
     * throws.
     */
    #[Test]
    public function send_to_user_completes_for_a_user_with_registered_tokens(): void
    {
        $user = User::factory()->create();
        FirebaseTokens::create([
            'user_id' => $user->id,
            'device_id' => 'device-1',
            'token' => 'fcm-token-1',
        ]);
        FirebaseTokens::create([
            'user_id' => $user->id,
            'device_id' => 'device-2',
            'token' => 'fcm-token-2',
        ]);

        $this->expectNotToPerformAssertions();

        app(PushNotificationService::class)->sendToUser($user->fresh(), [
            'title' => 'Hi',
            'body' => 'there',
            'icon' => null,
        ]);
    }
}
