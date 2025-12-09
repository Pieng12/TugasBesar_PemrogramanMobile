<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SOSHelper extends Model
{
    use HasFactory;

    protected $table = 's_o_s_helpers';

    protected $fillable = [
        'sos_id',
        'helper_id',
        'responded_at',
        'distance',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'responded_at' => 'datetime',
            'distance' => 'decimal:2',
        ];
    }

    /**
     * Get the SOS request this helper responded to
     */
    public function sosRequest()
    {
        return $this->belongsTo(SOSRequest::class, 'sos_id');
    }

    /**
     * Get the helper user
     */
    public function helper()
    {
        return $this->belongsTo(User::class, 'helper_id');
    }
}
