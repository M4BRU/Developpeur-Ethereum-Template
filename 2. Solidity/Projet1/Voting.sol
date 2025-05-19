// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable
{
    //error
    error Voting__VoterAlreadyAdded();
    error Voting__CantStartProposalRegistration();
    error Voting__NotInRegisteringVoterWorkflow();
    error Voting__VoterNotInWhitelist();
    error Voting__NotGoodWorkflow();
    error Voting__FinalWorkflowReached();
    error Voting__DontHaveWinnerYet();
    error Voting__VoterAlreadyVoted();
    error Voting__VoterHasAlreadyProposed();

    //types
    struct Voter
    {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    struct Proposal
    {
        string description;
        uint voteCount;
    }
    enum WorkFlowStatus
    {
        RegisteringVoters, 
        ProposalsRegistrationStarted,
        ProposalRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        Votesallied
    }
    WorkFlowStatus public s_workFlowStatus;
    mapping(address => Voter) public s_whitelist;
    mapping(uint => address) public s_ProposalToVoter;
    mapping(address => bool) private hasProposed;
    Proposal[] public s_proposalList;
    uint private s_winningProposalId;

    //event
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkFlowStatus previousStatus, WorkFlowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    modifier CheckIfWhiteListedAndInGoodWorkflow(WorkFlowStatus WorkFlowAttend)
    {
        if(!s_whitelist[msg.sender].isRegistered)
        {
            revert Voting__VoterNotInWhitelist();
        }

        if(s_workFlowStatus != WorkFlowAttend)
        {
            revert Voting__NotGoodWorkflow();
        }
        _;
    }


    //cosntructor
    constructor() Ownable(msg.sender){
        s_workFlowStatus = WorkFlowStatus.RegisteringVoters;
        s_whitelist[msg.sender].isRegistered = true;
    }

    function RegisterVoter(address _addressVoter) external onlyOwner
    {
        if(s_workFlowStatus != WorkFlowStatus.RegisteringVoters)
        revert Voting__NotInRegisteringVoterWorkflow();
        if (s_whitelist[_addressVoter].isRegistered)
            revert Voting__VoterAlreadyAdded();

        s_whitelist[_addressVoter].isRegistered = true;

        emit VoterRegistered(_addressVoter);
        
    }

    function GoNextWorkflow() external onlyOwner
    {
        WorkFlowStatus currentWorkFlow = s_workFlowStatus;
        if (currentWorkFlow == WorkFlowStatus.RegisteringVoters){
            StartProposalRegistration();
        }
        else if (currentWorkFlow == WorkFlowStatus.ProposalsRegistrationStarted){
            EndStartProposalRegistration();
        }
        else if (currentWorkFlow == WorkFlowStatus.ProposalRegistrationEnded){
            StartVotingSession();
        }
        else if (currentWorkFlow == WorkFlowStatus.VotingSessionStarted){
            EndVotingSession();
        }
        else if (currentWorkFlow == WorkFlowStatus.VotingSessionEnded){
            CountVotes();
            ResultVotes();
        }
        else 
            revert Voting__FinalWorkflowReached();
    }

    function StartProposalRegistration() internal onlyOwner
    {
        ChangeWorkflow(WorkFlowStatus.RegisteringVoters, WorkFlowStatus.ProposalsRegistrationStarted);        
    }
    function EndStartProposalRegistration() internal onlyOwner
    {
        ChangeWorkflow(WorkFlowStatus.ProposalsRegistrationStarted, WorkFlowStatus.ProposalRegistrationEnded);        
    }

    function StartVotingSession() internal onlyOwner
    {
        ChangeWorkflow(WorkFlowStatus.ProposalRegistrationEnded, WorkFlowStatus.VotingSessionStarted);
    }
    function EndVotingSession() internal onlyOwner
    {
        ChangeWorkflow(WorkFlowStatus.VotingSessionStarted, WorkFlowStatus.VotingSessionEnded);
    }
    function ResultVotes() internal onlyOwner
    {
        ChangeWorkflow(WorkFlowStatus.VotingSessionEnded, WorkFlowStatus.Votesallied);
    }
    
    function CountVotes() internal onlyOwner
    {
        uint max = 0;
        uint idMax = 0;
        for(uint i = 0; i < s_proposalList.length; i++)
        {
            if(s_proposalList[i].voteCount > max)
                max = s_proposalList[i].voteCount;
        }
        s_winningProposalId = idMax;
    }

    function DoProposalRegistration(string memory proposalText) external CheckIfWhiteListedAndInGoodWorkflow(WorkFlowStatus.ProposalsRegistrationStarted)
    {
        if(hasProposed[msg.sender])
            revert Voting__VoterHasAlreadyProposed();
        
        Proposal memory _proposal;
        _proposal.description = proposalText;
        s_proposalList.push(_proposal);

        uint proposalId = s_proposalList.length - 1;
        s_ProposalToVoter[proposalId] = msg.sender;
        hasProposed[msg.sender] = true;

        emit ProposalRegistered(proposalId);
    }

    function Vote(uint proposalId) external CheckIfWhiteListedAndInGoodWorkflow(WorkFlowStatus.VotingSessionStarted)
    {
        if(s_whitelist[msg.sender].hasVoted)
        {
            revert Voting__VoterAlreadyVoted();
        }
        s_proposalList[proposalId].voteCount++;
        s_whitelist[msg.sender].hasVoted = true;
        s_whitelist[msg.sender].votedProposalId = proposalId;

        emit Voted(msg.sender, proposalId);
    }


    function ChangeWorkflow(WorkFlowStatus previousWorkFlow,WorkFlowStatus newWorkFlow) internal 
    {
        s_workFlowStatus = newWorkFlow;

        emit WorkflowStatusChange(previousWorkFlow, newWorkFlow);
    }

    function getWinner() external view  returns(uint, address)
    {
        if(s_workFlowStatus != WorkFlowStatus.Votesallied)
            revert Voting__DontHaveWinnerYet();
        return (s_winningProposalId,s_ProposalToVoter[s_winningProposalId]);
    }

    
}