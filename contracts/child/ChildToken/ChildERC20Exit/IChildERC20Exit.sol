pragma solidity 0.6.6;

import "../IChildToken.sol";
import "../IChildTokenForExchange.sol";

interface IChildERC20Exit
{
    function addMapping(IChildToken originToken, IChildTokenForExchange tokenA,IChildTokenForExchange tokenB) external;
}
