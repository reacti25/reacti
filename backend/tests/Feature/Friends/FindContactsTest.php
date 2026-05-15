<?php

namespace Tests\Feature\Friends;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * POST /api/find-contacts
 *
 * Given a list of phone numbers from the device address book, returns
 * the users on the platform whose phone matches. Each row is tagged
 * with `is_friend` so the client can show "add" vs. "already friends".
 *
 * Before the migration to `user_blocks`, the controller filtered out
 * blocked users by querying a non-existent `blocked_users` table. The
 * endpoint would throw a SQL error before reaching the response — the
 * "blocked user is excluded" test below is the regression net for
 * that fix.
 */
class FindContactsTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function find_contacts_requires_auth(): void
    {
        $this->postJson('/api/find-contacts', ['contacts' => ['+10000000000']])
            ->assertStatus(401);
    }

    #[Test]
    public function find_contacts_requires_contacts_array(): void
    {
        $me = User::factory()->create();

        $this->actingAs($me, 'api')
            ->postJson('/api/find-contacts', [])
            ->assertStatus(422);
    }

    #[Test]
    public function find_contacts_returns_users_matching_the_submitted_phone_numbers(): void
    {
        $me     = User::factory()->create();
        $alice  = User::factory()->create(['phone' => '+12025550111']);
        $bob    = User::factory()->create(['phone' => '+12025550222']);
        $eve    = User::factory()->create(['phone' => '+19999999999']);

        $resp = $this->actingAs($me, 'api')->postJson('/api/find-contacts', [
            'contacts' => ['+1 (202) 555-0111', '+12025550222'],
        ]);

        $resp->assertOk();

        $returned = collect($resp->json('data.data'))->pluck('id')->all();
        $this->assertContains($alice->id, $returned);
        $this->assertContains($bob->id, $returned);
        $this->assertNotContains($eve->id, $returned, 'Eve was not in the submitted contacts.');
        $this->assertNotContains($me->id, $returned, 'The auth user must never be returned to themselves.');
    }

    /**
     * A user who has blocked me must not surface in my contact-match
     * results — even if their phone is in my address book. This is the
     * regression for the `blocked_users` → `user_blocks` table-name fix.
     */
    #[Test]
    public function find_contacts_excludes_users_who_blocked_me(): void
    {
        $me      = User::factory()->create();
        $blocker = User::factory()->create(['phone' => '+15555550100']);

        DB::table('user_blocks')->insert([
            'user_id'       => $me->id,        // I am the blocker for the join (controller filters where user_id=me)
            'block_user_id' => $blocker->id,   // the contact is the blocked party
            'created_at'    => now(),
            'updated_at'    => now(),
        ]);

        $resp = $this->actingAs($me, 'api')->postJson('/api/find-contacts', [
            'contacts' => ['+15555550100'],
        ]);

        $resp->assertOk();
        $returned = collect($resp->json('data.data'))->pluck('id')->all();
        $this->assertNotContains($blocker->id, $returned);
    }
}
