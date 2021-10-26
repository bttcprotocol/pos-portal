pragma solidity 0.6.6;

import {ChildERC20} from "./ChildERC20.sol";

/// TRC20.sol -- API for the TRC20 token standard

// See <https://github.com/tronprotocol/tips/blob/master/tip-20.md>.

// This file likely does not meet the threshold of originality
// required for copyright to apply.  As a result, this is free and
// unencumbered software belonging to the public domain.


contract WBTT is ChildERC20 {

    constructor(
      string memory name_,
      string memory symbol_,
      address childChainManager
    ) public ChildERC20(name_, symbol_, 18, childChainManager) {
    }

    receive() external payable {
        swapIn();
    }

    function swapIn() public payable {
        if (msg.value > 0){
            _balances[msg.sender] += msg.value;
            _totalSupply += msg.value;
            emit Transfer(address(0x1), msg.sender, msg.value);
        }
    }

    function swapOut(uint sad) public {
        require(sad >= 0, "not enough sad");
        require(_balances[msg.sender] >= sad, "not enough balance");
        require(_totalSupply >= sad, "not enough totalSupply");
        _balances[msg.sender] -= sad;
        msg.sender.transfer(sad);
        _totalSupply -= sad;
        emit Transfer(msg.sender, address(0x1), sad);
    }
}


