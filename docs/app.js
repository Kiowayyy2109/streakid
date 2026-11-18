"use strict";
/* =====================================================================
   StreakID — static front-end.
   - Reads go through a public BNB Chain RPC endpoint (no wallet needed).
   - Check-in is sent through the visitor's own wallet (window.ethereum):
     the visitor always reviews and confirms the transaction themselves.
   - No server, no sessions, no QR / pairing-code login, no approvals.
   ===================================================================== */

// ---------------- CONFIG (edit after deployment) --------------------
// TODO(phase-2): replace with the deployed StreakID address on BNB Chain.
const STREAK_ID_ADDRESS = "0x0000000000000000000000000000000000000000";
// SPACE ID Agent ID registry, BNB Chain mainnet (from the official
// Binance Agent ID Hackathon announcement; EIP-55 checksum verified).
const AGENT_ID_REGISTRY = "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F";
const BSC_CHAIN_ID = 56;
const BSC_RPC = "https://bsc-dataseed.binance.org";
const LEADERBOARD_LIMIT = 200;

// Function selectors (keccak256 of the signature, first 4 bytes;
// cross-checked against the compiled contract artifact).
const SEL = {
  checkIn: "0x183ff085",
  registryBalanceOf: "0x70a08231", // balanceOf(address) on the Agent ID NFT
  hasAgentId: "0x4eab3ef2",
  streakOf: "0x4fc1854a",
  bestStreakOf: "0x6253b708",
  pointsOf: "0xcf6a4403",
  totalCheckInsOf: "0x4bceea1e",
  lastCheckIn: "0xef6fdb1c",
  badgeMaskOf: "0xfa460d7c",
  canCheckInToday: "0x591ff3e0",
  nextCheckInAt: "0x0acb6219",
  totalAgents: "0xc5053712",
  getAgents: "0xbe5d5d9b",
};

// ---------------- tiny ABI helpers ----------------------------------
const pad32 = (hex) => hex.replace(/^0x/, "").padStart(64, "0");
const encAddress = (a) => pad32(a.toLowerCase());
const encUint = (n) => pad32(BigInt(n).toString(16));
const decUint = (hex) => (hex && hex !== "0x" ? BigInt(hex) : 0n);
const shortAddr = (a) => a.slice(0, 6) + "…" + a.slice(-4);

let rpcId = 0;
async function rpcCall(to, data) {
  const res = await fetch(BSC_RPC, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: ++rpcId,
      method: "eth_call",
      params: [{ to, data }, "latest"],
    }),
  });
  const json = await res.json();
  if (json.error) throw new Error(json.error.message || "RPC error");
  return json.result;
}

const streakCall = (sel, addr) => rpcCall(STREAK_ID_ADDRESS, sel + encAddress(addr));
const streakUint = async (sel, addr) => decUint(await streakCall(sel, addr));

// ---------------- DOM ------------------------------------------------
const $ = (id) => document.getElementById(id);
const connectBtn = $("connectBtn");
const walletInfo = $("walletInfo");
const agentIdInfo = $("agentIdInfo");
const statsCard = $("statsCard");
const checkInBtn = $("checkInBtn");
const nextInfo = $("nextInfo");
const txInfo = $("txInfo");

let account = null;
let countdownTimer = null;

$("contractLink").href = "https://bscscan.com/address/" + STREAK_ID_ADDRESS;

// ---------------- wallet ---------------------------------------------
async function connectWallet() {
  if (!window.ethereum) {
    walletInfo.textContent =
      "No browser wallet found. Install a BNB Chain wallet (e.g. Binance Wallet or MetaMask), or use the wallet's built-in browser.";
    return;
  }
  try {
    const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
    account = accounts[0];
    const chainId = await window.ethereum.request({ method: "eth_chainId" });
    if (parseInt(chainId, 16) !== BSC_CHAIN_ID) {
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x38" }],
        });
      } catch (e) {
        walletInfo.textContent = "Please switch your wallet to BNB Chain (chain id 56) and reconnect.";
        return;
      }
    }
    connectBtn.textContent = shortAddr(account);
    walletInfo.innerHTML = "Connected wallet: <span class='mono'>" + account + "</span>";
    await refreshUser();
  } catch (e) {
    walletInfo.textContent = "Connection rejected in the wallet.";
  }
}

if (window.ethereum) {
  window.ethereum.on("accountsChanged", () => location.reload());
  window.ethereum.on("chainChanged", () => location.reload());
}
connectBtn.addEventListener("click", connectWallet);

// ---------------- user state -------------------------------------------
async function refreshUser() {
  if (!account) return;
  const holds = decUint(await rpcCall(AGENT_ID_REGISTRY, SEL.registryBalanceOf + encAddress(account))) > 0n;
  agentIdInfo.innerHTML = holds
    ? "<span class='pill ok'>Agent ID holder ✓</span> Your wallet holds an Agent ID, so you can check in."
    : "<span class='pill no'>No Agent ID</span> This wallet does not hold an Agent ID. Agent IDs are claimed for free inside the Binance app (Wallet → Agent ID banner).";
  statsCard.hidden = false;

  const [streak, best, total, points, mask, canToday, nextAt] = await Promise.all([
    streakUint(SEL.streakOf, account),
    streakUint(SEL.bestStreakOf, account),
    streakUint(SEL.totalCheckInsOf, account),
    streakUint(SEL.pointsOf, account),
    streakUint(SEL.badgeMaskOf, account),
    streakUint(SEL.canCheckInToday, account),
    streakUint(SEL.nextCheckInAt, account),
  ]);
  $("statStreak").textContent = streak.toString();
  $("statBest").textContent = best.toString();
  $("statTotal").textContent = total.toString();
  $("statPoints").textContent = points.toString();

  document.querySelectorAll(".badge").forEach((el) => {
    const tier = Number(el.dataset.tier);
    el.classList.toggle("earned", (Number(mask) & (1 << tier)) !== 0);
  });

  const can = holds && canToday === 1n;
  checkInBtn.disabled = !can;
  checkInBtn.textContent = !holds
    ? "Agent ID required"
    : canToday === 1n
      ? "Check in today"
      : "Already checked in today ✓";

  clearInterval(countdownTimer);
  if (holds && canToday === 0n && nextAt > 0n) {
    const target = Number(nextAt) * 1000;
    const tick = () => {
      const left = Math.max(0, target - Date.now());
      const h = Math.floor(left / 3600000), m = Math.floor((left % 3600000) / 60000), s = Math.floor((left % 60000) / 1000);
      nextInfo.textContent = `Next check-in in ${h}h ${m}m ${s}s (UTC day rollover)`;
      if (left === 0) { clearInterval(countdownTimer); refreshUser(); }
    };
    tick();
    countdownTimer = setInterval(tick, 1000);
  } else {
    nextInfo.textContent = "";
  }
}

checkInBtn.addEventListener("click", async () => {
  if (!account || !window.ethereum) return;
  txInfo.textContent = "Waiting for you to confirm the transaction in your wallet…";
  try {
    const txHash = await window.ethereum.request({
      method: "eth_sendTransaction",
      params: [{ from: account, to: STREAK_ID_ADDRESS, data: SEL.checkIn }],
    });
    txInfo.innerHTML = "Check-in sent: <a href='https://bscscan.com/tx/" + txHash + "' target='_blank' rel='noopener'>" + txHash.slice(0, 18) + "…</a> — refreshing your stats in a few seconds…";
    setTimeout(async () => { await refreshUser(); await loadBoard(); }, 6000);
  } catch (e) {
    txInfo.textContent = "Transaction cancelled or rejected in the wallet. Nothing was sent.";
  }
});

// ---------------- leaderboard ------------------------------------------
async function loadBoard() {
  const tbody = document.querySelector("#board tbody");
  try {
    const total = decUint(await rpcCall(STREAK_ID_ADDRESS, SEL.totalAgents));
    $("totalAgents").textContent = total.toString();
    if (total === 0n) {
      tbody.innerHTML = "<tr><td colspan='6' class='muted'>No check-ins yet — be the first Agent ID holder on the board.</td></tr>";
      return;
    }
    const limit = total > BigInt(LEADERBOARD_LIMIT) ? LEADERBOARD_LIMIT : Number(total);
    const raw = await rpcCall(STREAK_ID_ADDRESS, SEL.getAgents + encUint(0) + encUint(limit));
    // Decode address[]: word0 = offset, word1 = length, then elements.
    const words = raw.replace(/^0x/, "").match(/.{64}/g) || [];
    const len = Number(BigInt("0x" + words[1]));
    const addrs = [];
    for (let i = 0; i < len; i++) addrs.push("0x" + words[2 + i].slice(24));

    const rows = await Promise.all(addrs.map(async (a) => {
      const [streak, totalCi, points, mask] = await Promise.all([
        streakUint(SEL.streakOf, a),
        streakUint(SEL.totalCheckInsOf, a),
        streakUint(SEL.pointsOf, a),
        streakUint(SEL.badgeMaskOf, a),
      ]);
      return { a, streak, totalCi, points, mask: Number(mask) };
    }));
    rows.sort((x, y) =>
      y.streak !== x.streak ? Number(y.streak - x.streak)
      : y.points !== x.points ? Number(y.points - x.points)
      : Number(y.totalCi - x.totalCi));

    const badgeIcons = ["🥉", "🥈", "🥇", "💎"];
    tbody.innerHTML = rows.map((r, i) => {
      const badges = badgeIcons.filter((_, t) => (r.mask & (1 << t)) !== 0).join(" ") || "—";
      const me = account && r.a.toLowerCase() === account.toLowerCase() ? " (you)" : "";
      return `<tr><td>${i + 1}</td><td class="mono">${shortAddr(r.a)}${me}</td><td>${r.streak}</td><td>${r.totalCi}</td><td>${r.points}</td><td>${badges}</td></tr>`;
    }).join("");
  } catch (e) {
    tbody.innerHTML = "<tr><td colspan='6' class='muted'>Could not load the leaderboard (the contract may not be deployed yet).</td></tr>";
    $("totalAgents").textContent = "–";
  }
}
$("refreshBoard").addEventListener("click", loadBoard);
loadBoard();
