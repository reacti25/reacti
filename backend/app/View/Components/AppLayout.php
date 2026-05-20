<?php

namespace App\View\Components;

use Illuminate\View\Component;
use Illuminate\View\View;

/**
 * Blade component for the authenticated application shell.
 *
 * Wraps pages shown to logged-in users by rendering the `layouts.app`
 * view (navigation, header, and main content slot).
 */
class AppLayout extends Component
{
    /**
     * Get the view / contents that represents the component.
     *
     * @return \Illuminate\View\View The `layouts.app` Blade view.
     */
    public function render(): View
    {
        return view('layouts.app');
    }
}
