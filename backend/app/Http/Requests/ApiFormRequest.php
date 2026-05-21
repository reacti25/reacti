<?php

namespace App\Http\Requests;

use App\Traits\ApiResponse;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

/**
 * Base Form Request for the JSON API.
 *
 * Subclasses declare `rules()` (and `authorize()` when a request needs
 * a guard beyond authentication). On a validation failure this base
 * returns the standard {@see ApiResponse} error envelope
 * `{ success:false, status:false, message, data, code }` at HTTP 422 —
 * byte-identical to what the controllers' previous inline
 * `Validator::make(...)` + `$this->error(..., 422)` produced — so
 * migrating a controller to a Form Request is behaviour-preserving.
 */
abstract class ApiFormRequest extends FormRequest
{
    /**
     * Authorize the request.
     *
     * Defaults to true — route middleware (`auth:api`, `guest:api`,
     * throttles) already gates these endpoints. Override in a subclass
     * for request-specific authorization.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Return the standard API error envelope on validation failure.
     *
     * Reports the first validation message — matching the pre-Form-Request
     * behaviour of `$validator->errors()->first()`.
     */
    protected function failedValidation(Validator $validator): void
    {
        throw new HttpResponseException(
            response()->json([
                'success' => false,
                'status' => false,
                'message' => $validator->errors()->first(),
                'data' => [],
                'code' => 422,
            ], 422)
        );
    }
}
