# Ludo-Z! System Architecture

## 1. Monorepo Layout
- `packages/ludo_rules/` — Pure-Dart deterministic rule engine (`LudoRulesConfig`, `LudoRuleEngine`, `TwinDiceState`, `CustomRuleEvaluator`) shared across Flutter offline/P2P mode and mirrored in TypeScript for Supabase Edge Functions.
- `supabase/migrations/` — Zero-trust PostgreSQL schema (`0001`–`0007`), strict Row-Level Security (`0002`), and atomic `SECURITY DEFINER` RPC functions (`0003`, `0007`).
- `supabase/functions/` — Server-authoritative RNG (`roll-dice`), move validator (`make-move`), CashMaal automated buy/sell webhooks (`cashmaal-*`), Adsterra reward verifier (`verify-adsterra-reward`), and remote config (`get-public-config`).
- `apps/mobile_flutter/` — 3D Flutter Android/iOS client with minimal `.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_ENV`), Multi-Device Offline P2P (Nearby Connections + Hotspot LAN + Bluetooth with live voice/text chat), and Online-Only Maya-Style Gemini AI Companion & Autonomous Player.
- `apps/admin_web/` — Modern SaaS Admin Web Dashboard for live control of Adsterra ad URLs, CashMaal buy/sell spreads & Vault secrets, rule presets, 3D store/dice upgrades, and player audits.

## 2. Core Security Invariants
1. **Zero Client RNG**: Online dice rolls are generated exclusively on Supabase Edge Functions using `crypto.getRandomValues`.
2. **Closed-Loop Economy**: P2P coin transfers are disabled. All Coins, Gems, and Trophies are bought from or sold back to the Admin Store via CashMaal automated SCI/IPN and Payout APIs.
3. **Offline P2P Isolation**: Multi-device offline matches run on a Host-authoritative local `LudoRuleEngine` and never mutate online CashMaal balances.
4. **Online-Only Gemini AI**: Gemini API key is stored in hardware-backed Android Keystore and strictly disabled in offline/P2P modes.
