// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StreakID} from "../contracts/StreakID.sol";
import {MockAgentID} from "../contracts/mocks/MockAgentID.sol";

contract StreakIDTest is Test {
    MockAgentID internal registry;
    StreakID internal streak;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA401); // never an Agent ID holder

    string internal constant BASE_URI = "https://example.invalid/badges/";

    function setUp() public {
        registry = new MockAgentID();
        streak = new StreakID(address(registry), BASE_URI);
        registry.setHolder(alice, true);
        registry.setHolder(bob, true);
        // Start at a clean UTC midnight so day math is obvious.
        vm.warp(20_000 * 86_400);
    }

    function _checkIn(address user) internal {
        vm.prank(user);
        streak.checkIn();
    }

    function _nextDay() internal {
        vm.warp(block.timestamp + 86_400);
    }

    // ---------------------------------------------------------------
    // Gate
    // ---------------------------------------------------------------

    function test_GateRejectsNonHolder() public {
        vm.prank(carol);
        vm.expectRevert(StreakID.NotAgentIdHolder.selector);
        streak.checkIn();
        assertEq(streak.totalAgents(), 0);
        assertEq(streak.totalCheckInsOf(carol), 0);
    }

    function test_GateRejectsAfterLosingAgentId() public {
        _checkIn(alice);
        registry.setHolder(alice, false);
        _nextDay();
        vm.prank(alice);
        vm.expectRevert(StreakID.NotAgentIdHolder.selector);
        streak.checkIn();
    }

    function test_HasAgentIdView() public view {
        assertTrue(streak.hasAgentId(alice));
        assertFalse(streak.hasAgentId(carol));
    }

    // ---------------------------------------------------------------
    // Check-in cadence & streaks
    // ---------------------------------------------------------------

    function test_FirstCheckIn() public {
        _checkIn(alice);
        assertEq(streak.streakOf(alice), 1);
        assertEq(streak.bestStreakOf(alice), 1);
        assertEq(streak.totalCheckInsOf(alice), 1);
        assertEq(streak.pointsOf(alice), 10);
        assertEq(streak.lastCheckIn(alice), block.timestamp);
        assertEq(streak.totalAgents(), 1);
        assertFalse(streak.canCheckInToday(alice));
        assertEq(streak.nextCheckInAt(alice), 20_001 * 86_400);
    }

    function test_SecondCheckInSameDayReverts() public {
        _checkIn(alice);
        vm.prank(alice);
        vm.expectRevert(StreakID.AlreadyCheckedInToday.selector);
        streak.checkIn();
        // Also later the same UTC day.
        vm.warp(block.timestamp + 3_600);
        vm.prank(alice);
        vm.expectRevert(StreakID.AlreadyCheckedInToday.selector);
        streak.checkIn();
        assertEq(streak.totalCheckInsOf(alice), 1);
    }

    function test_StreakIncrementsOnConsecutiveDays() public {
        _checkIn(alice);
        _nextDay();
        _checkIn(alice);
        assertEq(streak.streakOf(alice), 2);
        _nextDay();
        _checkIn(alice);
        assertEq(streak.streakOf(alice), 3);
        assertEq(streak.pointsOf(alice), 30 + 20); // 3 check-ins + tier-0 bonus
    }

    function test_StreakBreaksAfterMissedDay() public {
        _checkIn(alice);
        _nextDay();
        _checkIn(alice);
        assertEq(streak.streakOf(alice), 2);
        // One day later the streak is still alive (today is the day to save it).
        _nextDay();
        assertEq(streak.streakOf(alice), 2);
        // A full day passes with no check-in: the streak is broken.
        _nextDay();
        assertEq(streak.streakOf(alice), 0);
        _checkIn(alice);
        assertEq(streak.streakOf(alice), 1);
        assertEq(streak.bestStreakOf(alice), 2);
        assertEq(streak.totalCheckInsOf(alice), 3);
    }

    function test_TotalAgentsCountsUniqueUsersOnce() public {
        _checkIn(alice);
        _checkIn(bob);
        assertEq(streak.totalAgents(), 2);
        _nextDay();
        _checkIn(alice);
        _checkIn(bob);
        assertEq(streak.totalAgents(), 2);
        address[] memory page = streak.getAgents(0, 10);
        assertEq(page.length, 2);
        assertEq(page[0], alice);
        assertEq(page[1], bob);
        address[] memory page2 = streak.getAgents(1, 1);
        assertEq(page2.length, 1);
        assertEq(page2[0], bob);
        assertEq(streak.getAgents(5, 10).length, 0);
    }

    // ---------------------------------------------------------------
    // Badges
    // ---------------------------------------------------------------

    function _checkInDays(address user, uint256 numDays) internal {
        for (uint256 i = 0; i < numDays; i++) {
            if (i > 0) _nextDay();
            _checkIn(user);
        }
    }

    function test_BadgeMintedAtDay3() public {
        _checkInDays(alice, 3);
        assertTrue(streak.hasBadge(alice));
        assertTrue(streak.hasBadgeTier(alice, 0));
        assertFalse(streak.hasBadgeTier(alice, 1));
        assertEq(streak.balanceOf(alice), 1);
        uint256 tokenId = (uint256(uint160(alice)) << 8) | 0;
        assertEq(streak.ownerOf(tokenId), alice);
        assertEq(streak.tokenURI(tokenId), string(abi.encodePacked(BASE_URI, "3.json")));
    }

    function test_AllBadgeTiersByDay30() public {
        _checkInDays(alice, 30);
        assertEq(streak.balanceOf(alice), 4);
        assertEq(streak.badgeMaskOf(alice), 0x0f);
        // points: 30*10 + (20+50+150+400) = 920
        assertEq(streak.pointsOf(alice), 920);
        assertEq(streak.bestStreakOf(alice), 30);
        for (uint256 tier = 0; tier < 4; tier++) {
            uint256 tokenId = (uint256(uint160(alice)) << 8) | tier;
            assertEq(streak.ownerOf(tokenId), alice);
        }
        assertEq(streak.tokenURI((uint256(uint160(alice)) << 8) | 3), string(abi.encodePacked(BASE_URI, "30.json")));
    }

    function test_BadgeNotMintedTwiceAfterStreakRestart() public {
        _checkInDays(alice, 3);
        assertEq(streak.balanceOf(alice), 1);
        uint256 pointsBefore = streak.pointsOf(alice);
        // Miss two days, rebuild a 3-day streak.
        _nextDay();
        _nextDay();
        _checkInDays(alice, 3);
        assertEq(streak.balanceOf(alice), 1); // still one badge
        assertEq(streak.pointsOf(alice), pointsBefore + 30); // no second bonus
    }

    function test_OwnerOfUnmintedReverts() public {
        uint256 tokenId = (uint256(uint160(alice)) << 8) | 0;
        vm.expectRevert(StreakID.TokenNotMinted.selector);
        streak.ownerOf(tokenId);
    }

    function test_BadgeTransfersAlwaysRevert() public {
        _checkInDays(alice, 3);
        uint256 tokenId = (uint256(uint160(alice)) << 8) | 0;

        vm.prank(alice);
        vm.expectRevert(StreakID.Soulbound.selector);
        streak.transferFrom(alice, bob, tokenId);

        vm.prank(alice);
        vm.expectRevert(StreakID.Soulbound.selector);
        streak.safeTransferFrom(alice, bob, tokenId);

        vm.prank(alice);
        vm.expectRevert(StreakID.Soulbound.selector);
        streak.safeTransferFrom(alice, bob, tokenId, "");

        vm.prank(alice);
        vm.expectRevert(StreakID.Soulbound.selector);
        streak.approve(bob, tokenId);

        vm.prank(alice);
        vm.expectRevert(StreakID.Soulbound.selector);
        streak.setApprovalForAll(bob, true);

        assertEq(streak.getApproved(tokenId), address(0));
        assertFalse(streak.isApprovedForAll(alice, bob));
        assertEq(streak.ownerOf(tokenId), alice);
    }

    function test_SupportsInterface() public view {
        assertTrue(streak.supportsInterface(0x01ffc9a7));
        assertTrue(streak.supportsInterface(0x80ac58cd));
        assertTrue(streak.supportsInterface(0x5b5e139f));
        assertFalse(streak.supportsInterface(0xffffffff));
    }

    function test_EventsEmitted() public {
        vm.expectEmit(true, false, false, true);
        emit StreakID.CheckIn(alice, 1, 1, 10);
        _checkIn(alice);

        _nextDay();
        _checkIn(alice);
        _nextDay();
        uint256 tokenId = (uint256(uint160(alice)) << 8) | 0;
        vm.expectEmit(true, true, true, true);
        emit StreakID.Transfer(address(0), alice, tokenId);
        vm.expectEmit(true, true, false, true);
        emit StreakID.BadgeEarned(alice, tokenId, 3);
        _checkIn(alice);
    }

    // ---------------------------------------------------------------
    // Safety surface
    // ---------------------------------------------------------------

    function test_ContractRejectsPlainBnb() public {
        (bool ok,) = address(streak).call{value: 1 ether}("");
        assertFalse(ok);
    }

    function test_ConstructorRejectsZeroRegistry() public {
        vm.expectRevert(StreakID.ZeroAddress.selector);
        new StreakID(address(0), BASE_URI);
    }

    // ---------------------------------------------------------------
    // Gas measurement (deploy + check-in), logged for the report
    // ---------------------------------------------------------------

    function test_DeployGas() public {
        uint256 g0 = gasleft();
        StreakID fresh = new StreakID(address(registry), BASE_URI);
        uint256 used = g0 - gasleft();
        console.log("DEPLOY_GAS_CREATE_OPCODE_LEVEL:", used);
        console.log("DEPLOYED_SIZE_BYTES:", address(fresh).code.length);
        assertTrue(address(fresh) != address(0));
    }

    function test_CheckInGas() public {
        uint256 g0 = gasleft();
        vm.prank(alice);
        streak.checkIn();
        uint256 first = g0 - gasleft();
        console.log("CHECKIN_GAS_FIRST_TIME_USER:", first);

        _nextDay();
        g0 = gasleft();
        vm.prank(alice);
        streak.checkIn();
        console.log("CHECKIN_GAS_RETURNING_USER:", g0 - gasleft());
    }
}
