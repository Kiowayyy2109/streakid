// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Test-only stand-in for the SPACE ID Agent ID registry.
///         NOT deployed to mainnet. Lets tests control who "holds"
///         an Agent ID via an explicit allow-list.
contract MockAgentID {
    mapping(address => uint256) internal _balances;

    function setHolder(address user, bool holds) external {
        _balances[user] = holds ? 1 : 0;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }
}
