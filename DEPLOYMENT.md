# PriceGuard — Deployment Record & Runbook

Status as of Sat 21 Nov 2026: **DEPLOYED AND FULL LOOP VERIFIED ON-CHAIN.**
CEO funded the deployer with 0.151 Base Sepolia ETH on the morning of 21 Nov;
deployment ran the same morning. First `deploy.sh` run converted the lREACT
then stalled: `forge create` without `--broadcast` only dry-runs (empty
addresses, next step failed). Fixed in `deploy.sh` and executed via
`deploy-resume.sh` (skips the completed conversion; adds `--broadcast` and
empty-address guards). Logs: `deploy-run-20261121.log`,
`deploy-resume-run-20261121.log`.

**Verification (read back on-chain by Longan, 21 Nov ~07:19 WIB):**
- `GuardianVault.executed()` = **true** (first poll after the $80 push).
- Deployer MUSD balance = **8,000e18 exactly** (100 GRD × $80 trigger price).
- Vault MUSD reserve 20,000 → 12,000 (paid out 8,000); vault retains the
  100 GRD — settlement is from the vault's buy-out reserve, as designed
  (runbook step 6), not a market sale.
- Callback landed at Base Sepolia block 61492315, nine blocks after the
  $80 `pushPrice` (block 61492306).

## Deployer wallet

- Address: `0xe73684D70E244E1ae7A1c8C2694f76f802B97AcC`
- Key: stored ONLY in `~/workspace/reactive-entry/.env` (chmod 600). Testnet-only wallet.
- Balances at last check (20 Nov 2026): 0 on Sepolia, Base Sepolia, and Lasna.

## Blocker — testnet funding needs one human faucet claim

Every usable faucet for Sepolia / Base Sepolia ETH is gated by an interactive
check that cannot be completed from a terminal:

- pk910 Sepolia PoW faucet (sepolia-faucet.pk910.de): its public API config
  (fetched 20 Nov 2026) shows a captcha module with `requiredForStart: true` —
  a session cannot even be started without solving it in a browser.
- Alchemy / Coinbase / Chainlink / thirdweb / QuickNode faucets: account
  login, wallet-connect UI, or social verification.
- No Reactive-operated web faucet answers (faucet.reactive.network does not
  resolve; the Lasna explorer has no faucet page). The docs' only lREACT route
  is the faucet *contract*, which itself needs Sepolia ETH first.

**Exact action needed from CEO (about 2 minutes, one time):**
Claim testnet ETH to `0xe73684D70E244E1ae7A1c8C2694f76f802B97AcC` — either
(a) Base Sepolia ETH ≥ 0.15 ETH via the Coinbase or Alchemy Base Sepolia
faucet, or (b) Sepolia ETH ≥ 0.2 ETH via the pk910 PoW faucet
(sepolia-faucet.pk910.de, mine ~2–3 minutes in the browser).
Option (a) is simpler: the lREACT conversion contract also lives on Base
Sepolia, so one claim funds everything. Then say "done" and the deployment
below runs from the terminal with no further human steps.

## Deployment runbook (executed by `./deploy.sh` once funded)

Networks: Base Sepolia (chain 84532, RPC https://sepolia.base.org) and
Reactive Lasna (chain 5318007, RPC https://lasna-rpc.rnk.dev/).

1. Convert 0.1 Base Sepolia ETH → 10 lREACT via faucet contract
   `0x2afaFD298b23b62760711756088F75B7409f5967` `request(address)`.
2. Base Sepolia: deploy MockERC20 "GuardToken" (GRD), MockERC20 "MockUSD"
   (MUSD), PriceFeed.
3. Lasna: deploy GuardianReactive(feed, GRD, trigger = 90e18, stop-loss = true)
   with 5 lREACT attached.
4. Base Sepolia: deploy GuardianVault(proxy = 0x476F44b11F5C942c58f4c8E3d0300E5710743585,
   sender = GuardianReactive, GRD, MUSD, beneficiary = deployer) with
   0.02 ETH attached (callback payments).
5. Lasna: `GuardianReactive.setVault(vault)`.
6. Base Sepolia: mint 100 GRD to deployer → approve → `vault.deposit(100 GRD)`;
   mint 20,000 MUSD directly to the vault (buy-out reserve).
7. Trigger: `feed.pushPrice(GRD, 100e18)` (above the line — must NOT fire),
   then `feed.pushPrice(GRD, 80e18)` (breach — fires).
8. Verify: `vault.executed()` = true on Base Sepolia; deployer's MUSD balance
   = 8,000 (100 GRD × $80); find the callback tx (proxy → vault) on
   sepolia.basescan.org and the reactive tx on lasna.reactscan.net.

## Deployed addresses & proof transactions

_To be filled in the moment the runbook completes._

| Item | Address / Hash |
|---|---|
| GuardToken (GRD), Base Sepolia | `0xB5DA0Bb37c6Ed71FaD035d3C29Eb28aB9CdE3b70` |
| MockUSD (MUSD), Base Sepolia | `0x2604f452373b82F9b67905C044ee1C8c257a0c04` |
| PriceFeed, Base Sepolia | `0xF4c5eC147CF6241ef871D8dD3A724c7e84f79E11` |
| GuardianReactive, Lasna | `0xE4cDf76C65D9af4916842365191262a6176bd73F` |
| GuardianVault, Base Sepolia | `0x46f6f217ADE55A52b3874AEe6E7183935Ebe38e6` |
| lREACT conversion tx (Base Sepolia) | `0xbd5996f6a8739a94916ed58292791ac2b859bdf4a5bbf9d1d2fa21e52550a024` |
| setVault wiring tx (Lasna) | `0xd2efbe10a7bcb0f7b685b88e08814e18a4d705fa116622dc3f80aaa16cfce428` |
| Origin event tx, pushPrice $100 (no fire) | `0xaa15e7cea6028fd883f11cc581ff31532c0ec5597b65d5900028dc9753055234` |
| Origin event tx, pushPrice $80 (breach) | `0x380d058c9f188ef7043433b42be1319cf23fd7298b05c4c778bb26058dd2aec2` |
| Callback tx on Base Sepolia (vault execution + 8,000 MUSD payout) | `0x1dc6a39d91397c2b3c8fc7f62edb2344b785608c977ef307e57f08c3c0ee8969` |

Remaining for the submission: public GitHub repo + push, demo video (<3 min,
script in `DEMO-SCRIPT.md`), DoraHacks project registration under the
"Set It and Forget It" track. Deadline: Sat 6 Dec 2026 03:00 WIB.
