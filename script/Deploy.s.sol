// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY} from "../src/XY.sol";
import {XY107} from "../src/XY107.sol";

contract Deploy is Script {
    function run() external returns (XY xy, XY107 xy107) {
        return _deploy(keccak256(bytes(vm.envString("X_ACCOUNT_ID"))));
    }

    function _deploy(bytes32 xAccount) internal returns (XY xy, XY107 xy107) {
        vm.startBroadcast();
        xy = new XY("XY", "XY", xAccount);
        xy107 = new XY107("XY107", "XY107", address(xy));
        xy.setXy107(address(xy107));
        vm.stopBroadcast();
    }
}
