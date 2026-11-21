// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title PriceFeed — the origin contract of the PriceGuard demo (Base Sepolia).
/// @notice A minimal stand-in for a DEX / oracle price source. In production the
///         same reactive subscription would point at a real pair's price event;
///         for the demo, anyone can push a price so the full loop can be
///         triggered on demand and verified on-chain.
///         The reactive contract subscribes to `PriceUpdated` from this address.
contract PriceFeed {
    event PriceUpdated(address indexed token, uint256 price);

    /// @notice Latest pushed price per token, scaled by 1e18
    ///         (MockUSD units per 1 whole guarded token).
    mapping(address => uint256) public priceOf;

    function pushPrice(address token, uint256 price) external {
        priceOf[token] = price;
        emit PriceUpdated(token, price);
    }
}
