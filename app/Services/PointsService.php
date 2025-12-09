<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PointsService
{
    // Konstanta poin untuk berbagai aksi
    const POINTS_JOB_COMPLETED = 50;           // Poin untuk menyelesaikan pekerjaan
    const POINTS_SOS_COMPLETED = 100;          // Poin untuk menyelesaikan SOS sendiri
    const POINTS_SOS_HELPED = 100;             // Poin untuk membantu menyelesaikan SOS orang lain
    const POINTS_BONUS_PERFECT_RATING = 10;    // Bonus poin untuk rating sempurna (5.0)
    
    /**
     * Tambahkan poin ke user
     * 
     * @param int $userId
     * @param int $points
     * @param string $reason
     * @return bool
     */
    public static function addPoints(int $userId, int $points, string $reason = ''): bool
    {
        try {
            DB::beginTransaction();
            
            $user = User::find($userId);
            if (!$user) {
                DB::rollBack();
                return false;
            }
            
            $oldPoints = $user->total_points ?? 0;
            $newPoints = $oldPoints + $points;
            
            $user->update(['total_points' => $newPoints]);
            
            // Log poin untuk audit trail (opsional, bisa dibuat tabel points_history)
            Log::info("Points added to user {$userId}: +{$points} points (Reason: {$reason}). Total: {$oldPoints} -> {$newPoints}");
            
            DB::commit();
            return true;
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error("Failed to add points to user {$userId}: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Berikan poin untuk menyelesaikan pekerjaan
     * 
     * @param int $workerId
     * @param float|null $rating Bonus jika rating sempurna
     * @return bool
     */
    public static function awardJobCompletion(int $workerId, ?float $rating = null): bool
    {
        $points = self::POINTS_JOB_COMPLETED;
        
        // Bonus poin jika rating sempurna
        if ($rating !== null && $rating >= 5.0) {
            $points += self::POINTS_BONUS_PERFECT_RATING;
        }
        
        return self::addPoints($workerId, $points, 'Job completed');
    }
    
    /**
     * Berikan poin untuk menyelesaikan SOS sendiri
     * 
     * @param int $userId
     * @return bool
     */
    public static function awardSOSCompleted(int $userId): bool
    {
        $user = User::find($userId);
        if ($user) {
            $user->increment('completed_sos');
        }
        
        return self::addPoints($userId, self::POINTS_SOS_COMPLETED, 'SOS completed');
    }
    
    /**
     * Berikan poin untuk membantu menyelesaikan SOS orang lain
     * 
     * @param int $helperId
     * @return bool
     */
    public static function awardSOSHelped(int $helperId): bool
    {
        $user = User::find($helperId);
        if ($user) {
            $user->increment('helped_sos');
        }
        
        return self::addPoints($helperId, self::POINTS_SOS_HELPED, 'Helped SOS');
    }
    
    /**
     * Dapatkan total poin user
     * 
     * @param int $userId
     * @return int
     */
    public static function getUserPoints(int $userId): int
    {
        $user = User::find($userId);
        return $user ? ($user->total_points ?? 0) : 0;
    }
    
    /**
     * Dapatkan ranking user berdasarkan poin
     * 
     * @param int $userId
     * @return int|null
     */
    public static function getUserRank(int $userId): ?int
    {
        $user = User::find($userId);
        if (!$user) {
            return null;
        }
        
        $rank = User::where('total_points', '>', $user->total_points ?? 0)
            ->orWhere(function($query) use ($user) {
                $query->where('total_points', '=', $user->total_points ?? 0)
                      ->where('id', '<', $user->id);
            })
            ->count() + 1;
        
        return $rank;
    }
}



