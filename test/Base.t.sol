// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XY as XYToken} from "../src/XY.sol";
import {XY107} from "../src/XY107.sol";

abstract contract BaseTest is Test {
    bytes32 internal constant X_ACCOUNT = keccak256("official-account-id");
    uint256 internal constant START_TIME = 1_790_000_000;

    address internal creator = makeAddr("creator");
    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    XYToken internal xy;
    XY107 internal nft;

    function setUp() public virtual {
        vm.warp(START_TIME);
        vm.startPrank(creator);
        xy = new XYToken("XY", "XY", X_ACCOUNT);
        nft = new XY107("XY107", "XY107", address(xy));
        xy.setXy107(address(nft));
        vm.stopPrank();
        vm.deal(alice, 1_000 ether);
        vm.deal(bob, 1_000 ether);
    }

    function _contribute(address contributor, uint256 amount) internal {
        vm.prank(contributor);
        xy.contribute{value: amount}();
    }

    function _recipients(uint256 count) internal pure returns (address[] memory result) {
        result = new address[](count);
        for (uint256 i; i < count; ++i) {
            result[i] = address(uint160(i + 1));
        }
    }
}

contract LinkedXyMock {
    address public immutable XY;

    constructor(address xy_) {
        XY = xy_;
    }
}
