<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Seed a default payout method for immediate testing
        \App\Models\PayoutMethod::create([
            'label' => 'Test BCA Account',
            'channel_code' => 'BCA',
            'channel_type' => 'BANK',
            'account_number_encrypted' => \Illuminate\Support\Facades\Crypt::encryptString('1234567890'),
            'holder_name_encrypted' => \Illuminate\Support\Facades\Crypt::encryptString('John Doe'),
            'masked_account' => '••••7890',
            'is_primary' => true,
        ]);
    }
}
