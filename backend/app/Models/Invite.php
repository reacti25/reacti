<?php

namespace App\Models;

use App\Services\InviteService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A personal invite code (Feature 5).
 *
 * Backs the `invites` table: one opaque, reusable {@see $code} bound to the
 * {@see inviter()} who minted it. When a new user arrives with the code they
 * are offered a one-tap connect. Minting and resolution live in
 * {@see InviteService} so a deferred-deep-link provider can slot
 * in later without touching this model (DECISION D4).
 */
class Invite extends Model
{
    /** @var list<string> Mass-assignable attributes. */
    protected $fillable = [
        'code',
        'inviter_id',
    ];

    /** The user who created and shares this invite. */
    public function inviter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'inviter_id');
    }
}
