//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployVoting} from "script/DeployVoting.s.sol";
import {Voting} from "src/Voting.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants
{
    Voting public voting;
    HelperConfig public helperConfig;
    address owner;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RequestedVotingWinner(uint256 indexed requestId);
    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint proposalId);
    event AllVariablesReinitialized();

    function setUp() external
    {
        DeployVoting deployer = new DeployVoting();
        (voting, helperConfig) = deployer.DeployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        owner = helperConfig.getConfig().account;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testVotingInitializesInRegisteringVotersState()public view
    {
        assert(voting.getWorkFlowStatus() == Voting.WorkFlowStatus.RegisteringVoters);
    }

    function testVotingAcceptRegisterVoterIfOwner() public
    {
        vm.prank(owner);
        voting.RegisterVoter(PLAYER);
        assert(voting.getStatusOfAdressIfWhitelist(PLAYER));
    }

    function testVotingRefuseRegisterVoterIfNotOwner() public
    {
        vm.prank(PLAYER);
        vm.expectRevert();
        voting.RegisterVoter(PLAYER);
        
    }

    function testVotingIfProposalIsRecordedAfterSend() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(PLAYER);
        voting.GoNextWorkflow();
        vm.stopPrank();
        string memory testString = "test";
        vm.prank(PLAYER);
        voting.DoProposalRegistration(testString);
        assert(keccak256(bytes(voting.getProposal(0))) == keccak256(bytes(testString)));
    }

    function testVotingDoProposalRevertIfAlreadyProposed() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(PLAYER);
        voting.GoNextWorkflow();
        vm.stopPrank();
        string memory testString1 = "test1";
        string memory testString2 = "test2";
        vm.startPrank(PLAYER);
        voting.DoProposalRegistration(testString1);
        vm.expectRevert(Voting.Voting__VoterHasAlreadyProposed.selector);
        voting.DoProposalRegistration(testString2);
        vm.stopPrank();
    }

    function testVotingDoProposalRevertIfProposalAlreadyExist() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(address(1));
        voting.RegisterVoter(address(2));
        voting.GoNextWorkflow();
        vm.stopPrank();
        string memory testString = "test";
        vm.startPrank(address(1));
        voting.DoProposalRegistration(testString);
        vm.expectRevert(Voting.Voting__ProposalAlreadyExist.selector);
        vm.startPrank(address(2));
        voting.DoProposalRegistration(testString);
        vm.stopPrank();
    }

    function testVotingDontAllowToVoteTwice() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(PLAYER);
        voting.GoNextWorkflow();
        vm.stopPrank();
        string memory testString = "test";
        vm.prank(PLAYER);
        voting.DoProposalRegistration(testString);
        vm.startPrank(owner);
        voting.GoNextWorkflow();
        voting.GoNextWorkflow();
        vm.stopPrank();
        vm.startPrank(PLAYER);
        voting.Vote(0);
        vm.expectRevert(Voting.Voting__VoterAlreadyVoted.selector);
        voting.Vote(0);
        vm.stopPrank();
    }

    function testVotingDoProposalEmitsEvent() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(PLAYER);
        voting.GoNextWorkflow();
        vm.stopPrank();
        string memory testString = "test";
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(voting));
        emit ProposalRegistered(0);
        voting.DoProposalRegistration(testString);
    }

    //RegisterVoter

        function testVotingDontAllowToRegisterVoterIfNotGoodWorkflow() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(address(1));
        voting.GoNextWorkflow();
        vm.expectRevert(Voting.Voting__NotInRegisteringVoterWorkflow.selector);
        voting.RegisterVoter(address(2));
        vm.stopPrank();
    }

    function testVotingDontAllowToRegisterVoterIfAlreadyAdded() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(address(1));
        vm.expectRevert(Voting.Voting__VoterAlreadyAdded.selector);
        voting.RegisterVoter(address(1));
    }

    function testRegisterVoterEmitsEvent() public
    {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false, address(voting));
        emit VoterRegistered(PLAYER);
        voting.RegisterVoter(PLAYER);
    }



    function testVotingCheckWhiteListRevert() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(PLAYER);
        voting.GoNextWorkflow();
        vm.stopPrank();
        string memory testString = "test";
        vm.expectRevert(Voting.Voting__VoterNotInWhitelist.selector);
        vm.prank(owner);
        voting.DoProposalRegistration(testString);
    }

    function testVotingCheckGoodWorkflowRevert() public
    {
        vm.prank(owner);
        voting.RegisterVoter(PLAYER);
        string memory testString = "test";
        vm.expectRevert();
        vm.prank(PLAYER);
        voting.DoProposalRegistration(testString);
    }



    modifier skipFork()
    {
        if(block.chainid != LOCAL_CHAIN_ID)
            return;
        _;
    }

    modifier MakeEqualityInVoting()
    {
        vm.startPrank(owner);
        voting.RegisterVoter(address(1));
        voting.RegisterVoter(address(2));
        voting.GoNextWorkflow();
        vm.stopPrank();
        vm.prank(address(1));
        voting.DoProposalRegistration("test1");
        vm.prank(address(2));
        voting.DoProposalRegistration("test2");
        vm.startPrank(owner);
        voting.GoNextWorkflow();
        voting.GoNextWorkflow();
        vm.stopPrank();
        vm.prank(address(1));
        voting.Vote(0);
        vm.prank(address(2));
        voting.Vote(1);
        vm.prank(owner);
        voting.GoNextWorkflow();
        _;
    }
    function testVotingCountVotesReturnWinnerWhenNotEquality() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(address(1));
        voting.RegisterVoter(address(2));
        voting.GoNextWorkflow();
        vm.stopPrank();
        string memory stringTest1 = "test1";
        string memory stringTest2 = "test2";
        vm.prank(address(1));
        voting.DoProposalRegistration(stringTest1);
        vm.prank(address(2));
        voting.DoProposalRegistration(stringTest2);
        vm.startPrank(owner);
        voting.GoNextWorkflow();
        voting.GoNextWorkflow();
        vm.stopPrank();
        vm.prank(address(1));
        voting.Vote(1);
        vm.prank(address(2));
        voting.Vote(1);
        vm.startPrank(owner);
        voting.GoNextWorkflow();
        voting.GoNextWorkflow();
        vm.stopPrank();
        (uint256 winnerId,) = voting.getWinner();
        assert(keccak256(bytes(voting.getProposal(winnerId))) == keccak256(bytes(stringTest2)));
    }   

    function testVotingEqualityBetweenTwoProposalEmitsRequestId() public skipFork MakeEqualityInVoting
    {
        
        vm.recordLogs();
        vm.prank(owner);
        voting.GoNextWorkflow();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(uint256(requestId) > 0);
    }

    function testFulfillrandomWordsPicksAWinner() public skipFork MakeEqualityInVoting
    {
        vm.recordLogs();
        vm.prank(owner);
        voting.GoNextWorkflow();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(voting));

        Voting.WorkFlowStatus workFlow = voting.getWorkFlowStatus();

        assert(workFlow == Voting.WorkFlowStatus.VotesAllied);
        address winner = voting.getProposalToVoter(voting.getProposalIdWinner());
        assert(winner != address(0));
        assert(voting.getIsWinnerDecided());
    }

    function testVotingVerifyDontWinnerIfNoFulfill() public skipFork MakeEqualityInVoting
    {
        vm.prank(owner);
        assert(!voting.getIsWinnerDecided());
    }


    function testVotingAllVariablesArReinitialized() public
    {
        vm.startPrank(owner);
        voting.RegisterVoter(PLAYER);
        voting.GoNextWorkflow();
        vm.stopPrank();
        string memory testString = "test";
        vm.prank(PLAYER);
        voting.DoProposalRegistration(testString);
        vm.startPrank(owner);
        voting.GoNextWorkflow();
        voting.GoNextWorkflow();
        vm.stopPrank();
        vm.startPrank(PLAYER);
        voting.Vote(0);
        vm.startPrank(owner);
        voting.GoNextWorkflow();
        voting.GoNextWorkflow();
        vm.expectEmit(false,false,false,false, address(voting));
        emit AllVariablesReinitialized();
        voting.GoNextWorkflow();
        vm.stopPrank();
        assert(!voting.getStatusOfAdressIfWhitelist(PLAYER));
        assert(voting.getIndexOfWinners().length == 0);
        assert(voting.getIsWinnerDecided() == false);
        assert(voting.getProposalIdWinner() == type(uint).max);
    }

}