<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Socialite\Contracts\User as SocialiteUser;
use Laravel\Socialite\Facades\Socialite;
use Mockery;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Google social sign-in — `POST /api/social/signin/{provider}`.
 *
 * Before R10 this flow was dead twice over: the route pointed at a
 * `socialSignin` method that did not exist, and
 * `SocialAuthService::googleAuthenticate` wrote `name` /
 * `is_otp_verified` columns the `users` table does not have. These
 * tests pin the wired-up behaviour.
 *
 * Socialite is mocked — no real Google call is made.
 */
class SocialLoginTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Make `Socialite::driver('google')->stateless()->userFromToken()`
     * return a stubbed profile.
     */
    private function fakeGoogleUser(
        string $id,
        string $email,
        string $name,
        string $avatar = 'https://example.com/a.png'
    ): void {
        $socialUser = Mockery::mock(SocialiteUser::class);
        $socialUser->shouldReceive('getId')->andReturn($id);
        $socialUser->shouldReceive('getEmail')->andReturn($email);
        $socialUser->shouldReceive('getName')->andReturn($name);
        $socialUser->shouldReceive('getAvatar')->andReturn($avatar);

        $provider = Mockery::mock();
        $provider->shouldReceive('stateless')->andReturnSelf();
        $provider->shouldReceive('userFromToken')->andReturn($socialUser);

        Socialite::shouldReceive('driver')->with('google')->andReturn($provider);
    }

    #[Test]
    public function google_signin_creates_a_new_user_and_returns_a_token(): void
    {
        $this->fakeGoogleUser('google-uid-1', 'alice@gmail.com', 'Alice Walker');

        // A new social account goes through the same age gate as an email
        // signup, so the birthdate is part of the first-time payload.
        $resp = $this->postJson('/api/social/signin/google', [
            'token' => 'oauth-tok',
            'date_of_birth' => '1990-01-01',
        ]);

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $this->assertNotEmpty($resp->json('data.token'));

        $this->assertDatabaseHas('users', [
            'email' => 'alice@gmail.com',
            'first_name' => 'Alice',
            'last_name' => 'Walker',
            'google_id' => 'google-uid-1',
            'is_google_signin' => true,
        ]);

        // Social accounts skip the email-OTP step.
        $this->assertNotNull(User::where('email', 'alice@gmail.com')->first()->otp_verified_at);
    }

    #[Test]
    public function google_signin_links_to_an_existing_email_account(): void
    {
        $existing = User::factory()->create([
            'email' => 'bob@gmail.com',
            'first_name' => 'Bob',
        ]);

        $this->fakeGoogleUser('google-uid-2', 'bob@gmail.com', 'Bob Roberts');

        $resp = $this->postJson('/api/social/signin/google', ['token' => 'oauth-tok']);

        $resp->assertOk();
        $this->assertNotEmpty($resp->json('data.token'));

        // Matched the existing row — no duplicate created, and no
        // birthdate demanded of someone who already has an account.
        $this->assertSame(1, User::where('email', 'bob@gmail.com')->count());
        $this->assertSame($existing->id, $resp->json('data.id'));
    }

    /**
     * The hole this phase closes: `googleAuthenticate` used to mint an
     * account straight from a Google token via firstOrCreate, so the
     * registration FormRequest's age rule never ran. A Google token alone
     * must not be enough to create an account.
     */
    #[Test]
    public function google_signin_refuses_a_new_account_without_a_birthdate(): void
    {
        $this->fakeGoogleUser('google-uid-3', 'carol@gmail.com', 'Carol Danvers');

        $resp = $this->postJson('/api/social/signin/google', ['token' => 'oauth-tok']);

        $resp->assertStatus(422);
        // Refused at the door — no half-made account left behind.
        $this->assertDatabaseMissing('users', ['email' => 'carol@gmail.com']);
    }

    /** Under-age is refused on the social path too, and creates nothing. */
    #[Test]
    public function google_signin_refuses_a_new_account_below_the_minimum_age(): void
    {
        $this->fakeGoogleUser('google-uid-4', 'dave@gmail.com', 'Dave Lister');

        $tooYoung = now()->subYears(config('reacti.min_age'))->addDay()->toDateString();

        $resp = $this->postJson('/api/social/signin/google', [
            'token' => 'oauth-tok',
            'date_of_birth' => $tooYoung,
        ]);

        $resp->assertStatus(422);
        $this->assertDatabaseMissing('users', ['email' => 'dave@gmail.com']);
    }

    /** The birthdate is actually persisted, not just checked and dropped. */
    #[Test]
    public function google_signin_stores_the_birthdate_on_the_new_account(): void
    {
        $this->fakeGoogleUser('google-uid-5', 'erin@gmail.com', 'Erin Brockovich');

        $dob = now()->subYears(21)->toDateString();

        $this->postJson('/api/social/signin/google', [
            'token' => 'oauth-tok',
            'date_of_birth' => $dob,
        ])->assertOk();

        $user = User::where('email', 'erin@gmail.com')->firstOrFail();
        $this->assertSame($dob, $user->date_of_birth->toDateString());
    }

    /**
     * An existing account signing in again must not be blocked for having no
     * birthdate on file — those users are handled by the one-time age
     * confirmation (phase A4), not by locking them out at the door.
     */
    #[Test]
    public function google_signin_does_not_demand_a_birthdate_from_an_existing_account(): void
    {
        User::factory()->create([
            'email' => 'frank@gmail.com',
            'date_of_birth' => null,
        ]);

        $this->fakeGoogleUser('google-uid-6', 'frank@gmail.com', 'Frank Drebin');

        $this->postJson('/api/social/signin/google', ['token' => 'oauth-tok'])
            ->assertOk();
    }

    #[Test]
    public function social_signin_rejects_an_unsupported_provider(): void
    {
        $resp = $this->postJson('/api/social/signin/apple', ['token' => 'oauth-tok']);

        $resp->assertStatus(422);
        $resp->assertJsonPath('status', false);
    }

    #[Test]
    public function social_signin_404s_for_a_provider_outside_the_route_constraint(): void
    {
        // The route's whereIn allows only google|apple; anything else
        // does not match a route at all.
        $this->postJson('/api/social/signin/facebook', ['token' => 'x'])
            ->assertNotFound();
    }
}
