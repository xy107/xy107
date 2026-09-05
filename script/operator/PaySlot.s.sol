// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY} from "../../src/XY.sol";

contract PaySlot is Script {
    function run() external {
        run(XY(vm.envAddress("XY_ADDRESS")), vm.envUint("SLOT_INDEX"), vm.envAddress("RECIPIENT"));
    }

    function run(XY xy, uint256 index, address recipient) public {
        vm.startBroadcast();
        xy.paySlot(index, recipient);
        vm.stopBroadcast();
    }
}
