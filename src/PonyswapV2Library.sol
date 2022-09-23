// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./interfaces/IPonyswapV2Factory.sol";
import "./interfaces/IPonyswapV2Pair.sol";
import {PonyswapV2Pair} from "./PonyswapV2Pair.sol";

library PonyswapV2Library {
    error InsufficientAmount();
    error InsufficientLiquidity();

    function getReserves(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) public returns (uint256 reserveA, uint256 reserveB) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IPonyswapV2Pair(
            pairFor(factoryAddress, token0, token1)
        ).getReserves();

        // reserves are sorted back before being returned:
        // we want to return them in the same order as token addresses were specified!
        (reserveA, reserveB) = tokenA == tokenB
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    function pairFor(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal pure returns (address pairAddress) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        pairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryAddress,
                            keccak256(abi.encodePacked(token0, token1)), //salt
                            keccak256(type(PonyswapV2Pair).creationCode)
                        )
                    )
                )
            )
        );
    }

    function quote(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        // calculate liquidity not swap price
        // so it not constant product formula
        return (reserveOut * amountIn) / reserveIn;
    }

    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
