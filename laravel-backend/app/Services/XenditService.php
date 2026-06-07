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

        $channelProperties = $this->buildChannelProperties($channelCode, $paymentMethodType);

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

    private function buildChannelProperties(string $channelCode, string $paymentMethodType): array
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
                'success_return_url' => config('app.url') . '/payment/success',
                'failure_return_url' => config('app.url') . '/payment/failure',
                'cancel_return_url'  => config('app.url') . '/payment/cancel',
            ],
            'RETAIL' => [
                'payer_name' => 'POC User',
                'expires_at' => $expiry,
            ],
            default => throw new \Exception("Unsupported payment method type: $paymentMethodType"),
        };
    }

    public function createDisbursement(string $externalId, string $bankCode, string $accountHolder, string $accountNumber, float $amount, string $description)
    {
        $payload = [
            'external_id' => $externalId,
            'bank_code' => $bankCode,
            'account_holder_name' => $accountHolder,
            'account_number' => $accountNumber,
            'description' => $description,
            'amount' => (int) $amount,
        ];

        Log::info('Xendit createDisbursement payload:', $payload);

        $response = $this->client()->post("{$this->baseUrl}/disbursements", $payload);

        if ($response->failed()) {
            Log::error('Xendit createDisbursement failed:', $response->json() ?: [$response->body()]);
            throw new \Exception($response->json()['message'] ?? 'Failed to create Disbursement from Xendit');
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

    public function createCardSession(
        string $customerName,
        string $customerEmail,
        string $customerPhone
    ): array {
        $referenceId = 'card-session-' . (string) \Illuminate\Support\Str::uuid();
        $customerReferenceId = 'cust-' . (string) \Illuminate\Support\Str::uuid();

        $response = Http::withBasicAuth(config('services.xendit.secret_key'), '')
            ->withoutVerifying()
            ->withHeaders([
                'Content-Type' => 'application/json',
            ])
            ->post('https://api.xendit.co/sessions', [
                'reference_id'  => $referenceId,
                'session_type'  => 'SAVE',
                'mode'          => 'CARDS_SESSION_JS',
                'amount'        => 0,
                'currency'      => 'IDR',
                'country'       => 'ID',
                'customer'      => [
                    'reference_id'      => $customerReferenceId,
                    'type'              => 'INDIVIDUAL',
                    'email'             => $customerEmail,
                    'mobile_number'     => $customerPhone,
                    'individual_detail' => [
                        'given_names' => $customerName,
                    ],
                ],
                'cards_session_js' => [
                    'success_return_url' => config('app.url') . '/payment/success',
                    'failure_return_url' => config('app.url') . '/payment/failure',
                ],
            ]);

        if (!$response->successful()) {
            throw new \Exception('Xendit createCardSession failed: ' . $response->body());
        }

        return $response->json();
    }

    public function createCardPayment(
        string $paymentTokenId,
        int $amount,
        string $referenceId
    ): array {
        // Mock fallback for browser / desktop testing with simulated tokens
        if (str_starts_with($paymentTokenId, 'pt-mock-token-')) {
            Log::info("Mock card payment token detected. Simulating successful card payment.");
            return [
                'id' => 'pr-mock-' . (string) \Illuminate\Support\Str::uuid(),
                'status' => 'SUCCEEDED',
                'payment_method' => [
                    'type' => 'CARD',
                    'card' => [
                        'card_information' => [
                            'masked_card_number' => '400000XXXXXX1091',
                            'card_type' => 'DEBIT',
                            'network' => 'VISA',
                        ],
                    ],
                ],
            ];
        }

        $payload = [
            'reference_id'      => $referenceId,
            'type'              => 'PAY',
            'country'           => 'ID',
            'currency'          => 'IDR',
            'request_amount'    => $amount,
            'payment_token_id'  => $paymentTokenId,
            'channel_properties' => [
                'skip_three_ds'       => false,
                'success_return_url'  => config('app.url') . '/payment/success',
                'failure_return_url'  => config('app.url') . '/payment/failure',
                'card_on_file_type'   => 'CUSTOMER_UNSCHEDULED',
            ],
        ];

        $maxRetries = 3;
        $attempt = 0;

        while ($attempt < $maxRetries) {
            $response = Http::withBasicAuth(config('services.xendit.secret_key'), '')
                ->withoutVerifying()
                ->withHeaders([
                    'api-version' => '2024-11-11',
                    'Content-Type' => 'application/json',
                ])
                ->post('https://api.xendit.co/v3/payment_requests', $payload);

            $body = $response->json();

            if ($response->successful()) {
                return $body;
            }

            if (($body['error_code'] ?? '') === 'TOKEN_NOT_ACTIVE' && $attempt < $maxRetries - 1) {
                $attempt++;
                sleep(1);
                continue;
            }

            throw new \Exception('Xendit createCardPayment failed: ' . $response->body());
        }

        throw new \Exception('Xendit createCardPayment retries exhausted.');
    }
}
