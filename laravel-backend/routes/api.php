<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\PaymentChannelController;
use App\Http\Controllers\TransactionController;
use App\Http\Controllers\WebhookController;
use App\Http\Controllers\CardChargeController;

// Payment Channels
Route::get('/payment-channels', [PaymentChannelController::class, 'index']);

// Card Direct Charge
Route::post('/card/charge', [CardChargeController::class, 'charge']);

// Transactions
Route::get('/transactions', [TransactionController::class, 'index']);
Route::post('/transactions', [TransactionController::class, 'store']);
Route::get('/transactions/{id}', [TransactionController::class, 'show']);
Route::post('/transactions/{id}/accept', [TransactionController::class, 'accept']);
Route::post('/transactions/{id}/simulate', [TransactionController::class, 'simulate']);
Route::delete('/transactions', [TransactionController::class, 'clear']);

// Webhooks (Xendit callback integrations)
Route::prefix('webhooks/xendit')->group(function () {
    Route::post('/payment', [WebhookController::class, 'handlePayment']);
    Route::post('/disbursement', [WebhookController::class, 'handleDisbursement']);
});
