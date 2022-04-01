pragma solidity 0.6.6;

import {ChildERC20ExitStorage} from "./ChildERC20ExitStorage.sol";
import {IChildERC20Exit} from "./IChildERC20Exit.sol";
import {IChildToken} from "../IChildToken.sol";
import {IChildTokenForExchange} from "../IChildTokenForExchange.sol";

contract ChildERC20Exit is ChildERC20ExitStorage, IChildERC20Exit
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
    function addMapping(IChildToken originToken, IChildTokenForExchange tokenA,IChildTokenForExchange tokenB)
    external
    override
    only(MAPPER_ROLE)
    {
        require(address(originToken)!=address(0), "originToken not zero");
        childMappingInfo[originToken] = MappingInfo(originToken,tokenA,tokenB);
    }
}
