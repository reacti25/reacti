<?php

namespace Tests\Feature\Consent;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * POST /api/recording-consent (DG1).
 *
 * Records the authenticated user's consent to the patented silent
 * reaction-recording as a server-side, audit-stable timestamp. Pins: auth is
 * required, consent is written for the caller, and a repeat call preserves the
 * original consent moment.
 */
class RecordingConsentTest extends TestCase
{
    use RefreshDatabase;

    /** Unauthenticated callers cannot record consent → 401. */
    #[Test]
    public function recording_consent_requires_auth(): void
    {
        $this->postJson('/api/recording-consent')->assertStatus(401);
    }

    /** A consenting user gets `recording_consent_at` set and returned. */
    #[Test]
    public function it_records_consent_for_the_authenticated_user(): void
    {
        $user = User::factory()->create(['recording_consent_at' => null]);

        $response = $this->actingAs($user, 'api')->postJson('/api/recording-consent');

        $response->assertOk();
        $response->assertJsonPath('success', true);
        $this->assertNotNull($response->json('data.recording_consent_at'));
        $this->assertNotNull($user->fresh()->recording_consent_at);
    }

    /** Re-consenting must not overwrite the original consent timestamp. */
    #[Test]
    public function it_preserves_the_original_consent_timestamp_on_repeat_calls(): void
    {
        $consentedAt = now()->subDays(3);
        $user = User::factory()->create(['recording_consent_at' => $consentedAt]);

        $this->actingAs($user, 'api')->postJson('/api/recording-consent')->assertOk();

        $this->assertEquals(
            $consentedAt->toDateTimeString(),
            $user->fresh()->recording_consent_at->toDateTimeString(),
            'Re-consenting must not overwrite the original consent timestamp.',
        );
    }
}
