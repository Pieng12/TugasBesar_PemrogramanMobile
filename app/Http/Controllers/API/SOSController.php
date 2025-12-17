<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\SOSRequest;
use App\Models\SOSHelper;
use App\Services\NotificationService;
use App\Services\PointsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SOSController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        $query = SOSRequest::with(['requester', 'helper', 'sosHelpers.helper']);

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by location (within radius)
        if ($request->has('latitude') && $request->has('longitude') && $request->has('radius')) {
            $latitude = $request->latitude;
            $longitude = $request->longitude;
            $radius = $request->radius; // in kilometers

            $query->selectRaw("*, (6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) AS distance", [$latitude, $longitude, $latitude])
                  ->having('distance', '<=', $radius)
                  ->orderBy('distance');
        }

        $sosRequests = $query->orderBy('created_at', 'desc')->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $sosRequests
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'description' => 'required|string',
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
            'address' => 'required|string',
            'reward_amount' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        $sosRequest = SOSRequest::create([
            'requester_id' => $request->user()->id,
            'title' => $request->title,
            'description' => $request->description,
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
            'address' => $request->address,
            'reward_amount' => $request->reward_amount ?? 10000,
        ]);

        // Create notifications for nearby users (within 10km radius)
        NotificationService::createSOSNotificationForNearbyUsers(
            $request->latitude,
            $request->longitude,
            10.0, // 10 km radius
            $sosRequest->id,
            $sosRequest->title,
            $request->user()->id // Exclude the requester
        );

        return response()->json([
            'success' => true,
            'message' => 'SOS request created successfully',
            'data' => $sosRequest->load(['requester'])
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        $sosRequest = SOSRequest::with(['requester', 'helper', 'sosHelpers.helper'])->find($id);
        
        if (!$sosRequest) {
            return response()->json([
                'success' => false,
                'message' => 'SOS request not found'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $sosRequest
        ]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        $sosRequest = SOSRequest::find($id);
        
        if (!$sosRequest) {
            return response()->json([
                'success' => false,
                'message' => 'SOS request not found'
            ], 404);
        }

        $currentUserId = $request->user()->id;
        
        // Check authorization: 
        // - Requester can update their own SOS (status, cancel, complete)
        // - Helper tidak bisa update SOS, hanya bisa respond melalui endpoint respond
        $isRequester = $sosRequest->requester_id === $currentUserId;
        
        // Only requester can update SOS
        if (!$isRequester) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to update this SOS request. Only the requester can update it.'
            ], 403);
        }
        
        // Prevent changing status to inProgress (SOS tetap active agar banyak orang bisa ambil)
        if ($request->has('status') && $request->status === 'inProgress') {
            return response()->json([
                'success' => false,
                'message' => 'Status inProgress tidak digunakan. SOS tetap active agar banyak orang bisa membantu.'
            ], 400);
        }

        $validator = Validator::make($request->all(), [
            'title' => 'sometimes|string|max:255',
            'description' => 'sometimes|string',
            'latitude' => 'sometimes|numeric',
            'longitude' => 'sometimes|numeric',
            'address' => 'sometimes|string',
            'status' => 'sometimes|in:active,completed,cancelled', // inProgress dihapus
            'helper_id' => 'nullable|exists:users,id',
            'reward_amount' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        $oldStatus = $sosRequest->status;
        $sosRequest->update($request->only([
            'title', 'description', 'latitude', 'longitude', 
            'address', 'status', 'helper_id', 'reward_amount'
        ]));
        
        // Award points when SOS is marked as completed
        if ($oldStatus !== 'completed' && $sosRequest->status === 'completed') {
            // Award points to helper if someone helped (helper_id di-set saat confirm helper)
            if ($sosRequest->helper_id && $sosRequest->helper_id !== $sosRequest->requester_id) {
                PointsService::awardSOSHelped($sosRequest->helper_id);
                
                // Notify helper about points
                NotificationService::createNotification(
                    $sosRequest->helper_id,
                    'sos_helped',
                    '🎉 Poin Diterima!',
                    "Anda mendapat poin karena membantu menyelesaikan SOS \"{$sosRequest->title}\"",
                    'sos',
                    $sosRequest->id,
                    ['sos_id' => $sosRequest->id, 'sos_title' => $sosRequest->title]
                );
            }
            // If there is no helper_id set, check if there are helpers in sos_helpers
            else {
                $helpers = $sosRequest->sosHelpers;
                if ($helpers->isNotEmpty()) {
                    // Award points to the first helper (or could be modified to award all)
                    $firstHelper = $helpers->first();
                    PointsService::awardSOSHelped($firstHelper->helper_id);
                    
                    NotificationService::createNotification(
                        $firstHelper->helper_id,
                        'sos_helped',
                        '🎉 Poin Diterima!',
                        "Anda mendapat poin karena membantu menyelesaikan SOS \"{$sosRequest->title}\"",
                        'sos',
                        $sosRequest->id,
                        ['sos_id' => $sosRequest->id, 'sos_title' => $sosRequest->title]
                    );
                } else {
                    // If there is no helper, award points to the requester for completing their own SOS
                    PointsService::awardSOSCompleted($sosRequest->requester_id);
                }
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'SOS request updated successfully',
            'data' => $sosRequest->load(['requester', 'helper'])
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(Request $request, string $id)
    {
        $sosRequest = SOSRequest::find($id);
        
        if (!$sosRequest) {
            return response()->json([
                'success' => false,
                'message' => 'SOS request not found'
            ], 404);
        }

        // Check if user is the owner of the SOS request
        if ($sosRequest->requester_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized to delete this SOS request'
            ], 403);
        }

        $sosRequest->delete();

        return response()->json([
            'success' => true,
            'message' => 'SOS request deleted successfully'
        ]);
    }

    /**
     * Respond to an SOS request
     */
    public function respond(Request $request, string $id)
    {
        $sosRequest = SOSRequest::find($id);
        
        if (!$sosRequest) {
            return response()->json([
                'success' => false,
                'message' => 'SOS request not found'
            ], 404);
        }

        // Check if SOS request is still active
        if ($sosRequest->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'SOS request is no longer active'
            ], 400);
        }

        $validator = Validator::make($request->all(), [
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation errors',
                'errors' => $validator->errors()
            ], 422);
        }

        // Calculate distance
        $distance = $this->calculateDistance(
            $request->latitude, $request->longitude,
            $sosRequest->latitude, $sosRequest->longitude
        );

        // Check if user already responded to this SOS request
        $existingHelper = SOSHelper::where('sos_id', $id)
            ->where('helper_id', $request->user()->id)
            ->first();

        if ($existingHelper) {
            return response()->json([
                'success' => false,
                'message' => 'You have already responded to this SOS request'
            ], 400);
        }

        $sosHelper = SOSHelper::create([
            'sos_id' => $id,
            'helper_id' => $request->user()->id,
            'responded_at' => now(),
            'distance' => $distance,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Response to SOS request recorded successfully',
            'data' => $sosHelper->load(['helper'])
        ], 201);
    }

    /**
     * Get SOS requests by user
     */
    public function getByUser(Request $request, string $userId)
    {
        $sosRequests = SOSRequest::with(['requester', 'helper', 'sosHelpers.helper'])
            ->where('requester_id', $userId)
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $sosRequests
        ]);
    }

    /**
     * Calculate distance between two coordinates
     */
    private function calculateDistance($lat1, $lon1, $lat2, $lon2)
    {
        $earthRadius = 6371; // Earth's radius in kilometers

        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat/2) * sin($dLat/2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon/2) * sin($dLon/2);
        $c = 2 * atan2(sqrt($a), sqrt(1-$a));

        return $earthRadius * $c;
    }
}