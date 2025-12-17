<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Job;
use App\Models\User;
use Carbon\Carbon;

class JobSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $users = User::where('role', 'user')->get();
        if ($users->isEmpty()) {
            return;
        }

        $categories = ['cleaning', 'maintenance', 'delivery', 'tutoring', 'photography', 'cooking', 'gardening', 'petCare', 'other'];
        $statuses = ['pending', 'inProgress', 'completed', 'cancelled'];
        $statusWeights = [
            'pending' => 30,
            'inProgress' => 20,
            'completed' => 40,
            'cancelled' => 10,
        ];

        // Create 30 public jobs with various statuses
        for ($i = 0; $i < 30; $i++) {
            $customer = $users->random();
            $status = $this->getWeightedStatus($statusWeights);
            $category = $categories[array_rand($categories)];
            
            $jobData = $this->generateJobData($customer, $category, $status, false);
            
            // For completed and inProgress jobs, assign a worker
            if (in_array($status, ['completed', 'inProgress'])) {
                $worker = $users->where('id', '!=', $customer->id)->random();
                $jobData['assigned_worker_id'] = $worker->id;
            }

            Job::create($jobData);
        }

        // Create 10 private orders
        for ($i = 0; $i < 10; $i++) {
            $customer = $users->random();
            $worker = $users->where('id', '!=', $customer->id)->random();
            $category = $categories[array_rand($categories)];
            $status = $this->getWeightedStatus(['pending' => 20, 'inProgress' => 30, 'completed' => 50]);
            
            $jobData = $this->generateJobData($customer, $category, $status, true);
            $jobData['assigned_worker_id'] = $worker->id;

            Job::create($jobData);
        }
    }

    private function generateJobData(User $customer, string $category, string $status, bool $isPrivate): array
    {
        $titles = [
            'cleaning' => ['House Cleaning Service', 'Office Cleaning', 'Deep Cleaning Service', 'Regular Cleaning'],
            'maintenance' => ['AC Maintenance', 'Computer Repair', 'Plumbing Service', 'Electrical Repair'],
            'delivery' => ['Food Delivery', 'Package Delivery', 'Grocery Delivery', 'Document Delivery'],
            'tutoring' => ['Math Tutoring', 'English Tutoring', 'Science Tutoring', 'Music Lessons'],
            'photography' => ['Event Photography', 'Portrait Photography', 'Product Photography', 'Wedding Photography'],
            'cooking' => ['Cooking Service', 'Catering Service', 'Meal Preparation', 'Private Chef'],
            'gardening' => ['Garden Maintenance', 'Landscape Design', 'Plant Care', 'Lawn Mowing'],
            'petCare' => ['Pet Care Service', 'Dog Walking', 'Pet Grooming', 'Pet Sitting'],
            'other' => ['Moving Assistance', 'Errand Service', 'Personal Assistant', 'Event Helper'],
        ];

        $descriptions = [
            'cleaning' => 'Need someone to clean thoroughly. Must be experienced and bring own cleaning supplies.',
            'maintenance' => 'Need someone to check and repair. Professional service required.',
            'delivery' => 'Need someone to deliver items. Must have vehicle and be punctual.',
            'tutoring' => 'Need a tutor with teaching experience. Patient and professional preferred.',
            'photography' => 'Need a photographer with professional equipment and portfolio.',
            'cooking' => 'Need someone to cook. Must be hygienic and experienced.',
            'gardening' => 'Need someone to maintain garden. Tasks include watering, pruning, and fertilizing.',
            'petCare' => 'Need someone to take care of pets. Must be experienced with animals.',
            'other' => 'Need assistance with various tasks. Flexible schedule preferred.',
        ];

        $prices = [
            'cleaning' => [120000, 150000, 180000, 200000],
            'maintenance' => [150000, 200000, 250000, 300000],
            'delivery' => [30000, 50000, 75000, 100000],
            'tutoring' => [80000, 100000, 150000, 200000],
            'photography' => [1000000, 2000000, 3000000, 5000000],
            'cooking' => [200000, 300000, 400000, 500000],
            'gardening' => [100000, 120000, 150000, 200000],
            'petCare' => [150000, 250000, 350000, 450000],
            'other' => [100000, 200000, 300000, 500000],
        ];

        $title = $titles[$category][array_rand($titles[$category])];
        $price = $prices[$category][array_rand($prices[$category])];
        
        // Adjust price for private orders (usually higher)
        if ($isPrivate) {
            $price = (int)($price * 1.2);
        }

        $lat = -6.200000 + (rand(-500, 500) / 10000);
        $lng = 106.816666 + (rand(-500, 500) / 10000);

        $additionalInfo = [
            'is_private_order' => $isPrivate,
        ];

        if ($isPrivate) {
            $additionalInfo['private_note'] = 'This is a private order created through direct assignment.';
        }

        // Set scheduled time based on status
        $scheduledTime = null;
        if ($status === 'pending') {
            $scheduledTime = Carbon::now()->addDays(rand(1, 7))->setTime(rand(8, 18), rand(0, 59));
        } elseif ($status === 'inProgress') {
            $scheduledTime = Carbon::now()->subDays(rand(0, 3))->setTime(rand(8, 18), rand(0, 59));
        } elseif ($status === 'completed') {
            $scheduledTime = Carbon::now()->subDays(rand(7, 30))->setTime(rand(8, 18), rand(0, 59));
        }

        return [
            'customer_id' => $customer->id,
            'title' => $title,
            'description' => $descriptions[$category],
            'category' => $category,
            'price' => $price,
            'latitude' => $lat,
            'longitude' => $lng,
            'address' => $this->getRandomAddress(),
            'scheduled_time' => $scheduledTime,
            'status' => $status,
            'image_urls' => json_encode([]),
            'additional_info' => json_encode($additionalInfo),
            'created_at' => $status === 'completed' 
                ? Carbon::now()->subDays(rand(7, 60))
                : Carbon::now()->subDays(rand(0, 30)),
            'updated_at' => $status === 'completed'
                ? Carbon::now()->subDays(rand(0, 7))
                : Carbon::now(),
        ];
    }

    private function getWeightedStatus(array $weights): string
    {
        $total = array_sum($weights);
        $random = rand(1, $total);
        $current = 0;

        foreach ($weights as $status => $weight) {
            $current += $weight;
            if ($random <= $current) {
                return $status;
            }
        }

        return 'pending';
    }

    private function getRandomAddress(): string
    {
        $streets = ['Sudirman', 'Thamrin', 'Gatot Subroto', 'Kemang Raya', 'Pondok Indah', 'Bintaro Raya', 'Bekasi Raya', 'Senayan', 'Kuningan'];
        $areas = ['Jakarta Selatan', 'Jakarta Pusat', 'Jakarta Utara', 'Jakarta Barat', 'Jakarta Timur', 'Depok', 'Tangerang', 'Bekasi'];
        
        $street = $streets[array_rand($streets)];
        $area = $areas[array_rand($areas)];
        $number = rand(100, 999);

        return "Jl. $street No. $number, $area";
    }
}
