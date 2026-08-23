pragma solidity 0.6.6;

interface IRootChainManager {
    event TokenMapped(
        address indexed rootToken,
        address indexed childToken,
        bytes32 indexed tokenType
    );

    event PredicateRegistered(
        bytes32 indexed tokenType,
        address indexed predicateAddress
    );

    event EtherFundedToPredicate(
        address indexed sender,
        address indexed predicate,
        uint256 amount
    );

    event DepositStateChanged(bool enabled);

    event WithdrawAllSkipped(address indexed rootToken, uint8 indexed skipType);

    event BurnedMintableERC20(address indexed rootToken, uint256 amount);

    function registerPredicate(
        bytes32 tokenType,
        address predicateAddress
    ) external;

    function mapToken(
        address rootToken,
        address childToken,
        bytes32 tokenType
    ) external;

    function cleanMapToken(address rootToken, address childToken) external;

    function remapToken(
        address rootToken,
        address childToken,
        bytes32 tokenType
    ) external;

    function depositEtherFor(address user) external payable;

    function depositFor(
        address user,
        address rootToken,
        bytes calldata depositData
    ) external;

    function exit(bytes calldata inputData) external;

    function withdrawAll(address[] calldata rootTokens) external;

    function burnAllMintableERC20(address[] calldata rootTokens) external;

    // function withdrawEtherFor(address payable user, uint256 amount) external;

    // function withdrawFor(
    //     address user,
    //     address rootToken,
    //     bytes calldata withdrawData
    // ) external;

    // function fundEtherPredicate() external payable;

    // function setDepositEnabled(bool enabled) external;
}
