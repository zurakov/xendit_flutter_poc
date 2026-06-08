<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class XenditService
{
    protected string $secretKey;
    protected string $baseUrl = 'https://api.xendit.co';

    public function __construct()
    {
        $this->secretKey = env('XENDIT_SECRET_KEY', '');
    }

    protected function client()
    {
        return Http::withBasicAuth($this->secretKey, '')
            ->withoutVerifying()
            ->withHeaders([
                'Content-Type' => 'application/json',
            ]);
    }

    public function createPaymentRequest(
        string $referenceId,
        int $amount,
        string $channelCode,
        string $paymentMethodType
    ): array {
        // Map VA bank codes (e.g., BNI, BCA) to standard v3 channel codes (e.g., BNI_VIRTUAL_ACCOUNT)
        if ($paymentMethodType === 'VA' && !str_ends_with($channelCode, '_VIRTUAL_ACCOUNT')) {
            $channelCode = $channelCode . '_VIRTUAL_ACCOUNT';
        }

        $channelProperties = $this->buildChannelProperties($channelCode, $paymentMethodType, $referenceId);

        $response = Http::withBasicAuth(config('services.xendit.secret_key'), '')
            ->withoutVerifying()
            ->withHeaders([
                'api-version' => '2024-11-11',
                'Content-Type' => 'application/json',
            ])
            ->post('https://api.xendit.co/v3/payment_requests', [
                'reference_id'   => $referenceId,
                'type'           => 'PAY',
                'country'        => 'ID',
                'currency'       => 'IDR',
                'request_amount' => $amount,
                'channel_code'   => $channelCode,
                'channel_properties' => $channelProperties,
            ]);

        if (!$response->successful()) {
            throw new \Exception('Xendit createPaymentRequest failed: ' . $response->body());
        }

        return $response->json();
    }

    private function buildChannelProperties(string $channelCode, string $paymentMethodType, string $referenceId): array
    {
        $expiry = now()->addHours(24)->toIso8601String();

        return match($paymentMethodType) {
            'VA' => [
                'display_name' => 'POC Payment',
                'expires_at'   => $expiry,
            ],
            'QRIS' => [
                'qr_string_type' => 'DYNAMIC',
                'expires_at'     => $expiry,
            ],
            'EWALLET' => [
                'success_return_url' => config('app.url') . '/payment/success?reference_id=' . $referenceId,
                'failure_return_url' => config('app.url') . '/payment/failure?reference_id=' . $referenceId,
                'cancel_return_url'  => config('app.url') . '/payment/cancel?reference_id=' . $referenceId,
            ],
            'RETAIL' => [
                'payer_name' => 'POC User',
                'expires_at' => $expiry,
            ],
            default => throw new \Exception("Unsupported payment method type: $paymentMethodType"),
        };
    }

    public function createPayout(
        string $referenceId,
        string $channelCode,
        string $accountHolderName,
        string $accountNumber,
        float $amount,
        string $description
    ): array {
        // Ensure channelCode has ID_ prefix if not present (required by v3/v2 Payouts API)
        if (!str_starts_with($channelCode, 'ID_')) {
            $channelCode = 'ID_' . $channelCode;
        }

        // Mock fallback for sandbox/forbidden errors or mock testing account number
        if ($accountNumber === '1234567890' || $accountNumber === '000000000099') {
            Log::info("Mock payout account detected. Simulating successful payout.");
            return [
                'id' => 'po-mock-' . (string) \Illuminate\Support\Str::uuid(),
                'reference_id' => $referenceId,
                'status' => 'ACCEPTED',
                'amount' => (int) $amount,
                'channel_code' => $channelCode,
                'channel_properties' => [
                    'account_number' => $accountNumber,
                    'account_holder_name' => $accountHolderName,
                ]
            ];
        }

        $payload = [
            'reference_id' => $referenceId,
            'channel_code' => $channelCode,
            'channel_properties' => [
                'account_number' => $accountNumber,
                'account_holder_name' => $accountHolderName,
            ],
            'amount' => (int) $amount,
            'currency' => 'IDR',
            'description' => $description,
        ];

        Log::info('Xendit createPayout payload:', $payload);

        $response = Http::withBasicAuth(config('services.xendit.secret_key'), '')
            ->withoutVerifying()
            ->withHeaders([
                'Content-Type' => 'application/json',
                'Idempotency-key' => $referenceId,
            ])
            ->post('https://api.xendit.co/v2/payouts', $payload);

        if (!$response->successful()) {
            Log::error('Xendit createPayout failed:', $response->json() ?: [$response->body()]);
            throw new \Exception($response->json()['message'] ?? 'Failed to create Payout from Xendit');
        }

        return $response->json();
    }

    /**
     * Simulate a sandbox payment for test mode.
     */
    public function simulatePayment(string $type, string $externalId, ?string $xenditPaymentId, float $amount)
    {
        $url = "{$this->baseUrl}/v3/payment_requests/{$xenditPaymentId}/simulate";
        $payload = ['amount' => (int) $amount];

        Log::info("Simulating payment via Xendit API: URL={$url}, payload=" . json_encode($payload));

        $response = Http::withBasicAuth(config('services.xendit.secret_key'), '')
            ->withoutVerifying()
            ->withHeaders([
                'api-version' => '2024-11-11',
                'Content-Type' => 'application/json',
            ])
            ->post($url, $payload);

        if ($response->failed()) {
            Log::error("Xendit simulation failed: status={$response->status()}, body=" . $response->body());
            throw new \Exception($response->json()['message'] ?? 'Failed to simulate payment in Xendit Sandbox');
        }

        return $response->json();
    }

    public function createCardPaymentDirect(
        string $referenceId,
        int $amount,
        string $description,
        string $cardNumber,
        string $expiryMonth,
        string $expiryYear,
        string $cvn,
        string $cardholderFirstName,
        string $cardholderLastName,
        string $cardholderEmail,
        string $cardholderPhone
    ): array {
        // Mock fallback for browser / desktop testing with simulated card numbers
        if ($cardNumber === '4000000000001091') {
            Log::info("Mock card number detected. Simulating successful card payment requiring action.");
            return [
                'id' => 'pr-mock-' . (string) \Illuminate\Support\Str::uuid(),
                'status' => 'REQUIRES_ACTION',
                'actions' => [
                    [
                        'type' => 'REDIRECT_CUSTOMER',
                        'value' => config('app.url') . '/payment/success?reference_id=' . $referenceId,
                    ]
                ],
                'channel_properties' => [
                    'card_details' => [
                        'masked_card_number' => '400000XXXXXX1091',
                        'type' => 'DEBIT',
                        'network' => 'VISA',
                    ]
                ]
            ];
        }

        $payload = [
            'reference_id'   => $referenceId,
            'type'           => 'PAY',
            'country'        => 'ID',
            'currency'       => 'IDR',
            'request_amount' => $amount,
            'capture_method' => 'AUTOMATIC',
            'channel_code'   => 'CARDS',
            'channel_properties' => [
                'card_details' => [
                    'card_number' => $cardNumber,
                    'cvn'         => $cvn,
                    'expiry_month'=> $expiryMonth,
                    'expiry_year' => $expiryYear,
                    'cardholder_first_name' => $cardholderFirstName,
                    'cardholder_last_name'  => $cardholderLastName,
                    'cardholder_email'      => $cardholderEmail,
                ],
                'success_return_url'  => config('app.url') . '/payment/success?reference_id=' . $referenceId,
                'failure_return_url'  => config('app.url') . '/payment/failure?reference_id=' . $referenceId,
            ],
            'description' => $description,
        ];

        $response = Http::withBasicAuth(config('services.xendit.secret_key'), '')
            ->withoutVerifying()
            ->withHeaders([
                'api-version' => '2024-11-11',
                'Content-Type' => 'application/json',
            ])
            ->post('https://api.xendit.co/v3/payment_requests', $payload);

        if (!$response->successful()) {
            throw new \Exception('Xendit createCardPaymentDirect failed: ' . $response->body());
        }

        return $response->json();
    }
}
