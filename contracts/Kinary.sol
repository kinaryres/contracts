pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract DateTime {
    function isLeapYear(uint16 year) view public virtual returns (bool);
    function getYear(uint timestamp) view public virtual returns (uint16);
    function getMonth(uint timestamp) view public virtual returns (uint8);
    function getDay(uint timestamp) view public virtual returns (uint8);
    function getHour(uint timestamp) view public virtual returns (uint8);
    function getMinute(uint timestamp) view public virtual returns (uint8);
    function getSecond(uint timestamp) view public virtual returns (uint8);
    function getWeekday(uint timestamp) view public virtual returns (uint8);
    function toTimestamp(uint16 year, uint8 month, uint8 day) view public virtual returns (uint timestamp);
    function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) view public virtual returns (uint timestamp);
    function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute) view public virtual returns (uint timestamp);
    function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second) view public virtual returns (uint timestamp);
}

interface ContractReceiver {
  function tokenFallback( address _from, uint _value, bytes calldata _data) external;
}
 
contract Kinary is ChainlinkClient {
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value, bytes _data);
    event OwnershipTransfered(address indexed _old, address indexed _new);
    event Harvest(uint indexed _id, address indexed _owner, uint256 _value);
    event Withdraw(uint indexed _id, address indexed _owner, uint256 _value);
    event AddUpdateTokenRate(address indexed _token, uint256 _previous, uint256 _new);
    event AddUpdateTokenTotalSupply(address indexed _token, uint256 _previous, uint256 _new);
    event DeleteTokenRate(address indexed _token, uint256 _previous, uint256 _new);
    event DeleteTokenTotalSupply(address indexed _token, uint256 _previous, uint256 _new);


    mapping(address => uint) public balances;
    mapping(address => uint) public rates;
    mapping(address => address) public tokenPriceFeedMapping;
    mapping(address => uint) public allowedTokens;
    mapping(address => uint) public totalValueLockedPerToken;

    string public name  = "Kinary";
    string public symbol  = "KINA";
    uint8 public decimals = 3;
    uint public genesisTime = 0;
    uint public fixedRate = 42000;
    uint public startingYear = 0;
    uint public destinationYear = 0;
    uint public PHASE_MULTIPLIER = 0;
    uint public totalInCirculation = 0;
    address public dateTimeAddr = 0x92482Ba45A4D2186DafB486b322C6d0B88410FE7;
    uint256 public eN = 271828182845904523536028747135266249775724709369995;
    uint256 public eD = 100000000000000000000000000000000000000000000000000;
    uint256 public kN = 7;
    uint256 public kD = 1000;
    uint public z = 500;

    uint256 public totalSupply;
    address public peggedToken;
    Deposit[] public deposits;
    address[] public owners;
    

    // Deposits
    struct Deposit {
        address payable owner;
        uint amount;
        uint depositTimestamp;
        uint lockingPeriod;
        uint destinationTimestamp;
        uint harvested;
        bool withdrawed;
        address token;
    }

    DateTime dateTime = DateTime(dateTimeAddr);

    
    constructor() public {
        genesisTime = now;
        startingYear = 2021;
        destinationYear = 4021;
        PHASE_MULTIPLIER = 10000000;
        peggedToken = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
        owners.push(0x2E42c06BCD058ebF81d1F3BE3f7cf59DFFd9Deb1);
        owners.push(0xf9AED95D77792adC39F681e5AddFd27Ede21f490);
    }


    function getPhaseMultiplier() public returns (uint256) {
        uint256 multiplier = z*((eN/eD)**((-(kN/kN)) * getYearsPassed()));
        if (multiplier < 1) return 1;
        return multiplier;
    }


    function getYearsPassed() public returns (uint) {
        return dateTime.getYear(now - genesisTime);
    }
    

    function changePeggedToken(address token) public returns (bool) {
        require(isOwner(msg.sender));
        peggedToken = token;
    }

    
    function addUpdateAllowedToken(address token, uint totalTokenSupply) public returns (bool) {
        require(isOwner(msg.sender));
        emit AddUpdateTokenTotalSupply(token, allowedTokens[token], totalTokenSupply);
        allowedTokens[token] = totalTokenSupply;
    }

    function deleteAllowedToken(address token, uint totalTokenSupply) public returns (bool) {
        require(isOwner(msg.sender));
        emit DeleteTokenTotalSupply(token, allowedTokens[token], totalTokenSupply);
        delete allowedTokens[token];
    }

    function transferOwnership(address _newOwner) public returns (bool success) {
        require(isOwner(msg.sender));
        for (uint i=0; i<owners.length;i++){
            if (owners[i] == msg.sender) {
                owners[i] = _newOwner;
            }
        }
        emit OwnershipTransfered(msg.sender, _newOwner);
        return true;
    }

    
    function isOwner(address _sender) public returns (bool) {
        bool addressIsOwner = false;
        for (uint i=0; i<owners.length; i++){
            if (owners[i] == _sender) {
                addressIsOwner = true;
            }
        }
        return addressIsOwner;
    }


     function getTokenEthPrice(address token) public view returns (uint256) {
        address priceFeedAddress = tokenPriceFeedMapping[token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return uint256(price);
    }


    function getRate(address token) 
    internal returns (uint256) {
        if (allowedTokens[token] != 0) {
            if (token == peggedToken) return 1;
            uint256 peggedTokenPrice = getTokenEthPrice(peggedToken);
            uint256 ethTokenPrice = getTokenEthPrice(token);
            uint256 rate = (ethTokenPrice.div(peggedTokenPrice)).div(2);
            return rate;
        }
    }


    function addUpdateRate(address token, uint rate) 
    public {
        require(isOwner(msg.sender));
        if (allowedTokens[token] != 0) {
            emit AddUpdateTokenRate(token, rates[token], rate);
            rates[token] = rate;
        }
    }

    function removeRate(address token, uint rate) 
    public {
        require(isOwner(msg.sender));
        if (allowedTokens[token] != 0) {
            emit DeleteTokenRate(token, rates[token], rate);
            delete rates[token];
        }
    }


    function addDeposit(address payable owner, uint _amount, uint lockingPeriod, address token) 
    public {
        if (allowedTokens[token] != 0) {
            //TODO dev only
            require(lockingPeriod >= 0 && lockingPeriod <= 360);
            IERC20(token).transferFrom(msg.sender, address(this), _amount);
            deposits.push(
           Deposit({owner: owner, amount: _amount, depositTimestamp: now, 
           lockingPeriod: lockingPeriod, destinationTimestamp: calculateDestinationTimestamp(now, lockingPeriod), 
           harvested: 0, withdrawed: false, token: token}));
           totalValueLockedPerToken[token] = totalValueLockedPerToken[token] + _amount;
        }
    }

    function calculateDestinationTimestamp(uint fromTimestamp, uint lockingPeriod) public returns (uint) {
        uint16 desYear = dateTime.getYear(fromTimestamp);
        uint8 desMonth = dateTime.getMonth(fromTimestamp);
        uint8 desDay = dateTime.getDay(fromTimestamp);
        uint8 tempDays = uint8(lockingPeriod) * 7;
        do {
            if (tempDays >= 365) {
                desYear = desYear + 1;
                tempDays - 365;
                continue;
            }
            if (tempDays >= 30) {
                desMonth = desMonth + 1;
                desMonth - 30;
                continue;
            }
            if (tempDays >= 1) {
                desDay = desDay + 1;
                desMonth - 1;
                continue;
            }
        } while (tempDays > 0);
        return dateTime.toTimestamp(desYear,desMonth,desDay);
    }

    function harvest(uint256 _depositIndex) public returns (bool) {
        if (_depositIndex == 0) return false;
        Deposit storage deposit = deposits[_depositIndex];
        require(deposit.owner == msg.sender, "This asset doesn't belong to you");
        require(deposits[_depositIndex].withdrawed == false);
        require(deposit.owner == msg.sender);
        uint256 rate = getRate(deposit.token) * (deposit.lockingPeriod / 12);
        if (rate == 0) return false;
        require(now >= deposit.destinationTimestamp);
        uint progress = (now) / deposit.destinationTimestamp;
        uint amount = (deposit.amount.mul(rate).mul(progress).mul(getPhaseMultiplier())) - deposit.harvested;
        require(amount > 0, "Nothing to harvest yet");
        _mint(msg.sender, amount);
        deposits[_depositIndex].harvested = deposits[_depositIndex].harvested + amount;
        emit Harvest(_depositIndex, deposit.owner, deposit.amount);
        return true;
    }


     function withdraw(uint256 _depositIndex) public returns (bool) {
        if (_depositIndex == 0) return false;
        Deposit storage deposit = deposits[_depositIndex];
        require(deposits[_depositIndex].withdrawed == false);
        require(deposit.owner == msg.sender, "This asset doesn't belong to you");
        address token = deposit.token;
        require(now >= deposit.destinationTimestamp);
        IERC20(deposit.token).transferFrom(address(this), msg.sender, deposit.amount);
        deposits[_depositIndex].withdrawed = true;
        totalValueLockedPerToken[token] = totalValueLockedPerToken[token] - deposit.amount;
        harvest(_depositIndex);
        emit Withdraw(_depositIndex, deposit.owner, deposit.amount);
        return true;
    }

   
    // Function that is called when a user or another contract wants to transfer funds .
    function transfer(address _to, uint _value, bytes memory _data, bytes memory _custom_fallback) public returns (bool success) {
        if(isContract(_to)) {
            if (balanceOf(msg.sender) < _value) revert();
            balances[msg.sender] = balanceOf(msg.sender).sub(_value);
            balances[_to] = balanceOf(_to).add(_value);
            ContractReceiver rx = ContractReceiver(_to);
            emit Transfer(msg.sender, _to, _value, _data);
            return true;
        }
        else {
            return transferToAddress(_to, _value, _data);
        }
    }
  

  // Function that is called when a user or another contract wants to transfer funds .
    function transfer(address _to, uint _value, bytes memory _data) public returns (bool success) {
        if(isContract(_to)) {
            return transferToContract(_to, _value, _data);
        }
        else {
            return transferToAddress(_to, _value, _data);
        }
    }
  
  // Standard function transfer similar to ERC20 transfer with no _data .
  // Added due to backwards compatibility reasons .
    function transfer(address _to, uint _value) public returns (bool success) {
        //standard function transfer similar to ERC20 transfer with no _data
        //added due to backwards compatibility reasons
        bytes memory empty;
        if(isContract(_to)) {
            return transferToContract(_to, _value, empty);
        }
        else {
            return transferToAddress(_to, _value, empty);
        }
    }

    function _mint(address account, uint256 amount) internal returns (bool success) {
        require(account != address(0), "ERC20: mint to zero address");
        totalSupply = totalSupply.add(amount);
        balances[account] = balances[account].add(amount);
    }

    function _burn(address account, uint256 amount) internal returns (bool success) {
        require(account != address(0), "ERC20: mint to zero address");
        totalSupply = totalSupply.sub(amount);
        balances[account] = balances[account].sub(amount);
    }

//assemble the given address bytecode. If bytecode exists then the _addr is a contract.
    function isContract(address _addr) private view returns (bool is_contract) {
        uint length;
        assembly {
                //retrieve the size of the code on target address, this needs assembly
                length := extcodesize(_addr)
        }
        return (length>0);
    }

  //function that is called when transaction target is an address
    function transferToAddress(address _to, uint _value, bytes memory _data) private returns (bool success) {
        if (balanceOf(msg.sender) < _value) revert();
        balances[msg.sender] = balanceOf(msg.sender).sub(_value);
        balances[_to] = balanceOf(_to).add(_value);
        emit Transfer(msg.sender, _to, _value, _data);
        return true;
    }
    

  
  //function that is called when transaction target is a contract
    function transferToContract(address _to, uint _value, bytes memory _data) private returns (bool success) {
        if (balanceOf(msg.sender) < _value) revert();
        balances[msg.sender] = balanceOf(msg.sender).sub(_value);
        balances[_to] = balanceOf(_to).add(_value);
        ContractReceiver receiver = ContractReceiver(_to);
        receiver.tokenFallback(msg.sender, _value, _data);
        emit Transfer(msg.sender, _to, _value, _data);
        return true;
    }

    function balanceOf(address _owner) view public returns (uint balance) {
        return balances[_owner];
    }
  
  
}