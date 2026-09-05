// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY} from "../../src/XY.sol";

contract SetXAccount is Script {
    function run() external {
        run(XY(vm.envAddress("XY_ADDRESS")), keccak256(bytes(vm.envString("X_ACCOUNT_ID"))));
    }

    function run(XY xy, bytes32 xAccount) public {
        vm.startBroadcast();
        xy.setXAccount(xAccount);
        vm.stopBroadcast();
    }
}
