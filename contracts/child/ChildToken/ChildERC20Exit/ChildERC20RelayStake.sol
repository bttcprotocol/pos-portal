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
import {IOracle} from "./IOracle.sol";

contract ChildERC20RelayStake is AccessControlMixin, ContextMixin, Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant COMMUNITY_ROLE = keccak256("COMMUNITY_ROLE");
    bytes32 public constant CFO_ROLE = keccak256("CFO_ROLE");
    uint256 public constant PRECISION = 100;
    IERC20 public constant BTT_T = IERC20(0x0000000000000000000000000000000000001010);
    
    IERC20 public btt_e;
    IERC20 public btt_b;
    IOracle public oracle;

    enum Status{
        pending,
        staked,
        activated,
        unstaked
    }

    struct RelayerBasic{
        uint256 stakeAmount;
        uint256 unstakedTime;
        Status status;
    }
    mapping(address => RelayerBasic) public relayerBasic;
    EnumerableSet.AddressSet internal relayers;
    uint256 public totalStaked;
    uint256 public penalSum;
    uint256 public withdrawnPenalSum;
    uint256 public timeInterval;
    address public receiver;
    
    event Stake(address indexed from, uint256 amount, uint256 totalStakedAmount);
    event UnStake(address indexed relayer, uint256 stakeAmount, uint256 availableTime);
    event ActivateRelayer(address indexed relayer);
    event WithdrawCollateral(address indexed relayer, uint256 amount);
    event TimeIntervalUpdated(uint256 value);
    event Punished(address indexed relayer, uint256 amount, uint256 stakeAmount);
    event Retrieved(address receiver, uint256 amount);
    event ReceiverUpdated(address receiver);
    event OracleUpdated(address oracle);

    function initialize(
        address _admin,
        address _operator,
        address _community,
        address _cfo,
        address _btt_e,
        address _btt_b,
        address _receiver,
        uint256 _timeInterval) external initializer {
        _setupContractId("ChildERC20RelayStake");
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OPERATOR_ROLE, _operator);
        _setupRole(COMMUNITY_ROLE, _community);
        _setupRole(CFO_ROLE, _cfo);
        btt_b = IERC20(_btt_b);
        btt_e = IERC20(_btt_e);
        receiver = _receiver;
        timeInterval = _timeInterval;
    }
    
    receive() external payable {
    }

    function stake(IERC20 btt, uint256 amount) payable external {
        _stake(btt,amount,msgSender());
    }

    function stakeTo(IERC20 btt, uint256 amount, address targetRelayer) payable external {
        require(targetRelayer != address(0x00), "ChildERC20RelayStake: targetRelayer should not be zero address");
        _stake(btt,amount,targetRelayer);
    }

    function _stake(IERC20 btt, uint256 amount, address relayer) internal {
        RelayerBasic storage basic = relayerBasic[relayer];

        require(basic.status != Status.unstaked, "ChildERC20RelayStake: incorrect status");
        require(btt == BTT_T || btt == btt_b || btt == btt_e,"ChildERC20RelayStake: incorrect btt address");
        if(btt == BTT_T){
            require(amount == msg.value, "ChildERC20RelayStake: incorrect btt amount");
        }
        if(btt == btt_e || btt == btt_b){
            btt.safeTransferFrom(msgSender(), address(this), amount);
            IChildTokenForExchange(address(btt)).swapOut(amount);
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
            require(block.timestamp.sub(basic.unstakedTime) >= timeInterval,"ChildERC20RelayStake: less than limit timeInterval");
        }

        delete relayerBasic[relayer];
        
        if(basic.stakeAmount > 0){
            totalStaked = totalStaked.sub(basic.stakeAmount);
            payable(relayer).transfer(basic.stakeAmount);
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

    function retrieve(uint256 amount) external only(CFO_ROLE){
        require(amount <= (penalSum.sub(withdrawnPenalSum)), "ChildERC20RelayStake: exceeds penal sum");
        payable(receiver).transfer(amount);
        withdrawnPenalSum = withdrawnPenalSum.add(amount);
        emit Retrieved(receiver, amount);
    }

    function activateRelayer(address relayer) external only(COMMUNITY_ROLE){
        require(relayer != address(0x00), "ChildERC20RelayStake: relayer should not be zero address");
        require(relayerBasic[relayer].status == Status.staked, "ChildERC20RelayStake: incorrect status");
        
        relayers.add(relayer);
        relayerBasic[relayer].status = Status.activated;
        emit ActivateRelayer(relayer);
    }

    function setTimeInterval(uint256 interval) external only(DEFAULT_ADMIN_ROLE){
        require(interval > 0, "ChildERC20RelayStake: need non-zero value");
        timeInterval = interval;
        emit TimeIntervalUpdated(interval);
    }

    function setReceiver(address receiverNew) external only(DEFAULT_ADMIN_ROLE){
        require(receiverNew != address(0x00), "ChildERC20RelayStake: receiverNew should not be zero address");
        receiver = receiverNew;
        emit ReceiverUpdated(receiverNew);
    }

    function setOracle(address oracleNew) external only(DEFAULT_ADMIN_ROLE){
        require(oracleNew != address(0x00), "ChildERC20RelayStake: oracleNew should not be zero address");
        oracle = IOracle(oracleNew);
        emit OracleUpdated(oracleNew);
    }

    function replaceRole(bytes32 role, address addr) external only(role){
        require(addr != address(0x00), "ChildERC20RelayStake: role should not be zero address");
        require(role == OPERATOR_ROLE || role == COMMUNITY_ROLE || role == CFO_ROLE, "ChildERC20RelayStake: incorrect role");
        renounceRole(role, msgSender());
        _setupRole(role, addr);
    }

    function getMaxHourlyOrders(address relayer) view external returns(uint256){
        uint256 stakeAmount = relayerBasic[relayer].stakeAmount;
        uint256 hardLimit = oracle.hardLimit();
        uint256 scale = oracle.scale();
        uint256 orderCost = oracle.orderCost();
        if(stakeAmount >= hardLimit){
            return stakeAmount.sub(hardLimit).mul(PRECISION).div(scale).div(orderCost);
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
        uint256 hardLimit = oracle.hardLimit();
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
