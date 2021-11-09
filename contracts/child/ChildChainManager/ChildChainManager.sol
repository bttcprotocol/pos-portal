pragma solidity 0.6.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IChildChainManager} from "./IChildChainManager.sol";
import {IChildToken} from "../ChildToken/IChildToken.sol";
import {Initializable} from "../../common/Initializable.sol";
import {AccessControlMixin} from "../../common/AccessControlMixin.sol";
import {IStateReceiver} from "../IStateReceiver.sol";


contract ChildChainManager is
    IChildChainManager,
    Initializable,
    AccessControlMixin,
    IStateReceiver
{
    bytes32 public constant DEPOSIT = keccak256("DEPOSIT");
    bytes32 public constant MAP_TOKEN = keccak256("MAP_TOKEN");
    bytes32 public constant MAPPER_ROLE = keccak256("MAPPER_ROLE");
    bytes32 public constant STATE_SYNCER_ROLE = keccak256("STATE_SYNCER_ROLE");

    mapping(bytes => address) public rootToChildToken;
    mapping(address => bytes) public childToRootToken;

    function initialize(address _owner) external initializer {
        _setupContractId("ChildChainManager");
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MAPPER_ROLE, _owner);
        _setupRole(STATE_SYNCER_ROLE, _owner);
    }

    /**
     * @notice Map a token to enable its movement via the PoS Portal, callable only by mappers
     * Normally mapping should happen automatically using state sync
     * This function should be used only while initial deployment when state sync is not registrered or if it fails
     * @param rootToken address of token on root chain
     * @param childToken address of token on child chain
     */
    function mapToken(address rootToken, address childToken, uint256 chainId)
        external
        override
        only(MAPPER_ROLE)
    {
        _mapToken(rootToken, childToken, chainId);
    }

    /**
     * @notice Receive state sync data from root chain, only callable by state syncer
     * @dev state syncing mechanism is used for both depositing tokens and mapping them
     * @param data bytes data from RootChainManager contract
     * `data` is made up of bytes32 `syncType` and bytes `syncData`
     * `syncType` determines if it is deposit or token mapping
     * in case of token mapping, `syncData` is encoded address `rootToken`, address `childToken` and bytes32 `tokenType`
     * in case of deposit, `syncData` is encoded address `user`, address `rootToken` and bytes `depositData`
     * `depositData` is token specific data (amount in case of ERC20). It is passed as is to child token
     */
    function onStateReceive(uint256, bytes calldata data)
        external
        override
        only(STATE_SYNCER_ROLE)
    {
        (bytes32 syncType, bytes memory syncData) = abi.decode(
            data,
            (bytes32, bytes)
        );

        if (syncType == DEPOSIT) {
            _syncDeposit(syncData);
        } else if (syncType == MAP_TOKEN) {
            (address rootToken, address childToken, uint256 chainId, ) = abi.decode(
                syncData,
                (address, address, uint256, bytes32)
            );
            _mapToken(rootToken, childToken, chainId);
        } else {
            revert("ChildChainManager: INVALID_SYNC_TYPE");
        }
    }

    /**
     * @notice Clean polluted token mapping
     * @param rootToken address of token on root chain. Since rename token was introduced later stage,
     * clean method is used to clean pollulated mapping
     */
    function cleanMapToken(
        address rootToken,
        address childToken,
        uint256 chainId
    ) external override only(MAPPER_ROLE) {
        bytes root = abi.encode(rootToken, chainId);
        rootToChildToken[root] = '';
        childToRootToken[childToken] = address(0);

        emit TokenMapped(rootToken, childToken, chainId);
    }

    function _mapToken(address rootToken, address childToken, uint256 chainId) private {
        bytes root = abi.encode(rootToken, chainId);
        address oldChildToken = rootToChildToken[root];
        bytes oldRootToken = childToRootToken[childToken];

        if (rootToChildToken[oldRootToken] != address(0)) {
            rootToChildToken[oldRootToken] = address(0);
        }
        //  todo: how to check b
        if (childToRootToken[oldChildToken].length != 0) {
            childToRootToken[oldChildToken] = '';
        }

        rootToChildToken[root] = childToken;
        childToRootToken[childToken] = root;

        emit TokenMapped(rootToken, childToken, chainId);
    }

    function _syncDeposit(bytes memory syncData) private {
        (address user, address rootToken, uint256 chainId, bytes memory depositData) = abi
            .decode(syncData, (address, address, uint256, bytes));
        bytes root = abi.encode(rootToken, chainId);
        address childTokenAddress = rootToChildToken[root];
        require(
            childTokenAddress != address(0x0),
            "ChildChainManager: TOKEN_NOT_MAPPED"
        );
        IChildToken childTokenContract = IChildToken(childTokenAddress);
        childTokenContract.deposit(user, depositData);
    }
}
