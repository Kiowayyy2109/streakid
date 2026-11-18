// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {StreakID} from "../contracts/StreakID.sol";

/// @notice Deployment script (used for the Phase-1 local simulation and,
///         in Phase 2, for the real BNB Chain mainnet deployment).
///         The Agent ID registry address below is the SPACE ID Agent ID
///         contract on BNB Chain mainnet, as published in the official
///         Binance Agent ID Hackathon announcement. It is asserted
///         programmatically against the announcement value in DESIGN.md.
contract Deploy is Script {
    address internal constant AGENT_ID_MAINNET = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    string internal constant BADGE_BASE_URI = "https://kiowayyy2109.github.io/streakid/badges/";

    function run() external returns (StreakID deployed) {
        vm.startBroadcast();
        deployed = new StreakID(AGENT_ID_MAINNET, BADGE_BASE_URI);
        vm.stopBroadcast();
    }
}
