pragma solidity 0.6.6;

import "./IChildToken.sol";
import "./IChildTokenForExchange.sol";

interface IChildERC20Exit
{
    event ExitTokenTo(address indexed from, address indexed to, address fromToken, address indexed toToken, uint256 amount);

    function addMapping(IChildToken originToken, IChildTokenForExchange tokenA,IChildTokenForExchange tokenB) external;

    function withdrawTo(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount) external;

    function withdrawBTT(address to,IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount) payable external;

}
