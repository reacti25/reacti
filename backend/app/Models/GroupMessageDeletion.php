<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A per-user "delete for me" record for a {@see GroupMessage}.
 *
 * Its presence hides the message from the given user only. Fetches exclude
 * messages that have a deletion for the viewer.
 */
class GroupMessageDeletion extends Model
{
    /** @var list<string> */
    protected $fillable = ['message_id', 'user_id'];
}
