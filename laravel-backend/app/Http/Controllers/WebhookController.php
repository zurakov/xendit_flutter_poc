<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

class WebhookController extends Controller
{
    /**
     * Verify the Xendit callback token.
     */
    protected function isValidToken(Request $request): bool
    {
        $token = $request->header('x-callback-token');
        $expectedToken = config('services.xendit.webhook_token');
        
        Log::info('Webhook verification:', [
            'received' => $token,
            'expected' => $expectedToken
        ]);

        return $token === $expectedToken;
    }

    /**
     * Handle unified payment webhook.
     */
    public function handlePayment(Request $request): JsonResponse
    {
        Log::info('Unified Payment Webhook hit:', $request->all());

        // 1. Verify callback token
        if (!$this->isValidToken($request)) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        $payload = $request->json()->all();

        // 2. Only process succeeded events
        if (($payload['event'] ?? '') !== 'payment.succeeded') {
            return response()->json(['message' => 'Event ignored'], 200);
        }

        $data        = $payload['data'] ?? [];
        $referenceId = $data['reference_id'] ?? null;
        $paymentId   = $data['id'] ?? null;

        // 3. Find and update the transaction
        $transaction = Transaction::where('external_id', $referenceId)
            ->orWhere('xendit_payment_id', $paymentId)
            ->first();

        if (!$transaction) {
            Log::warning("Transaction not found for Payment: ref_id={$referenceId}, pay_id={$paymentId}");
            return response()->json(['message' => 'Transaction not found'], 404);
        }

        if ($transaction->status === 'PENDING') {
            $transaction->update([
                'status'  => 'PAID',
                'paid_at' => now(),
            ]);
            Log::info("Transaction {$transaction->id} marked as PAID via unified payment webhook.");
        }

        return response()->json(['message' => 'OK'], 200);
    }

    /**
     * Webhook for Disbursement completed/failed.
     */
    public function handleDisbursement(Request $request)
    {
        Log::info('Disbursement Webhook hit:', $request->all());

        if (!$this->isValidToken($request)) {
            return response()->json(['success' => false, 'error' => 'Invalid webhook token'], 401);
        }

        $externalId = $request->input('external_id');
        $status = strtoupper($request->input('status', ''));

        $transaction = Transaction::where('disbursement_external_id', $externalId)->first();

        if (!$transaction) {
            Log::warning("Transaction not found for Disbursement: disb_ext_id={$externalId}");
            return response()->json(['success' => false, 'error' => 'Transaction not found'], 200);
        }

        if ($transaction->status === 'ACCEPTED') {
            if ($status === 'COMPLETED') {
                $transaction->update(['status' => 'DISBURSED']);
                Log::info("Transaction {$transaction->id} marked as DISBURSED via webhook.");
            } elseif ($status === 'FAILED') {
                $transaction->update(['status' => 'FAILED']);
                Log::info("Transaction {$transaction->id} marked as FAILED via webhook.");
            }
        }

        return response()->json(['success' => true]);
    }
}
