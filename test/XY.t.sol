// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest, LinkedXyMock} from "./Base.t.sol";
import {XY} from "../src/XY.sol";

contract XYTest is BaseTest {
    function testConstructorInitializesSupplyAndTranches() public view {
        assertEq(xy.name(), "XY");
        assertEq(xy.symbol(), "XY");
        assertEq(xy.decimals(), 8);
        assertEq(xy.CREATOR(), creator);
        assertEq(xy.xAccount(), X_ACCOUNT);
        assertEq(xy.ALLOCATION_DEADLINE(), START_TIME + xy.ALLOCATION_PERIOD());
        assertEq(xy.totalSupply(), xy.TOTAL_SUPPLY());
        assertEq(xy.balanceOf(creator), xy.CREATOR_AMOUNT());

        uint256 allocated = xy.trancheRemaining(XY.Tranche.SONGJIANG)
            + xy.trancheRemaining(XY.Tranche.PUBLIC)
            + xy.trancheRemaining(XY.Tranche.SEED_SUPPORTER)
            + xy.trancheRemaining(XY.Tranche.SPREADER) + xy.trancheRemaining(XY.Tranche.YU)
            + xy.trancheRemaining(XY.Tranche.ARTIST);
        assertEq(allocated, xy.balanceOf(address(xy)));
    }

    function testConstructorRejectsZeroXAccount() public {
        vm.expectRevert(XY.InvalidInput.selector);
        new XY("XY", "XY", bytes32(0));
    }

    function testSetXy107RejectsInvalidCallersAndContracts() public {
        vm.prank(creator);
        XY fresh = new XY("XY", "XY", X_ACCOUNT);
        LinkedXyMock wrongLink = new LinkedXyMock(address(xy));
        EmptyContract missingLink = new EmptyContract();

        vm.prank(alice);
        vm.expectRevert(XY.Unauthorized.selector);
        fresh.setXy107(address(nft));

        vm.startPrank(creator);
        vm.expectRevert(XY.InvalidAddress.selector);
        fresh.setXy107(address(0));
        vm.expectRevert(XY.InvalidAddress.selector);
        fresh.setXy107(alice);
        vm.expectRevert(XY.InvalidAddress.selector);
        fresh.setXy107(address(wrongLink));
        vm.expectRevert(XY.InvalidAddress.selector);
        fresh.setXy107(address(missingLink));
        vm.stopPrank();
    }

    function testSetXy107CanOnlyBeCalledOnce() public {
        vm.prank(creator);
        vm.expectRevert(XY.InvalidAddress.selector);
        xy.setXy107(address(nft));
    }

    function testContributeTracksAllocationWithoutRefund() public {
        _contribute(alice, 4 ether);

        assertEq(xy.balanceOf(alice), 40_000e8);
        assertEq(xy.totalRoundAllocatedXy(), 40_000e8);
        assertEq(xy.totalRaisedEth(), 4 ether);
        assertEq(xy.payoutPoolEth(), 4 ether);
        assertEq(address(xy).balance, 4 ether);
    }

    function testContributeCapsRoundAndRefundsExcess() public {
        _contribute(alice, 430 ether);

        assertEq(xy.balanceOf(alice), xy.PUBLIC_AMOUNT());
        assertEq(xy.trancheRemaining(XY.Tranche.PUBLIC), 0);
        assertEq(xy.totalRaisedEth(), xy.ROUND_CAP_ETH());
        assertEq(alice.balance, 572 ether);

        vm.prank(bob);
        vm.expectRevert(XY.InvalidState.selector);
        xy.contribute{value: 1 ether}();
    }

    function testContributeRejectsZeroAndSubMinimumAmounts() public {
        vm.prank(alice);
        vm.expectRevert(XY.InvalidState.selector);
        xy.contribute();

        vm.startPrank(alice);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.contribute{value: 1}();
        vm.expectRevert(XY.InvalidInput.selector);
        xy.contribute{value: 0.00009999 ether}();
        vm.stopPrank();
    }

    function testContributeAcceptsMinimumPurchase() public {
        _contribute(alice, 0.0001 ether);
        assertEq(xy.balanceOf(alice), xy.MIN_PURCHASE_XY());
    }

    function testPaySlotTransfersPayoutAndPreventsDuplicate() public {
        _contribute(alice, 4 ether);
        uint256 balanceBefore = bob.balance;

        vm.prank(creator);
        xy.paySlot(2, bob);

        assertEq(bob.balance, balanceBefore + xy.SLOT_PAYOUT_ETH());
        assertEq(xy.payoutPoolEth(), 0);
        assertEq(xy.paidSlotBitmap(), bytes32(uint256(1)));

        _contribute(alice, 4 ether);
        vm.prank(creator);
        vm.expectRevert(XY.InvalidState.selector);
        xy.paySlot(2, bob);
    }

    function testPaySlotSupportsLastIndex() public {
        _contribute(alice, 4 ether);
        vm.prank(creator);
        xy.paySlot(108, bob);
        assertEq(xy.paidSlotBitmap(), bytes32(uint256(1) << 106));
    }

    function testPaySlotRejectsUnauthorizedOrInvalidInput() public {
        vm.prank(alice);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.paySlot(2, bob);

        vm.startPrank(creator);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.paySlot(1, bob);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.paySlot(109, bob);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.paySlot(2, address(0));
        vm.expectRevert(XY.InvalidInput.selector);
        xy.paySlot(2, bob);
        vm.stopPrank();
    }

    function testReleaseYuTransfersEntireTranche() public {
        vm.prank(creator);
        xy.releaseYu(alice);
        assertTrue(xy.yuReleased());
        assertEq(xy.trancheRemaining(XY.Tranche.YU), 0);
        assertEq(xy.balanceOf(alice), xy.YU_AMOUNT());

        vm.prank(creator);
        vm.expectRevert(XY.InvalidState.selector);
        xy.releaseYu(bob);
    }

    function testReleaseYuRejectsInvalidCalls() public {
        vm.prank(alice);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.releaseYu(alice);

        vm.prank(creator);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.releaseYu(address(0));

        vm.warp(xy.ALLOCATION_DEADLINE());
        vm.prank(creator);
        vm.expectRevert(XY.InvalidState.selector);
        xy.releaseYu(alice);
    }

    function testBurnYuAfterDeadline() public {
        vm.expectRevert(XY.InvalidState.selector);
        xy.burnYu();

        vm.warp(xy.ALLOCATION_DEADLINE());
        xy.burnYu();
        assertEq(xy.trancheRemaining(XY.Tranche.YU), 0);
        assertEq(xy.totalBurned(), xy.YU_AMOUNT());

        vm.expectRevert(XY.InvalidState.selector);
        xy.burnYu();
    }

    function testBurnYuRejectsReleasedTranche() public {
        vm.prank(creator);
        xy.releaseYu(alice);
        vm.warp(xy.ALLOCATION_DEADLINE());
        vm.expectRevert(XY.InvalidState.selector);
        xy.burnYu();
    }

    function testPaySeedSupportersUsesFixedAmounts() public {
        vm.startPrank(creator);
        xy.paySeedSupporter(alice, 0);
        xy.paySeedSupporter(bob, 1);
        xy.paySeedSupporter(admin, 2);
        vm.stopPrank();

        assertEq(xy.balanceOf(alice), 600_000e8);
        assertEq(xy.balanceOf(bob), 400_000e8);
        assertEq(xy.balanceOf(admin), 200_000e8);
        assertEq(xy.paidSeedSupporterBitmap(), 7);
        assertEq(xy.trancheRemaining(XY.Tranche.SEED_SUPPORTER), 0);
    }

    function testPaySeedSupporterRejectsInvalidCalls() public {
        vm.startPrank(creator);
        vm.expectRevert(XY.InvalidAddress.selector);
        xy.paySeedSupporter(address(0), 0);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.paySeedSupporter(alice, 3);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.paySeedSupporter(alice, 0);

        vm.prank(creator);
        xy.paySeedSupporter(alice, 0);
        vm.prank(creator);
        vm.expectRevert(XY.InvalidState.selector);
        xy.paySeedSupporter(alice, 0);

        vm.warp(xy.ALLOCATION_DEADLINE());
        vm.prank(creator);
        vm.expectRevert(XY.InvalidState.selector);
        xy.paySeedSupporter(alice, 1);
    }

    function testDistributeSpreadersTransfersFixedAwards() public {
        address[] memory recipients = _recipients(2);
        vm.prank(creator);
        xy.distributeSpreaders(recipients);

        assertEq(xy.spreaderPaidCount(), 2);
        assertEq(xy.balanceOf(recipients[0]), xy.SPREADER_AMOUNT());
        assertEq(xy.balanceOf(recipients[1]), xy.SPREADER_AMOUNT());
        assertEq(
            xy.trancheRemaining(XY.Tranche.SPREADER),
            xy.SPREADER_TOTAL_AMOUNT() - 2 * xy.SPREADER_AMOUNT()
        );
    }

    function testDistributeSpreadersRejectsInvalidCalls() public {
        vm.prank(alice);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.distributeSpreaders(_recipients(1));

        vm.startPrank(creator);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.distributeSpreaders(_recipients(0));
        vm.expectRevert(XY.InvalidInput.selector);
        xy.distributeSpreaders(_recipients(101));

        address[] memory withZero = _recipients(2);
        withZero[1] = address(0);
        vm.expectRevert(XY.InvalidAddress.selector);
        xy.distributeSpreaders(withZero);
        vm.stopPrank();

        vm.warp(xy.ALLOCATION_DEADLINE());
        vm.prank(creator);
        vm.expectRevert(XY.InvalidState.selector);
        xy.distributeSpreaders(_recipients(1));
    }

    function testDistributeSpreadersRejectsExhaustedTranche() public {
        // The count cap normally keeps these values in sync. Corrupt the tranche to exercise
        // the independent defensive balance check.
        bytes32 slot = keccak256(abi.encode(uint256(XY.Tranche.SPREADER), uint256(8)));
        vm.store(address(xy), slot, bytes32(uint256(xy.SPREADER_AMOUNT() - 1)));

        vm.prank(creator);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.distributeSpreaders(_recipients(1));
    }

    function testDistributeSpreadersRejectsMoreThanRemainingSeats() public {
        vm.prank(creator);
        xy.distributeSpreaders(_recipients(100));
        vm.prank(creator);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.distributeSpreaders(_recipients(1));
    }

    function testPayArtistTransfersEntireTrancheOnce() public {
        vm.prank(creator);
        xy.payArtist(alice);
        assertEq(xy.balanceOf(alice), xy.ARTIST_AMOUNT());

        vm.prank(creator);
        vm.expectRevert(XY.InvalidState.selector);
        xy.payArtist(bob);
    }

    function testPayArtistRejectsInvalidCalls() public {
        vm.prank(alice);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.payArtist(alice);
        vm.prank(creator);
        vm.expectRevert(XY.InvalidAddress.selector);
        xy.payArtist(address(0));
    }

    function testRemainderBurnsAfterDeadlineAndOnlyOnce() public {
        vm.expectRevert(XY.InvalidState.selector);
        xy.burnSpreaderRemainder();
        vm.expectRevert(XY.InvalidState.selector);
        xy.burnSeedSupporterRemainder();

        vm.warp(xy.ALLOCATION_DEADLINE());
        xy.burnSpreaderRemainder();
        xy.burnSeedSupporterRemainder();
        assertEq(xy.totalBurned(), xy.SPREADER_TOTAL_AMOUNT() + xy.SEED_SUPPORTER_TOTAL_AMOUNT());

        vm.expectRevert(XY.InvalidState.selector);
        xy.burnSpreaderRemainder();
        vm.expectRevert(XY.InvalidState.selector);
        xy.burnSeedSupporterRemainder();
    }

    function testOperatorAdministration() public {
        assertEq(xy.operator(), creator);
        vm.prank(alice);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.transferAdmin(admin);
        vm.prank(creator);
        vm.expectRevert(XY.InvalidAddress.selector);
        xy.transferAdmin(address(0));

        vm.prank(creator);
        xy.transferAdmin(admin);
        assertEq(xy.operator(), admin);

        bytes32 updated = keccak256("updated-account");
        vm.prank(creator);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.setXAccount(updated);
        vm.prank(admin);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.setXAccount(bytes32(0));
        vm.prank(admin);
        xy.setXAccount(updated);
        assertEq(xy.xAccount(), updated);
    }

    function testBurnSongjiangLockRejectsUnauthorizedCaller() public {
        vm.expectRevert(XY.Unauthorized.selector);
        xy.burnSongjiangLock();
    }

    function testBurnSongjiangLockRejectsSecondBurn() public {
        for (uint256 tokenId = 2; tokenId <= 108; ++tokenId) {
            address minter = address(uint160(tokenId + 1_000));
            vm.deal(minter, 1 ether);
            vm.prank(minter);
            nft.mint{value: 1 ether}(tokenId);
        }

        vm.prank(creator);
        nft.burnSongjiang();
        vm.prank(address(nft));
        vm.expectRevert(XY.Unauthorized.selector);
        xy.burnSongjiangLock();
    }
}

contract EmptyContract {}
