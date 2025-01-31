// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Badges} from "../src/Badges.sol";

contract DeployBadges is Script {
    address trustedAuthority = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address owner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    function run() external {
        vm.startBroadcast();

        Badges badges = new Badges();
        badges.initialize(trustedAuthority, owner);

        vm.stopBroadcast();
    }
}
