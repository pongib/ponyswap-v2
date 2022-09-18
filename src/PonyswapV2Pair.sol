// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";
import "forge-std/console.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();

contract PonyswapV2Pair is ERC20, Math {
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    address private s_token0;
    address private s_token1;
    uint112 private s_reserve0;
    uint112 private s_reserve1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address token0, address token1)
        ERC20("PonyswapV2 LP", "PONY-LP", 18)
    {
        s_token0 = token0;
        s_token1 = token1;
    }

    function mint() public {
        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this));
        uint256 amount0 = balance0 - s_reserve0;
        uint256 amount1 = balance1 - s_reserve1;
        uint256 liquidity;

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            console.log("amount0", amount0);
            console.log("amount1", amount1);
            console.log("s_reserve0", s_reserve0);
            console.log("s_reserve1", s_reserve1);
            console.log("LP amount0", (totalSupply * amount0) / s_reserve0);
            console.log("LP amount1", (totalSupply * amount1) / s_reserve1);
            liquidity = Math.min(
                (totalSupply * amount0) / s_reserve0,
                (totalSupply * amount1) / s_reserve1
            );
            console.log("liquidity", liquidity);
        }

        if (liquidity <= 0) {
            revert InsufficientLiquidityMinted();
        }

        _mint(msg.sender, liquidity);
        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn() public {
        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[msg.sender];
        uint256 amount0 = (balance0 * liquidity) / totalSupply;
        uint256 amount1 = (balance1 * liquidity) / totalSupply;

        if (amount0 <= 0 || amount1 <= 0) {
            revert InsufficientLiquidityBurned();
        }

        _burn(msg.sender, liquidity);
        _safeTransfer(s_token0, msg.sender, amount0);
        _safeTransfer(s_token1, msg.sender, amount1);

        _sync();
    }

    function _sync() public {
        _update(
            IERC20(s_token0).balanceOf(address(this)),
            IERC20(s_token1).balanceOf(address(this))
        );
    }

    function _update(uint256 balance0, uint256 balance1) private {
        s_reserve0 = uint112(balance0);
        s_reserve1 = uint112(balance1);

        emit Sync(s_reserve0, s_reserve0);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert TransferFailed();
    }

    function getReserve()
        public
        view
        returns (
            uint112,
            uint112,
            uint32
        )
    {
        return (s_reserve0, s_reserve1, 0);
    }
}
