<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Staging test-account password
    |--------------------------------------------------------------------------
    |
    | Password assigned to the fixed staging smoke/contract test accounts
    | created by Database\Seeders\StagingTestAccountsSeeder. Sourced from the
    | STAGING_SEED_PASSWORD environment variable so the real value never lives
    | in version control. Reading it through config (rather than env() directly
    | inside the seeder) is deliberate: on the server `php artisan config:cache`
    | runs on every deploy, after which env() returns null — config() keeps
    | working because the value is baked in at cache time.
    |
    */

    'staging_account_password' => env('STAGING_SEED_PASSWORD'),

];
