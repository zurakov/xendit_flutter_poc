<?php

namespace App\Http\Controllers;

use App\Services\XenditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class CardChargeController extends Controller
{
    protected XenditService $xendit;

    public function __construct(XenditService $xendit)
    {
        $this->xendit = $xendit;
    }

    public function charge(Request $request)
    {
        $request->validate([
            'amount'               => 'required|numeric|min:1000',
            'description'          => 'nullable|string|max:255',
            'card_number'          => 'required|string|min:13|max:19',
            'expiry_month'         => 'required|string|size:2',
            'expiry_year'          => 'required|string|size:4',
            'cvn'                  => 'required|string|min:3|max:4',
            'cardholder_first_name'=> 'required|string|max:100',
            'cardholder_last_name' => 'required|string|max:100',
            'cardholder_email'     => 'required|email|max:255',
            'cardholder_phone'     => 'required|string|max:20',
        ]);

        $referenceId = 'card-' . Str::uuid()->toString();

        try {
            $xenditResponse = $this->xendit->createCardPaymentDirect(
                referenceId:          $referenceId,
                amount:               (int) $request->amount,
                description:          $request->description ?? 'Card Payment',
                cardNumber:           $request->card_number,
                expiryMonth:          $request->expiry_month,
                expiryYear:           $request->expiry_year,
                cvn:                  $request->cvn,
                cardholderFirstName:  $request->cardholder_first_name,
                cardholderLastName:   $request->cardholder_last_name,
                cardholderEmail:      $request->cardholder_email,
                cardholderPhone:      $request->cardholder_phone,
            );

            $status = strtoupper($xenditResponse['status'] ?? 'PENDING');
            $requiresAction = $status === 'REQUIRES_ACTION';
            $actionUrl = null;

            // Extract 3DS redirect URL from actions array
            if ($requiresAction) {
                $actions = $xenditResponse['actions'] ?? [];
                foreach ($actions as $action) {
                    $type = $action['type'] ?? $action['descriptor'] ?? '';
                    if (in_array($type, ['REDIRECT_CUSTOMER', 'WEB_URL', 'AUTH'])) {
                        $actionUrl = $action['value'] ?? $action['url'] ?? null;
                        break;
                    }
                }
                if (!$actionUrl && !empty($actions)) {
                    $actionUrl = $actions[0]['value'] ?? $actions[0]['url'] ?? null;
                }
            }

            // Map local status
            $localStatus = 'PENDING';
            if (in_array($status, ['SUCCEEDED', 'COMPLETED'])) {
                $localStatus = 'PAID';
            } elseif (in_array($status, ['FAILED', 'CANCELED', 'DECLINED'])) {
                $localStatus = 'FAILED';
            }

            // Failure reasons map for premium UX
            $failureDescriptions = [
                'EXPIRED_CARD' => 'The card has expired. Please check the expiry date or try another card.',
                'SUSPECTED_FRAUDULENT' => 'This transaction was flagged as suspected fraud by the issuer.',
                'DECLINED_BY_PROCESSOR' => 'The payment processor declined this transaction.',
                'INSUFFICIENT_BALANCE' => 'The card has insufficient balance or credit limit.',
                'STOLEN_CARD' => 'This card is reported as lost or stolen.',
                'INACTIVE_OR_UNAUTHORIZED_CARD' => 'The card is inactive or not authorized for online/e-commerce use.',
                'PROCESSOR_ERROR' => 'A backend card processor error occurred. Please try again.',
                'INVALID_CVV' => 'The CVV/CVN security code entered is incorrect.',
                'DECLINED_BY_ISSUER' => 'The transaction was declined by the card issuing bank.',
                'AUTHENTICATION_FAILED' => 'Card 3DS verification failed. Please enter the correct OTP.',
            ];

            $failureCode = $xenditResponse['failure_code'] ?? null;
            $failureReason = null;
            if ($failureCode) {
                $failureReason = $failureDescriptions[strtoupper($failureCode)] ?? 'The transaction was declined. Code: ' . $failureCode;
            }

            // Persist transaction record
            $isPaid = $localStatus === 'PAID';
            $transaction = \App\Models\Transaction::create([
                'external_id'         => $referenceId,
                'amount'              => (float) $request->amount,
                'description'         => $request->description ?? 'Card Payment',
                'payment_method_type' => 'CARD',
                'payment_channel'     => 'CARDS',
                'payment_details'     => [
                    'masked_card' => $xenditResponse['channel_properties']['card_details']['masked_card_number']
                                     ?? $xenditResponse['payment_method']['card']['card_information']['masked_card_number']
                                     ?? null,
                    'network'     => $xenditResponse['channel_properties']['card_details']['network']
                                     ?? $xenditResponse['payment_method']['card']['card_information']['network']
                                     ?? 'UNKNOWN',
                    'card_type'   => $xenditResponse['channel_properties']['card_details']['type']
                                     ?? $xenditResponse['payment_method']['card']['card_information']['card_type']
                                     ?? 'CREDIT',
                    'failure_code'   => $failureCode,
                    'failure_reason' => $failureReason,
                ],
                'status'              => $localStatus,
                'paid_at'             => $isPaid ? now() : null,
                'xendit_payment_id'   => $xenditResponse['id'] ?? $xenditResponse['payment_request_id'] ?? null,
            ]);

            return response()->json([
                'success'         => true,
                'data'            => [
                    'id'              => $transaction->id,
                    'external_id'     => $transaction->external_id,
                    'amount'          => $transaction->amount,
                    'status'          => $transaction->status,
                    'requires_action' => $requiresAction,
                    'action_url'      => $actionUrl,
                    'payment_details' => $transaction->payment_details,
                ]
            ]);
        } catch (\Exception $e) {
            Log::error('Direct card charge failed: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error'   => $e->getMessage()
            ], 500);
        }
    }

    public function paymentSuccess(Request $request)
    {
        $referenceId = $request->query('reference_id');
        Log::info("paymentSuccess redirect hit for reference_id: {$referenceId}");

        if ($referenceId) {
            $transaction = \App\Models\Transaction::where('external_id', $referenceId)->first();
            if ($transaction && $transaction->status === 'PENDING') {
                $transaction->update([
                    'status'  => 'PAID',
                    'paid_at' => now(),
                ]);
                Log::info("Transaction {$transaction->id} marked as PAID via redirect.");
            }
        }

        return view('payment_result', [
            'status' => 'success',
            'title' => 'Payment Successful',
            'message' => 'Thank you! Your payment has been authorized successfully.',
            'referenceId' => $referenceId
        ]);
    }

    public function paymentFailure(Request $request)
    {
        $referenceId = $request->query('reference_id');
        $failureCode = $request->query('failure_code') ?? $request->query('failure_reason') ?? null;
        Log::info("paymentFailure redirect hit for reference_id: {$referenceId}, failure_code: {$failureCode}");

        if ($referenceId) {
            $transaction = \App\Models\Transaction::where('external_id', $referenceId)->first();
            if ($transaction && $transaction->status === 'PENDING') {
                $paymentDetails = $transaction->payment_details ?? [];

                $failureDescriptions = [
                    'EXPIRED_CARD' => 'The card has expired. Please check the expiry date or try another card.',
                    'SUSPECTED_FRAUDULENT' => 'This transaction was flagged as suspected fraud by the issuer.',
                    'DECLINED_BY_PROCESSOR' => 'The payment processor declined this transaction.',
                    'INSUFFICIENT_BALANCE' => 'The card has insufficient balance or credit limit.',
                    'STOLEN_CARD' => 'This card is reported as lost or stolen.',
                    'INACTIVE_OR_UNAUTHORIZED_CARD' => 'The card is inactive or not authorized for online/e-commerce use.',
                    'PROCESSOR_ERROR' => 'A backend card processor error occurred. Please try again.',
                    'INVALID_CVV' => 'The CVV/CVN security code entered is incorrect.',
                    'DECLINED_BY_ISSUER' => 'The transaction was declined by the card issuing bank.',
                    'AUTHENTICATION_FAILED' => 'Card 3DS verification failed. Please enter the correct OTP.',
                ];

                $reason = $failureCode ? ($failureDescriptions[strtoupper($failureCode)] ?? 'Authentication/authorization was declined by card issuer.') : '3DS authentication failed or was cancelled.';
                
                $paymentDetails['failure_code'] = $failureCode ?? 'AUTHENTICATION_FAILED';
                $paymentDetails['failure_reason'] = $reason;

                $transaction->update([
                    'status'  => 'FAILED',
                    'payment_details' => $paymentDetails,
                ]);
                Log::info("Transaction {$transaction->id} marked as FAILED via redirect.");
            }
        }

        return view('payment_result', [
            'status' => 'failure',
            'title' => 'Payment Failed',
            'message' => 'Unfortunately, your payment could not be processed. Please try again.',
            'referenceId' => $referenceId
        ]);
    }
}

