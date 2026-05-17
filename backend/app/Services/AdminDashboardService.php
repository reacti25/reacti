<?php

namespace App\Services;

use App\Models\User;

/**
 * Business logic for the admin panel's landing dashboard.
 *
 * Extracted from {@see \App\Http\Controllers\Web\Backend\DashboardController}
 * so the controller only resolves data and renders the Blade view. The
 * service returns plain data (counts/arrays); the controller builds the
 * `view()` response. No behaviour change from the pre-refactor controller.
 */
class AdminDashboardService
{
    /**
     * Gather the summary statistics shown on the dashboard.
     *
     * Currently a single headline metric — the total number of users —
     * exactly as the pre-refactor controller computed inline.
     *
     * @return array  ['totalUsers' => int] for the dashboard view.
     */
    public function dashboardStats(): array
    {
        // Headline metric shown on the dashboard tile.
        $totalUsers = User::count();

        return [
            'totalUsers' => $totalUsers,
        ];
    }
}
