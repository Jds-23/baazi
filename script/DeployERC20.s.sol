// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "../test/mock/Token.sol";
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
contract Deploy is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        Token token = new Token("Test Token");
        token.approve(
            address(0xf8e930bD0f87b326df26C49eC97Dd88D1FB3809f),
            type(uint256).max
        );
        vm.stopBroadcast();

        console.log("Token deployed at", address(token));
    }
}
