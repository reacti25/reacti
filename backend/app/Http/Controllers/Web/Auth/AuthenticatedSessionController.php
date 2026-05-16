<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Manages the admin-panel login session (web guard).
 *
 * Serves the `login` / `logout` routes: shows the login form, authenticates
 * an incoming credentials request, and tears the session down on logout.
 * Renders the `auth.login` Blade view. Access is restricted to admins —
 * non-admin accounts are logged straight back out.
 */
class AuthenticatedSessionController extends Controller
{
    /**
     * Display the login view.
     *
     * @return View  The `auth.login` Blade view.
     */
    public function create(): View
    {
        return view('auth.login');
    }

    /**
     * Handle an incoming authentication request.
     *
     * @param  LoginRequest  $request  Form-request that validates credentials and rate limiting.
     * @return RedirectResponse  Redirect to the dashboard for admins, or back to login otherwise.
     */
    public function store(LoginRequest $request): RedirectResponse
    {
        $request->authenticate();
        $request->session()->regenerate();
        $user = auth('web')->user();

        // Only admin accounts may use the web panel; a successfully
        // authenticated non-admin is immediately logged back out.
        if ($user && $user->role === 'admin') {
            return redirect()->intended(route('dashboard', absolute: false));
        } else {
            Auth::logout();
            return redirect()->route('login');
        }

    }

    /**
     * Destroy an authenticated session.
     *
     * @param  Request  $request  The current request, used to invalidate the session.
     * @return RedirectResponse  Redirect to the site root after logout.
     */
    public function destroy(Request $request): RedirectResponse
    {
        Auth::guard('web')->logout();

        $request->session()->invalidate();

        $request->session()->regenerateToken();

        return redirect('/');
    }
}
