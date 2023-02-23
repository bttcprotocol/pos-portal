pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {EnumerableSet} from "../../../common/EnumerableSet.sol";
import {AccessControlMixin} from "../../../common/AccessControlMixin.sol";
import {ContextMixin} from "../../../common/ContextMixin.sol";
import {Initializable} from "../../../common/Initializable.sol";
import {IChildTokenForExchange} from "./IChildTokenForExchange.sol";

contract ChildERC20RelayStake is AccessControlMixin, ContextMixin, Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant COMMUNITY_ROLE = keccak256("COMMUNITY_ROLE");
    uint256 public constant PRECISION = 100;

    IERC20 public usdd_t;
    IERC20 public usdd_e;
    IERC20 public usdd_b;

    enum Status{
        pending,
        staked,
        activated,
        unstaked
    }

    struct RelayerBasic{
        uint256 stakeAmount;
        uint256 unstakedTime;
        uint256 timeInterval;
        Status status;
    }
    mapping(address => RelayerBasic) public relayerBasic;
    EnumerableSet.AddressSet internal relayers;
    uint256 public totalStaked;
    uint256 public penalSum;
    uint256 public withdrawnPenalSum;
    uint256 public timeInterval;
    address public receiver;
    uint256 public hardLimit;
    uint256 public softLimit;
    uint256 public buffer;
    uint256 public orderCost;
    uint256 public scale;
    
    event Stake(address indexed from, uint256 amount, uint256 totalStakedAmount);
    event UnStake(address indexed relayer, uint256 stakeAmount, uint256 availableTime);
    event ActivateRelayer(address indexed relayer);
    event WithdrawCollateral(address indexed relayer, uint256 amount);
    event HardLimitUpdated(uint256 value);
    event SoftLimitUpdated(uint256 value);
    event TimeIntervalUpdated(uint256 value);
    event RelayerTimeIntervalUpdated(address relayer,uint256 interval);
    event OrdersParamsUpdated(uint256 buffer,uint256 scale,uint256 orderCost);
    event ReceiverUpdated(address receiver);
    event Punished(address indexed relayer, uint256 amount, uint256 stakeAmount);
    event Retrieved(uint256 amount);

    function initialize(
        address _admin,
        address _operator,
        address _community,
        address _usdd_t,
        address _usdd_e,
        address _usdd_b,
        address _receiver,
        uint256 _timeInterval) external initializer {
        _setupContractId("ChildERC20RelayStake");
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OPERATOR_ROLE, _operator);
        _setupRole(COMMUNITY_ROLE, _community);
        usdd_t = IERC20(_usdd_t);
        usdd_b = IERC20(_usdd_b);
        usdd_e = IERC20(_usdd_e);
        receiver = _receiver;
        timeInterval = _timeInterval;
    }

    function stake(IERC20 usdd, uint256 amount) external {
        address relayer = msgSender();
        RelayerBasic storage basic = relayerBasic[relayer];

        require(basic.status != Status.unstaked, "ChildERC20RelayStake: incorrect status");
        require(usdd == usdd_t || usdd == usdd_b || usdd == usdd_e,"ChildERC20RelayStake: incorrect usdd address");
        usdd.safeTransferFrom(relayer, address(this), amount);
        if(usdd == usdd_e || usdd == usdd_b){
            IChildTokenForExchange(address(usdd)).swapOut(amount);
        }
        totalStaked = totalStaked.add(amount);
        basic.stakeAmount = basic.stakeAmount.add(amount);
        if(basic.status == Status.pending){
            basic.status = Status.staked;
        }
        emit Stake(relayer,amount,basic.stakeAmount);
    }

    function unstake() external {
        address relayer = msgSender();
        require(relayerBasic[relayer].status == Status.activated, "ChildERC20RelayStake: incorrect status");
        require(relayerBasic[relayer].stakeAmount > 0, "ChildERC20RelayStake: Nothing is staked");

        relayerBasic[relayer].status = Status.unstaked;
        relayerBasic[relayer].unstakedTime = block.timestamp;

        relayers.remove(relayer);
        emit UnStake(relayer,relayerBasic[relayer].stakeAmount,block.timestamp + timeInterval);
    }

    function withdrawCollateral() external{
        address relayer = msgSender();
        RelayerBasic memory basic = relayerBasic[relayer];

        require(basic.status == Status.unstaked || basic.status == Status.staked,"ChildERC20RelayStake: incorrect status");
        
        if(basic.status == Status.unstaked){
            if(basic.timeInterval > 0){
                require(block.timestamp.sub(basic.unstakedTime) >= basic.timeInterval,"ChildERC20RelayStake: less than relayer limit timeInterval");
            }else{
                require(block.timestamp.sub(basic.unstakedTime) >= timeInterval,"ChildERC20RelayStake: less than limit timeInterval");
            }
        }

        delete relayerBasic[relayer];
        
        if(basic.stakeAmount > 0){
            totalStaked = totalStaked.sub(basic.stakeAmount);
            IERC20(usdd_t).safeTransfer(relayer,basic.stakeAmount);
        }
        emit WithdrawCollateral(relayer,basic.stakeAmount);
    }

    function punish(address relayer,uint256 amount) external only(OPERATOR_ROLE){
        require(amount <= relayerBasic[relayer].stakeAmount, "ChildERC20RelayStake: exceeds stake amount");
        require(relayerBasic[relayer].status == Status.activated || relayerBasic[relayer].status == Status.unstaked , "ChildERC20RelayStake: incorrect status");
        relayerBasic[relayer].stakeAmount = relayerBasic[relayer].stakeAmount.sub(amount);
        penalSum = penalSum.add(amount);
        totalStaked = totalStaked.sub(amount);
        emit Punished(relayer,amount,relayerBasic[relayer].stakeAmount);
    }

    function retrieve(uint256 amount) external only(COMMUNITY_ROLE){
        require(amount <= (penalSum.sub(withdrawnPenalSum)), "ChildERC20RelayStake: exceeds penal sum");
        IERC20(usdd_t).safeTransfer(receiver, amount);
        withdrawnPenalSum = withdrawnPenalSum.add(amount);
        emit Retrieved(amount);
    }

    function activateRelayer(address relayer) external only(COMMUNITY_ROLE){
        require(relayer != address(0x00), "ChildERC20RelayStake: relayer should not be zero address");
        require(relayerBasic[relayer].status == Status.staked, "ChildERC20RelayStake: incorrect status");
        require(relayerBasic[relayer].stakeAmount >= softLimit, "ChildERC20RelayStake: less than limit softLimit");
        
        relayers.add(relayer);
        relayerBasic[relayer].status = Status.activated;
        emit ActivateRelayer(relayer);
    }

    function setTimeInterval(uint256 interval) external only(COMMUNITY_ROLE){
        require(interval > 0, "ChildERC20RelayStake: need non-zero value");
        timeInterval = interval;
        emit TimeIntervalUpdated(interval);
    }

    function setHardLimit(uint256 hardLimitNew) external only(COMMUNITY_ROLE){
        require(hardLimitNew >= 0, "ChildERC20RelayStake: need non-zero value");
        hardLimit = hardLimitNew;
        emit HardLimitUpdated(hardLimitNew);
    }

    function setSoftLimit(uint256 softLimitNew) external only(COMMUNITY_ROLE){
        require(softLimitNew >= 0, "ChildERC20RelayStake: need non-zero value");
        softLimit = softLimitNew;
        emit SoftLimitUpdated(softLimitNew);
    }

    function setRelayertimeInterval(address relayer,uint256 interval) external only(COMMUNITY_ROLE){
        require(relayer != address(0x00), "ChildERC20RelayStake: relayer should not be zero address");
        relayerBasic[relayer].timeInterval = interval;
        emit RelayerTimeIntervalUpdated(relayer,interval);
    }

    function setReceiver(address receiverNew) external only(COMMUNITY_ROLE){
        require(receiverNew != address(0x00), "ChildERC20RelayStake: receiverNew should not be zero address");
        receiver = receiverNew;
        emit ReceiverUpdated(receiverNew);
    }

    function setOrdersParams(uint256 bufferNew, uint256 scaleNew, uint256 orderCostNew) external only(OPERATOR_ROLE){
        require(scaleNew > 0 && orderCostNew > 0, "ChildERC20RelayStake: need non-zero value");
        buffer = bufferNew;
        scale = scaleNew;
        orderCost = orderCostNew;
        emit OrdersParamsUpdated(buffer,scale,orderCost);
    }

    function replaceRole(bytes32 role, address addr) external only(role){
        require(addr != address(0x00), "ChildERC20RelayStake: role should not be zero address");
        require(role == OPERATOR_ROLE || role == COMMUNITY_ROLE, "ChildERC20RelayStake: incorrect role");
        renounceRole(role, msgSender());
        _setupRole(role, addr);
    }

    function getMaxHourlyOrders(address relayer) view external returns(uint256){
        uint256 stakeAmount = relayerBasic[relayer].stakeAmount;
        uint256 bufferAmount = hardLimit.mul(buffer).div(PRECISION);

        if(stakeAmount >= bufferAmount){
            return stakeAmount.sub(bufferAmount).mul(PRECISION).div(scale).div(orderCost);
        }
        return 0;  
    }

    function isActive(address relayer) external view returns(bool){
        if(relayerBasic[relayer].status == Status.activated){
            return true;
        }
        return false;
    }

    function isOrderTaking(address relayer) external view returns(bool){
        if(relayerBasic[relayer].status == Status.activated && relayerBasic[relayer].stakeAmount >= hardLimit){
            return true;
        }
        return false;
    }

    function getRelayerStakeAmount(address relayer) external view returns(uint256){
        return relayerBasic[relayer].stakeAmount;
    }

    function getRelayers() public view returns (address[] memory){
        return relayers.values();
    }

}
