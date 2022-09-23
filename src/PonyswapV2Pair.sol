// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "forge-std/console.sol";
import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();
error InsufficientOutputAmount();
error InsufficientLiquidity();
error InvalidK();
error BalanceOverflow();
error AlreadyInitialized();

contract PonyswapV2Pair is ERC20, Math {
    using UQ112x112 for uint224;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    address public s_token0;
    address public s_token1;
    uint112 private s_reserve0;
    uint112 private s_reserve1;
    uint32 private s_blockTimestampLast;

    uint256 public s_price0CumulativeLast;
    uint256 public s_price1CumulativeLast;

    event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Swap(
        address indexed sender,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    constructor(address token0, address token1)
        ERC20("PonyswapV2 LP", "PONY-LP", 18)
    {
        s_token0 = token0;
        s_token1 = token1;
    }

    function initialize(address token0, address token1) public {
        if (s_token0 != address(0) || s_token1 != address(0))
            revert AlreadyInitialized();

        s_token0 = token0;
        s_token1 = token1;
    }

    function mint() public {
        (uint112 reserve0, uint112 reserve1, ) = getReserves();
        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this));
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;
        uint256 liquidity;

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
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
        _update(balance0, balance1, reserve0, reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn() public {
        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[msg.sender];
        uint256 amount0 = (balance0 * liquidity) / totalSupply;
        uint256 amount1 = (balance1 * liquidity) / totalSupply;

        if (amount0 <= 0 || amount1 <= 0) revert InsufficientLiquidityBurned();

        _burn(msg.sender, liquidity);
        _safeTransfer(s_token0, msg.sender, amount0);
        _safeTransfer(s_token1, msg.sender, amount1);

        balance0 = IERC20(s_token0).balanceOf(address(this));
        balance1 = IERC20(s_token1).balanceOf(address(this));

        (uint112 reserve0, uint112 reserve1, ) = getReserves();

        _update(balance0, balance1, reserve0, reserve1);

        emit Burn(msg.sender, amount0, amount1);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) public {
        if (amount0Out == 0 && amount1Out == 0)
            revert InsufficientOutputAmount();

        (uint112 reserve0, uint112 reserve1, ) = getReserves();
        if (amount0Out > reserve0 || amount1Out > reserve1)
            revert InsufficientLiquidity();

        uint256 balance0 = IERC20(s_token0).balanceOf(address(this)) -
            amount0Out;
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this)) -
            amount1Out;

        if (balance0 * balance1 < uint256(reserve0) * uint256(reserve1)) {
            revert InvalidK();
        }

        _update(balance0, balance1, reserve0, reserve1);

        if (amount0Out > 0) _safeTransfer(s_token0, msg.sender, amount0Out);
        if (amount1Out > 1) _safeTransfer(s_token1, msg.sender, amount1Out);

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    function sync() public {
        (uint112 reserve0, uint112 reserve1, ) = getReserves();

        _update(
            IERC20(s_token0).balanceOf(address(this)),
            IERC20(s_token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }

    function _update(
        uint256 balance0,
        uint256 balance1,
        uint112 reserve0,
        uint112 reserve1
    ) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max)
            revert BalanceOverflow();

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - s_blockTimestampLast;

            if (timeElapsed > 0 && reserve0 > 0 && reserve1 > 0) {
                s_price0CumulativeLast +=
                    uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) *
                    timeElapsed;

                s_price1CumulativeLast +=
                    uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) *
                    timeElapsed;
            }
        }

        s_reserve0 = uint112(balance0);
        s_reserve1 = uint112(balance1);
        s_blockTimestampLast = uint32(block.timestamp);

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

    function getReserves()
        public
        view
        returns (
            uint112,
            uint112,
            uint32
        )
    {
        return (s_reserve0, s_reserve1, s_blockTimestampLast);
    }
}
