<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserBan extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'admin_id',
        'banned_from',
        'banned_until',
        'reason',
        'lifted_at',
        'metadata',
    ];

    protected $casts = [
        'banned_from' => 'datetime',
        'banned_until' => 'datetime',
        'lifted_at' => 'datetime',
        'metadata' => 'array',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function admin()
    {
        return $this->belongsTo(User::class, 'admin_id');
    }
}





