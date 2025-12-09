<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class NotificationController extends Controller
{
    /**
     * Get user notifications
     */
    public function index(Request $request)
    {
        $user = Auth::user();
        $limit = $request->get('limit', 20);
        $offset = $request->get('offset', 0);

        // Get notifications from database
        $query = Notification::where('user_id', $user->id)
            ->orderBy('created_at', 'desc');

        $total = $query->count();
        $unreadCount = $query->where('is_read', false)->count();

        $notifications = $query->offset($offset)
            ->limit($limit)
            ->get()
            ->map(function ($notification) {
                return [
                    'id' => $notification->id,
                    'type' => $notification->type,
                    'title' => $notification->title,
                    'body' => $notification->body,
                    'is_read' => (bool) $notification->is_read,
                    'related_type' => $notification->related_type,
                    'related_id' => $notification->related_id,
                    'data' => $notification->data,
                    'created_at' => $notification->created_at->toISOString(),
                ];
            })
            ->values(); // Reset array keys to ensure it's a proper array, not object

        // Return format that matches frontend expectations
        // Frontend expects: response['data'] to be either a List or Map with 'data' key
        return response()->json([
            'success' => true,
            'data' => $notifications, // Return notifications directly as array
            'message' => 'Notifications retrieved successfully'
        ]);
    }

    /**
     * Mark notification as read
     */
    public function markAsRead(Request $request)
    {
        $user = Auth::user();
        
        $request->validate([
            'id' => 'required|integer|exists:notifications,id'
        ]);
        
        $success = NotificationService::markAsRead($request->id, $user->id);
        
        if (!$success) {
            return response()->json([
                'success' => false,
                'message' => 'Notification not found or unauthorized'
            ], 404);
        }
        
        return response()->json([
            'success' => true,
            'message' => 'Notification marked as read'
        ]);
    }

    /**
     * Mark all notifications as read
     */
    public function markAllAsRead(Request $request)
    {
        $user = Auth::user();
        
        $count = NotificationService::markAllAsRead($user->id);
        
        return response()->json([
            'success' => true,
            'message' => "All notifications marked as read ({$count} notifications)",
            'count' => $count
        ]);
    }

    /**
     * Delete a notification
     */
    public function destroy(Request $request, $id)
    {
        $user = Auth::user();
        
        $notification = Notification::where('id', $id)
            ->where('user_id', $user->id)
            ->first();
        
        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notification not found'
            ], 404);
        }
        
        $notification->delete();
        
        return response()->json([
            'success' => true,
            'message' => 'Notification deleted successfully'
        ]);
    }

    /**
     * TEST ENDPOINT: Trigger test notification (untuk testing via Postman)
     * Endpoint ini untuk testing notifikasi push FCM
     * 
     * Cara pakai:
     * 1. Login dulu untuk dapat token
     * 2. Panggil endpoint ini dengan token di header
     * 3. Notifikasi akan dikirim ke user yang sedang login
     */
    public function testNotification(Request $request)
    {
        $user = Auth::user();
        
        $request->validate([
            'title' => 'nullable|string|max:255',
            'body' => 'nullable|string',
            'type' => 'nullable|string',
        ]);

        $title = $request->input('title', '🧪 Test Notifikasi');
        $body = $request->input('body', 'Ini adalah notifikasi test dari Postman!');
        $type = $request->input('type', 'system');

        // Cek apakah user punya FCM token
        if (empty($user->fcm_token)) {
            return response()->json([
                'success' => false,
                'message' => 'User tidak memiliki FCM token. Pastikan user sudah login di aplikasi Flutter.',
                'data' => [
                    'user_id' => $user->id,
                    'user_name' => $user->name,
                    'fcm_token_exists' => false,
                ]
            ], 400);
        }

        // NOTE: Prefer HTTP v1 (service account) — do not block test endpoint
        // if legacy `FCM_SERVER_KEY` is not set. The NotificationService will
        // attempt HTTP v1 first and only fallback to legacy key when available.
        $serverKey = config('services.firebase.fcm_server_key');
        $serverKeyExists = !empty($serverKey);

        // Kirim notifikasi dengan push FCM
        NotificationService::createNotificationAndPush(
            $user->id,
            $type,
            $title,
            $body,
            null,
            null,
            ['test' => true, 'timestamp' => now()->toISOString()]
        );

        return response()->json([
            'success' => true,
            'message' => 'Test notification sent! Cek log Laravel untuk detail.',
            'data' => [
                'user_id' => $user->id,
                'user_name' => $user->name,
                'fcm_token_exists' => true,
                'fcm_token_preview' => substr($user->fcm_token, 0, 20) . '...',
                'server_key_exists' => $serverKeyExists,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                    'type' => $type,
                ],
                'note' => 'Cek log Laravel (storage/logs/laravel.log) untuk melihat apakah FCM berhasil dikirim atau ada error.'
            ]
        ]);
    }

    /**
     * TEST ENDPOINT: Simulasi notifikasi pesanan baru (untuk testing)
     * Endpoint ini mensimulasikan ketika ada user lain yang membuat pesanan
     */
    public function testJobNotification(Request $request)
    {
        $user = Auth::user();
        
        $request->validate([
            'job_title' => 'nullable|string|max:255',
        ]);

        $jobTitle = $request->input('job_title', 'Bersihkan Rumah 3 Kamar');

        // Simulasi notifikasi "Ada pekerja yang melamar"
        NotificationService::createNotificationAndPush(
            $user->id,
            'job_application',
            '📝 Ada Pekerja yang Melamar',
            "Ada pekerja mengajukan diri untuk pekerjaan \"{$jobTitle}\"",
            'job',
            999, // fake job ID untuk testing
            ['job_id' => 999, 'job_title' => $jobTitle, 'test' => true]
        );

        return response()->json([
            'success' => true,
            'message' => 'Test job notification sent!',
            'data' => [
                'user_id' => $user->id,
                'user_name' => $user->name,
                'fcm_token_exists' => !empty($user->fcm_token),
                'notification' => [
                    'type' => 'job_application',
                    'title' => '📝 Ada Pekerja yang Melamar',
                    'body' => "Ada pekerja mengajukan diri untuk pekerjaan \"{$jobTitle}\"",
                ]
            ]
        ]);
    }
}





