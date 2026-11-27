<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Minimum age
    |--------------------------------------------------------------------------
    |
    | The youngest age that may hold a Reacti account, in years. Enforced
    | server-side on registration (UserRegisterRequest) — the client's date
    | picker is UX, not the control.
    |
    | 16 is a deliberate single worldwide rule (Achia, 2026-08-14): it clears
    | the GDPR-K ceiling so there is no per-country branching, and it fits an
    | app whose core flow records the viewer's face when they open a message.
    |
    | Changing this number changes who can register, so change it here — never
    | inline the value at a call site.
    |
    */
    'min_age' => (int) env('REACTI_MIN_AGE', 16),

    /*
    |--------------------------------------------------------------------------
    | Google Play link
    |--------------------------------------------------------------------------
    |
    | Where the invite page sends Android visitors. Unset (the default), the
    | page shows the App Store to everyone, exactly as before Android existed:
    | a Play button must not appear before there is a listing (or closed-test
    | opt-in page) for it to open. Set it when the Android app is installable
    | (Android plan, Step 10).
    |
    */
    'play_store_url' => env('REACTI_PLAY_STORE_URL'),

    /*
    |--------------------------------------------------------------------------
    | Update prompt
    |--------------------------------------------------------------------------
    |
    | The newest app version per platform, used when the admin settings leave
    | it empty (see AppVersionController); an older app offers to update when
    | it opens. Unset: no prompt. The staging server sets them to test it.
    |
    | update_url: where "Update" goes. The App Store page and the Play listing
    | by default; staging points iPhones at TestFlight instead.
    |
    */
    'latest_version' => [
        'ios' => env('REACTI_LATEST_IOS'),
        'android' => env('REACTI_LATEST_ANDROID'),
    ],
    'update_url' => [
        'ios' => env('REACTI_UPDATE_URL_IOS', 'https://apps.apple.com/app/id6755814897'),
        'android' => env('REACTI_UPDATE_URL_ANDROID', 'https://play.google.com/store/apps/details?id=com.reacti.app'),
    ],
];
