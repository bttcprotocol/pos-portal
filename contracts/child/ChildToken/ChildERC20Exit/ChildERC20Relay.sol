pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {AccessControlMixin} from "../../../common/AccessControlMixin.sol";
import {NativeMetaTransaction} from "../../../common/NativeMetaTransaction.sol";
import {ContextMixin} from "../../../common/ContextMixin.sol";
import {IChildToken} from "./IChildToken.sol";
import {IChildERC20Exit} from "./IChildERC20Exit.sol";


interface IChildChainManager {
    function childToRootToken(address childToken) external returns (address);
}

interface IChildERC20RelayStake {
    function isActive(address relayer) external view returns(bool);
}

contract ChildERC20Relay is AccessControlMixin, NativeMetaTransaction, ContextMixin{
    using SafeERC20 for IERC20;

    event RelayStart(uint256 indexed id, address indexed relayer);
    event RelayExit(uint256 indexed id, address indexed relayer, address to,
        address tokenWithdraw, address tokenExit, uint256 actual, uint256 fee, bool withRefuel, uint256 refuelFee);
    event RelayEnd(uint256 indexed id, address indexed relayer);
    event FeeUpdated(address indexed relayer, address indexed tokenExit, uint256 fee);
    event RefuelFeeUpdated(address indexed tokenExit, uint256 refuelFee);
    event StateUpdated(address indexed relayer, address indexed tokenExit, bool state);
    event RefuelStateUpdated(address indexed tokenExit, bool state);
    event PauseAction(address indexed relayer, bool isRelayerPaused);
    event MaxHourlyOrdersUpdated(uint256 value);

    uint256 public nonce;
    uint256 public maxHourlyOrders;
    
    IChildChainManager public childChainManager;
    IChildERC20RelayStake public childERC20RelayStake;
    IChildERC20Exit public exitHelper;
    
    mapping(IChildToken => bool) public approved;
    mapping(address => mapping(IChildToken => uint256)) public relayerTokenFees;
    mapping(address => mapping(IChildToken => bool)) public relayerTokenStates;
    mapping(address => bool) public isRelayerPaused;
    mapping(IChildToken => uint256) public tokenRefuelFees;
    mapping(IChildToken => bool) public tokenRefuelStates;

    struct HourlyCount{
        uint64 hour;
        uint64 count;
    }
    mapping(address => HourlyCount) public currentHourlyCount;

    bytes32 public constant REFUELER_ROLE = keccak256("REFUELER_ROLE");

    function initialize(
        address _admin,
        address _refueler,
        address _exitHelper,
        address _childChainManager,
        address _childERC20RelayStake,
        uint256 _maxHourlyOrders) external initializer {
        _setupContractId("ChildERC20Relay");
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(REFUELER_ROLE, _refueler);
        exitHelper = IChildERC20Exit(_exitHelper);
        childChainManager = IChildChainManager(_childChainManager);
        childERC20RelayStake = IChildERC20RelayStake(_childERC20RelayStake);
        maxHourlyOrders = _maxHourlyOrders;
        _initializeEIP712("ChildERC20Relay");
    }

    modifier onlyActive(address relayer){
        require(childERC20RelayStake.isActive(relayer), "ChildERC20Relay: relayer is not active");
        _;
    }

    function setRelayerPause(bool state) external onlyActive(msgSender()){
        address relayer = msgSender();
         isRelayerPaused[relayer] = state;
        emit PauseAction(relayer, state);
    }

    function setRelayerTokenStates(IChildToken childToken, bool state) external onlyActive(msgSender()){
        address relayer= msgSender();
        if(state){
            require(childChainManager.childToRootToken(address(childToken))!= address(0),"ChildERC20Relay: TOKEN_NOT_MAPPED");
        }
        relayerTokenStates[relayer][childToken] = state;
        emit StateUpdated(relayer, address(childToken), state);
    }

    function setRelayerTokenFees(IChildToken childToken, uint256 fee) external onlyActive(msgSender()){
        address relayer = msgSender();
        relayerTokenFees[relayer][childToken] = fee;
        emit FeeUpdated(relayer, address(childToken), fee);
    }

    function setTokenRefuelStates( IChildToken childToken, bool state) external only(REFUELER_ROLE){
        if(state){
            require(childChainManager.childToRootToken(address(childToken))!= address(0),"ChildERC20Relay: TOKEN_NOT_MAPPED");
        }
        tokenRefuelStates[childToken] = state;
        emit RefuelStateUpdated(address(childToken), state);
    }

    function setTokenRefuelFees( IChildToken childToken, uint256 refuelFee) external only(REFUELER_ROLE){
        tokenRefuelFees[childToken] = refuelFee;
        emit RefuelFeeUpdated(address(childToken), refuelFee);
    }
    
    function withdrawToByRelayer(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount, address relayer, bool withRefuel,uint256 expectedRefuelFee,uint256 expectedRelayerFee)
    external onlyActive(relayer){
        require(relayerTokenStates[relayer][tokenExit], "ChildERC20Relay: unsupported relayer and exitToken");

        _updateHourlyCount(relayer);

        uint256 refuelFee = 0;
        if (withRefuel) {
            require(tokenRefuelStates[tokenExit], "ChildERC20Relay: unsupported exitToken for refuel");
            refuelFee = tokenRefuelFees[tokenExit];
            require(refuelFee == expectedRefuelFee, "ChildERC20Relay: Mismatch refuelFee");
        }
        uint256 fee = relayerTokenFees[relayer][tokenExit];
        require(fee == expectedRelayerFee, "ChildERC20Relay: Mismatch fee");

        require(amount > fee + refuelFee, "ChildERC20Relay: amount must be larger than fee");
        uint256 actualExit = amount - fee - refuelFee;

        uint256 _nonce = nonce + 1;
        nonce = _nonce;
        emit RelayStart(_nonce, relayer);

        IERC20(tokenWithdraw).safeTransferFrom(msgSender(), address(this), amount);
        if(fee > 0){
            IERC20(tokenWithdraw).transfer(relayer, fee);
        }
        if(refuelFee > 0){
            IERC20(tokenWithdraw).transfer(getRoleMember(REFUELER_ROLE, 0), refuelFee);
        }

        if (!approved[tokenWithdraw]) {
            IERC20(tokenWithdraw).approve(address(exitHelper), uint256(-1));
            approved[tokenWithdraw] = true;
        }

        emit RelayExit(_nonce, relayer, to, address(tokenWithdraw), address(tokenExit), actualExit, fee, withRefuel, refuelFee);
        exitHelper.withdrawTo(to, tokenWithdraw, tokenExit, actualExit);

        emit RelayEnd(_nonce, relayer);
    }

    function withdrawBTTByRelayer(address to, IChildToken tokenWithdraw, IChildToken tokenExit, uint256
        amount, address payable relayer, bool withRefuel,uint256 expectedRefuelFee,uint256 expectedRelayerFee)
    payable external  onlyActive(relayer){

        require(relayerTokenStates[relayer][tokenExit], "ChildERC20Relay: unsupported relayer and exitToken");

        _updateHourlyCount(relayer);

        uint256 refuelFee = 0;
        if (withRefuel) {
            require(tokenRefuelStates[tokenExit], "ChildERC20Relay: unsupported relayer and exitToken for refuel");
            refuelFee = tokenRefuelFees[tokenExit];
            require(refuelFee == expectedRefuelFee, "ChildERC20Relay: Mismatch refuelFee");
        }
        uint256 fee = relayerTokenFees[relayer][tokenExit];
        require(fee == expectedRelayerFee, "ChildERC20Relay: Mismatch fee");

        require(amount > fee + refuelFee, "ChildERC20Relay: amount must be larger than fee");
        uint256 actualExit = amount - fee - refuelFee;

        uint256 _nonce = nonce + 1;
        nonce = _nonce;
        emit RelayStart(_nonce, relayer);

        if (address(tokenWithdraw) == address(0x1010)) {
            require(msg.value >= amount, "ChildERC20Relay: msg value can't be less than amount");
            if(fee > 0){
                relayer.transfer(fee);
            }
            if(refuelFee > 0){
                payable(getRoleMember(REFUELER_ROLE, 0)).transfer(refuelFee);
            }

            emit RelayExit(_nonce, relayer, to, address(tokenWithdraw), address(tokenExit), actualExit, fee, withRefuel, refuelFee);
            exitHelper.withdrawBTT{value:actualExit}(to, tokenWithdraw, tokenExit, actualExit);

            emit RelayEnd(_nonce, relayer);

            if (msg.value > amount) {
                msg.sender.transfer(msg.value - amount);
            }
            return;
        }

        IERC20(tokenWithdraw).safeTransferFrom(msgSender(), address(this), amount);

        if(fee > 0){
            IERC20(tokenWithdraw).transfer(relayer, fee);
        }
        if(refuelFee > 0){
            IERC20(tokenWithdraw).transfer(getRoleMember(REFUELER_ROLE, 0), refuelFee);
        }
        if (!approved[tokenWithdraw]) {
            IERC20(tokenWithdraw).approve(address(exitHelper), uint256(-1));
            approved[tokenWithdraw] = true;
        }

        emit RelayExit(_nonce, relayer, to, address(tokenWithdraw), address(tokenExit), actualExit, fee, withRefuel, refuelFee);
        exitHelper.withdrawBTT(to, tokenWithdraw, tokenExit, actualExit);

        emit RelayEnd(_nonce, relayer);
    }

    function _updateHourlyCount(address relayer) internal{
        uint8 currentHour = uint8(block.timestamp / 3600);
        HourlyCount storage hc = currentHourlyCount[relayer];

        if(hc.hour == currentHour){
            require(hc.count < maxHourlyOrders,"ChildERC20Relay: exceeds max hourly count");
            hc.count += 1;
        }else{
            hc.hour = currentHour;
            hc.count = 1;
        }
    }

    function setMaxHourlyOrders(uint256 maxNew) external only(DEFAULT_ADMIN_ROLE){
        require(maxNew > 0, "ChildERC20Relay: need non-zero value");
        maxHourlyOrders = maxNew;
        emit MaxHourlyOrdersUpdated(maxNew);
    }

    function setRefueler(address addr) external only(DEFAULT_ADMIN_ROLE) {
        for (int i = 0; i < 255; i++) {
            if (getRoleMemberCount(REFUELER_ROLE) >= 1) {
                revokeRole(REFUELER_ROLE, getRoleMember(REFUELER_ROLE, 0));
            } else {
                break;
            }
        }
        _setupRole(REFUELER_ROLE, addr);
    }

    function getCurrentHourlyCount(address relayer) view public returns(uint64){
        uint8 currentHour = uint8(block.timestamp / 3600);
        HourlyCount memory hc = currentHourlyCount[relayer];
        if(hc.hour == currentHour){
            return hc.count;
        }else{
            return 0;
        }
    }  
}
