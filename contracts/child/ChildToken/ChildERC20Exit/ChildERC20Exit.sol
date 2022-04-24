pragma solidity 0.6.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {AccessControlMixin} from "../../../common/AccessControlMixin.sol";
import {NativeMetaTransaction} from "../../../common/NativeMetaTransaction.sol";
import {ContextMixin} from "../../../common/ContextMixin.sol";
import {IChildERC20Exit} from "./IChildERC20Exit.sol";
import {IChildToken} from "./IChildToken.sol";
import {IChildTokenForExchange} from "./IChildTokenForExchange.sol";
import {IWBTTForExchange} from "./IWBTTForExchange.sol";

contract ChildERC20Exit is
    AccessControlMixin,
    NativeMetaTransaction,
    ContextMixin,
    IChildERC20Exit
{
    using SafeERC20 for IERC20;

    mapping(IChildToken => IChildToken) tokenToOrigin;

    bool public isOpen = true;

    bytes32 public constant MAPPER_ROLE = keccak256("MAPPER_ROLE");

    constructor(
        address admin,
        address mapper
    ) public {
        _setupContractId("ChildERC20Exit");
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MAPPER_ROLE, mapper);
        _initializeEIP712("ChildERC20Exit");
    }

    modifier open() {
        require(isOpen, "The contract is not open");
        _;
    }

    function setOpen(bool flag) external only(DEFAULT_ADMIN_ROLE) {
        isOpen = flag;
    }

    function addMapping(IChildToken originToken, IChildTokenForExchange tokenA,
        IChildTokenForExchange tokenB)
    external
    override
    only(MAPPER_ROLE)
    {
        require(address(tokenToOrigin[originToken]) == address(0), "token mapping only add once");
        require(address(tokenToOrigin[tokenA]) == address(0), "token mapping only add once");
        require(address(tokenToOrigin[tokenB]) == address(0), "token mapping only add once");
        tokenToOrigin[tokenA] = originToken;
        tokenToOrigin[tokenB] = originToken;
        tokenToOrigin[originToken] = originToken;
    }

    /**
     * @notice function to swap and withdraw ERC20 token automatically except btt interrelated token
     * @param to token receive address
     * @param tokenWithdraw token to withdraw
     * @param tokenExit token to exit
     * @param amount token amount
     */
    function withdrawTo(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount)
    external override open() {
        IERC20(tokenWithdraw).safeTransferFrom(msgSender(), address(this), amount);
        if (tokenWithdraw == tokenExit) {
            tokenExit.withdrawTo(to, amount);
            return;
        }
        IChildToken originToken = tokenToOrigin[tokenWithdraw];
        require(address(originToken) != address(0), "originToken can't be zero");
        if (tokenWithdraw != originToken) {
            IChildTokenForExchange(address(tokenWithdraw)).swapOut(amount);
            tokenWithdraw = originToken;
        }
        if (tokenExit == originToken) {
            tokenExit.withdrawTo(to, amount);
            return;
        }
        IERC20(tokenWithdraw).safeIncreaseAllowance(address(tokenExit), amount);
        IChildTokenForExchange(address(tokenExit)).swapIn(amount);
        tokenExit.withdrawTo(to, amount);
    }

    /**
     * @notice function to swap and withdraw btt interrelated token automatically,it can receive
     *  call value, if token to withdraw is btt, msg value can't be less than amount
     * @param to token receive address
     * @param tokenWithdraw token to withdraw
     * @param tokenExit token to exit
     * @param amount token amount
     */
    function withdrawBTT(address to,IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount)
     payable external override open() {
        if (address(tokenWithdraw) == address(0x1010)) {
            require(msg.value >= amount, "msg value can't be less than amount");
            if (address(tokenExit) == address(0x1010)) {
                tokenWithdraw.withdrawTo{value:amount}(to, amount);
            } else {
                IWBTTForExchange(address(tokenExit)).swapIn{value:amount}();
                tokenExit.withdrawTo(to, amount);
            }
            if (msg.value > amount) {
                msg.sender.transfer(msg.value - amount);
            }
            return;
        }
        IERC20(tokenWithdraw).safeTransferFrom(msgSender(), address(this), amount);
        if (address(tokenExit) == address(0x1010)) {
            IWBTTForExchange(address(tokenWithdraw)).swapOut(amount);
            tokenExit.withdrawTo{value:amount}(to, amount);
            return;
        }
        if (tokenWithdraw != tokenExit) {
            IWBTTForExchange(address(tokenWithdraw)).swapOut(amount);
            IWBTTForExchange(address(tokenExit)).swapIn{value:amount}();
        }
        tokenExit.withdrawTo(to, amount);
    }

    receive() external payable {

    }

    function originToken(IChildToken token) external view returns(IChildToken) {
        return tokenToOrigin[token];
    }

}
