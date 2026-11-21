// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/// @title GuardianReactive — the reactive contract of PriceGuard (Reactive Lasna).
/// @notice Watches `PriceUpdated` events from a PriceFeed on the origin chain.
///         The moment the price crosses the owner's line (stop-loss: at or
///         below the trigger; take-profit: at or above it), it requests one
///         callback to the GuardianVault on the destination chain, which sells
///         the position into a stable token. Then it unsubscribes: a guardian
///         that has fired its one shot goes quiet instead of billing forever.
contract GuardianReactive is AbstractReactive {
    uint256 public constant ORIGIN_CHAIN_ID = 84532; // Base Sepolia
    uint256 public constant DESTINATION_CHAIN_ID = 84532; // Base Sepolia
    uint64 public constant CALLBACK_GAS_LIMIT = 1_000_000;

    uint256 public constant PRICE_UPDATED_TOPIC0 =
        uint256(keccak256("PriceUpdated(address,uint256)"));

    address public immutable feed;
    address public immutable token;
    uint256 public immutable triggerPrice;
    bool public immutable isStopLoss;

    address public owner;
    address public vault;
    bool public fired;
    uint256 public lastPrice;
    uint256 public firedPrice;

    event VaultSet(address vault);
    event GuardFired(uint256 price, uint256 triggerPrice, bool isStopLoss);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    /// @param feed_ PriceFeed address on the origin chain.
    /// @param token_ The guarded token (indexed topic of the price event).
    /// @param triggerPrice_ The line, scaled by 1e18 (MockUSD per token).
    /// @param isStopLoss_ true = fire when price <= trigger; false = fire when price >= trigger.
    constructor(address feed_, address token_, uint256 triggerPrice_, bool isStopLoss_) payable {
        feed = feed_;
        token = token_;
        triggerPrice = triggerPrice_;
        isStopLoss = isStopLoss_;
        owner = msg.sender;

        SYSTEM.subscribe(
            ORIGIN_CHAIN_ID,
            feed_,
            PRICE_UPDATED_TOPIC0,
            uint256(uint160(token_)), // topic1 = indexed token address
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /// @notice Deployment order (per Reactive docs): reactive contract first,
    ///         callback contract second (it hardcodes this contract's address),
    ///         then the vault is wired in here through this setter.
    function setVault(address vault_) external onlyOwner {
        vault = vault_;
        emit VaultSet(vault_);
    }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log_) external onlySystem {
        if (fired || vault == address(0)) return;
        if (log_.topic0 != PRICE_UPDATED_TOPIC0) return;
        if (log_.chainId != ORIGIN_CHAIN_ID || log_.contractAddress != feed) return;
        if (address(uint160(log_.topic1)) != token) return;

        uint256 price = abi.decode(log_.data, (uint256));
        lastPrice = price;

        bool breached = isStopLoss ? (price <= triggerPrice) : (price >= triggerPrice);
        if (!breached) return;

        fired = true;
        firedPrice = price;
        emit GuardFired(price, triggerPrice, isStopLoss);

        bytes memory payload = abi.encodeWithSignature("executeGuard(address,uint256)", address(0), price);
        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: DESTINATION_CHAIN_ID,
                recipient: vault,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );

        // One shot, then go quiet: stop paying for further price events.
        SYSTEM.unsubscribe(
            ORIGIN_CHAIN_ID,
            feed,
            PRICE_UPDATED_TOPIC0,
            uint256(uint160(token)),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /// @notice Settles any outstanding debt to the system contract from this
    ///         contract's own lREACT balance (standard Reactive maintenance).
    function coverDebt() external {
        _coverDebt();
    }
}
