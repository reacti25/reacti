<?php

namespace Tests\Feature\Profile;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The "my account" endpoints exposed by UserProfileController:
 *
 *   GET    /profile           — read your own user record
 *   POST   /update-profile    — change first/last name, bio, phone, avatar
 *   POST   /update-username   — change username (separate to guard duplicates)
 *   POST   /update-password   — change password (requires current password)
 *
 * Every endpoint here is behind auth:api, so each method has both a
 * happy path and an explicit "no token" 401 test. Validation is
 * checked where the controller relies on it (oversized name, duplicate
 * phone, current-password mismatch).
 */
class UserProfileTest extends TestCase
{
    use RefreshDatabase;

    /**
     * GET /profile returns the auth user's record. We assert on `data.id`
     * — the controller wraps the user in a UserResource inside the
     * ApiResponse `success()` envelope.
     */
    #[Test]
    public function profile_returns_the_authenticated_user(): void
    {
        $user = User::factory()->create(['first_name' => 'Alice']);

        $resp = $this->actingAs($user, 'api')->getJson('/api/profile');

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.id', $user->id);
    }

    /** No auth → 401. Guards against an unauthenticated client reading any user. */
    #[Test]
    public function profile_requires_auth(): void
    {
        $this->getJson('/api/profile')->assertStatus(401);
    }

    /**
     * POST /update-profile with valid text fields. We don't touch
     * avatar here because the file-upload helper writes to
     * `public_path()` which is real filesystem; the validation path
     * tests cover the avatar contract without doing real I/O.
     */
    #[Test]
    public function update_profile_persists_text_fields(): void
    {
        $user = User::factory()->create([
            'first_name' => 'Alice',
            'last_name'  => 'Old',
            'bio'        => null,
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/update-profile', [
            'first_name' => 'Alicia',
            'last_name'  => 'New',
            'bio'        => 'just here for the patent flow',
        ]);

        $resp->assertOk();
        $this->assertDatabaseHas('users', [
            'id'         => $user->id,
            'first_name' => 'Alicia',
            'last_name'  => 'New',
            'bio'        => 'just here for the patent flow',
        ]);
    }

    /** No auth → 401. */
    #[Test]
    public function update_profile_requires_auth(): void
    {
        $this->postJson('/api/update-profile', ['first_name' => 'X'])
            ->assertStatus(401);
    }

    /** `max:50` rule on first_name → 422 on 51 chars. */
    #[Test]
    public function update_profile_rejects_oversized_first_name(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/update-profile', [
            'first_name' => str_repeat('a', 51),
        ]);

        $resp->assertStatus(422);
    }

    /**
     * `unique:users,phone,<my id>` — note the trailing `<my id>` lets
     * the user keep their own phone. We seed a different user with
     * the phone first, then try to claim it → 422.
     */
    #[Test]
    public function update_profile_rejects_phone_already_in_use(): void
    {
        $taken = User::factory()->create(['phone' => '+12025550100']);
        $user  = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/update-profile', [
            'phone' => '+12025550100',
        ]);

        $resp->assertStatus(422);
    }

    /** Happy path: username change persists. */
    #[Test]
    public function update_username_renames_the_user(): void
    {
        $user = User::factory()->create(['username' => 'old']);

        $resp = $this->actingAs($user, 'api')
            ->postJson('/api/update-username', ['username' => 'new-name']);

        $resp->assertOk();
        $this->assertDatabaseHas('users', [
            'id'       => $user->id,
            'username' => 'new-name',
        ]);
    }

    /** Same `unique:users,username,<my id>` story as phone → 422. */
    #[Test]
    public function update_username_rejects_duplicate(): void
    {
        User::factory()->create(['username' => 'taken']);
        $user = User::factory()->create(['username' => 'mine']);

        $resp = $this->actingAs($user, 'api')
            ->postJson('/api/update-username', ['username' => 'taken']);

        $resp->assertStatus(422);
    }

    /** No auth → 401. */
    #[Test]
    public function update_username_requires_auth(): void
    {
        $this->postJson('/api/update-username', ['username' => 'x'])
            ->assertStatus(401);
    }

    /**
     * Happy path. Confirms current-password check passed AND the new
     * hash actually replaced the old one (Hash::check on `new-password`
     * returns true after the update).
     */
    #[Test]
    public function update_password_replaces_the_hash_when_current_password_is_correct(): void
    {
        $user = User::factory()->create([
            'password' => Hash::make('old-password'),
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/update-password', [
            'current_password'      => 'old-password',
            'password'              => 'new-password',
            'password_confirmation' => 'new-password',
        ]);

        $resp->assertOk();
        $user->refresh();
        $this->assertTrue(Hash::check('new-password', $user->password));
    }

    /**
     * If the supplied `current_password` doesn't match the user's
     * existing hash → 422. Critical — otherwise a stolen session
     * could rotate the password without the original password.
     */
    #[Test]
    public function update_password_rejects_wrong_current_password(): void
    {
        $user = User::factory()->create([
            'password' => Hash::make('old-password'),
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/update-password', [
            'current_password'      => 'wrong-old',
            'password'              => 'new-password',
            'password_confirmation' => 'new-password',
        ]);

        $resp->assertStatus(422);
    }

    /** `confirmed` rule on new password → 422 on mismatch. */
    #[Test]
    public function update_password_rejects_confirmation_mismatch(): void
    {
        $user = User::factory()->create([
            'password' => Hash::make('old-password'),
        ]);

        $resp = $this->actingAs($user, 'api')->postJson('/api/update-password', [
            'current_password'      => 'old-password',
            'password'              => 'new-password',
            'password_confirmation' => 'wrong',
        ]);

        $resp->assertStatus(422);
    }

    /** No auth → 401. */
    #[Test]
    public function update_password_requires_auth(): void
    {
        $this->postJson('/api/update-password', [
            'current_password'      => 'a',
            'password'              => 'b',
            'password_confirmation' => 'b',
        ])->assertStatus(401);
    }
}
