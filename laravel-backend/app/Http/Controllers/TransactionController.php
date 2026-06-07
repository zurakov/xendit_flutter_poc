<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Models\PayoutMethod;
use App\Services\XenditService;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;

class TransactionController extends Controller
{
    protected XenditService $xendit;

    public function __construct(XenditService $xendit)
    {
        $this->xendit = $xendit;
    }

    /**
     * List all transactions.
     */
    public function index()
    {
        $transactions = Transaction::with('payoutMethod')->orderBy('created_at', 'desc')->get();
        return response()->json([
            'success' => true,
            'data' => $transactions
        ]);
    }

    /**
     * Show a specific transaction.
     */
    public function show($id)
    {
        $transaction = Transaction::with('payoutMethod')->find($id);

        if (!$transaction) {
            return response()->json([
                'success' => false,
                'error' => 'Transaction not found'
            ], 404);
        }

        // Auto-complete mock disbursements after 3 seconds for seamless demo
        if ($transaction->status === 'ACCEPTED' && str_starts_with($transaction->disbursement_external_id ?? '', 'mock-disb-')) {
            $secondsSinceUpdate = now()->diffInSeconds($transaction->updated_at);
            if ($secondsSinceUpdate >= 3) {
                $transaction->update([
                    'status' => 'DISBURSED'
                ]);
                Log::info("Mock disbursement {$transaction->disbursement_external_id} auto-completed to DISBURSED.");
                
                // Refresh model
                $transaction->refresh();
            }
        }

        return response()->json([
            'success' => true,
            'data' => $transaction
        ]);
    }

    /**
     * Create a new payment transaction.
     */
    public function store(Request $request)
    {
        $request->validate([
            'amount' => 'required|numeric|min:1',
            'description' => 'nullable|string|max:255',
            'payment_method_type' => 'required|string|in:VA,QRIS,EWALLET,RETAIL,CARD',
            'payment_channel' => 'required|string',
            'payment_token_id' => 'required_if:payment_method_type,CARD|string',
        ]);

        $uuid = Str::uuid()->toString();
        $externalId = "txn-{$uuid}";
        $amount = (float) $request->amount;
        $desc = $request->description ?: 'POC Payment';
        $type = $request->payment_method_type;
        $channel = $request->payment_channel;

        try {
            if ($type === 'CARD') {
                $xenditResponse = $this->xendit->createCardPayment(
                    paymentTokenId: $request->payment_token_id,
                    amount:         (int) $amount,
                    referenceId:    $externalId,
                );
            } else {
                $xenditResponse = $this->xendit->createPaymentRequest(
                    referenceId:       $externalId,
                    amount:            (int) $amount,
                    channelCode:       $channel,
                    paymentMethodType: $type,
                );
            }

            $xenditId = $xenditResponse['id'] ?? $xenditResponse['payment_request_id'] ?? null;
            $paymentDetails = $this->extractPaymentDetails($xenditResponse, $type);

            // Check if payment request succeeded/completed immediately (e.g. for Cards)
            $status = 'PENDING';
            $paidAt = null;
            if (isset($xenditResponse['status']) && in_array(strtoupper($xenditResponse['status']), ['SUCCEEDED', 'COMPLETED'])) {
                $status = 'PAID';
                $paidAt = now();
            }

            // Save transaction in database
            $transaction = Transaction::create([
                'external_id' => $externalId,
                'amount' => $amount,
                'description' => $desc,
                'payment_method_type' => $type,
                'payment_channel' => $channel,
                'payment_details' => $paymentDetails,
                'status' => $status,
                'paid_at' => $paidAt,
                'xendit_payment_id' => $xenditId,
            ]);

            return response()->json([
                'success' => true,
                'data' => [
                    'id' => $transaction->id,
                    'external_id' => $transaction->external_id,
                    'amount' => $transaction->amount,
                    'status' => $transaction->status,
                    'payment_method_type' => $transaction->payment_method_type,
                    'payment_channel' => $transaction->payment_channel,
                    'payment_details' => $transaction->payment_details,
                    'xendit_payment_id' => $transaction->xendit_payment_id,
                ]
            ], 201);

        } catch (\Exception $e) {
            $errMessage = $e->getMessage();
            Log::error("Transaction creation failed: " . $errMessage);

            if (str_contains($errMessage, 'TOKEN_NOT_ACTIVE')) {
                return response()->json([
                    'success' => false,
                    'error' => 'TOKEN_NOT_ACTIVE',
                    'message' => 'Card tokenization is still processing. Please try again in a moment.'
                ], 422);
            }

            if (str_contains($errMessage, 'CHANNEL_NOT_ACTIVATED')) {
                return response()->json([
                    'success' => false,
                    'error' => 'CHANNEL_NOT_ACTIVATED',
                    'message' => 'Retail payment is not activated on this account.'
                ]);
            }

            return response()->json([
                'success' => false,
                'error' => 'Failed to initiate payment: ' . $errMessage
            ], 500);
        }
    }

    /**
     * Accept a PAID transaction and trigger disbursement.
     */
    public function accept($id, Request $request)
    {
        $request->validate([
            'payout_method_id' => 'required|exists:payout_methods,id'
        ]);

        $transaction = Transaction::find($id);

        if (!$transaction) {
            return response()->json([
                'success' => false,
                'error' => 'Transaction not found'
            ], 404);
        }

        if ($transaction->status !== 'PAID') {
            return response()->json([
                'success' => false,
                'error' => 'Transaction must be in PAID status to request payout. Current: ' . $transaction->status
            ], 400);
        }

        $payoutMethod = PayoutMethod::find($request->payout_method_id);

        try {
            // Decrypt immediately before making the API request
            $decryptedAccountNumber = $payoutMethod->getDecryptedAccountNumber();
            $decryptedHolderName = $payoutMethod->getDecryptedHolderName();

            // Default holder name for e-wallets if empty
            if (empty($decryptedHolderName)) {
                $decryptedHolderName = $payoutMethod->label ?: 'POC User';
            }

            // Create disbursement external_id
            $timestamp = time();
            $disbExternalId = "disbursement-{$transaction->id}-{$timestamp}";

            // Trigger disbursement
            try {
                $result = $this->xendit->createDisbursement(
                    $disbExternalId,
                    $payoutMethod->channel_code,
                    $decryptedHolderName,
                    $decryptedAccountNumber,
                    $transaction->amount,
                    "Payout for transaction {$transaction->external_id}"
                );
            } catch (\Exception $e) {
                $errMessage = $e->getMessage();
                // If API Key is forbidden (REQUEST_FORBIDDEN_ERROR), fallback to a local mock sandbox disbursement
                if (str_contains($errMessage, 'forbidden') || str_contains($errMessage, 'REQUEST_FORBIDDEN_ERROR') || str_contains($errMessage, 'permissions')) {
                    Log::warning("Xendit disbursement API returned forbidden (permissions). Falling back to mock sandbox payout.");
                    
                    $mockDisbId = "mock-disb-{$transaction->id}-{$timestamp}";
                    $transaction->update([
                        'status' => 'ACCEPTED',
                        'payout_method_id' => $payoutMethod->id,
                        'disbursement_external_id' => $mockDisbId,
                    ]);

                    return response()->json([
                        'success' => true,
                        'data' => [
                            'transaction_id' => $transaction->id,
                            'status' => $transaction->status,
                            'message' => 'API Key lacks Disbursements permission. Activated local sandbox simulation fallback.',
                            'disbursement' => [
                                'id' => 'mock_disb_' . Str::random(10),
                                'external_id' => $mockDisbId,
                                'amount' => (int) $transaction->amount,
                                'status' => 'PENDING',
                                'bank_code' => $payoutMethod->channel_code,
                                'account_holder_name' => $decryptedHolderName,
                                'description' => "Mock Payout (API key lacks permissions)",
                            ]
                        ]
                    ]);
                } else {
                    throw $e;
                }
            }

            // Update transaction state
            $transaction->update([
                'status' => 'ACCEPTED',
                'payout_method_id' => $payoutMethod->id,
                'disbursement_external_id' => $disbExternalId,
            ]);

            return response()->json([
                'success' => true,
                'data' => [
                    'transaction_id' => $transaction->id,
                    'status' => $transaction->status,
                    'disbursement' => $result
                ]
            ]);

        } catch (\Exception $e) {
            Log::error("Payout disbursement failed: " . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Failed to execute payout: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Simulate sandbox payment for testing.
     */
    public function simulate($id)
    {
        $transaction = Transaction::find($id);

        if (!$transaction) {
            return response()->json([
                'success' => false,
                'error' => 'Transaction not found'
            ], 404);
        }

        try {
            $result = $this->xendit->simulatePayment(
                $transaction->payment_method_type,
                $transaction->external_id,
                $transaction->xendit_payment_id,
                $transaction->amount
            );

            // Update status to PAID locally so the app updates immediately, even if webhooks are not configured
            if ($transaction->status === 'PENDING') {
                $transaction->update([
                    'status' => 'PAID',
                    'paid_at' => now(),
                ]);
                Log::info("Transaction {$transaction->id} marked as PAID locally after successful API simulation.");
            }

            return response()->json([
                'success' => true,
                'data' => $result
            ]);
        } catch (\Exception $e) {
            Log::error("Simulation endpoint failed: " . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => 'Failed to simulate payment: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Clear all transactions.
     */
    public function clear()
    {
        Transaction::query()->delete();
        Log::info("All transactions cleared from local SQLite database.");
        return response()->json([
            'success' => true,
            'message' => 'All payments removed from database.'
        ]);
    }

    private function extractPaymentDetails(array $xenditResponse, string $type): array
    {
        $actions = collect($xenditResponse['actions'] ?? []);

        return match($type) {
            'VA' => [
                'va_number' => $xenditResponse['channel_properties']['virtual_account_number']
                               ?? $actions->firstWhere('descriptor', 'VIRTUAL_ACCOUNT_NUMBER')['value']
                               ?? $actions->firstWhere('action', 'PAY')['url']
                               ?? null,
                'bank_code' => str_replace('_VIRTUAL_ACCOUNT', '', $xenditResponse['channel_code']),
                'expiry'    => $xenditResponse['channel_properties']['expires_at'] ?? null,
            ],
            'QRIS' => [
                'qr_string' => $xenditResponse['channel_properties']['qr_string']
                               ?? $actions->firstWhere('descriptor', 'QR_STRING')['value']
                               ?? $actions->firstWhere('action', 'QR_CHECKOUT')['url']
                               ?? null,
                'expiry'    => $xenditResponse['channel_properties']['expires_at'] ?? null,
            ],
            'EWALLET' => [
                'deeplink_url'            => $actions->firstWhere('descriptor', 'DEEPLINK_URL')['value']
                                             ?? $actions->firstWhere('action', 'AUTH')['url']
                                             ?? $actions->firstWhere('url_type', 'DEEPLINK')['url']
                                             ?? null,
                'mobile_web_checkout_url' => $actions->firstWhere('descriptor', 'MOBILE_WEB')['value']
                                             ?? $actions->firstWhere('url_type', 'MOBILE')['url']
                                             ?? null,
                'checkout_url'            => $actions->firstWhere('descriptor', 'CHECKOUT_URL')['value']
                                             ?? $actions->firstWhere('url_type', 'WEB')['url']
                                             ?? $actions->first()['value']
                                             ?? $actions->first()['url']
                                             ?? null,
                'ewallet_type'            => $xenditResponse['channel_code'],
            ],
            'RETAIL' => [
                'payment_code' => $xenditResponse['channel_properties']['payment_code']
                                  ?? $actions->firstWhere('descriptor', 'PAYMENT_CODE')['value']
                                  ?? $actions->firstWhere('action', 'PAY')['url']
                                  ?? null,
                'outlet'       => $xenditResponse['channel_code'],
                'expiry'       => $xenditResponse['channel_properties']['expires_at'] ?? null,
            ],
            'CARD' => [
                'masked_card' => $xenditResponse['payment_method']['card']['card_information']['masked_card_number'] ?? null,
                'card_type'   => $xenditResponse['payment_method']['card']['card_information']['card_type'] ?? 'CREDIT',
                'network'     => $xenditResponse['payment_method']['card']['card_information']['network'] ?? 'VISA',
            ],
            default => $xenditResponse,
        };
    }
}
