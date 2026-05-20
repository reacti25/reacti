<?php

namespace App\Http\Controllers\Web\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Auth\Events\Registered;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules;
use Illuminate\View\View;

/**
 * Handles new user registration on the web side.
 *
 * Serves the `register` routes: shows the registration form and creates a
 * new `User`, firing the `Registered` event and logging the user in.
 * Renders the `auth.register` Blade view.
 */
class RegisteredUserController extends Controller
{
    /**
     * Display the registration view.
     *
     * @return View The `auth.register` Blade view.
     */
    public function create(): View
    {
        return view('auth.register');
    }

    /**
     * Handle an incoming registration request.
     *
     * Validates the input, creates the account with a hashed password,
     * fires the `Registered` event (which triggers email verification),
     * and logs the new user in.
     *
     * @param  Request  $request  Body: name, email, password, password_confirmation.
     * @return RedirectResponse Redirect to the dashboard after the account is created.
     *
     * @throws \Illuminate\Validation\ValidationException When the submitted fields fail validation.
     */
    public function store(Request $request): RedirectResponse
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'lowercase', 'email', 'max:255', 'unique:'.User::class],
            'password' => ['required', 'confirmed', Rules\Password::defaults()],
        ]);

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
        ]);

        event(new Registered($user));

        Auth::login($user);

        return redirect(route('dashboard', absolute: false));
    }
}
