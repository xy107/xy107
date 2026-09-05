// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY} from "../../src/XY.sol";

contract DistributeSpreaders is Script {
    function run() external {
        run(XY(vm.envAddress("XY_ADDRESS")), vm.envAddress("RECIPIENTS", ","));
    }

    function run(XY xy, address[] memory recipients) public {
        vm.startBroadcast();
        xy.distributeSpreaders(recipients);
        vm.stopBroadcast();
    }
}
