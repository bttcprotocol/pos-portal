pragma solidity 0.6.6;

import "./IChildToken.sol";
import "./IChildTokenForExchange.sol";

interface IChildERC20Exit
{
    function addMapping(IChildToken originToken, IChildTokenForExchange tokenA,IChildTokenForExchange tokenB) external;

    function withdrawTo(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount) external;
}