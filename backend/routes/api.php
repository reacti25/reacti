<?php

use App\Http\Controllers\Api\Auth\AnalyticsOptOutController;
use App\Http\Controllers\Api\Auth\AuthenticationController;
use App\Http\Controllers\Api\Auth\ResetPasswordController;
use App\Http\Controllers\Api\Auth\SocialLoginController;
use App\Http\Controllers\Api\Auth\UserProfileController;
use App\Http\Controllers\Api\Chat\ChatController;
use App\Http\Controllers\Api\Chat\Group\GroupCreateController;
use App\Http\Controllers\Api\Chat\Group\GroupManageMemberController;
use App\Http\Controllers\Api\Chat\Group\GroupMessageController;
use App\Http\Controllers\Api\FirebaseTokenController;
use App\Http\Controllers\Api\Friend\FindFriendController;
use App\Http\Controllers\Api\Friend\FriendRequestController;
use App\Http\Controllers\Api\Friend\FriendsController;
use App\Http\Controllers\Api\Friend\ReportUserController;
use App\Http\Controllers\Api\PrivacyController;
use App\Http\Controllers\Api\User\UserBlockController;
use App\Http\Controllers\Api\User\UserController;
use Illuminate\Support\Facades\Route;

// health-check
Route::get('/check', function () {
    return 'Project is running!';
});

// Guest user routes.
//
// Every route here is rate-limited. Without it the 4-digit OTP
// (10,000 combinations) is brute-forceable in minutes. `throttle:6,1`
// = 6 requests/minute/IP for the OTP- and password-sensitive routes;
// login/register/social get a more generous 12/minute so a user
// fat-fingering a password is not locked out, while still capping
// automated attacks.
Route::group(['middleware' => 'guest:api'], function () {
    Route::post('/login', [AuthenticationController::class, 'login'])
        ->middleware('throttle:12,1');
    Route::post('/register', [AuthenticationController::class, 'register'])
        ->middleware('throttle:12,1');
    Route::post('/resend-register-otp', [AuthenticationController::class, 'resendRegisterOtp'])
        ->middleware('throttle:6,1');
    Route::post('/email-verify', [AuthenticationController::class, 'verifyEmail'])
        ->middleware('throttle:6,1');

    // Password Reset
    Route::post('/forgot-password', [ResetPasswordController::class, 'forgotPassword'])
        ->middleware('throttle:6,1');
    Route::post('/verify-otp', [ResetPasswordController::class, 'verifyOTP'])
        ->middleware('throttle:6,1');
    Route::post('/resend-otp', [ResetPasswordController::class, 'resendOtp'])
        ->middleware('throttle:6,1');
    Route::post('/reset-password', [ResetPasswordController::class, 'ResetPassword'])
        ->middleware('throttle:6,1');

    Route::post('social/signin/{provider}', [SocialLoginController::class, 'socialSignin'])
        ->whereIn('provider', ['google', 'apple'])
        ->middleware('throttle:12,1');
});

Route::group(['middleware' => 'auth:api'], function () {

    Route::post('/logout', [AuthenticationController::class, 'logout']); // working

    // Persist the analytics opt-out preference (honoured server-side).
    Route::post('/analytics-opt-out', [AnalyticsOptOutController::class, 'store']);

    // Profile
    Route::get('/profile', [UserProfileController::class, 'profile']); // working
    Route::post('/update-profile', [UserProfileController::class, 'updateProfile']); // working
    Route::post('/update-username', [UserProfileController::class, 'updateUsername']); // working
    Route::post('/update-password', [UserProfileController::class, 'updatePassword']); // working
    Route::delete('/delete-profile', [UserProfileController::class, 'deleteProfile']); // working

    // find contact
    Route::post('/find-contacts', [FindFriendController::class, 'findContacts']);

    // user list
    Route::get('/user-list', [UserController::class, 'userList']);

    // Friend request system
    Route::prefix('/friends')->group(function () {
        Route::post('/send-request', [FriendRequestController::class, 'sendRequest']); // working: send friend request
        Route::post('/cancel-request', [FriendRequestController::class, 'cancelRequest']); // working: cancle friend request
        Route::post('/accept-request', [FriendRequestController::class, 'acceptRequest']); // working: accept friend request
        Route::post('/decline-request', [FriendRequestController::class, 'declineRequest']); // working: decline friend request
        Route::get('/requests', [FriendRequestController::class, 'getRequests']); // working: all incoming requests
        Route::get('/requests/sent/list', [FriendRequestController::class, 'getSentRequests']); // working all send friend request

        Route::get('/list', [FriendsController::class, 'friendList']); // all firend list all auth user

        Route::get('/users/{user}/', [FriendsController::class, 'userFriendList']); // Get another user's friend list

        Route::delete('/unfriend/{id}', [FriendsController::class, 'unfriend']);
    });

    // Get user details
    Route::get('/user-profile/{userId}', [UserController::class, 'userDetais']);

    // User Report system
    Route::prefix('/report')->group(function () {
        Route::post('/user/{reported_user_id}', [ReportUserController::class, 'reportUser']); // working
        Route::get('/list', [ReportUserController::class, 'reportedUsers']); // working
    });

    // User Block system
    Route::prefix('/block')->group(function () {
        Route::post('/user/{block_user_id}', [UserBlockController::class, 'toggleBlock']); // working
        Route::get('/list', [UserBlockController::class, 'blockedUsers']); // working
    });

    Route::middleware(['auth:api'])->controller(ChatController::class)->prefix('auth/chat')->group(function () {
        Route::get('/list', 'listCombined'); // working
        Route::post('/send/{receiver_id}', 'send'); // working
        Route::get('/conversation/{receiver_id}', 'conversation'); // working
        Route::get('room/{receiver_id}', 'room');
        Route::get('/search', 'search'); // working
        Route::get('/seen/all/{receiver_id}', 'seenAll'); // working
        Route::get('/seen/single/{chat_id}', 'seenSingle'); // working
        Route::delete('/delete/{receiver_id}', 'deleteChat'); // working
        Route::delete('/delete/chat/messages', 'deleteMessage'); // working
        Route::post('/mark-viewed/{message_id}', 'markAsViewed'); // wroking
    });

    // The "Chatting System Version 2.0" route group (v2/auth/chat/*,
    // SingleChatController) was removed — it was an unadopted parallel
    // implementation: the mobile client only ever called the v1
    // auth/chat/* routes above. See docs/refactor/big-refactor-plan.md.

    // New group chat routes
    Route::middleware(['auth:api'])->prefix('auth/group')->group(function () {

        // gorup opertation routes
        Route::post('/create', [GroupCreateController::class, 'createGroup']); // working
        Route::get('/list', [GroupCreateController::class, 'listGroups']); // done
        Route::get('/{group_id}', [GroupCreateController::class, 'groupDetails']); // done
        Route::post('/{group_id}/update', [GroupCreateController::class, 'updateGroup']); // absolutely working
        Route::post('/{group_id}/update/avatar', [GroupCreateController::class, 'updateAvatar']); // working

        // message routes
        Route::post('/{group_id}/send', [GroupMessageController::class, 'sendMessage']); // working
        Route::post('/{group_id}/message/{message_id}', [GroupMessageController::class, 'editMessage']); // working
        Route::get('/{group_id}/messages', [GroupMessageController::class, 'getMessages']); // working
        Route::post('/mark-viewed/{message_id}', [GroupMessageController::class, 'markAsViewed']); // wroking
        Route::get('/{group_id}/messages/media', [GroupMessageController::class, 'messageMedia']);
        Route::post('/{group_id}/read', [GroupMessageController::class, 'markAsRead']); // working
        Route::delete('/{group_id}/delete-messages', [GroupMessageController::class, 'deleteMessages']); // working

        // group member routes
        Route::post('/{group_id}/add-members', [GroupManageMemberController::class, 'addMembers']); // working
        Route::delete('/{group_id}/remove-member/{user_id}', [GroupManageMemberController::class, 'removeMember']); // working
        Route::post('/{group_id}/make-admin/{user_id}', [GroupManageMemberController::class, 'makeAdmin']); // working
        Route::post('/{group_id}/remove-admin/{user_id}', [GroupManageMemberController::class, 'removeAdmin']); // working
        Route::post('/{group_id}/leave', [GroupManageMemberController::class, 'leaveGroup']); // working
        Route::delete('/{group_id}/delete', [GroupManageMemberController::class, 'deleteGroup']); // working
        Route::get('/{group}/available-users', [GroupManageMemberController::class, 'availableUsers']);
    });

    // Privacy Policy and Terms & Conditions
    Route::get('/privacy-policy', [PrivacyController::class, 'index']); //

    Route::middleware(['auth:api'])->controller(FirebaseTokenController::class)->prefix('firebase')->group(function () {
        Route::get('test', 'test');
        Route::post('token/add', 'store');
        Route::post('token/get', 'getToken');
        Route::post('token/delete', 'deleteToken');
    });
});
