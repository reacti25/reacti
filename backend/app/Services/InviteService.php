<?php

namespace App\Services;

use App\Models\Friend;
use App\Models\Invite;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Str;

/**
 * Personal-invite business logic (Feature 5).
 *
 * The single seam for minting, resolving, and connecting via invite codes,
 * kept provider-agnostic so a paid deferred-deep-link provider (Branch / Adjust
 * / …) can be added later as configuration, not surgery (DECISION D4): callers
 * only ever deal in the opaque code, never a provider SDK.
 */
class InviteService
{
    /**
     * Return the caller's reusable invite code, minting one on first use.
     *
     * One code per inviter (the `invites.inviter_id` unique constraint), so
     * repeated calls are idempotent and the shared link is stable.
     */
    public function mintFor(User $inviter): Invite
    {
        $existing = Invite::firstWhere('inviter_id', $inviter->id);
        if ($existing !== null) {
            return $existing;
        }

        return Invite::create([
            'inviter_id' => $inviter->id,
            'code' => $this->uniqueCode(),
        ]);
    }

    /**
     * Resolve a code to its invite (with the inviter eager-loaded), or null.
     */
    public function resolve(string $code): ?Invite
    {
        return Invite::with('inviter')->firstWhere('code', $code);
    }

    /**
     * Records a step of the invite loop against [$code].
     *
     * The loop is: link shared -> landing page opened -> web demo watched ->
     * store tapped -> app installed -> account connected. Everything between
     * "shared" and "connected" was invisible, so there was no way to tell
     * whether the web demo earned its place or where the loop leaked.
     *
     * Counted, not flagged: a link dropped into a group chat is opened many
     * times, and that reach is the thing worth knowing.
     *
     * Silent when the code is unknown. This is reachable from a public page, so
     * a bad code is a typo or a probe, not an error worth reporting.
     *
     * @param  string  $code  The invite code from the URL.
     * @param  string  $step  One of `opened`, `demo_completed`, `store_clicked`.
     */
    public function recordFunnelStep(string $code, string $step): void
    {
        $column = match ($step) {
            'opened' => 'opened_count',
            'demo_completed' => 'demo_completed_count',
            'store_clicked' => 'store_clicked_count',
            default => null,
        };
        if ($column === null) {
            return;
        }

        $invite = Invite::firstWhere('code', $code);
        if (! $invite) {
            return;
        }

        // increment() is a single atomic UPDATE, so two people opening the same
        // link at once cannot lose a count to a read-modify-write race.
        $invite->increment($column);

        if ($step === 'opened' && $invite->first_opened_at === null) {
            $invite->forceFill(['first_opened_at' => now()])->saveQuietly();
        }
    }

    /**
     * Connect an arriving invitee to the inviter: create the mutual friendship
     * (idempotent). A self-referential code is a no-op. Reuses the same
     * two-row friendship shape as accepting a friend request.
     */
    public function connect(Invite $invite, User $invitee): void
    {
        if ($invite->inviter_id === $invitee->id) {
            return;
        }

        $this->linkFriends($invite->inviter_id, $invitee->id);
        $this->linkFriends($invitee->id, $invite->inviter_id);
    }

    /** Insert one directed friendship row if it doesn't already exist. */
    private function linkFriends(int $userId, int $friendId): void
    {
        Friend::firstOrCreate(
            ['user_id' => $userId, 'friend_id' => $friendId],
            ['became_friends_at' => Carbon::now()],
        );
    }

    /** Generate an opaque, URL-safe code not already in use. */
    private function uniqueCode(): string
    {
        do {
            $code = Str::lower(Str::random(12));
        } while (Invite::where('code', $code)->exists());

        return $code;
    }
}
