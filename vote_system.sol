pragma solidity ^0.4.18;

contract VoteSystem {
    
    uint256 public vote_duration = 345600; // 5760 blocks/day >> 5760 * 30 * 2 = 345600 blocks/2months.
    uint256 public last_vote_index = 0;
    
    mapping (uint256 => result[]) public votes;
    mapping (address => uint256)  public balances;
    
    struct result
    {
        string option_name;
        string description;
        bytes  data;
    }
    
    function submit_vote() payable
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
