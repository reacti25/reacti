<?php

namespace App\Traits;

/**
 * Shared trait for building consistent JSON API responses.
 *
 * Mixed into controllers so every endpoint returns the same envelope
 * shape ({ success/status, message, data, code }), keeping the mobile
 * client's response handling uniform across the whole API.
 */
trait ApiResponse
{
    /**
     * Build a successful JSON response envelope.
     *
     * @param  mixed  $data  Payload to return to the client.
     * @param  string|null  $message  Optional human-readable message.
     * @param  int  $code  HTTP status code (also echoed in body).
     * @return \Illuminate\Http\JsonResponse
     */
    public function success($data, $message = null, $code = 200)
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
            'code' => $code,

        ], $code);
    }

    /**
     * Build an error JSON response envelope.
     *
     * Note the failure flag is keyed `status` here (not `success` as in
     * {@see success()}); this asymmetry is intentional and matched by
     * the client.
     *
     * @param  mixed  $data  Payload describing the error.
     * @param  string|null  $message  Optional human-readable message.
     * @param  int  $code  HTTP status code (also echoed in body).
     * @return \Illuminate\Http\JsonResponse
     */
    public function error($data, $message = null, $code = 500)
    {
        return response()->json([
            'status' => false,
            'message' => $message,
            'data' => $data,
            'code' => $code,
        ], $code);
    }
}
