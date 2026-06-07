<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    protected $fillable = [
        'external_id',
        'amount',
        'description',
        'payment_method_type',
        'payment_channel',
        'payment_details',
        'status',
        'xendit_payment_id',
        'paid_at',
        'payout_method_id',
        'disbursement_external_id',
    ];

    protected $casts = [
        'payment_details' => 'array',
        'paid_at' => 'datetime',
        'amount' => 'double',
    ];

    /**
     * Get the payout method associated with this transaction.
     */
    public function payoutMethod()
    {
        return $this->belongsTo(PayoutMethod::class);
    }
}
