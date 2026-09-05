// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {XY} from "../src/XY.sol";
import {XY107} from "../src/XY107.sol";

contract DeployTest is Test {
    function testRunDeploysAndLinksContracts() public {
        address creator = DEFAULT_SENDER;
        string memory xAccountId = "xy107_2026";
        bytes32 xAccount = keccak256(bytes(xAccountId));
        vm.setEnv("X_ACCOUNT_ID", xAccountId);

        (XY xy, XY107 xy107) = new Deploy().run();

        assertEq(xy.CREATOR(), creator);
        assertEq(xy.xAccount(), xAccount);
        assertEq(xy.xy107(), address(xy107));
        assertEq(address(xy107.XY()), address(xy));
    }
}
