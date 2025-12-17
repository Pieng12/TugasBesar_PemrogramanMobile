<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Address;
use Carbon\Carbon;

class AddressSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $users = User::where('role', 'user')->get();

        foreach ($users as $user) {
            // Each user gets 1-3 addresses
            $numAddresses = rand(1, 3);
            $isFirst = true;

            for ($i = 0; $i < $numAddresses; $i++) {
                $label = $this->getRandomLabel($i);
                $addressData = $this->getRandomAddress($user);

                Address::create([
                    'user_id' => $user->id,
                    'label' => $label,
                    'address' => $addressData['address'],
                    'recipient' => $user->name,
                    'phone' => $user->phone,
                    'notes' => $this->getRandomNotes(),
                    'latitude' => $addressData['latitude'],
                    'longitude' => $addressData['longitude'],
                    'is_default' => $isFirst,
                    'last_used_at' => $isFirst ? Carbon::now() : null,
                    'created_at' => Carbon::now()->subDays(rand(0, 90)),
                    'updated_at' => Carbon::now()->subDays(rand(0, 90)),
                ]);

                $isFirst = false;
            }
        }
    }

    private function getRandomLabel(int $index): string
    {
        $labels = ['Rumah', 'Kantor', 'Kos', 'Apartemen', 'Rumah Orang Tua'];
        return $labels[$index] ?? 'Alamat ' . ($index + 1);
    }

    private function getRandomAddress(User $user): array
    {
        $addresses = [
            [
                'address' => 'Jl. Sudirman No. ' . rand(100, 999) . ', Jakarta Selatan',
                'latitude' => -6.200000 + (rand(-100, 100) / 10000),
                'longitude' => 106.816666 + (rand(-100, 100) / 10000),
            ],
            [
                'address' => 'Jl. Thamrin No. ' . rand(100, 999) . ', Jakarta Pusat',
                'latitude' => -6.201000 + (rand(-100, 100) / 10000),
                'longitude' => 106.817000 + (rand(-100, 100) / 10000),
            ],
            [
                'address' => 'Jl. Gatot Subroto No. ' . rand(100, 999) . ', Jakarta Utara',
                'latitude' => -6.202000 + (rand(-100, 100) / 10000),
                'longitude' => 106.818000 + (rand(-100, 100) / 10000),
            ],
            [
                'address' => 'Jl. Kemang Raya No. ' . rand(100, 999) . ', Jakarta Barat',
                'latitude' => -6.203000 + (rand(-100, 100) / 10000),
                'longitude' => 106.819000 + (rand(-100, 100) / 10000),
            ],
            [
                'address' => 'Jl. Pondok Indah No. ' . rand(100, 999) . ', Depok',
                'latitude' => -6.205000 + (rand(-100, 100) / 10000),
                'longitude' => 106.821000 + (rand(-100, 100) / 10000),
            ],
        ];

        return $addresses[array_rand($addresses)];
    }

    private function getRandomNotes(): ?string
    {
        $notes = [
            null,
            'Rumah warna putih, pagar hitam',
            'Lantai 2, unit 205',
            'Dekat dengan masjid',
            'Ada parkir mobil',
            'Tolong di depan gerbang',
        ];

        return $notes[array_rand($notes)];
    }
}


