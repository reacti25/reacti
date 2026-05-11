<?php

namespace Tests\Feature\Privacy;

use App\Models\DynamicPage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class PrivacyTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function privacy_policy_endpoint_returns_the_page_when_one_exists(): void
    {
        $user = User::factory()->create();
        DynamicPage::create([
            'page_slug'    => 'privacy-policy',
            'page_title'   => 'Privacy Policy',
            'page_content' => '<p>your data is yours</p>',
        ]);

        $resp = $this->actingAs($user, 'api')->getJson('/api/privacy-policy');
        $resp->assertOk();
        $resp->assertJsonPath('status', true);
        $resp->assertJsonPath('data.page_slug', 'privacy-policy');
    }

    #[Test]
    public function privacy_policy_returns_null_data_when_no_page_seeded(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson('/api/privacy-policy');
        $resp->assertOk();
        $resp->assertJsonPath('data', null);
    }

    #[Test]
    public function privacy_policy_requires_auth(): void
    {
        $this->getJson('/api/privacy-policy')->assertStatus(401);
    }
}
