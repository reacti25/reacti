<?php

/**
 * Globally-available procedural helper functions.
 *
 * This file is autoloaded as a "files" entry in composer.json and defines
 * small, framework-wide utilities: filename derivation, email parsing,
 * CMS common-section loading, human-readable number formatting, and URL
 * validation. It declares no class — each function is global.
 */

use App\Enums\PageEnum;
use App\Enums\SectionEnum;
use App\Models\CMS;

/**
 * Build a timestamp-prefixed base name for an uploaded file.
 *
 * Strips the original extension; the prefix keeps generated names unique.
 *
 * @param  \Illuminate\Http\UploadedFile  $file  The uploaded file.
 * @return string A name in the form "<timestamp>_<original-basename>".
 */
function getFileName($file): string
{
    return time().'_'.pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME);
}

/**
 * Extract the local part (before the "@") of an email address.
 *
 * Often used to derive a default display name from an email.
 *
 * @param  string  $email  The full email address.
 * @return string The portion preceding the "@".
 */
function getEmailName($email): string
{
    $parts = explode('@', $email);

    return $parts[0];
}

/**
 * Load the active CMS content for the shared "common" page sections.
 *
 * Iterates the common sections defined by SectionEnum and, for each,
 * fetches the configured number of latest active CMS rows using the
 * section's declared retrieval type (e.g. first/get).
 *
 * @return array<string, mixed> Section key => its loaded CMS content.
 */
function getCommonData()
{
    $common = CMS::where('page', PageEnum::COMMON)->where('status', 'active');
    foreach (SectionEnum::getCommon() as $key => $section) {
        $cms[$key] = (clone $common)->where('section', $key)->latest()->take($section['item'])->{$section['type']}();
    }

    return $cms;
}

/**
 * Format a large number into a compact value with a magnitude suffix.
 *
 * Scales the number down to the nearest thousand-grouping and returns the
 * suffix (K, M, B, T, Q). Numbers below 1,000 are returned with no suffix.
 *
 * @param  int|float  $number  The raw number to format.
 * @param  int  $precision  Decimal places to keep on the scaled value.
 * @return array{number: string, format: string} The formatted number and its suffix.
 */
function formatNumber($number, $precision = 2): array
{
    if ($number >= 1000000000000000) {
        return [
            'number' => number_format($number / 1000000000000000, $precision),
            'format' => 'Q',
        ];
    } elseif ($number >= 1000000000000) {
        return [
            'number' => number_format($number / 1000000000000, $precision),
            'format' => 'T',
        ];
    } elseif ($number >= 1000000000) {
        return [
            'number' => number_format($number / 1000000000, $precision),
            'format' => 'B',
        ];
    } elseif ($number >= 1000000) {
        return [
            'number' => number_format($number / 1000000, $precision),
            'format' => 'M',
        ];
    } elseif ($number >= 1000) {
        return [
            'number' => number_format($number / 1000, $precision),
            'format' => 'K',
        ];
    }

    // For numbers less than 1K, no format suffix is needed
    return [
        'number' => number_format($number),
        'format' => '',
    ];
}

if (! function_exists('is_url')) {
    /**
     * Determine whether a string is a syntactically valid URL.
     *
     * Guarded by function_exists() to avoid clashing with any other
     * library that may define the same global helper.
     *
     * @param  string  $url  The value to validate.
     * @return bool True when the value is a well-formed URL.
     */
    function is_url($url)
    {
        return filter_var($url, FILTER_VALIDATE_URL) !== false;
    }
}
