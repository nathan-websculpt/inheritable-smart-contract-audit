// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {InheritanceManager} from "../src/InheritanceManager.sol";

contract CounterScript is Script {
    InheritanceManager public inheritanceManger;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        inheritanceManger = new InheritanceManager();

        vm.stopBroadcast();
    }
}
