# Reactive Omni Buildathon — Pre-Flight Note

Prepared: Fri 20 Nov 2026 (WIB), by Longan (agent) for CEO.
All facts below were verified live on 20 Nov 2026 from the official DoraHacks
page, the official Reactive blog post (4 Nov 2026), and the official docs at
dev.reactive.network. Where sources disagree, the disagreement is stated.

## 1. Verified deadline

- **DoraHacks (authoritative):** the hackathon event window on the DoraHacks
  detail page is `2026-11-04T12:00:00Z → 2026-12-05T20:00:00Z`.
  → **Submission deadline: Saturday 6 Dec 2026, 03:00 WIB** (20:00 UTC 5 Dec).
- Reactive blog: "runs until December 5th" (consistent with 5 Dec UTC).
- Eventbrite lists the event ending 6 Dec 04:00 PST (= 6 Dec 19:00 WIB), which
  is LATER than DoraHacks — do not rely on it; DoraHacks governs submissions.
- **Safe internal target: submit by Fri 5 Dec 2026 evening WIB.**

Day-of-week check: 5 Dec 2026 is a Saturday; 6 Dec 2026 is a Sunday.

## 2. Submission requirements (from DoraHacks + official blog)

- [ ] Register on DoraHacks and pick ONE track.
- [ ] Public, open-source GitHub repository (public by submission time).
- [ ] Deployed contract addresses.
- [ ] A few transaction hashes showing the FULL loop: origin event → reactive
      transaction → callback on the destination chain. **Entries without
      on-chain reactive transactions and callbacks "aren't scored further."**
- [ ] Demo video under 3 minutes.
- [ ] Everything built during the event (5 Nov – 5 Dec). Prior work may only
      come in as a dependency, not as the submission itself.
- [ ] "Every Second Counts" must run on Lasna testnet. The other two tracks
      may use Reactive mainnet OR Lasna. → We use Lasna (testnet only, per
      hard rule) for all tracks.
- [ ] On Base Sepolia use timestamps, not block counts, for timers/cooldowns
      (200 ms blocks since the Denim upgrade).
- [ ] AI rules: no ban on AI anywhere. In "Reactive Meets AI" the AI must be
      part of the RUNNING system, not just the coding tool; AI-assisted
      projects without in-loop AI belong in "Set It and Forget It".

## 3. Judging criteria (equal weight, scored 1–5 each, judged by Reactive team)

1. **Execution** — does it run? On-chain reactive txs + callbacks required.
2. **Integration** — the reactive contract must do real work, not be bolted on.
3. **Usefulness** — solves a problem real users have.
4. **Craft** — readable code, working demo, followable documentation.

## 4. Tracks & prizes (USD, paid in REACT)

| Track | 1st | 2nd | Notes |
|---|---|---|---|
| Every Second Counts | $2,000 | $250 | Time-sensitive DeFi; Unichain Sepolia and/or Base Sepolia with Lasna in the middle; strongest entries show measured full-loop latency |
| Set It and Forget It | $2,000 | $250 | Personal automation on any supported chain; usefulness over speed |
| Reactive Meets AI | $1,000 | — | AI must be in the running loop |

Eligibility / KYC / payout: no KYC or geographic restriction is stated on the
DoraHacks page or the official blog post (checked 20 Nov 2026). Prizes are
denominated in USD and paid in REACT — expect payout to a wallet supplied via
DoraHacks after judging. (If DoraHacks asks for KYC at payout time, that is a
CEO decision point; nothing in the build depends on it.)

## 5. Chosen track + concept

**Track: Set It and Forget It.**

**Concept — "PriceGuard": set a stop-loss (or take-profit) for your token once,
and a reactive contract watches the price for you — if the price crosses your
line, your position is automatically sold into a stable token. No bot, no
keeper, no staying awake.**

Why this track over the alternatives:
- Same top prize as Every Second Counts ($2,000) but judged on usefulness,
  not on measured latency races against other DeFi builders.
- The concept is explainable in one sentence to a non-technical judge, which
  is exactly what this track's brief asks for ("is this something you'd
  actually leave running?").
- Reactive Meets AI pays half ($1,000, no runner-up) and would force a
  contrived "model" into the loop; a price-threshold guardian is honest,
  provable work. AI stays as our build tool, which this track explicitly
  welcomes.

## 6. Architecture

```
Base Sepolia (origin + destination)          Reactive Lasna (chain 5318007)
-----------------------------------          ------------------------------
PriceFeed (mock oracle)                      GuardianReactive (AbstractReactive)
  pushPrice(token, price)                      - subscribes to PriceUpdated
  emits PriceUpdated(token, price)  ------>    - holds the guard rule
                                               - on breach: SYSTEM.request
GuardianVault (AbstractCallback)               CallbackV_1_0 → Base Sepolia
  holds user's GuardToken + MockUSD  <------   callback via Base Sepolia
  on authenticated callback:                   callback proxy
    sells position → MockUSD at feed price
```

- **Origin event:** `PriceUpdated(address indexed token, uint256 price)` from
  our PriceFeed on Base Sepolia. (Stands in for a DEX/oracle price event;
  README states this plainly.)
- **Reactive contract:** `GuardianReactive` on Lasna, built on
  `AbstractReactive` from the official `reactive-lib-omni`. Subscribes to the
  PriceUpdated topic from the PriceFeed address on chain 84532. Stores the
  rule (token, trigger price, direction). When a price crosses the line it
  requests exactly one callback, then deactivates (one-shot guardian).
- **Destination contract:** `GuardianVault` on Base Sepolia, built on
  `AbstractCallback`, authorized for the Base Sepolia callback proxy
  `0x476F44b11F5C942c58f4c8E3d0300E5710743585` and for our reactive contract
  only. It custodies the demo position (GuardToken, our mock ERC-20) and a
  MockUSD reserve; the callback converts the position to MockUSD at the
  triggering price and emits `GuardExecuted`. Real balance changes, fully
  verifiable on Basescan.
- Deployment order per docs: reactive contract first → callback contract
  (needs reactive address, immutable) → set recipient on reactive contract →
  fund both (lREACT on Lasna for the reactive contract; Base Sepolia ETH for
  the vault, which pays the proxy per callback).

Key protocol facts (docs, verified 20 Nov 2026):
- System contract (Lasna + mainnet): `0x8888888888888888888888888888888888888888`
- Lasna: RPC `https://lasna-rpc.rnk.dev/` (chain ID 5318007, currency lREACT,
  explorer https://lasna.reactscan.net). Chain ID confirmed by live RPC call.
  (The blog also mentions `https://lasna-omni-rpc.rnk.dev`; the docs URL above
  answered correctly, so it is the one we use.)
- lREACT faucet: send Sepolia ETH to the faucet contract — Ethereum Sepolia
  `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434` or Base Sepolia
  `0x2afaFD298b23b62760711756088F75B7409f5967`, call `request(address)` with
  value; rate 1 ETH → 100 lREACT (max 5 ETH/tx).
- Callback proxies (testnet): Base Sepolia
  `0x476F44b11F5C942c58f4c8E3d0300E5710743585`, Ethereum Sepolia
  `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4`, Unichain Sepolia
  `0x775c9B990ADe401060B78D0e98684eEf8d2466C1`.
- Callback authentication: proxy overwrites the first payload argument with
  the reactive contract's address; destination must check BOTH
  `onlyServiceProvider` (caller = proxy) and `onlyCallbackSender` (injected
  address = our reactive contract). `AbstractCallback` provides both.
- Reactive contracts pay for their own reactive transactions in lREACT and go
  silent when in debt — the reactive contract must be funded at deployment.

## 7. Tooling

- Foundry (forge/cast/anvil) is already installed at `~/.foundry/bin`.
- Official library: `Reactive-Network/reactive-lib-omni` (GitHub) — the
  `@reactive` package the docs import (`AbstractReactive`, `AbstractCallback`,
  `ISystemContract`, `IReactive`). Used as a dependency, which the rules
  explicitly allow.
- Solidity ^0.8.29 per the library's pragma.

## 8. Risks / blockers

1. **Testnet funding from a terminal — REALIZED BLOCKER (20 Nov 2026).**
   We need (a) Base Sepolia ETH for deployments + vault callback payments,
   and (b) Sepolia ETH (either chain) to convert into lREACT via the faucet
   contract. All terminal routes were tried and are gated: the pk910 PoW
   faucet's live API config requires a captcha before a session can start
   (`requiredForStart: true`); Alchemy/Coinbase/Chainlink/thirdweb/QuickNode
   faucets need account login, wallet-connect UI, or social verification;
   Reactive operates no web faucet. The contracts are built and unit-tested
   (7/7 pass, including a full-loop simulation). Live deployment waits on ONE
   human faucet claim (~2 min) to deployer
   `0xe73684D70E244E1ae7A1c8C2694f76f802B97AcC`; after that, `./deploy.sh`
   completes deployment + the real on-chain loop from the terminal with no
   further human steps. Full detail in `DEPLOYMENT.md`.
2. **Lasna RPC variant confusion** (docs vs blog URLs) — resolved: docs URL
   verified live.
3. **Callback gas economics:** the proxy withholds gas for accounting; the
   callback gasLimit must be generous (docs examples use 1,000,000).
4. **One-shot semantics:** after firing, the reactive contract unsubscribes /
   deactivates so the demo can't double-sell; re-arming is an owner action.

## 9. Win-probability note (honest estimate)

- P(finishing a valid submission with a real on-chain loop): ~60% — the tech
  path is standard and documented; the main risk is faucet funding friction.
- P(winning the track | valid submission): ~10% — hackathon base rates are
  low and judging is by the Reactive team (subjective), but the field for a
  niche infra buildathon is far smaller than consumer-app contests, and a
  genuinely working cross-chain loop with clean docs is exactly what the
  Execution/Integration criteria reward.
