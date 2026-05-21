<?php

namespace App\Traits;

use Illuminate\Http\JsonResponse;

/**
 * Shared trait for building consistent JSON API responses.
 *
 * Every endpoint returns the same envelope shape
 * `{ success, message, data, code }`. {@see error()} additionally
 * emits a legacy `status` key: historically the failure flag was
 * keyed `status` while success used `success`. `status` is kept as a
 * deprecated alias of `success` so older mobile builds keep working;
 * it will be removed once they are off it. New code must read
 * `success` on both the success and the error path.
 */
trait ApiResponse
{
    /**
     * Build a successful JSON response envelope.
     *
     * @param  mixed  $data  Payload to return to the client.
     * @param  string|null  $message  Optional human-readable message.
     * @param  int  $code  HTTP status code (also echoed in body).
     * @return JsonResponse
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
     * Emits `success: false` (the canonical flag) and `status: false`
     * (the deprecated legacy alias — see the trait docblock).
     *
     * @param  mixed  $data  Payload describing the error.
     * @param  string|null  $message  Optional human-readable message.
     * @param  int  $code  HTTP status code (also echoed in body).
     * @return JsonResponse
     */
    public function error($data, $message = null, $code = 500)
    {
        return response()->json([
            'success' => false,
            'status' => false,
            'message' => $message,
            'data' => $data,
            'code' => $code,
        ], $code);
    }
}
