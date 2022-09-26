pragma solidity 0.6.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {AccessControlMixin} from "../../../common/AccessControlMixin.sol";
import {NativeMetaTransaction} from "../../../common/NativeMetaTransaction.sol";
import {ContextMixin} from "../../../common/ContextMixin.sol";
import {IChildToken} from "./IChildToken.sol";
import {IChildERC20Exit} from "./IChildERC20Exit.sol";

contract ChildERC20Relay is AccessControlMixin, NativeMetaTransaction, ContextMixin {
    using SafeERC20 for IERC20;

    event Start(uint256 indexed id, address indexed relayer, address to, address tokenWithdraw, address tokenExit, uint256 total);
    event RelayExit(uint256 indexed id, address indexed relayer, address tokenWithdraw, address tokenExit, uint256 fee);
    event End(uint256 indexed id, address indexed relayer, address to, address tokenWithdraw, address tokenExit, uint256 total);
    event FeeUpdated(address indexed relayer, address indexed tokenExit, uint256 fee);

    uint256 public nonce;
    IChildERC20Exit public exitHelper;
    mapping(address => mapping(IChildToken => uint256)) public relayerTokenFees;
    mapping(IChildToken => bool) public approved;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    constructor(
        address _admin,
        address _manager,
        address _exitHelper
    ) public {
        _setupContractId("ChildERC20Relay");
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MANAGER_ROLE, _manager);
        exitHelper = _exitHelper;
        _initializeEIP712("ChildERC20Relay");
    }

    function setRelayerTokenFees(address relayer, IChildToken childToken, uint256 fee) external only(MANAGER_ROLE) {
        relayerTokenFees[relayer][childToken] = fee;
        emit FeeUpdated(relayer, childToken, fee);
    }

    function withdrawToByRelayer(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount, address relayer)
    external {

        uint256 fee = relayerTokenFees[relayer][tokenExit];
        require(fee > 0, "ChildERC20Relayer: unsupported relayer and exitToken");
        require(amount > fee, "ChildERC20Relayer: amount must be larger than fee");
        uint256 actualExit = amount - fee;

        uint256 _nonce = nonce + 1;
        nonce = _nonce;

        emit Start(_nonce);

        IERC20(tokenWithdraw).safeTransferFrom(msgSender(), address(this), amount);
        IERC20(tokenWithdraw).transfer(relayer, fee);

        if (!approved[tokenWithdraw]) {
            IERC20(tokenWithdraw).approve(exitHelper, uint256(-1));
            approved[tokenWithdraw] = true;
        }

        exitHelper.withdrawTo(to, tokenWithdraw, tokenExit, actualExit);
        emit End(_nonce);
    }

    function withdrawBTTByRelayer(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount)
    payable external {

    }

}
