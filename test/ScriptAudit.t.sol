// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XY} from "../src/XY.sol";
import {XY107} from "../src/XY107.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {PaySlot} from "../script/operator/PaySlot.s.sol";
import {ReleaseYu} from "../script/operator/ReleaseYu.s.sol";
import {DistributeSpreaders} from "../script/operator/DistributeSpreaders.s.sol";
import {PayArtist} from "../script/operator/PayArtist.s.sol";
import {TransferAdmin} from "../script/operator/TransferAdmin.s.sol";
import {SetXAccount} from "../script/operator/SetXAccount.s.sol";
import {CommitMetadata} from "../script/operator/CommitMetadata.s.sol";
import {SetImageBaseURI} from "../script/operator/SetImageBaseURI.s.sol";
import {SetContractURI} from "../script/operator/SetContractURI.s.sol";
import {BurnYu} from "../script/permissionless/BurnYu.s.sol";
import {BurnSpreaderRemainder} from "../script/permissionless/BurnSpreaderRemainder.s.sol";
import {
    BurnSeedSupporterRemainder
} from "../script/permissionless/BurnSeedSupporterRemainder.s.sol";
import {BurnSongjiang} from "../script/permissionless/BurnSongjiang.s.sol";

/// @dev Tests public env-reading entrypoints locally; forge tests never broadcast to a network.
contract ScriptAuditTest is Test {
    XY internal xy;
    XY107 internal nft;
    address internal recipient = makeAddr("script-recipient");

    function setUp() public {
        vm.setEnv("X_ACCOUNT_ID", "xy107_2026");
        (xy, nft) = new Deploy().run();
        vm.setEnv("XY_ADDRESS", vm.toString(address(xy)));
        vm.setEnv("XY107_ADDRESS", vm.toString(address(nft)));
        vm.setEnv("RECIPIENT", vm.toString(recipient));
    }

    function testAudit_AllOperatorScriptEntrypoints() public {
        vm.deal(recipient, 4 ether);
        vm.prank(recipient);
        xy.contribute{value: 4 ether}();
        vm.setEnv("SLOT_INDEX", "2");
        new PaySlot().run();
        assertEq(recipient.balance, 4 ether);
        new ReleaseYu().run();
        vm.setEnv(
            "RECIPIENTS", string.concat(vm.toString(recipient), ",", vm.toString(DEFAULT_SENDER))
        );
        new DistributeSpreaders().run();
        new PayArtist().run();
        assertEq(xy.balanceOf(recipient), 2_080_000e8);

        vm.setEnv("X_ACCOUNT_ID", "audit-account");
        new SetXAccount().run();
        assertEq(xy.xAccount(), keccak256("audit-account"));
        vm.setEnv("TOKEN_ID", "1");
        vm.setEnv("TOKEN_NAME", "Songjiang");
        vm.setEnv("TOKEN_DESCRIPTION", "Final image");
        vm.setEnv("IMAGE_HASH", vm.toString(keccak256("image")));
        new CommitMetadata().run();
        (,, bytes32 committed) = nft.metadata(1);
        assertEq(committed, keccak256("image"));
        vm.setEnv("IMAGE_BASE_URI", "ipfs://images");
        new SetImageBaseURI().run();
        assertEq(nft.imageBaseURI(), "ipfs://images");
        vm.setEnv("CONTRACT_URI", "ipfs://collection");
        new SetContractURI().run();
        assertEq(nft.contractURI(), "ipfs://collection");
        vm.setEnv("NEW_ADMIN", vm.toString(recipient));
        new TransferAdmin().run();
        assertEq(xy.operator(), recipient);
        assertEq(xy.CREATOR(), DEFAULT_SENDER);
    }

    function testAudit_AllPermissionlessScriptEntrypoints() public {
        vm.warp(xy.ALLOCATION_DEADLINE());
        new BurnYu().run();
        new BurnSpreaderRemainder().run();
        new BurnSeedSupporterRemainder().run();
        for (uint256 id = 2; id <= 108; ++id) {
            address minter = address(uint160(10_000 + id));
            vm.deal(minter, 1 ether);
            vm.prank(minter);
            nft.mint{value: 1 ether}(id);
        }
        new BurnSongjiang().run();
        assertEq(xy.totalBurned(), 14_720_000e8);
        assertEq(xy.totalSupply(), 6_280_000e8);
    }
}
