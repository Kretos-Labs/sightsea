// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IDelegatedProxy {
    function _getSharesSupply(address subject) external view returns(uint256);
    function _getSharesBalance(address from, address subject) external view returns(uint256);
    function _transferToken(address to, uint256 amount) external returns(bool);
}

contract SightseaSharesV1 is Ownable {
    ERC20 public currencyToken;

    address public _targetContract;
    address public currencyTokenAddress;
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public buyTransactionFee;
    uint256 public sellTransactionFee;

    constructor() Ownable(msg.sender)  {}

    //*============ MODIFIERS ==========
    modifier onlyTargetContract() {
        require(msg.sender == _targetContract, "Only allowed contract can call this function");
        _;
    }

    uint256 internal _userBuyGasRefundAmount = 0;

    //*========== PROXY ==========
    function _getSharesSupply(address subject)  external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getSharesSupply.selector, subject)
        );

        require(success, "Unable to get shares supply");

        uint256 supply = abi.decode(data, (uint256));

        return supply;
    }

    function getSharesSupply(
        address subject
    ) public view returns (uint256) {
        return IDelegatedProxy(address(this))._getSharesSupply(subject);
    }

    function _getSharesBalance(address from, address subject)  external returns (uint256) {
        (bool success, bytes memory data) = _targetContract.call(
            abi.encodeWithSelector(this.getSharesBalance.selector, from, subject)
        );

        require(success, "Unable to get shares balance");

        uint256 supply = abi.decode(data, (uint256));

        return supply;
    }

    function getSharesBalance(
        address from,
        address subject
    ) public view returns (uint256) {
        return IDelegatedProxy(address(this))._getSharesBalance(from, subject);
    }

    function setDefaultConfig() public onlyOwner {
        buyTransactionFee = 10000000000000000;
        protocolFeePercent = 50000000000000000;
        sellTransactionFee = 10000000000000000;
        subjectFeePercent = 50000000000000000;
    }

    //*============ TOKEN ============
    function setCurrencyToken(address tokenAddress) public onlyOwner {
        currencyToken = ERC20(tokenAddress);
        currencyTokenAddress = tokenAddress;
    }

    function setTargetContract(address target) public onlyOwner {
        _targetContract = target;
    }

    function depositGas() public payable {}

    function withdrawGas(uint256 amount) public onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }

    //*============ FEE MANAGEMENT ============
    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function getFeeDestination() public view returns (address) {
        return protocolFeeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function getProtocolFeePercent() public view returns (uint256) {
        return protocolFeePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        subjectFeePercent = _feePercent;
    }

    function getSubjectFeePercent() public view returns (uint256) {
        return subjectFeePercent;
    }

    function setUserBuyGasRefundAmount(uint256 amount) public onlyOwner {
        _userBuyGasRefundAmount = amount;
    }

    function setSellTransactionFee(uint256 amount) public onlyOwner {
        sellTransactionFee = amount;
    }

    function getSellTransactionFee() public view returns (uint256) {
        return sellTransactionFee;
    }

    function setBuyTransactionFee(uint256 amount) public onlyOwner {
        buyTransactionFee = amount;
    }

    function getBuyTransactionFee() public view returns (uint256) {
        return buyTransactionFee;
    }

    //*============ SHARES INFORMATION ============
    function getPrice(
        uint256 supply,
        uint256 amount
    ) public pure returns (uint256) {
        uint256 sumSupply = supply + amount;
        return 1 ether * (sumSupply * sumSupply) / 32768;
    }

    function getBuyFee(
        uint256 price
    ) public view returns (uint256) {
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 totalFee = protocolFee + subjectFee + buyTransactionFee;
        return totalFee;
    }

    function getSellFee(
        uint256 price
    ) public view returns (uint256) {
        uint256 totalFee = sellTransactionFee;
        return totalFee;
    }

    //*============ SHARES ACTIONS ============
    function buyShares(
        address from,
        address sharesSubject,
        uint256 amount
    ) public {
        uint256 supply = this.getSharesSupply(sharesSubject);
        
        require(
            supply > 0 || sharesSubject == from,
            "Only the shares' subject can buy the first share"
        );

        uint256 price = getPrice(supply, amount);
        uint256 fee = getBuyFee(price);

        uint256 tokenBalance = currencyToken.balanceOf(from);

        require(tokenBalance >= fee, "Insufficient payment");

        //* SEND TOKEN
        uint256 protocolFee = price + price * protocolFeePercent / 1 ether + buyTransactionFee; //1 + 0.05 * 1
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        bool success1 = true;

        if (from != sharesSubject) {
            success1 = currencyToken.transferFrom(from, sharesSubject, subjectFee);
        }

        bool success2 = currencyToken.transferFrom(from, protocolFeeDestination, protocolFee);
        require(success1 && success2, "Unable to send tokens");
    }

    function sellShares(
        address from,
        address sharesSubject,
        uint256 amount
    ) public {
        uint256 supply = this.getSharesSupply(sharesSubject);
        uint256 sharesAmount = this.getSharesBalance(from, sharesSubject);
        // require((supply + 1) > amount, "Cannot sell the last share");

        uint256 price = getPrice(supply - amount, amount);

        require(
            sharesAmount >= amount,
            "Insufficient shares"
        );

        //* SEND TOKEN
        //Kiểm tra điều kiện nếu sell là âm thì trả tiền ngược về cho platform
        bool success1 = true;
        uint256 sellFee = sellTransactionFee;

        if (price < sellFee) {
            //Send fee back to platform
            success1 = currencyToken.transferFrom(from, protocolFeeDestination, sellFee - price);
        } else if (price > sellFee) {
            //Send token to seller
            (bool proxySuccess, bytes memory data) = _targetContract.call(
                abi.encodeWithSelector(IDelegatedProxy._transferToken.selector, from, price - sellFee)
            );

            success1 = proxySuccess;
        }

        require(success1, "Unable to send tokens");
    }
}
