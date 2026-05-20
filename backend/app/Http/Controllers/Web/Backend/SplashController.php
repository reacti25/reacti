<?php

namespace App\Http\Controllers\Web\Backend;

use App\Http\Controllers\Controller;
use App\Models\Splash;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\View\View;

/**
 * Manages the app's splash-screen content (web guard).
 *
 * Two roles in one controller:
 *  - `Splash` is a read-only JSON endpoint that returns the stored splash
 *    content, consumed by the mobile app on startup.
 *  - `index` / `createOrUpdate` / `destroy` back the admin `admin.splash.*`
 *    routes in routes/backend.php — `index` renders the
 *    `backend.layouts.splash.index` Blade view, the others edit the single
 *    splash record and redirect back.
 */
class SplashController extends Controller
{
    use ApiResponse;

    /**
     * Return the splash-screen content as JSON (for the mobile app).
     *
     * @return \Illuminate\Http\JsonResponse Success payload with the splash row, or a 500 error.
     */
    public function Splash()
    {
        try {
            $data = Splash::first();

            if (! $data) {
                return $this->success([], 'Splash Data not found', 200);
            }

            return $this->success($data, 'Splash Data successfully retrieved', 200);
        } catch (Exception $e) {

            // Log the failure and surface a generic 500 to the caller.
            Log::error($e->getMessage());

            return $this->error($e->getMessage(), 'Error while fetching Splash Data', 500);
        }
    }

    /**
     * Show the splash-screen editor in the admin panel.
     *
     * @return View The `backend.layouts.splash.index` Blade view.
     */
    public function index(): View
    {
        $splash = Splash::first();

        return view('backend.layouts.splash.index', compact('splash'));
    }

    /**
     * Create the splash record, or update it if one already exists.
     *
     * Splash content is a singleton — there is only ever one row.
     *
     * @param  Request  $request  Body: title (required), subtitle (optional).
     * @return RedirectResponse Redirect to the splash editor with a status flash message.
     */
    public function createOrUpdate(Request $request): RedirectResponse
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'subtitle' => 'nullable|string|max:255',
        ]);

        $splash = Splash::first();

        // Update the existing singleton row, or create it on first save.
        if ($splash) {

            $splash->update($request->all());
            $message = 'Splash updated successfully!';
        } else {

            Splash::create($request->all());
            $message = 'Splash created successfully!';
        }

        return redirect()->route('admin.splash.index')->with('status', $message);
    }

    /**
     * Delete the splash record.
     *
     * @param  Splash  $splash  Route-model-bound splash record to delete.
     * @return RedirectResponse Redirect to the splash editor with a status flash message.
     */
    public function destroy(Splash $splash): RedirectResponse
    {
        $splash->delete();

        return redirect()->route('admin.splash.index')->with('status', 'Splash deleted successfully!');
    }
}
