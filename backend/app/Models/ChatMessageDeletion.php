<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A per-user "delete for me" record for a 1:1 {@see Chat} message.
 *
 * Its presence hides the message from the given user only; the row itself
 * stays. Fetches exclude messages that have a deletion for the viewer.
 */
class ChatMessageDeletion extends Model
{
    /** @var list<string> */
    protected $fillable = ['chat_id', 'user_id'];
}
