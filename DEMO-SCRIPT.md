# PriceGuard — Demo Video Script (target 2:30, hard cap 3:00)

Format: screen recording, terminal + two explorer tabs (sepolia.basescan.org
and lasna.reactscan.net). No face cam needed. Record AFTER the live deployment
in DEPLOYMENT.md is complete, using the real addresses and hashes.

## Shot list

| # | Time | Screen | Action |
|---|---|---|---|
| 1 | 0:00–0:20 | Title slide (plain text) | "PriceGuard — a stop-loss that watches itself." Hold while narration 1 plays. |
| 2 | 0:20–0:45 | README architecture diagram | Pan over the How-it-works diagram; highlight the three contracts. |
| 3 | 0:45–1:05 | Terminal | `cast call` the vault: show the position — 100 GRD deposited, guard armed, stop-loss line $90 (`triggerPrice` on the reactive contract, Lasna tab). |
| 4 | 1:05–1:25 | Terminal | Push a harmless price first: `pushPrice(GRD, 100)` → wait → show `fired()` still false. "Above the line, nothing happens — as it should." |
| 5 | 1:25–1:50 | Terminal | Push the crash: `pushPrice(GRD, 80)`. Cut to the Lasna explorer: the reactive transaction appears — `react()` ran by itself, nobody sent it. |
| 6 | 1:50–2:15 | Base Sepolia explorer | Open the callback transaction (proxy → GuardianVault): `GuardExecuted` event, 100 GRD → 8,000 MockUSD. Show the beneficiary's MockUSD balance: 8,000. |
| 7 | 2:15–2:30 | Title slide | Closing line + repo URL. |

## Narration (read verbatim, ~150 wpm)

1. "This is PriceGuard: a stop-loss that watches itself. You set your line
   once — after that, no bot, no server, and no staying awake. A reactive
   contract watches the price for you, and sells for you when it matters."
2. "Three contracts. A price feed on Base Sepolia emits price events. A
   reactive contract on Reactive Lasna subscribes to them and holds my
   rule: sell everything if GuardToken falls to ninety dollars. And a vault
   back on Base Sepolia holds the actual position — one hundred GuardToken."
3. "The guard is armed. The position is in the vault. The line is ninety
   dollars. Now we wait for the market to do something."
4. "First, a normal price: one hundred dollars. Above the line — and
   correctly, nothing happens. The reactive contract saw the event, checked
   the rule, and stayed quiet."
5. "Now the crash: eighty dollars. Watch Lasna — there it is. A reactive
   transaction that nobody sent. The contract saw the breach and requested
   its callback home."
6. "And here is the callback landing on Base Sepolia: the vault executed
   the guard. One hundred GuardToken became eight thousand MockUSD, paid
   out to the owner — while nobody was watching. That is the whole loop:
   event, decision, execution, all on-chain."
7. "Set it, forget it, and let the chain keep watch. PriceGuard — code and
   full transaction history are in the repository."

## Recording notes

- Pre-open all explorer tabs at the exact transactions before recording;
  the loop takes seconds-to-a-minute to land, so record the trigger live
  but cut the waiting in edit.
- Keep every address/hash visible long enough to pause on — judges verify.
- Export at 1080p, under 3:00 including titles.
