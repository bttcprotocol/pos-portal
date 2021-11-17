pragma solidity 0.6.6;

interface IChildChainManager {
    event TokenMapped(uint64 indexed chainId, address indexed rootToken, address indexed childToken);

    function mapToken(uint64 chainId, address rootToken, address childToken) external;
    function cleanMapToken(uint64 chainId, address rootToken, address childToken) external;
}
