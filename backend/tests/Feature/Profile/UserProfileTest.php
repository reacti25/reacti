<?php

namespace Tests\Feature\Profile;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class UserProfileTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function profile_returns_the_authenticated_user(): void
    {
        $user = User::factory()->create(['first_name' => 'Alice']);

        $resp = $this->actingAs($user, 'api')->getJson('/api/profile');

        $resp->assertOk();
        $resp->assertJsonPath('success', true);
        $resp->assertJsonPath('data.id', $user->id);
    }

    #[Test]
    public function profile_requires_auth(): void
    {
        $this->getJson('/api/profile')->assertStatus(401);
    }

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

    #[Test]
    public function update_profile_requires_auth(): void
    {
        $this->postJson('/api/update-profile', ['first_name' => 'X'])
            ->assertStatus(401);
    }

    #[Test]
    public function update_profile_rejects_oversized_first_name(): void
    {
        $user = User::factory()->create();

        $resp = $this->actingAs($user, 'api')->postJson('/api/update-profile', [
            'first_name' => str_repeat('a', 51),
        ]);

        $resp->assertStatus(422);
    }

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

    #[Test]
    public function update_username_rejects_duplicate(): void
    {
        User::factory()->create(['username' => 'taken']);
        $user = User::factory()->create(['username' => 'mine']);

        $resp = $this->actingAs($user, 'api')
            ->postJson('/api/update-username', ['username' => 'taken']);

        $resp->assertStatus(422);
    }

    #[Test]
    public function update_username_requires_auth(): void
    {
        $this->postJson('/api/update-username', ['username' => 'x'])
            ->assertStatus(401);
    }

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
