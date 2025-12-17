<?php

namespace Database\Seeders;

use App\Models\User;
// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Clear existing data (optional - comment out if you want to keep existing data)
        // \App\Models\JobApplication::truncate();
        // \App\Models\JobReview::truncate();
        // \App\Models\Address::truncate();
        // \App\Models\Job::truncate();
        // \App\Models\User::where('role', '!=', 'super_admin')->delete();

        $this->call([
            UserSeeder::class,
            AddressSeeder::class,
            JobSeeder::class,
            PrivateOrderSeeder::class,
            JobApplicationSeeder::class,
            JobReviewSeeder::class,
            SOSSeeder::class,
        ]);
    }
}
