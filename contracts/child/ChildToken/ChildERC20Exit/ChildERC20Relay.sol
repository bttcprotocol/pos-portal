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

    event RelayStart(uint256 indexed id, address indexed relayer);
    event RelayExit(uint256 indexed id, address indexed relayer, address to,
        address tokenWithdraw, address tokenExit, uint256 actual, uint256 fee);
    event RelayEnd(uint256 indexed id, address indexed relayer);
    event FeeUpdated(address indexed relayer, address indexed tokenExit, uint256 fee);
    event RelayerUpdated(address indexed relayer, bool state);

    uint256 public nonce;
    IChildERC20Exit public exitHelper;
    mapping(address => mapping(IChildToken => uint256)) public relayerTokenFees;
    mapping(address => bool) public relayerStates;
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
        exitHelper = IChildERC20Exit(_exitHelper);
        _initializeEIP712("ChildERC20Relay");
    }

    function setRelayerStates(address relayer, bool state) external {
        require(relayer != address(0x00), "ChildERC20Relay: relayer should not be zero address");
        if (!hasRole(MANAGER_ROLE, msgSender())) {
            require(relayer == msgSender() && state == false, "ChildERC20Relay: INSUFFICIENT_PERMISSIONS");
        }

        relayerStates[relayer] = state;
        emit RelayerUpdated(relayer, state);
    }

    function setRelayerTokenFees(address relayer, IChildToken childToken, uint256 fee) external {
        require(relayerStates[relayer], "ChildERC20Relay: relayer is not active");
        if (!hasRole(MANAGER_ROLE, msgSender())) {
            require(relayer == msgSender(), "ChildERC20Relay: INSUFFICIENT_PERMISSIONS");
        }

        relayerTokenFees[relayer][childToken] = fee;
        emit FeeUpdated(relayer, address(childToken), fee);
    }

    function withdrawToByRelayer(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount, address relayer)
    external {
        require(relayerStates[relayer], "ChildERC20Relay: relayer is not active");

        uint256 fee = relayerTokenFees[relayer][tokenExit];
        require(fee > 0, "ChildERC20Relay: unsupported relayer and exitToken");
        require(amount > fee, "ChildERC20Relay: amount must be larger than fee");
        uint256 actualExit = amount - fee;

        uint256 _nonce = nonce + 1;
        nonce = _nonce;
        emit RelayStart(_nonce, relayer);

        IERC20(tokenWithdraw).safeTransferFrom(msgSender(), address(this), amount);
        IERC20(tokenWithdraw).transfer(relayer, fee);

        if (!approved[tokenWithdraw]) {
            IERC20(tokenWithdraw).approve(address(exitHelper), uint256(-1));
            approved[tokenWithdraw] = true;
        }

        emit RelayExit(_nonce, relayer, to, address(tokenWithdraw), address(tokenExit), actualExit, fee);
        exitHelper.withdrawTo(to, tokenWithdraw, tokenExit, actualExit);

        emit RelayEnd(_nonce, relayer);
    }

    function withdrawBTTByRelayer(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount, address payable relayer)
    payable external {
        require(relayerStates[relayer], "ChildERC20Relay: relayer is not active");

        uint256 fee = relayerTokenFees[relayer][tokenExit];
        require(fee > 0, "ChildERC20Relay: unsupported relayer and exitToken");
        require(amount > fee, "ChildERC20Relay: amount must be larger than fee");
        uint256 actualExit = amount - fee;

        uint256 _nonce = nonce + 1;
        nonce = _nonce;
        emit RelayStart(_nonce, relayer);

        if (address(tokenWithdraw) == address(0x1010)) {
            require(msg.value >= amount, "msg value can't be less than amount");
            relayer.transfer(fee);

            emit RelayExit(_nonce, relayer, to, address(tokenWithdraw), address(tokenExit), actualExit, fee);
            exitHelper.withdrawBTT{value:actualExit}(to, tokenWithdraw, tokenExit, actualExit);

            if (msg.value > amount) {
                msg.sender.transfer(msg.value - amount);
            }

            emit RelayEnd(_nonce, relayer);
            return;
        }

        IERC20(tokenWithdraw).safeTransferFrom(msgSender(), address(this), amount);
        IERC20(tokenWithdraw).transfer(relayer, fee);

        if (!approved[tokenWithdraw]) {
            IERC20(tokenWithdraw).approve(address(exitHelper), uint256(-1));
            approved[tokenWithdraw] = true;
        }

        emit RelayExit(_nonce, relayer, to, address(tokenWithdraw), address(tokenExit), actualExit, fee);
        exitHelper.withdrawBTT(to, tokenWithdraw, tokenExit, actualExit);

        emit RelayEnd(_nonce, relayer);
    }
}
