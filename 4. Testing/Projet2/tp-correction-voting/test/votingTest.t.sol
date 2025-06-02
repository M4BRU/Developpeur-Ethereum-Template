// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Voting} from "src/voting.sol";

contract votingTest is Test
{
    //Events
    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint proposalId);
    event WorkflowStatusChange(Voting.WorkflowStatus previousStatus, Voting.WorkflowStatus newStatus);
    event Voted (address voter, uint proposalId);

    Voting voting;
    address private USER = makeAddr("USER");

    function setUp() public
    {
        voting = new Voting();
    }

    //MODIFIERS

    function testVotingIfModifierOnlyOwnerWork() public
    {
        vm.prank(USER);
        vm.expectRevert();
        voting.addVoter(USER);
    }

    function testVotingModifierOnlyVotersWork() public
    {
        voting.addVoter(USER);
        vm.expectRevert();
        voting.getVoter(USER);
    }

    //ADD VOTER

    function testVotingAddVoterRevertIfNotInGoodWorkflow() public
    {
        voting.startProposalsRegistering();
        vm.expectRevert();
        voting.addVoter(USER);
    }

    function testVotingAddVoterRevertIfVoterAlreadyAdded() public
    {
        voting.addVoter(USER);
        vm.expectRevert();
        voting.addVoter(USER);
    }

    function testVotingAddVoterIfVoterIsRegisteredTrueAfterAdd() public
    {
        voting.addVoter(USER);
        vm.prank(USER);
        assertEq(voting.getVoter(USER).isRegistered, true);
    }

    function testFuzzVotingAddVoterIfVoterIsRegisteredTrueAfterAdd(address voter) public
    {
        vm.assume(voter != address(0));
        voting.addVoter(voter);
        vm.prank(voter);
        assertEq(voting.getVoter(voter).isRegistered, true);
    }
    function testVotingAddVoterVoterRegisteredEmited() public
    {
        vm.expectEmit(true,false,false,false, address(voting));
        emit VoterRegistered(USER);
        voting.addVoter(USER);
    }

    


    //ADD PROPOSAL

    function testVotingAddProposalRevertIfNotInGoodWorkFlow() public
    {
        voting.addVoter(USER);
        vm.expectRevert();
        voting.addProposal("test");
    }

    modifier ProposalStarted()
    {
        voting.addVoter(USER);
        voting.startProposalsRegistering();
        _;
    }

    function testVotingAddProposalRevertIfDescriptionIsEmpty() public ProposalStarted
    {
        vm.expectRevert();
        voting.addProposal("");
    }

    function testVotingAddProposalIsAddedToList() public ProposalStarted
    {
        //vm.startPrank();
        vm.prank(USER);
        voting.addProposal("test");
        vm.prank(USER);
        string memory proposal = voting.getOneProposal(1).description;
        //vm.stopPrank();
        assertEq(proposal, "test");
    }

    function testFuzzVotingAddProposalIsAddedToList(string memory description) public ProposalStarted
    {
        vm.assume(keccak256(abi.encodePacked(description))  != keccak256(abi.encodePacked("")));
        //vm.startPrank();
        vm.prank(USER);
        voting.addProposal(description);
        vm.prank(USER);
        string memory proposal = voting.getOneProposal(1).description;
        //vm.stopPrank();
        assertEq(proposal, description);
    }

    function testVotingAddProposalEventEmited() public ProposalStarted
    {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(voting));
        emit ProposalRegistered(2);
        voting.addProposal("test");
    }


    //SET VOTE

    function testVotingSetVoteRevertIfNotGoodWorkflow() public
    {
        voting.addVoter(USER);
        vm.prank(USER);
        vm.expectRevert();
        voting.setVote(0);
    }

    modifier StartVoting()
    {
        voting.addVoter(USER);
        voting.startProposalsRegistering();
        vm.prank(USER);
        voting.addProposal("test");
        voting.endProposalsRegistering();
        voting.startVotingSession();
        _;
    }

    function testVotingSetVoterRevertIfAlreadyVoted() public StartVoting
    {
        
        vm.startPrank(USER);
        voting.setVote(0);
        vm.expectRevert();
        voting.setVote(0);
        vm.stopPrank();
    }

    function testVotingSetVoteRevertIfProposalIdIncorrect() public StartVoting
    {
        vm.prank(USER);
        vm.expectRevert();
        voting.setVote(10);
    }

    function testVotingSetVoteVoterAndProposalValuesChanged() public StartVoting
    {
        vm.startPrank(USER);
        voting.setVote(0);
        uint256 votedProposalId = voting.getVoter(USER).votedProposalId;
        bool hasVoted = voting.getVoter(USER).hasVoted;
        uint256 voteCount = voting.getOneProposal(0).voteCount;
        vm.stopPrank();
        assertEq(votedProposalId, 0);
        assertEq(hasVoted, true);
        assertEq(voteCount, 1);
    }

    function testVotingSetVoteEventEmited() public StartVoting
    {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(voting));
        emit Voted(address(this), 0);
        voting.setVote(0);
    }

    //START PROPOSALS REGISTERING

    function testVotingStartProposalRevertIfNotGoodWorkFlow() public
    {
        voting.startProposalsRegistering();
        voting.endProposalsRegistering();
        vm.expectRevert();
        voting.startProposalsRegistering();
    }

    function testVotingStartProposalWorkflowChanged() public
    {
        voting.startProposalsRegistering();
        assert(voting.workflowStatus() == Voting.WorkflowStatus.ProposalsRegistrationStarted);
    }

    function testVotingStartProposalGenesisProposalAdded() public
    {
        voting.addVoter(USER);
        voting.startProposalsRegistering();
        vm.prank(USER);
        string memory proposal = voting.getOneProposal(0).description;
        assert(keccak256(abi.encode(proposal)) == keccak256(abi.encode("GENESIS")) );
    }

    function testVotingStartProposalEventEmited() public
    {
        vm.expectEmit(true, true, false, false, address(voting));
        emit WorkflowStatusChange(Voting.WorkflowStatus.RegisteringVoters, Voting.WorkflowStatus.ProposalsRegistrationStarted);
        voting.startProposalsRegistering();
    }

    //END PROPOSALS REGISTERING

    

    function testVotingEndProposalRevertIfNotGodWorkflow() public StartVoting
    {
        vm.expectRevert();
        voting.endProposalsRegistering();
    }

    function testVotingEndProposalWorkflowChanged() public ProposalStarted
    {
        voting.endProposalsRegistering();
        assert(voting.workflowStatus() == Voting.WorkflowStatus.ProposalsRegistrationEnded);
    }

    function testVotingEndProposalEventEmited() public ProposalStarted
    {
        vm.expectEmit(true, true, false, false, address(voting));
        emit WorkflowStatusChange(Voting.WorkflowStatus.ProposalsRegistrationStarted, Voting.WorkflowStatus.ProposalsRegistrationEnded);
        voting.endProposalsRegistering();
    }

    //START VOTING SESSION

    function testVotingStartVotingRevertifNotGoodWorkflow() public
    {
        vm.expectRevert();
        voting.startVotingSession();
    }

    function testVotingStartVotingWorkflowChanged() public ProposalStarted
    {
        voting.endProposalsRegistering();
        voting.startVotingSession();
        assert(voting.workflowStatus() == Voting.WorkflowStatus.VotingSessionStarted);
    }

    function testVotingStartVotingEventEmited() public ProposalStarted
    {
        voting.endProposalsRegistering();
        vm.expectEmit(true, true, false, false, address(voting));
        emit WorkflowStatusChange(Voting.WorkflowStatus.ProposalsRegistrationEnded, Voting.WorkflowStatus.VotingSessionStarted);
        voting.startVotingSession();
    }

    //END VOTING SESSION

    function testVotingEndVotingRevertifNotGoodWorkflow() public
    {
        vm.expectRevert();
        voting.endVotingSession();
    }

    function testVotingEndVotingWorkflowChanged() public ProposalStarted
    {
        voting.endProposalsRegistering();
        voting.startVotingSession();
        voting.endVotingSession();
        assert(voting.workflowStatus() == Voting.WorkflowStatus.VotingSessionEnded);
    }

    function testVotingEndVotingEventEmited() public ProposalStarted
    {
        voting.endProposalsRegistering();
        voting.startVotingSession();
        vm.expectEmit(true, true, false, false, address(voting));
        emit WorkflowStatusChange(Voting.WorkflowStatus.VotingSessionStarted, Voting.WorkflowStatus.VotingSessionEnded);
        voting.endVotingSession();
    }

    //TALLY VOTES

    function testVotingTallyVotesRevertIfNotGoodWorkflow() public 
    {
        vm.expectRevert();
        voting.tallyVotes();
    }

    function testVotingTallyVotesWinningProposalIdAndWorkflowChanged() public StartVoting
    {
        vm.prank(USER);
        voting.setVote(1);
        voting.endVotingSession();
        voting.tallyVotes();
        assertEq(voting.winningProposalID(), 1);
        assert(voting.workflowStatus() == Voting.WorkflowStatus.VotesTallied);
    }

    function testVotingTallyVotesWorkflowEventEmited() public StartVoting
    {
        vm.prank(USER);
        voting.setVote(1);
        voting.endVotingSession();
        vm.expectEmit(true, true, false, false, address(voting));
        emit WorkflowStatusChange(Voting.WorkflowStatus.VotingSessionEnded, Voting.WorkflowStatus.VotesTallied);
        voting.tallyVotes();
    }

    function testVotingTallyVotesWithEquality() public
    {       
        address USER2 = makeAddr("USER2");

        voting.addVoter(USER);
        voting.addVoter(USER2);

        voting.startProposalsRegistering();

        vm.prank(USER);
        voting.addProposal("test1");

        vm.prank(USER2);
        voting.addProposal("test2");

        voting.endProposalsRegistering();
        voting.startVotingSession();

        vm.prank(USER);
        voting.setVote(1);

        vm.prank(USER2);
        voting.setVote(2);

        voting.endVotingSession();
        voting.tallyVotes();

        uint winningProposalId = voting.winningProposalID();
        vm.startPrank(USER);
        uint voteCount1 = voting.getOneProposal(1).voteCount;
        uint voteCount2 = voting.getOneProposal(2).voteCount;
        vm.stopPrank();

        assertEq(voteCount1, voteCount2);
        assertTrue(winningProposalId == 1 || winningProposalId == 2);
    }

}

