<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsNotBanned
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user) {
            return $next($request);
        }

        if ($user->isCurrentlyBanned()) {
            return response()->json([
                'success' => false,
                'message' => 'Akun Anda sedang diblokir hingga ' . optional($user->banned_until)->translatedFormat('d MMMM yyyy HH:mm') . '.',
                'reason' => $user->ban_reason,
            ], 403);
        }

        return $next($request);
    }
}





