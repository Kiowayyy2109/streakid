# StreakID 🔥

**The daily check-in club for Agent ID holders — on BNB Chain.**

StreakID is a free, single-purpose reputation dApp built for the
[Binance Wallet × BNB Chain Agent ID Hackathon](https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf).
Every day, holders of an **Agent ID** (the `name.ai` on-chain identity of a
Binance Agentic Wallet, issued by SPACE ID) can check in once. Consecutive
days build a **streak**; reaching 3, 7, 14 or 30 days in a row mints a
**soulbound badge** that stays with the wallet forever.

Points and badges are reputation records only. They are not tokens, cannot
be traded or transferred, carry no monetary value, and promise no return
of any kind.

---

## How Agent ID is integrated (core mechanic, not a sticker)

Agent ID is the access key to the whole product:

- The `StreakID` contract stores the official SPACE ID Agent ID registry
  address as an **immutable** and calls `balanceOf(msg.sender)` on it in
  every `checkIn()`. Wallets that do not hold an Agent ID are rejected
  on-chain (`NotAgentIdHolder`) — the rule cannot be bypassed from the
  front-end.
- Agent ID registry (BNB Chain mainnet, from the hackathon announcement):
  **`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`**
  (contract name “SPACE ID Agent ID”, symbol `AI`, ERC-721, non-transferable;
  EIP-55 checksum of the announcement address verified programmatically).
- Because an Agent ID is one-per-person and non-transferable, a streak is
  a Sybil-resistant proof of a *persistent agent identity showing up daily*
  — the foundation for agent reputation: services can read `streakOf`,
  `pointsOf` and `hasBadgeTier` to recognise established agents.

## What the contract does

One contract, `contracts/StreakID.sol` (Solidity 0.8.26, no external
dependencies, hand-rolled and deliberately small — deployed size 5,335
bytes, deploy ≈ 1.29M gas):

| Function | Behaviour |
|---|---|
| `checkIn()` | Agent ID holders only, once per UTC day. Updates streak (missed day → streak restarts at 1), lifetime count, and points (+10 per check-in, plus milestone bonuses 20/50/150/400). |
| Milestone badges | At streaks of 3 / 7 / 14 / 30 days an ERC-721 badge is minted (token id encodes owner + tier). |
| Views | `streakOf`, `bestStreakOf`, `pointsOf`, `totalCheckInsOf`, `lastCheckIn`, `canCheckInToday`, `nextCheckInAt`, `hasBadge`, `badgeMaskOf`, `hasBadgeTier`, `milestoneOf`, `hasAgentId`, `totalAgents`, `getAgents(offset, limit)` for the public leaderboard. |
| Events | `CheckIn(user, streak, totalCheckIns, points)`, `BadgeEarned(user, tokenId, milestoneDays)`, ERC-721 `Transfer` on badge mint. |

## Owner permissions — the complete list

**There are none.** The contract has:

- ❌ no owner / admin role, and no function restricted to a deployer;
- ❌ no pause, no freeze, no blacklist;
- ❌ no mint function callable by anyone (badges mint only inside
  `checkIn()` when a milestone is reached);
- ❌ no withdraw / sweep / rescue function, and it cannot receive BNB
  (plain transfers revert) — user funds can never enter it;
- ❌ no approvals: the contract never asks users to approve anything;
- ❌ no upgradeability / proxy: the code deployed is the code here;
- ✅ one immutable set at construction: the Agent ID registry address,
  and one string set at construction: the badge metadata base URI.
  Neither can be changed after deployment.

The deployer keeps **zero** privileges after deployment.

## Soulbound badges

Badges implement the ERC-721 read surface (`balanceOf`, `ownerOf`,
`tokenURI`, `supportsInterface` for 0x80ac58cd / 0x5b5e139f / ERC-165) so
wallets and explorers can display them, but **every transfer and approval
entry point reverts** with `Soulbound()`:
`transferFrom`, both `safeTransferFrom` overloads, `approve`, and
`setApprovalForAll`. `getApproved` always returns the zero address and
`isApprovedForAll` always returns false.

## Website

`site/` is a fully static page (plain HTML/CSS/JS, no build step, no
server, no analytics):

- Connects with a generic injected wallet (`window.ethereum`) — **no QR /
  pairing-code login, no server-side sessions**. The visitor always
  reviews and confirms the check-in transaction in their own wallet.
- Reads (Agent ID status, stats, leaderboard) go straight to a public
  BNB Chain RPC — the page works read-only without a wallet.
- The leaderboard shows this project's own check-in activity (wallet
  address, streak, points). StreakID does **not** offer any
  name→wallet lookup of other people.

Deploy it anywhere static (GitHub Pages: publish the `site/` folder).

## Build, test, verify

Requires [Foundry](https://getfoundry.sh).

```bash
forge build          # compile (solc 0.8.26, optimizer runs = 200)
forge test           # 19 unit tests: gate, cadence, streak break,
                     # badge milestones, soulbound reverts, gas usage
forge script script/Deploy.s.sol --rpc-url <BSC RPC> --broadcast
```

BscScan verification (after deployment):

```bash
forge verify-contract <DEPLOYED_ADDRESS> contracts/StreakID.sol:StreakID \
  --chain bsc --constructor-args <ABI-encoded registry + base URI>
```

Constructor arguments: `(address agentIdRegistry, string badgeBaseURI)` =
`(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F, "https://kiowayyy2109.github.io/streakid/badges/")`.

## Safety-rule compliance (hackathon red lines)

- No QR / pairing-code sign-in anywhere; no server holds user sessions.
- No prompt or flow bypasses wallet confirmation — every state change is
  a transaction the user signs themselves.
- No unauthorised transfers, no bundled transfers, no hidden approvals.
- Contract fully open-source (this repo, MIT) with owner permissions
  disclosed above (there are none).
- No Binance / BNB branding in the project, token, or domain name.
- No collection of seed phrases, private keys, API secrets, pairing codes.
- No promise of returns anywhere in product or copy; points/badges are
  explicitly valueless reputation records.
- Not a trading product; no name→wallet lookup feature.

## Repository layout

```
contracts/StreakID.sol        the contract (single file, no dependencies)
contracts/mocks/MockAgentID.sol  test-only registry stand-in (never deployed)
test/StreakID.t.sol           Foundry test suite (19 tests)
script/Deploy.s.sol           deployment script
site/                         static website (index.html, app.js, style.css, badges/)
DESIGN.md                     design notes, gas measurements, test results
SUBMISSION_DRAFT.md           prepared hackathon submission materials
```

## License

MIT — see `LICENSE`.
