<?php

use Illuminate\Http\UploadedFile;

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
