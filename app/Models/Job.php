<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Job extends Model
{
    use HasFactory;

    protected $fillable = [
        'customer_id',
        'title',
        'description',
        'category',
        'price',
        'latitude',
        'longitude',
        'address',
        'scheduled_time',
        'status',
        'assigned_worker_id',
        'image_urls',
        'additional_info',
        'cancelled_by_admin_id',
        'admin_cancel_reason',
        'admin_cancelled_at',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'latitude' => 'decimal:8',
            'longitude' => 'decimal:8',
            'scheduled_time' => 'datetime',
            'image_urls' => 'array',
            'additional_info' => 'array',
            'admin_cancelled_at' => 'datetime',
        ];
    }

    /**
     * Get the customer who created this job
     */
    public function customer()
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    /**
     * Get the assigned worker for this job
     */
    public function assignedWorker()
    {
        return $this->belongsTo(User::class, 'assigned_worker_id');
    }

    public function cancelledByAdmin()
    {
        return $this->belongsTo(User::class, 'cancelled_by_admin_id');
    }

    /**
     * Get the applications for this job
     */
    public function applications()
    {
        return $this->hasMany(JobApplication::class);
    }
}
