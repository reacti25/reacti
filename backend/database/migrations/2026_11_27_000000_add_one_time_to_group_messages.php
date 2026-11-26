<?php

use App\Services\GroupOneTimeMediaService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One-time media in group chats. See {@see GroupOneTimeMediaService}.
 *
 * On `group_messages`:
 * - `one_time`: the sender marked the photo or video one-time (a reaction to
 *   it inherits the flag).
 * - `one_time_screenshot_at`: a member took a screenshot of it (iPhone).
 * - `one_time_erased_at`: the exchange was erased; the media's row stays as
 *   the trace, with `one_time_reacted` of `one_time_recipients` members.
 *
 * On `group_message_user_statuses`, per member and message:
 * - `opened_at`: when this member opened the media or played the reaction.
 * - `done_at`: when this member's app reported it watched to the end.
 *
 * Every column is added only if missing: the July 2026 attempt left a bare
 * `group_messages.one_time` on the servers, and the 1:1 version of this
 * migration broke the first staging deploy on exactly that.
 */
return new class extends Migration
{
    /** Columns of each table, with how to add each one. */
    private function columns(): array
    {
        return [
            'group_messages' => [
                'one_time' => fn (Blueprint $t) => $t->boolean('one_time')->default(false),
                'one_time_screenshot_at' => fn (Blueprint $t) => $t->timestamp('one_time_screenshot_at')->nullable(),
                'one_time_erased_at' => fn (Blueprint $t) => $t->timestamp('one_time_erased_at')->nullable(),
                'one_time_reacted' => fn (Blueprint $t) => $t->unsignedSmallInteger('one_time_reacted')->nullable(),
                'one_time_recipients' => fn (Blueprint $t) => $t->unsignedSmallInteger('one_time_recipients')->nullable(),
            ],
            'group_message_user_statuses' => [
                'opened_at' => fn (Blueprint $t) => $t->timestamp('opened_at')->nullable(),
                'done_at' => fn (Blueprint $t) => $t->timestamp('done_at')->nullable(),
            ],
        ];
    }

    public function up(): void
    {
        foreach ($this->columns() as $table => $columns) {
            $missing = array_filter($columns, fn ($column) => ! Schema::hasColumn($table, $column), ARRAY_FILTER_USE_KEY);
            if ($missing === []) {
                continue;
            }
            Schema::table($table, function (Blueprint $t) use ($missing) {
                foreach ($missing as $add) {
                    $add($t);
                }
            });
        }
    }

    public function down(): void
    {
        foreach ($this->columns() as $table => $columns) {
            Schema::table($table, function (Blueprint $t) use ($columns) {
                $t->dropColumn(array_keys($columns));
            });
        }
    }
};
