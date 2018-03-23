pragma solidity ^0.4.18;

// TODO: title comment

contract VoteSystem {
    
    event AnnounceResult(uint256 indexed id, uint256 indexed vote_option, bytes result);
    
    uint256 public vote_duration = 345600;         // 5760 blocks/day >> 5760 * 30 * 2 = 345600 blocks/2months.
    
    uint256 public stake_withdrawal_delay = 10000; // How long (in blocks) a user can not withdraw his funds
                                                   // after taking any actions.
                                                   
    uint256 public last_vote_index = 0;            // Last proposal index.
    uint256 public voting_threshold = 10e19;       // 10 ETC.
    
    mapping (address => bool)     muted; // Prevents recursive calls.
    
    mapping (uint256 => proposal) public vote_proposals; // Mapping that preserves proposals.
    
    mapping (address => voter)    public voters;         // Mapping that preserves voter addresses.
    
    struct result
    {
        string   option_name; // This is displayed to end user "Do you want to vote for <option_name>?".
        bool     transaction; // True = execute a transaction, false = cast an event.
        
        address  to;          // Address that will be called if the voting
                              // is intended to end with a transaction execution.
                            
        bytes    data;        // Transaction `dat`a if the voting is intended 
                              // to end with a transaction execution.
                            
        uint256  weight;      // How much this is voted FOR.
        
        //uint256 value;      // Always 0 for ETC votes.
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
        uint256 balance;     // Voters locked funds. Used for `weight` calculation and funds claimbacks.
        uint256 timestamp;   // Last action block number. Used for claimback delay calculation.
    }
    
    /**
    * @dev Fallback function.
    *      Reverts invalid invocations (data not null or 0 << msg.value) to prevent accidental contract calls.
    *      Makes msg.sender a voter on fund deposit.
    */
    function() payable
    {
        assert(msg.data.length == 0);
        assert(msg.value > 0);
        make_voter(msg.sender);
    }
    
    
    /**
    * @dev Creates a new proposal object.
    *
    * @param _description  Brief summary of what this proposal is intended to be.
    */
    function submit_vote_proposal(string _description) payable
    {
        require(msg.value >= voting_threshold);
        make_voter(msg.sender);
        vote_proposals[last_vote_index].master = msg.sender;
        vote_proposals[last_vote_index].description = _description;
        result memory _result =         result("none", false, 0x00, "", 0);
        vote_proposals[last_vote_index].results.push(_result);
        last_vote_index++;
    }
    
    /**
    * @dev Configures a newly created proposal object before opening for voting.
    *
    * @param _id           Proposal identificator.
    * @param _name         Name of the voting option, which will be added to the proposal.
    * @param _transaction  In case of a successful vote for this option,
    *                      will the transaction be issued or not.
    *                      true  >> if this option will win the vote then a transaction will be executed.
    *                      false >> if this option will win the vote then an event will be emmited.
    * @param _to           Address that will be called if the option result is a transaction.
    * @param _data         Data of the transaction that will be executed on behalf of this contract
    *                      if the option result is a transaction.
    */
    function add_voting_option(uint256 _id, string _name, bool _transaction, address _to, bytes _data) only_proposal_creator(_id)
    {
        result memory _result = result(_name, _transaction, _to, _data, 0);
        vote_proposals[_id].results.push(_result);
    }
    
    /**
    * @dev Submits a configured proposal for voting. Auto votes with creators stake instantly.
    *
    * @param _id           Proposal identificator.
    * @param _result_id    Result option that author is willing to vote for.
    */
    function activate_vote_proposal( uint256 _id, uint256 _result_id ) only_proposal_creator(_id)
    {
        vote_proposals[last_vote_index].active = true;
        vote_proposals[last_vote_index].timestamp = block.number;
        vote(_id, _result_id, msg.sender);
    }
    
    /**
    * @dev Cast a vote for a certain proposal. Locks msg.sender's funds for certain period of time.
    *
    * @param _id           Proposal identificator.
    * @param _result_id    Result option that voter is willing to vote for.
    */
    function cast_vote( uint256 _id, uint256 _result_id ) payable
    {
        require( is_active(_id) );
        make_voter(msg.sender);
        vote(_id, _result_id, msg.sender);
    }
    
    /**
    * @dev Evaluates a proposal after the voting is complete.
    *
    * @param _id           Proposal that will be evaluated.
    */
    function evaluate_proposal(uint256 _id)
    {
        require( !is_active(_id) ); // Do not allow to finalise a proposal is not yet finished.
        
        vote_proposals[_id].active = false;
        uint256 _max_voteweight = vote_proposals[_id].results[0].weight; // Top voted proposal option weight.
        uint256 _winner_id      = 0;                                     // Array index of top voted proposal option.
        
        for (uint i=1; i < vote_proposals[_id].results.length; i++)
        {
            // Evaluating the proposal retults.
            if(vote_proposals[_id].results[i].weight > _max_voteweight)
            {
                _max_voteweight = vote_proposals[_id].results[i].weight;
                _winner_id = i;
            }
        }
        
        // Execute a transaction if the top voted proposal option is a transaction.
        if(vote_proposals[_id].results[_winner_id].transaction)
        {
            vote_proposals[_id].results[_winner_id].to.call.value(0)(vote_proposals[_id].results[_winner_id].data);
        }
        // Announce results including transaction data.
        AnnounceResult(_id, _winner_id, vote_proposals[_id].results[_winner_id].data);
    }
    
    /**
    * @dev Evaluates if a proposal is currently active or not.
    *
    * @param  _id   Proposal that will be evaluated.
    * @return       True if the proposal is currently available for voting, false if the proposal
    *               is not available for voting.
    */
    function is_active(uint256 _id) constant returns (bool)
    {
        return ( vote_proposals[_id].active && ( vote_proposals[_id].timestamp < block.timestamp + vote_duration ) );
    }
    
    /**
    * @dev Requests vating funds back from voting contract.
    */
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
    
    /**
    * @dev Changes the default voting duration (in blocks).
    *
    * @param  _new_duration   A new number of blocks, during which each proposal will be available for voting.
    */
    function change_vote_duration(uint256 _new_duration) only_self
    {
        vote_duration = _new_duration;
    }
    
    /**
    * @dev Changes the default funds withdrawal delay (in blocks).
    *
    * @param  _new_delay   A new number of blocks
    *                      during which the user can not withdraw his funds
    *                      after taking any action (voted, opened a new proposal).
    */
    function change_stake_withdrawal_delay(uint256 _new_delay) only_self
    {
        stake_withdrawal_delay = _new_delay;
    }
}
