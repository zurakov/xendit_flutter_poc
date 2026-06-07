<?php

namespace App\Http\Controllers;

use App\Models\PayoutMethod;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;

class PayoutMethodController extends Controller
{
    /**
     * List all payout methods.
     */
    public function index()
    {
        $payoutMethods = PayoutMethod::orderBy('created_at', 'desc')->get();
        
        return response()->json([
            'success' => true,
            'data' => $payoutMethods
        ]);
    }

    /**
     * Store a new payout method.
     */
    public function store(Request $request)
    {
        $request->validate([
            'label' => 'required|string|max:255',
            'channel_code' => 'required|string|max:50',
            'channel_type' => 'required|string|in:BANK,EWALLET',
            'account_number' => 'required|string|max:50',
            'holder_name' => 'required_if:channel_type,BANK|nullable|string|max:255',
            'is_primary' => 'nullable|boolean',
        ]);

        $accountNumber = $request->account_number;
        $holderName = $request->holder_name;

        // Mask account number (e.g. ••••7890)
        $maskedAccount = '••••' . substr($accountNumber, -4);
        if (strlen($accountNumber) < 4) {
            $maskedAccount = str_repeat('•', strlen($accountNumber));
        }

        $isPrimary = $request->input('is_primary', false);

        DB::beginTransaction();
        try {
            if ($isPrimary) {
                // Set all other payout methods to not primary
                PayoutMethod::where('is_primary', true)->update(['is_primary' => false]);
            }

            $payoutMethod = PayoutMethod::create([
                'label' => $request->label,
                'channel_code' => $request->channel_code,
                'channel_type' => $request->channel_type,
                'account_number_encrypted' => Crypt::encryptString($accountNumber),
                'holder_name_encrypted' => $holderName ? Crypt::encryptString($holderName) : null,
                'masked_account' => $maskedAccount,
                'is_primary' => $isPrimary,
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'data' => $payoutMethod
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'error' => 'Failed to save payout method: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Remove a payout method.
     */
    public function destroy($id)
    {
        $payoutMethod = PayoutMethod::find($id);

        if (!$payoutMethod) {
            return response()->json([
                'success' => false,
                'error' => 'Payout method not found'
            ], 404);
        }

        $payoutMethod->delete();

        return response()->json([
            'success' => true,
            'message' => 'Payout method deleted successfully'
        ]);
    }
}
