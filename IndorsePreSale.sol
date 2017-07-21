pragma solidity ^0.4.11;

contract SafeMath {
    function safeAdd(uint256 x, uint256 y) internal returns(uint256) {
      uint256 z = x + y;
      assert((z >= x) && (z >= y));
      return z;
    }

    function safeSubtract(uint256 x, uint256 y) internal returns(uint256) {
      assert(x >= y);
      uint256 z = x - y;
      return z;
    }

    function safeMult(uint256 x, uint256 y) internal returns(uint256) {
      uint256 z = x * y;
      assert((x == 0)||(z/x == y));
      return z;
    }
}

contract IndorsePreSale is SafeMath {
    // Fund deposit address
    address public ethFundDeposit;                              // deposit address for ETH for Indorse
    address public owner;                                       // Owner of the pre sale contract

    // presale parameters
    bool public isFinalized;                                    // switched to true in operational state
    uint256 public fundingStart;
    uint256 public fundingEnd;
    uint256 public constant WEI_PER_ETHER = 1000000000000000000;
    uint256 public constant maxLimit =  80 * WEI_PER_ETHER;     // Maximum limit for taking in the money
    uint256 public constant minRequired = 10 * WEI_PER_ETHER;
    uint256 public totalSupply;
    mapping (address => uint256) public balances;
    
    // events
    event Contribution(address indexed _to, uint256 _value);
    
    modifier onlyOwner() {
      require (msg.sender == owner);
      _;
    }

    function transferOwnership(address newOwner) onlyOwner {
      if (newOwner != address(0)) {
        owner = newOwner;
      }
    }

    // @dev constructor
    function IndorsePreSale(address _ethFundDeposit, uint256 _duration) {
      isFinalized = false;                                      //controls pre through crowdsale state
      ethFundDeposit = _ethFundDeposit;
      owner = msg.sender;
      fundingStart = now;
      fundingEnd = fundingStart + _duration * 1 minutes;
      totalSupply = 0;
    }

    // @dev this function accepts Ether and increases the balances of the contributors
    function() payable {           
      uint256 checkedSupply = safeAdd(totalSupply, msg.value);
      require (msg.value >= minRequired);                        // The contribution needs to be above 100 Ether
      require (!isFinalized);                                   // Cannot accept Ether after finalizing the contract
      require (now >= fundingStart);
      require (now <= fundingEnd);
      require (msg.value > 0);
      require (checkedSupply <= maxLimit);
      if (balances[msg.sender] != 0){
        balances[msg.sender] = safeAdd(balances[msg.sender], msg.value);
      } else {
        balances[msg.sender] = msg.value;
      }
      
      totalSupply = safeAdd(totalSupply, msg.value);
      ethFundDeposit.transfer(this.balance);                     // send the eth to Indorse multi-sig
    }

    /// @dev Ends the funding period and sends the ETH home
    function finalize() external {
      require (!isFinalized);
      require (msg.sender == ethFundDeposit);                   // locks finalize to the ultimate ETH owner
      require (now >= fundingEnd);
      // move to operational
      isFinalized = true;
      ethFundDeposit.transfer(this.balance);                     // send the eth to Indorse multi-sig
    }

    /// @dev Allows contributors to recover their ether in the case of a failed funding campaign.
    function refund() external onlyOwner{
      require (!isFinalized);                                   // prevents refund if operational
      require (now >= fundingEnd);                              // prevents refund until sale period is over
      require (msg.sender != ethFundDeposit);                   // Indorse not entitled to a refund
      uint256 retVal = balances[msg.sender];
      require (retVal != 0);
      balances[msg.sender] = 0;
      totalSupply = safeSubtract(totalSupply, retVal);          // extra safe
      msg.sender.transfer(retVal);       
    }

}
