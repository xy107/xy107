// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY} from "../../src/XY.sol";

contract PayArtist is Script {
    function run() external {
        run(XY(vm.envAddress("XY_ADDRESS")), vm.envAddress("RECIPIENT"));
    }

    function run(XY xy, address recipient) public {
        vm.startBroadcast();
        xy.payArtist(recipient);
        vm.stopBroadcast();
    }
}
