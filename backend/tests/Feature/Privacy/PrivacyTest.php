<?php

namespace Tests\Feature\Privacy;

use App\Models\DynamicPage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * GET /privacy-policy reads a row from `dynamic_pages` keyed by
 * page_slug='privacy-policy'. Tests cover the seeded-page path, the
 * empty-data path (controller returns null data, not 404), and the
 * auth gate.
 */
class PrivacyTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Happy path: a `privacy-policy` row is seeded in `dynamic_pages`,
     * the endpoint returns it inside the standard envelope. We assert
     * on `data.page_slug` to confirm the controller is fetching the
     * right row (vs. some other slug it might pick up by mistake).
     */
    #[Test]
    public function privacy_policy_endpoint_returns_the_page_when_one_exists(): void
    {
        $user = User::factory()->create();
        DynamicPage::create([
            'page_slug' => 'privacy-policy',
            'page_title' => 'Privacy Policy',
            'page_content' => '<p>your data is yours</p>',
        ]);

        $resp = $this->actingAs($user, 'api')->getJson('/api/privacy-policy');
        $resp->assertOk();
        $resp->assertJsonPath('status', true);
        $resp->assertJsonPath('data.page_slug', 'privacy-policy');
    }

    /**
     * No seeded row → the controller returns `data: null` with a 200,
     * NOT a 404. Tests pin this so a future change to "return 404 if
     * missing" is caught (it would break clients that expect 200 +
     * null).
     */
    #[Test]
    public function privacy_policy_returns_null_data_when_no_page_seeded(): void
    {
        $user = User::factory()->create();
        $resp = $this->actingAs($user, 'api')->getJson('/api/privacy-policy');
        $resp->assertOk();
        $resp->assertJsonPath('data', null);
    }

    /** No auth → 401. The endpoint sits behind auth:api in the routes file. */
    #[Test]
    public function privacy_policy_requires_auth(): void
    {
        $this->getJson('/api/privacy-policy')->assertStatus(401);
    }
}
