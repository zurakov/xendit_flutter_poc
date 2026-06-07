<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PayoutMethod extends Model
{
    protected $fillable = [
        'label',
        'channel_code',
        'channel_type',
        'account_number_encrypted',
        'holder_name_encrypted',
        'masked_account',
        'is_primary',
    ];

    protected $casts = [
        'is_primary' => 'boolean',
    ];

    /**
     * Decrypt the encrypted account number.
     */
    public function getDecryptedAccountNumber(): string
    {
        return \Illuminate\Support\Facades\Crypt::decryptString($this->account_number_encrypted);
    }

    /**
     * Decrypt the encrypted holder name.
     */
    public function getDecryptedHolderName(): ?string
    {
        return $this->holder_name_encrypted 
            ? \Illuminate\Support\Facades\Crypt::decryptString($this->holder_name_encrypted) 
            : null;
    }
}
