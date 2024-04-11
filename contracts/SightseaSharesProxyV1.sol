// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IDelegatedProxy {
    function _getPrice(uint256 supply, uint256 amount) external view returns(uint256);
    function _getBuyFee(uint256 price) external view returns(uint256);
    function _getSellTransactionFee() external view returns(uint256);
    function _getBuyTransactionFee() external view returns(uint256);
    function _getSubjectFeePercent() external view returns(uint256);
    function _getProtocolFeePercent() external view returns(uint256);
    function _getSellFee(uint256 price) external view returns(uint256);
    function buyShares(address from, address sharesSubject, uint256 amount) external;
    function sellShares(address from, address sharesSubject, uint256 amount) external;
}

contract SightseaSharesProxyV1 is Ownable {
    using SafeMath for uint256;

    ERC20 public currencyToken;

    address public currencyTokenAddress;
    address public _targetContract;
    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => uint256) public sharesSupply;

    uint256 internal _userBuyGasRefundAmount = 0;

    constructor() Ownable(msg.sender) {}

    //*============ MODIFIERS ==========
    modifier onlyTargetContract() {
        require(msg.sender == _targetContract, "Only allowed contract can call this function");
        _;
    }

    //*============ EVENTS ============
    event Trade(
        address trader,
        address subject,
        bool isBuy,
        uint256 shareAmount,
        uint256 price,
        uint256 fee,
        uint256 supply
    );

    event GasRefund(address indexed user, uint256 amount);

    //SETTERS & GETTERS
    function setTargetContract(address target) public onlyOwner {
        _targetContract = target;
    }
    
    function setCurrencyToken(address tokenAddress) public onlyOwner {
        currencyToken = ERC20(tokenAddress);
        currencyTokenAddress = tokenAddress;
    }

    //*============ TOKEN ============
    function depositGas() public payable {}

    function withdrawGas(uint256 amount) public onlyTargetContract onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }

    function transferToken(address to, uint256 amount) public onlyTargetContract onlyOwner returns (bool) {
        currencyToken.transfer(to, amount);

        return true;
    }

    //SHARES INFORMATION
    function _getSellTransactionFee() external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getSellTransactionFee.selector)
        );

        uint256 price = abi.decode(data, (uint256));

        return price;
    }

    function getSellTransactionFee() public view returns (uint256) {
        return IDelegatedProxy(address(this))._getSellTransactionFee();
    }

    function _getBuyTransactionFee() external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getBuyTransactionFee.selector)
        );

        uint256 price = abi.decode(data, (uint256));

        return price;
    }

    function getBuyTransactionFee() public view returns (uint256) {
        return IDelegatedProxy(address(this))._getBuyTransactionFee();
    }

    function _getSubjectFeePercent() external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getSubjectFeePercent.selector)
        );

        uint256 price = abi.decode(data, (uint256));

        return price;
    }

    function getSubjectFeePercent() public view returns (uint256) {
        return IDelegatedProxy(address(this))._getSubjectFeePercent();
    }

    function _getProtocolFeePercent() external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getProtocolFeePercent.selector)
        );

        uint256 price = abi.decode(data, (uint256));

        return price;
    }

    function getProtocolFeePercent() public view returns (uint256) {
        return IDelegatedProxy(address(this))._getProtocolFeePercent();
    }
    

    function _getPrice(
        uint256 supply,
        uint256 amount
    ) external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getPrice.selector, supply, amount)
        );

        require(success, "Unable to get price");

        uint256 price = abi.decode(data, (uint256));

        return price;
    }

    function getPrice(
        uint256 supply,
        uint256 amount
    ) public view returns (uint256) {
        return IDelegatedProxy(address(this))._getPrice(supply, amount);
    }

    function setSharesBalance(
        address buyer, 
        address subject, 
        uint256 amount
    ) public onlyOwner onlyTargetContract returns (bool) {
        sharesBalance[subject][buyer] = amount;

        return true;
    }

    function getSharesBalance(
        address from,
        address subject
    ) public view returns (uint256) {
        return sharesBalance[subject][from];
    }

    function setSharesSupply(
        address subject, 
        uint256 amount
    ) public onlyOwner onlyTargetContract returns (bool) {
        sharesSupply[subject] = amount;

        return true;
    }

    function getSharesSupply(
        address subject
    ) public view returns (uint256) {
        return sharesSupply[subject];
    }

    function getKeyHoldingSupplyOfUser(
        address from,
        address sharesSubject
    ) public view returns (uint256) {
        return sharesBalance[sharesSubject][from];
    }

    //=========== BUY SHARE INFORMATION ========
    function getBuyPrice(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject], amount);
    }

    function _getBuyFee(
        uint256 price
    ) external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getBuyFee.selector, price)
        );

        require(success, "Unable to get price");

        uint256 fee = abi.decode(data, (uint256));

        return fee;
    }

    function getBuyFee(
        uint256 price
    ) public view returns (uint256) {
        return IDelegatedProxy(address(this))._getBuyFee(price);
    }

    function getBuyPriceAfterFee(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = this.getBuyPrice(sharesSubject, amount);
        uint256 fee = this.getBuyFee(price);

        console.log(fee);
        console.log(price);

        return price + fee;
    }

    //=========== SELL SHARE INFORMATION ========
    function getSellPrice(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        if (sharesSupply[sharesSubject] == 0) {
            return 0;
        }

        return getPrice(sharesSupply[sharesSubject] - amount, amount);
    }

    function _getSellFee(
        uint256 price
    ) external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getSellFee.selector, price)
        );

        require(success, "Unable to get price");

        uint256 fee = abi.decode(data, (uint256));

        return fee;
    }

    function getSellFee(
        uint256 price
    ) public view returns (uint256) {
        return IDelegatedProxy(address(this))._getSellFee(price);
    }

    function getSellPriceAfterFee(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = this.getSellPrice(sharesSubject, amount);
        uint256 fee = this.getSellFee(price);

        return price.sub(fee);
    }

    //=========== BUY SHARE ========
    function buyShares(
        address sharesSubject,
        uint256 amount
    ) public {
        uint256 supply = sharesSupply[sharesSubject];
        uint256 price = getPrice(supply, amount);
        uint256 fee = getBuyFee(price);

        (bool proxySuccess, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(IDelegatedProxy.buyShares.selector, msg.sender, sharesSubject, amount)
        );

        require(proxySuccess, "Unable to buyShares");

        sharesBalance[sharesSubject][msg.sender] =
            sharesBalance[sharesSubject][msg.sender] +
            amount;
        sharesSupply[sharesSubject] = supply + amount;

        emit Trade(
            msg.sender,
            sharesSubject,
            true,
            amount,
            price,
            fee,
            supply + amount
        );

        //* REFUND GAS FEE
        uint256 gasUsed = gasleft();
        uint256 gasRefundAmount = (_userBuyGasRefundAmount + gasUsed) * tx.gasprice;
        emit GasRefund(msg.sender, gasRefundAmount);

        console.log(gasRefundAmount);
        
        payable(msg.sender).transfer(gasRefundAmount);
    }

    //=========== SELL SHARE ========
    function sellShares(
        address sharesSubject,
        uint256 amount
    ) public {
        uint256 supply = sharesSupply[sharesSubject];
        uint256 price = getPrice(supply, amount);
        uint256 fee = getSellFee(price);

        (bool proxySuccess, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(IDelegatedProxy.sellShares.selector, msg.sender, sharesSubject, amount)
        );

        require(proxySuccess, "Unable to sellShares");

        sharesBalance[sharesSubject][msg.sender] =
            sharesBalance[sharesSubject][msg.sender] -
            amount;
        sharesSupply[sharesSubject] = supply - amount;

        emit Trade(
            msg.sender,
            sharesSubject,
            false,
            amount,
            price,
            fee,
            supply + amount
        );

        //* REFUND GAS FEE
        uint256 gasUsed = gasleft();
        uint256 gasRefundAmount = (_userBuyGasRefundAmount + gasUsed) * tx.gasprice;
        emit GasRefund(msg.sender, gasRefundAmount);

        console.log(gasRefundAmount);
        
        payable(msg.sender).transfer(gasRefundAmount);
    }
}