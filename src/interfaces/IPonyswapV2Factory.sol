// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

interface IPonyswapV2Factory {
    function pairs(address, address) external pure returns (address);

    function createPair(address, address) external returns (address);
}
