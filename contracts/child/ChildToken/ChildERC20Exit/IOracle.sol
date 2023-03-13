pragma solidity 0.6.6;

interface IOracle {
    function hardLimit() view external returns (uint256);
    function orderCost() view external returns (uint256);
    function scale() view external returns (uint256);

}
