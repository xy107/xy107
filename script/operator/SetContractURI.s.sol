// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY107} from "../../src/XY107.sol";

contract SetContractURI is Script {
    function run() external {
        run(XY107(vm.envAddress("XY107_ADDRESS")), vm.envString("CONTRACT_URI"));
    }

    function run(XY107 xy107, string memory contractUri) public {
        vm.startBroadcast();
        xy107.setContractURI(contractUri);
        vm.stopBroadcast();
    }
}
