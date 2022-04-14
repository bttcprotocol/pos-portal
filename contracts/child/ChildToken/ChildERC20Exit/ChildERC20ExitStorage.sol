
pragma solidity 0.6.6;

import {AccessControlMixin} from "../../../common/AccessControlMixin.sol";
import {NativeMetaTransaction} from "../../../common/NativeMetaTransaction.sol";
import {ContextMixin} from "../../../common/ContextMixin.sol";
import {IChildToken} from "./IChildToken.sol";
import {IChildTokenForExchange} from "./IChildTokenForExchange.sol";


contract ChildERC20ExitStorage is  AccessControlMixin, NativeMetaTransaction, ContextMixin
{
    mapping(IChildToken => MappingInfo) childMappingInfo;
    mapping(IChildToken => IChildToken) tokenToOrigin;
    struct MappingInfo{
        IChildTokenForExchange mappingTokenA;
        IChildTokenForExchange mappingTokenB;
    }

}
