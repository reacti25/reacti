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
];
