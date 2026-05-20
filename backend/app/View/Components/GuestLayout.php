<?php

namespace App\View\Components;

use Illuminate\View\Component;
use Illuminate\View\View;

/**
 * Blade component for the unauthenticated (guest) layout.
 *
 * Wraps pages shown to visitors who are not logged in — such as login,
 * registration, and password-reset screens — by rendering the
 * `layouts.guest` view.
 */
class GuestLayout extends Component
{
    /**
     * Get the view / contents that represents the component.
     *
     * @return View The `layouts.guest` Blade view.
     */
    public function render(): View
    {
        return view('layouts.guest');
    }
}
