# Known Operational Notes & Checklist

1. **Supabase Vault Secrets**: Before enabling live CashMaal auto-payouts in production, set `CASHMAAL_MERCHANT_ID`, `CASHMAAL_SECRET_PIN`, and `CASHMAAL_PAYOUT_API_KEY` via the Admin Panel Vault endpoint or Supabase Dashboard Secrets.
2. **Android Nearby & Mic Permissions**: Offline multi-device P2P requires runtime user approval for `NEARBY_WIFI_DEVICES`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, `ACCESS_FINE_LOCATION` (Android <= 12), and `RECORD_AUDIO`.
3. **Gemini API Key**: Stored client-side in `flutter_secure_storage` (Android Keystore) and used directly over WebSocket/HTTPS in Online Mode only; never transmitted to or stored in Supabase database tables.
