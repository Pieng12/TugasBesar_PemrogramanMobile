<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Job;
use App\Models\User;
use App\Models\JobApplication;
use Carbon\Carbon;

class JobApplicationSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $users = User::where('role', 'user')->get();
        $jobs = Job::where('status', 'pending')
            ->whereNull('assigned_worker_id')
            ->whereDoesntHave('applications')
            ->get();

        if ($jobs->isEmpty() || $users->isEmpty()) {
            return;
        }

        // Create applications for public jobs (not private orders)
        foreach ($jobs as $job) {
            $additionalInfo = $job->additional_info ?? [];
            $isPrivate = $additionalInfo['is_private_order'] ?? false;

            // Skip private orders - they are directly assigned
            if ($isPrivate) {
                continue;
            }

            // Random number of applicants (1-5)
            $numApplicants = rand(1, 5);
            $applicantIds = $users->random(min($numApplicants, $users->count()))->pluck('id');

            foreach ($applicantIds as $workerId) {
                // Don't allow customer to apply to their own job
                if ($workerId == $job->customer_id) {
                    continue;
                }

                $statuses = ['pending', 'accepted', 'rejected'];
                $status = $statuses[array_rand($statuses)];

                // Only one accepted application per job
                $hasAccepted = JobApplication::where('job_id', $job->id)
                    ->where('status', 'accepted')
                    ->exists();

                if ($hasAccepted && $status === 'accepted') {
                    $status = 'pending';
                }

                JobApplication::create([
                    'job_id' => $job->id,
                    'worker_id' => $workerId,
                    'status' => $status,
                    'applied_at' => Carbon::now()->subDays(rand(0, 7)),
                    'message' => $this->getRandomMessage(),
                ]);

                // If accepted, assign the worker to the job
                if ($status === 'accepted') {
                    $job->update([
                        'assigned_worker_id' => $workerId,
                        'status' => 'inProgress',
                    ]);
                }
            }
        }
    }

    private function getRandomMessage(): string
    {
        $messages = [
            'Saya memiliki pengalaman yang relevan untuk pekerjaan ini.',
            'Saya sangat tertarik dengan pekerjaan ini dan siap untuk mulai bekerja.',
            'Saya memiliki keahlian yang sesuai dengan kebutuhan pekerjaan ini.',
            'Saya dapat menyelesaikan pekerjaan ini dengan baik dan tepat waktu.',
            'Saya memiliki pengalaman serupa sebelumnya.',
            'Saya siap untuk bekerja dan memberikan hasil terbaik.',
            'Saya memiliki semua peralatan yang diperlukan untuk pekerjaan ini.',
            'Saya dapat mulai bekerja segera setelah diterima.',
        ];

        return $messages[array_rand($messages)];
    }
}


