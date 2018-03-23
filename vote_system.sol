pragma solidity ^0.4.18;

contract VoteSystem {
    
    uint256 public vote_duration = 345600; // 5760 blocks/day >> 5760 * 30 * 2 = 345600 blocks/2months.
    uint256 public stake_withdrawal_delay = 10000;
    uint256 public last_vote_index = 0;
    uint256 public voting_threshold = 10e19; // 10 ETC.
    
    mapping (address => bool) muted; // Prevents recursive calls.
    
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
        address  master;
        string   description;
        uint256  timestamp;
        bool     active;
    }
    
    struct voter
    {
        uint256 balance;
        uint256 timestamp;
    }
    
    function() payable
    {
        assert(msg.data.length == 0);
        assert(msg.value > 0);
        make_voter(msg.sender);
    }
    
    function submit_vote_proposal() payable
    {
        require(msg.value >= voting_threshold);
        make_voter(msg.sender);
    }
    
    function add_voting_option(uint256 _id, string _name, bool _transaction, address _to, bytes _data) only_proposal_creator(_id)
    {
        result memory _result = result(_name, _transaction, _to, _data);
        vote_proposals[_id].results.push(_result);
    }
    
    function start_vote_proposal( uint256 _id, uint256 _result_id ) only_proposal_creator(_id)
    {
        
    }
    
    function cast_vote( uint256 _id, uint256 _result_id ) payable
    {
        make_voter(msg.sender);
    }
    
    function withdraw_stake() mutex(msg.sender)
    {
        require(voters[msg.sender].timestamp < vote_duration + stake_withdrawal_delay);
        msg.sender.transfer(voters[msg.sender].balance);
        voters[msg.sender].balance = 0;
    }
    
    function make_voter(address _who) private
    {
        voters[_who].balance += msg.value;
        voters[_who].timestamp = block.number;
    }
    
    
    // DEBUGGING FUNCTIONALITY.
    
    modifier only_proposal_creator(uint256 _id)
    {
        require(vote_proposals[_id].master == msg.sender);
        _;
    }
    
    modifier only_self
    {
        require(msg.sender == address(this));
        _;
    }
    
    // Mutex to prevent recursive calls.
    modifier mutex(address _target)
    {
        if( muted[_target] )
        {
            revert();
        }
        
        muted[_target] = true;
        _;
        muted[_target] = false;
    }
    
    function change_vote_duration(uint256 _new_duration) only_self
    {
        vote_duration = _new_duration;
    }
    
    function change_stake_withdrawal_delay(uint256 _new_delay) only_self
    {
        stake_withdrawal_delay = _new_delay;
    }
}
