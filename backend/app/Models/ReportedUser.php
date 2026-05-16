<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

/**
 * Eloquent model for an abuse/conduct report filed against a user.
 *
 * Backs the `reported_users` table. `user_id` is the reporter and
 * `reported_user_id` is the user being reported, along with the
 * `reason` and optional free-text `description`.
 */
class ReportedUser extends Model
{
    /** Attributes mass-assignable when filing a report. */
    protected $fillable = ['user_id', 'reported_user_id', 'reason', 'description'];

    /**
     * Relationship: the `User` who was reported.
     *
     * Only the public profile columns are selected so report listings
     * never leak sensitive fields of the reported account.
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function reportedUser()
    {
        return $this->belongsTo(User::class, 'reported_user_id', 'id')
            ->select('id', 'first_name', 'last_name', 'username', 'avatar');
    }
}
