# CCMAP - E-Bike Sharing Platform Developer Guide

Welcome to the CCMAP codebase! This document provides a comprehensive overview of how this Flutter + Supabase application operates, designed to help newly onboarded developers quickly orient themselves, understand the architecture, and contribute effectively.

---

## 1. Quick Start: How to Run the App Locally

To test and develop on your local machine, follow these steps:

1. **Clone the Repository**
   ```bash
   git clone <your-repository-url>
   cd ccmap_bits
   ```

2. **Configure Environment Variables**
   The application securely manages Supabase credentials via a `.env` file. You must create this file manually.
   - Create a file named `.env` in the root folder (`ccmap_bits/.env`).
   - Add your Supabase project keys to the file:
     ```env
     SUPABASE_URL=https://<YOUR-PROJECT-ID>.supabase.co
     SUPABASE_ANON_KEY=<YOUR-ANON-KEY>
     ```

3. **Install Dependencies**
   Run the following to pull all necessary Flutter packages:
   ```bash
   flutter pub get
   ```

4. **Run the App (Web Testing Mode)**
   We strongly recommend testing on port 5000 due to pre-configured redirects or CORS settings.
   ```bash
   flutter run --web-port 5000
   ```
   > **Note:** When evaluating physical hardware aspects (like NFC), the web version uses a built-in Mock Simulator. To truly test NFC logic, you must compile and deploy to a physical Android (`flutter run -d android`) or iOS device.

---

## 2. Directory Structure

The project strictly follows a feature-based / logic-based folder structure to ensure maintainability.

```text
ccmap_bits/
├── lib/
│   ├── main.dart                 # Application entry point & Supabase initialization
│   ├── screens/                  # All UI Pages and Views
│   │   ├── admin/                # Features limited to Sys-Admins (Station & Cycle Mgmt)
│   │   ├── auth/                 # Sign In / OTP login logic and screens
│   │   ├── landing_page.dart     # The Map, Station locator, and Book Ride flow
│   │   ├── ride_details_page.dart# Active tracking, Trip Billing, GPS trailing
│   │   └── payment_mock_page.dart# Post-trip receipt and mock payment 
│   ├── utils/                    # Core Hardware & Logic APIs
│   │   ├── nfc_service.dart      # Platform-switching Smart Gateway for NFC
│   │   ├── nfc_web.dart          # Mocks NFC scanning for local web development
│   │   ├── nfc_mobile.dart       # True native NFC_manager logic for Android/iOS
│   │   └── routing_service.dart  # Connects to OSRM APIs to draw paths on the map
│   └── widgets/                  # Highly reusable UI components
│       └── app_drawer.dart       # The side-navigation menu
├── android/                      # Native Android configurations (Permissions inside AndroidManifest)
├── ios/                          # Native iOS configurations (Permissions inside Info.plist)
└── pubspec.yaml                  # Core dependency listing
```

---

## 3. Architecture & Key Workflows

### A. Authentication
- **Location:** `lib/screens/auth/`
- **How it works:** We use Supabase Magic Links / OTP via email. When a user logs in, Supabase issues a session token. Based on `_supabase.auth.currentUser`, the `main.dart` routing mechanism determines whether to show the Login Page or immediately launch the `LandingPage`.

### B. Hardware Synchronization (QR + NFC)
- **Problem:** We must ensure the user is physically touching the bike to unlock or lock it.
- **Solution:** 
  - The App uses a simple barcode scanner to read a QR code visually stuck to the bike.
  - The App then forces the user to tap their phone against the hidden NFC RFID tag. We use `lib/utils/nfc_service.dart` to write physical data to this tag (`status:unlocked`).
- **Web Bypass:** Because web browsers lack physical NFC access, if `kIsWeb` is true, the `NfcWebHandler` automatically steps in to provide a 2-second mock loading screen, allowing developers to test the flow without needing a real phone.

### C. Booking & Billing (The Ride Flow)
If you need to change how a user books a ride, look here:

1. **Starting the Ride (`landing_page.dart`)**
   - The user selects a station and cycle.
   - The app verifies their Wallet Balance is `>= 10.0` (The Base fare).
   - After they physically tap the NFC tag via the dialog, the app creates a new row in the `rides` table on Supabase (status: `ongoing`).
   - The user is transitioned to `ride_details_page.dart`.

2. **Tracking the Ride (`ride_details_page.dart`)**
   - **GPS:** Uses `Geolocator` stream. It logs the route polyline into `_trail` and heartbeats the location to Supabase every 15 seconds.
   - **Time:** Uses a `Timer` to calculate elapsed seconds.
   - **Pricing Model:** Currently set to **Time-Based**.
     - `_baseFare`: ₹10
     - `_farePerMinute`: ₹2
     - *How to Change:* Open `ride_details_page.dart`, look for the static variables at the top of the state class, and adjust them. The formula uses `ceil()` to round up to the nearest minute.

3. **Ending the Ride (`ride_details_page.dart`)**
   - The user clicks "End Ride" and taps the NFC lock.
   - The app runs `_processFinalPayment()`.
   - **Wallet Logic:** The app queries the user's `wallet_balance` from the `profiles` table, subtracts the final fare, and saves the new balance. **Users are allowed to go into a negative balance.**

### D. The Admin Dashboard
- **Location:** `lib/screens/admin/admin_page.dart`
- **Purpose:** Provide a master view for adding, editing, and deleting stations and cycles.
- **Provisioning Flow:** When an Admin adds a new cycle, the system inserts a temporary stub into Supabase to acquire a `UUID`. It then forces the admin to hold their phone against a blank RFID sticker, encoding the new UUID onto it natively. 

---
