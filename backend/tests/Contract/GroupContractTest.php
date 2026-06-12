<?php

namespace Tests\Contract;

use App\Http\Resources\ChatResource;
use App\Http\Resources\MessageResource;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\GroupMessageUserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;

/**
 * Contract tests for the group chat endpoints the iOS app depends on,
 * including the per-group leg of the patent flow.
 *
 * These lock the exact response shape of the group list, group
 * conversation, group send (text and the patent `reaction` upload), and
 * the per-user group `mark-viewed` unblur. A backend change that renames,
 * drops, retypes, or nulls a field these endpoints return — the class of
 * bug that emptied every private chat on 2026-05-23 — fails here before it
 * can reach main.
 *
 * Note an intentional wire divergence locked by these schemas: the group
 * {@see MessageResource} emits `is_blurred`/`is_viewed`
 * as integers, whereas the 1:1 {@see ChatResource}
 * emits them as booleans. Both are pinned to their real types so the live
 * app's parsing of each is protected independently.
 */
class GroupContractTest extends ContractTestCase
{
    use RefreshDatabase;

    private User $owner;

    private User $member;

    private Group $group;

    /**
     * Build a realistic two-member group: `owner` (admin) and `member`,
     * with one text message from the owner so the list and conversation
     * endpoints have content to serialize.
     */
    protected function setUp(): void
    {
        parent::setUp();

        $this->owner = User::factory()->create();
        $this->member = User::factory()->create();

        $this->group = Group::factory()->create(['created_by' => $this->owner->id]);
        GroupMember::factory()->admin()->create([
            'group_id' => $this->group->id,
            'user_id' => $this->owner->id,
        ]);
        GroupMember::factory()->create([
            'group_id' => $this->group->id,
            'user_id' => $this->member->id,
        ]);

        GroupMessage::factory()->create([
            'group_id' => $this->group->id,
            'sender_id' => $this->owner->id,
            'text' => 'hello group',
        ]);
    }

    /** GET /api/auth/group/list matches the group-list contract. */
    #[Test]
    public function group_list_matches_contract(): void
    {
        $response = $this->actingAs($this->owner, 'api')->getJson('/api/auth/group/list');

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'group-list');
    }

    /** GET /api/auth/group/{id}/messages matches the group-messages contract. */
    #[Test]
    public function group_messages_matches_contract(): void
    {
        $response = $this->actingAs($this->member, 'api')
            ->getJson('/api/auth/group/'.$this->group->id.'/messages');

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'group-messages');
    }

    /** POST /api/auth/group/{id}/send matches the group-send contract (text message). */
    #[Test]
    public function group_send_text_matches_contract(): void
    {
        $response = $this->actingAs($this->owner, 'api')
            ->postJson('/api/auth/group/'.$this->group->id.'/send', ['text' => 'sending now']);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'group-send');
    }

    /**
     * POST /api/auth/group/{id}/send with message_type=reaction matches the
     * group-send contract — the group leg of the patent reaction upload
     * (sendGroupMessageRx). The shape must be identical to a normal send so
     * the live app parses a reaction the same way.
     */
    #[Test]
    public function group_send_reaction_matches_contract(): void
    {
        $response = $this->actingAs($this->member, 'api')
            ->postJson('/api/auth/group/'.$this->group->id.'/send', [
                'text' => 'reacted',
                'message_type' => 'reaction',
            ]);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'group-send');
        // The patent contract: a reaction is never blurred or marked viewed.
        $this->assertSame(0, $response->json('data.message.is_blurred'));
        $this->assertSame(0, $response->json('data.message.is_viewed'));
        $this->assertSame('reaction', $response->json('data.message.message_type'));
    }

    /**
     * POST /api/auth/group/mark-viewed/{id} matches the group-mark-viewed
     * contract — the per-user unblur leg of the patent flow for groups.
     */
    #[Test]
    public function group_mark_viewed_matches_contract(): void
    {
        // A blurred media message from the member; the owner is the viewer
        // who will unblur it. Seed the owner's per-user status row blurred,
        // exactly as the send path would.
        $media = GroupMessage::factory()->withMedia()->create([
            'group_id' => $this->group->id,
            'sender_id' => $this->member->id,
        ]);
        GroupMessageUserStatus::create([
            'message_id' => $media->id,
            'user_id' => $this->owner->id,
            'is_viewed' => false,
            'is_blurred' => true,
        ]);

        $response = $this->actingAs($this->owner, 'api')
            ->postJson('/api/auth/group/mark-viewed/'.$media->id);

        $response->assertOk();
        $this->assertMatchesContract($response->json(), 'group-mark-viewed');
    }
}
