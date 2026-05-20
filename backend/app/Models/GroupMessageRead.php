<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Eloquent model for a per-user read receipt on a group message.
 *
 * Backs the `group_message_reads` table. One row records that a given
 * user read a given `GroupMessage` at `read_at`. Eloquent timestamps
 * are disabled because `read_at` is the only time column needed.
 */
class GroupMessageRead extends Model
{
    use HasFactory;

    /** No created_at/updated_at columns — `read_at` is tracked explicitly. */
    public $timestamps = false;

    /** Attributes mass-assignable when recording a read receipt. */
    protected $fillable = [
        'group_message_id',
        'user_id',
        'read_at',
    ];

    /**
     * Attribute cast definitions.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'read_at' => 'datetime',
    ];

    /**
     * Relationship: the `GroupMessage` that was read.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function message()
    {
        return $this->belongsTo(GroupMessage::class, 'group_message_id');
    }

    /**
     * Relationship: the `User` who read the message.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
