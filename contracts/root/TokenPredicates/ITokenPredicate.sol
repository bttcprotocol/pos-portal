pragma solidity 0.6.6;

import {RLPReader} from "../../lib/RLPReader.sol";

/// @title Token predicate interface for all pos portal predicates
/// @notice Abstract interface that defines methods for custom predicates
interface ITokenPredicate {

    /**
     * @notice Deposit tokens into pos portal
     * @dev When `depositor` deposits tokens into pos portal, tokens get locked into predicate contract.
     * @param depositor Address who wants to deposit tokens
     * @param depositReceiver Address (address) who wants to receive tokens on side chain
     * @param rootToken Token which gets deposited
     * @param depositData Extra data for deposit (amount for ERC20, token id for ERC721 etc.) [ABI encoded]
     */
    function lockTokens(
        address depositor,
        address depositReceiver,
        address rootToken,
        bytes calldata depositData
    ) external;

    /**
     * @notice Validates and processes exit while withdraw process
     * @dev Validates exit log emitted on sidechain. Reverts if validation fails.
     * @dev Processes withdraw based on custom logic. Example: transfer ERC20/ERC721, mint ERC721 if mintable withdraw
     * @param sender Address
     * @param rootToken Token which gets withdrawn
     * @param logRLPList Valid sidechain log for data like amount, token id etc.
     */
    function exitTokens(
        address sender,
        address rootToken,
        bytes calldata logRLPList
    ) external;


    /**
     * @notice withdraw token from the corresponding Predicate contract.
     * @dev This method does not trigger cross-chain synchronization; consequently, the balance on the child chain remains unchanged.
     * @param user         The address designated to receive the tokens.
     * @param rootToken    The address of the token to be extracted, located on the root chain.
     * @param withdrawData bytes data that is sent to predicate
     */
    function withdrawTokens(
        address user,
        address rootToken,
        bytes calldata withdrawData
    ) external;

    function setMintableEnabled(bool enabled) external;
}
