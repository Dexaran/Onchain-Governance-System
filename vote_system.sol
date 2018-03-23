pragma solidity ^0.4.18;

contract VoteSystem {
    
    uint256 public vote_duration = 345600; // 5760 blocks/day >> 5760 * 30 * 2 = 345600 blocks/2months.
    uint256 public last_vote_index = 0;
    uint256 public voting_threshold = 10e19; // 10 ETC.
    
    mapping (uint256 => proposal) public vote_proposals;
    
    mapping (address => voter)  public voters;
    
    struct result
    {
        string option_name;
        bool transaction; // true = execute a transaction, false = cast an event
        
        address to;
        bytes   data;
        //uint256 value;    // always 0 for ETC votes.
    }
    
    struct proposal
    {
        result[] results;
        string   description;
        uint256  timestamp;
    }
    
    struct voter
    {
        uint256 balance;
        uint256 timestamp;
    }
    
    function submit_vote() payable
    {
        require(msg.value >= voting_threshold);
        
    }
    
    function cast_vote(uint256 _voting_index, uint256 _voting_result) payable
    {
        
    }
    
    
    // DEBUGGING FUNCTIONALITY.
    
    modifier only_self
    {
        require(msg.sender == address(this));
        _;
    }
    
    function change_vote_duration(uint256 _new_duration) only_self
    {
        vote_duration = _new_duration;
    }
}
