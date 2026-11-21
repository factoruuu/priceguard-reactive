// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { MockERC20 } from "../src/MockERC20.sol";
import { PriceFeed } from "../src/PriceFeed.sol";
import { GuardianVault } from "../src/GuardianVault.sol";
import { GuardianReactive } from "../src/GuardianReactive.sol";

/// @notice Stands in for the Reactive system contract at 0x8888... in tests:
///         records subscriptions and callback requests so the test can prove
///         the reactive contract asked for exactly the right callback.
contract MockSystem {
    uint256 public subscribeCalls;
    uint256 public unsubscribeCalls;
    uint256 public callbackCalls;
    uint256 public lastCallbackChainId;
    address public lastCallbackRecipient;
    bytes public lastCallbackPayload;

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        subscribeCalls++;
    }

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        unsubscribeCalls++;
    }

    function requestCallback(ISystemContract.CallbackVersion, bytes memory) external {
        callbackCalls++;
    }

    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory config_) external {
        callbackCalls++;
        lastCallbackChainId = config_.chainId;
        lastCallbackRecipient = config_.recipient;
        lastCallbackPayload = config_.payload;
    }

    function debt(address) external pure returns (uint256) {
        return 0;
    }
}

contract PriceGuardTest is Test {
    address internal constant SYSTEM_ADDR = 0x8888888888888888888888888888888888888888;
    address payable internal proxy = payable(address(0xCA11BAC7)); // stand-in for the callback proxy
    address internal user = makeAddr("user");

    MockERC20 internal guard;
    MockERC20 internal usd;
    PriceFeed internal feed;
    GuardianVault internal vault;
    GuardianReactive internal reactive;
    MockSystem internal sys;

    uint256 internal constant TRIGGER = 90e18; // stop-loss line: $90

    function setUp() public {
        // Put the mock system contract at the real system contract address so
        // AbstractReactive's hardcoded SYSTEM points at it.
        sys = new MockSystem();
        vm.etch(SYSTEM_ADDR, address(sys).code);

        guard = new MockERC20("GuardToken", "GRD");
        usd = new MockERC20("MockUSD", "MUSD");
        feed = new PriceFeed();

        reactive = new GuardianReactive{ value: 1 ether }(address(feed), address(guard), TRIGGER, true);
        vault = new GuardianVault{ value: 1 ether }(
            IPayable(proxy), address(reactive), guard, usd, user
        );
        reactive.setVault(address(vault));

        // Fund the demo: user holds 100 GRD and deposits them; vault holds a
        // 20,000 MUSD reserve to buy the position out with.
        guard.mint(user, 100e18);
        usd.mint(address(vault), 20_000e18);
        vm.startPrank(user);
        guard.approve(address(vault), 100e18);
        vault.deposit(100e18);
        vm.stopPrank();
    }

    function _priceLog(uint256 price) internal view returns (IReactive.LogRecord memory log_) {
        log_.chainId = 84532;
        log_.contractAddress = address(feed);
        log_.topic0 = uint256(keccak256("PriceUpdated(address,uint256)"));
        log_.topic1 = uint256(uint160(address(guard)));
        log_.data = abi.encode(price);
        log_.opCode = 2;
    }

    function test_subscribedOnDeploy() public view {
        assertEq(MockSystem(SYSTEM_ADDR).subscribeCalls(), 1);
    }

    function test_noFireAboveTrigger() public {
        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(95e18));
        assertEq(MockSystem(SYSTEM_ADDR).callbackCalls(), 0);
        assertFalse(reactive.fired());
    }

    function test_fireAtTriggerRequestsCallback() public {
        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(90e18));
        assertTrue(reactive.fired());
        MockSystem s = MockSystem(SYSTEM_ADDR);
        assertEq(s.callbackCalls(), 1);
        assertEq(s.lastCallbackChainId(), 84532);
        assertEq(s.lastCallbackRecipient(), address(vault));
        // One-shot: unsubscribed after firing.
        assertEq(s.unsubscribeCalls(), 1);
    }

    function test_fullLoopSellsPosition() public {
        // 1. Price crashes through the stop-loss line.
        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(80e18));

        // 2. The proxy delivers the callback: first payload word is the
        //    reactive contract's address, injected by the proxy.
        bytes memory payload = MockSystem(SYSTEM_ADDR).lastCallbackPayload();
        bytes memory args = new bytes(payload.length - 4);
        for (uint256 i = 4; i < payload.length; i++) {
            args[i - 4] = payload[i];
        }
        (address injected, uint256 price) = abi.decode(args, (address, uint256));
        assertEq(injected, address(0)); // placeholder the proxy overwrites
        assertEq(price, 80e18);

        vm.prank(proxy);
        vault.executeGuard(address(reactive), price);

        // 3. Position converted: 100 GRD sold at $80 -> 8,000 MUSD to the user.
        assertTrue(vault.executed());
        assertEq(usd.balanceOf(user), 8_000e18);
        assertEq(guard.balanceOf(address(vault)), 100e18); // vault keeps the sold tokens
        assertEq(usd.balanceOf(address(vault)), 12_000e18);
    }

    function test_vaultRejectsStrangers() public {
        vm.expectRevert();
        vault.executeGuard(address(reactive), 80e18); // caller is not the proxy
    }

    function test_vaultRejectsWrongReactiveSender() public {
        vm.prank(proxy);
        vm.expectRevert();
        vault.executeGuard(address(0xBAD), 80e18); // proxy caller, wrong sender
    }

    function test_reactRejectsNonSystem() public {
        vm.expectRevert();
        reactive.react(_priceLog(80e18)); // caller is not the system contract
    }
}
