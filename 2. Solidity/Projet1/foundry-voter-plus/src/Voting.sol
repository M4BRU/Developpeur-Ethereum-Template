// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/Script.sol";

contract Voting is VRFConsumerBaseV2Plus
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
    error Voting__ProposalAlreadyExist();
    error Voting__NotEnoughPlayers();
    
    error Voting__NobodyVoteResetOfContract();

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
        VotesAllied
    }
    
    uint256 private constant INVALID_ID = type(uint).max;
    WorkFlowStatus private s_workFlowStatus;
    mapping(address => Voter) private s_whitelist;
    address[] private s_whitelistAddresses;
    mapping(uint256 => address) private s_ProposalToVoter;
    mapping(address => bool) private s_hasProposed;
    Proposal[] private s_proposalList;
    uint private s_winningProposalId = INVALID_ID;
    bool private s_isWinnerDecided;
    uint[] private s_indexOfWinners;
    uint256 public s_nbPlayers;
    uint256 private s_nbPersonWhoVote;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;

    //event
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkFlowStatus previousStatus, WorkFlowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event RequestedVotingWinner(uint256 indexed requestId);
    event ProposalIdVoted(uint256 proposalId);
    event AllVariablesReinitialized();
    event Voting__NoVoteToProposalsResetOfContract();
    event Voting__NoProposalResetOfContract();

    //cosntructor
    constructor(uint256 entranceFee, uint interval, address vrfCoordinator,  bytes32 gasLane, uint256 subId, uint32 callBackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator){
        s_workFlowStatus = WorkFlowStatus.RegisteringVoters;
        //s_whitelist[msg.sender].isRegistered = true;
        i_interval = interval;
        i_entranceFee = entranceFee;
        i_keyHash = gasLane;
        i_subscriptionId = subId;
        i_callBackGasLimit = callBackGasLimit;

        s_workFlowStatus = WorkFlowStatus.RegisteringVoters;
    }

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

    


    

    function RegisterVoter(address _addressVoter) external onlyOwner
    {
        if(s_workFlowStatus != WorkFlowStatus.RegisteringVoters)
        revert Voting__NotInRegisteringVoterWorkflow();
        if (s_whitelist[_addressVoter].isRegistered)
            revert Voting__VoterAlreadyAdded();

        s_whitelist[_addressVoter].isRegistered = true;
        s_nbPlayers++;
        s_whitelistAddresses.push(_addressVoter);

        emit VoterRegistered(_addressVoter);
        
    }

    function DoProposalRegistration(string memory proposalText) external CheckIfWhiteListedAndInGoodWorkflow(WorkFlowStatus.ProposalsRegistrationStarted)
    {
        if(s_hasProposed[msg.sender])
            revert Voting__VoterHasAlreadyProposed();
        if(CheckIfProposalAlreadyExist(proposalText))
            revert Voting__ProposalAlreadyExist();
        
        
        Proposal memory _proposal;
        _proposal.description = proposalText;
        s_proposalList.push(_proposal);

        uint proposalId = s_proposalList.length - 1;
        s_ProposalToVoter[proposalId] = msg.sender;
        s_hasProposed[msg.sender] = true;

        emit ProposalRegistered(proposalId);
    }

    function CheckIfProposalAlreadyExist(string memory proposal) internal view returns(bool)
    {
        for(uint256 i = 0; i < s_proposalList.length; i++)
        {
            if(CompareStrings(proposal, s_proposalList[i].description))
                return true;
                
        }
        return false;
    }

    
    function CountVotes() internal onlyOwner
    {
        uint max = 0;
        uint256 winnerCount;

        for(uint i = 0; i < s_proposalList.length; i++)
        {
            if(s_proposalList[i].voteCount > max)
            {
                max = s_proposalList[i].voteCount;
                winnerCount = 1;
            }             
            else if(s_proposalList[i].voteCount == max)
                winnerCount++;
        }
        
        if(winnerCount == 0)
        {
            ChangeWorkflow(WorkFlowStatus.VotingSessionStarted, WorkFlowStatus.RegisteringVoters);
            revert Voting__NobodyVoteResetOfContract();
        }

        for(uint i = 0; i < s_proposalList.length; i++)
        {
            if(s_proposalList[i].voteCount == max)
                s_indexOfWinners.push(i);
        }
        if(s_indexOfWinners.length > 1)
        {
            ChooseRandomWinner();
        }
        else if (s_indexOfWinners.length == 1)
        {
            s_winningProposalId = s_indexOfWinners[0];
            s_isWinnerDecided = true;
        }
        
    }

    function ChooseRandomWinner() private 
    {
        //console.log("SUBSCRIPTIONID = ", i_subscriptionId);

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callBackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )});
        
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedVotingWinner(requestId);
    }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override
    {
        uint256 random = randomWords[0] % s_indexOfWinners.length;

        s_winningProposalId = random;
        s_isWinnerDecided = true;
        //address VoterWinner = s_ProposalToVoter[random];
        ResultVotes();
        emit ProposalIdVoted(random);
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
        s_nbPersonWhoVote++;

        emit Voted(msg.sender, proposalId);
    }


    function ChangeWorkflow(WorkFlowStatus previousWorkFlow,WorkFlowStatus newWorkFlow) internal 
    {
        s_workFlowStatus = newWorkFlow;

        emit WorkflowStatusChange(previousWorkFlow, newWorkFlow);
    }

    function CompareStrings(string memory string1, string memory string2) private pure returns(bool)
    {
        return keccak256(abi.encodePacked(string1)) == keccak256(abi.encodePacked(string2));
    }

    function getWinner() external view  returns(uint, address)
    {
        if(s_workFlowStatus != WorkFlowStatus.VotesAllied)
            revert Voting__DontHaveWinnerYet();
        return (s_winningProposalId,s_ProposalToVoter[s_winningProposalId]);
    }

    function GoNextWorkflow() external onlyOwner
    {
        WorkFlowStatus currentWorkFlow = s_workFlowStatus;
        if (currentWorkFlow == WorkFlowStatus.RegisteringVoters){
            if(s_nbPlayers == 0)
                revert Voting__NotEnoughPlayers();
            StartProposalRegistration();
        }
        else if (currentWorkFlow == WorkFlowStatus.ProposalsRegistrationStarted){
            if(s_proposalList.length == 0)
            {
                ResetVoting(WorkFlowStatus.ProposalsRegistrationStarted);
                emit Voting__NoProposalResetOfContract();
            }
                
            EndStartProposalRegistration();
        }
        else if (currentWorkFlow == WorkFlowStatus.ProposalRegistrationEnded){    
            StartVotingSession();
        }
        else if (currentWorkFlow == WorkFlowStatus.VotingSessionStarted){
            if(s_nbPersonWhoVote == 0)
            {
                ResetVoting(WorkFlowStatus.VotingSessionStarted);
                emit Voting__NoVoteToProposalsResetOfContract();
            }
            
            EndVotingSession();
        }
        else if (currentWorkFlow == WorkFlowStatus.VotingSessionEnded){
            CountVotes();
            if(s_isWinnerDecided)
            {
                ResultVotes();  
            }
        }
        else if(currentWorkFlow == WorkFlowStatus.VotesAllied)
        {
            ResetVoting(WorkFlowStatus.VotesAllied);
        }
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
    function ResultVotes() internal onlyOwnerOrCoordinator
    {
        ChangeWorkflow(WorkFlowStatus.VotingSessionEnded, WorkFlowStatus.VotesAllied);
    }
    function ResetVoting(WorkFlowStatus workFlowActuel) internal onlyOwner
    {
        for(uint i = 0; i < s_whitelistAddresses.length; i++)
        {
            delete s_hasProposed[s_whitelistAddresses[i]];
            delete s_whitelist[s_whitelistAddresses[i]];
        }

        for(uint i = 0; i < s_proposalList.length; i++)
        {
            delete s_ProposalToVoter[i];
        }

        delete s_whitelistAddresses;
        delete s_proposalList;
        delete s_indexOfWinners;
        s_nbPlayers = 0;
        s_isWinnerDecided = false;
        s_winningProposalId = INVALID_ID;
        s_nbPersonWhoVote = 0;


        emit AllVariablesReinitialized();
        
        ChangeWorkflow(workFlowActuel, WorkFlowStatus.RegisteringVoters);
    }

    function getWorkFlowStatus() external view returns(WorkFlowStatus)
    {
        return s_workFlowStatus;
    }
    function getStatusOfAdressIfWhitelist(address _addr) external view returns(bool)
    {
        return s_whitelist[_addr].isRegistered;
    }
    function getProposal(uint256 i) external view returns(string memory)
    {
        return s_proposalList[i].description;
    }
    function getProposalIdWinner() external view returns(uint256)
    {
        return s_winningProposalId;
    }
    function getIsWinnerDecided() external view returns(bool)
    {
        return s_isWinnerDecided;
    }
    function getWhitelistAddresses() external view returns(address[] memory) 
    {
        return s_whitelistAddresses;
    }
    function getProposalToVoter(uint256 i) external view returns(address)
    {
        return s_ProposalToVoter[i];
    }
    function getIndexOfWinners() external view returns(uint[] memory)
    {
        return s_indexOfWinners;
    }
}