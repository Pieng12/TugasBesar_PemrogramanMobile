<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\BanComplaint;
use App\Models\Job;
use App\Models\JobReview;
use App\Models\SOSRequest;
use App\Models\User;
use App\Models\UserBan;
use App\Services\NotificationService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class AdminController extends Controller
{
    public function dashboard()
    {
        $stats = [
            'total_users' => User::count(),
            'banned_users' => User::where('is_banned', true)->count(),
            'active_jobs' => Job::whereIn('status', ['pending', 'inProgress', 'pending_completion'])->count(),
            'disputed_jobs' => Job::where('status', 'disputed')->count(),
            'active_sos' => SOSRequest::where('status', 'active')->count(),
            'completed_sos' => SOSRequest::where('status', 'completed')->count(),
            'total_reviews' => JobReview::count(),
        ];

        $recentActions = AdminAction::with('admin')
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        $recentBans = UserBan::with(['user', 'admin'])
            ->orderBy('created_at', 'desc')
            ->limit(5)
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'stats' => $stats,
                'recent_actions' => $recentActions,
                'recent_bans' => $recentBans,
            ],
        ]);
    }

    public function users(Request $request)
    {
        $query = User::query()->withCount(['jobs as total_jobs' => function ($q) {
            $q->whereIn('status', ['pending', 'inProgress', 'pending_completion']);
        }]);

        if ($request->filled('role')) {
            $query->where('role', $request->role);
        }

        if ($request->filled('status')) {
            if ($request->status === 'banned') {
                $query->where('is_banned', true);
            } elseif ($request->status === 'active') {
                $query->where('is_banned', false);
            }
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        $users = $query->orderBy('created_at', 'desc')->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $users,
        ]);
    }

    public function banUser(Request $request, User $user)
    {
        $validator = Validator::make($request->all(), [
            'duration_days' => 'nullable|integer|min:1|max:365',
            'banned_until' => 'nullable|date|after:now',
            'is_permanent' => 'nullable|boolean',
            'reason' => 'required|string|min:10',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $validator->errors(),
            ], 422);
        }

        $isPermanent = $request->boolean('is_permanent', false);

        // If not permanent, require duration or banned_until
        if (!$isPermanent && !$request->filled('duration_days') && !$request->filled('banned_until')) {
            return response()->json([
                'success' => false,
                'message' => 'Harap tentukan durasi ban, tanggal berakhir, atau pilih ban permanen.',
            ], 422);
        }

        if ($user->id === $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak dapat memblokir akun sendiri.',
            ], 400);
        }

        if ($user->isAdmin() && !$request->user()->isAdmin()) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak dapat memblokir administrator lain.',
            ], 403);
        }

        // If permanent, set banned_until to null
        $banUntil = $isPermanent 
            ? null 
            : ($request->filled('banned_until')
                ? Carbon::parse($request->banned_until)
                : now()->addDays($request->duration_days));

        DB::transaction(function () use ($user, $request, $banUntil, $isPermanent) {
            $user->update([
                'is_banned' => true,
                'ban_started_at' => now(),
                'banned_until' => $banUntil,
                'ban_reason' => $request->reason,
                'last_banned_by' => $request->user()->id,
            ]);

            UserBan::create([
                'user_id' => $user->id,
                'admin_id' => $request->user()->id,
                'banned_from' => now(),
                'banned_until' => $banUntil, // null for permanent ban
                'reason' => $request->reason,
                'metadata' => [
                    'duration_days' => $isPermanent ? null : $request->duration_days,
                    'is_permanent' => $isPermanent,
                ],
            ]);

            $user->tokens()->delete();

            AdminAction::create([
                'admin_id' => $request->user()->id,
                'action_type' => 'user_banned',
                'target_type' => 'user',
                'target_id' => $user->id,
                'reason' => $request->reason,
                'metadata' => [
                    'banned_until' => $banUntil,
                    'is_permanent' => $isPermanent,
                ],
            ]);
        });

        $banMessage = $isPermanent
            ? "Akun Anda diblokir permanen karena: {$request->reason}"
            : "Akun Anda diblokir hingga {$banUntil->format('d M Y H:i')} karena: {$request->reason}";

        NotificationService::createNotification(
            $user->id,
            'admin_ban',
            'Akun Anda Diblokir',
            $banMessage,
            'user',
            $user->id,
            [
                'banned_until' => $banUntil,
                'is_permanent' => $isPermanent,
                'reason' => $request->reason,
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'User berhasil diblokir.',
        ], 200);
    }

    public function unbanUser(Request $request, User $user)
    {
        if (!$user->is_banned) {
            return response()->json([
                'success' => false,
                'message' => 'User tidak sedang dalam status blokir.',
            ], 400);
        }

        DB::transaction(function () use ($user, $request) {
            $lastBan = UserBan::where('user_id', $user->id)->latest()->first();
            if ($lastBan && !$lastBan->lifted_at) {
                $lastBan->update(['lifted_at' => now()]);
            }

            $user->clearBan();

            AdminAction::create([
                'admin_id' => $request->user()->id,
                'action_type' => 'user_unbanned',
                'target_type' => 'user',
                'target_id' => $user->id,
                'reason' => $request->reason,
            ]);
        });

        NotificationService::createNotification(
            $user->id,
            'admin_unban',
            'Akun Anda Aktif Kembali',
            'Akun Anda sudah diaktifkan kembali. Tetap patuhi pedoman komunitas kami.',
            'user',
            $user->id
        );

        return response()->json([
            'success' => true,
            'message' => 'Status blokir user telah dicabut.',
        ]);
    }

    public function jobs(Request $request)
    {
        $query = Job::with(['customer', 'assignedWorker', 'cancelledByAdmin']);

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('only_flagged') && $request->boolean('only_flagged')) {
            $query->where(function ($q) {
                $q->whereNotNull('admin_cancel_reason')
                    ->orWhere('status', 'disputed');
            });
        }

        $jobs = $query->orderBy('created_at', 'desc')->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $jobs,
        ]);
    }

    public function forceCancelJob(Request $request, Job $job)
    {
        $validator = Validator::make($request->all(), [
            'reason' => 'required|string|min:10',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Alasan wajib diisi.',
                'errors' => $validator->errors(),
            ], 422);
        }

        if ($job->status === 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'Tidak dapat membatalkan pesanan yang sudah selesai.',
            ], 400);
        }

        $job->status = 'cancelled';
        $job->cancelled_by_admin_id = $request->user()->id;
        $job->admin_cancel_reason = $request->reason;
        $job->admin_cancelled_at = now();

        $additionalInfo = $job->additional_info;
        if (is_string($additionalInfo)) {
            $decoded = json_decode($additionalInfo, true);
            $additionalInfo = is_array($decoded) ? $decoded : [];
        } elseif (!is_array($additionalInfo)) {
            $additionalInfo = [];
        }

        $additionalInfo['admin_cancel'] = [
            'reason' => $request->reason,
            'cancelled_at' => now()->toDateTimeString(),
            'admin_id' => $request->user()->id,
        ];
        $job->additional_info = $additionalInfo;
        $job->save();

        AdminAction::create([
            'admin_id' => $request->user()->id,
            'action_type' => 'job_cancelled',
            'target_type' => 'job',
            'target_id' => $job->id,
            'reason' => $request->reason,
        ]);

        if ($job->customer_id) {
            NotificationService::createNotification(
                $job->customer_id,
                'admin_job_cancelled',
                'Pesanan Dihapus Admin',
                "Pesanan \"{$job->title}\" dibatalkan oleh admin. Alasan: {$request->reason}",
                'job',
                $job->id,
                ['reason' => $request->reason]
            );
        }

        if ($job->assigned_worker_id) {
            NotificationService::createNotification(
                $job->assigned_worker_id,
                'admin_job_cancelled',
                'Pesanan Dihapus Admin',
                "Pesanan \"{$job->title}\" dibatalkan oleh admin. Silakan hubungi dukungan jika perlu.",
                'job',
                $job->id,
                ['reason' => $request->reason]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Pesanan berhasil dibatalkan oleh admin.',
            'data' => $job->fresh(['customer', 'assignedWorker']),
        ]);
    }

    public function sos(Request $request)
    {
        $query = SOSRequest::with(['requester', 'helper']);

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('requester_id')) {
            $query->where('requester_id', $request->requester_id);
        }

        $sos = $query->orderBy('created_at', 'desc')->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $sos,
        ]);
    }

    public function reviews(Request $request)
    {
        $query = JobReview::with(['reviewer', 'reviewee', 'job']);

        if ($request->filled('rating')) {
            $query->where('rating', $request->rating);
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('comment', 'like', "%{$search}%")
                    ->orWhereHas('reviewer', function ($qr) use ($search) {
                        $qr->where('name', 'like', "%{$search}%");
                    })
                    ->orWhereHas('reviewee', function ($qe) use ($search) {
                        $qe->where('name', 'like', "%{$search}%");
                    });
            });
        }

        $reviews = $query->orderBy('created_at', 'desc')->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $reviews,
        ]);
    }

    public function deleteReview(Request $request, JobReview $review)
    {
        $validator = Validator::make($request->all(), [
            'reason' => 'required|string|min:10',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Alasan wajib diisi.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $reviewData = $review->load(['reviewer', 'reviewee', 'job'])->toArray();
        $reviewee = $review->reviewee;
        $reviewerId = $review->reviewer_id;
        $jobId = $review->job_id;

        $review->delete();

        if ($reviewee) {
            $reviewee->updateRating();
        }

        AdminAction::create([
            'admin_id' => $request->user()->id,
            'action_type' => 'review_deleted',
            'target_type' => 'job_review',
            'target_id' => $reviewData['id'] ?? null,
            'reason' => $request->reason,
            'metadata' => $reviewData,
        ]);

        if ($reviewerId) {
            NotificationService::createNotification(
                $reviewerId,
                'admin_review_removed',
                'Review Dihapus Admin',
                "Review Anda untuk pesanan #{$jobId} dihapus karena: {$request->reason}",
                'job',
                $jobId,
                ['reason' => $request->reason]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Review berhasil dihapus.',
        ]);
    }

    public function banComplaints(Request $request)
    {
        $query = BanComplaint::with(['user', 'handler'])->orderBy('created_at', 'desc');

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        $complaints = $query->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $complaints,
        ]);
    }

    public function handleBanComplaint(Request $request, BanComplaint $complaint)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:pending,reviewed,resolved,rejected',
            'admin_notes' => 'nullable|string|min:5',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $complaint->status = $request->status;
        $complaint->admin_notes = $request->admin_notes;
        $complaint->handled_by = $request->user()->id;
        $complaint->handled_at = now();
        $complaint->save();

        AdminAction::create([
            'admin_id' => $request->user()->id,
            'action_type' => 'ban_complaint_' . $request->status,
            'target_type' => 'ban_complaint',
            'target_id' => $complaint->id,
            'reason' => $request->admin_notes,
            'metadata' => $complaint->toArray(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Komplain berhasil diperbarui.',
            'data' => $complaint->fresh(['user', 'handler']),
        ]);
    }
}

