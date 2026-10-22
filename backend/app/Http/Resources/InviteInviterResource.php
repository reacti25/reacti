<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Public inviter profile returned by `GET /invites/{code}` (Feature 5).
 *
 * This endpoint is unauthenticated (a fresh install resolving a shared code),
 * so it exposes ONLY non-sensitive display fields — never phone, email, or any
 * other PII — enough to render "{Inviter} invited you".
 *
 * @property User $resource
 */
class InviteInviterResource extends JsonResource
{
    /**
     * @param  Request  $request  The incoming request.
     * @return array<string, mixed>
     */
    public function toArray($request): array
    {
        return [
            'id' => $this->resource->id,
            'first_name' => $this->resource->first_name,
            'last_name' => $this->resource->last_name,
            'username' => $this->resource->username,
            'avatar' => $this->resource->avatar ? asset($this->resource->avatar) : null,
        ];
    }
}
