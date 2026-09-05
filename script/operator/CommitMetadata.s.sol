// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XY107} from "../../src/XY107.sol";

contract CommitMetadata is Script {
    function run() external {
        run(
            XY107(vm.envAddress("XY107_ADDRESS")),
            vm.envUint("TOKEN_ID"),
            vm.envString("TOKEN_NAME"),
            vm.envString("TOKEN_DESCRIPTION"),
            vm.envBytes32("IMAGE_HASH")
        );
    }

    function run(
        XY107 xy107,
        uint256 tokenId,
        string memory name,
        string memory description,
        bytes32 imageHash
    ) public {
        vm.startBroadcast();
        xy107.commitMetadata(tokenId, name, description, imageHash);
        vm.stopBroadcast();
    }
}
