<?php

namespace Database\Seeders;

use App\Models\User;
use Faker\Factory as Faker;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class UserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // --- Admin User ---
        User::create([
            'first_name' => 'System',
            'last_name' => 'Admin',
            'username' => 'admin',
            'role' => 'admin',
            // A .test address can never receive mail: admin@gmail.com belonged
            // to a stranger, who would have received any password reset.
            'email' => 'admin@reacti.test',
            'phone' => '1234567890',
            // Never a fixed password: '12345678' shipped to production and left
            // the admin dashboard open to anyone (2026-10-15). Set
            // ADMIN_SEED_PASSWORD to choose one; otherwise it is random and the
            // admin must be given a password deliberately.
            'password' => Hash::make(env('ADMIN_SEED_PASSWORD') ?: Str::random(40)),
            'avatar' => asset('default/default_image.jpg'),
            'cover' => asset('default/default_image.jpg'),
            'bio' => 'Administrator of the platform.',
            'address' => 'Dhaka, Bangladesh',
            'otp' => null,
            'otp_expires_at' => null,
            'otp_verified_at' => Carbon::now(),
            'status' => 'active',
            'is_google_signin' => false,
            'is_apple_signin' => false,
        ]);

        // --- 10 Regular Users data
        $faker = Faker::create();

        for ($i = 1; $i <= 10; $i++) {
            $firstName = $faker->firstName;
            $lastName = $faker->lastName;
            $email = strtolower($firstName.'.'.$lastName.$i.'@gmail.com');

            User::create([
                'first_name' => $firstName,
                'last_name' => $lastName,
                'username' => strtolower($firstName.$lastName.$i),
                'role' => 'user',
                'email' => $email,
                'phone' => '01'.$faker->numberBetween(100000000, 999999999),
                'password' => Hash::make('12345678'),
                'avatar' => asset('default/default_image.jpg'),
                'cover' => asset('default/default_image.jpg'),
                'bio' => 'Hello! I’m '.$firstName.'.',
                'address' => $faker->city.', Bangladesh',
                'otp_verified_at' => Carbon::now(),
                'status' => 'active',
                'is_google_signin' => false,
                'is_apple_signin' => false,
            ]);
        }
    }
}
