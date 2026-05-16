<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Eloquent model for a chat typing-indicator record.
 *
 * Backs the `typing_indicators` table, used to persist transient
 * "user is typing…" state. Currently a bare model with no extra
 * configuration; behaviour is driven entirely by the controllers and
 * broadcast events that read and write it.
 */
class TypingIndicator extends Model
{
    //
}
