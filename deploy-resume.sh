#!/usr/bin/env bash
# PriceGuard — RESUME deployment (step 0 conversion already done 2026-11-21:
# 0.1 Base Sepolia ETH -> 10 lREACT confirmed, tx 0xbd5996f6a8739a94916ed58292791ac2b859bdf4a5bbf9d1d2fa21e52550a024).
# Fixes vs deploy.sh: forge create needs --broadcast (without it = dry run, empty addresses);
# address guards abort loudly if any deploy returns empty.
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
set -a; source .env; set +a

BASE=https://sepolia.base.org
LASNA=https://lasna-rpc.rnk.dev/
PROXY=0x476F44b11F5C942c58f4c8E3d0300E5710743585   # Base Sepolia callback proxy
ME=$DEPLOYER_ADDRESS

echo "== 0. lREACT balance check (conversion already done) =="
echo "lREACT balance: $(cast balance $ME --rpc-url $LASNA)"

echo "== 1. Base Sepolia: tokens + price feed =="
GRD=$(forge create src/MockERC20.sol:MockERC20 --rpc-url $BASE --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "GuardToken" "GRD" | awk '/Deployed to:/{print $3}')
MUSD=$(forge create src/MockERC20.sol:MockERC20 --rpc-url $BASE --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "MockUSD" "MUSD" | awk '/Deployed to:/{print $3}')
FEED=$(forge create src/PriceFeed.sol:PriceFeed --rpc-url $BASE --private-key $PRIVATE_KEY --broadcast \
  | awk '/Deployed to:/{print $3}')
[ -n "$GRD" ] && [ -n "$MUSD" ] && [ -n "$FEED" ] || { echo "ABORT: empty address in step 1 (GRD=$GRD MUSD=$MUSD FEED=$FEED)"; exit 1; }
echo "GRD=$GRD MUSD=$MUSD FEED=$FEED"

echo "== 2. Lasna: reactive contract (stop-loss at \$90, funded with 5 lREACT) =="
REACTIVE=$(forge create src/GuardianReactive.sol:GuardianReactive --rpc-url $LASNA \
  --private-key $PRIVATE_KEY --broadcast --value 5ether \
  --constructor-args $FEED $GRD 90000000000000000000 true | awk '/Deployed to:/{print $3}')
[ -n "$REACTIVE" ] || { echo "ABORT: reactive deploy failed"; exit 1; }
echo "REACTIVE=$REACTIVE"

echo "== 3. Base Sepolia: vault (funded with 0.02 ETH for callback payments) =="
VAULT=$(forge create src/GuardianVault.sol:GuardianVault --rpc-url $BASE \
  --private-key $PRIVATE_KEY --broadcast --value 0.02ether \
  --constructor-args $PROXY $REACTIVE $GRD $MUSD $ME | awk '/Deployed to:/{print $3}')
[ -n "$VAULT" ] || { echo "ABORT: vault deploy failed"; exit 1; }
echo "VAULT=$VAULT"

echo "== 4. Wire vault into the reactive contract =="
cast send $REACTIVE --rpc-url $LASNA --private-key $PRIVATE_KEY "setVault(address)" $VAULT

echo "== 5. Fund the demo position: 100 GRD deposited, 20,000 MUSD reserve =="
cast send $GRD --rpc-url $BASE --private-key $PRIVATE_KEY "mint(address,uint256)" $ME 100000000000000000000
cast send $MUSD --rpc-url $BASE --private-key $PRIVATE_KEY "mint(address,uint256)" $VAULT 20000000000000000000000
cast send $GRD --rpc-url $BASE --private-key $PRIVATE_KEY "approve(address,uint256)" $VAULT 100000000000000000000
cast send $VAULT --rpc-url $BASE --private-key $PRIVATE_KEY "deposit(uint256)" 100000000000000000000

echo "== 6. Trigger the loop: price 100 (no fire), then 80 (FIRE) =="
cast send $FEED --rpc-url $BASE --private-key $PRIVATE_KEY "pushPrice(address,uint256)" $GRD 100000000000000000000
cast send $FEED --rpc-url $BASE --private-key $PRIVATE_KEY "pushPrice(address,uint256)" $GRD 80000000000000000000

echo "Addresses: GRD=$GRD MUSD=$MUSD FEED=$FEED REACTIVE=$REACTIVE VAULT=$VAULT"
echo "Now poll: cast call $VAULT 'executed()(bool)' --rpc-url $BASE  (expect true within ~1 min)"
echo "And:     cast call $MUSD 'balanceOf(address)(uint256)' $ME --rpc-url $BASE  (expect 8000e18)"
