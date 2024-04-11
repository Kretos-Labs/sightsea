// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract mETH is ERC20, Ownable {
    constructor() ERC20("mETH", "mETH") Ownable(msg.sender)  {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}