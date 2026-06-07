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
        Schema::create('payout_methods', function (Blueprint $table) {
            $table->id();
            $table->string('label');
            $table->string('channel_code');
            $table->string('channel_type'); // BANK | EWALLET
            $table->text('account_number_encrypted');
            $table->text('holder_name_encrypted')->nullable(); // Can be null for e-wallets
            $table->string('masked_account');
            $table->boolean('is_primary')->default(false);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payout_methods');
    }
};
