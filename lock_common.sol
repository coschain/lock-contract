pragma solidity ^0.4.24;

    contract DAO {
        function balanceOf(address addr) public returns (uint);
    }
    
    interface RegisterInterface {
        function register(string);
    }
    
// auth
contract Auth {
    address      public  owner;
    constructor () public {
         owner = msg.sender;
    }
    
    modifier auth {
        require(isAuthorized(msg.sender) == true);
        _;
    }
    
    function isAuthorized(address src) internal view returns (bool) {
        if(src == owner){
            return true;
        } else {
            return false;
        }
    }
}

    contract TokenTimelock is Auth{
    
    constructor() public {
        benificiary = msg.sender;
    }
    
    uint constant public days_of_month = 30;
    
    uint  public firstTime = 0;
    uint  public secondTIme = 0;
    uint  public thirdTime = 0;
    uint  public fourthTime = 0;
    mapping (uint => bool) public release_map;
    
    uint256 public totalFutureRelease = 0;
    

    // cosToken address, 
    address constant public contract_addr = 0x589891a198195061cb8ad1a75357a3b7dbadd7bc;

    address public benificiary;
    
    uint     public  startTime; 
    bool public lockStart = false;
    
    // set total cos to lock
    function set_total(uint256 total) auth public {
        require(lockStart == false);
        totalFutureRelease = total;
    }
    
    // set month to release
    function set_release_month(int months1,int months2,int months3,int months4) auth public {
        require(lockStart == false);
        require(months1 > 0);
        require(months2 > 0);
        require(months3 > 0);
        require(months4 > 0);
        firstTime = uint(months1) * days_of_month;
        secondTIme = uint(months2) * days_of_month;
        thirdTime = uint(months3) * days_of_month;
        fourthTime = uint(months4) * days_of_month;
        
        require(firstTime < secondTIme );
        require(secondTIme < thirdTime);
        require(thirdTime < fourthTime);
    }

    // when transfer certain balance to this contract address, we can call lock
    function lock(int offsetMinutes) auth public returns(bool) {
        require(lockStart == false);
        require(firstTime != 0);
        require(secondTIme != 0);
        require(thirdTime != 0);
        require(fourthTime != 0);
        require(offsetMinutes >= 0);
        
        DAO cosTokenApi = DAO(contract_addr);
        uint256 balance = cosTokenApi.balanceOf(address(this));
        require(balance == totalFutureRelease);
        
        startTime = block.timestamp + uint(offsetMinutes) * 1 minutes;
        lockStart = true;
    }
    
    function set_benificiary(address b) auth public {
        benificiary = b;
    }
    
    function release_specific(uint index,uint i) private {
        if (release_map[i] == true) {
            emit mapCheck(true,i);
            return;
        }
        emit mapCheck(false,i);
        
        DAO cosTokenApi = DAO(contract_addr);
        uint256 balance = cosTokenApi.balanceOf(address(this));
        uint256 eachRelease = 0;
        if (index == 1) {
            eachRelease = totalFutureRelease / 10;
        } else if (index >= 2 && index <= 4) {
            eachRelease = (totalFutureRelease / 10) * 3;
        } else {
            require(false);
        }
        
        bool ok = balance >= eachRelease; 
        emit balanceCheck(ok,balance);
        require(balance >= eachRelease);
  
        bool success = contract_addr.call(bytes4(keccak256("transfer(address,uint256)")),benificiary,eachRelease);
        emit tokenTransfer(success);
        require(success);
        release_map[i] = true;
    }
    
    event mapCheck(bool ok,uint window);
    event balanceCheck(bool ok,uint256 balance);
    event tokenTransfer(bool success);

    function release() auth public {
        require(lockStart == true);
        require(release_map[fourthTime] == false);
        uint theDay = dayFor();
        // release day must be after lock day
        require(theDay > firstTime);
        
        if (  theDay > firstTime && theDay <= secondTIme) {
            release_specific(1,firstTime);
        } else if (theDay > secondTIme && theDay <= thirdTime) {
            release_specific(1,firstTime);
            release_specific(2,secondTIme);
        } else if (theDay > thirdTime && theDay <= fourthTime) {
            release_specific(1,firstTime);
            release_specific(2,secondTIme);
            release_specific(3,thirdTime);
        } else if (theDay > fourthTime) {
            release_specific(1,firstTime);
            release_specific(2,secondTIme);
            release_specific(3,thirdTime);
            release_specific(4,fourthTime);
        }
    }
    
        // days after lock
    function dayFor() view public returns (uint) {
        uint timestamp = block.timestamp;
        return timestamp < startTime ? 0 : (timestamp - startTime) / 1 days + 1;
    }
    
    function regist(string key) auth public {
        RegisterInterface(contract_addr).register(key);
    }
}
