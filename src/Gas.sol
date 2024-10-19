// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0; 

import "./Ownable.sol";

contract Constants {
    uint8 public tradeFlag = 1;
    uint8 public basicFlag = 0;
    uint8 public dividendFlag = 1;
    uint8 public tradePercent = 12;
    }

struct InternalState {
    uint32 paymentCounter;
    uint32 tradeMode;
    uint32 wasLastOdd;
    uint32 isReady;
}
contract GasContract is Ownable, Constants {
    InternalState internalState;
    uint256 totalSupply = 0; // cannot be updated
    mapping(address => uint256) public balances;
    address contractOwner;
    mapping(address => mapping(uint256 => Payment))  public payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }
    PaymentType constant defaultPayment = PaymentType.Unknown;
    History[] public paymentHistory; // when a payment was updated
    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }
    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }
    mapping(address => uint32) public isOddWhitelistUser;
    
    struct ImportantStruct {
        uint256 amount;
        uint256 valueA; // max 3 digits
        uint256 bigValue;
        uint256 valueB; // max 3 digits
        bool paymentStatus;
        address sender;
    }
    mapping(address => ImportantStruct) public whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (checkForAdmin(senderOfTx)) {
            require(
                checkForAdmin(senderOfTx)
            );
            _;
        } else if (senderOfTx == contractOwner) {
            _;
        } else {
            revert();
        }
    }

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(
            senderOfTx == sender
        );
        uint256 usersTier = whitelist[senderOfTx];
        require(
            usersTier > 0
        );
        require(
            usersTier < 4
        );
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;
        internalState.isReady = 0;
        internalState.wasLastOdd = 0;
        internalState.paymentCounter = 0;
        
        for (uint256 ii = 0; ii < 5; ii++) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
                if (_admins[ii] == contractOwner) {
                    balances[contractOwner] = totalSupply;
                } else {
                    balances[_admins[ii]] = 0;
                }
                if (_admins[ii] == contractOwner) {
                    emit supplyChanged(_admins[ii], totalSupply);
                } else if (_admins[ii] != contractOwner) {
                    emit supplyChanged(_admins[ii], 0);
                }
            }
        }
    }

    function getPaymentHistory()
        public
        payable
        returns (History[] memory paymentHistory_)
    {
        return paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        return balances[_user];
    }

    function getTradingMode() public view returns (bool mode_) {
        return (tradeFlag == 1 || dividendFlag == 1);
    }


    function addHistory(address _updateAddress, bool _tradeMode)
        public
        returns (bool status_, bool tradeMode_)
    {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
        bool[] memory status = new bool[](Constants.tradePercent);
        for (uint256 i = 0; i < Constants.tradePercent; i++) {
            status[i] = true;
        }
        return ((status[0] == true), _tradeMode);
    }


    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public  {
        address senderOfTx = msg.sender;
        require(
            balances[senderOfTx] >= _amount
        );

        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++internalState.paymentCounter;
        payments[senderOfTx][payment.paymentID] = payment;
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        require(
            _ID > 0
        );
        require(
            _amount > 0
        );
        require(
            _user != address(0)
        );

        address senderOfTx = msg.sender;

        payments[_user][_ID].amount = _amount;
        payments[_user][_ID].paymentType = _type;
        payments[_user][_ID].adminUpdated = true;
        payments[_user][_ID].admin = senderOfTx;
        bool tradingMode = getTradingMode();
        addHistory(_user, tradingMode);
        emit PaymentUpdated(
            senderOfTx,
            _ID,
            _amount,
            payments[_user][_ID].recipientName
        );

    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        require(
            _tier < 255
        );
        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 2;
        }
        uint32 wasLastAddedOdd = internalState.wasLastOdd;
        if (wasLastAddedOdd == 1) {
            internalState.wasLastOdd = 0;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else if (wasLastAddedOdd == 0) {
            internalState.wasLastOdd = 1;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;
        whiteListStruct[senderOfTx] = ImportantStruct(_amount, 0, 0, 0, true, msg.sender);
        
        require(
            balances[senderOfTx] >= _amount
        );
        require(
            _amount > 3
        );
        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        balances[senderOfTx] += whitelist[senderOfTx];
        balances[_recipient] -= whitelist[senderOfTx];
        
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }


    fallback() external payable {
         payable(msg.sender).transfer(msg.value);
    }
}