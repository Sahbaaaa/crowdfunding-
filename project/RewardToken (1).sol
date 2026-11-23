// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20, Ownable {
    constructor() 
    ERC20("Reward Token", "RWD")
    Ownable(msg.sender) 
{
    _mint(msg.sender, 1000 * (10 ** uint256(decimals())));
}

    // Make mint public so anyone can get tokens for testing
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}