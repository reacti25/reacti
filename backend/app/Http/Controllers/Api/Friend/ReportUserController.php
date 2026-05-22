<?php

namespace App\Http\Controllers\Api\Friend;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Friend\ReportUserRequest;
use App\Http\Resources\ReportedUserCollection;
use App\Services\ModerationService;
use App\Traits\ApiResponse;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Handles user-to-user abuse reports for the API.
 *
 * Backs the authenticated report routes: filing a one-time report
 * against another user and listing the reports the auth user has
 * filed. This is a thin controller — it validates input and delegates
 * to {@see ModerationService}.
 */
class ReportUserController extends Controller
{
    use ApiResponse;

    /**
     * @param  ModerationService  $moderationService  Abuse-report business logic.
     */
    public function __construct(private readonly ModerationService $moderationService)
    {
        parent::__construct();
    }

    /**
     * File a one-time abuse report against another user.
     *
     * A user may report a given target only once (duplicates return
     * 409). Filing a report also severs any friend relationship or
     * pending request between the two users. Delegates to
     * {@see ModerationService::reportUser()}.
     *
     * @param  ReportUserRequest  $request  Body: reason, description (both optional)
     * @param  int  $reported_user_id  URL param: the user being reported
     * @return JsonResponse Success, 404 (unknown target),
     *                      400 (self), 409 (duplicate), 422, 500
     */
    public function reportUser(ReportUserRequest $request, $reported_user_id)
    {
        // Existence check on the URL param — a resource guard returning
        // a 404 (not a 422), so it stays inline rather than in the
        // ReportUserRequest Form Request, which handles only the body.
        $validator = Validator::make(['reported_user_id' => $reported_user_id], [
            'reported_user_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return $this->error([], 'User not found.', 404);
        }

        $user = auth('api')->user();

        try {
            $this->moderationService->reportUser(
                $user,
                $reported_user_id,
                $request->reason,
                $request->description
            );

            return $this->success([], 'User has been reported successfully.');
        } catch (ApiException $e) {
            return $this->error([], $e->getMessage(), $e->status());
        } catch (Exception $e) {
            return $this->error([], 'Something went wrong.', 500);
        }
    }

    /**
     * List the users the authenticated user has reported.
     *
     * Delegates to {@see ModerationService::reportedUsers()}.
     *
     * @param  Request  $request  Query: per_page (default 10)
     * @return JsonResponse Paginated ReportedUserCollection
     */
    public function reportedUsers(Request $request)
    {
        $user = auth('api')->user();

        $perPage = $request->get('per_page', 10); // ?per_page=20

        $reports = $this->moderationService->reportedUsers($user, $perPage);

        return $this->success(
            new ReportedUserCollection($reports),
            'Reported users fetched successfully.'
        );
    }
}
