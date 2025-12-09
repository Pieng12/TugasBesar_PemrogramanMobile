<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\BanComplaint;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class BanComplaintController extends Controller
{
    /**
     * Store a newly created complaint from banned user.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'reason' => 'required|string|min:20',
            'evidence_url' => 'nullable|url|max:2048',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Akun tidak ditemukan.',
            ], 404);
        }

        $complaint = BanComplaint::create([
            'user_id' => $user->id,
            'email' => $user->email,
            'reason' => $request->reason,
            'evidence_url' => $request->evidence_url,
            'status' => 'pending',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Pengajuan komplain berhasil dikirim. Tim kami akan meninjaunya.',
            'data' => $complaint,
        ], 201);
    }
}




