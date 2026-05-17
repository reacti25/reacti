<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Exception;
use Illuminate\Support\Facades\Validator;
use App\Services\FirebaseTokenService;


/**
 * Manages per-device Firebase Cloud Messaging (FCM) tokens.
 *
 * Backs the authenticated routes that register, fetch, and remove the
 * push-notification token for a given device. These tokens are what
 * the chat controllers fan messages out to via `Helper::sendNotifyMobile`.
 * This is a thin controller — it validates input, delegates to
 * {@see FirebaseTokenService}, and builds the bespoke `response()->json`
 * envelopes (this controller does not use the ApiResponse trait).
 */
class FirebaseTokenController extends Controller
{
    /**
     * @param  FirebaseTokenService  $firebaseTokenService  FCM-token business logic.
     */
    public function __construct(private readonly FirebaseTokenService $firebaseTokenService)
    {
        parent::__construct();
    }

    /**
     * Send a test push notification to all of the auth user's devices.
     *
     * Diagnostic endpoint only — pushes a fixed dummy payload so a
     * developer can verify FCM delivery end-to-end. Delegates to
     * {@see FirebaseTokenService::test()}.
     *
     * @return \Illuminate\Http\JsonResponse  The user's registered tokens.
     */
    public function test()
    {
        $user = $this->firebaseTokenService->test(auth('api')->user());

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
     * so each device keeps exactly one current token. Delegates to
     * {@see FirebaseTokenService::store()}.
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

        try {
            $data = $this->firebaseTokenService->store(
                auth('api')->user(),
                $request->token,
                $request->device_id
            );

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
     * Delegates to {@see FirebaseTokenService::getToken()}.
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
        $data = $this->firebaseTokenService->getToken(auth('api')->user(), $request->device_id);
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
     * user is no longer signed in on. Delegates to
     * {@see FirebaseTokenService::deleteToken()}.
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

        $deleted = $this->firebaseTokenService->deleteToken(auth('api')->user(), $request->device_id);
        if ($deleted) {
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
