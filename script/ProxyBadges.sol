// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Badges} from "../src/Badges.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployBadges is Script {
    address trustedAuthority = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address owner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    function run() external {
        vm.startBroadcast();

        // Deploy the logic contract (Implementation)
        Badges badgesImplementation = new Badges();

        // Deploy the proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(badgesImplementation),
            abi.encodeWithSignature("initialize(address,address)", trustedAuthority, owner)
        );

        // Cast the proxy address to Badges contract to interact with it
        Badges badges = Badges(address(proxy));

        console.log("Deployed Badges at:", address(badges));
        console.log("Trusted Authority:", badges.trustedAuthority());

        vm.stopBroadcast();
    }
}
