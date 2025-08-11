// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/TileGame.sol";

contract DeployTileGame is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 subscriptionId = 15108255275766907245751257821482158770584873961783970832749530933736276488625;
        
        vm.startBroadcast(deployerPrivateKey);
        
        TileGame tileGame = new TileGame(subscriptionId);
        
        console.log("TileGame deployed at:", address(tileGame));
        console.log("Deployed by:", msg.sender);
        console.log("Subscription ID:", subscriptionId);
        
        vm.stopBroadcast();
    }
}