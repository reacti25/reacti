<?php

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/**
 * Globally-available procedural helper functions.
 *
 * This file is autoloaded as a "files" entry in composer.json and defines
 * small, framework-wide utilities. It declares no class — each function
 * is global.
 */

/**
 * Build a timestamp-prefixed base name for an uploaded file.
 *
 * Strips the original extension; the prefix keeps generated names unique.
 *
 * @param  UploadedFile  $file  The uploaded file.
 * @return string A name in the form "<timestamp>_<original-basename>".
 */
function getFileName($file): string
{
    return time().'_'.pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME);
}

/**
 * Public URL of a stored media path (`uploads/...`) on the media disk.
 *
 * On Hostinger this is `https://reacti.io/uploads/...`, exactly the URL the
 * app always returned; on AWS it is the CloudFront host. Older rows may hold
 * a full URL already; those are returned untouched.
 *
 * @param  string|null  $path  Value of a `file`/`thumbnail`/`avatar` column.
 * @return string|null Absolute URL, or null when the path is empty.
 */
function media_url(?string $path): ?string
{
    if (! $path) {
        return null;
    }
    if (preg_match('#^(https?:)?//#', $path)) {
        return $path;
    }

    return Storage::disk('media')->url($path);
}
