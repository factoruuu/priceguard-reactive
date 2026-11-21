// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";
import { MockERC20 } from "./MockERC20.sol";

/// @title GuardianVault — the destination contract of PriceGuard (Base Sepolia).
/// @notice Custodies one user's position in the guarded token plus a MockUSD
///         reserve. When the reactive contract on Lasna reports that the price
///         crossed the user's line, the Reactive Network callback proxy calls
///         `executeGuard` here and the whole position is converted into
///         MockUSD at the triggering price and paid out to the beneficiary.
///
///         Authentication is the standard Reactive two-step: the caller must be
///         the chain's callback proxy (`onlyServiceProvider`) and the address
///         the proxy injects as the first argument must be our reactive
///         contract (`onlyCallbackSender`). Nobody else can trigger a sale.
contract GuardianVault is AbstractCallback {
    MockERC20 public immutable guardToken;
    MockERC20 public immutable stableToken;
    address public immutable beneficiary;

    /// @notice One-shot: after the guard fires once, it never fires again.
    bool public executed;
    uint256 public executedPrice;
    uint256 public executedAmountIn;
    uint256 public executedAmountOut;

    event Deposited(address indexed from, uint256 amount);
    event GuardExecuted(uint256 price, uint256 amountIn, uint256 amountOut);

    constructor(
        IPayable callbackProxy_,
        address callbackSender_,
        MockERC20 guardToken_,
        MockERC20 stableToken_,
        address beneficiary_
    ) payable AbstractCallback(callbackProxy_, callbackSender_) {
        guardToken = guardToken_;
        stableToken = stableToken_;
        beneficiary = beneficiary_;
    }

    /// @notice Fund the position the guard protects.
    function deposit(uint256 amount) external {
        require(guardToken.transferFrom(msg.sender, address(this), amount), "transfer");
        emit Deposited(msg.sender, amount);
    }

    /// @notice Callback entry point. The first argument is overwritten by the
    ///         callback proxy with the reactive contract's address.
    /// @param sender_ Reactive contract address (injected by the proxy).
    /// @param price_  Triggering price, scaled by 1e18 (MockUSD per token).
    function executeGuard(address sender_, uint256 price_)
        external
        onlyServiceProvider
        onlyCallbackSender(sender_)
    {
        require(!executed, "already executed");
        executed = true;
        executedPrice = price_;

        uint256 amountIn = guardToken.balanceOf(address(this));
        executedAmountIn = amountIn;
        if (amountIn == 0) {
            emit GuardExecuted(price_, 0, 0);
            return;
        }

        uint256 amountOut = (amountIn * price_) / 1e18;
        require(stableToken.balanceOf(address(this)) >= amountOut, "reserve");
        executedAmountOut = amountOut;

        require(stableToken.transfer(beneficiary, amountOut), "payout");
        emit GuardExecuted(price_, amountIn, amountOut);
    }

    /// @notice Settles any outstanding debt to the callback proxy from this
    ///         contract's own ETH balance (standard Reactive maintenance).
    function coverDebt() external {
        _coverDebt();
    }
}
