<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'nik',
        'email',
        'password',
        'phone',
        'address',
        'date_of_birth',
        'gender',
        'profile_image',
        // Removed user_type - all users can create and take jobs
        'rating',
        'completed_jobs',
        'completed_sos',
        'helped_sos',
        'total_points',
        'total_earnings',
        'is_verified',
        'current_latitude',
        'current_longitude',
        'current_address',
        'role',
        'is_banned',
        'ban_started_at',
        'banned_until',
        'ban_reason',
        'last_banned_by',
        'fcm_token',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * The attributes that should be appended to the model's array form.
     *
     * @var array
     */
    protected $appends = ['total_earnings'];

    /**
     * Get the user's total earnings.
     *
     * @return int
     */
    public function getTotalEarningsAttribute()
    {
        // Sum the price of all completed jobs assigned to this user
        return (int) $this->assignedJobs()->where('status', 'completed')->sum('price');
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'rating' => 'decimal:2',
            'completed_jobs' => 'integer',
            'completed_sos' => 'integer',
            'helped_sos' => 'integer',
            'total_points' => 'integer',
            'total_earnings' => 'integer',
            'is_verified' => 'boolean',
            'current_latitude' => 'decimal:8',
            'current_longitude' => 'decimal:8',
            'is_banned' => 'boolean',
            'ban_started_at' => 'datetime',
            'banned_until' => 'datetime',
        ];
    }

    /**
     * Get the jobs created by this user
     */
    public function jobs()
    {
        return $this->hasMany(Job::class, 'customer_id');
    }

    /**
     * Get the jobs assigned to this user (as worker)
     */
    public function assignedJobs()
    {
        return $this->hasMany(Job::class, 'assigned_worker_id');
    }

    /**
     * Get the addresses for this user
     */
    public function addresses()
    {
        return $this->hasMany(Address::class);
    }

    /**
     * Get the SOS requests created by this user
     */
    public function sosRequests()
    {
        return $this->hasMany(SOSRequest::class, 'requester_id');
    }

    /**
     * Get the SOS helpers for this user
     */
    public function sosHelpers()
    {
        return $this->hasMany(SOSHelper::class, 'helper_id');
    }

    /**
     * Get reviews received by this user
     */
    public function receivedReviews()
    {
        return $this->hasMany(JobReview::class, 'reviewee_id');
    }

    /**
     * Get reviews given by this user
     */
    public function givenReviews()
    {
        return $this->hasMany(JobReview::class, 'reviewer_id');
    }

    /**
     * Calculate and update rating based on received reviews
     */
    public function updateRating()
    {
        $averageRating = $this->receivedReviews()->avg('rating');
        $this->rating = $averageRating ? round($averageRating, 2) : 0.00;
        $this->save();
        return $this->rating;
    }

    /**
     * Determine if the user currently has admin privileges.
     */
    public function isAdmin(): bool
    {
        return in_array($this->role, ['admin', 'super_admin'], true);
    }

    /**
     * Determine if the user is currently banned.
     */
    public function isCurrentlyBanned(): bool
    {
        if (!$this->is_banned) {
            return false;
        }

        // If banned_until is null, it's a permanent ban
        if ($this->banned_until === null) {
            return true;
        }

        // If banned_until has passed, auto-clear the ban
        if (now()->greaterThan($this->banned_until)) {
            $this->clearBan();
            return false;
        }

        return true;
    }

    /**
     * Clear ban related attributes.
     */
    public function clearBan(): void
    {
        $this->is_banned = false;
        $this->ban_started_at = null;
        $this->banned_until = null;
        $this->ban_reason = null;
        $this->last_banned_by = null;
        $this->save();
    }
}
