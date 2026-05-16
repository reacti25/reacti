<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Eloquent model for a global application setting.
 *
 * Backs the `settings` table — a simple key/value style store for
 * admin-configurable options. Mass assignment is fully open since the
 * column set is controlled entirely by the admin panel.
 */
class Setting extends Model
{
    /** No mass-assignment guard — all columns are assignable. */
    protected $guarded = [];
}

