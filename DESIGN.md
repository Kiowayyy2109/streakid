# StreakID — DESIGN & Phase-1 Report

Date: 2026-11-18 (WIB) · Phase 1: design + code + local tests + site + submission draft.
No mainnet deployment, no spend. Everything below is measured, not estimated from formulas.

---

## 1. Final design

**Name: StreakID** (kept from the working name).
Brand check: the name contains no "Binance"/"BNB" element and does not
imitate any official brand — it is a generic compound of "streak" + "ID".
Domain plan: `kiowayyy2109.github.io/streakid` (GitHub Pages, free) — also
brand-clean. Badge NFT name "StreakID Badge", symbol `STREAK`.

**Product:** daily check-in dApp exclusively for Agent ID holders (BNB Chain).

**Contract:** one dependency-free Solidity 0.8.26 contract, `contracts/StreakID.sol`.

- Gate: `checkIn()` calls `balanceOf(msg.sender)` on the immutable SPACE ID
  Agent ID registry; non-holders revert (`NotAgentIdHolder`).
- Cadence: one check-in per address per **UTC day** (`block.timestamp / 86400`).
  Consecutive day → streak +1; gap ≥ 1 missed day → streak restarts at 1
  (live `streakOf` already reads 0 once the streak is dead).
- Points: +10 per check-in; milestone bonuses +20 / +50 / +150 / +400.
  Points are a plain counter — non-transferable, not a token, no value claims.
- Badges: **full ERC-721 read surface** (`balanceOf`, `ownerOf`, `tokenURI`,
  `supportsInterface` 0x80ac58cd/0x5b5e139f/ERC-165) with **all transfer and
  approval entry points reverting** (`Soulbound`). Token id encodes
  (owner, tier): `(uint160(user) << 8) | tier`, tiers = 3/7/14/30-day streaks.
  Ownership is derived from a 4-bit mask — no per-token storage.
- User state is packed into **one storage slot** (232/256 bits: lastDay,
  lastTs, streak, bestStreak, totalCheckIns, points, badgeMask).
- Community views for the site: `totalAgents()` (unique check-in addresses),
  `getAgents(offset, limit)` (first-check-in order, for the leaderboard).
- **Owner permissions: none.** No owner/admin, no pause, no mint function,
  no withdraw, no proxy/upgrade, cannot receive BNB (plain transfer reverts).
  Only construction-time immutables: registry address + badge base URI.

**Registry address verification (programmatic, per workspace rule):**
announcement text (lowercase) `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`
→ computed EIP-55 checksum `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` —
matches the value used in code/docs. On-chain sanity: `name()` = "SPACE ID
Agent ID", `symbol()` = "AI", and `balanceOf(Panji's Agentic Wallet)` = **1**
(he holds kiowayyy.ai, so the Phase-2 test check-in can come from the
deploying wallet itself).

## 2. Test results (Foundry, solc 0.8.26, optimizer runs = 200)

**19 / 19 tests PASS** (`forge test`, suite `test/StreakID.t.sol`):

| Area | Tests | Result |
|---|---|---|
| Gate | non-holder rejected; rejected after losing Agent ID; `hasAgentId` view | ✅ |
| Cadence | first check-in state; same-day second check-in reverts (also later same day) | ✅ |
| Streaks | increments on consecutive days; breaks after a missed day; best-streak kept; live streak reads 0 when dead | ✅ |
| Community | `totalAgents` counts unique users once; `getAgents` pagination | ✅ |
| Badges | minted at day 3; all 4 tiers by day 30 (points total 920 = 30×10 + 620 bonuses); no double-mint after streak restart; `ownerOf` unminted reverts; `tokenURI` format | ✅ |
| Soulbound | `transferFrom`, both `safeTransferFrom`, `approve`, `setApprovalForAll` all revert; approvals read as none | ✅ |
| ERC-165 | 0x01ffc9a7 / 0x80ac58cd / 0x5b5e139f true, 0xffffffff false | ✅ |
| Events | `CheckIn`, `BadgeEarned`, `Transfer` (mint) emitted with expected args | ✅ |
| Safety | plain BNB transfer to contract reverts; zero-registry constructor reverts | ✅ |

One test initially failed due to a test-side off-by-one (a streak is still
alive on the day after the last check-in — that day is the save day; it
breaks only after a full missed day). Contract logic was correct; the test
was fixed to assert the intended semantics.

## 3. Gas — measured, and the budget verdict

Toolchain measurements (optimizer runs = 200 — runs = 1,000,000 was also
measured and is *worse*: 1,604,070 gas / 6,903 bytes, so 200 is canonical):

| Measurement | Gas |
|---|---|
| Deploy, CREATE level (test, `gasleft()` delta) | 1,279,082 |
| **Deploy, real transaction (anvil simulation, tx receipt `gasUsed`)** | **1,285,410** |
| Runtime code size | 5,335 bytes (creation bytecode 6,035 B; code deposit alone 1,067,000) |
| First-ever check-in (incl. leaderboard array push) | 108,028 (call level) |
| Returning-user check-in | 44,725 (call level) |

Budget math (deployer = Panji's Agentic Wallet, balance measured on-chain
2026-11-18: **0.0003784532 BNB** = 378,453,156,715,494 wei; live BSC gas
price measured via RPC: **0.05 gwei** = 50,000,000 wei):

| Scenario | Deploy tx | + first check-in tx (≈129,228 incl. intrinsic) | Total BNB | Fits 0.000378 BNB? |
|---|---|---|---|---|
| 0.05 gwei (live) | 1,285,410 gas → 0.0000643 BNB | ≈ 1,414,638 gas total | **≈ 0.0000707 BNB** | ✅ Yes — uses ~19% of balance, margin ≈ 0.000308 BNB |
| 0.2 gwei (4× spike) | 0.0002571 BNB | ≈ 1,414,638 gas total | **≈ 0.0002829 BNB** | ✅ Yes — uses ~75% of balance, margin ≈ 0.000096 BNB (≈ 477k gas headroom) |

**Verdict: the full ERC-721 soulbound badge design FITS the existing
balance at the live gas price AND at a 4× gas-price spike. No top-up is
needed, and no feature had to be cut.** The fallback (badges as records +
events only, ≈ 0.5–0.7M gas deploy) was therefore *not* adopted — it would
have saved gas that is not needed, at the cost of wallet/explorer badge
visibility. Trade-off consciously taken: deploy consumes ~1.29M gas
instead of ~0.6M, in exchange for real ERC-721 badges that display in
wallets and on BscScan — affordable in both scenarios above.

Operational note for Phase 2: deploy when BSC gas is at its usual
0.05 gwei; if the price is elevated, the plan still fits up to ≈ 0.26 gwei
for deploy + first check-in combined.

## 4. Website

`site/` — static, no build step, GitHub-Pages-ready:
`index.html`, `style.css`, `app.js` (vanilla JS, zero dependencies),
`badges/{3,7,14,30}.json` + `badge-*.svg` metadata/art for tokenURI.

- Generic injected-wallet connect (`window.ethereum`), auto chain-switch
  to BSC (56). **No QR/pairing login, no server, no sessions.**
- The user always confirms the check-in transaction in their own wallet.
- Reads via public BSC RPC — leaderboard and stats work without a wallet.
- Shows: Agent ID holder status, streak/best/total/points, badge row,
  next-check-in countdown, community counter, leaderboard (address +
  streak + check-ins + points + badges) read from `getAgents` +
  per-user views. No name→wallet lookup feature.
- The contract address is a single constant (`STREAK_ID_ADDRESS`) at the
  top of `app.js`, currently the zero address placeholder — set once after
  deployment. Function selectors in `app.js` were cross-checked against
  the compiled artifact's method identifiers (12/12 match).
- `app.js` syntax-validated with Node; badge JSON validated.

## 5. Submission path (researched)

- Announcement requirement: submit project name, website, contract
  address(es), Agent ID usage description + other materials during
  2026-11-18 08:00 UTC → **2026-12-09 08:00 UTC (15:00 WIB)**, "no
  registration needed". One project per team. Rewards are sent to the
  **reward receiving address provided during submission** (T&Cs).
- The only submission link in the official announcement is the **campaign
  survey**: `https://app.binance.com/uni-qr/user-survey/ff6832f8d2984af289068c9450a3c98c`
  — a Binance **in-app** survey (web shows a QR code). ⇒ The final submit
  step must be done **by Panji himself in the Binance app with his
  account**; the exact in-survey field list is only visible there.
  All answers are pre-written in `SUBMISSION_DRAFT.md` so the form takes
  minutes. (The same survey link is also cited in the announcement for the
  X-post Promotion Award; whether project submission uses this exact
  survey or a sibling form must be confirmed in-app at submit time —
  the prepared materials cover every field the announcement names.)
- X/Twitter promotion award: **not usable** (Panji's X account is
  suspended) and out of scope.

## 6. Phase 2 — steps waiting on Panji / execution order

1. **Panji: no top-up needed.** Balance suffices (see §3). Deployment uses
   his Agentic Wallet via BAW — needs his usual deploy confirmation tap
   when the moment comes (value 0 besides gas; preview first, per house rules).
2. Create public GitHub repo `Kiowayyy2109/streakid`, push this code,
   enable GitHub Pages on `site/`. (Deliberately not done in Phase 1:
   publishing is a Phase-2 step; everything is committed locally.)
3. Deploy `StreakID` to BSC mainnet with constructor args
   `(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F, "https://kiowayyy2109.github.io/streakid/badges/")`.
4. Verify source on BscScan (forge verify-contract; exact command in README).
5. Set `STREAK_ID_ADDRESS` in `site/app.js`, republish Pages.
6. First real check-in from Panji's Agentic Wallet (kiowayyy.ai) — proves
   the gate end-to-end (est. ≈ 0.0000065 BNB at live gas price).
7. **Panji submits** via the Binance app survey using SUBMISSION_DRAFT.md
   (reward address = his Agentic Wallet 0x5892606Efb9D8cAd0dDd7CFBD37e1e4C842CaCD4).
8. Community drive before 2026-12-09 15:00 WIB: **≥ 30 unique Agent ID
   addresses** must check in (Innovation Award eligibility; also the
   Pioneer/growth ranking metric). Owner action: share the site link in
   his Agent ID communities; each holder's check-in costs them only gas.
