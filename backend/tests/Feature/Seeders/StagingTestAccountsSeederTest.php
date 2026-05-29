<?php

namespace Tests\Feature\Seeders;

use App\Models\Friend;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Database\Seeders\StagingTestAccountsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use RuntimeException;
use Tests\TestCase;

/**
 * StagingTestAccountsSeeder — fixed staging/CI test logins.
 *
 * Verifies the seeder produces two verified, active, mutually-friended
 * users sharing one group; that it is idempotent (safe to re-run); that
 * the created accounts can actually authenticate via POST /api/login; and
 * that its safety guards (empty password, production environment) hold.
 */
class StagingTestAccountsSeederTest extends TestCase
{
    use RefreshDatabase;

    /** Password injected via config for the duration of each test. */
    private const TEST_PASSWORD = 'StagingSeed!2026';

    /**
     * Provide a non-empty seed password before each test so the seeder's
     * "refuse on empty password" guard does not trip on the happy paths.
     */
    protected function setUp(): void
    {
        parent::setUp();
        config(['seeding.staging_account_password' => self::TEST_PASSWORD]);
    }

    /** Seeds exactly two active, OTP-verified users with the fixed emails. */
    #[Test]
    public function it_creates_two_active_verified_users(): void
    {
        $this->seed(StagingTestAccountsSeeder::class);

        $this->assertSame(2, User::count());

        foreach (['smoke-a@reacti.test', 'smoke-b@reacti.test'] as $email) {
            $user = User::where('email', $email)->first();
            $this->assertNotNull($user, "Expected seeded user {$email} to exist.");
            $this->assertSame('active', $user->status);
            $this->assertNotNull($user->otp_verified_at);
        }
    }

    /** Links the two users with a single confirmed-friendship row. */
    #[Test]
    public function it_makes_the_two_users_friends(): void
    {
        $this->seed(StagingTestAccountsSeeder::class);

        $a = User::where('email', 'smoke-a@reacti.test')->first();
        $b = User::where('email', 'smoke-b@reacti.test')->first();

        $this->assertSame(1, Friend::count());
        $this->assertDatabaseHas('friends', ['user_id' => $a->id, 'friend_id' => $b->id]);
        // The User::friends() union should read the relationship as mutual.
        $this->assertTrue($a->friends()->where('users.id', $b->id)->exists());
    }

    /** Puts both users in one group: A as admin/owner, B as member. */
    #[Test]
    public function it_creates_one_shared_group_with_correct_roles(): void
    {
        $this->seed(StagingTestAccountsSeeder::class);

        $a = User::where('email', 'smoke-a@reacti.test')->first();
        $b = User::where('email', 'smoke-b@reacti.test')->first();

        $this->assertSame(1, Group::count());
        $group = Group::first();
        $this->assertSame($a->id, $group->created_by);
        $this->assertSame(2, GroupMember::where('group_id', $group->id)->count());
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id, 'user_id' => $a->id, 'role' => 'admin',
        ]);
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id, 'user_id' => $b->id, 'role' => 'member',
        ]);
    }

    /** Re-running the seeder updates in place — no duplicate rows. */
    #[Test]
    public function it_is_idempotent(): void
    {
        $this->seed(StagingTestAccountsSeeder::class);
        $this->seed(StagingTestAccountsSeeder::class);

        $this->assertSame(2, User::count());
        $this->assertSame(1, Friend::count());
        $this->assertSame(1, Group::count());
        $this->assertSame(2, GroupMember::count());
    }

    /** A seeded account can authenticate through the real login endpoint. */
    #[Test]
    public function seeded_account_can_log_in(): void
    {
        $this->seed(StagingTestAccountsSeeder::class);

        $response = $this->postJson('/api/login', [
            'email' => 'smoke-a@reacti.test',
            'password' => self::TEST_PASSWORD,
        ]);

        $response->assertOk();
        $response->assertJsonPath('success', true);
        $this->assertNotEmpty($response->json('data.token'));
    }

    /** Refuses to seed when no password is configured, creating no rows. */
    #[Test]
    public function it_refuses_to_run_without_a_password(): void
    {
        config(['seeding.staging_account_password' => null]);

        try {
            (new StagingTestAccountsSeeder)->run();
            $this->fail('Expected a RuntimeException when no password is configured.');
        } catch (RuntimeException) {
            // expected
        }

        $this->assertSame(0, User::count());
    }

    /**
     * Refuses to seed in the production environment.
     *
     * Invokes the seeder directly rather than via $this->seed(): the
     * artisan db:seed command has its own production confirmation guard
     * that would bail first, so calling run() is what actually exercises
     * the seeder's own environment check (the real backstop when db:seed
     * is run with --force).
     */
    #[Test]
    public function it_refuses_to_run_in_production(): void
    {
        $this->app['env'] = 'production';

        try {
            (new StagingTestAccountsSeeder)->run();
            $this->fail('Expected a RuntimeException when run in production.');
        } catch (RuntimeException) {
            // expected
        } finally {
            $this->app['env'] = 'testing';
        }

        $this->assertSame(0, User::count());
    }
}
