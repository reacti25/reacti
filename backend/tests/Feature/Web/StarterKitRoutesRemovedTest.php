<?php

namespace Tests\Feature\Web;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The web /register page from the Breeze starter kit was live on production
 * until 2026-10-25. It created accounts that skipped the email OTP and the
 * 16+ age gate, which only the API sign-up enforces. These tests keep it gone
 * while the admin sign-in pages keep working.
 */
class StarterKitRoutesRemovedTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function web_register_page_and_form_are_gone(): void
    {
        $this->get('/register')->assertNotFound();

        $this->post('/register', [
            'name' => 'x', 'email' => 'x@example.com',
            'password' => 'Password123!', 'password_confirmation' => 'Password123!',
        ])->assertNotFound();

        $this->assertDatabaseMissing('users', ['email' => 'x@example.com']);
    }

    #[Test]
    public function email_verification_and_confirm_password_pages_are_gone(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->get('/verify-email')->assertNotFound();
        $this->actingAs($user)->get('/confirm-password')->assertNotFound();
    }

    #[Test]
    public function admin_sign_in_pages_still_render(): void
    {
        $this->get('/login')->assertOk();
        $this->get('/forgot-password')->assertOk();
    }
}
