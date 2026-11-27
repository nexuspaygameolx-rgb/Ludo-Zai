import express from "express";
import cors from "cors";
import crypto from "crypto";
import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const supabaseUrl = process.env.SUPABASE_URL || "";
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const db = supabaseUrl && serviceKey
  ? createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } })
  : null;

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "Ludo-Z! Docker Backend", timestamp: new Date().toISOString() });
});

// 1. Public remote config endpoint for Flutter APK startup
app.get("/api/public-config", async (_req, res) => {
  try {
    if (!db) return res.status(503).json({ error: "Database not configured" });
    const { data, error } = await db.from("app_remote_config").select("*").eq("id", 1).single();
    if (error) throw error;
    res.json({ config: data });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 2. Cryptographically Secure Server Dice Roll (Anti-Hack RNG)
app.post("/api/match/roll-dice", async (req, res) => {
  try {
    const { count = 2 } = req.body;
    const safeCount = count === 1 ? 1 : 2;
    const values = Array.from({ length: safeCount }, () => crypto.randomInt(1, 7));
    res.json({ values, used: Array(safeCount).fill(false), timestamp: Date.now() });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Helper: Compile plain Urdu/English/Punjabi natural-language instruction into executable Ludo rule
function compileNaturalInstruction(instructionText, customTitle) {
  const lower = String(instructionText || "").toLowerCase();

  let trigger = "on_capture";
  if (lower.includes("ghar") || lower.includes("home") || lower.includes("lane") || lower.includes("ander")) {
    trigger = "on_home_entry";
  } else if (lower.includes("dice") || lower.includes("daana") || lower.includes("chakka") || lower.includes("6") || lower.includes("12") || lower.includes("roll")) {
    trigger = "on_dice_roll";
  }

  let condition = "has_finished_token";
  let conditionValue = null;
  if (lower.includes("kuti") || lower.includes("ulti") || lower.includes("reverse")) {
    condition = "is_kuti";
  } else if (lower.includes("12") || lower.includes("double six") || lower.includes("do chakkay")) {
    condition = "dice_sum_exact";
    conditionValue = 12;
  } else if (lower.includes("6") || lower.includes("chakka")) {
    condition = "dice_sum_exact";
    conditionValue = 6;
  }

  let action = "grant_extra_turn";
  if (lower.includes("kuti") || lower.includes("ulti") || lower.includes("ulTi") || lower.includes("reverse") || lower.includes("palat")) {
    action = "flip_to_kuti";
  }

  const code = crypto.randomBytes(3).toString("hex").toUpperCase();
  const title = (customTitle && customTitle.trim())
    ? customTitle.trim()
    : instructionText.trim().slice(0, 38) + (instructionText.trim().length > 38 ? "..." : "");

  return {
    rule_code: code,
    title,
    natural_instruction: instructionText.trim(),
    trigger_type: trigger,
    condition_type: condition,
    condition_value: conditionValue,
    action_type: action,
  };
}

// 3. Compile Natural-Language Rule & Save to Global Community Database
app.post("/api/rules/compile-and-save", async (req, res) => {
  try {
    const { instruction, title, creator_id, creator_name } = req.body;
    if (!instruction || String(instruction).trim().length < 4) {
      throw new Error("Please write a clear rule instruction");
    }

    const compiled = compileNaturalInstruction(instruction, title);

    if (db) {
      const { data, error } = await db
        .from("community_nl_rules")
        .upsert(
          {
            ...compiled,
            creator_id: creator_id || null,
            creator_name: creator_name || "Desi Player",
            is_approved: true,
          },
          { onConflict: "rule_code" }
        )
        .select()
        .single();
      if (error) throw error;
      return res.json({ ok: true, rule: data });
    }

    res.json({ ok: true, rule: compiled });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 4. Fetch All Community Natural-Language Rules for All Users
app.get("/api/rules/community", async (_req, res) => {
  try {
    if (!db) return res.json({ rules: [] });
    const { data, error } = await db
      .from("community_nl_rules")
      .select("*")
      .eq("is_approved", true)
      .order("created_at", { ascending: false })
      .limit(100);
    if (error) throw error;
    res.json({ rules: data || [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 5. Automated CashMaal Buy Order Creation (100 PKR = 1000 Coins, 100 PKR = 100 Gems)
app.post("/api/cashmaal/buy", async (req, res) => {
  try {
    if (!db) throw new Error("Server DB not configured");
    const { user_id, asset_type, asset_amount } = req.body;
    if (!user_id) throw new Error("Gmail registration required for Buy/Sell");

    const { data: cfg } = await db.from("app_remote_config").select("cashmaal_public_config").eq("id", 1).single();
    const cm = cfg?.cashmaal_public_config || {};
    if (!cm.enabled) throw new Error("CashMaal Store is currently disabled");

    const amount = Math.max(1, Number(asset_amount));
    let pkrAmount = 0;
    let rateApplied = 0;

    if (asset_type === "coins") {
      rateApplied = Number(cm.coins_buy_rate_pkr_per_1000 ?? 100);
      pkrAmount = (amount / 1000) * rateApplied;
    } else if (asset_type === "gems") {
      rateApplied = Number(cm.gems_buy_rate_pkr_per_100 ?? 100);
      pkrAmount = (amount / 100) * rateApplied;
    } else {
      throw new Error("Invalid asset type");
    }

    const { data: order, error } = await db
      .from("cashmaal_orders")
      .insert({
        user_id,
        order_type: "buy",
        asset_type,
        asset_amount: amount,
        pkr_amount: Number(pkrAmount.toFixed(2)),
        rate_applied: rateApplied,
        status: "pending",
      })
      .select()
      .single();
    if (error) throw error;

    const merchantId = process.env.CASHMAAL_MERCHANT_ID || "";
    const checkoutBase = process.env.CASHMAAL_CHECKOUT_BASE_URL || "";
    const checkoutUrl = `${checkoutBase}?merchant_id=${encodeURIComponent(merchantId)}&order_id=${order.id}&amount=${order.pkr_amount}&currency=PKR`;

    res.json({ order, checkout_url: checkoutUrl });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 6. Automated CashMaal Sell & Direct Account Withdrawal (30% Admin Fee -> 70% Net Payout)
app.post("/api/cashmaal/sell", async (req, res) => {
  try {
    if (!db) throw new Error("Server DB not configured");
    const { user_id, asset_type, asset_amount, cashmaal_account } = req.body;
    if (!user_id) throw new Error("Gmail registration required to sell and withdraw");
    if (!cashmaal_account) throw new Error("CashMaal account email/ID is required");

    const { data: cfg } = await db.from("app_remote_config").select("cashmaal_public_config").eq("id", 1).single();
    const cm = cfg?.cashmaal_public_config || {};
    if (!cm.enabled) throw new Error("CashMaal Store is currently disabled");

    const amount = Number(asset_amount);
    const feePercent = Number(cm.sell_fee_percent ?? 30);
    const payoutMultiplier = (100 - feePercent) / 100;

    let grossPkr = 0;
    let netPkr = 0;
    let rateApplied = 0;

    if (asset_type === "coins") {
      const minCoins = Number(cm.min_sell_coins ?? 1000);
      if (amount < minCoins) throw new Error(`Minimum sell amount is ${minCoins} coins`);
      const buyRate = Number(cm.coins_buy_rate_pkr_per_1000 ?? 100);
      rateApplied = Number((buyRate * payoutMultiplier).toFixed(2));
      grossPkr = (amount / 1000) * buyRate;
      netPkr = Number((grossPkr * payoutMultiplier).toFixed(2));

      const { error: lockErr } = await db.rpc("apply_wallet_delta", {
        p_user_id: user_id,
        p_coins_delta: -amount,
        p_gems_delta: 0,
        p_reason: "cashmaal_sell_escrow",
        p_note: `Sell ${amount} coins (Gross ${grossPkr} PKR - ${feePercent}% fee = ${netPkr} PKR)`,
      });
      if (lockErr) throw new Error(lockErr.message);
    } else if (asset_type === "gems") {
      const minGems = Number(cm.min_sell_gems ?? 100);
      if (amount < minGems) throw new Error(`Minimum sell amount is ${minGems} gems`);
      const buyRate = Number(cm.gems_buy_rate_pkr_per_100 ?? 100);
      rateApplied = Number((buyRate * payoutMultiplier).toFixed(2));
      grossPkr = (amount / 100) * buyRate;
      netPkr = Number((grossPkr * payoutMultiplier).toFixed(2));

      const { error: lockErr } = await db.rpc("apply_wallet_delta", {
        p_user_id: user_id,
        p_coins_delta: 0,
        p_gems_delta: -amount,
        p_reason: "cashmaal_sell_escrow",
        p_note: `Sell ${amount} gems (Gross ${grossPkr} PKR - ${feePercent}% fee = ${netPkr} PKR)`,
      });
      if (lockErr) throw new Error(lockErr.message);
    } else {
      throw new Error("Unsupported asset type");
    }

    const { data: order, error: ordErr } = await db
      .from("cashmaal_orders")
      .insert({
        user_id,
        order_type: "sell",
        asset_type,
        asset_amount: amount,
        pkr_amount: netPkr,
        rate_applied: rateApplied,
        cashmaal_account: String(cashmaal_account).trim(),
        status: "processing",
        audit_notes: `${feePercent}% sell fee applied (Gross: ${grossPkr} PKR, Net: ${netPkr} PKR)`,
      })
      .select()
      .single();
    if (ordErr) throw ordErr;

    const payoutUrl = process.env.CASHMAAL_PAYOUT_API_URL || "";
    const payoutApiKey = process.env.CASHMAAL_PAYOUT_API_KEY || "";
    const merchantId = process.env.CASHMAAL_MERCHANT_ID || "";

    if (payoutUrl && payoutApiKey && cm.auto_payout_enabled !== false) {
      const gwResp = await fetch(payoutUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${payoutApiKey}`,
        },
        body: JSON.stringify({
          merchant_id: merchantId,
          receiver_account: String(cashmaal_account).trim(),
          amount_pkr: netPkr,
          reference_id: order.id,
        }),
      });
      const gwData = await gwResp.json().catch(() => ({}));
      if (gwResp.ok && (gwData.status === "success" || gwData.txn_id)) {
        await db
          .from("cashmaal_orders")
          .update({
            status: "completed",
            gateway_txn_id: String(gwData.txn_id || `CM_${Date.now()}`),
            updated_at: new Date().toISOString(),
          })
          .eq("id", order.id);
        return res.json({
          ok: true,
          status: "completed",
          net_pkr: netPkr,
          fee_percent: feePercent,
          message: `${netPkr} PKR aapke CashMaal account (${cashmaal_account}) mein auto-transfer kar diye gaye hain!`,
        });
      } else {
        await db.rpc("apply_wallet_delta", {
          p_user_id: user_id,
          p_coins_delta: asset_type === "coins" ? amount : 0,
          p_gems_delta: asset_type === "gems" ? amount : 0,
          p_reason: "cashmaal_sell_refund",
          p_reference_id: order.id,
          p_note: "Auto-refund due to CashMaal payout failure",
        });
        await db
          .from("cashmaal_orders")
          .update({ status: "failed", audit_notes: JSON.stringify(gwData) })
          .eq("id", order.id);
        throw new Error(gwData.message || "CashMaal payout failed; balance refunded to your wallet.");
      }
    }

    res.json({
      ok: true,
      status: "processing",
      net_pkr: netPkr,
      fee_percent: feePercent,
      message: `${netPkr} PKR withdrawal queued for CashMaal auto-payout.`,
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 7. CashMaal IPN Webhook
app.post("/api/cashmaal/ipn", async (req, res) => {
  try {
    if (!db) throw new Error("Server DB not configured");
    const { order_id, txn_id, secret_pin } = req.body;
    const expectedPin = process.env.CASHMAAL_SECRET_PIN || "";
    if (!expectedPin || secret_pin !== expectedPin) {
      return res.status(403).json({ error: "Invalid IPN secret PIN" });
    }

    const { data: order } = await db.from("cashmaal_orders").select("*").eq("id", order_id).single();
    if (!order || order.status === "completed") return res.json({ ok: true });

    await db.rpc("apply_wallet_delta", {
      p_user_id: order.user_id,
      p_coins_delta: order.asset_type === "coins" ? order.asset_amount : 0,
      p_gems_delta: order.asset_type === "gems" ? order.asset_amount : 0,
      p_reason: "cashmaal_buy_deposit",
      p_reference_id: String(txn_id),
    });

    await db
      .from("cashmaal_orders")
      .update({ status: "completed", gateway_txn_id: String(txn_id), updated_at: new Date().toISOString() })
      .eq("id", order.id);

    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

const port = Number(process.env.PORT || 10000);
app.listen(port, () => {
  console.log(`Ludo-Z! Docker backend running on port ${port}`);
});
