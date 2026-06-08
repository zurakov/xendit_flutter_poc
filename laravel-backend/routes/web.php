<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\CardChargeController;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/payment/success', [CardChargeController::class, 'paymentSuccess'])->name('payment.success');
Route::get('/payment/failure', [CardChargeController::class, 'paymentFailure'])->name('payment.failure');

