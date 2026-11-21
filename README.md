# PriceGuard — a stop-loss that watches itself

**Set a stop-loss for your token once, and a reactive contract watches the
price for you. If the price crosses your line, your position is sold into a
stable token automatically. No bot, no keeper, no staying awake.**

Built for the **Reactive Omni Buildathon** (DoraHacks), track
**Set It and Forget It**. Everything runs on testnets: Base Sepolia +
Reactive Lasna.

## Why

Every DEX user knows the feeling: you set a mental stop-loss, go to sleep,
and wake up to a position down 40%. The usual fixes all need something
running — a keeper bot on a server, a limit-order protocol with its own
keepers, or you, watching charts at 3 a.m.

Reactive contracts remove the "something running". The rule itself lives
on-chain: a contract on Reactive Lasna subscribes to price events on
Base Sepolia, and the moment the price crosses your line it sends a
callback transaction back to your vault on Base Sepolia, which sells.
There is no server to crash and no operator to trust — the subscription,
the decision, and the execution are all on-chain and verifiable.

## How it works

```
Base Sepolia                                Reactive Lasna
------------                                --------------
PriceFeed.pushPrice(GRD, $80)
  └─ emits PriceUpdated(GRD, $80) ───────►  GuardianReactive.react()
                                              stop-loss line: $90 → breached
                                              └─ requestCallbackV_1_0 ──►
GuardianVault.executeGuard(price = $80)  ◄── callback via Base Sepolia proxy
  └─ sells 100 GRD → 8,000 MockUSD
     paid out to the position's owner
```

1. **PriceFeed** (Base Sepolia) is the origin contract. It emits
   `PriceUpdated(token, price)`. In this demo anyone can push a price so the
   loop can be triggered on demand; the same subscription would point at a
   real DEX pair / oracle event in production.
2. **GuardianReactive** (Lasna) subscribes to those events for one token
   (the token is an indexed topic, so the subscription is narrow). It holds
   the rule: trigger price + direction (stop-loss or take-profit). On a
   breach it requests exactly one callback, emits `GuardFired`, and
   unsubscribes — a guardian that has fired goes quiet instead of billing
   its owner for every later price tick.
3. **GuardianVault** (Base Sepolia) custodies the position (GuardToken)
   and a MockUSD reserve. The callback is authenticated the standard
   Reactive way — caller must be the chain's callback proxy, and the
   sender address the proxy injects must be our reactive contract — then
   the whole position converts to MockUSD at the triggering price and is
   paid out to the beneficiary.

Both protocol contracts use the official
[`reactive-lib-omni`](https://github.com/Reactive-Network/reactive-lib-omni)
bases (`AbstractReactive` / `AbstractCallback`), as the buildathon rules
allow for dependencies.

## Contracts

| Contract | Chain | Role |
|---|---|---|
| `PriceFeed` | Base Sepolia | Origin: emits price events |
| `GuardianReactive` | Reactive Lasna | Watches events, decides, requests the callback |
| `GuardianVault` | Base Sepolia | Destination: holds the position, executes the protective sale |
| `MockERC20` ×2 | Base Sepolia | GuardToken (the position) and MockUSD (the safe asset) |

Deployed addresses and the full-loop transaction hashes: see
[DEPLOYMENT.md](DEPLOYMENT.md).

## Run it locally

```bash
forge build
forge test   # 7 tests, incl. a full-loop simulation with a mock system contract
```

## Deploy (testnet)

Fund a wallet with Base Sepolia ETH, copy `.env.example` to `.env`, then:

```bash
./deploy.sh
```

The script converts a little ETH to lREACT through Reactive's faucet
contract, deploys all five contracts in the order the Reactive docs
prescribe (reactive first, callback second, then wire them together),
funds the demo position, and fires the loop with a $100 → $80 price move
against a $90 stop-loss line.

## Design choices worth noticing

- **One-shot by design.** Stop-losses are one-shot in real life too. After
  firing, the reactive contract unsubscribes itself, so it never bills for
  another event.
- **The reactive contract does real work.** It filters by chain, contract,
  topic and token, decodes the price, evaluates the rule, and only then
  spends money on a callback. Non-breaching prices cost a cheap `react()`
  and nothing else.
- **Two-factor callback authentication.** `onlyServiceProvider` +
  `onlyCallbackSender`, exactly as the Reactive docs prescribe — a forged
  "sell everything" call from anyone else reverts.
- **Honest demo seams.** The price feed is a stand-in and the tokens are
  mocks; the reactive loop, the decision, the custody and the payout are
  the real thing, all verifiable on the explorers.

## License

MIT
