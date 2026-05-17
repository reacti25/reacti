<?php

namespace App\Services;

use App\Helper\Helper;
use App\Models\FirebaseTokens;
use App\Models\User;

/**
 * Business logic for per-device Firebase Cloud Messaging (FCM) tokens.
 *
 * Extracted from {@see \App\Http\Controllers\Api\FirebaseTokenController} so
 * the controller only validates input and shapes responses. That controller
 * uses bespoke `response()->json` envelopes rather than the ApiResponse
 * trait, so these methods simply return data (or null) — they do not throw
 * {@see \App\Exceptions\ApiException}; validation and not-found branches
 * stay as direct responses in the controller.
 */
class FirebaseTokenService
{
    /**
     * Send a test push notification to all of the user's devices.
     *
     * Diagnostic only — pushes a fixed dummy payload so a developer can
     * verify FCM delivery end-to-end. Returns the (freshly re-loaded)
     * user so the controller can echo its `firebaseTokens`.
     *
     * @param  User  $authUser  The authenticated user.
     * @return User|null  The re-loaded user, or null if it no longer exists.
     */
    public function test(User $authUser): ?User
    {
        $user = User::find($authUser->id);
        if ($user && $user->firebaseTokens) {
            $notifyData = ['title' => "Payment Failed", 'body'  => "test body", 'icon'  => config('settings.logo')];
            foreach ($user->firebaseTokens as $firebaseToken) {
                Helper::sendNotifyMobile($firebaseToken->token, $notifyData);
            }
        }

        return $user;
    }

    /**
     * Register (or refresh) the FCM token for the user's device.
     *
     * Any existing token for the same user + device is removed first so
     * each device keeps exactly one current token.
     *
     * Note: the pre-refactor `if ($firebase)` test is on a query builder
     * object, which is always truthy — the guard is effectively a no-op
     * and is preserved verbatim here.
     *
     * @param  User    $user       The authenticated user.
     * @param  string  $token      The FCM token to store.
     * @param  string  $deviceId   The device the token belongs to.
     * @return FirebaseTokens  The newly saved token row.
     *
     * @throws \Exception  On an unexpected save failure; the controller
     *                     maps it to its bespoke 418 envelope.
     */
    public function store(User $user, $token, $deviceId): FirebaseTokens
    {
        // First delete any existing token for this device so the device
        // never accumulates more than one current token.
        $firebase = FirebaseTokens::where('user_id', $user->id)->where('device_id', $deviceId);
        if ($firebase) {
            $firebase->delete();
        }

        $data = new FirebaseTokens();
        $data->user_id = $user->id;
        $data->token = $token;
        $data->device_id = $deviceId;
        $data->status = "active";
        $data->save();

        return $data;
    }

    /**
     * Fetch the user's FCM token for a specific device.
     *
     * @param  User    $user      The authenticated user.
     * @param  string  $deviceId  The device whose token to fetch.
     * @return FirebaseTokens|null  The token row, or null when none exists.
     */
    public function getToken(User $user, $deviceId): ?FirebaseTokens
    {
        return FirebaseTokens::where('user_id', $user->id)
            ->where('device_id', $deviceId)
            ->first();
    }

    /**
     * Remove the user's FCM token for a specific device.
     *
     * Note: the pre-refactor `if ($user)` test is on a query builder
     * object, which is always truthy — so the `else`/404 branch in the
     * controller is effectively dead. This is preserved verbatim: the
     * delete always runs and `true` is always returned.
     *
     * @param  User    $user      The authenticated user.
     * @param  string  $deviceId  The device whose token to remove.
     * @return bool  Always true (the always-true guard is preserved).
     */
    public function deleteToken(User $user, $deviceId): bool
    {
        $tokens = FirebaseTokens::where('user_id', $user->id)->where('device_id', $deviceId);
        if ($tokens) {
            $tokens->delete();
            return true;
        }

        return false;
    }
}
