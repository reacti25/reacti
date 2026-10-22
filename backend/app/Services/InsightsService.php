<?php

namespace App\Services;

use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Anonymous per-person journeys for the Reacti Insights dashboard.
 *
 * The analytics (PostHog) only see people on app 1.6.0+ who keep usage data
 * on, and some loop events only fire while a chat is open. The database is
 * the full record, so the dashboard's product numbers (registered users, who
 * sent, whether it was opened, reacted to, and the reaction watched) come
 * from here. Each person is a row of dates and flags with no id, name or
 * email: the dashboard script does the counting.
 *
 * A "Reacti" is a photo or video message (`file` set) that is not itself a
 * reaction. Soft-deleted messages still count: they were sent. Hard-deleted
 * accounts take their messages with them (cascade), so all-time totals are
 * of accounts that still exist.
 */
class InsightsService
{
    /**
     * One row per user account (admins excluded), oldest first.
     *
     * `sent` holds one `[date, opened, reacted, watched]` per Reacti the
     * person sent (flags are 0/1), in date order. Dates are `Y-m-d`.
     *
     * @return list<array{joined: string, sent: list<array>, first_received: ?string}>
     */
    public function journeys(): array
    {
        $sent = $this->privateReactis()->concat($this->groupReactis())->groupBy('sender_id');
        $received = $this->firstReceived();

        return DB::table('users')->where('role', 'user')->orderBy('id')
            ->get(['id', 'created_at'])
            ->map(fn ($u) => [
                'joined' => substr((string) $u->created_at, 0, 10),
                'sent' => ($sent[$u->id] ?? collect())
                    ->map(fn ($r) => [substr((string) $r->created_at, 0, 10), (int) $r->opened, (int) $r->reacted, (int) $r->watched])
                    ->sortBy(fn ($r) => $r[0])->values()->all(),
                'first_received' => isset($received[$u->id]) ? substr((string) $received[$u->id], 0, 10) : null,
            ])->all();
    }

    /**
     * 1:1 Reactis with their outcome flags.
     *
     * Opened = the recipient unblurred it (`is_viewed`). Reacted = a reaction
     * points back at it. Watched = that reaction's own `is_viewed`, which the
     * sender's app sets when they press play on it (app 1.3.0+).
     */
    private function privateReactis(): Collection
    {
        return DB::table('chats as c')->whereNotNull('c.file')->where('c.message_type', '!=', 'reaction')
            ->selectRaw('c.sender_id, c.created_at, c.is_viewed as opened')
            ->selectRaw("exists(select 1 from chats r where r.reply_to_id = c.id and r.message_type = 'reaction') as reacted")
            ->selectRaw("exists(select 1 from chats r where r.reply_to_id = c.id and r.message_type = 'reaction' and r.is_viewed = 1) as watched")
            ->get();
    }

    /**
     * Group Reactis with the same flags. View state is per member
     * (`group_message_user_statuses`), and the sender's own row is created
     * viewed, so opened counts other members only and watched counts the
     * original sender's row on any reaction to it.
     */
    private function groupReactis(): Collection
    {
        return DB::table('group_messages as g')->whereNotNull('g.file')->where('g.message_type', '!=', 'reaction')
            ->selectRaw('g.sender_id, g.created_at')
            ->selectRaw('exists(select 1 from group_message_user_statuses s where s.message_id = g.id and s.user_id != g.sender_id and s.is_viewed = 1) as opened')
            ->selectRaw("exists(select 1 from group_messages r where r.reply_to_message_id = g.id and r.message_type = 'reaction') as reacted")
            ->selectRaw("exists(select 1 from group_messages r join group_message_user_statuses s on s.message_id = r.id and s.user_id = g.sender_id and s.is_viewed = 1 where r.reply_to_message_id = g.id and r.message_type = 'reaction') as watched")
            ->get();
    }

    /**
     * When each user first received a Reacti (1:1 or in a group), keyed by
     * user id. A group status row exists for every member the message reached.
     */
    private function firstReceived(): Collection
    {
        $private = DB::table('chats')->whereNotNull('file')->where('message_type', '!=', 'reaction')
            ->groupBy('receiver_id')->selectRaw('receiver_id as user_id, min(created_at) as at')->get();
        $group = DB::table('group_messages as g')->join('group_message_user_statuses as s', 's.message_id', '=', 'g.id')
            ->whereNotNull('g.file')->where('g.message_type', '!=', 'reaction')->whereColumn('s.user_id', '!=', 'g.sender_id')
            ->groupBy('s.user_id')->selectRaw('s.user_id, min(g.created_at) as at')->get();

        return $private->concat($group)->groupBy('user_id')->map(fn ($rows) => $rows->min('at'));
    }
}
