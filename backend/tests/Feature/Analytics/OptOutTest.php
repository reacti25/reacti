<?php

namespace Tests\Feature\Analytics;

use App\Analytics\Analytics;
use App\Analytics\AnalyticsEvents;
use App\Models\Friend;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\RecordingAnalyticsTransport;
use Tests\TestCase;

/**
 * The backend must emit NO analytics event carrying an opted-out user's id —
 * via the persisted `users.analytics_opt_out` flag OR the X-Analytics-Opt-Out
 * header. Anonymous system events still flow. Pins the fix for the staging gap
 * where opted-out users still produced backend api_request / message_persisted.
 */
class OptOutTest extends TestCase
{
    use RefreshDatabase;

    private RecordingAnalyticsTransport $transport;

    protected function setUp(): void
    {
        parent::setUp();
        $this->transport = new RecordingAnalyticsTransport;
        $this->app->instance(
            Analytics::class,
            new Analytics($this->transport, 'staging', 'salt'),
        );
    }

    public function test_opted_out_user_flag_suppresses_api_request(): void
    {
        $user = User::factory()->create(['analytics_opt_out' => true]);

        $this->actingAs($user, 'api')->getJson('/api/profile')->assertOk();

        $this->assertEmpty($this->transport->eventsNamed(AnalyticsEvents::API_REQUEST));
    }

    public function test_opt_out_header_suppresses_api_request(): void
    {
        $this->getJson('/api/check', ['X-Analytics-Opt-Out' => '1'])->assertOk();

        $this->assertEmpty($this->transport->eventsNamed(AnalyticsEvents::API_REQUEST));
    }

    public function test_anonymous_request_still_emits_api_request(): void
    {
        $this->getJson('/api/check')->assertOk();

        $this->assertNotEmpty($this->transport->eventsNamed(AnalyticsEvents::API_REQUEST));
    }

    public function test_opted_out_sender_produces_no_backend_events(): void
    {
        [$a, $b] = $this->friends(senderOptedOut: true);

        $this->actingAs($a, 'api')
            ->postJson('/api/auth/chat/send/'.$b->id, ['text' => 'hi'])
            ->assertOk();

        // No message_persisted (sender opted out) and no api_request for them.
        $this->assertEmpty($this->transport->eventsNamed(AnalyticsEvents::MESSAGE_PERSISTED));
        $this->assertEmpty($this->transport->eventsNamed(AnalyticsEvents::API_REQUEST));
    }

    public function test_opted_in_sender_still_produces_backend_events(): void
    {
        [$a, $b] = $this->friends(senderOptedOut: false);

        $this->actingAs($a, 'api')
            ->postJson('/api/auth/chat/send/'.$b->id, ['text' => 'hi'])
            ->assertOk();

        $this->assertNotEmpty($this->transport->eventsNamed(AnalyticsEvents::MESSAGE_PERSISTED));
    }

    public function test_endpoint_persists_the_opt_out_flag(): void
    {
        $user = User::factory()->create(['analytics_opt_out' => false]);

        $this->actingAs($user, 'api')
            ->postJson('/api/analytics-opt-out', ['opted_out' => true])
            ->assertOk()
            ->assertJsonPath('data.analytics_opt_out', true);

        $this->assertTrue($user->fresh()->analytics_opt_out);
    }

    /**
     * Two friends sharing a room; the first ($a, the sender) opted out or not.
     *
     * @return array{0: User, 1: User}
     */
    private function friends(bool $senderOptedOut): array
    {
        $a = User::factory()->create(['analytics_opt_out' => $senderOptedOut]);
        $b = User::factory()->create();
        Friend::create([
            'user_id' => $a->id,
            'friend_id' => $b->id,
            'became_friends_at' => now(),
        ]);
        Room::factory()->between($a, $b)->create();

        return [$a, $b];
    }
}
