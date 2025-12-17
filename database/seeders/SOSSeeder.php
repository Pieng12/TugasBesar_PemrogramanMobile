<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\SOSRequest;
use App\Models\SOSHelper;
use App\Models\User;

class SOSSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Get users for SOS creation
        $users = User::all();

        $sosRequests = [
            [
                'requester_id' => $users->random()->id,
                'title' => 'Car Accident - Need Immediate Help',
                'description' => 'I was involved in a minor car accident. No injuries but need help with documentation and insurance claims. Currently at the scene.',
                'latitude' => -6.200000,
                'longitude' => 106.816666,
                'address' => 'Jl. Sudirman No. 123, Jakarta Selatan',
                'status' => 'active',
                'reward_amount' => 15000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'Lost Wallet - Need Help Finding',
                'description' => 'I lost my wallet somewhere in this area. Contains important documents and cards. Reward for anyone who can help find it.',
                'latitude' => -6.201000,
                'longitude' => 106.817000,
                'address' => 'Jl. Thamrin No. 456, Jakarta Pusat',
                'status' => 'active',
                'reward_amount' => 10000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'Medical Emergency - Need Transport',
                'description' => 'My friend is having a medical emergency and needs immediate transport to the nearest hospital. Please help!',
                'latitude' => -6.202000,
                'longitude' => 106.818000,
                'address' => 'Jl. Gatot Subroto No. 789, Jakarta Utara',
                'status' => 'inProgress',
                'helper_id' => $users->random()->id,
                'reward_amount' => 25000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'Flat Tire - Need Assistance',
                'description' => 'My car has a flat tire and I don\'t know how to change it. Need someone with tools and experience to help.',
                'latitude' => -6.203000,
                'longitude' => 106.819000,
                'address' => 'Jl. Kemang Raya No. 321, Jakarta Barat',
                'status' => 'active',
                'reward_amount' => 20000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'Lost Child - Urgent Search',
                'description' => 'My 8-year-old son is missing in this area. Last seen wearing blue shirt and jeans. Please help search!',
                'latitude' => -6.204000,
                'longitude' => 106.820000,
                'address' => 'Jl. Pondok Indah No. 654, Depok',
                'status' => 'active',
                'reward_amount' => 50000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'House Break-in - Need Security',
                'description' => 'Someone broke into my house while I was away. Need someone to help secure the property and contact authorities.',
                'latitude' => -6.205000,
                'longitude' => 106.821000,
                'address' => 'Jl. Bintaro Raya No. 987, Tangerang',
                'status' => 'completed',
                'helper_id' => $users->random()->id,
                'completed_at' => now()->subHours(2),
                'reward_amount' => 30000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'Pet Emergency - Need Vet',
                'description' => 'My dog is injured and needs immediate veterinary care. Need help transporting to the nearest vet clinic.',
                'latitude' => -6.206000,
                'longitude' => 106.822000,
                'address' => 'Jl. Bekasi Raya No. 147, Bekasi',
                'status' => 'active',
                'reward_amount' => 18000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'Fire Emergency - Need Help',
                'description' => 'Small fire in my kitchen. Need help putting it out and ensuring safety. Fire department is on the way.',
                'latitude' => -6.207000,
                'longitude' => 106.823000,
                'address' => 'Jl. Senayan No. 258, Jakarta Selatan',
                'status' => 'inProgress',
                'helper_id' => $users->random()->id,
                'reward_amount' => 40000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'Flooded House - Need Evacuation',
                'description' => 'My house is flooding due to heavy rain. Need help evacuating important belongings and finding temporary shelter.',
                'latitude' => -6.208000,
                'longitude' => 106.824000,
                'address' => 'Jl. Kuningan No. 369, Jakarta Selatan',
                'status' => 'active',
                'reward_amount' => 35000,
            ],
            [
                'requester_id' => $users->random()->id,
                'title' => 'Elderly Fall - Need Medical Help',
                'description' => 'My elderly mother fell and may have broken her hip. Need immediate medical assistance and transport to hospital.',
                'latitude' => -6.209000,
                'longitude' => 106.825000,
                'address' => 'Jl. Sudirman No. 741, Jakarta Pusat',
                'status' => 'active',
                'reward_amount' => 45000,
            ],
        ];

        foreach ($sosRequests as $sosData) {
            SOSRequest::create($sosData);
        }

        // Create SOS helpers for some requests
        $activeSOS = SOSRequest::where('status', 'active')->get();
        foreach ($activeSOS->take(3) as $sos) {
            SOSHelper::create([
                'sos_id' => $sos->id,
                'helper_id' => $users->random()->id,
                'responded_at' => now()->subMinutes(rand(5, 30)),
                'distance' => rand(100, 2000) / 100, // Random distance between 1-20 km
                'status' => 'responding',
            ]);
        }

        $inProgressSOS = SOSRequest::where('status', 'inProgress')->get();
        foreach ($inProgressSOS as $sos) {
            SOSHelper::create([
                'sos_id' => $sos->id,
                'helper_id' => $sos->helper_id,
                'responded_at' => now()->subMinutes(rand(10, 60)),
                'distance' => rand(50, 1500) / 100,
                'status' => 'onTheWay',
            ]);
        }
    }
}





