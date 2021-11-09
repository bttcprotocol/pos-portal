pragma solidity 0.6.6;

interface IChildChainManager {
    event TokenMapped(address indexed rootToken, address indexed childToken, uint64 indexed chainId);

    function mapToken(address rootToken, address childToken, uint64 chainId) external;
    function cleanMapToken(address rootToken, address childToken, uint64 chainId) external;
}
