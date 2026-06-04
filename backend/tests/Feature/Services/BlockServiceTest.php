<?php

namespace Tests\Feature\Services;

use App\Models\User;
use App\Models\UserBlock;
use App\Services\BlockService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * BlockService::blockExistsBetween / hasBlocked — the block-state
 * queries consolidated out of ChatService, SingleChatService and
 * FriendService into the single block authority.
 */
class BlockServiceTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Resolve the service under test from the container.
     */
    private function service(): BlockService
    {
        return app(BlockService::class);
    }

    /** `blockExistsBetween` is true when the first user blocked the second. */
    #[Test]
    public function block_exists_between_detects_a_block_in_the_forward_direction(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        UserBlock::create(['user_id' => $a->id, 'block_user_id' => $b->id]);

        $this->assertTrue($this->service()->blockExistsBetween($a->id, $b->id));
    }

    /**
     * `blockExistsBetween` is direction-agnostic — true even when it is
     * the *other* user who created the block.
     */
    #[Test]
    public function block_exists_between_detects_a_block_in_the_reverse_direction(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        UserBlock::create(['user_id' => $b->id, 'block_user_id' => $a->id]);

        $this->assertTrue($this->service()->blockExistsBetween($a->id, $b->id));
    }

    /** `blockExistsBetween` is false when neither user has blocked the other. */
    #[Test]
    public function block_exists_between_is_false_without_a_block(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        $this->assertFalse($this->service()->blockExistsBetween($a->id, $b->id));
    }

    /** `hasBlocked` is true only in the blocker→blocked direction, not the reverse. */
    #[Test]
    public function has_blocked_is_one_directional(): void
    {
        $blocker = User::factory()->create();
        $blocked = User::factory()->create();
        UserBlock::create(['user_id' => $blocker->id, 'block_user_id' => $blocked->id]);

        $this->assertTrue($this->service()->hasBlocked($blocker->id, $blocked->id));
        $this->assertFalse($this->service()->hasBlocked($blocked->id, $blocker->id));
    }

    /** `hasBlocked` is false when no block exists. */
    #[Test]
    public function has_blocked_is_false_without_a_block(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        $this->assertFalse($this->service()->hasBlocked($a->id, $b->id));
    }
}
