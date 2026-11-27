<?php

namespace Tests\Feature\Group;

use App\Events\GroupMessageReadEvent;
use App\Events\GroupMessageSendEvent;
use App\Events\GroupMessageViewedEvent;
use App\Events\GroupOneTimeChangedEvent;
use App\Http\Resources\MessageResource;
use App\Models\Group;
use App\Models\GroupMember;
use App\Models\GroupMessage;
use App\Models\User;
use App\Services\GroupOneTimeMediaService;
use App\Services\OneTimeMediaService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * One-time media in group chats, end to end on the server:
 *
 *   the sender sends a one-time photo to a group of three -> each member
 *   opens it once with their own link (mark-viewed, the patent trigger) ->
 *   each member's reaction inherits the flag -> everyone plays each
 *   reaction once -> once everyone is done (or after 24 hours) every
 *   reaction and file is gone and the photo's row is the trace.
 *
 * Plus the edges: forged and spent links, a member who joined later, a
 * late reaction, the gallery and forwarding, and screenshot reports.
 */
class GroupOneTimeMediaTest extends TestCase
{
    use RefreshDatabase;

    private User $sender;

    private User $amy;

    private User $ben;

    private Group $group;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Event::fake([
            GroupMessageSendEvent::class,
            GroupMessageViewedEvent::class,
            GroupMessageReadEvent::class,
            GroupOneTimeChangedEvent::class,
        ]);
        $this->sender = User::factory()->create();
        $this->amy = User::factory()->create();
        $this->ben = User::factory()->create();
        $this->group = Group::factory()->create(['created_by' => $this->sender->id]);
        GroupMember::factory()->admin()->create(['group_id' => $this->group->id, 'user_id' => $this->sender->id]);
        foreach ([$this->amy, $this->ben] as $member) {
            $this->join($member);
        }
        // Every request below comes from an app that shows one-time media.
        $this->withHeader(OneTimeMediaService::CLIENT_HEADER, '1');
    }

    private function join(User $member): void
    {
        GroupMember::factory()->create(['group_id' => $this->group->id, 'user_id' => $member->id]);
    }

    /** [$from] sends a one-time photo to the group. */
    private function sendOneTimePhoto(?User $from = null): GroupMessage
    {
        $this->actingAs($from ?? $this->sender, 'api')
            ->post("/api/auth/group/{$this->group->id}/send", [
                'file' => UploadedFile::fake()->image('photo.jpg'),
                'message_type' => 'normal',
                'one_time' => 1,
            ])
            ->assertOk()
            ->assertJsonPath('success', true);

        return GroupMessage::latest('id')->firstOrFail();
    }

    /** [$member]'s silent reaction to [$media] is uploaded. */
    private function sendReaction(User $member, GroupMessage $media): TestResponse
    {
        return $this->actingAs($member, 'api')
            ->post("/api/auth/group/{$this->group->id}/send", [
                'file' => UploadedFile::fake()->create('reaction.mp4', 200, 'video/mp4'),
                'message_type' => 'reaction',
                'reply_to_message_id' => $media->id,
            ], ['Accept' => 'application/json']);
    }

    /** [$member] opens [$media], records and uploads their reaction. */
    private function openAndReact(User $member, GroupMessage $media): GroupMessage
    {
        $this->markViewed($member, $media)->assertOk();
        $this->sendReaction($member, $media)->assertOk();

        return GroupMessage::latest('id')->firstOrFail();
    }

    private function markViewed(User $viewer, GroupMessage $message): TestResponse
    {
        return $this->actingAs($viewer, 'api')->postJson("/api/auth/group/mark-viewed/{$message->id}");
    }

    private function finish(User $viewer, GroupMessage $message): TestResponse
    {
        return $this->actingAs($viewer, 'api')->postJson("/api/auth/group/one-time/{$message->id}/finish");
    }

    /** [$viewer] watches [$message] (a reaction) to the end. */
    private function watch(User $viewer, GroupMessage $message): void
    {
        $this->markViewed($viewer, $message)->assertOk();
        $this->finish($viewer, $message)->assertOk();
    }

    /** The group thread as [$viewer] gets it, keyed by message id. */
    private function thread(User $viewer): array
    {
        $rows = $this->actingAs($viewer, 'api')
            ->getJson("/api/auth/group/{$this->group->id}/messages")
            ->assertOk()
            ->json('data.messages');

        return collect($rows)->keyBy('id')->all();
    }

    private function linkFor(User $viewer, GroupMessage $message): ?string
    {
        return $this->thread($viewer)[$message->id]['file'] ?? null;
    }

    /** A one-time send is flagged, stored off the public disk, and sealed for members. */
    #[Test]
    public function a_one_time_photo_is_stored_privately_and_sealed(): void
    {
        $media = $this->sendOneTimePhoto();

        $this->assertTrue($media->one_time);
        $this->assertStringStartsWith('one-time/', $media->file);
        Storage::disk('local')->assertExists($media->file);
        $this->assertFileDoesNotExist(public_path($media->file));

        $row = $this->thread($this->amy)[$media->id];
        $this->assertTrue($row['is_one_time']);
        $this->assertSame(1, $row['is_blurred'], 'one-time media must stay sealed: the seal drives the reaction recording');
        $this->assertSame('image', $row['media_type']);
    }

    /** Every member gets their own working link; the sender gets none. */
    #[Test]
    public function each_member_has_their_own_link(): void
    {
        $media = $this->sendOneTimePhoto();

        $amyLink = $this->linkFor($this->amy, $media);
        $benLink = $this->linkFor($this->ben, $media);

        $this->assertNotNull($amyLink);
        $this->assertNotSame($amyLink, $benLink);
        $this->assertMatchesRegularExpression('#/api/group-one-time-media/\d+/\d+/[0-9a-f]{64}$#', $amyLink);
        $this->get($amyLink)->assertOk()->assertHeader('Cache-Control', 'no-store, private');
        $this->get($amyLink, ['Range' => 'bytes=0-1'])->assertStatus(206);
        $this->assertNull($this->linkFor($this->sender, $media), 'the sender sees a label, not the photo');
    }

    /** The sender sees how many members opened it so far, and the chat is told live. */
    #[Test]
    public function the_sender_sees_how_many_opened_it(): void
    {
        $media = $this->sendOneTimePhoto();
        $row = $this->thread($this->sender)[$media->id];
        $this->assertSame(0, $row['one_time_opened']);
        $this->assertSame(2, $row['one_time_recipients']);
        $this->assertNull($this->thread($this->amy)[$media->id]['one_time_opened'], 'only for its sender');

        $this->markViewed($this->amy, $media)->assertOk();
        $this->markViewed($this->amy, $media)->assertOk();

        $this->assertSame(1, $this->thread($this->sender)[$media->id]['one_time_opened'], 'a repeat does not count');
        Event::assertDispatchedTimes(GroupOneTimeChangedEvent::class, 1);
    }

    /** A link signed for one member does not work for another. */
    #[Test]
    public function a_forged_link_is_refused(): void
    {
        $media = $this->sendOneTimePhoto();
        $amyLink = $this->linkFor($this->amy, $media);

        $forged = str_replace("/{$this->amy->id}/", "/{$this->ben->id}/", $amyLink);
        $this->get($forged)->assertNotFound();
        $this->get("/api/group-one-time-media/{$media->id}/{$this->amy->id}/".str_repeat('0', 64))->assertNotFound();
    }

    /** Amy opening it closes it for Amy only; finishing closes it at once. */
    #[Test]
    public function opening_closes_it_for_that_member_only(): void
    {
        $media = $this->sendOneTimePhoto();
        $amyLink = $this->linkFor($this->amy, $media);

        $this->markViewed($this->amy, $media)->assertOk();
        $this->get($amyLink)->assertOk();
        $this->travel(OneTimeMediaService::OPEN_WINDOW_MINUTES + 1)->minutes();

        $this->get($amyLink)->assertNotFound();
        $this->assertNull($this->linkFor($this->amy, $media));
        $this->assertArrayHasKey($media->id, $this->thread($this->amy), 'Amy still sees the opened tile');
        $this->assertNotNull($this->linkFor($this->ben, $media), 'Ben has not opened it yet');

        $benLink = $this->linkFor($this->ben, $media);
        $this->markViewed($this->ben, $media)->assertOk();
        $this->finish($this->ben, $media)->assertOk();
        $this->get($benLink)->assertNotFound();
    }

    /** Someone who joined after it was sent never sees it. */
    #[Test]
    public function a_member_who_joined_later_never_sees_it(): void
    {
        $media = $this->sendOneTimePhoto();
        $late = User::factory()->create();
        $this->join($late);

        $this->assertArrayNotHasKey($media->id, $this->thread($late));
        $this->assertArrayNotHasKey($media->id, $this->thread($late), 'still hidden on a second load');
    }

    /** A reaction inherits the flag and is stored privately. */
    #[Test]
    public function a_reaction_to_a_one_timer_is_one_time_too(): void
    {
        $media = $this->sendOneTimePhoto();
        $reaction = $this->openAndReact($this->amy, $media);

        $this->assertTrue($reaction->one_time);
        $this->assertStringStartsWith('one-time/', $reaction->file);
        Storage::disk('local')->assertExists($reaction->file);
    }

    /** Everyone sees a reaction once (after reacting themselves); then it is gone for them. */
    #[Test]
    public function each_member_plays_each_reaction_once(): void
    {
        $media = $this->sendOneTimePhoto();
        $amysReaction = $this->openAndReact($this->amy, $media);

        // The sender sees it at once; Ben only after reacting himself.
        $this->assertNotNull($this->linkFor($this->sender, $amysReaction));
        $this->assertArrayNotHasKey($amysReaction->id, $this->thread($this->ben));
        $this->openAndReact($this->ben, $media);
        $benLink = $this->linkFor($this->ben, $amysReaction);
        $this->assertNotNull($benLink);

        // Ben plays it to the end: gone for him, still there for the sender.
        $this->watch($this->ben, $amysReaction);
        $this->get($benLink)->assertNotFound();
        $this->assertArrayNotHasKey($amysReaction->id, $this->thread($this->ben));
        $this->assertNotNull($this->linkFor($this->sender, $amysReaction));
        // Amy's own reaction stays in her chat, without a link.
        $this->assertNull($this->thread($this->amy)[$amysReaction->id]['file']);
    }

    /** Once every member is done with the photo and every reaction, all of it is erased. */
    #[Test]
    public function the_exchange_is_erased_once_everyone_is_done(): void
    {
        $media = $this->sendOneTimePhoto();
        $amysReaction = $this->openAndReact($this->amy, $media);
        $bensReaction = $this->openAndReact($this->ben, $media);
        foreach ([$this->amy, $this->ben] as $member) {
            $this->finish($member, $media)->assertOk();
        }
        $this->watch($this->sender, $amysReaction);
        $this->watch($this->ben, $amysReaction);
        $this->watch($this->sender, $bensReaction);
        $this->assertNull($media->fresh()->one_time_erased_at, 'Amy has not watched Ben yet');

        $this->watch($this->amy, $bensReaction);

        $trace = $media->fresh();
        $this->assertNotNull($trace->one_time_erased_at);
        $this->assertNull($trace->text);
        $this->assertSame(2, $trace->one_time_reacted);
        $this->assertSame(2, $trace->one_time_recipients);
        $this->assertNull(GroupMessage::withTrashed()->find($amysReaction->id));
        $this->assertNull(GroupMessage::withTrashed()->find($bensReaction->id));
        Storage::disk('local')->assertMissing([$media->file, $amysReaction->file, $bensReaction->file]);
        Event::assertDispatched(GroupOneTimeChangedEvent::class, fn ($e) => $e->groupId === $this->group->id);

        $row = $this->thread($this->amy)[$media->id];
        $this->assertTrue($row['one_time_erased']);
        $this->assertNull($row['file']);
        $this->assertSame(2, $row['one_time_reacted']);
        $this->assertSame(2, $row['one_time_recipients']);
    }

    /** A reaction its sender deleted for everyone does not hold up the erase. */
    #[Test]
    public function a_deleted_reaction_does_not_hold_up_the_erase(): void
    {
        $media = $this->sendOneTimePhoto();
        $amysReaction = $this->openAndReact($this->amy, $media);
        $bensReaction = $this->openAndReact($this->ben, $media);
        $this->actingAs($this->ben, 'api')
            ->deleteJson("/api/auth/group/{$this->group->id}/delete-messages", ['message_ids' => [$bensReaction->id]])
            ->assertOk();
        foreach ([$this->amy, $this->ben] as $member) {
            $this->finish($member, $media)->assertOk();
        }
        $this->watch($this->sender, $amysReaction);

        $this->watch($this->ben, $amysReaction);

        $this->assertNotNull($media->fresh()->one_time_erased_at);
        $this->assertNull(GroupMessage::withTrashed()->find($bensReaction->id), 'its file and row go too');
        Storage::disk('local')->assertMissing($bensReaction->file);
    }

    /** After 24 hours it is erased for everyone, seen or not. */
    #[Test]
    public function after_24_hours_it_is_erased_for_everyone(): void
    {
        $media = $this->sendOneTimePhoto();
        $amysReaction = $this->openAndReact($this->amy, $media);
        $benLink = $this->linkFor($this->ben, $media);

        $this->travel(GroupOneTimeMediaService::TTL_HOURS)->hours();
        $this->travel(1)->minutes();

        $this->get($benLink)->assertNotFound();
        $row = $this->thread($this->ben)[$media->id];
        $this->assertTrue($row['one_time_erased']);
        $this->assertSame(1, $row['one_time_reacted']);
        $this->assertNull(GroupMessage::withTrashed()->find($amysReaction->id));
        Storage::disk('local')->assertMissing([$media->file, $amysReaction->file]);
    }

    /** The prune command erases exchanges nobody came back to. */
    #[Test]
    public function the_prune_command_erases_expired_group_exchanges(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->travel(GroupOneTimeMediaService::TTL_HOURS + 1)->hours();

        $this->artisan('chat:prune-one-time')
            ->expectsOutputToContain('Erased 1 group one-time exchange(s).')
            ->assertSuccessful();

        $this->assertNotNull($media->fresh()->one_time_erased_at);
    }

    /** A reaction that arrives after the erase is refused, so the app drops it. */
    #[Test]
    public function a_late_reaction_is_refused(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->markViewed($this->amy, $media)->assertOk();
        $this->travel(GroupOneTimeMediaService::TTL_HOURS + 1)->hours();

        $this->sendReaction($this->amy, $media)->assertStatus(422);
        $this->assertSame(1, GroupMessage::count());
    }

    /** Not in the shared gallery, and it cannot be forwarded. */
    #[Test]
    public function it_is_kept_out_of_the_gallery_and_forwarding(): void
    {
        $media = $this->sendOneTimePhoto();

        $gallery = $this->actingAs($this->amy, 'api')
            ->getJson("/api/auth/group/{$this->group->id}/messages/media")
            ->assertOk()
            ->json();
        $this->assertStringNotContainsString((string) $media->file, json_encode($gallery));

        $this->actingAs($this->amy, 'api')->postJson('/api/auth/chat/forward', [
            'source_type' => 'group',
            'message_id' => $media->id,
            'recipients' => [['type' => 'group', 'id' => $this->group->id]],
        ]);
        $this->assertSame(1, GroupMessage::count(), 'nothing was forwarded');
    }

    /** A member's screenshot report stamps it; the sender cannot report their own. */
    #[Test]
    public function a_screenshot_report_tells_the_sender(): void
    {
        $media = $this->sendOneTimePhoto();

        $this->actingAs($this->sender, 'api')
            ->postJson("/api/auth/group/one-time/{$media->id}/screenshot")
            ->assertNotFound();
        $this->actingAs($this->amy, 'api')
            ->postJson("/api/auth/group/one-time/{$media->id}/screenshot")
            ->assertOk();

        $this->assertTrue($this->thread($this->sender)[$media->id]['one_time_screenshot']);
        Event::assertDispatched(GroupOneTimeChangedEvent::class);
    }

    /** Only a member it was sent to may say they finished it. */
    #[Test]
    public function finish_is_refused_for_the_sender_and_ordinary_messages(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->finish($this->sender, $media)->assertNotFound();

        $this->actingAs($this->sender, 'api')
            ->post("/api/auth/group/{$this->group->id}/send", [
                'file' => UploadedFile::fake()->image('photo.jpg'),
                'message_type' => 'normal',
            ])
            ->assertOk();
        $ordinary = GroupMessage::latest('id')->firstOrFail();
        $this->finish($this->amy, $ordinary)->assertNotFound();
        @unlink(public_path($ordinary->file));
    }

    /** An app from before one-time media gets a line asking to update, never a link. */
    #[Test]
    public function an_older_app_is_asked_to_update(): void
    {
        $media = $this->sendOneTimePhoto();
        $reaction = $this->openAndReact($this->amy, $media);
        $this->withoutHeader(OneTimeMediaService::CLIENT_HEADER);

        $thread = $this->thread($this->ben);
        $this->assertSame('One-time photo. Update Reacti to open it.', $thread[$media->id]['text']);
        $this->assertNull($thread[$media->id]['file']);
        $this->assertSame(0, $thread[$media->id]['is_blurred']);
        $row = $this->thread($this->sender)[$reaction->id];
        $this->assertSame('One-time reaction. Update Reacti to watch it.', $row['text']);
        $this->assertSame('normal', $row['message_type']);
        $this->assertNull($row['file']);
    }

    /** The broadcast is one payload for every member's phone, so it carries no link. */
    #[Test]
    public function the_broadcast_carries_no_link(): void
    {
        $media = $this->sendOneTimePhoto();

        $payload = (new MessageResource($media->fresh(), 'broadcast'))->resolve();

        $this->assertTrue($payload['is_one_time']);
        $this->assertNull($payload['file']);
        $this->assertSame('One-time photo. Update Reacti to open it.', $payload['text']);
    }

    /** Opening the chat list erases expired group exchanges too. */
    #[Test]
    public function the_chat_list_erases_expired_group_exchanges(): void
    {
        $media = $this->sendOneTimePhoto();
        $this->travel(GroupOneTimeMediaService::TTL_HOURS + 1)->hours();

        $this->actingAs($this->amy, 'api')->getJson('/api/auth/chat/list')->assertOk();

        $this->assertNotNull($media->fresh()->one_time_erased_at);
    }

    /** An ordinary group photo is untouched: public link, no flag, nothing erased. */
    #[Test]
    public function an_ordinary_group_photo_is_unchanged(): void
    {
        $this->actingAs($this->sender, 'api')
            ->post("/api/auth/group/{$this->group->id}/send", [
                'file' => UploadedFile::fake()->image('photo.jpg'),
                'message_type' => 'normal',
            ])
            ->assertOk()
            ->assertJsonPath('data.message.is_one_time', false);
        $photo = GroupMessage::latest('id')->firstOrFail();

        $this->travel(GroupOneTimeMediaService::TTL_HOURS + 1)->hours();
        $row = $this->thread($this->amy)[$photo->id];

        $this->assertFalse($photo->fresh()->one_time);
        $this->assertStringNotContainsString('one-time', $row['file']);
        $this->assertFalse($row['one_time_erased']);
        @unlink(public_path($photo->file));
    }
}
