<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class BadgeController extends Controller
{
    /**
     * Get user badges
     */
    public function index(Request $request)
    {
        $user = Auth::user();
        
        // Generate badges based on user stats
        $badges = $this->generateUserBadges($user);

        return response()->json([
            'success' => true,
            'data' => $badges,
            'message' => 'User badges retrieved successfully'
        ]);
    }

    /**
     * Get all available badges
     */
    public function getAllBadges()
    {
        $allBadges = [
            [
                'id' => 'first_job',
                'name' => 'First Steps',
                'description' => 'Complete your first job',
                'icon' => '🎯',
                'type' => 'milestone',
                'requirement' => 'Complete 1 job',
                'reward' => 'Profile badge'
            ],
            [
                'id' => 'job_master',
                'name' => 'Job Master',
                'description' => 'Complete 10 jobs',
                'icon' => '⭐',
                'type' => 'milestone',
                'requirement' => 'Complete 10 jobs',
                'reward' => 'Profile badge + 1000 points'
            ],
            [
                'id' => 'super_worker',
                'name' => 'Super Worker',
                'description' => 'Complete 50 jobs',
                'icon' => '🏆',
                'type' => 'milestone',
                'requirement' => 'Complete 50 jobs',
                'reward' => 'Profile badge + 5000 points'
            ],
            [
                'id' => 'high_rating',
                'name' => 'Quality Expert',
                'description' => 'Maintain 4.5+ rating',
                'icon' => '💎',
                'type' => 'quality',
                'requirement' => 'Maintain 4.5+ rating for 10 jobs',
                'reward' => 'Profile badge + Priority listing'
            ],
            [
                'id' => 'sos_hero',
                'name' => 'SOS Hero',
                'description' => 'Respond to 5 SOS requests',
                'icon' => '🦸',
                'type' => 'emergency',
                'requirement' => 'Respond to 5 SOS requests',
                'reward' => 'Profile badge + Emergency responder status'
            ],
            [
                'id' => 'early_bird',
                'name' => 'Early Bird',
                'description' => 'Complete jobs before scheduled time',
                'icon' => '🐦',
                'type' => 'punctuality',
                'requirement' => 'Complete 5 jobs early',
                'reward' => 'Profile badge + Early completion bonus'
            ],
            [
                'id' => 'customer_favorite',
                'name' => 'Customer Favorite',
                'description' => 'Get 5-star rating from 10 customers',
                'icon' => '❤️',
                'type' => 'customer_service',
                'requirement' => 'Get 5-star rating from 10 customers',
                'reward' => 'Profile badge + Featured listing'
            ],
            [
                'id' => 'money_maker',
                'name' => 'Money Maker',
                'description' => 'Earn Rp 10,000,000',
                'icon' => '💰',
                'type' => 'earnings',
                'requirement' => 'Earn Rp 10,000,000',
                'reward' => 'Profile badge + VIP status'
            ],
            [
                'id' => 'reliable',
                'name' => 'Reliable Worker',
                'description' => 'Never cancel a job',
                'icon' => '✅',
                'type' => 'reliability',
                'requirement' => 'Complete 20 jobs without cancellation',
                'reward' => 'Profile badge + Trusted worker status'
            ],
            [
                'id' => 'versatile',
                'name' => 'Versatile Worker',
                'description' => 'Work in 5 different categories',
                'icon' => '🎭',
                'type' => 'versatility',
                'requirement' => 'Work in 5 different job categories',
                'reward' => 'Profile badge + Multi-category expert'
            ]
        ];

        return response()->json([
            'success' => true,
            'data' => $allBadges,
            'message' => 'All badges retrieved successfully'
        ]);
    }

    /**
     * Generate user badges based on their stats
     */
    private function generateUserBadges($user)
    {
        $earnedBadges = [];
        $availableBadges = [];

        // Check for earned badges
        if ($user->completed_jobs >= 1) {
            $earnedBadges[] = [
                'id' => 'first_job',
                'name' => 'First Steps',
                'description' => 'Complete your first job',
                'icon' => '🎯',
                'type' => 'milestone',
                'earned_date' => now()->subDays(30)->toISOString(),
                'progress' => 100
            ];
        }

        if ($user->completed_jobs >= 10) {
            $earnedBadges[] = [
                'id' => 'job_master',
                'name' => 'Job Master',
                'description' => 'Complete 10 jobs',
                'icon' => '⭐',
                'type' => 'milestone',
                'earned_date' => now()->subDays(15)->toISOString(),
                'progress' => 100
            ];
        }

        if ($user->completed_jobs >= 50) {
            $earnedBadges[] = [
                'id' => 'super_worker',
                'name' => 'Super Worker',
                'description' => 'Complete 50 jobs',
                'icon' => '🏆',
                'type' => 'milestone',
                'earned_date' => now()->subDays(5)->toISOString(),
                'progress' => 100
            ];
        }

        if ($user->rating >= 4.5) {
            $earnedBadges[] = [
                'id' => 'high_rating',
                'name' => 'Quality Expert',
                'description' => 'Maintain 4.5+ rating',
                'icon' => '💎',
                'type' => 'quality',
                'earned_date' => now()->subDays(10)->toISOString(),
                'progress' => 100
            ];
        }

        if ($user->total_earnings >= 10000000) {
            $earnedBadges[] = [
                'id' => 'money_maker',
                'name' => 'Money Maker',
                'description' => 'Earn Rp 10,000,000',
                'icon' => '💰',
                'type' => 'earnings',
                'earned_date' => now()->subDays(3)->toISOString(),
                'progress' => 100
            ];
        }

        // Check for available badges (not yet earned)
        if ($user->completed_jobs < 10 && $user->completed_jobs >= 1) {
            $availableBadges[] = [
                'id' => 'job_master',
                'name' => 'Job Master',
                'description' => 'Complete 10 jobs',
                'icon' => '⭐',
                'type' => 'milestone',
                'progress' => ($user->completed_jobs / 10) * 100,
                'requirement' => 'Complete 10 jobs'
            ];
        }

        if ($user->completed_jobs < 50 && $user->completed_jobs >= 10) {
            $availableBadges[] = [
                'id' => 'super_worker',
                'name' => 'Super Worker',
                'description' => 'Complete 50 jobs',
                'icon' => '🏆',
                'type' => 'milestone',
                'progress' => ($user->completed_jobs / 50) * 100,
                'requirement' => 'Complete 50 jobs'
            ];
        }

        if ($user->rating < 4.5 && $user->rating >= 4.0) {
            $availableBadges[] = [
                'id' => 'high_rating',
                'name' => 'Quality Expert',
                'description' => 'Maintain 4.5+ rating',
                'icon' => '💎',
                'type' => 'quality',
                'progress' => ($user->rating / 4.5) * 100,
                'requirement' => 'Maintain 4.5+ rating'
            ];
        }

        if ($user->total_earnings < 10000000 && $user->total_earnings >= 1000000) {
            $availableBadges[] = [
                'id' => 'money_maker',
                'name' => 'Money Maker',
                'description' => 'Earn Rp 10,000,000',
                'icon' => '💰',
                'type' => 'earnings',
                'progress' => ($user->total_earnings / 10000000) * 100,
                'requirement' => 'Earn Rp 10,000,000'
            ];
        }

        return [
            'earned_badges' => $earnedBadges,
            'available_badges' => $availableBadges,
            'total_earned' => count($earnedBadges),
            'total_available' => count($availableBadges)
        ];
    }
}





