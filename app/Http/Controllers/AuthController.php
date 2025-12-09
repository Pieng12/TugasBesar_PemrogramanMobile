<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\BanComplaint;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    /**
     * Register a new user
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'nik' => 'nullable|string|max:16|unique:users',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8',
            'phone' => 'nullable|string|max:20',
            'address' => 'nullable|string',
            'date_of_birth' => 'nullable|date',
            'gender' => 'nullable|string|in:male,female',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = User::create([
            'name' => $request->name,
            'nik' => $request->nik,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'phone' => $request->phone,
            'address' => $request->address,
            'date_of_birth' => $request->date_of_birth,
            'gender' => $request->gender,
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'User registered successfully',
            'data' => [
                'user' => $user,
                'token' => $token,
                'token_type' => 'Bearer'
            ]
        ], 201);
    }

    /**
     * Login user
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|email',
            'password' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        if (!Auth::attempt($request->only('email', 'password'))) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials'
            ], 401);
        }

        $user = User::where('email', $request->email)->firstOrFail();
        
        // Refresh user to get latest ban status and auto-clear if expired
        $user->refresh();

        if ($user->isCurrentlyBanned()) {
            $latestComplaint = BanComplaint::where('user_id', $user->id)
                ->latest()
                ->first();
            
            // Check if ban is permanent (banned_until is null)
            $banMessage = $user->banned_until 
                ? 'Akun Anda sedang diblokir hingga ' . $user->banned_until->format('d M Y H:i') . '.'
                : 'Akun Anda diblokir permanen.';

            return response()->json([
                'success' => false,
                'message' => $banMessage,
                'data' => [
                    'ban_reason' => $user->ban_reason,
                    'banned_until' => $user->banned_until,
                    'email' => $user->email,
                    'complaint' => $latestComplaint ? [
                        'status' => $latestComplaint->status,
                        'admin_notes' => $latestComplaint->admin_notes,
                        'handled_at' => $latestComplaint->handled_at,
                        'submitted_at' => $latestComplaint->created_at,
                    ] : null,
                ],
            ], 403);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data' => [
                'user' => $user,
                'token' => $token,
                'token_type' => 'Bearer'
            ]
        ]);
    }

    /**
     * Logout user
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logout successful'
        ]);
    }

    /**
     * Get authenticated user
     */
    public function user(Request $request)
    {
        $user = $request->user();
        
        // Update rating from reviews before returning
        $user->updateRating();
        $user->refresh();
        
        return response()->json([
            'success' => true,
            'data' => $user
        ]);
    }

    /**
     * Change password
     */
    public function changePassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:8',
            'new_password_confirmation' => 'required|string|same:new_password',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();

        // Verify current password
        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Current password is incorrect'
            ], 400);
        }

        // Check if new password is same as current password
        if (Hash::check($request->new_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'New password must be different from current password'
            ], 400);
        }

        // Update password
        $user->update([
            'password' => Hash::make($request->new_password)
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Password changed successfully'
        ]);
    }

    /**
     * Get all active sessions (tokens)
     */
    public function getActiveSessions(Request $request)
    {
        $user = $request->user();
        $currentToken = $request->user()->currentAccessToken();
        
        $tokens = $user->tokens()->orderBy('created_at', 'desc')->get();
        
        $sessions = $tokens->map(function ($token) use ($currentToken) {
            return [
                'id' => $token->id,
                'name' => $token->name ?? 'Perangkat',
                'last_used_at' => $token->last_used_at,
                'created_at' => $token->created_at,
                'is_current' => $token->id === $currentToken->id,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $sessions
        ]);
    }

    /**
     * Logout from all devices
     */
    public function logoutAll(Request $request)
    {
        $user = $request->user();
        
        // Delete all tokens except current one
        $currentToken = $request->user()->currentAccessToken();
        $user->tokens()->where('id', '!=', $currentToken->id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logged out from all other devices successfully'
        ]);
    }

    /**
     * Revoke a specific token
     */
    public function revokeToken(Request $request, $tokenId)
    {
        $user = $request->user();
        $currentToken = $request->user()->currentAccessToken();
        
        // Prevent revoking current token
        if ($currentToken->id == $tokenId) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot revoke current session'
            ], 400);
        }

        $token = $user->tokens()->where('id', $tokenId)->first();
        
        if (!$token) {
            return response()->json([
                'success' => false,
                'message' => 'Token not found'
            ], 404);
        }

        $token->delete();

        return response()->json([
            'success' => true,
            'message' => 'Session revoked successfully'
        ]);
    }
}





