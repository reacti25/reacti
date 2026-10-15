<?php

namespace Tests\Feature\Web;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The public account-deletion page that Google Play's Data safety form links
 * to. Google checks that it loads, names the app or developer, shows how to
 * request deletion, and says what is deleted and what is kept.
 */
class DeleteAccountPageTest extends TestCase
{
    #[Test]
    public function it_loads_without_signing_in(): void
    {
        $this->get('/delete-account')->assertOk();
    }

    #[Test]
    public function it_names_the_app_and_the_developer(): void
    {
        $this->get('/delete-account')
            ->assertSee('Reacti')
            ->assertSee('Achia Rosin');
    }

    #[Test]
    public function it_shows_both_ways_to_delete(): void
    {
        $this->get('/delete-account')
            ->assertSeeInOrder(['Profile', 'Settings', 'Delete Account'])
            ->assertSee('reacti.ai25@gmail.com')
            ->assertSee('Delete my account');
    }

    #[Test]
    public function it_says_what_is_deleted_and_what_is_kept(): void
    {
        $this->get('/delete-account')
            ->assertSee('What is deleted')
            ->assertSee('reaction videos')
            ->assertSee('What is kept')
            ->assertSee('30 days');
    }
}
