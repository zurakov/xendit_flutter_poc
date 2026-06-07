<?php

namespace App\Http\Controllers;

use App\Services\XenditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class CardSessionController extends Controller
{
    protected XenditService $xendit;

    public function __construct(XenditService $xendit)
    {
        $this->xendit = $xendit;
    }

    public function create(Request $request)
    {
        $request->validate([
            'customer_name' => 'required|string|max:255',
            'customer_email' => 'required|email|max:255',
            'customer_phone' => 'required|string|max:255',
        ]);

        try {
            $session = $this->xendit->createCardSession(
                customerName:  $request->customer_name,
                customerEmail: $request->customer_email,
                customerPhone: $request->customer_phone,
            );

            return response()->json([
                'success' => true,
                'data' => [
                    'payment_session_id' => $session['payment_session_id'] ?? null,
                    'expires_at'         => $session['expires_at'] ?? null,
                ]
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to create card session: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => $e->getMessage()
            ], 500);
        }
    }
}
