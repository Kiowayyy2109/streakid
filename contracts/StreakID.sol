// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Minimal read interface for an ERC-721 registry (SPACE ID Agent ID).
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title StreakID — daily check-in for Agent ID holders
/// @notice StreakID is a free, single-purpose reputation dApp on BNB Chain.
///         Only wallets holding an Agent ID (SPACE ID Agent ID NFT, `name.ai`)
///         can check in, once per UTC day. Consecutive days build a streak.
///         Reaching a streak milestone (3 / 7 / 14 / 30 days) mints a
///         soulbound (non-transferable) ERC-721 badge.
///
///         Design guarantees (auditable in this file):
///         - NO owner / admin role exists. Nobody can pause, mint at will,
///           change the registry, or touch user data after deployment.
///         - NO function moves user assets. Check-in costs the caller only
///           their own network gas. The contract never requests approvals
///           and cannot receive or withdraw funds.
///         - Points and badges are reputation records only. They are not
///           financial instruments, carry no monetary value, and promise
///           no return of any kind.
contract StreakID {
    // ------------------------------------------------------------------
    // Constants & immutables
    // ------------------------------------------------------------------

    /// @notice The Agent ID registry this deployment gates on (SPACE ID
    ///         Agent ID on BNB Chain mainnet:
    ///         0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F).
    IAgentIdRegistry public immutable AGENT_ID;

    uint256 internal constant SECONDS_PER_DAY = 86_400;
    uint256 internal constant POINTS_PER_CHECKIN = 10;

    /// @notice Streak lengths (days) that earn a badge tier 0..3.
    uint8 internal constant TIER_COUNT = 4;

    // ------------------------------------------------------------------
    // Badge (ERC-721, soulbound) metadata
    // ------------------------------------------------------------------

    string public constant name = "StreakID Badge";
    string public constant symbol = "STREAK";

    /// @notice Base URI for badge metadata; tokenURI(id) = base + tier + ".json".
    string public badgeBaseURI;

    // ------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------

    /// @dev Packed into a single storage slot (232 of 256 bits used).
    struct UserData {
        uint32 lastDay; // UTC day index of the last check-in
        uint32 lastTs; // unix timestamp of the last check-in
        uint32 streak; // stored streak (see streakOf for the live value)
        uint32 bestStreak; // longest streak ever reached
        uint32 totalCheckIns; // lifetime check-in count
        uint64 points; // reputation points
        uint8 badgeMask; // bit i set => milestone tier i badge minted
    }

    mapping(address => UserData) internal _users;

    /// @dev Every address that has ever checked in (first check-in order).
    address[] internal _agents;

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    event CheckIn(address indexed user, uint256 streak, uint256 totalCheckIns, uint256 points);
    event BadgeEarned(address indexed user, uint256 indexed tokenId, uint256 milestoneDays);

    /// @dev ERC-721 Transfer event, emitted on badge mint (from = address(0)).
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------

    error NotAgentIdHolder();
    error AlreadyCheckedInToday();
    error Soulbound();
    error TokenNotMinted();
    error ZeroAddress();

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------

    /// @param agentIdRegistry Address of the SPACE ID Agent ID ERC-721 contract.
    /// @param badgeBaseURI_ Base URI used by tokenURI for badge metadata.
    constructor(address agentIdRegistry, string memory badgeBaseURI_) {
        if (agentIdRegistry == address(0)) revert ZeroAddress();
        AGENT_ID = IAgentIdRegistry(agentIdRegistry);
        badgeBaseURI = badgeBaseURI_;
    }

    // ------------------------------------------------------------------
    // Core: daily check-in
    // ------------------------------------------------------------------

    /// @notice Check in for today (UTC). Caller must hold an Agent ID.
    ///         One check-in per address per UTC day. A missed day resets
    ///         the streak to 1 on the next check-in.
    function checkIn() external {
        if (AGENT_ID.balanceOf(msg.sender) == 0) revert NotAgentIdHolder();

        uint256 day = block.timestamp / SECONDS_PER_DAY;
        UserData storage u = _users[msg.sender];

        if (u.totalCheckIns != 0 && u.lastDay == day) revert AlreadyCheckedInToday();

        uint256 newStreak;
        if (u.totalCheckIns == 0) {
            _agents.push(msg.sender);
            newStreak = 1;
        } else if (day == uint256(u.lastDay) + 1) {
            newStreak = uint256(u.streak) + 1;
        } else {
            // Same day is handled above, so this is a gap of >= 2 days.
            newStreak = 1;
        }

        uint256 newPoints = uint256(u.points) + POINTS_PER_CHECKIN;

        // Milestone badges: at most one new tier can be reached per day,
        // but the loop keeps the rule obvious and costs little.
        uint8 mask = u.badgeMask;
        for (uint256 i = 0; i < TIER_COUNT; i++) {
            uint8 bit = uint8(1 << i);
            if (mask & bit == 0 && newStreak >= _milestone(i)) {
                mask |= bit;
                newPoints += _bonus(i);
                uint256 tokenId = _tokenId(msg.sender, i);
                emit Transfer(address(0), msg.sender, tokenId);
                emit BadgeEarned(msg.sender, tokenId, _milestone(i));
            }
        }

        u.lastDay = uint32(day);
        u.lastTs = uint32(block.timestamp);
        u.streak = uint32(newStreak);
        if (newStreak > u.bestStreak) u.bestStreak = uint32(newStreak);
        u.totalCheckIns += 1;
        u.points = uint64(newPoints);
        u.badgeMask = mask;

        emit CheckIn(msg.sender, newStreak, u.totalCheckIns, newPoints);
    }

    // ------------------------------------------------------------------
    // Views: identity gate
    // ------------------------------------------------------------------

    /// @notice True if `user` currently holds an Agent ID.
    function hasAgentId(address user) external view returns (bool) {
        return AGENT_ID.balanceOf(user) > 0;
    }

    // ------------------------------------------------------------------
    // Views: user stats
    // ------------------------------------------------------------------

    /// @notice Live streak: the stored streak if it is still alive
    ///         (last check-in was today or yesterday), otherwise 0.
    function streakOf(address user) public view returns (uint256) {
        UserData storage u = _users[user];
        if (u.totalCheckIns == 0) return 0;
        uint256 day = block.timestamp / SECONDS_PER_DAY;
        if (day > uint256(u.lastDay) + 1) return 0;
        return u.streak;
    }

    /// @notice Longest streak the user has ever reached.
    function bestStreakOf(address user) external view returns (uint256) {
        return _users[user].bestStreak;
    }

    /// @notice Reputation points (non-transferable, no monetary value).
    function pointsOf(address user) external view returns (uint256) {
        return _users[user].points;
    }

    /// @notice Lifetime number of check-ins.
    function totalCheckInsOf(address user) external view returns (uint256) {
        return _users[user].totalCheckIns;
    }

    /// @notice Unix timestamp of the user's last check-in (0 if never).
    function lastCheckIn(address user) external view returns (uint256) {
        return _users[user].lastTs;
    }

    /// @notice True if the user can check in right now (ignores the
    ///         Agent ID gate; pair with hasAgentId).
    function canCheckInToday(address user) external view returns (bool) {
        UserData storage u = _users[user];
        if (u.totalCheckIns == 0) return true;
        return u.lastDay != block.timestamp / SECONDS_PER_DAY;
    }

    /// @notice Unix timestamp from which the next check-in is possible
    ///         (0 if the user has never checked in).
    function nextCheckInAt(address user) external view returns (uint256) {
        UserData storage u = _users[user];
        if (u.totalCheckIns == 0) return 0;
        return (uint256(u.lastDay) + 1) * SECONDS_PER_DAY;
    }

    // ------------------------------------------------------------------
    // Views: badges
    // ------------------------------------------------------------------

    /// @notice True if the user holds at least one milestone badge.
    function hasBadge(address user) external view returns (bool) {
        return _users[user].badgeMask != 0;
    }

    /// @notice Bitmask of earned badge tiers (bit i => tier i earned).
    function badgeMaskOf(address user) external view returns (uint8) {
        return _users[user].badgeMask;
    }

    /// @notice True if the user earned the badge for `tier` (0..3 =
    ///         3 / 7 / 14 / 30 day streaks).
    function hasBadgeTier(address user, uint256 tier) external view returns (bool) {
        if (tier >= TIER_COUNT) return false;
        return _users[user].badgeMask & uint8(1 << tier) != 0;
    }

    /// @notice The streak length (days) required for badge `tier`.
    function milestoneOf(uint256 tier) external pure returns (uint256) {
        return _milestone(tier);
    }

    // ------------------------------------------------------------------
    // Views: community
    // ------------------------------------------------------------------

    /// @notice Number of unique addresses that have ever checked in.
    function totalAgents() external view returns (uint256) {
        return _agents.length;
    }

    /// @notice Paginated list of participating addresses (first-check-in
    ///         order), for the public leaderboard on the project website.
    function getAgents(uint256 offset, uint256 limit) external view returns (address[] memory page) {
        uint256 total = _agents.length;
        if (offset >= total) return new address[](0);
        uint256 end = offset + limit;
        if (end > total) end = total;
        page = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = _agents[i];
        }
    }

    // ------------------------------------------------------------------
    // ERC-721 (soulbound): read surface
    // ------------------------------------------------------------------

    /// @notice Number of badges held by `owner` (0..4).
    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _popcount4(_users[owner].badgeMask);
    }

    /// @notice Owner of badge `tokenId`. Token ids encode (user, tier):
    ///         tokenId = (uint160(user) << 8) | tier.
    function ownerOf(uint256 tokenId) public view returns (address) {
        address user = address(uint160(tokenId >> 8));
        uint256 tier = tokenId & 0xff;
        if (tier >= TIER_COUNT) revert TokenNotMinted();
        if (_users[user].badgeMask & uint8(1 << tier) == 0) revert TokenNotMinted();
        return user;
    }

    /// @notice Metadata URI for a minted badge.
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        ownerOf(tokenId); // reverts if not minted
        uint256 milestone = _milestone(tokenId & 0xff);
        return string(abi.encodePacked(badgeBaseURI, _toString(milestone), ".json"));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC-165
            || interfaceId == 0x80ac58cd // ERC-721
            || interfaceId == 0x5b5e139f; // ERC-721 metadata
    }

    /// @notice Soulbound badges are never approved for transfer.
    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    /// @notice Soulbound badges are never approved for transfer.
    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    // ------------------------------------------------------------------
    // ERC-721 (soulbound): every transfer / approval path reverts
    // ------------------------------------------------------------------

    function approve(address, uint256) external pure {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) external pure {
        revert Soulbound();
    }

    function transferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256, bytes memory) external pure {
        revert Soulbound();
    }

    // ------------------------------------------------------------------
    // Internals
    // ------------------------------------------------------------------

    function _milestone(uint256 tier) internal pure returns (uint256) {
        if (tier == 0) return 3;
        if (tier == 1) return 7;
        if (tier == 2) return 14;
        return 30;
    }

    function _bonus(uint256 tier) internal pure returns (uint256) {
        if (tier == 0) return 20;
        if (tier == 1) return 50;
        if (tier == 2) return 150;
        return 400;
    }

    function _tokenId(address user, uint256 tier) internal pure returns (uint256) {
        return (uint256(uint160(user)) << 8) | tier;
    }

    function _popcount4(uint8 mask) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < TIER_COUNT; i++) {
            if (mask & uint8(1 << i) != 0) count++;
        }
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
