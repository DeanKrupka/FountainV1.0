//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Fountain} from "../src/Fountain.sol";

contract DeployFountain is Script {
    function run() external returns (Fountain) {
        vm.startBroadcast();
        Fountain fountain = new Fountain();
        vm.stopBroadcast();
        return fountain;
    }
}
