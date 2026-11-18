# BscScan source verification

Two equivalent routes after deployment. The deployed bytecode was produced
by Foundry (solc 0.8.26, optimizer runs = 200, evm cancun) from commit in
this repo.

## Route A — forge (from the README)

```bash
forge verify-contract <DEPLOYED_ADDRESS> contracts/StreakID.sol:StreakID \
  --chain bsc --constructor-args <see constructor-args.txt, without 0x prefix handling per forge docs>
```

## Route B — BscScan web UI, "Solidity (Standard-Json-Input)"

1. Upload `StreakID.standard-input.json` from this folder. It is the exact
   compiler input Foundry used (compiler 0.8.26+commit.8a97fa7a, optimizer
   200 runs, evm cancun), cleaned of Foundry-only keys; recompiling it with
   solc 0.8.26 reproduces the deployed creation bytecode byte-for-byte
   (verified locally in Phase 2a, including the metadata hash — full match).
2. Constructor arguments: the ABI-encoded value in `constructor-args.txt`
   for `(address agentIdRegistry, string badgeBaseURI)` =
   `(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F, "https://kiowayyy2109.github.io/streakid/badges/")`.

## Files

- `StreakID.standard-input.json` — standard JSON input (full match).
- `StreakID.flattened.sol` — flattened source (reference / alternative
  single-file route; note the flattened file alone does not carry the
  metadata of the original multi-file input).
- `constructor-args.txt` — ABI-encoded constructor arguments (hex).
- `init-code.txt` — full deployment init code (creation bytecode +
  constructor args), exactly what the deployment transaction carries as
  its data payload.
