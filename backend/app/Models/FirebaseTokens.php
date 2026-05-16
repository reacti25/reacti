<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Model;

/**
 * Eloquent model for a registered Firebase Cloud Messaging device token.
 *
 * Backs the `firebase_tokens` table. Each row links a user to one of
 * their device push tokens; the chat send endpoints fan out push
 * notifications to every token a recipient owns.
 */
class FirebaseTokens extends Model
{
    use HasFactory;

    /** No mass-assignment guard — all columns are assignable. */
    protected $guarded = [];

    /**
     * Relationship: the `User` this device token belongs to.
     *
     * @return BelongsTo
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
