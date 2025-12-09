<?php

namespace App\Services;

use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging;

class FirebaseService
{
    protected Messaging $messaging;

    public function __construct()
    {
        $credentialsPath = storage_path('app/firebase/firebase-key.json');

        if (!file_exists($credentialsPath)) {

            $firebaseJson = env('FIREBASE_JSON');

            if (!$firebaseJson) {
                throw new \Exception("Firebase JSON not set in environment variables.");
            }

            // Buat folder jika belum ada
            $dir = storage_path('app/firebase');
            if (!is_dir($dir)) {
                mkdir($dir, 0755, true);
            }

            // Convert escaped JSON → array
            $decoded = json_decode($firebaseJson, true);

            if (!$decoded) {
                throw new \Exception("Invalid FIREBASE_JSON format.");
            }

            // Simpan sebagai file JSON yang rapi (fungsi penting untuk private_key)
            file_put_contents(
                $credentialsPath,
                json_encode($decoded, JSON_PRETTY_PRINT)
            );
        }

        // Load Firebase
        $factory = (new Factory)
            ->withServiceAccount($credentialsPath);

        $this->messaging = $factory->createMessaging();
    }

    public function getMessaging(): Messaging
    {
        return $this->messaging;
    }
}
