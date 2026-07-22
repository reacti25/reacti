<?php

namespace App\Http\Controllers\Api\Invite;

use App\Http\Controllers\Controller;
use App\Http\Resources\InviteInviterResource;
use App\Services\InviteService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;

/**
 * Personal-invite endpoints (Feature 5).
 *
 * A thin controller over {@see InviteService}:
 *   - {@see store()}   POST /auth/invites            (auth)   → mint/return the caller's code
 *   - {@see show()}    GET  /invites/{code}          (public) → the inviter's public profile
 *   - {@see connect()} POST /auth/invites/{code}/connect (auth) → befriend the inviter
 *
 * The share link itself (reacti.app/i/{code}) is assembled client-side from the
 * returned code, keeping the backend provider-agnostic (DECISION D4).
 */
class InviteController extends Controller
{
    use ApiResponse;

    public function __construct(private readonly InviteService $inviteService)
    {
        parent::__construct();
    }

    /** Mint (or return) the authenticated user's reusable invite code. */
    public function store(): JsonResponse
    {
        $invite = $this->inviteService->mintFor(auth('api')->user());

        return $this->success(['code' => $invite->code], 'Invite code ready.');
    }

    /**
     * Resolve a code to the inviter's public profile. Unauthenticated so a
     * fresh install can surface "{Inviter} invited you" before/after signup.
     */
    public function show(string $code): JsonResponse
    {
        $invite = $this->inviteService->resolve($code);

        if ($invite === null || $invite->inviter === null) {
            return $this->error(null, 'Invite not found.', 404);
        }

        return $this->success(
            new InviteInviterResource($invite->inviter),
            'Inviter fetched.',
        );
    }

    /** One-tap connect: befriend the inviter behind this code. */
    public function connect(string $code): JsonResponse
    {
        $invite = $this->inviteService->resolve($code);

        if ($invite === null) {
            return $this->error(null, 'Invite not found.', 404);
        }

        $this->inviteService->connect($invite, auth('api')->user());

        return $this->success(['inviter_id' => $invite->inviter_id], 'Connected.');
    }
}
