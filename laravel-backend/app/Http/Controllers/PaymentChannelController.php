<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class PaymentChannelController extends Controller
{
    /**
     * Get available payment channels grouped by type.
     */
    public function index()
    {
        $channels = [
            'VA' => [
                [ 'code' => 'BCA',     'name' => 'BCA',      'logo' => 'bca' ],
                [ 'code' => 'BNI',     'name' => 'BNI',      'logo' => 'bni' ],
                [ 'code' => 'BRI',     'name' => 'BRI',      'logo' => 'bri' ],
                [ 'code' => 'MANDIRI', 'name' => 'Mandiri',  'logo' => 'mandiri' ],
                [ 'code' => 'PERMATA', 'name' => 'Permata',  'logo' => 'permata' ],
                [ 'code' => 'BSI',     'name' => 'BSI',      'logo' => 'bsi' ],
                [ 'code' => 'BJB',     'name' => 'BJB',      'logo' => 'bjb' ]
            ],
            'QRIS' => [
                [ 'code' => 'QRIS', 'name' => 'QR Code (QRIS)', 'logo' => 'qris' ]
            ],
            'EWALLET' => [
                [ 'code' => 'GOPAY',     'name' => 'GoPay',      'logo' => 'gopay' ],
                [ 'code' => 'OVO',       'name' => 'OVO',         'logo' => 'ovo' ],
                [ 'code' => 'DANA',      'name' => 'Dana',        'logo' => 'dana' ],
                [ 'code' => 'SHOPEEPAY', 'name' => 'ShopeePay',  'logo' => 'shopeepay' ],
                [ 'code' => 'LINKAJA',   'name' => 'LinkAja',    'logo' => 'linkaja' ]
            ],
            'RETAIL' => [
                [ 'code' => 'ALFAMART',  'name' => 'Alfamart',   'logo' => 'alfamart' ],
                [ 'code' => 'INDOMARET', 'name' => 'Indomaret',  'logo' => 'indomaret' ]
            ],
            'CARD' => [
                [ 'code' => 'CARDS', 'name' => 'Credit / Debit Card', 'logo' => 'card' ]
            ]
        ];

        return response()->json([
            'success' => true,
            'data' => $channels
        ]);
    }
}
