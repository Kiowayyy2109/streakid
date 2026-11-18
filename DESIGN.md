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

---

## 7. Phase 2a — repo + Pages live; deploy path audited (2026-11-18 ~18:42–19:00 WIB)

No deployment, no spend, no transaction executed in this phase.

### GitHub repo (public)
- **https://github.com/Kiowayyy2109/streakid** — created via the
  custom.github connector (PAT, scope `repo`), pushed with the Git Data API.
- Contents: `contracts/`, `test/`, `script/`, `site/`, `docs/` (Pages copy
  of `site/`), `verification/`, README, LICENSE, DESIGN.md,
  SUBMISSION_DRAFT.md, foundry.toml. `lib/forge-std` is a standard public
  dependency and stays git-ignored (same hygiene as the local repo);
  StreakID itself has zero imports, so verification does not need it.
- Push commits: `1933b07` (initial), `66a53a0` (site files briefly landed
  at repo root — superseded), `1fd4ac5` (moved the published copy into
  `docs/`, removed the root copies).

### GitHub Pages (live)
- The Pages API only accepts publishing paths `/` or `/docs` (a `/site`
  source is rejected with 422), so Pages serves branch `main`, path
  `/docs`. The local canonical source remains `site/`; **after deployment,
  update `STREAK_ID_ADDRESS` in `site/app.js` and re-copy `site/` →
  `docs/` before re-pushing.**
- **Live at https://kiowayyy2109.github.io/streakid/** — verified HTTP 200
  (page title/content "StreakID" present) and
  `https://kiowayyy2109.github.io/streakid/badges/3.json` HTTP 200, so the
  constructor badge base URI resolves exactly as deployed later.
- The served `app.js` still carries the zero-address placeholder
  (`STREAK_ID_ADDRESS = 0x0000…0000`) — nothing points at a contract yet.

### BscScan verification files (in `verification/`)
- `StreakID.standard-input.json` — the exact Foundry compiler input
  (solc 0.8.26+commit.8a97fa7a, optimizer 200 runs, evm cancun), cleaned
  only of Foundry-only keys (`allowPaths`/`basePath`/`includePaths`).
  **Proven in this phase: recompiling this file with solc 0.8.26
  reproduces the Phase-1 creation bytecode byte-for-byte, including the
  metadata hash (full match).** (A hand-built minimal input differed in
  the metadata trailer only — do not use a hand-built input.)
- `StreakID.flattened.sol` (reference), `constructor-args.txt`
  (ABI-encoded `(registry, baseURI)` — registry word asserted equal to
  the announcement address programmatically), `init-code.txt`
  (creation bytecode + constructor args = 6,195 bytes), `README.md`
  with both verification routes. Command route (from README):
  `forge verify-contract <ADDR> contracts/StreakID.sol:StreakID --chain bsc --constructor-args <from constructor-args.txt>`.

### Deploy path via BAW — AUDITED: native creation is NOT possible
- Preconditions are fine: BAW session logged in; Developer Mode enabled
  (expires 2026-11-25 16:23 WIB); dev-mode daily quota untouched.
- `baw contract-call preview` **requires `--to` for EVM** — omitting it
  fails with `SERVICE_ERROR "to is required for EVM contract-call"`.
  A contract-creation transaction needs an empty `to`, so the CLI cannot
  express one.
- Tested the only remaining shape: preview with
  `--to 0x0000000000000000000000000000000000000000` and the full init code
  as `--inputData` (requestId `835fdf7129ec488b843de6bd218fb29a`, expired
  2026-11-18 18:52 WIB, **never executed**). BAW parsed it as a plain
  `ContractInteraction` **call to the zero address** (action shown as the
  init code's first 4 bytes, `gasLimit: null`, trivial simulation pass).
  Executing that preview would send calldata to `0x0` and **deploy
  nothing** — do not use it in Phase 2b.
- No other deploy facility exists in the BAW skill/CLI surface.

### Recommended deploy routes for Phase 2b (Panji chooses + taps)
- **Route B (keeps everything inside BAW):** deploy through the canonical
  CREATE2 factory `0x4e59b44847b379578588920cA78FbF26c0B4956C` (Arachnid
  deterministic deployment proxy — code presence on BSC verified
  read-only in this phase, 69 bytes runtime). One BAW contract-call:
  `to` = factory, `inputData` = `<32-byte salt><init code>`, value 0 —
  a normal contract call, so the usual preview → Panji tap → execute
  flow applies. Contract address = CREATE2 address derived from
  factory + salt + init-code hash (computable and assertable in code
  before broadcasting). Deployer of record is the factory; StreakID has
  no owner, so nothing depends on deployer identity. Gas ≈ deploy
  (1,285,410) + factory overhead — still ≈ 0.00007 BNB at the live
  0.05 gwei price, well inside the Agentic balance (0.0003784532 BNB,
  re-read this phase; gas price still 0.05 gwei).
- **Route A (classic):** a dedicated project EOA whose key is generated
  locally at deploy time (file mode 600, never printed). Panji funds it
  with ≈ 0.0001 BNB via one ordinary BAW `wallet send` (his tap), then
  deployment runs from that EOA with forge/cast. After deployment the
  key controls nothing (the contract has no owner) and the EOA is
  retired. Downside vs B: one extra funding transaction and a key file
  to safeguard until deployment completes.
- Route B is recommended: no new key, no funding hop, and every step
  stays inside the preview + tap discipline Panji already uses.

### What exactly waits on Panji
1. **Choose the deploy route (B recommended, or A)** and give the deploy
   tap when the Phase-2b preview is shown. Nothing else about the deploy
   needs him.
2. After deployment + BscScan verification + site address update: the
   **first check-in tap** from his Agentic Wallet (proves the gate;
   ≈ 0.0000065 BNB).
3. The **in-app Binance survey submission** (SUBMISSION_DRAFT.md) —
   unchanged, only he can do it.
4. Community drive to ≥ 30 unique Agent ID check-ins before
   2026-12-09 15:00 WIB — unchanged.

---

## 8. Phase 2b — Route B chosen; CREATE2 deploy preview prepared (2026-11-18 ~18:54 WIB)

Panji chose **Route B**. Preview only in this phase — **nothing was
executed, no transaction sent.**

### Salt & calldata (deterministic, reproducible)
- Salt string: `StreakID v1 kiowayyy` (UTF-8).
- **Salt = keccak256("StreakID v1 kiowayyy") =
  `0x6274da33870be9a51a521ff4bf4f6ef6c4ff6677717dac88f16089d51e3eccbb`**
- Calldata = salt (32 B) ‖ init code taken **only** from
  `verification/init-code.txt` (6,195 B) → 6,227 B total.
- Programmatic assertions (all passed): init code ends exactly with
  `verification/constructor-args.txt`; the registry word inside those
  args equals the announcement address
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`; string-arg offset = 0x40.
- Init-code keccak256:
  `0xc29847a142a32c80c264632421bd6e7db3d57c90d86a984b4ee32ccee46cd583`.

### The contract address that will be born
- **CREATE2 address: `0x6E477bffF71313805a5BE07F2Bf735e041FD7f0b`**
  (= keccak256(0xff ‖ factory ‖ salt ‖ keccak256(init code))[12:]).

### Read-only on-chain checks + simulation (BSC RPC)
- Factory `0x4e59b44847b379578588920cA78FbF26c0B4956C` code = **69 bytes**
  on BSC ✓ (canonical Arachnid proxy).
- Target address code = `0x` — **still empty**, nothing deployed there ✓.
- `eth_call` to the factory from Panji's Agentic Wallet
  (`0x5892606Efb9D8cAd0dDd7CFBD37e1e4C842CaCD4`) with the exact calldata:
  **no revert, and the proxy returned exactly
  `0x6E477bffF71313805a5BE07F2Bf735e041FD7f0b`** — the simulated deploy
  lands at the computed address ✓.
- `eth_estimateGas` = **1,311,191 gas** (direct CREATE measured 1,285,410
  in Phase 1; factory overhead ≈ 25,781). At the live 0.05 gwei price →
  **final estimated cost ≈ 0.00006556 BNB**; Agentic balance re-read
  0.0003784532 BNB — fits with ≈ 0.000313 BNB margin.

### BAW preview (prepared, NOT executed)
- Command shape: `baw contract-call preview --binanceChainId 56
  --from 0x5892606Efb9D8cAd0dDd7CFBD37e1e4C842CaCD4
  --to 0x4e59b44847b379578588920cA78FbF26c0B4956C --value 0
  --inputData <salt‖init code> --json`. Dev Mode confirmed enabled
  (expires 2026-11-25), session CONNECTED.
- **requestId: `c705f3e5a1344b728928560529383038`**
- **Expires: 2026-11-18 18:59:54 WIB** (preview lifetime is only ≈ 5
  minutes — at execute time, re-run this preview immediately before
  Panji's tap and execute with the fresh requestId).
- Parsed result, verified programmatically (11/11 checks passed):
  `transactionType = ContractInteraction`, `contractAddress` = factory,
  `action = 0x6274da33` (= first 4 bytes of the salt — expected: the
  proxy takes raw salt‖init-code calldata, no function selector),
  simulationCode `000000000` with no error, `gasTokenFromData = 0`,
  balanceChanges / allowanceChanges / authorityChanges all empty,
  risks all empty, `requireConfirmation = false`, `gasLimit = null`
  (backend-estimated).

### Next (waits on Panji's tap)
1. Fresh preview (same parameters) → show Panji → his tap → `baw
   contract-call execute --requestId <fresh>` → contract lives at
   `0x6E477bffF71313805a5BE07F2Bf735e041FD7f0b`.
2. BscScan verification (files in `verification/`), set
   `STREAK_ID_ADDRESS` in `site/app.js`, re-copy `site/` → `docs/`, push.
3. First check-in tap from Panji's Agentic Wallet; then his in-app
   survey submission; then the ≥ 30 Agent ID community drive.

## 9. Phase 2c — DEPLOYED to BSC mainnet (2026-11-18 ~19:01–19:10 WIB)

Panji approved execution ("Gas, execute deploy sekarang", 18:59 WIB).
Exactly **one** execute was performed.

### Fresh preview (re-run immediately before execute)
- Same parameters as §8 (factory `0x4e59b44847b379578588920cA78FbF26c0B4956C`,
  calldata = salt `0x6274da33…eccbb` ‖ init code from
  `verification/init-code.txt`, value 0, from Agentic Wallet
  `0x5892606Efb9D8cAd0dDd7CFBD37e1e4C842CaCD4`). Dev Mode re-confirmed
  enabled (expires 2026-11-25).
- **requestId: `31a11796213e4623a0925ac7cc1d3143`** (the §8 preview
  `c705f3e5…` had expired and was NOT used).
- Programmatic verification of the fresh preview (10/10 passed):
  `transactionType = ContractInteraction`, `contractAddress` = factory,
  `action = 0x6274da33`, `gasTokenFromData = 0`, simulationCode
  `000000000` with no error, balanceChanges / allowanceChanges /
  authorityChanges all empty, risks all empty,
  `requireConfirmation = false`.

### Execute result
- `baw contract-call execute --requestId 31a11796213e4623a0925ac7cc1d3143`
  → orderId `26111800002063168777`, status `BROADCASTED`.
- **Tx hash: `0x48edb32d4a54c1f9d4b103cae811395925e1d9efe2eb9745686c284b79ef5a5f`**
- **Block: 134307672**, receipt status `0x1` (success).
- **gasUsed: 1,288,404**; gasPrice ≈ 0.15747 gwei (backend-set, above
  the 0.05 gwei spot seen earlier); **actual cost: 0.0002028842 BNB**.
- Agentic BNB balance after: **0.0001755690 BNB**
  (0.0003784532 − 0.0002028842 = 0.0001755690 ✓).

### Post-deploy on-chain verification (all passed)
- Contract lives at exactly the computed CREATE2 address:
  **`0x6E477bffF71313805a5BE07F2Bf735e041FD7f0b`** ✓
- Runtime code = **5,335 bytes**; byte-for-byte equal to the Foundry
  artifact's deployedBytecode once the `AGENT_ID` immutable is patched
  in (exactly 3 × 20-byte ranges — 1175–1194, 1580–1599, 2584–2603 —
  hold the registry address on-chain vs. zeros in the artifact;
  metadata tail identical) ✓
- `AGENT_ID()` getter → `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` ✓
- `name()` = "StreakID Badge", `symbol()` = "STREAK" ✓

### Source verification status
- The README command (`forge verify-contract … --chain bsc
  --constructor-args <constructor-args.txt>`) was run as-is. With no
  Etherscan/BscScan API key in the environment, forge routed it to
  **Sourcify**, which answered **"Contract source code already fully
  verified"** (after one timeout retry and one HTTP 429 during
  retries; no further requests were made to Sourcify after that).
  → Source is **fully verified on Sourcify (full match)**.
- **BscScan-side verification is NOT yet confirmed**: no BscScan API
  key is available in this environment and the public BscScan page
  fetch was rejected (HTTP 403). The standard-input JSON route in
  `verification/` remains ready for the manual BscScan step
  (submit `StreakID.standard-input.json` + constructor args
  `00000000000000000000000060b9262456de011f7d15a54cdd8c48baaa8b022f…`
  from `constructor-args.txt`).

### Remaining (unchanged from §8)
1. Set `STREAK_ID_ADDRESS` in `site/app.js` to the deployed address,
   re-copy `site/` → `docs/`, push (site currently still placeholder).
2. First real check-in from Panji's Agentic Wallet (his tap).
3. Panji submits the in-app Binance survey (SUBMISSION_DRAFT.md now
   carries the final contract address).
4. Community drive: ≥ 30 unique Agent ID addresses check in before
   2026-12-09 15:00 WIB.
