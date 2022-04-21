pragma solidity 0.6.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IChildToken is IERC20 {
    event WithdrawTo(address indexed from, address indexed to, uint256 amount);
    function deposit(address user, bytes calldata depositData) external;
    function withdrawTo(address to, uint256 amount) payable external;
}
