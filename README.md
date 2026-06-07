# Xendit Payment & Payout System POC

This proof-of-concept (POC) demonstrates a complete Indonesian money-in (Multi-Channel Payments via Xendit) and money-out (Disbursements via Xendit) lifecycle using a **PHP Laravel 11** backend (with SQLite) and a **Flutter 3.x** mobile frontend.

---

## 🛠️ Stack & Technologies

- **Backend**: PHP 8.3, Laravel 11, SQLite (No local database server installation required)
- **Frontend**: Flutter 3.x (Dart), provider (State Management), dio (HTTP client), qr_flutter (QRIS rendering), url_launcher (eWallet launching)
- **Tunneling**: Microsoft `devtunnel` (for public webhook URLs)
- **Xendit**: Test Mode Integration

---

## 🚀 Setup & Execution Guide

### Part 1: Laravel Backend Setup

1. **Navigate to the Backend Directory**:
   ```bash
   cd laravel-backend
   ```

2. **Configure Environment Variables**:
   Open `laravel-backend/.env` and update the following settings if needed (pre-configured with Sandbox keys for testing):
   ```ini
   XENDIT_SECRET_KEY=xnd_development_WwJk6dWh7fP6K80WpZ14s4gQ0J8g9X5Bv3j817G9q1P2r
   XENDIT_WEBHOOK_TOKEN=poc_webhook_token_123456
   XENDIT_VA_BANK=BNI
   ```

3. **Start the Laravel Server**:
   ```bash
   php artisan serve --port=8000
   ```
   The backend will start listening at `http://localhost:8000`.

---

### Part 2: Tunneling with Devtunnel (Webhooks)

Since Xendit needs to send payment callback webhooks to your local machine, expose your local port 8000 using the pre-installed Microsoft `devtunnel`:

1. **Start the Tunnel**:
   ```bash
   devtunnel host -p 8000 --allow-anonymous
   ```

2. **Copy the Public URL**:
   Look for the output containing `Connect via browser:` or the URL pointing to your tunnel, which typically looks like:
   `https://[tunnel-id]-[port].rel.tunnels.api.visualstudio.com`

3. **Register Webhook Callbacks in Xendit Dashboard**:
   Go to your **Xendit Dashboard** -> **Settings** -> **Callbacks** and configure the following URLs under their respective sections:
   - **Virtual Account Paid** -> `POST` `https://[your-devtunnel-domain]/api/webhooks/xendit/va-paid`
   - **QR Code Paid** -> `POST` `https://[your-devtunnel-domain]/api/webhooks/xendit/qr-paid`
   - **eWallet Payment Status** -> `POST` `https://[your-devtunnel-domain]/api/webhooks/xendit/ewallet-paid`
   - **Retail Outlet Paid** -> `POST` `https://[your-devtunnel-domain]/api/webhooks/xendit/retail-paid`
   - **Disbursement Sent/Completed** -> `POST` `https://[your-devtunnel-domain]/api/webhooks/xendit/disbursement`

4. **Verify the Token**:
   Make sure the `x-callback-token` header value matches the token you defined in `.env` (`poc_webhook_token_123456`).

---

### Part 3: Flutter Frontend Setup

1. **Navigate to the Frontend Directory**:
   ```bash
   cd flutter-frontend
   ```

2. **Configure API Base URL**:
   Open `lib/config/app_config.dart` and update the `baseUrl` to point to your public `devtunnel` domain URL (including `/api` path):
   ```dart
   class AppConfig {
     static const String baseUrl = 'https://[your-devtunnel-domain]/api';
   }
   ```
   *Note: For Android Emulator testing, you can use `http://10.0.2.2:8000/api` if you are not testing webhooks.*

3. **Run the App**:
   Ensure an Android Emulator or iOS Simulator is running, then run:
   ```bash
   flutter run
   ```

---

## 🧪 Simulation & Testing Guide

Once the app is running, follow these steps to simulate a complete payment & payout lifecycle:

### Step 1: Create a Payment
1. Tap the **"Create Payment"** floating action button on the Home Screen.
2. Select your preferred channel under the tabs:
   - **Virtual Account (VA)**: BNI, BCA, BRI, Mandiri, Permata, BSI, BJB
   - **QR Code (QRIS)**: Dynamic QRIS code
   - **eWallet**: GoPay, OVO, DANA, ShopeePay, LinkAja
   - **Retail**: Alfamart, Indomaret
3. Enter the amount (minimum `10,000` IDR) and description, then tap **"Generate Payment Link"**.
4. You will be redirected to the **Payment Detail Screen** displaying payment instructions.

### Step 2: Simulate Payment (Money-In)
Go to your **Xendit Dashboard (Test Mode)** and simulate payment based on the channel type:

- **Virtual Account**:
  1. Go to **Virtual Accounts** -> **Transactions**.
  2. Locate the generated VA number from the Flutter app.
  3. Click **"Simulate Payment"** next to it.
- **QR Code (QRIS)**:
  1. Go to **QR Codes**.
  2. Find the QR Code matching the `reference_id` (starts with `txn-`).
  3. Click **"Simulate Payment"**.
- **eWallet**:
  1. Go to **eWallets**.
  2. Locate the charge matching the `reference_id` (starts with `txn-`).
  3. Click **"Simulate Payment"** (or use the redirect checkout page).
- **Retail Outlet**:
  1. Go to **Retail Outlets**.
  2. Find the payment code.
  3. Click **"Simulate Payment"**.

### Step 3: Verify Status updates to PAID
1. The Flutter screen will poll the backend every 3 seconds while on the detail screen.
2. As soon as Xendit hits Laravel's webhook, the database is updated to `PAID`.
3. The Flutter app detects this update, stops polling, and displays a green **"✓ Payment Received"** banner.

### Step 4: Accept and Payout (Money-Out)
1. Tap the **"Accept & Payout"** button on the detail screen.
2. A bottom sheet will show saved payout methods.
   - *Note: A default "Test BCA Account" is pre-seeded in the database for instant testing.*
   - *To manage payout methods, tap the settings icon in the top right of the Home Screen.*
3. Select the payout method, confirm the dialog, and watch the status update to `ACCEPTED`.
4. In the background, Xendit creates a **Disbursement**.
5. Once Xendit processes the test payout, it fires the disbursement webhook back to Laravel.
6. The transaction's status automatically changes to `DISBURSED`. Check the Xendit Dashboard -> **Disbursements** to verify.

---

## 🔒 Security Design Highlights

- **Encrypted Storage**: Payout account numbers and holder names are encrypted inside the SQLite database using Laravel's AES-256-CBC engine (`Crypt::encryptString`). They are never stored in plain text.
- **In-Memory Decryption**: Decryption only occurs immediately before sending the API request payload to Xendit.
- **Masked Fields**: API endpoints for listing or showing payout methods return a masked format (e.g. `••••7890`). Raw account numbers are never exposed in JSON responses.
- **Exempt CSRF for Webhooks**: Laravel exempts `/api/webhooks/xendit/*` from CSRF checks via `bootstrap/app.php` but verifies them using the manual header token `x-callback-token`.
