pragma solidity ^0.4.18;

// TODO: title comment

contract VoteSystem {
    
    uint256 public vote_duration = 345600; // 5760 blocks/day >> 5760 * 30 * 2 = 345600 blocks/2months.
    uint256 public stake_withdrawal_delay = 10000;
    uint256 public last_vote_index = 0;
    uint256 public voting_threshold = 10e19; // 10 ETC.
    
    mapping (address => bool)     muted; // Prevents recursive calls.
    
    mapping (uint256 => proposal) public vote_proposals; // Mapping that preserves proposals.
    
    mapping (address => voter)    public voters;         // Mapping that preserves voter addresses.
    
    struct result
    {
        string option_name; // This is displayed to end user "Do you want to vote for <option_name>?".
        bool transaction;   // True = execute a transaction, false = cast an event.
        
        address to;         // Address that will be called if the voting
                            // is intended to end with a transaction execution.
                            
        bytes   data;       // Transaction `dat`a if the voting is intended 
                            // to end with a transaction execution.
                            
        uint256 weight;     // How much this is voted FOR.
        
        //uint256 value;    // Always 0 for ETC votes.
    }
    
    struct proposal
    {
        result[] results;      // Array of options that are available for vote.
                               // Example: Reduce block reward?
                               //          [0] to 1 ETC per block.
                               //          [2] to 2 ETC per block.
                               //          [3] leave as is.
    
        address  master;       // Voting creator.
        string   description;  // Description of the voting purpose.
                               // Example: "This is a voting to reduce block reward on ETC."
        uint256  timestamp;    // From this time, the voting is considered "active".
        bool     active;       // True >> currently votable, false << not votable.
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
    
    function submit_vote_proposal(string _description) payable
    {
        require(msg.value >= voting_threshold);
        make_voter(msg.sender);
        vote_proposals[last_vote_index].master = msg.sender;
        vote_proposals[last_vote_index].description = _description;
    }
    
    function add_voting_option(uint256 _id, string _name, bool _transaction, address _to, bytes _data) only_proposal_creator(_id)
    {
        result memory _result = result(_name, _transaction, _to, _data, 0);
        vote_proposals[_id].results.push(_result);
    }
    
    function activate_vote_proposal( uint256 _id, uint256 _result_id ) only_proposal_creator(_id)
    {
        vote_proposals[last_vote_index].active = true;
        vote_proposals[last_vote_index].timestamp = block.number;
        vote(_id, _result_id, msg.sender);
    }
    
    function cast_vote( uint256 _id, uint256 _result_id ) payable
    {
        require( is_active(_id) );
        make_voter(msg.sender);
        vote(_id, _result_id, msg.sender);
    }
    
    function is_active(uint256 _id) constant returns (bool)
    {
        return ( vote_proposals[_id].active && ( vote_proposals[_id].timestamp < block.timestamp + vote_duration ) );
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
    
    function vote(uint256 _id, uint256 _result_id, address _who) private
    {
        vote_proposals[_id].results[_result_id].weight += voters[_who].balance;
        //voters[_who].timestamp = block.number;
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
