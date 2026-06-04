<?php

namespace App\Http\Controllers\Web\Backend;

use App\Http\Controllers\Controller;
use App\Services\AdminDashboardService;
use Illuminate\View\View;

/**
 * Renders the admin panel's landing dashboard (web guard).
 *
 * Backs the `dashboard` route in routes/backend.php — the page admins land
 * on after login. This is a thin controller: it delegates the summary-stat
 * lookup to {@see AdminDashboardService} and renders the
 * `backend.layouts.dashboard` Blade view.
 */
class DashboardController extends Controller
{
    /**
     * @param  AdminDashboardService  $dashboardService  Dashboard summary-stat logic.
     */
    public function __construct(private readonly AdminDashboardService $dashboardService)
    {
        parent::__construct();
    }

    /**
     * Display the dashboard view.
     *
     * @return View The `backend.layouts.dashboard` view with the total user count.
     */
    public function index()
    {
        $user = auth()->user();
        // Headline metric shown on the dashboard tile.
        $stats = $this->dashboardService->dashboardStats();

        return view('backend.layouts.dashboard', [
            'totalUsers' => $stats['totalUsers'],
        ]);
    }
}
