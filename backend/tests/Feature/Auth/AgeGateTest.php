<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The signup age gate (docs/PLAN-age-gate-2026-08-04.md, phase A1).
 *
 * Reacti records the viewer's face when they open a media message, so an
 * under-age account is a problem the moment it exists. The rule lives in
 * UserRegisterRequest, NOT in the app: the client's date picker is UX, and
 * anything that talks to the API directly has to clear the same bar.
 *
 * Minimum age comes from config('reacti.min_age') — these tests read it from
 * config too, so raising or lowering the threshold doesn't need a test edit.
 */
class AgeGateTest extends TestCase
{
    use RefreshDatabase;

    /** A payload that passes everything except what the caller overrides. */
    private function payload(array $overrides = []): array
    {
        return array_merge([
            'first_name' => 'Ada',
            'last_name' => 'Byron',
            'email' => 'ada@example.com',
            'password' => 'correct-horse',
            'password_confirmation' => 'correct-horse',
            'date_of_birth' => now()->subYears(30)->toDateString(),
        ], $overrides);
    }

    /** Comfortably over the threshold → registration proceeds as normal. */
    #[Test]
    public function registration_succeeds_for_an_adult(): void
    {
        Mail::fake();

        $this->postJson('/api/register', $this->payload())->assertOk();

        $this->assertNotNull(Cache::get('register_data_ada@example.com'));
    }

    /** One day short of the minimum age → 422, and nothing is cached. */
    #[Test]
    public function registration_is_refused_below_the_minimum_age(): void
    {
        Mail::fake();

        $tooYoung = now()->subYears(config('reacti.min_age'))->addDay()->toDateString();

        $resp = $this->postJson('/api/register', $this->payload([
            'date_of_birth' => $tooYoung,
        ]));

        $resp->assertStatus(422);
        $resp->assertJsonValidationErrors('date_of_birth');

        // Refused at the door: no pending registration, no OTP mail.
        $this->assertNull(Cache::get('register_data_ada@example.com'));
        Mail::assertNothingSent();
    }

    /**
     * The boundary itself. Someone whose birthday is TODAY has just reached
     * the minimum age and must pass — an off-by-one here would lock out a
     * legitimate signup on their birthday.
     */
    #[Test]
    public function registration_succeeds_exactly_on_the_birthday(): void
    {
        Mail::fake();

        $this->postJson('/api/register', $this->payload([
            'date_of_birth' => now()->subYears(config('reacti.min_age'))->toDateString(),
        ]))->assertOk();

        $this->assertNotNull(Cache::get('register_data_ada@example.com'));
    }

    /** Omitting the field entirely must not be a way around the gate. */
    #[Test]
    public function registration_requires_a_date_of_birth(): void
    {
        $payload = $this->payload();
        unset($payload['date_of_birth']);

        $this->postJson('/api/register', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('date_of_birth');
    }

    /** Garbage in the field is refused rather than silently coerced. */
    #[Test]
    public function registration_rejects_an_unparseable_date(): void
    {
        $this->postJson('/api/register', $this->payload(['date_of_birth' => 'yesterday-ish']))
            ->assertStatus(422)
            ->assertJsonValidationErrors('date_of_birth');
    }

    /**
     * The birthdate has to survive the OTP leg — it is cached by register()
     * and only becomes a column when verifyEmail() creates the row. If that
     * hand-off breaks, every new account silently lands with a null DOB and
     * the gate records nothing.
     */
    #[Test]
    public function date_of_birth_lands_on_the_user_after_otp_verification(): void
    {
        Mail::fake();

        $dob = now()->subYears(22)->toDateString();
        $this->postJson('/api/register', $this->payload(['date_of_birth' => $dob]))->assertOk();

        $otp = Cache::get('register_otp_ada@example.com');

        $this->postJson('/api/email-verify', [
            'email' => 'ada@example.com',
            'otp' => $otp,
        ])->assertOk();

        // Asserted through the model rather than assertDatabaseHas: the `date`
        // cast writes "Y-m-d 00:00:00", which MySQL coerces to a DATE but
        // SQLite (what CI runs) stores verbatim, so a raw column match fails
        // on a row that is actually correct.
        $user = User::where('email', 'ada@example.com')->firstOrFail();
        $this->assertSame($dob, $user->date_of_birth->toDateString());
    }

    /**
     * A birthdate is PII and no screen displays one. It must not appear in a
     * profile response — the `users/{id}` shape is what other people can see.
     */
    #[Test]
    public function date_of_birth_is_never_exposed_in_a_profile_response(): void
    {
        $user = User::factory()->create(['date_of_birth' => '1990-05-04']);

        $this->assertArrayNotHasKey('date_of_birth', $user->toArray());
    }
}
