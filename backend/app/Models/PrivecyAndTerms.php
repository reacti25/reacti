<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Eloquent model for legal content (privacy policy / terms of service).
 *
 * Backs the (intentionally so-spelled) `privecy_and_terms` table. Each
 * row stores one legal document, identified by `type`, which is served
 * to the app and public site.
 */
class PrivecyAndTerms extends Model
{
    /** Explicit table name — kept matching the legacy spelling in the DB. */
    protected $table = 'privecy_and_terms';

    /** Attributes mass-assignable when editing a legal document. */
    protected $fillable = ['type', 'description'];

    /** Timestamp columns are omitted from serialized output. */
    protected $hidden = ['created_at', 'updated_at'];

    /**
     * Accessor that capitalizes the document `type` for display.
     *
     * @param  string  $value  Raw stored type value.
     * @return string  The type with its first letter upper-cased.
     */
    public function getTypeAttribute($value)
    {
        return ucfirst($value);
    }
}
