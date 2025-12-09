<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SOSRequest extends Model
{
    use HasFactory;

    protected $table = 's_o_s_requests';

    protected $fillable = [
        'requester_id',
        'title',
        'description',
        'latitude',
        'longitude',
        'address',
        'status',
        'helper_id',
        'completed_at',
        'reward_amount',
    ];

    protected function casts(): array
    {
        return [
            'latitude' => 'decimal:8',
            'longitude' => 'decimal:8',
            'completed_at' => 'datetime',
            'reward_amount' => 'integer',
        ];
    }

    /**
     * Get the requester who created this SOS request
     */
    public function requester()
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    /**
     * Get the helper assigned to this SOS request
     */
    public function helper()
    {
        return $this->belongsTo(User::class, 'helper_id');
    }

    /**
     * Get all helpers who responded to this SOS request
     */
    public function sosHelpers()
    {
        return $this->hasMany(SOSHelper::class, 'sos_id');
    }
}
