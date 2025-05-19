// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {Voting} from "src/Voting.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployVoting is Script
{
    function run() public
    {
            DeployContract();
    }

    function DeployContract() public returns(Voting, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

    if(config.subscriptionId == 0)
    {
        CreateSubscription createSubscription = new CreateSubscription();
        (config.subscriptionId, config.vrfCoordinator) = 
            createSubscription.createSubscription(config.vrfCoordinator, config.account);

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
    }

        vm.startBroadcast(config.account);
        Voting voting = new Voting(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(voting), config.vrfCoordinator, config.subscriptionId, config.account);

        return (voting, helperConfig);
    }
}