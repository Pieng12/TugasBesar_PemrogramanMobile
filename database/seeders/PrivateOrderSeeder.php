<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Job;
use App\Models\User;

class PrivateOrderSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Get all users - all can create and take jobs
        $users = User::all();

        // Create private orders for testing
        $privateOrders = [
            [
                'customer_id' => $users->random()->id,
                'assigned_worker_id' => $users->random()->id,
                'title' => 'Private House Cleaning',
                'description' => 'Private cleaning service for my apartment. Need someone reliable and experienced. This is a private order.',
                'category' => 'cleaning',
                'price' => 200000,
                'latitude' => -6.200000,
                'longitude' => 106.816666,
                'address' => 'Jl. Sudirman No. 123, Jakarta Selatan',
                'scheduled_time' => now()->addDays(1)->setTime(9, 0),
                'status' => 'pending',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => true,
                    'target_worker_name' => $users->random()->name,
                    'rooms' => 2,
                    'bathrooms' => 1,
                    'private_note' => 'This is a private order created through leaderboard'
                ]),
            ],
            [
                'customer_id' => $users->random()->id,
                'assigned_worker_id' => $users->random()->id,
                'title' => 'Private AC Repair',
                'description' => 'Private AC repair service. Need someone with specific expertise in this brand. Direct assignment.',
                'category' => 'maintenance',
                'price' => 300000,
                'latitude' => -6.201000,
                'longitude' => 106.817000,
                'address' => 'Jl. Thamrin No. 456, Jakarta Pusat',
                'scheduled_time' => now()->addDays(2)->setTime(14, 0),
                'status' => 'inProgress',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => true,
                    'target_worker_name' => $users->random()->name,
                    'brand' => 'Daikin',
                    'private_note' => 'Private order - direct assignment'
                ]),
            ],
            [
                'customer_id' => $users->random()->id,
                'assigned_worker_id' => $users->random()->id,
                'title' => 'Private Tutoring Session',
                'description' => 'Private tutoring for my daughter. Need someone with teaching experience. This is a private order.',
                'category' => 'tutoring',
                'price' => 150000,
                'latitude' => -6.202000,
                'longitude' => 106.818000,
                'address' => 'Jl. Gatot Subroto No. 789, Jakarta Utara',
                'scheduled_time' => now()->addDays(3)->setTime(16, 0),
                'status' => 'completed',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => true,
                    'target_worker_name' => $users->random()->name,
                    'subject' => 'Mathematics',
                    'student_age' => 12,
                    'private_note' => 'Private tutoring order'
                ]),
            ],
            [
                'customer_id' => $users->random()->id,
                'assigned_worker_id' => $users->random()->id,
                'title' => 'Private Photography Service',
                'description' => 'Private photography for family event. Need professional photographer. Direct assignment.',
                'category' => 'photography',
                'price' => 800000,
                'latitude' => -6.203000,
                'longitude' => 106.819000,
                'address' => 'Jl. Kemang Raya No. 321, Jakarta Barat',
                'scheduled_time' => now()->addDays(5)->setTime(10, 0),
                'status' => 'pending',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => true,
                    'target_worker_name' => $users->random()->name,
                    'event_type' => 'family_gathering',
                    'private_note' => 'Private photography order'
                ]),
            ],
            [
                'customer_id' => $users->random()->id,
                'assigned_worker_id' => $users->random()->id,
                'title' => 'Private Cooking Service',
                'description' => 'Private cooking service for special dinner. Need someone with specific cuisine expertise.',
                'category' => 'cooking',
                'price' => 400000,
                'latitude' => -6.204000,
                'longitude' => 106.820000,
                'address' => 'Jl. Pondok Indah No. 654, Depok',
                'scheduled_time' => now()->addDays(4)->setTime(18, 0),
                'status' => 'pending',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => true,
                    'target_worker_name' => $users->random()->name,
                    'cuisine' => 'Italian',
                    'guests' => 6,
                    'private_note' => 'Private cooking order'
                ]),
            ],
            [
                'customer_id' => $users->random()->id,
                'assigned_worker_id' => $users->random()->id,
                'title' => 'Private Garden Design',
                'description' => 'Private garden design consultation. Need someone with landscape design experience.',
                'category' => 'gardening',
                'price' => 600000,
                'latitude' => -6.205000,
                'longitude' => 106.821000,
                'address' => 'Jl. Bintaro Raya No. 987, Tangerang',
                'scheduled_time' => now()->addDays(6)->setTime(9, 0),
                'status' => 'pending',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => true,
                    'target_worker_name' => $users->random()->name,
                    'service_type' => 'design_consultation',
                    'garden_size' => 'medium',
                    'private_note' => 'Private garden design order'
                ]),
            ],
            [
                'customer_id' => $users->random()->id,
                'assigned_worker_id' => $users->random()->id,
                'title' => 'Private Pet Care',
                'description' => 'Private pet care service for my cat. Need someone experienced with cats.',
                'category' => 'petCare',
                'price' => 250000,
                'latitude' => -6.206000,
                'longitude' => 106.822000,
                'address' => 'Jl. Bekasi Raya No. 147, Bekasi',
                'scheduled_time' => now()->addDays(2)->setTime(8, 0),
                'status' => 'inProgress',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => true,
                    'target_worker_name' => $users->random()->name,
                    'pet_type' => 'cat',
                    'duration' => '2 days',
                    'private_note' => 'Private pet care order'
                ]),
            ],
            [
                'customer_id' => $users->random()->id,
                'assigned_worker_id' => $users->random()->id,
                'title' => 'Private Computer Setup',
                'description' => 'Private computer setup and configuration. Need someone with IT expertise.',
                'category' => 'maintenance',
                'price' => 350000,
                'latitude' => -6.207000,
                'longitude' => 106.823000,
                'address' => 'Jl. Senayan No. 258, Jakarta Selatan',
                'scheduled_time' => now()->addDays(3)->setTime(13, 0),
                'status' => 'pending',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => true,
                    'target_worker_name' => $users->random()->name,
                    'device_type' => 'desktop',
                    'setup_type' => 'new_installation',
                    'private_note' => 'Private computer setup order'
                ]),
            ],
        ];

        foreach ($privateOrders as $orderData) {
            Job::create($orderData);
        }

        // Create some regular jobs for comparison
        $regularJobs = [
            [
                'customer_id' => $users->random()->id,
                'title' => 'Regular House Cleaning',
                'description' => 'Regular house cleaning service. Open for all workers to apply.',
                'category' => 'cleaning',
                'price' => 180000,
                'latitude' => -6.208000,
                'longitude' => 106.824000,
                'address' => 'Jl. Kuningan No. 369, Jakarta Selatan',
                'scheduled_time' => now()->addDays(2)->setTime(10, 0),
                'status' => 'pending',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => false,
                    'rooms' => 3,
                    'bathrooms' => 2
                ]),
            ],
            [
                'customer_id' => $users->random()->id,
                'title' => 'Regular Food Delivery',
                'description' => 'Regular food delivery service. Open for applications.',
                'category' => 'delivery',
                'price' => 75000,
                'latitude' => -6.209000,
                'longitude' => 106.825000,
                'address' => 'Jl. Sudirman No. 456, Jakarta Pusat',
                'scheduled_time' => now()->addDays(1)->setTime(12, 0),
                'status' => 'pending',
                'image_urls' => json_encode([]),
                'additional_info' => json_encode([
                    'is_private_order' => false,
                    'distance' => '8km',
                    'restaurant' => 'Warung Nasi Gudeg'
                ]),
            ],
        ];

        foreach ($regularJobs as $jobData) {
            Job::create($jobData);
        }
    }
}
