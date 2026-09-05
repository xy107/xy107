// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BaseTest} from "./Base.t.sol";
import {XY} from "../src/XY.sol";
import {XY107} from "../src/XY107.sol";

/// @dev Bounded valid actions exercise interleavings; unexpected reverts must fail the campaign.
contract SecurityHandler is Test {
    XY public immutable token;
    XY107 public immutable nft;
    address public immutable creator;
    uint256 public paidEth;
    uint256 public withdrawnEth;
    uint256 public donatedTokens;
    uint256 public forcedEth;
    uint256 public acceptedEth;
    uint256 public successfulMints;
    uint256 public mintPayments;

    constructor(XY token_, XY107 nft_, address creator_) {
        token = token_;
        nft = nft_;
        creator = creator_;
    }

    function contribute(uint256 rawAmount, uint256 actorSeed) external {
        if (token.totalRaisedEth() == 428 ether) return;
        address actor = _actor(actorSeed);
        uint256 amount = bound(rawAmount, 0.0001 ether, 450 ether);
        vm.deal(actor, amount);
        uint256 beforeBalance = address(token).balance;
        vm.prank(actor);
        token.contribute{value: amount}();
        acceptedEth += address(token).balance - beforeBalance;
    }

    function paySlot(uint256 slotSeed, uint256 actorSeed) external {
        uint256 slot = bound(slotSeed, 2, 108);
        if (token.payoutPoolEth() < 4 ether) return;
        if (uint256(token.paidSlotBitmap()) & (1 << (slot - 2)) != 0) return;
        address recipient = _actor(actorSeed);
        uint256 beforeBalance = recipient.balance;
        vm.prank(token.operator());
        token.paySlot(slot, recipient);
        paidEth += recipient.balance - beforeBalance;
    }

    function allocate(uint256 trancheSeed, uint256 actorSeed, uint256 seatSeed) external {
        uint256 choice = trancheSeed % 4;
        address recipient = _actor(actorSeed);
        if (choice == 0) {
            if (block.timestamp >= token.ALLOCATION_DEADLINE() || token.yuReleased()) return;
            vm.prank(token.operator());
            token.releaseYu(recipient);
        } else if (choice == 1) {
            if (block.timestamp >= token.ALLOCATION_DEADLINE()) return;
            uint8 seat = uint8(seatSeed % 3);
            if (token.paidSeedSupporterBitmap() & (1 << seat) != 0) return;
            vm.prank(creator);
            token.paySeedSupporter(recipient, seat);
        } else if (choice == 2) {
            if (block.timestamp >= token.ALLOCATION_DEADLINE() || token.spreaderPaidCount() == 100) return;
            uint256 count = bound(seatSeed, 1, 100 - token.spreaderPaidCount());
            address[] memory recipients = new address[](count);
            for (uint256 i; i < count; ++i) {
                recipients[i] = recipient;
            }
            vm.prank(token.operator());
            token.distributeSpreaders(recipients);
        } else {
            if (token.artistPaid()) return;
            vm.prank(token.operator());
            token.payArtist(recipient);
        }
    }

    function advanceTime(uint256 delta) external {
        vm.warp(block.timestamp + bound(delta, 0, 30 days));
    }

    function burnExpired(uint256 seed) external {
        if (block.timestamp < token.ALLOCATION_DEADLINE()) return;
        uint256 choice = seed % 3;
        if (choice == 0 && token.trancheRemaining(XY.Tranche.YU) > 0) token.burnYu();
        if (choice == 1 && token.trancheRemaining(XY.Tranche.SEED_SUPPORTER) > 0) {
            token.burnSeedSupporterRemainder();
        }
        if (choice == 2 && token.trancheRemaining(XY.Tranche.SPREADER) > 0) {
            token.burnSpreaderRemainder();
        }
    }

    function changeAdmin(uint256 actorSeed) external {
        address next = _actor(actorSeed);
        vm.prank(token.operator());
        token.transferAdmin(next);
    }

    function mint(uint256 idSeed, uint256 actorSeed) external {
        uint256 id = bound(idSeed, 2, 108);
        address actor = _actor(actorSeed);
        if (nft.hasMintedHero(actor)) return;
        try nft.ownerOf(id) returns (address) {
            return;
        } catch {}
        vm.deal(actor, 1 ether);
        vm.prank(actor);
        nft.mint{value: 1 ether}(id);
        ++successfulMints;
        mintPayments += 1 ether;
    }

    function transferHero(uint256 idSeed, uint256 actorSeed) external {
        uint256 id = bound(idSeed, 2, 108);
        address recipient = _actor(actorSeed);
        try nft.ownerOf(id) returns (address owner) {
            vm.prank(owner);
            nft.transferFrom(owner, recipient, id);
        } catch {}
    }

    function withdraw(uint256 rawAmount) external {
        uint256 amount = bound(rawAmount, 0, address(nft).balance);
        uint256 beforeBalance = creator.balance;
        vm.prank(creator);
        nft.withdrawEth(amount);
        withdrawnEth += creator.balance - beforeBalance;
    }

    function burnSongjiang() external {
        if (nft.heroMintCount() != 107 || token.trancheRemaining(XY.Tranche.SONGJIANG) == 0) {
            return;
        }
        nft.burnSongjiang();
    }

    function donate(uint256 actorSeed, uint256 rawAmount) external {
        address actor = _actor(actorSeed);
        uint256 amount = bound(rawAmount, 0, token.balanceOf(actor));
        vm.prank(actor);
        token.transfer(address(token), amount);
        donatedTokens += amount;
    }

    function forceEth(uint256 rawAmount) external {
        uint256 amount = bound(rawAmount, 0, 1 ether);
        // Model unsolicited ETH without depending on SELFDESTRUCT fork semantics.
        vm.deal(address(token), address(token).balance + amount);
        forcedEth += amount;
    }

    function _actor(uint256 seed) private pure returns (address) {
        return address(uint160(0x10000 + seed % 128));
    }
}

contract SecurityInvariantTest is BaseTest {
    SecurityHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new SecurityHandler(xy, nft, creator);
        bytes4[] memory selectors = new bytes4[](13);
        selectors[0] = handler.contribute.selector;
        selectors[1] = handler.paySlot.selector;
        selectors[2] = handler.allocate.selector;
        selectors[3] = handler.advanceTime.selector;
        selectors[4] = handler.burnExpired.selector;
        selectors[5] = handler.changeAdmin.selector;
        selectors[6] = handler.mint.selector;
        selectors[7] = handler.transferHero.selector;
        selectors[8] = handler.withdraw.selector;
        selectors[9] = handler.burnSongjiang.selector;
        selectors[10] = handler.donate.selector;
        selectors[11] = handler.forceEth.selector;
        // Give contributions more weight so mixed sale/payout sequences stay active.
        selectors[12] = handler.contribute.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_ConservationAndLifecycle() public view {
        assertEq(xy.totalSupply() + xy.totalBurned(), xy.TOTAL_SUPPLY());
        uint256 reserved;
        for (uint256 i; i < 6; ++i) {
            reserved += xy.trancheRemaining(XY.Tranche(i));
        }
        assertEq(xy.balanceOf(address(xy)), reserved + handler.donatedTokens());
        assertEq(xy.totalRaisedEth(), handler.acceptedEth());
        assertLe(xy.totalRaisedEth(), 428 ether);
        assertEq(xy.totalRaisedEth(), xy.payoutPoolEth() + handler.paidEth());
        assertEq(address(xy).balance, xy.payoutPoolEth() + handler.forcedEth());
        uint256 bitmap = uint256(xy.paidSlotBitmap());
        assertEq(bitmap >> 107, 0);
        uint256 paidCount;
        while (bitmap != 0) {
            bitmap &= bitmap - 1;
            ++paidCount;
        }
        assertEq(handler.paidEth(), paidCount * 4 ether);
        assertEq(
            xy.totalRoundAllocatedXy() + xy.trancheRemaining(XY.Tranche.PUBLIC), xy.PUBLIC_AMOUNT()
        );
        assertLe(xy.spreaderPaidCount(), 100);
        assertLe(xy.paidSeedSupporterBitmap(), 7);
        assertEq(nft.heroMintCount(), handler.successfulMints());
        assertLe(nft.heroMintCount(), 107);
        assertEq(address(nft).balance + handler.withdrawnEth(), handler.mintPayments());
        if (xy.trancheRemaining(XY.Tranche.SONGJIANG) == 0) {
            assertEq(nft.heroMintCount(), 107);
            assertEq(nft.balanceOf(address(nft)), 0);
        } else {
            assertEq(nft.ownerOf(1), address(nft));
        }
    }
}
