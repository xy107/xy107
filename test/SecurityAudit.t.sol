// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {XY} from "../src/XY.sol";
import {XY107} from "../src/XY107.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @dev Includes proofs of remaining audit findings and regressions for remediated findings.
contract SecurityAuditTest is BaseTest {
    function testAudit_BurnedSongjiangStillAcceptsOnePermanentMetadataCommitment() public {
        _mintAllHeroes();
        vm.prank(alice);
        nft.burnSongjiang();
        vm.prank(creator);
        nft.commitMetadata(1, "Songjiang", "Final artwork", keccak256("image"));
        (,, bytes32 imageHash) = nft.metadata(1);
        assertEq(imageHash, keccak256("image"));
        vm.prank(creator);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.commitMetadata(1, "Songjiang", "Replacement", keccak256("replacement"));
        assertEq(xy.totalBurned(), xy.SONGJIANG_AMOUNT());
    }

    function testAudit_PocSelfAdminPermanentlyDisablesOperator() public {
        vm.prank(creator);
        xy.transferAdmin(address(xy));
        assertEq(xy.operator(), address(xy));
        vm.prank(creator);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.transferAdmin(creator);
        vm.prank(creator);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.payArtist(alice);
    }

    function testAudit_PocSelfAllocationConsumesAwardWithoutDeliveringTokens() public {
        uint256 beforeBalance = xy.balanceOf(address(xy));
        vm.prank(creator);
        xy.releaseYu(address(xy));
        assertEq(xy.balanceOf(address(xy)), beforeBalance);
        assertEq(xy.trancheRemaining(XY.Tranche.YU), 0);
        vm.warp(xy.ALLOCATION_DEADLINE());
        vm.expectRevert(XY.InvalidState.selector);
        xy.burnYu();
    }

    function testAudit_PocEmptyAccountIdIsAcceptedByDeployment() public {
        vm.setEnv("X_ACCOUNT_ID", "");
        (XY fresh,) = new Deploy().run();
        assertEq(fresh.xAccount(), keccak256(""));
        assertTrue(fresh.xAccount() != bytes32(0));
    }

    function testAudit_PartialRoundCannotPaySubFourEthRemainder() public {
        _contribute(alice, 7 ether);
        vm.startPrank(creator);
        xy.paySlot(2, bob);
        vm.expectRevert(XY.InvalidInput.selector);
        xy.paySlot(3, bob);
        vm.stopPrank();
        vm.warp(xy.ALLOCATION_DEADLINE() + 1000 days);
        assertEq(xy.payoutPoolEth(), 3 ether);
        // Contributions remain open after the allocation deadline.
        _contribute(alice, 1 ether);
        vm.prank(creator);
        xy.paySlot(3, bob);
        assertEq(xy.payoutPoolEth(), 0);
    }

    function testAudit_All107SlotsDrainExactly428Eth() public {
        _contribute(alice, 428 ether);
        uint256 beforeBalance = bob.balance;
        vm.startPrank(creator);
        for (uint256 i = 2; i <= 108; ++i) {
            xy.paySlot(i, bob);
        }
        vm.stopPrank();
        assertEq(bob.balance - beforeBalance, 428 ether);
        assertEq(xy.payoutPoolEth(), 0);
        assertEq(address(xy).balance, 0);
        assertEq(uint256(xy.paidSlotBitmap()), (uint256(1) << 107) - 1);
        assertEq(xy.totalRaisedEth(), 428 ether);
    }

    function testAudit_RefundRejectionRollsBackEntireContribution() public {
        AuditReceiver receiver = new AuditReceiver(xy, nft);
        receiver.configure(true, false);
        vm.deal(address(receiver), 429 ether);
        vm.expectRevert(AuditReceiver.Rejected.selector);
        receiver.buy(429 ether);
        assertEq(xy.totalRaisedEth(), 0);
        assertEq(xy.totalRoundAllocatedXy(), 0);
        assertEq(xy.balanceOf(address(receiver)), 0);
        assertEq(xy.trancheRemaining(XY.Tranche.PUBLIC), xy.PUBLIC_AMOUNT());
        receiver.configure(false, false);
        receiver.buy(428 ether);
        assertEq(xy.totalRaisedEth(), 428 ether);
    }

    function testAudit_RefundCallbackCannotReenterContributeOrPaySlot() public {
        AuditReceiver receiver = new AuditReceiver(xy, nft);
        vm.prank(creator);
        xy.transferAdmin(address(receiver));
        receiver.configure(false, true);
        vm.deal(address(receiver), 429 ether);
        receiver.buy(429 ether);
        assertEq(
            receiver.contributionError(), ReentrancyGuard.ReentrancyGuardReentrantCall.selector
        );
        assertEq(receiver.payoutError(), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        assertEq(xy.totalRaisedEth(), 428 ether);
        assertEq(xy.payoutPoolEth(), 428 ether);
        assertEq(xy.paidSlotBitmap(), bytes32(0));
        assertEq(address(receiver).balance, 1 ether);
    }

    function testAudit_PayoutCallbackCannotReenterAndRejectionCanBeRetried() public {
        AuditReceiver receiver = new AuditReceiver(xy, nft);
        _contribute(alice, 8 ether);
        receiver.configure(true, false);
        vm.prank(creator);
        vm.expectRevert(AuditReceiver.Rejected.selector);
        xy.paySlot(2, address(receiver));
        assertEq(xy.payoutPoolEth(), 8 ether);
        assertEq(xy.paidSlotBitmap(), bytes32(0));
        vm.prank(creator);
        xy.transferAdmin(address(receiver));
        receiver.configure(false, true);
        receiver.pay();
        assertEq(
            receiver.contributionError(), ReentrancyGuard.ReentrancyGuardReentrantCall.selector
        );
        assertEq(receiver.payoutError(), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        assertEq(xy.payoutPoolEth(), 4 ether);
        assertEq(address(receiver).balance, 4 ether);
    }

    function testAudit_NftReceiverRejectionRollsBackMint() public {
        AuditReceiver receiver = new AuditReceiver(xy, nft);
        receiver.configure(true, false);
        vm.deal(address(receiver), 2 ether);
        vm.expectRevert(AuditReceiver.Rejected.selector);
        receiver.mintHero(2);
        assertFalse(nft.hasMintedHero(address(receiver)));
        assertEq(nft.heroMintCount(), 0);
        assertEq(address(nft).balance, 0);
        receiver.configure(false, false);
        receiver.mintHero(2);
        assertEq(nft.ownerOf(2), address(receiver));
    }

    function testAudit_NftCallbackCannotReenterMintOrBurn() public {
        AuditReceiver receiver = new AuditReceiver(xy, nft);
        receiver.configure(false, true);
        vm.deal(address(receiver), 3 ether);
        receiver.mintHero(2);
        assertEq(receiver.mintError(), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        assertEq(receiver.burnError(), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        assertEq(nft.heroMintCount(), 1);
        assertEq(address(nft).balance, 1 ether);
    }

    function testAudit_WithdrawCallbackCannotReenter() public {
        AuditCreator receiver = new AuditCreator();
        XY107 otherNft = receiver.nft();
        vm.prank(alice);
        otherNft.mint{value: 1 ether}(2);
        receiver.withdraw();
        assertEq(receiver.withdrawError(), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        assertEq(address(otherNft).balance, 0);
        assertEq(address(receiver).balance, 1 ether);
    }

    function testAudit_FailedCrossContractBurnIsAtomic() public {
        vm.prank(creator);
        XY unlinked = new XY("XY", "XY", X_ACCOUNT);
        XY107 otherNft = new XY107("XY107", "XY107", address(unlinked));
        for (uint256 id = 2; id <= 108; ++id) {
            address minter = address(uint160(10_000 + id));
            vm.deal(minter, 1 ether);
            vm.prank(minter);
            otherNft.mint{value: 1 ether}(id);
        }
        vm.expectRevert(XY.Unauthorized.selector);
        otherNft.burnSongjiang();
        assertEq(otherNft.ownerOf(1), address(otherNft));
        assertEq(unlinked.totalBurned(), 0);
        vm.prank(creator);
        unlinked.setXy107(address(otherNft));
        otherNft.burnSongjiang();
        assertEq(unlinked.totalBurned(), unlinked.SONGJIANG_AMOUNT());
    }

    function testAudit_DeadlineBoundaryAndCreatorPrivilegesAfterHandoff() public {
        uint256 deadline = xy.ALLOCATION_DEADLINE();
        vm.prank(creator);
        xy.transferAdmin(admin);
        vm.warp(deadline - 1);
        vm.prank(admin);
        vm.expectRevert(XY.Unauthorized.selector);
        xy.paySeedSupporter(alice, 0);
        vm.prank(creator);
        xy.paySeedSupporter(alice, 0);
        vm.prank(admin);
        xy.distributeSpreaders(_recipients(1));
        vm.expectRevert(XY.InvalidState.selector);
        xy.burnYu();
        vm.warp(deadline);
        vm.prank(creator);
        vm.expectRevert(XY.InvalidState.selector);
        xy.paySeedSupporter(bob, 1);
        address[] memory recipients = _recipients(1);
        vm.prank(admin);
        vm.expectRevert(XY.InvalidState.selector);
        xy.distributeSpreaders(recipients);
        vm.prank(admin);
        vm.expectRevert(XY.InvalidState.selector);
        xy.releaseYu(bob);
        xy.burnYu();
        xy.burnSpreaderRemainder();
        xy.burnSeedSupporterRemainder();
        vm.prank(admin);
        xy.payArtist(bob);
        assertEq(xy.totalSupply() + xy.totalBurned(), xy.TOTAL_SUPPLY());
    }

    function testAudit_DuplicateRecipientsArePermittedByDesign() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = alice;
        vm.prank(creator);
        xy.distributeSpreaders(recipients);
        assertEq(xy.spreaderPaidCount(), 2);
        assertEq(xy.balanceOf(alice), 80_000e8);
    }

    function testAudit_InvalidBatchRollsBackEarlierTransfers() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        vm.prank(creator);
        vm.expectRevert(XY.InvalidAddress.selector);
        xy.distributeSpreaders(recipients);
        assertEq(xy.spreaderPaidCount(), 0);
        assertEq(xy.balanceOf(alice), 0);
        assertEq(xy.trancheRemaining(XY.Tranche.SPREADER), xy.SPREADER_TOTAL_AMOUNT());
    }

    function testAudit_TransferredNftDoesNotRestoreMintEligibility() public {
        vm.prank(alice);
        nft.mint{value: 1 ether}(2);
        vm.prank(alice);
        nft.transferFrom(alice, bob, 2);
        vm.prank(alice);
        vm.expectRevert(XY107.InvalidState.selector);
        nft.mint{value: 1 ether}(3);
        vm.prank(bob);
        nft.mint{value: 1 ether}(3);
        assertEq(nft.balanceOf(bob), 2);
    }

    function testAudit_FinalOneWeiReceivesRoundingDust() public {
        _contribute(alice, 428 ether - 1);
        assertEq(xy.trancheRemaining(XY.Tranche.PUBLIC), 1);
        _contribute(bob, 1);
        assertEq(xy.balanceOf(bob), 1);
        assertEq(xy.totalRoundAllocatedXy(), xy.PUBLIC_AMOUNT());
    }

    function testFuzz_AuditContributionConservesValue(uint256 first, uint256 second) public {
        first = bound(first, 0.0001 ether, 428 ether - 0.0001 ether);
        second = bound(second, 0.0001 ether, 500 ether);
        _contribute(alice, first);
        _contribute(bob, second);
        uint256 raised = first + second > 428 ether ? 428 ether : first + second;
        assertEq(xy.totalRaisedEth(), raised);
        assertEq(xy.payoutPoolEth(), raised);
        assertEq(address(xy).balance, raised);
        assertEq(alice.balance + bob.balance + raised, 2_000 ether);
        assertEq(xy.totalRoundAllocatedXy(), xy.balanceOf(alice) + xy.balanceOf(bob));
        assertEq(
            xy.totalRoundAllocatedXy() + xy.trancheRemaining(XY.Tranche.PUBLIC), xy.PUBLIC_AMOUNT()
        );
        if (raised == 428 ether) assertEq(xy.trancheRemaining(XY.Tranche.PUBLIC), 0);
    }

    function _mintAllHeroes() private {
        for (uint256 id = 2; id <= 108; ++id) {
            address minter = address(uint160(10_000 + id));
            vm.deal(minter, 1 ether);
            vm.prank(minter);
            nft.mint{value: 1 ether}(id);
        }
    }
}

contract AuditReceiver is IERC721Receiver {
    XY private immutable _xy;
    XY107 private immutable _nft;
    bool private _reject;
    bool private _attack;
    bytes4 public contributionError;
    bytes4 public payoutError;
    bytes4 public mintError;
    bytes4 public burnError;
    error Rejected();

    constructor(XY xy_, XY107 nft_) {
        _xy = xy_;
        _nft = nft_;
    }

    function configure(bool reject_, bool attack_) external {
        _reject = reject_;
        _attack = attack_;
    }

    function buy(uint256 amount) external {
        _xy.contribute{value: amount}();
    }

    function pay() external {
        _xy.paySlot(2, address(this));
    }

    function mintHero(uint256 id) external {
        _nft.mint{value: 1 ether}(id);
    }

    receive() external payable {
        if (_reject) revert Rejected();
        if (_attack) {
            try _xy.contribute{value: 0.0001 ether}() {}
            catch (bytes memory reason) {
                contributionError = bytes4(reason);
            }
            try _xy.paySlot(3, address(this)) {}
            catch (bytes memory reason) {
                payoutError = bytes4(reason);
            }
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (_reject) revert Rejected();
        if (_attack) {
            try _nft.mint{value: 1 ether}(3) {}
            catch (bytes memory reason) {
                mintError = bytes4(reason);
            }
            try _nft.burnSongjiang() {}
            catch (bytes memory reason) {
                burnError = bytes4(reason);
            }
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract AuditCreator {
    XY107 public immutable nft;
    bytes4 public withdrawError;

    constructor() {
        XY token = new XY("XY", "XY", keccak256("creator"));
        nft = new XY107("XY107", "XY107", address(token));
        token.setXy107(address(nft));
    }

    function withdraw() external {
        nft.withdrawEth(1 ether);
    }

    receive() external payable {
        try nft.withdrawEth(0) {}
        catch (bytes memory reason) {
            withdrawError = bytes4(reason);
        }
    }
}
