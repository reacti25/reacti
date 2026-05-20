<?php

namespace App\Enums;

/**
 * Backed enum of the public site's CMS page identifiers.
 *
 * Each case maps to the URL slug of a managed marketing page, giving
 * the codebase a type-safe reference instead of loose slug strings
 * when resolving or rendering dynamic page content.
 */
enum PageEnum: string
{
    case HOME_PAGE = 'home-page';
    case EVENT_PAGE = 'event-page';
    case EVENT_DETAILS_PAGE = 'event-details-page';
    case FEATURES_PAGE = 'features-page';
    case NEWSLETTER_PAGE = 'newsletter-page';
}
