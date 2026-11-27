import React, { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL || "",
  import.meta.env.VITE_SUPABASE_ANON_KEY || ""
);

export default function App() {
  const [tab, setTab] = useState<"dashboard" | "cashmaal" | "adsterra" | "rules" | "users">("dashboard");
  const [config, setConfig] = useState<any>(null);
  const [orders, setOrders] = useState<any[]>([]);
  const [users, setUsers] = useState<any[]>([]);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState("");

  useEffect(() => {
    loadAll();
  }, []);

  async function loadAll() {
    const { data: cfg } = await supabase.from("app_remote_config").select("*").eq("id", 1).single();
    if (cfg) setConfig(cfg);
    const { data: ord } = await supabase.from("cashmaal_orders").select("*").order("created_at", { ascending: false }).limit(25);
    if (ord) setOrders(ord);
    const { data: profs } = await supabase.from("profiles").select("*").order("created_at", { ascending: false }).limit(30);
    if (profs) setUsers(profs);
  }

  async function saveRemoteConfig() {
    if (!config) return;
    setSaving(true);
    const { error } = await supabase
      .from("app_remote_config")
      .update({
        maintenance_mode: config.maintenance_mode,
        maintenance_message: config.maintenance_message,
        force_update_apk_url: config.force_update_apk_url,
        adsterra_config: config.adsterra_config,
        cashmaal_public_config: config.cashmaal_public_config,
        default_rules: config.default_rules,
        gemini_ai_global_enabled: config.gemini_ai_global_enabled,
        updated_at: new Date().toISOString(),
      })
      .eq("id", 1);
    setSaving(false);
    setToast(error ? `Error: ${error.message}` : "Live APK configuration updated!");
    setTimeout(() => setToast(""), 3500);
  }

  async function toggleUserBan(userId: string, currentlyBanned: boolean) {
    await supabase.from("profiles").update({ is_banned: !currentlyBanned }).eq("id", userId);
    loadAll();
  }

  const cardStyle: React.CSSProperties = {
    background: "#141B2D",
    border: "1px solid #2A3550",
    borderRadius: 16,
    padding: 20,
    marginBottom: 16,
  };

  const inputStyle: React.CSSProperties = {
    width: "100%",
    padding: "10px 12px",
    borderRadius: 10,
    border: "1px solid #2A3550",
    background: "#0B0F1A",
    color: "#F8FAFC",
    marginTop: 6,
    marginBottom: 12,
  };

  if (!config) {
    return <div style={{ padding: 32 }}>Loading Ludo-Z! Admin Control Center...</div>;
  }

  return (
    <div style={{ maxWidth: 1120, margin: "0 auto", padding: 24 }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div>
          <h1 style={{ margin: 0, color: "#F5B041", fontSize: 26 }}>Ludo-Z! Admin Control Center</h1>
          <p style={{ margin: "4px 0 0", color: "#94A3B8", fontSize: 13 }}>
            Zero-APK-Update Live Control: CashMaal Spreads, Adsterra Links, Desi Kuti Rules & Player Audits
          </p>
        </div>
        <button
          onClick={saveRemoteConfig}
          disabled={saving}
          style={{
            background: "#F5B041",
            color: "#0B0F1A",
            border: "none",
            borderRadius: 12,
            padding: "12px 20px",
            fontWeight: 800,
            cursor: "pointer",
          }}
        >
          {saving ? "Saving..." : "Publish Live Changes"}
        </button>
      </header>

      {toast && (
        <div style={{ background: "#10B981", color: "#0B0F1A", padding: 12, borderRadius: 12, fontWeight: 700, marginBottom: 16 }}>
          {toast}
        </div>
      )}

      <nav style={{ display: "flex", gap: 10, marginBottom: 20, flexWrap: "wrap" }}>
        {(["dashboard", "cashmaal", "adsterra", "rules", "users"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            style={{
              padding: "10px 16px",
              borderRadius: 12,
              border: "1px solid #2A3550",
              background: tab === t ? "#F5B041" : "#141B2D",
              color: tab === t ? "#0B0F1A" : "#F8FAFC",
              fontWeight: 700,
              cursor: "pointer",
              textTransform: "uppercase",
            }}
          >
            {t}
          </button>
        ))}
      </nav>

      {tab === "dashboard" && (
        <div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: 16 }}>
            <div style={cardStyle}>
              <div style={{ color: "#94A3B8", fontSize: 12 }}>REGISTERED PLAYERS</div>
              <div style={{ fontSize: 28, fontWeight: 900, color: "#00E5FF" }}>{users.length}</div>
            </div>
            <div style={cardStyle}>
              <div style={{ color: "#94A3B8", fontSize: 12 }}>CASHMAAL ORDERS</div>
              <div style={{ fontSize: 28, fontWeight: 900, color: "#10B981" }}>{orders.length}</div>
            </div>
            <div style={cardStyle}>
              <div style={{ color: "#94A3B8", fontSize: 12 }}>GEMINI AI GLOBAL</div>
              <div style={{ fontSize: 28, fontWeight: 900, color: "#F5B041" }}>
                {config.gemini_ai_global_enabled ? "ACTIVE" : "PAUSED"}
              </div>
            </div>
          </div>

          <div style={cardStyle}>
            <h3>Global App & Maintenance Switches</h3>
            <label>
              <input
                type="checkbox"
                checked={config.maintenance_mode}
                onChange={(e) => setConfig({ ...config, maintenance_mode: e.target.checked })}
              />{" "}
              Enable Maintenance Mode
            </label>
            <input
              style={inputStyle}
              value={config.maintenance_message}
              onChange={(e) => setConfig({ ...config, maintenance_message: e.target.value })}
              placeholder="Maintenance banner text"
            />
            <label>Force Update Direct APK Download Link (GitHub / Drive)</label>
            <input
              style={inputStyle}
              value={config.force_update_apk_url}
              onChange={(e) => setConfig({ ...config, force_update_apk_url: e.target.value })}
              placeholder="Direct APK URL"
            />
          </div>
        </div>
      )}

      {tab === "cashmaal" && (
        <div style={cardStyle}>
          <h3>CashMaal Buy / Sell Spread (Admin Margin Model)</h3>
          <label>Coins Buy Rate (PKR per 1,000 Coins — User Buys Higher)</label>
          <input
            type="number"
            style={inputStyle}
            value={config.cashmaal_public_config.coins_buy_rate_pkr_per_1000}
            onChange={(e) =>
              setConfig({
                ...config,
                cashmaal_public_config: {
                  ...config.cashmaal_public_config,
                  coins_buy_rate_pkr_per_1000: Number(e.target.value),
                },
              })
            }
          />
          <label>Coins Sell Rate (PKR per 1,000 Coins — Admin Buys Cheaper)</label>
          <input
            type="number"
            style={inputStyle}
            value={config.cashmaal_public_config.coins_sell_rate_pkr_per_1000}
            onChange={(e) =>
              setConfig({
                ...config,
                cashmaal_public_config: {
                  ...config.cashmaal_public_config,
                  coins_sell_rate_pkr_per_1000: Number(e.target.value),
                },
              })
            }
          />
          <label>Gems Buy Rate (PKR per 10 Gems)</label>
          <input
            type="number"
            style={inputStyle}
            value={config.cashmaal_public_config.gems_buy_rate_pkr_per_10}
            onChange={(e) =>
              setConfig({
                ...config,
                cashmaal_public_config: {
                  ...config.cashmaal_public_config,
                  gems_buy_rate_pkr_per_10: Number(e.target.value),
                },
              })
            }
          />
          <label>Gems Sell Rate (PKR per 10 Gems)</label>
          <input
            type="number"
            style={inputStyle}
            value={config.cashmaal_public_config.gems_sell_rate_pkr_per_10}
            onChange={(e) =>
              setConfig({
                ...config,
                cashmaal_public_config: {
                  ...config.cashmaal_public_config,
                  gems_sell_rate_pkr_per_10: Number(e.target.value),
                },
              })
            }
          />
        </div>
      )}

      {tab === "adsterra" && (
        <div style={cardStyle}>
          <h3>Adsterra Links & Reward Amounts (Live APK Sync)</h3>
          <label>Adsterra Direct Link URL</label>
          <input
            style={inputStyle}
            value={config.adsterra_config.direct_link_url}
            onChange={(e) =>
              setConfig({
                ...config,
                adsterra_config: { ...config.adsterra_config, direct_link_url: e.target.value },
              })
            }
          />
          <label>Adsterra Rewarded Ad URL</label>
          <input
            style={inputStyle}
            value={config.adsterra_config.rewarded_ad_url}
            onChange={(e) =>
              setConfig({
                ...config,
                adsterra_config: { ...config.adsterra_config, rewarded_ad_url: e.target.value },
              })
            }
          />
          <label>Coins Reward Per Verified Ad</label>
          <input
            type="number"
            style={inputStyle}
            value={config.adsterra_config.reward_coins}
            onChange={(e) =>
              setConfig({
                ...config,
                adsterra_config: { ...config.adsterra_config, reward_coins: Number(e.target.value) },
              })
            }
          />
        </div>
      )}

      {tab === "rules" && (
        <div style={cardStyle}>
          <h3>Default Desi Kuti Rules</h3>
          <label style={{ display: "block", marginBottom: 10 }}>
            <input
              type="checkbox"
              checked={config.default_rules.kutiMode}
              onChange={(e) =>
                setConfig({
                  ...config,
                  default_rules: { ...config.default_rules, kutiMode: e.target.checked },
                })
              }
            />{" "}
            Default Kuti Mode ON (Twin Dice + Ghar Wali Ulti Kuti)
          </label>
          <label style={{ display: "block", marginBottom: 10 }}>
            <input
              type="checkbox"
              checked={config.default_rules.autoSingleDiceOnLastToken}
              onChange={(e) =>
                setConfig({
                  ...config,
                  default_rules: { ...config.default_rules, autoSingleDiceOnLastToken: e.target.checked },
                })
              }
            />{" "}
            Auto Switch to 1 Dice When 1 Token Remaining
          </label>
        </div>
      )}

      {tab === "users" && (
        <div style={cardStyle}>
          <h3>Player Audit & Ban Controls</h3>
          {users.map((u) => (
            <div
              key={u.id}
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                padding: "10px 0",
                borderBottom: "1px solid #2A3550",
              }}
            >
              <div>
                <strong>{u.display_name}</strong> (@{u.username}) — Level {u.level} | Trophies: {u.trophies} | Kuti Kills:{" "}
                {u.total_kuti_captures}
              </div>
              <button
                onClick={() => toggleUserBan(u.id, u.is_banned)}
                style={{
                  background: u.is_banned ? "#10B981" : "#FF3B5C",
                  color: "#fff",
                  border: "none",
                  borderRadius: 8,
                  padding: "6px 12px",
                  cursor: "pointer",
                }}
              >
                {u.is_banned ? "Unban" : "Ban User"}
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
