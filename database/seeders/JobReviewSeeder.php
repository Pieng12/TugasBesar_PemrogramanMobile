<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Job;
use App\Models\JobReview;
use App\Models\User;
use Carbon\Carbon;

class JobReviewSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Get completed jobs
        $completedJobs = Job::where('status', 'completed')
            ->whereNotNull('assigned_worker_id')
            ->get();

        foreach ($completedJobs as $job) {
            $customer = $job->customer;
            $worker = $job->assignedWorker;

            if (!$customer || !$worker) {
                continue;
            }

            // Customer reviews worker (80% chance)
            if (rand(1, 100) <= 80) {
                $rating = $this->getRandomRating();
                JobReview::create([
                    'job_id' => $job->id,
                    'reviewer_id' => $customer->id,
                    'reviewee_id' => $worker->id,
                    'rating' => $rating,
                    'comment' => $this->getRandomComment($rating, 'customer'),
                    'created_at' => Carbon::now()->subDays(rand(0, 30)),
                    'updated_at' => Carbon::now()->subDays(rand(0, 30)),
                ]);

                // Update worker rating
                $worker->updateRating();
            }

            // Worker reviews customer (70% chance)
            if (rand(1, 100) <= 70) {
                $rating = $this->getRandomRating();
                JobReview::create([
                    'job_id' => $job->id,
                    'reviewer_id' => $worker->id,
                    'reviewee_id' => $customer->id,
                    'rating' => $rating,
                    'comment' => $this->getRandomComment($rating, 'worker'),
                    'created_at' => Carbon::now()->subDays(rand(0, 30)),
                    'updated_at' => Carbon::now()->subDays(rand(0, 30)),
                ]);

                // Update customer rating
                $customer->updateRating();
            }
        }
    }

    private function getRandomRating(): int
    {
        // Weighted random: higher chance for good ratings
        $weights = [
            5 => 40,  // 40% chance for 5 stars
            4 => 35,  // 35% chance for 4 stars
            3 => 15,  // 15% chance for 3 stars
            2 => 7,   // 7% chance for 2 stars
            1 => 3,   // 3% chance for 1 star
        ];

        $total = array_sum($weights);
        $random = rand(1, $total);
        $current = 0;

        foreach ($weights as $rating => $weight) {
            $current += $weight;
            if ($random <= $current) {
                return $rating;
            }
        }

        return 5;
    }

    private function getRandomComment(int $rating, string $type): string
    {
        $comments = [
            5 => [
                'customer' => [
                    'Pekerja sangat profesional dan menyelesaikan pekerjaan dengan sempurna!',
                    'Sangat puas dengan hasil pekerjaannya. Sangat direkomendasikan!',
                    'Pekerja yang sangat baik, tepat waktu dan hasilnya memuaskan.',
                    'Pelayanan sangat baik dan pekerjaan selesai sesuai harapan.',
                ],
                'worker' => [
                    'Customer yang sangat baik dan komunikatif. Sangat menyenangkan bekerja dengan mereka.',
                    'Pembayaran tepat waktu dan komunikasi yang jelas. Terima kasih!',
                    'Customer yang ramah dan mudah diajak bekerja sama.',
                ],
            ],
            4 => [
                'customer' => [
                    'Pekerja yang baik, hasil pekerjaan cukup memuaskan.',
                    'Pekerjaan selesai dengan baik, ada sedikit hal yang bisa diperbaiki.',
                    'Secara keseluruhan puas dengan pelayanan.',
                ],
                'worker' => [
                    'Customer yang baik, komunikasi lancar.',
                    'Pembayaran tepat waktu dan pekerjaan berjalan lancar.',
                ],
            ],
            3 => [
                'customer' => [
                    'Pekerjaan selesai tapi ada beberapa hal yang kurang.',
                    'Cukup baik, tapi masih ada ruang untuk perbaikan.',
                ],
                'worker' => [
                    'Customer cukup baik, ada beberapa kendala komunikasi.',
                ],
            ],
            2 => [
                'customer' => [
                    'Pekerjaan kurang memuaskan, ada beberapa masalah.',
                    'Hasil pekerjaan tidak sesuai ekspektasi.',
                ],
                'worker' => [
                    'Ada beberapa kendala dalam komunikasi.',
                ],
            ],
            1 => [
                'customer' => [
                    'Sangat tidak puas dengan pelayanan.',
                    'Pekerjaan tidak sesuai harapan.',
                ],
                'worker' => [
                    'Ada masalah dalam komunikasi dan koordinasi.',
                ],
            ],
        ];

        $ratingComments = $comments[$rating][$type] ?? ['Tidak ada komentar.'];
        return $ratingComments[array_rand($ratingComments)];
    }
}


