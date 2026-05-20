<?php

namespace App\Exceptions;

use App\Traits\ApiResponse;
use Exception;

/**
 * Domain exception that carries an HTTP status code.
 *
 * Thrown by service-layer classes to signal an *expected* business-rule
 * failure — a bad OTP, a throttled request, a missing record, an
 * unauthorized action, and so on. The controller catches it and maps it
 * straight onto the {@see ApiResponse::error()} envelope,
 * reproducing the exact status code and message the pre-refactor inline
 * checks returned. Unexpected failures keep bubbling up as plain
 * {@see Exception}s and are mapped to a 500 by the controller.
 */
class ApiException extends Exception
{
    /** @var int HTTP status code to send on the error response. */
    protected int $status;

    /**
     * @param  string  $message  Human-readable error message for the client.
     * @param  int  $status  HTTP status code (e.g. 400, 401, 403, 404, 429).
     */
    public function __construct(string $message, int $status = 400)
    {
        parent::__construct($message);
        $this->status = $status;
    }

    /**
     * The HTTP status code the controller should respond with.
     */
    public function status(): int
    {
        return $this->status;
    }
}
