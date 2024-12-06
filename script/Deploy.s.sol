// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Baazi} from "../src/Baazi.sol";
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
contract Deploy is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        Baazi baazi = new Baazi();

        vm.stopBroadcast();

        console.log("Baazi deployed at", address(baazi));
    }
}
