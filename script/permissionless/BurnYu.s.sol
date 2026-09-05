// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY} from "../../src/XY.sol";

contract BurnYu is Script {
    function run() external {
        run(XY(vm.envAddress("XY_ADDRESS")));
    }

    function run(XY xy) public {
        vm.startBroadcast();
        xy.burnYu();
        vm.stopBroadcast();
    }
}
