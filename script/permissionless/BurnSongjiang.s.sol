// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY107} from "../../src/XY107.sol";

contract BurnSongjiang is Script {
    function run() external {
        run(XY107(vm.envAddress("XY107_ADDRESS")));
    }

    function run(XY107 xy107) public {
        vm.startBroadcast();
        xy107.burnSongjiang();
        vm.stopBroadcast();
    }
}
