<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Job;
use App\Models\JobReview;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class JobController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        $query = Job::with(['customer', 'assignedWorker']);

        // Filter out private orders from public job listing
        // Only show jobs that don't have assigned_worker_id (public jobs)
        $query->whereNull('assigned_worker_id');

        // Filter out cancelled jobs
        $query->where('status', '!=', 'cancelled');

        // Only show pending jobs (menunggu/terbuka)
        // If status filter is not explicitly provided, default to pending
        if ($request->has('status')) {
            $query->where('status', $request->status);
        } else {
            // Default: only show pending jobs
            $query->where('status', 'pending');
        }

        // Filter out private orders (jobs with is_private_order in additional_info)
        $query->where(function($q) {
            $q->whereNull('additional_info->is_private_order')
              ->orWhere('additional_info->is_private_order', '!=', true);
        });

        // Filter by category
        if ($request->has('category')) {
            $query->where('category', $request->category);
        }

        // Filter by location (within radius)
        if ($request->has('latitude') && $request->has('longitude') && $request->has('radius')) {
            $latitude = $request->latitude;
            $longitude = $request->longitude;
            $radius = $request->radius; // in kilometers

            $query->selectRaw("*, (6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) AS distance", [$latitude, $longitude, $latitude])
                  ->having('distance', '<=', $radius)
                  ->orderBy('distance');
        } else {
            // If no location filter, order by created_at
            $query->orderBy('created_at', 'desc');
        }

        $jobs = $query->paginate(20);

        // Update ratings for customers before returning
        foreach ($jobs->items() as $job) {
            if ($job->customer) {
                $job->customer->updateRating();
                $job->customer->refresh();
            }
            if ($job->assignedWorker) {
                $job->assignedWorker->updateRating();
                $job->assignedWorker->refresh();
            }
        }

        return response()->json([
            'success' => true,
            'data' => $jobs
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'description' => 'required|string',
            'category' => 'required|in:cleaning,maintenance,delivery,tutoring,photography,cooking,gardening,petCare,other',
            'price' => 'required|numeric|min:0',
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
            'address' => 'required|string',
            'scheduled_time' => 'nullable|date|after:now',
            'image_urls' => 'nullable|array',
            'additional_info' => 'nullable|array',
            // Tambahkan validasi untuk assigned_worker_id
            'assigned_worker_id' => 'nullable|integer|exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        $job = new Job();
        $job->customer_id = $request->user()->id;
        $job->title = $request->title;
        $job->description = $request->description;
        $job->category = $request->category;
        $job->price = $request->price;
        $job->latitude = $request->latitude;
        $job->longitude = $request->longitude;
        $job->address = $request->address;
        $job->scheduled_time = $request->scheduled_time;
        $job->image_urls = $request->image_urls;
        $job->additional_info = $request->additional_info;

        // INI PERBAIKAN UTAMANYA: Cek dan simpan assigned_worker_id jika ada
        if ($request->has('assigned_worker_id')) {
            $job->assigned_worker_id = $request->input('assigned_worker_id');
        }
        $job->save();

        // Create notification for job creation (if it's a public job)
        if (!$request->has('assigned_worker_id')) {
            // Public job - no notification needed on creation, will notify when someone applies
        } else {
            // Private order - notify the assigned worker
            NotificationService::createNotificationAndPush(
                $job->assigned_worker_id,
                'private_order_new',
                '📌 Pesanan Pribadi Baru',
                "Anda mendapat pesanan pribadi: \"{$job->title}\"",
                'job',
                $job->id,
                ['job_id' => $job->id, 'job_title' => $job->title]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Job created successfully',
            'data' => $job->load(['customer', 'assignedWorker'])
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(Request $request, string $id)
    {
        $job = Job::with(['customer', 'assignedWorker'])->find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        // Update ratings for customer and assigned worker before returning
        if ($job->customer) {
            $job->customer->updateRating();
            $job->customer->refresh();
        }
        if ($job->assignedWorker) {
            $job->assignedWorker->updateRating();
            $job->assignedWorker->refresh();
        }

        $currentUserReview = null;
        $hasReviewed = false;
        if ($request->user()) {
            $currentUserReview = JobReview::where('job_id', $job->id)
                ->where('reviewer_id', $request->user()->id)
                ->first();
            $hasReviewed = $currentUserReview !== null;
        }

        $job->setAttribute('current_user_review', $currentUserReview);
        $job->setAttribute('has_reviewed_by_current_user', $hasReviewed);

        return response()->json([
            'success' => true,
            'data' => $job
        ]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        // Check if user is the owner of the job
        if ($job->customer_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to update this job'
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'title' => 'sometimes|string|max:255',
            'description' => 'sometimes|string',
            'category' => 'sometimes|in:cleaning,maintenance,delivery,tutoring,photography,cooking,gardening,petCare,other',
            'price' => 'sometimes|numeric|min:0',
            'latitude' => 'sometimes|numeric',
            'longitude' => 'sometimes|numeric',
            // Tambahkan status baru 'pending_completion'
            'address' => 'sometimes|string',
            'scheduled_time' => 'nullable|date|after:now',
            'status' => 'sometimes|in:pending,inProgress,completed,cancelled,disputed,pending_completion',
            'assigned_worker_id' => 'nullable|exists:users,id',
            'image_urls' => 'nullable|array',
            'additional_info' => 'nullable|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        $job->update($request->only([
            'title', 'description', 'category', 'price', 'latitude', 
            'longitude', 'address', 'scheduled_time', 'status', 
            'assigned_worker_id', 'image_urls', 'additional_info'
        ]));

        return response()->json([
            'success' => true,
            'message' => 'Job updated successfully',
            'data' => $job->load(['customer', 'assignedWorker'])
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        // Check if user is the owner of the job
        if ($job->customer_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to delete this job'
            ], 403);
        }

        $job->delete();

        return response()->json([
            'success' => true,
            'message' => 'Job deleted successfully'
        ]);
    }

    /**
     * Apply to a job
     */
    public function apply(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        // Check if user is trying to apply to their own job
        if ($job->customer_id === $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'You cannot apply to your own job'
            ], 400);
        }

        // Check if job is still available
        if ($job->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Job is no longer available for applications'
            ], 400);
        }

        // Check if user already applied
        $existingApplication = \App\Models\JobApplication::where('job_id', $id)
            ->where('worker_id', $request->user()->id)
            ->first();

        if ($existingApplication) {
            if ($existingApplication->status === 'cancelled') {
                $existingApplication->update([
                    'status' => 'pending',
                    'applied_at' => now(),
                ]);
                $application = $existingApplication;
            } else {
                return response()->json([
                    'success' => false,
                    'message' => 'You have already applied to this job'
                ], 400);
            }
        } else {
            $application = \App\Models\JobApplication::create([
                'job_id' => $id,
                'worker_id' => $request->user()->id,
                'status' => 'pending',
                'applied_at' => now(),
            ]);
        }

        // Notify customer about new application
        NotificationService::createNotificationAndPush(
            $job->customer_id,
            'job_application',
            '📝 Ada Pekerja yang Melamar',
            "Ada pekerja mengajukan diri untuk pekerjaan \"{$job->title}\"",
            'job',
            $job->id,
            ['job_id' => $job->id, 'job_title' => $job->title, 'application_id' => $application->id]
        );

        return response()->json([
            'success' => true,
            'message' => 'Application submitted successfully',
            'data' => $application
        ], 201);
    }

    /**
     * Assign a worker to a job
     */
    public function assign(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        // Check if user is the owner of the job
        if ($job->customer_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to assign this job'
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'worker_id' => 'required|exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        $job->update([
            'assigned_worker_id' => $request->worker_id,
            'status' => 'inProgress',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Worker assigned successfully',
            'data' => $job->load(['customer', 'assignedWorker'])
        ]);
    }

    /**
     * Mark a job as complete
     */
    public function complete(Request $request, string $id)
    {
        $job = Job::find($id);

        if (!$job) {
            return response()->json(['success' => false, 'message' => 'Job not found'], 404);
        }

        // Check if the user is the customer
        if ($job->customer_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized action'], 403);
        }

        $additionalInfo = $job->additional_info;
        $isPrivateOrder = false;
        if (is_array($additionalInfo) && isset($additionalInfo['is_private_order'])) {
            $isPrivateOrder = $additionalInfo['is_private_order'];
        }

        if ($isPrivateOrder) {
            // If the job is in progress, set it to pending_completion
            if ($job->status === 'inProgress') {
                $job->update(['status' => 'pending_completion']);
                // We need to re-fetch the job to get the updated status
                $job = Job::find($id);
            }

            // Now, we can call the customerConfirmCompletion method
            return $this->customerConfirmCompletion($request, $id);
        }

        // For public jobs, we follow the two-step completion process
        // This method can be kept for legacy purposes or removed.
        return response()->json([
            'success' => false,
            'message' => 'This endpoint is deprecated for public jobs. Please use the new two-step completion flow.'
        ], 400);
    }

    /**
     * [WORKER] Worker marks a job as complete, waiting for customer confirmation.
     */
    public function workerCompleteJob(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json(['success' => false, 'message' => 'Job not found'], 404);
        }

        // Only the assigned worker can perform this action
        if ($job->assigned_worker_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized action'], 403);
        }

        // Can only be done if the job is in progress
        if ($job->status !== 'inProgress') {
            return response()->json(['success' => false, 'message' => 'Job is not in progress'], 400);
        }

        $job->update(['status' => 'pending_completion']);

        // Notify customer that worker has completed the job
        NotificationService::createNotificationAndPush(
            $job->customer_id,
            'job_completed',
            '⏳ Konfirmasi Penyelesaian',
            "Pekerja mengajukan penyelesaian untuk pesanan \"{$job->title}\". Silakan konfirmasi.",
            'job',
            $job->id,
            ['job_id' => $job->id, 'job_title' => $job->title]
        );

        return response()->json([
            'success' => true,
            'message' => 'Job completion submitted. Waiting for customer confirmation.',
            'data' => $job->load(['customer', 'assignedWorker'])
        ]);
    }

    /**
     * [CUSTOMER] Customer confirms the job is completed.
     */
    public function customerConfirmCompletion(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json(['success' => false, 'message' => 'Job not found'], 404);
        }

        // Only the customer can perform this action
        if ($job->customer_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized action'], 403);
        }

        // Can only be done if the job is waiting for completion confirmation
        if ($job->status !== 'pending_completion') {
            return response()->json(['success' => false, 'message' => 'Job is not awaiting completion confirmation'], 400);
        }

        $job->update([
            'status' => 'completed', 
            'completed_at' => now(),
        ]);

        // Award points to worker for completing the job
        if ($job->assigned_worker_id) {
            $worker = \App\Models\User::find($job->assigned_worker_id);
            if ($worker) {
                // Increment completed jobs count
                $worker->increment('completed_jobs');
                
                // Award points (with bonus if perfect rating)
                $rating = $worker->rating ?? 0.0;
                \App\Services\PointsService::awardJobCompletion($job->assigned_worker_id, $rating);
            }
            
            NotificationService::createNotificationAndPush(
                $job->assigned_worker_id,
                'job_completed',
                '✅ Pesanan Selesai',
                "Pesanan \"{$job->title}\" telah dikonfirmasi selesai oleh customer. Anda mendapat poin!",
                'job',
                $job->id,
                ['job_id' => $job->id, 'job_title' => $job->title]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Job completed successfully',
            'data' => $job->load(['customer', 'assignedWorker'])
        ]);
    }

    /**
     * [CUSTOMER] Customer disputes the job completion.
     */
    public function disputeJob(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json(['success' => false, 'message' => 'Job not found'], 404);
        }

        // Only the customer can perform this action
        if ($job->customer_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized action'], 403);
        }

        // Can only dispute if worker has marked it as complete
        if ($job->status !== 'pending_completion') {
            return response()->json(['success' => false, 'message' => 'Cannot dispute a job that is not awaiting completion'], 400);
        }

        $validator = Validator::make($request->all(), [
            'dispute_reason' => 'required|string|min:10',
        ]);

        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => 'Validation errors', 'errors' => $validator->errors()], 422);
        }

        $additionalInfo = $job->additional_info ?? [];
        $additionalInfo['dispute_reason'] = $request->input('dispute_reason');

        $job->update([
            'status' => 'disputed',
            'additional_info' => $additionalInfo
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Job disputed successfully. We will review your case.',
            'data' => $job->load(['customer', 'assignedWorker'])
        ]);
    }

    /**
     * Review a job
     */
    public function review(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'rating' => 'required|integer|min:1|max:5',
            'comment' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        // Check if user can review this job
        $canReview = false;
        if ($job->customer_id === $request->user()->id) {
            $canReview = true; // Customer reviewing worker
        } elseif ($job->assigned_worker_id === $request->user()->id) {
            $canReview = true; // Worker reviewing customer
        }

        if (!$canReview) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to review this job'
            ], 403);
        }

        $revieweeId = $job->customer_id === $request->user()->id ? $job->assigned_worker_id : $job->customer_id;
        
        // Validate that reviewee_id exists
        if (!$revieweeId) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot review: Job has no assigned worker or customer'
            ], 400);
        }
        
        // Check if review already exists (prevent duplicate reviews)
        $existingReview = \App\Models\JobReview::where('job_id', $id)
            ->where('reviewer_id', $request->user()->id)
            ->first();
        
        if ($existingReview) {
            // Update existing review
            $existingReview->update([
                'rating' => $request->rating,
                'comment' => $request->comment,
            ]);
            $review = $existingReview;
        } else {
            // Create new review
            $review = \App\Models\JobReview::create([
                'job_id' => $id,
                'reviewer_id' => $request->user()->id,
                'reviewee_id' => $revieweeId,
                'rating' => $request->rating,
                'comment' => $request->comment,
            ]);
        }

        // Update the reviewee's rating based on all received reviews
        $reviewee = \App\Models\User::find($revieweeId);
        if ($reviewee) {
            $reviewee->updateRating();
        }

        return response()->json([
            'success' => true,
            'message' => 'Review submitted successfully',
            'data' => $review
        ], 201);
    }

    /**
     * Get reviews for a specific worker/user
     */
    public function getWorkerReviews(string $workerId)
    {
        $worker = \App\Models\User::find($workerId);
        
        if (!$worker) {
            return response()->json([
                'success' => false,
                'message' => 'Worker not found'
            ], 404);
        }

        // Get all reviews for this worker (where they are the reviewee)
        $reviews = \App\Models\JobReview::with(['reviewer', 'job'])
            ->where('reviewee_id', $workerId)
            ->orderBy('created_at', 'desc')
            ->get();

        // Log for debugging
        \Log::info('Getting reviews for worker', [
            'worker_id' => $workerId,
            'reviews_count' => $reviews->count(),
            'reviews' => $reviews->toArray()
        ]);

        return response()->json([
            'success' => true,
            'data' => [
                'data' => $reviews,
                'total' => $reviews->count(),
                'average_rating' => $reviews->avg('rating') ? round($reviews->avg('rating'), 2) : 0.00
            ]
        ]);
    }

    /**
     * Get user's applied jobs
     */
    public function myApplications(Request $request)
    {
        $applications = \App\Models\JobApplication::with(['job.customer', 'job.assignedWorker'])
            ->where('worker_id', $request->user()->id)
            ->orderBy('applied_at', 'desc')
            ->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $applications
        ]);
    }

    /**
     * Get user's created jobs
     */
    public function myJobs(Request $request)
    {
        $jobs = Job::with(['customer', 'assignedWorker'])
            ->where('customer_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $jobs
        ]);
    }

    /**
     * Get jobs assigned to user (for workers)
     */
    public function myAssignedJobs(Request $request)
    {
        $jobs = Job::with(['customer', 'assignedWorker'])
            ->where('assigned_worker_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $jobs
        ]);
    }

    /**
     * Accept a job application
     */
    public function acceptApplication(Request $request, string $id)
    {
        $application = \App\Models\JobApplication::with('job')->find($id);
        
        if (!$application) {
            return response()->json([
                'success' => false,
                'message' => 'Application not found'
            ], 404);
        }

        // Check if user is the job owner
        if ($application->job->customer_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized'
            ], 403);
        }

        // Check if job is still available
        if ($application->job->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Job is no longer available'
            ], 400);
        }

        // Update application status
        $application->update(['status' => 'accepted']);

        // Auto-reject all other pending applications for this job
        $otherApplications = \App\Models\JobApplication::where('job_id', $application->job->id)
            ->where('id', '!=', $application->id)
            ->where('status', 'pending')
            ->get();

        foreach ($otherApplications as $otherApp) {
            $otherApp->update(['status' => 'rejected']);
            
            // Notify other workers that their application was rejected
            NotificationService::createNotificationAndPush(
                $otherApp->worker_id,
                'job_rejected',
                '❌ Lamaran Ditolak',
                "Lamaran Anda untuk pekerjaan \"{$application->job->title}\" telah ditolak karena pekerja lain telah dipilih.",
                'job',
                $application->job->id,
                ['job_id' => $application->job->id, 'job_title' => $application->job->title, 'application_id' => $otherApp->id]
            );
        }

        // Update job status and assign worker
        $application->job->update([
            'status' => 'inProgress',
            'assigned_worker_id' => $application->worker_id
        ]);

        // Notify worker that their application was accepted
        NotificationService::createNotificationAndPush(
            $application->worker_id,
            'job_accepted',
            '✅ Lamaran Diterima',
            "Lamaran Anda untuk pekerjaan \"{$application->job->title}\" telah diterima!",
            'job',
            $application->job->id,
            ['job_id' => $application->job->id, 'job_title' => $application->job->title, 'application_id' => $application->id]
        );

        return response()->json([
            'success' => true,
            'message' => 'Application accepted successfully',
            'data' => $application
        ]);
    }

    /**
     * Reject a job application
     */
    public function rejectApplication(Request $request, string $id)
    {
        $application = \App\Models\JobApplication::with('job')->find($id);
        
        if (!$application) {
            return response()->json([
                'success' => false,
                'message' => 'Application not found'
            ], 404);
        }

        // Check if user is the job owner
        if ($application->job->customer_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized'
            ], 403);
        }

        // Update application status
        $application->update(['status' => 'rejected']);

        // Notify worker that their application was rejected
        NotificationService::createNotificationAndPush(
            $application->worker_id,
            'job_rejected',
            '❌ Lamaran Ditolak',
            "Lamaran Anda untuk pekerjaan \"{$application->job->title}\" telah ditolak",
            'job',
            $application->job->id,
            ['job_id' => $application->job->id, 'job_title' => $application->job->title, 'application_id' => $application->id]
        );

        return response()->json([
            'success' => true,
            'message' => 'Application rejected successfully',
            'data' => $application
        ]);
    }

    /**
     * Get applications for a specific job
     */
    public function getJobApplications(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        // Check if user is the job owner
        if ($job->customer_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized'
            ], 403);
        }

        $applications = \App\Models\JobApplication::with(['worker'])
            ->where('job_id', $id)
            ->orderBy('applied_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $applications
        ]);
    }

    /**
     * Cancel a job
     */
    public function cancelJob(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        $workerApplication = \App\Models\JobApplication::where('job_id', $id)
            ->where('worker_id', $request->user()->id)
            ->first();

        // Check if user is authorized to cancel this job
        $isCustomer = $job->customer_id === $request->user()->id;
        $isWorker = $job->assigned_worker_id === $request->user()->id;
        
        if (!$isCustomer && !$isWorker) {
            if ($workerApplication) {
                if ($workerApplication->status !== 'pending') {
                    return response()->json([
                        'success' => false,
                        'message' => 'Lamaran sudah diproses dan tidak bisa dibatalkan'
                    ], 400);
                }

                $workerApplication->update(['status' => 'cancelled']);

                NotificationService::createNotificationAndPush(
                    $job->customer_id,
                    'job_application_cancelled',
                    'Lamaran Dibatalkan',
                    "Seorang pekerja membatalkan lamaran untuk pekerjaan \"{$job->title}\"",
                    'job',
                    $job->id,
                    [
                        'job_id' => $job->id,
                        'job_title' => $job->title,
                        'application_id' => $workerApplication->id,
                    ]
                );

                return response()->json([
                    'success' => true,
                    'message' => 'Lamaran dibatalkan',
                    'data' => $job->fresh()
                ]);
            }

            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to cancel this job'
            ], 403);
        }

        // Check if job can be cancelled
        if ($job->status === 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'Cannot cancel completed job'
            ], 400);
        }

        // Update job status
        $job->update(['status' => 'cancelled']);

        // If there are pending applications, reject them
        \App\Models\JobApplication::where('job_id', $id)
            ->where('status', 'pending')
            ->update(['status' => 'rejected']);

        // Notify worker if job was assigned
        if ($job->assigned_worker_id && $isCustomer) {
            NotificationService::createNotificationAndPush(
                $job->assigned_worker_id,
                'job_cancelled',
                '❌ Pesanan Dibatalkan',
                "Pesanan \"{$job->title}\" telah dibatalkan oleh customer",
                'job',
                $job->id,
                ['job_id' => $job->id, 'job_title' => $job->title]
            );
        }

        // Notify customer if worker cancelled
        if ($isWorker) {
            NotificationService::createNotificationAndPush(
                $job->customer_id,
                'job_cancelled',
                '❌ Pesanan Dibatalkan',
                "Pesanan \"{$job->title}\" telah dibatalkan oleh pekerja",
                'job',
                $job->id,
                ['job_id' => $job->id, 'job_title' => $job->title]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Job cancelled successfully',
            'data' => $job
        ]);
    }

    /**
     * Accept private order
     */
    public function acceptPrivateOrder(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        // Check if this is a private order
        $additionalInfo = $job->additional_info;
        $isPrivateOrder = false;
        if (is_array($additionalInfo) && isset($additionalInfo['is_private_order'])) {
            $isPrivateOrder = $additionalInfo['is_private_order'];
        }

        if (!$isPrivateOrder) {
            return response()->json([
                'success' => false,
                'message' => 'This is not a private order'
            ], 400);
        }

        // Check if the current user is the assigned worker
        if ($job->assigned_worker_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'You are not assigned to this private order'
            ], 403);
        }

        // Check if job is still pending
        if ($job->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Job is no longer pending'
            ], 400);
        }

        // Update job status to inProgress and set application status to accepted
        $job->update([
            'status' => 'inProgress'
        ]);

        // Notify customer that private order was accepted
        NotificationService::createNotificationAndPush(
            $job->customer_id,
            'private_order_accepted',
            '✅ Pesanan Pribadi Diterima',
            "Pesanan pribadi \"{$job->title}\" telah diterima oleh pekerja",
            'job',
            $job->id,
            ['job_id' => $job->id, 'job_title' => $job->title]
        );

        return response()->json([
            'success' => true,
            'message' => 'Private order accepted successfully',
            'data' => $job
        ]);
    }

    /**
     * Reject private order
     */
    public function rejectPrivateOrder(Request $request, string $id)
    {
        $job = Job::find($id);
        
        if (!$job) {
            return response()->json([
                'success' => false,
                'message' => 'Job not found'
            ], 404);
        }

        // Check if this is a private order
        $additionalInfo = $job->additional_info;
        $isPrivateOrder = false;
        if (is_array($additionalInfo) && isset($additionalInfo['is_private_order'])) {
            $isPrivateOrder = $additionalInfo['is_private_order'];
        }

        if (!$isPrivateOrder) {
            return response()->json([
                'success' => false,
                'message' => 'This is not a private order'
            ], 400);
        }

        // Check if the current user is the assigned worker
        if ($job->assigned_worker_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'You are not assigned to this private order'
            ], 403);
        }

        // Check if job is still pending
        if ($job->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Job is no longer pending'
            ], 400);
        }

        // Update job status to cancelled and set application status to rejected
        $job->update([
            'status' => 'cancelled'
        ]);

        // Notify customer that private order was rejected
        NotificationService::createNotificationAndPush(
            $job->customer_id,
            'private_order_rejected',
            '❌ Pesanan Pribadi Ditolak',
            "Pesanan pribadi \"{$job->title}\" telah ditolak oleh pekerja",
            'job',
            $job->id,
            ['job_id' => $job->id, 'job_title' => $job->title]
        );

        return response()->json([
            'success' => true,
            'message' => 'Private order rejected successfully',
            'data' => $job
        ]);
    }
}