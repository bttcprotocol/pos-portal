pragma solidity 0.6.6;

import {IChildToken} from "./IChildToken.sol";

interface IChildTokenForExchange is IChildToken {
    function swapIn(uint256 amount) external;

    function swapOut(uint256 amount) external;

}
