# StreakID — Agent ID Hackathon submission draft (Phase 1, NOT submitted)

Prepared 2026-11-18. Everything below is ready to paste into the official
submission channel once the contract is deployed and verified (Phase 2).

## Submission channel (researched 2026-11-18)

- The hackathon announcement (Binance support, 2026-11-18) says projects
  submit "project name, website, contract address(es), Agent ID usage
  description, and other required materials" during the Submission Period
  (2026-11-18 08:00 UTC → 2026-12-09 08:00 UTC) and that "no registration
  is needed".
- The only submission link embedded in the official announcement is the
  **official campaign survey**:
  `https://app.binance.com/uni-qr/user-survey/ff6832f8d2984af289068c9450a3c98c`
  It is a Binance **in-app** survey (the web URL shows a QR code: "Scan to
  Download App"). Consequences:
  - The final submission step must be completed **by Panji inside the
    Binance app, logged in with his own Binance account**. It cannot be
    delegated to an agent session.
  - The exact field list inside the survey is only visible inside the app.
    The announcement names the core fields (project name, website,
    contract address(es), Agent ID usage description, plus "other required
    materials"); the T&Cs add that rewards are sent to "the reward
    receiving address provided during project submission", so a reward
    address field must be expected.
  - Action for Phase 2: Panji opens the survey in the app; every answer is
    prepared below so the form can be completed in minutes.

## Prepared answers

**Project name**
> StreakID

**Team type**
> Individual — Panji Nugraha, Agent ID **kiowayyy.ai**

**Website** (after Phase-2 GitHub Pages publish)
> https://kiowayyy2109.github.io/streakid/

**Smart contract address(es)** (after Phase-2 deploy + BscScan verification)
> StreakID (BNB Chain mainnet): `0x6E477bffF71313805a5BE07F2Bf735e041FD7f0b`
> BscScan: `https://bscscan.com/address/0x6E477bffF71313805a5BE07F2Bf735e041FD7f0b` (source fully verified on Sourcify; BscScan verification via standard-input JSON prepared, MIT)

**Open-source repository**
> https://github.com/Kiowayyy2109/streakid (to be created/pushed in Phase 2)

**Reward receiving address**
> 0x5892606Efb9D8cAd0dDd7CFBD37e1e4C842CaCD4
> (Panji's Agentic Wallet — the wallet that holds his Agent ID kiowayyy.ai)

**Short description (one line)**
> StreakID is a daily check-in dApp exclusively for Agent ID holders on BNB Chain: check in every day, build your streak, and earn soulbound milestone badges that prove your agent identity shows up.

**Long description**
> Agent IDs give every AI agent a name — but a name alone says nothing about whether an agent is actually alive, active, and persistent. StreakID turns the Agent ID into a living reputation signal.
>
> Once per UTC day, an Agent ID holder checks in with one tap. The StreakID smart contract verifies Agent ID ownership directly against the official SPACE ID Agent ID registry on BNB Chain — no Agent ID, no check-in; the rule lives in the contract, not in a server. Consecutive days build a streak; miss a day and it restarts. At 3, 7, 14 and 30 days, the contract mints a soulbound ERC-721 badge that can never be transferred or sold, together with non-transferable reputation points.
>
> Because an Agent ID is one-per-person and non-transferable, a 30-day streak is Sybil-resistant evidence of a persistent agent identity — the kind of signal other dApps can build on: any contract or service can read streakOf / pointsOf / hasBadgeTier to recognise established agents.
>
> StreakID is deliberately safe by design: a single dependency-free contract with no owner, no admin functions, no pause, no approvals, and no ability to receive or move user funds. The website is fully static, connects through the visitor's own wallet (no QR logins, no server sessions), and every action is a transaction the user reviews and confirms themselves. Points and badges are reputation records only — they are not tokens, cannot be traded, and have no monetary value.

**Agent ID usage description (the key field)**
> Agent ID is the core access-control and identity layer of StreakID:
> 1. Gate: the contract immutably stores the official SPACE ID Agent ID registry (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F, BNB Chain) and calls balanceOf(msg.sender) on it inside every checkIn(). Only Agent ID holders can participate — enforced on-chain.
> 2. Identity binding: streaks, points and soulbound badges are bound to the same wallet that holds the Agent ID, so an agent's .ai identity accumulates a public, non-transferable track record.
> 3. Composability: public view functions (streakOf, pointsOf, hasBadgeTier, totalAgents, getAgents) let any other dApp or agent service read Agent ID holders' activity reputation.
> 4. Growth loop: the public leaderboard counts unique interacting Agent ID addresses (totalAgents), which is exactly the ecosystem activity the hackathon wants to drive.

**Category / tags (if asked)**
> Identity, Reputation, Social, Agent Infrastructure

**Demo / screenshots (Phase 2)**
> Live site URL + screenshots of: (1) check-in flow in Binance Wallet, (2) leaderboard, (3) a minted 3-day badge on BscScan. To be captured after deployment.

## Pre-submit checklist (Phase 2)

- [ ] Contract deployed on BNB Chain mainnet (budget confirmed in DESIGN.md)
- [ ] Source verified on BscScan; constructor args match README
- [ ] One real check-in from Panji's Agentic Wallet (kiowayyy.ai) succeeds
- [ ] GitHub repo public (Kiowayyy2109/streakid) with this code + MIT license
- [ ] Site live on GitHub Pages with the real contract address in app.js
- [ ] Survey opened in Binance app by Panji; answers pasted from this file
- [ ] Community drive started: ≥ 30 unique Agent ID addresses check in
      before 2026-12-09 15:00 WIB (Innovation Award eligibility)
