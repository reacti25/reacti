<?php

namespace Tests\Feature\Auth;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Google/Apple sign-in was removed on 2026-10-25: no app version ever
 * called it, and it skipped the email OTP. Pins that the API endpoint
 * and the admin keys page are gone. Bringing it back is planned in
 * docs/PLAN-social-signin-FUTURE.md.
 */
class SocialSigninRemovedTest extends TestCase
{
    /** Both the API endpoint and the admin settings page 404. */
    #[Test]
    public function social_signin_routes_are_not_registered(): void
    {
        $this->postJson('/api/social/signin/google', ['token' => 'x'])->assertNotFound();
        $this->get('/admin/setting/social')->assertNotFound();
    }
}
