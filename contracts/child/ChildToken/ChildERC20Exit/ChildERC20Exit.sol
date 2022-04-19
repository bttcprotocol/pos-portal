pragma solidity 0.6.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ChildERC20ExitStorage} from "./ChildERC20ExitStorage.sol";
import {IChildERC20Exit} from "./IChildERC20Exit.sol";
import {IChildToken} from "./IChildToken.sol";
import {IChildTokenForExchange} from "./IChildTokenForExchange.sol";

contract ChildERC20Exit is
    ChildERC20ExitStorage,
    IChildERC20Exit
{
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
    function addMapping(IChildToken originToken, IChildTokenForExchange tokenA,
        IChildTokenForExchange tokenB)
    external
    override
    only(MAPPER_ROLE)
    {
        require(address(originToken)!=address(0), "originToken can't be zero");
        tokenToOrigin[tokenA] = originToken;
        tokenToOrigin[tokenB] = originToken;
        tokenToOrigin[originToken] = originToken;
    }

    function withdrawTo(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount)
    external override {
        tokenWithdraw.transferFrom(msgSender(), address(this), amount);
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
        tokenWithdraw.approve(address(tokenExit), amount);
        IChildTokenForExchange(address(tokenExit)).swapIn(amount);
        tokenExit.withdrawTo(to, amount);
    }

    function originToken(IChildToken token) external view returns(IChildToken) {
        return tokenToOrigin[token];
    }

}
