<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\JobController;
use App\Http\Controllers\API\SOSController;
use App\Http\Controllers\API\LeaderboardController;
use App\Http\Controllers\API\BadgeController;
use App\Http\Controllers\API\LocationController;
use App\Http\Controllers\API\NotificationController;
use App\Http\Controllers\API\UserController;
use App\Http\Controllers\API\AddressController;
use App\Http\Controllers\API\AdminController;
use App\Http\Controllers\API\FcmTokenController;
use App\Http\Controllers\API\BanComplaintController;

// Public routes (no authentication required)
Route::group([], function () {
    // Authentication routes
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
    Route::post('/reset-password', [AuthController::class, 'resetPassword']);
    
    // Public leaderboard
    Route::get('/leaderboard-public', [LeaderboardController::class, 'index']);
    
    // Public SOS requests (limited data)
    Route::get('/sos', [SOSController::class, 'index']);
    
    // Public jobs (limited data)
    Route::get('/jobs', [JobController::class, 'index']);
    
    // Public rating/review routes (anyone can view reviews)
    Route::get('/ratings/worker/{workerId}', [JobController::class, 'getWorkerReviews']);

    // Public ban complaint submission
    Route::post('/ban-complaints', [BanComplaintController::class, 'store']);
});

// Protected routes (authentication required)
Route::middleware('auth:sanctum')->group(function () {
    // User routes
    Route::get('/user', [AuthController::class, 'user']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/change-password', [AuthController::class, 'changePassword']);
    Route::get('/sessions', [AuthController::class, 'getActiveSessions']);
    Route::post('/logout-all', [AuthController::class, 'logoutAll']);
    Route::delete('/sessions/{tokenId}', [AuthController::class, 'revokeToken']);
    Route::put('/profile', [UserController::class, 'updateProfile']);
    Route::post('/profile/upload-image', [UserController::class, 'uploadProfileImage']);
    Route::get('/profile', [UserController::class, 'getProfile']);
    
    // My jobs routes (must be before /jobs/{id} routes)
    Route::get('/jobs/my-applications', [JobController::class, 'myApplications']);
    Route::get('/jobs/my-jobs', [JobController::class, 'myJobs']);
    Route::get('/jobs/my-assigned-jobs', [JobController::class, 'myAssignedJobs']);
    
    // Job routes
    Route::post('/jobs', [JobController::class, 'store']);
    Route::get('/jobs/{id}', [JobController::class, 'show']);
    Route::put('/jobs/{id}', [JobController::class, 'update']);
    Route::delete('/jobs/{id}', [JobController::class, 'destroy']);
    Route::post('/jobs/{id}/apply', [JobController::class, 'apply']);
    Route::post('/jobs/{id}/assign', [JobController::class, 'assign']);
    Route::post('/jobs/{id}/complete', [JobController::class, 'complete']);
    Route::post('/jobs/{id}/review', [JobController::class, 'review']);
    Route::post('/jobs/{id}/cancel', [JobController::class, 'cancelJob']);
    Route::post('/jobs/{id}/accept-private', [JobController::class, 'acceptPrivateOrder']);
    Route::post('/jobs/{id}/reject-private', [JobController::class, 'rejectPrivateOrder']);
    Route::get('/jobs/{id}/applications', [JobController::class, 'getJobApplications']);
    Route::post('/applications/{id}/accept', [JobController::class, 'acceptApplication']);
    Route::post('/applications/{id}/reject', [JobController::class, 'rejectApplication']);
    
    // SOS routes
    Route::post('/sos', [SOSController::class, 'store']);
    Route::get('/sos/{id}', [SOSController::class, 'show']);
    Route::put('/sos/{id}', [SOSController::class, 'update']);
    Route::delete('/sos/{id}', [SOSController::class, 'destroy']);
    Route::post('/sos/{id}/respond', [SOSController::class, 'respond']);
    Route::get('/sos/user/{userId}', [SOSController::class, 'getByUser']);
    
    // Leaderboard routes
    Route::get('/leaderboard', [LeaderboardController::class, 'index']);
    Route::get('/leaderboard/user/{userId}', [LeaderboardController::class, 'getUserRanking']);
    
    // Badge routes
    Route::get('/badges', [BadgeController::class, 'index']);
    Route::get('/badges/user/{userId}', [BadgeController::class, 'getUserBadges']);
    Route::post('/badges/assign', [BadgeController::class, 'assignBadge']);
    
    // Location routes
    Route::post('/location/update', [LocationController::class, 'updateLocation']);
    Route::get('/location/nearby', [LocationController::class, 'getNearbyUsers']);
    
    // Notification routes
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/mark-read', [NotificationController::class, 'markAsRead']);
    Route::post('/notifications/mark-all-read', [NotificationController::class, 'markAllAsRead']);
    Route::delete('/notifications/{id}', [NotificationController::class, 'destroy']);
    
    // TEST ENDPOINTS untuk testing notifikasi via Postman
    Route::post('/notifications/test', [NotificationController::class, 'testNotification']);
    Route::post('/notifications/test-job', [NotificationController::class, 'testJobNotification']);

    // FCM token route
    Route::post('/fcm/token', [FcmTokenController::class, 'update']);
    
    // Address routes
    Route::get('/addresses', [AddressController::class, 'index']);
    Route::post('/addresses', [AddressController::class, 'store']);
    Route::put('/addresses/{id}', [AddressController::class, 'update']);
    Route::delete('/addresses/{id}', [AddressController::class, 'destroy']);
    Route::post('/addresses/{id}/set-default', [AddressController::class, 'setDefault']);

    Route::post('jobs/{id}/worker-complete', [JobController::class, 'workerCompleteJob']);
    Route::post('jobs/{id}/customer-confirm', [JobController::class, 'customerConfirmCompletion']);
    Route::post('jobs/{id}/dispute', [JobController::class, 'disputeJob']);

    Route::middleware('ensure_admin')->prefix('admin')->group(function () {
        Route::get('/dashboard', [AdminController::class, 'dashboard']);
        Route::get('/users', [AdminController::class, 'users']);
        Route::post('/users/{user}/ban', [AdminController::class, 'banUser']);
        Route::post('/users/{user}/unban', [AdminController::class, 'unbanUser']);
        Route::get('/jobs', [AdminController::class, 'jobs']);
        Route::post('/jobs/{job}/force-cancel', [AdminController::class, 'forceCancelJob']);
        Route::get('/sos', [AdminController::class, 'sos']);
        Route::get('/reviews', [AdminController::class, 'reviews']);
        Route::delete('/reviews/{review}', [AdminController::class, 'deleteReview']);
        Route::get('/ban-complaints', [AdminController::class, 'banComplaints']);
        Route::post('/ban-complaints/{complaint}/handle', [AdminController::class, 'handleBanComplaint']);
    });
});