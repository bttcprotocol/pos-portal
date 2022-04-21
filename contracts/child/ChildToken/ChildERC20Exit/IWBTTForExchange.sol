pragma solidity 0.6.6;

import {IChildToken} from "./IChildToken.sol";

interface IWBTTForExchange is IChildToken {
    function swapIn() payable external;

    function swapOut(uint256 amount) external;

}
