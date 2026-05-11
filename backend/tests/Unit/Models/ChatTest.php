<?php

namespace Tests\Unit\Models;

use App\Models\Chat;
use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class ChatTest extends TestCase
{
    use RefreshDatabase;

    // -------- scopeBetweenUsers --------

    #[Test]
    public function scope_between_users_matches_messages_in_either_direction(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $eve   = User::factory()->create();

        $room   = Room::factory()->between($alice, $bob)->create();
        $a_to_b = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'room_id'     => $room->id,
        ]);
        $b_to_a = Chat::factory()->create([
            'sender_id'   => $bob->id,
            'receiver_id' => $alice->id,
            'room_id'     => $room->id,
        ]);
        // Unrelated chat
        $room2  = Room::factory()->between($alice, $eve)->create();
        Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $eve->id,
            'room_id'     => $room2->id,
        ]);

        $ids = Chat::betweenUsers($alice->id, $bob->id)->pluck('id')->all();

        $this->assertEqualsCanonicalizing([$a_to_b->id, $b_to_a->id], $ids);
    }

    // -------- scopeForRoom --------

    #[Test]
    public function scope_for_room_filters_by_room_id(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $room1 = Room::factory()->between($alice, $bob)->create();

        $eve   = User::factory()->create();
        $room2 = Room::factory()->between($alice, $eve)->create();

        $inRoom1 = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'room_id'     => $room1->id,
        ]);
        Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $eve->id,
            'room_id'     => $room2->id,
        ]);

        $ids = Chat::forRoom($room1->id)->pluck('id')->all();

        $this->assertEquals([$inRoom1->id], $ids);
    }

    // -------- scopeUnreadFor --------

    #[Test]
    public function scope_unread_for_returns_only_unread_messages_for_the_user(): void
    {
        $alice = User::factory()->create();
        $bob   = User::factory()->create();
        $room  = Room::factory()->between($alice, $bob)->create();

        $unread = Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'room_id'     => $room->id,
            'status'      => 'sent',
        ]);
        Chat::factory()->create([
            'sender_id'   => $alice->id,
            'receiver_id' => $bob->id,
            'room_id'     => $room->id,
            'status'      => 'read',
        ]);

        $ids = Chat::unreadFor($bob->id)->pluck('id')->all();

        $this->assertEquals([$unread->id], $ids);
    }

    // -------- markAsRead / markAsDelivered --------

    #[Test]
    public function mark_as_read_updates_status_to_read(): void
    {
        $chat = Chat::factory()->create(['status' => 'sent']);

        $this->assertTrue($chat->markAsRead());

        $chat->refresh();
        $this->assertSame('read', $chat->status);
    }

    #[Test]
    public function mark_as_delivered_updates_status_to_delivered(): void
    {
        $chat = Chat::factory()->create(['status' => 'sent']);

        $this->assertTrue($chat->markAsDelivered());

        $chat->refresh();
        $this->assertSame('delivered', $chat->status);
    }

    // -------- hasMedia / isReply / isForwarded --------

    #[Test]
    public function has_media_reflects_presence_of_a_file(): void
    {
        $withMedia = Chat::factory()->blurredMedia()->make();
        $textOnly  = Chat::factory()->make(['file' => null]);

        $this->assertTrue($withMedia->hasMedia());
        $this->assertFalse($textOnly->hasMedia());
    }

    #[Test]
    public function is_reply_reflects_reply_to_id(): void
    {
        $reply  = Chat::factory()->make(['reply_to_id' => 42]);
        $direct = Chat::factory()->make(['reply_to_id' => null]);

        $this->assertTrue($reply->isReply());
        $this->assertFalse($direct->isReply());
    }

    #[Test]
    public function is_forwarded_reflects_forwarded_from(): void
    {
        $fwd    = Chat::factory()->make(['forwarded_from' => 7]);
        $direct = Chat::factory()->make(['forwarded_from' => null]);

        $this->assertTrue($fwd->isForwarded());
        $this->assertFalse($direct->isForwarded());
    }

    // -------- media_type accessor --------

    #[Test]
    public function media_type_attribute_derives_from_file_extension(): void
    {
        $cases = [
            'photo.jpg'  => 'image',
            'photo.PNG'  => 'image',
            'clip.mp4'   => 'video',
            'voice.m4a'  => 'audio',
            'doc.pdf'    => 'document',
            'rando.bin'  => 'file',
        ];

        foreach ($cases as $filename => $expected) {
            $chat = Chat::factory()->make([
                'file'      => $filename,
                'file_type' => null,
            ]);
            $this->assertSame(
                $expected,
                $chat->media_type,
                "Expected media_type='{$expected}' for filename '{$filename}'",
            );
        }
    }

    #[Test]
    public function media_type_attribute_is_null_when_no_file(): void
    {
        $chat = Chat::factory()->make(['file' => null, 'file_type' => null]);
        $this->assertNull($chat->media_type);
    }

    // -------- short_text accessor --------

    #[Test]
    public function short_text_truncates_long_text_and_appends_ellipsis(): void
    {
        $chat = Chat::factory()->make([
            'text' => str_repeat('a', 80),
        ]);
        $this->assertSame(50, mb_strlen($chat->short_text) - 3); // '...' appended
        $this->assertStringEndsWith('...', $chat->short_text);
    }

    #[Test]
    public function short_text_returns_full_text_when_short_enough(): void
    {
        $chat = Chat::factory()->make(['text' => 'hello']);
        $this->assertSame('hello', $chat->short_text);
    }

    #[Test]
    public function short_text_is_null_when_text_is_empty(): void
    {
        $chat = Chat::factory()->make(['text' => null]);
        $this->assertNull($chat->short_text);
    }
}
