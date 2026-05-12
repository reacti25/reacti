<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class UserFactory extends Factory
{
    protected $model = User::class;

    protected static ?string $password = null;

    public function definition(): array
    {
        return [
            'first_name' => $this->faker->firstName,
            'last_name' => $this->faker->lastName,
            'username' => $this->faker->unique()->userName,
            'email' => $this->faker->unique()->safeEmail,
            'password' => static::$password ??= Hash::make('password'),
            'phone' => $this->faker->unique()->e164PhoneNumber,
            'role' => 'user',
            'avatar' => null,
            'address' => $this->faker->streetAddress,
            'otp_verified_at' => now(),
            'last_activity_at' => now(),
            'status' => 'active',
            'remember_token' => Str::random(10),
        ];
    }
}
