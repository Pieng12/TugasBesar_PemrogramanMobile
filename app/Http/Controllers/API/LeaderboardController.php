<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class LeaderboardController extends Controller
{
    /**
     * Get leaderboard data
     */
    public function index(Request $request)
    {
        $category = $request->get('category', 'all');
        $limit = $request->get('limit', 20);
        $latitude = $request->get('latitude');
        $longitude = $request->get('longitude');
        $radius = $request->get('radius'); // in kilometers

        // All users can be on leaderboard if they have points (completed jobs or SOS)
        $query = User::where(function($q) {
            $q->where('total_points', '>', 0)
              ->orWhere('completed_jobs', '>', 0)
              ->orWhere('completed_sos', '>', 0)
              ->orWhere('helped_sos', '>', 0);
        });

        // Filter by location (for "Area Sekitar" mode)
        // ONLY use addresses table for location (not users.current_latitude/longitude)
        if ($latitude !== null && $longitude !== null && $radius !== null) {
            // Only include users who have at least one address with valid location
            $query->whereHas('addresses', function($addressQ) {
                $addressQ->whereNotNull('latitude')
                         ->whereNotNull('longitude')
                         ->where('latitude', '!=', 0)
                         ->where('longitude', '!=', 0);
            })
            ->selectRaw("users.*, 
                (SELECT 6371 * acos(cos(radians(?)) * cos(radians(addresses.latitude)) * cos(radians(addresses.longitude) - radians(?)) + sin(radians(?)) * sin(radians(addresses.latitude)))
                 FROM addresses 
                 WHERE addresses.user_id = users.id 
                   AND addresses.latitude IS NOT NULL 
                   AND addresses.longitude IS NOT NULL
                   AND addresses.latitude != 0
                   AND addresses.longitude != 0
                 ORDER BY addresses.is_default DESC, 
                          CASE WHEN addresses.last_used_at IS NOT NULL THEN 1 ELSE 0 END DESC,
                          addresses.last_used_at DESC, 
                          addresses.created_at DESC
                 LIMIT 1) AS distance", 
                [$latitude, $longitude, $latitude])
            ->havingRaw('distance IS NOT NULL')
            ->havingRaw('distance <= ?', [$radius]);
        }

        // Filter by category based on completed jobs count in that category
        // Jobs where user is the assigned worker (not the customer)
        if ($category !== 'all') {
            $query->whereHas('assignedJobs', function($q) use ($category) {
                $q->where('category', $category)
                  ->where('status', 'completed');
            });
        }

        // Add category job count for sorting when category filter is applied
        if ($category !== 'all') {
            $query->withCount(['assignedJobs as category_jobs_count' => function($q) use ($category) {
                $q->where('category', $category)
                  ->where('status', 'completed');
            }]);
        }

        // Sorting logic:
        // If location filter is applied (Area Sekitar mode), sort by distance first, then by points/category
        // If no location filter (Global mode), sort by points/category first
        
        if ($latitude !== null && $longitude !== null && $radius !== null) {
            // Area Sekitar mode: sort by distance first, then by category count or total points
            $query->orderBy('distance');
            if ($category !== 'all') {
                $query->orderBy('category_jobs_count', 'desc');
            } else {
                $query->orderBy('total_points', 'desc');
            }
        } else {
            // Global mode: sort by category count or total points first
            if ($category !== 'all') {
                $query->orderBy('category_jobs_count', 'desc');
            } else {
                $query->orderBy('total_points', 'desc');
            }
        }
        
        // Secondary sorting (always applied)
        $query->orderBy('completed_jobs', 'desc')
              ->orderBy('completed_sos', 'desc')
              ->orderBy('helped_sos', 'desc')
              ->orderBy('rating', 'desc');

        $users = $query->limit($limit)->get();

        // Log for debugging
        \Log::info('Leaderboard query result', [
            'total_users' => $users->count(),
            'category' => $category,
            'has_location_filter' => $latitude !== null && $longitude !== null && $radius !== null,
            'user_ids' => $users->pluck('id')->toArray(),
        ]);

        return response()->json([
            'success' => true,
            'data' => $users->map(function ($user) use ($category) {
                $categoryJobsCount = 0;
                if ($category !== 'all') {
                    $categoryJobsCount = \App\Models\Job::where('assigned_worker_id', $user->id)
                        ->where('category', $category)
                        ->where('status', 'completed')
                        ->count();
                }

                return [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'profile_image' => $user->profile_image,
                    'rating' => $user->rating,
                    'completed_jobs' => $user->completed_jobs ?? 0,
                    'completed_sos' => $user->completed_sos ?? 0,
                    'helped_sos' => $user->helped_sos ?? 0,
                    'total_points' => $user->total_points ?? 0,
                    'total_earnings' => $user->total_earnings,
                    'is_verified' => $user->is_verified,
                    'current_address' => $user->current_address,
                    'current_latitude' => $user->current_latitude,
                    'current_longitude' => $user->current_longitude,
                    'category_jobs_count' => $categoryJobsCount,
                    'distance' => $user->distance ?? null,
                ];
            }),
            'message' => 'Leaderboard data retrieved successfully'
        ]);
    }

    /**
     * Get user ranking
     */
    public function getUserRanking(Request $request, $userId)
    {
        $user = User::find($userId);
        
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found'
            ], 404);
        }

        $totalUsers = User::where(function($q) {
            $q->where('total_points', '>', 0)
              ->orWhere('completed_jobs', '>', 0)
              ->orWhere('completed_sos', '>', 0)
              ->orWhere('helped_sos', '>', 0);
        })->count();

        $userPoints = $user->total_points ?? 0;
        $userCompletedJobs = $user->completed_jobs ?? 0;
        $userCompletedSOS = $user->completed_sos ?? 0;
        $userHelpedSOS = $user->helped_sos ?? 0;

        $userRank = User::where(function($q) {
            $q->where('total_points', '>', 0)
              ->orWhere('completed_jobs', '>', 0)
              ->orWhere('completed_sos', '>', 0)
              ->orWhere('helped_sos', '>', 0);
        })
        ->where(function ($query) use ($userPoints, $userCompletedJobs, $userCompletedSOS, $userHelpedSOS, $user) {
            $query->where('total_points', '>', $userPoints)
                  ->orWhere(function ($q) use ($userPoints, $userCompletedJobs, $userCompletedSOS, $userHelpedSOS, $user) {
                      $q->where('total_points', '=', $userPoints)
                        ->where(function($subQ) use ($userCompletedJobs, $userCompletedSOS, $userHelpedSOS, $user) {
                            $subQ->where('completed_jobs', '>', $userCompletedJobs)
                                 ->orWhere(function($q2) use ($userCompletedJobs, $userCompletedSOS, $userHelpedSOS, $user) {
                                     $q2->where('completed_jobs', '=', $userCompletedJobs)
                                        ->where(function($q3) use ($userCompletedSOS, $userHelpedSOS, $user) {
                                            $q3->where('completed_sos', '>', $userCompletedSOS)
                                               ->orWhere(function($q4) use ($userCompletedSOS, $userHelpedSOS, $user) {
                                                   $q4->where('completed_sos', '=', $userCompletedSOS)
                                                      ->where('helped_sos', '>', $userHelpedSOS);
                                               });
                                        });
                                 });
                        })
                        ->where('id', '<', $user->id);
                  });
        })
        ->count() + 1;

        return response()->json([
            'success' => true,
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'rating' => $user->rating,
                    'completed_jobs' => $userCompletedJobs,
                    'completed_sos' => $userCompletedSOS,
                    'helped_sos' => $userHelpedSOS,
                    'total_points' => $userPoints,
                    'total_earnings' => $user->total_earnings,
                ],
                'rank' => $userRank,
                'total_users' => $totalUsers,
                'percentile' => $totalUsers > 0 ? round((($totalUsers - $userRank + 1) / $totalUsers) * 100, 2) : 0
            ],
            'message' => 'User ranking retrieved successfully'
        ]);
    }
}





