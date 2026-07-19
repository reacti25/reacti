<?php

namespace Tests\Unit\Helpers;

use App\Helpers\Helper;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Pins the push-notification sound contract: every push carries an explicit
 * alert sound so a message arriving while the app is backgrounded/closed makes
 * a sound. iOS delivers silently without `aps.sound`, which is why the iPhone
 * was quiet out-of-app — this asserts the field is now always present, and that
 * adding it never drops the iOS badge.
 */
class PushMessageSoundTest extends TestCase
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
    public function ios_push_carries_the_default_alert_sound(): void
    {
        $this->assertSame('default', $this->payload()['apns']['payload']['aps']['sound']);
    }

    #[Test]
    public function android_push_carries_the_default_alert_sound(): void
    {
        $this->assertSame('default', $this->payload()['android']['notification']['sound']);
    }

    #[Test]
    public function the_sound_does_not_drop_the_ios_badge(): void
    {
        $aps = $this->payload(7)['apns']['payload']['aps'];

        // Both must survive together — the sound is merged into, not a
        // replacement for, the badge-carrying APNs payload.
        $this->assertSame(7, $aps['badge']);
        $this->assertSame('default', $aps['sound']);
    }
}
