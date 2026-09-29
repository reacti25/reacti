<?php

namespace Tests\Unit\Helpers;

use App\Helpers\Helper;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins the Android half of the push payload (Android plan, Step 6).
 *
 * Without a channel id, Android shows a push on a low-importance fallback
 * channel: no banner, and nothing fails loudly. The id must match the channel
 * the app creates (`kAndroidPushChannelId`); the app's
 * `android_push_config_test.dart` checks this file for the same literal.
 */
class AndroidPushConfigTest extends TestCase
{
    /** Serialise the built CloudMessage to the array FCM would receive. */
    private function payload(?int $badge = null): array
    {
        $message = Helper::buildPushMessage('device-token', [
            'title' => 'Avital',
            'body' => 'sent you a photo',
            'icon' => null,
        ], $badge);

        return json_decode(json_encode($message), true);
    }

    #[Test]
    public function android_push_names_the_apps_high_importance_channel(): void
    {
        $this->assertSame(
            'high_importance_channel',
            $this->payload()['android']['notification']['channel_id']
        );
    }

    #[Test]
    public function android_push_is_sent_at_high_priority(): void
    {
        $this->assertSame('high', $this->payload()['android']['priority']);
    }

    #[Test]
    public function the_channel_does_not_drop_the_default_sound(): void
    {
        // withDefaultSounds() runs after the AndroidConfig is set; both must
        // survive in the same android.notification block.
        $notification = $this->payload()['android']['notification'];

        $this->assertSame('default', $notification['sound']);
        $this->assertSame('high_importance_channel', $notification['channel_id']);
    }

    #[Test]
    public function the_android_block_leaves_the_ios_payload_unchanged(): void
    {
        $aps = $this->payload(3)['apns']['payload']['aps'];

        $this->assertSame(3, $aps['badge']);
        $this->assertSame('default', $aps['sound']);
    }
}
