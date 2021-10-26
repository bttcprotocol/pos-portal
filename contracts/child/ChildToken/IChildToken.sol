pragma solidity 0.6.6;

interface IChildToken {
    event WithdrawTo(address indexed to);
    function deposit(address user, bytes calldata depositData) external;
}
