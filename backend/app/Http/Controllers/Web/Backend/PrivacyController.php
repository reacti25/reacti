<?php

namespace App\Http\Controllers\Web\Backend;

use App\Http\Controllers\Controller;
use App\Models\PrivecyAndTerms;
use Illuminate\Http\Request;

/**
 * Admin editor for legal / informational content blocks (web guard).
 *
 * Backs the admin routes in routes/backend.php that manage the various
 * `PrivecyAndTerms` content types — terms & conditions, privacy policy,
 * "why desi" carousel copy, and trust & safety text. Each type has a
 * show/update pair: the show action renders an editor Blade view under
 * `backend.layouts.privacy*`, and the update action persists the submitted
 * HTML and redirects back.
 */
class PrivacyController extends Controller
{
    /**
     * Show the terms & conditions editor.
     *
     * @return \Illuminate\View\View The `backend.layouts.privacy.index` view with the terms record.
     */
    public function termsAndCondition()
    {
        $terms = PrivecyAndTerms::first();

        return view('backend.layouts.privacy.index', compact('terms'));
    }

    /**
     * Persist the terms & conditions content.
     *
     * @param  Request  $request  Body: description (required HTML content).
     * @return \Illuminate\Http\RedirectResponse Redirect back with a success flash message.
     */
    public function termsAndConditionUpdate(Request $request)
    {
        $request->validate([
            'description' => 'required',
        ]);

        // Find existing record with type 'terms'
        $terms = PrivecyAndTerms::where('type', 'terms')->first();

        if ($terms) {
            // Update existing record
            $terms->description = $request->description;
        } else {
            // Create new record
            $terms = new PrivecyAndTerms;
            $terms->type = 'terms';
            $terms->description = $request->description;
        }

        $terms->save();

        return redirect()->back()->with('success', 'Terms and Conditions updated successfully.');
    }

    /**
     * Show the privacy policy editor.
     *
     * @return \Illuminate\View\View The `backend.layouts.privacyandterms.privacy_policy` view.
     */
    public function privacyPolicy()
    {
        $privacy = PrivecyAndTerms::where('type', 'privacy')->first();

        return view('backend.layouts.privacyandterms.privacy_policy', compact('privacy'));
    }

    /**
     * Persist the privacy policy content.
     *
     * @param  Request  $request  Body: description (required HTML content).
     * @return \Illuminate\Http\RedirectResponse Redirect back with a success flash message.
     */
    public function privacyPolicyUpdate(Request $request)
    {
        $request->validate([
            'description' => 'required',
        ]);

        // Find existing record with type 'privacy'
        $privacy = PrivecyAndTerms::where('type', 'privacy')->first();

        if ($privacy) {
            // Update existing record
            $privacy->description = $request->description;
        } else {
            // Create new record
            $privacy = new PrivecyAndTerms;
            $privacy->type = 'privacy';
            $privacy->description = $request->description;
        }

        $privacy->save();

        return redirect()->back()->with('success', 'Privacy Policy updated successfully.');
    }

    /**
     * show why desi carouel update page
     *
     * @return \Illuminate\View\View The `backend.layouts.privacyandterms.why_desi_carousel` view.
     */
    public function whyDesiCarousel()
    {
        $why_desi_carousel = PrivecyAndTerms::where('type', 'why_desi_carousel')->first();

        return view('backend.layouts.privacyandterms.why_desi_carousel', compact('why_desi_carousel'));
    }

    /**
     * update why desi carousel
     *
     * @param  Request  $request  Body: description (required HTML content).
     * @return \Illuminate\Http\RedirectResponse Redirect back with a success flash message.
     */
    public function whyDesiCarouselUpdate(Request $request)
    {

        $request->validate([
            'description' => 'required',
        ]);

        // Find existing record with type 'privacy'
        $why_desi_carousel = PrivecyAndTerms::where('type', 'why_desi_carousel')->first();

        if ($why_desi_carousel) {
            // Update existing record
            $why_desi_carousel->description = $request->description;
        } else {
            // Create new record
            $why_desi_carousel = new PrivecyAndTerms;
            $why_desi_carousel->type = 'why_desi_carousel';
            $why_desi_carousel->description = $request->description;
        }

        $why_desi_carousel->save();

        return redirect()->back()->with('success', 'Privacy Policy updated successfully.');
    }

    // trust and service

    /**
     * Show the trust & safety editor.
     *
     * @return \Illuminate\View\View The `backend.layouts.privacyandterms.trust_sefty` view.
     */
    public function trustSefty()
    {
        $trust_and_sefty = PrivecyAndTerms::where('type', 'trust&service')->first();

        return view('backend.layouts.privacyandterms.trust_sefty', compact('trust_and_sefty'));
    }

    /**
     * Persist the trust & safety content.
     *
     * @param  Request  $request  Body: description (required HTML content).
     * @return \Illuminate\Http\RedirectResponse Redirect back with a success flash message.
     */
    public function trustAndService(Request $request)
    {

        $request->validate([
            'description' => 'required',
        ]);

        // Find existing record with type 'privacy'
        $trust_and_service = PrivecyAndTerms::where('type', 'trust&service')->first();

        if ($trust_and_service) {
            // Update existing record
            $trust_and_service->description = $request->description;
        } else {
            // Create new record
            $trust_and_service = new PrivecyAndTerms;
            $trust_and_service->type = 'trust&service';
            $trust_and_service->description = $request->description;
        }

        $trust_and_service->save();

        return redirect()->back()->with('success', 'Privacy Policy updated successfully.');
    }
}
