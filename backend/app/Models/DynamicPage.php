<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Eloquent model for a CMS-style dynamic page.
 *
 * Backs the `dynamic_pages` table, holding editable marketing/legal
 * pages (title, URL slug and rich content) that are rendered and served
 * to the public site without requiring a code change.
 */
class DynamicPage extends Model
{
    /** Attributes mass-assignable when creating or editing a page. */
    protected $fillable = [
        'page_title',
        'page_slug',
        'page_content',
        'status',
    ];

    /** Timestamp columns are omitted from serialized output. */
    protected $hidden = ['created_at', 'updated_at'];
}
