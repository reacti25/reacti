<?php

namespace App\Http\Controllers\Web\Backend;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Post;
use App\Models\User;
use App\Models\Venue;

/**
 * Renders the admin panel's landing dashboard (web guard).
 *
 * Backs the `dashboard` route in routes/backend.php — the page admins land
 * on after login. Renders the `backend.layouts.dashboard` Blade view with
 * summary statistics.
 */
class DashboardController extends Controller
{
    /**
     * Display the dashboard view.
     *
     * @return \Illuminate\View\View  The `backend.layouts.dashboard` view with the total user count.
     */
    public function index()
    {
        $user = auth()->user();
        // Headline metric shown on the dashboard tile.
        $totalUsers = User::count();
        return view('backend.layouts.dashboard', compact(
            'totalUsers',
        ));
    }

   
}
