<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\DB;

class NotificationService
{
    /**
     * Create a notification for a single user
     */
    public static function createNotification(
        int $userId,
        string $type,
        string $title,
        string $body,
        ?string $relatedType = null,
        ?int $relatedId = null,
        ?array $data = null
    ): Notification {
        return Notification::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'is_read' => false,
            'related_type' => $relatedType,
            'related_id' => $relatedId,
            'data' => $data,
        ]);
    }

    /**
     * Create notification and send push via FCM if user has fcm_token
     */
    public static function createNotificationAndPush(
        int $userId,
        string $type,
        string $title,
        string $body,
        ?string $relatedType = null,
        ?int $relatedId = null,
        ?array $data = null
    ): Notification {
        $notification = self::createNotification(
            $userId,
            $type,
            $title,
            $body,
            $relatedType,
            $relatedId,
            $data
        );

        $user = User::find($userId);
        if ($user && $user->fcm_token) {
            $payloadData = $data ?? [];
            $payloadData['type'] = $type;
            if ($relatedType !== null) {
                $payloadData['related_type'] = $relatedType;
            }
            if ($relatedId !== null) {
                $payloadData['related_id'] = $relatedId;
            }

            self::sendFcmNotification(
                $user->fcm_token,
                $title,
                $body,
                $payloadData
            );
        }

        return $notification;
    }

    /**
     * Create notifications for multiple users
     */
    public static function createNotificationsForUsers(
        array $userIds,
        string $type,
        string $title,
        string $body,
        ?string $relatedType = null,
        ?int $relatedId = null,
        ?array $data = null
    ): void {
        $notifications = [];
        $now = now();

        foreach ($userIds as $userId) {
            $notifications[] = [
                'user_id' => $userId,
                'type' => $type,
                'title' => $title,
                'body' => $body,
                'is_read' => false,
                'related_type' => $relatedType,
                'related_id' => $relatedId,
                'data' => json_encode($data),
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        if (!empty($notifications)) {
            Notification::insert($notifications);
        }
    }

    /**
     * Send push notification via Firebase Cloud Messaging
     */
    public static function sendFcmNotification(
        string $fcmToken,
        string $title,
        string $body,
        ?array $data = null
    ): void {
        if (!$fcmToken) {
            \Log::error('FCM token kosong');
            return;
        }

        // Prefer HTTP v1 using service account (kreait/firebase-php)
        try {
            $firebaseService = app(\App\Services\FirebaseService::class);
            $messaging = $firebaseService->getMessaging();

            $payloadData = $data ?? [];
            $payloadData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';

            $message = \Kreait\Firebase\Messaging\CloudMessage::withTarget('token', $fcmToken)
                ->withNotification(\Kreait\Firebase\Messaging\Notification::create($title, $body))
                ->withData($payloadData)
                ->withAndroidConfig(\Kreait\Firebase\Messaging\AndroidConfig::fromArray([
                    'priority' => 'high',
                    'notification' => [
                        'sound' => 'default',
                        'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                    ],
                ]));

            $messaging->send($message);

            \Log::info('FCM notification sent via HTTP v1', [
                'fcm_token' => substr($fcmToken, 0, 20) . '...',
                'title' => $title,
            ]);
            return;

        } catch (\Kreait\Firebase\Exception\MessagingException $e) {
            \Log::error('FCM messaging exception (v1)', [
                'error' => $e->getMessage(),
                'fcm_token' => substr($fcmToken, 0, 20) . '...',
            ]);
            // Fall through to optional legacy fallback below
        } catch (\Throwable $e) {
            \Log::error('FCM push exception (v1)', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
                'fcm_token' => substr($fcmToken, 0, 20) . '...',
            ]);
            // Fall through to optional legacy fallback below
        }

        // Optional fallback: if legacy server key still exists, use it
        $serverKey = config('services.firebase.fcm_server_key');
        if ($serverKey) {
            try {
                $payload = [
                    'to' => $fcmToken,
                    'priority' => 'high',
                    'notification' => [
                        'title' => $title,
                        'body' => $body,
                        'sound' => 'default',
                        'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                    ],
                    'data' => $payloadData,
                ];

                $response = Http::withHeaders([
                    'Authorization' => 'key=' . $serverKey,
                    'Content-Type' => 'application/json',
                ])->post('https://fcm.googleapis.com/fcm/send', $payload);

                if ($response->successful()) {
                    \Log::info('FCM notification sent via legacy key', [
                        'fcm_token' => substr($fcmToken, 0, 20) . '...',
                        'title' => $title,
                    ]);
                } else {
                    \Log::error('FCM push failed (legacy)', [
                        'status' => $response->status(),
                        'response' => $response->body(),
                        'fcm_token' => substr($fcmToken, 0, 20) . '...',
                    ]);
                }
            } catch (\Throwable $e) {
                \Log::error('FCM push exception (legacy)', [
                    'error' => $e->getMessage(),
                    'trace' => $e->getTraceAsString(),
                    'fcm_token' => substr($fcmToken, 0, 20) . '...',
                ]);
            }
        } else {
            \Log::warning('No legacy server key available; message not sent after v1 failure');
        }
    }

    /**
     * Create notification for nearby users (for SOS)
     */
    public static function createSOSNotificationForNearbyUsers(
        float $latitude,
        float $longitude,
        float $radius,
        int $sosId,
        string $sosTitle,
        int $excludeUserId
    ): void {
        // Get nearby users within radius (excluding the SOS requester)
        // Note: User model uses current_latitude and current_longitude
        $nearbyUsers = User::selectRaw("*, (6371 * acos(cos(radians(?)) * cos(radians(current_latitude)) * cos(radians(current_longitude) - radians(?)) + sin(radians(?)) * sin(radians(current_latitude)))) AS distance", [$latitude, $longitude, $latitude])
            ->where('id', '!=', $excludeUserId)
            ->whereNotNull('current_latitude')
            ->whereNotNull('current_longitude')
            ->having('distance', '<=', $radius)
            ->get();

        if ($nearbyUsers->isEmpty()) {
            return;
        }

        $notifications = [];
        $now = now();

        foreach ($nearbyUsers as $user) {
            $distance = round($user->distance, 1);
            $notifications[] = [
                'user_id' => $user->id,
                'type' => 'sos_nearby',
                'title' => '🚨 SOS Darurat di Sekitar',
                'body' => "Ada sinyal darurat \"{$sosTitle}\" sekitar {$distance} km dari lokasi Anda",
                'is_read' => false,
                'related_type' => 'sos',
                'related_id' => $sosId,
                'data' => json_encode([
                    'sos_id' => $sosId,
                    'distance' => $distance,
                ]),
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        if (!empty($notifications)) {
            Notification::insert($notifications);
        }
    }

    /**
     * Mark notification as read
     */
    public static function markAsRead(int $notificationId, int $userId): bool
    {
        $notification = Notification::where('id', $notificationId)
            ->where('user_id', $userId)
            ->first();

        if (!$notification) {
            return false;
        }

        $notification->update([
            'is_read' => true,
            'read_at' => now(),
        ]);

        return true;
    }

    /**
     * Mark all notifications as read for a user
     */
    public static function markAllAsRead(int $userId): int
    {
        return Notification::where('user_id', $userId)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
            ]);
    }
}

