<?php

namespace App\Http\Controllers\Api;

use App\Helper\Helper;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\FirebaseTokens;
use App\Models\User;
use Exception;
use Illuminate\Support\Facades\Validator;


/**
 * Manages per-device Firebase Cloud Messaging (FCM) tokens.
 *
 * Backs the authenticated routes that register, fetch, and remove the
 * push-notification token for a given device. These tokens are what
 * the chat controllers fan messages out to via `Helper::sendNotifyMobile`.
 */
class FirebaseTokenController extends Controller
{
    /**
     * Send a test push notification to all of the auth user's devices.
     *
     * Diagnostic endpoint only — pushes a fixed dummy payload so a
     * developer can verify FCM delivery end-to-end.
     *
     * @return \Illuminate\Http\JsonResponse  The user's registered tokens.
     */
    public function test()
    {
        $user = User::find(auth('api')->user()->id);
        if ($user && $user->firebaseTokens) {
            $notifyData = ['title' => "Payment Failed", 'body'  => "test body", 'icon'  => config('settings.logo')];
            foreach ($user->firebaseTokens as $firebaseToken) {
                Helper::sendNotifyMobile($firebaseToken->token, $notifyData);
            }
        }

        return response()->json([
            'status' => true,
            'message' => 'Token saved successfully',
            'data' => $user->firebaseTokens,
            'code' => 200,
        ], 200);
    }

    /**
     * Register (or refresh) the FCM token for the caller's device.
     *
     * Any existing token for the same user + device is deleted first,
     * so each device keeps exactly one current token.
     *
     * @param  Request  $request  Body: token, device_id (both required)
     * @return \Illuminate\Http\JsonResponse  The saved token row, 400 on
     *                                        validation failure, 418 on error
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'token' => 'required|string',
            'device_id' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 400);
        }

        // First delete any existing token for this device so the device
        // never accumulates more than one current token.
        $firebase = FirebaseTokens::where('user_id', auth('api')->user()->id)->where('device_id', $request->device_id);
        if ($firebase) {
            $firebase->delete();
        }

        try {
            $data = new FirebaseTokens();
            $data->user_id = auth('api')->user()->id;
            $data->token = $request->token;
            $data->device_id = $request->device_id;
            $data->status = "active";
            $data->save();

            return response()->json([
                'status' => true,
                'message' => 'Token saved successfully',
                'data' => $data,
                'code' => 200,
            ], 200);
        } catch (Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'No records found',
                'code' => 418,
                'data' => [],
            ], 418);
        }
    }

    /**
     * Fetch the auth user's FCM token for a specific device.
     *
     * @param  Request  $request  Body: device_id (required)
     * @return \Illuminate\Http\JsonResponse  The token row, 400 on
     *                                        validation failure, 404 if none
     */
    public function getToken(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'device_id' => 'required|string',
        ]);
        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 400);
        }
        $user_id = auth('api')->user()->id;
        $device_id = $request->device_id;
        $data = FirebaseTokens::where('user_id', $user_id)->where('device_id', $device_id)->first();
        if (!$data) {
            return response()->json([
                'status' => false,
                'message' => 'No records found',
                'code' => 404,
                'data' => [],
            ], 404);
        }
        return response()->json([
            'status' => true,
            'message' => 'Token fetched successfully',
            'data' => $data,
            'code' => 200,
        ], 200);
    }

    /**
     * Remove the auth user's FCM token for a specific device.
     *
     * Called on sign-out so the server stops pushing to a device the
     * user is no longer signed in on.
     *
     * @param  Request  $request  Body: device_id (required)
     * @return \Illuminate\Http\JsonResponse  Success, 400 on validation
     *                                        failure, 404 if no token exists
     */
    public function deleteToken(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'device_id' => 'required|string',
        ]);
        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 400);
        }

        $user = FirebaseTokens::where('user_id', auth('api')->user()->id)->where('device_id', $request->device_id);
        if ($user) {
            $user->delete();
            return response()->json([
                'status' => true,
                'message' => 'Token deleted successfully',
                'code' => 200,
            ], 200);
        } else {
            return response()->json([
                'status' => false,
                'message' => 'No records found',
                'code' => 404,
            ], 404);
        }
    }
}
