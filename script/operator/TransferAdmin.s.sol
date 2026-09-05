// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY} from "../../src/XY.sol";

contract TransferAdmin is Script {
    function run() external {
        run(XY(vm.envAddress("XY_ADDRESS")), vm.envAddress("NEW_ADMIN"));
    }

    function run(XY xy, address newAdmin) public {
        vm.startBroadcast();
        xy.transferAdmin(newAdmin);
        vm.stopBroadcast();
    }
}
