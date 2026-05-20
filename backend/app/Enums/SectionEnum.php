<?php

namespace App\Enums;

/**
 * Backed enum of the content-section types a CMS page can contain.
 *
 * Each case identifies a reusable layout block (hero banner, card,
 * newsletter form, etc.) so page builders and renderers can reference
 * section kinds in a type-safe way rather than via raw strings.
 */
enum SectionEnum: string
{
    case HERO = 'hero';
    case UPCOMING_EVENT = 'upcoming-event';
    case POPULAR_VANUE = 'popular-vanue';
    case APP_DOWNLOAD = 'app-download';
    case NEWSLETTER = 'newsletter';
    case CARD = 'card';
    case TEXT = 'text';
}
