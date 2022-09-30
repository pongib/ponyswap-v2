// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./PonyswapV2Pair.sol";
import "./interfaces/IPonyswapV2Pair.sol";

import "forge-std/console.sol";

error IdenticalAddresses();
error PairExists();
error ZeroAddress();

contract PonyswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 length
    );

    function createPair(address tokenA, address tokenB)
        public
        returns (address pair)
    {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        if (token0 == address(0)) revert ZeroAddress();

        if (pairs[token0][token1] != address(0)) revert PairExists();

        bytes memory bytecode = type(PonyswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        console.logBytes32(salt);
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        console.log(pair);

        IPonyswapV2Pair(pair).initialize(token0, token1);

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;

        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
