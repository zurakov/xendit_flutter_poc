<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->string('external_id')->unique()->index();
            $table->decimal('amount', 15, 2);
            $table->string('description')->nullable();
            $table->string('payment_method_type'); // VA | QRIS | EWALLET | RETAIL
            $table->string('payment_channel'); // BNI | GOPAY | QRIS | ALFAMART etc.
            $table->json('payment_details'); // stores JSON payment parameters
            $table->string('status')->default('PENDING'); // PENDING | PAID | ACCEPTED | DISBURSED | FAILED
            $table->string('xendit_payment_id')->nullable(); // ewc_xxx, qr_xxx, va_xxx
            $table->timestamp('paid_at')->nullable();
            $table->foreignId('payout_method_id')->nullable()->constrained('payout_methods')->onDelete('set null');
            $table->string('disbursement_external_id')->nullable()->unique();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
