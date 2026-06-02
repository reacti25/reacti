<?php

namespace Database\Seeders;

use App\Models\Friend;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

/**
 * Seeds a fixed, reproducible set of test accounts for the staging
 * environment (and CI), so smoke tests, contract tests, and manual
 * on-device testing always have known users to log in as.
 *
 * Creates two verified, active users that are confirmed friends and share
 * one group:
 *   - smoke-a@reacti.test  (group admin / owner)
 *   - smoke-b@reacti.test  (group member)
 *
 * The seeder is idempotent — running it repeatedly updates the same rows
 * rather than creating duplicates — and refuses to run in production so it
 * can never inject test logins into the live user base. The shared password
 * comes from the STAGING_SEED_PASSWORD env var via config('seeding.*'); it is
 * never hard-coded here.
 *
 * Run on the server with:
 *   php artisan db:seed --class=StagingTestAccountsSeeder
 */
class StagingTestAccountsSeeder extends Seeder
{
    /** Fixed login for test user A — the group owner/admin. */
    private const USER_A_EMAIL = 'smoke-a@reacti.test';

    /** Fixed login for test user B — a regular group member. */
    private const USER_B_EMAIL = 'smoke-b@reacti.test';

    /** Name of the shared group both test users belong to. */
    private const GROUP_NAME = 'Smoke Test Group';

    /**
     * Create (or refresh) the staging test accounts, their friendship,
     * and their shared group.
     *
     * @throws RuntimeException If run in production, or if no seed password
     *                          is configured (refusing to create accounts
     *                          with a blank/guessable password).
     */
    public function run(): void
    {
        // Hard stop: these are test logins and must never touch the live
        // user base. Staging, local, and CI (testing) are all allowed.
        if (app()->environment('production')) {
            throw new RuntimeException(
                'StagingTestAccountsSeeder must not run in production.'
            );
        }

        $password = config('seeding.staging_account_password');
        if (empty($password)) {
            throw new RuntimeException(
                'STAGING_SEED_PASSWORD is not set — refusing to create test '
                .'accounts with an empty password. Set it in the environment '
                .'(and re-run config:cache on the server) before seeding.'
            );
        }

        $userA = $this->upsertUser(self::USER_A_EMAIL, 'Smoke', 'Alpha', 'smoke_a', $password);
        $userB = $this->upsertUser(self::USER_B_EMAIL, 'Smoke', 'Bravo', 'smoke_b', $password);

        $this->ensureFriendship($userA, $userB);
        $this->ensureSharedGroup($userA, $userB);

        $this->command?->info("Staging test accounts ready: {$userA->email} (admin) and {$userB->email}.");
    }

    /**
     * Create or update a single verified, active test user keyed by email.
     *
     * @param  string  $email  Fixed login email (the idempotency key).
     * @param  string  $firstName  Display first name.
     * @param  string  $lastName  Display last name.
     * @param  string  $username  Unique handle.
     * @param  string  $password  Plaintext password to hash and store.
     * @return User The persisted user.
     */
    private function upsertUser(
        string $email,
        string $firstName,
        string $lastName,
        string $username,
        string $password
    ): User {
        return User::updateOrCreate(
            ['email' => $email],
            [
                'first_name' => $firstName,
                'last_name' => $lastName,
                'username' => $username,
                'password' => Hash::make($password),
                'status' => 'active',
                'otp_verified_at' => now(),
                'last_activity_at' => now(),
            ]
        );
    }

    /**
     * Ensure a single confirmed-friendship row links the two users.
     *
     * Friendships are stored as one directed row; {@see User::friends()}
     * unions both directions, so a single A->B row makes them mutual.
     *
     * @param  User  $userA  Owning side of the friendship row.
     * @param  User  $userB  Friend side of the friendship row.
     */
    private function ensureFriendship(User $userA, User $userB): void
    {
        Friend::firstOrCreate(
            ['user_id' => $userA->id, 'friend_id' => $userB->id],
            ['became_friends_at' => now()],
        );
    }

    /**
     * Ensure both users share one group, with A as admin and B as member.
     *
     * @param  User  $userA  Group creator/owner (admin).
     * @param  User  $userB  Regular member.
     */
    private function ensureSharedGroup(User $userA, User $userB): void
    {
        $group = Group::firstOrCreate(
            ['name' => self::GROUP_NAME, 'created_by' => $userA->id],
            ['description' => 'Shared group for staging smoke/contract tests.'],
        );

        GroupMember::firstOrCreate(
            ['group_id' => $group->id, 'user_id' => $userA->id],
            ['role' => 'admin', 'joined_at' => now()],
        );

        GroupMember::firstOrCreate(
            ['group_id' => $group->id, 'user_id' => $userB->id],
            ['role' => 'member', 'joined_at' => now()],
        );
    }
}
