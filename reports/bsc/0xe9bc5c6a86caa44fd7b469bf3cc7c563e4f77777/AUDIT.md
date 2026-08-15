# Exploitability audit — "Max" / Giggle Mascot (BSC) and its Flap dependency graph

**Target:** `0xe9Bc5C6A86caA44fD7b469bf3cc7c563E4F77777` (BNB Smart Chain, chainid 56)
**Companion document:** [`README.md`](./README.md) — the contract *map* (scope). This document is the *risk* pass over that scope.
**Date:** 2026-08-15. Live state re-read directly against BSC JSON-RPC at audit time (see [§7](#7-live-state-read-at-audit-time)).

**Mandate:** find reachable states where a low-capital or unprivileged attacker extracts protocol-scale value or seizes
authority. Decisive criterion is *attacker gain relative to attacker cost*, not protocol loss alone. Admin-key risk,
mempool/MEV ordering, and transient spot-price distortion are explicitly out of scope.

---

## 0. Result

**Zero qualifying findings.**

Every candidate that survived initial generation was killed at falsification — either by a guard elsewhere in the code,
by an unreachable precondition, or by arithmetic showing the attacker ends behind. The decisive structural facts are:

1. **The tax machinery has no attacker-reachable outflow at all.** Every terminal destination of collected value is a
   protocol-owned address (`feeReceiver` Safe, `marketAddress` Safe, `0x…dEaD`, the burned-LP dead address). The only
   destination that could pay an unprivileged caller — the `Dividend` contract — is fed by `dividendBps`, which reads
   **`0`** on-chain. `totalDividendTokenSent = 0` and `totalDividendsDistributed = 0` confirm nothing has ever flowed
   there.
2. **The one globally-scoped tax exemption in the token (`notLiquidating == false` zeroes tax for *every* transfer,
   not just the processor's) is not reachable by an attacker**, because no attacker-controlled contract receives
   execution anywhere inside that window. Full call-graph enumeration in [§4.1](#41-the-notliquidating-global-tax-exemption-window).
3. **Dividend share accounting is exact:** `share == balanceOf(user)` is re-established on every transfer, and the
   MasterChef-style settlement is arithmetically conservative in the protocol's favour at every rounding site.
4. **Authority is fully gated.** Token `owner()` is `address(0)` and nothing else in the token is owner-gated;
   `taxProcessor.owner()` and `dividend.owner()` are the Portal proxy; the live clones are already initialised.

Reporting zero is the honest outcome here, not a shortfall. The real risk on this token is **centralisation**, which is
correctly scoped out of this exercise and is already documented in [`README.md` §4](./README.md#4-upstream--who-holds-power-over-this-token-without-being-it).

---

## 1. System model

### 1.1 What the protocol is

`Max` is an EIP-1167 clone of `FlapTaxTokenV3`, a fixed-supply (1e9) ERC-20 with an asymmetric buy/sell tax, launched by
the Flap launchpad. It has graduated off its bonding curve (`state = 2`, `TaxEnforcedAntiFarmer`) onto a PancakeSwap V2
pair whose LP is 99.99% burned. Three satellite contracts carry the moving parts:

| Contract | Role |
|---|---|
| `FlapTaxTokenV3` clone `0xe9Bc…77777` | withholds tax on pool-touching transfers; triggers liquidation |
| `TaxProcessorUniV2` clone `0xD0e4…9A2f1` | converts withheld tax tokens → WBNB, splits into buckets, pays out |
| `Dividend` clone `0xCbd8…863c9` | tracks per-holder shares; would distribute WBNB pro rata |
| `Portal` proxy `0xe2cE…9De0` | owner of the two clones; launchpad factory/broker |

### 1.2 Value paths (where value enters and leaves)

**In:**
- A trader buys from or sells to `mainPool`. `_getTaxWithPoolState` withholds `3%` of the *transferred token amount*
  into the token contract's own balance. This is the only inflow.
- Anyone may push value in voluntarily: `TaxProcessor.processBondingCurveTax(amount)` (pulls WBNB from `msg.sender`),
  `Dividend.deposit(amount)` (pulls the dividend token from `msg.sender`), or a bare ERC-20/native donation, which
  `_reconcileBalance` / `_afterReconcile` later absorb.

**Out:** value leaves only through `TaxProcessor.dispatch()` (permissionless keeper call) and the swap legs it drives:

```
tax tokens (token contract)
  └─ processTaxTokens ──► _processFeeToken: split by bps ──► _swapTokensForQuote (PancakeSwap V2)
        ├─ deflationBps → flapBlackHole (= 0x…dEaD)            [live value: 0 bps → dead path]
        ├─ lpBps        → addLiquidity, LP minted to 0x…dEaD   [live value: 0 bps → dead path]
        ├─ dividendBps  → Dividend.deposit → holders pro rata  [live value: 0 bps → dead path]
        ├─ feeRate      → feeReceiver Safe 0x8a08…7aB0E        [live: 1000 bps = 10%]
        └─ market bps   → marketAddress Safe 0xC7f5…bF4A4      [live: 10000 bps of the remainder = 90%]
```

**The whole live outflow is 10% / 90% to two protocol Safes.** No unprivileged address is a payee of anything.

### 1.3 Authority model

| Lever | Holder | Reachable by an attacker? |
|---|---|---|
| `token.startMigration` / `finalizeMigration` | `owner()` = `address(0)` | No — `onlyOwner` can never pass |
| token tax rate | **no setter exists at any privilege level** | No |
| `token.pools[]` | write-only inside `initialize()`; **no post-init setter** | No |
| `taxProcessor.*` setters, `withdrawAll` | `onlyOwner` = Portal proxy | No |
| `dividend.*` setters, `emergencyWithdraw` | `onlyOwner` = Portal proxy | No |
| `taxProcessor.registerV4LPFeeSource` | `onlyPortal` | No |
| `dividend.setShare` | `onlyTaxToken` | No |
| `taxProcessor.reconcileToken` | `msg.sender == address(this)` | No |
| Portal roles / upgrade | master Safe 3-of-4 | Out of scope (admin) |

Every clone in the live graph is already initialised (`owner`, `taxToken`, `portal` all read non-zero), so no
initialise-front-run window exists on the deployed instances.

---

## 2. Invariants derived from that model

These are the properties targeted by the search. Each is stated with the code that is supposed to enforce it.

**Solvency**

- **I1.** `WBNB.balanceOf(taxProcessor) ≥ feeQuoteBalance + marketQuoteBalance + pendingDividendQuoteTokenBalance +
  lpQuoteBalance + preBondBurnFunds + commissionQuoteBalance`. Every credit site must be backed by tokens actually
  received.
- **I2.** `dividendToken.balanceOf(dividend) ≥ Σ_users withdrawableDividendOf(user)`.
- **I3.** `taxToken.balanceOf(taxProcessor) ≥ deferredTaxTokenBalance (+ dividendTokenBalance when dividendToken == taxToken)`.

**Accounting**

- **I4.** `Dividend.totalShares == Σ_users userInfo[u].share` at all times.
- **I5.** For every non-excluded holder, `userInfo[u].share == balanceOf(u)` (or `0` when below `minimumShareBalance`)
  immediately after any transfer touching `u`.
- **I6.** Total dividend entitlement created never exceeds total dividend token received:
  `Σ_u (accumulated_u − rewardDebt_u)⁺ + pending_u + withdrawn_u ≤ totalDividendsDistributed`.
- **I7.** `token.totalSupply()` is constant at `1e9 ether` — no mint or burn path after `initialize`.
- **I8.** Bucket splits are exhaustive and non-inflating: the pieces of any split sum to exactly the input
  (`_processFeeQuote`, `_processFeeToken`, `_processTokenDistribution` all route the division remainder to `fee`).

**Access / value-for-contribution**

- **I9.** No caller obtains dividend share without a matching token balance.
- **I10.** No caller can direct any transfer of protocol funds to an address of their choosing.
- **I11.** Tax is charged on every pool-touching transfer except those made by the protocol's own liquidation machinery.
- **I12.** No caller can take, or cause the loss of, a privileged role.
- **I13.** A single actor cannot cause the token to become non-transferable (`_afterTokenTransfer` reverting the
  transfer on any `setShare` failure makes this a real liveness surface).

---

## 3. Triage — where the money is

Effort was concentrated in proportion to custodied value and to attacker reachability:

| Surface | Value at stake | Depth spent |
|---|---|---|
| `TaxProcessorBase.sol` + `TaxProcessorUniV2.sol` (all 3 storage-sharing contracts) | all collected tax; custodies WBNB + tax tokens | full line-by-line, both delegate facets |
| `Dividend.sol` | pro-rata claim on all dividend WBNB; the *only* possible unprivileged payee | full line-by-line + arithmetic proof |
| `FlapTaxTokenV3.sol` | 1e9 supply, tax withholding, liquidation trigger | full line-by-line |
| PancakeSwap V2 pair/router integration | 106.25 WBNB / 44.9M MAX of live reserves | full call-graph trace of every leg the protocol drives |
| `Portal.sol` / `PortalBase.sol` visible surface, `LibCurve` | launchpad-wide reserves | access-control + curve rounding review; **trade facets not published — see [§6](#6-assumptions--limitations)** |
| `FlapBlackHole`, Safes, WBNB | terminal / canonical | read, confirmed benign |

---

## 4. Candidates generated and how each died

This is the falsification record. Nothing below is a finding.

### 4.1 The `notLiquidating` global tax-exemption window

`FlapTaxTokenV3._getTaxWithPoolState` (L200) wraps the *entire* tax computation in `if (currentPoolState.notLiquidating)`.
While `_liquidateTax` holds that flag false, **every transfer in the system is tax-free, not just the processor's.**
`_liquidateTax` is also free to trigger: `token.transfer(mainPool, 1)` opens the window at a cost of 1 wei plus gas,
because the trigger condition ignores the transfer amount entirely.

If any attacker-controlled contract could execute inside that window, it would sell tax-free — and, more importantly,
could re-enter `_liquidateTax`'s own bookkeeping. Full enumeration of every call made while the flag is false, under
the live configuration:

| Step | Callee | Attacker-controlled? |
|---|---|---|
| `_approve(this, taxProcessor, max)` | self | no |
| `taxProcessor.processTaxTokens` | fixed clone | no |
| `taxToken.transferFrom` | self | no |
| `IDividend.setShare(taxProcessor, …)` | fixed clone | no |
| `router.getAmountsIn` | `view` (verified in bundled router source L820) | no |
| `taxToken.liquidationThreshold()` | `view`, self | no |
| `router.swapExactTokensForTokensSupportingFeeOnTransferTokens` | canonical PancakeRouter | no |
| `pair.swap(a0, a1, to, new bytes(0))` | **empty `data` ⇒ `pancakeCall` is never invoked** (router L719) | no |
| `WBNB.transfer` | no hooks (2020 WBNB) | no |
| `IERC20(taxToken).safeTransfer(0x…dEaD, deflation)` | `deflationBps == 0` ⇒ never executes | n/a |
| `_addLiquidity → router.addLiquidity` | `lpBps == 0` ⇒ never executes; and `pair.mint` has no user callback | n/a |

**Dead: no attacker code runs inside the window.** The exemption is over-broad as written — it should have been scoped
to `from == taxProcessor` rather than made global — but it is not reachable. Noted as hardening in [§5](#5-hardening-notes-not-findings).

### 4.2 Just-in-time dividend capture using a PancakeSwap flash swap

The strongest low-capital shape available: `dispatch()` is permissionless, so the attacker chooses *when* a dividend
deposit lands; and `pair.swap(…, data)` lets them flash-borrow MAX to spike `share` for the duration of one
transaction, with `withdrawDividends()` claiming inside the same call.

Falsified on arithmetic, using live reserves (WBNB `106.2536`, MAX `44,905,745.84`) and live
`totalShares = 953,119,450.56`:

| Borrow | Share after 3% buy tax | Capture of one deposit `D` | Round-trip cost (3% buy + 3% sell + 0.25% pair fee) |
|---|---|---|---|
| 100% of pool reserve (44.91M MAX) | 43.56M | **4.37%** | **6.64 BNB** |
| 50% of pool reserve | 21.78M | 2.23% | 3.32 BNB |

Break-even needs `D > 152 BNB` for the 100% case. For scale, the token contract's *entire* liquidation threshold is
`392,040 MAX ≈ 0.93 BNB`, and `dividendBps = 0` means `D` is identically zero today. Gain is strictly bounded by
`share/(totalShares + share)`, i.e. it scales *sub*-linearly with capital and can never exceed the deposit itself.
**Dead: profit is proportional to (and here far below) contributed capital.**

### 4.3 Dividend share/debt accounting — over-claim

Checked `_setShare` ↔ `withdrawableDividendOf` ↔ `_withdrawDividendOfUser` against share-increase, share-decrease,
claim-then-change, exclude/unexclude, and first-interaction orderings. The settlement is correct and every rounding
site favours the protocol: entitlement uses floor (`share * M / MAGNITUDE`) while `rewardDebt` uses
`Math.ceilDiv`, so `part1` is pinned to `0` immediately after any claim. `M` itself is floored at deposit
(`actualReceived * MAGNITUDE / totalShares`), so the sum of all entitlements is `≤` the sum of all deposits. **I2/I6 hold. Dead.**

### 4.4 Fabricating dividend share without tokens

`setShare` is `onlyTaxToken` and the token only ever passes `balanceOf(from)` / `balanceOf(to)` from
`_afterTokenTransfer`, after balances have settled — including inside `_taxedTransfer`'s two-leg split. The skip list
(`address(this)`, `0`, `0xdead`, `dividendContract`, `pools[…]`) only *suppresses* share, never inflates it. No path
writes `userInfo[u].share` outside `_setShare`, which always adjusts `totalShares` by the same delta. **I4/I5/I9 hold. Dead.**

### 4.5 `magnifiedDividendPerShare` overflow → permanent token brick

`_afterTokenTransfer` reverts the whole transfer if `setShare` reverts, so an overflow in `share * M` would freeze the
token. Requires `share * M ≥ 2^256`. With `MAGNITUDE = 2^128` and `minimumShareBalance = 10,000e18` forcing
`totalShares ≥ 1e22`, `M` grows by at most `received * 3.4e16`; bricking even a 1%-of-supply holder needs
`≈ 3.4e17 BNB` of deposits. **Dead: unreachable by ~20 orders of magnitude.** (It becomes theoretically live only if an
owner sets `minimumShareBalance` to dust — an admin action, out of scope.)

### 4.6 Reentrancy on the native-ETH dividend payout

`Dividend._sendToken` does `IWETH.withdraw(amount)` then `payable(user).call{value: amount}("")` with **all remaining
gas**, and `withdrawDividendsFor(address)` lets anyone aim that call at any address. Checks-effects-interactions is
respected: `rewardDebt`, `pendingBalance` and `withdrawnDividends` are all written before the call. A re-entrant
`withdrawDividends()` computes `withdrawableDividendOf == 0` and returns `false`; a re-entrant token transfer runs
`_setShare` whose settlement branch is already neutralised by the ceil-rounded `rewardDebt`. **Dead.**

### 4.7 Reentrancy through the LP-add leg (`reconcileToken` → `_addLiquidity`)

`_afterReconcile` self-calls `reconcileToken`, which is *outside* the token's `notLiquidating` window — so the
`router.addLiquidity` token leg lands on `mainPool` with tax live and re-enters `processTaxTokens` mid-`addLiquidity`,
with `lpQuoteBalance` not yet decremented and the router's approvals reset underneath the outer call. Traced fully.
Outcomes are (a) revert, swallowed by `_afterReconcile`'s `try/catch`, or (b) a double-decrement that the
`>=`-guards clamp to `0`, leaving *tracked ≤ actual* and the surplus recaptured by the next
`_reconcileBalance → _processFeeQuote`. **No attacker gain in either branch**, and `lpBps == 0` makes the path
unreachable on this token entirely. **Dead** (kept as hardening, [§5](#5-hardening-notes-not-findings)).

### 4.8 Unauthenticated `processBondingCurveTax` / `deposit` / donations

`TaxProcessor.processBondingCurveTax` has no access control and credits `quoteAmount` straight into the fee buckets —
but `safeTransferFrom` pulls that exact amount from the caller first, and `quoteToken` is fixed to WBNB (no
fee-on-transfer, no reentrancy). Same for `Dividend.deposit`. Both are *donation* primitives: the attacker's balance
strictly decreases and the funds land at protocol Safes. `_reconcileBalance` / `_afterReconcile` sweep raw donations
into the same buckets. **Dead: negative expected value for the attacker. I1/I8 hold.**

### 4.9 Attacker-timed liquidation with zero slippage protection

`_swapTokensForQuote` uses `amountOutMin = 0`; `_addLiquidity` uses `amountAMin = amountBMin = 0`; both use
`deadline = block.timestamp`. Combined with the free trigger from §4.1, an attacker fully controls *when* the protocol
market-sells its tax inventory. Monetising it requires moving the pool price around the protocol's swap — i.e.
transient spot-price manipulation / sandwiching, **explicitly out of scope**. It is also not protocol-scale: the entire
inventory at the trigger threshold is `392,040 MAX ≈ 0.93 BNB`. **Dead: out of scope and sub-threshold.**

### 4.10 Tax avoidance on unregistered pools

`pools[]` is written only inside `initialize()` and has no setter, so the `TaxEnforcedAntiFarmer` "tax any pool" branch
only ever covers the pools passed at launch. Anyone can deploy a second MAX pair (V2 or V3) and trade there untaxed.
Real, but the gain is exactly 3% of the attacker's own trade — **profit proportional to stake. Dead.**

### 4.11 Bonding-curve rounding (`LibCurve`)

`estimateSupply` subtracts a `divWadUp` term (⇒ supply rounds **down** on buys); `estimateReserve` returns a `divWadUp`
value (⇒ payout rounds **down** on sells); `estimateReserveV2` rounds the decimal down-scale up. Every rounding site
favours the protocol, as the comments claim. **Dead** — though the callers (`PORTAL_TRADE_V2`) are unpublished, see [§6](#6-assumptions--limitations).

### 4.12 Authority seizure

`token.owner() == address(0)` with no owner-gated function that matters; `_disableInitializers()` in the constructors of
`FlapTaxTokenV3`, `Dividend` and `TaxProcessorBaseStorage` protects the implementations; all live clones are already
initialised, closing the initialise-front-run window. `TaxProcessorV2DispatchImpl.executeDispatch()` is `external` with
no guard, but the selector is not exposed on `TaxProcessorCore` and there is **no `fallback()`** on the clone, so it is
unreachable there; called directly on `DISPATCH_IMPL` it operates on that contract's own empty storage. **I12 holds. Dead.**

### 4.13 SwapRegistry's single-EOA ProxyAdmin

`_convertQuoteToDividendToken` would `safeApprove` a router address returned by SwapRegistry — a genuinely dangerous
shape if that registry turned hostile. Gated behind `msg.sender == converter` **and** `dividendToken != quoteToken`;
live `converter == address(0)` and `dividendToken == quoteToken == WBNB`, so the branch is doubly dead here. Reaching it
elsewhere requires compromising the EOA — **admin risk, out of scope.**

---

## 5. Hardening notes (not findings)

Ordered by how much they would reduce future blast radius. None is exploitable in the audited state.

1. **Scope the tax exemption to the actor, not to global time.** `_getTaxWithPoolState` should gate on
   `from == taxProcessor || to == taxProcessor` rather than on `notLiquidating`. Today the exemption's safety rests
   entirely on the *absence* of a user callback in PancakeSwap V2's `swap` path — a property of the current DEX
   integration, not of this contract. Any future migration to a DEX with hooks (V4 / PCS Infinity are already
   referenced throughout `PortalBase`) or any dividend/quote token with transfer callbacks re-opens it.
2. **Give the liquidation swap real slippage bounds.** `amountOutMin = 0` plus an attacker-chosen trigger is a
   standing invitation; a bound derived from `liqExpectedOutputAmount` (already stored, currently only used for the
   threshold-direction signal) would cost nothing.
3. **Take `nonReentrant` down to `reconcileToken`,** or set a re-entrancy flag around `_addLiquidity` the way
   `_swapping` already guards `_swapTokensForQuote`. §4.7's ordering hazard is currently masked only by `lpBps == 0`.
4. **Add a post-init `setPools` (owner-gated) or drop the anti-farmer branch.** As shipped, "tax on all pools" cannot
   cover a pool created after launch, so the anti-farmer state is functionally identical to `TaxEnforced` (§4.10).
5. **`preBondBurnFunds = burnAmount` in `_executeDispatchInternal` should be `+=`.** In the bonding-curve branch it can
   clobber deflation credited by a `processBondingCurveTax` callback earlier in the same dispatch. Self-heals via
   `_reconcileBalance`, hence not a finding, but the assignment is wrong on its face.

---

## 6. Assumptions & limitations

**External components assumed, not verified in this pass**

- **WBNB** behaves as the standard 2020 deploy: no transfer hooks, no fee-on-transfer, `withdraw` sends via `transfer`.
  Confirmed against the bundled source. If the quote token of some *other* Flap clone is fee-on-transfer, §4.8 flips:
  `processBondingCurveTax` would credit more than it receives and break **I1**. Quote tokens are admin-whitelisted, so
  this is not attacker-reachable — but it is the assumption that carries the most weight.
- **PancakeSwap V2 router/pair are canonical** and `pair.swap` invokes `pancakeCall` only when `data.length > 0`.
  Verified in the bundled router source (L719) and pair source. §4.1's conclusion depends on this.
- **`Dividend.dividendToken == weth`** — verified live. The native-unwrap payout path in §4.6 is the one that runs.

**Not fully traceable**

- **`PORTAL_TWEAK`, `PORTAL_TRADE_V2`, `PORTAL_LAUNCHER`, `PORTAL_ROLLER`, `PORTAL_DEX_ROUTER`, `PORTAL_LENS*` are not
  published.** Bonding-curve `buy`/`sell`/`redeem`/`claim` accounting and the launcher's clone-then-initialise
  atomicity therefore could not be audited. `LibCurve`'s rounding is correct in isolation (§4.11), but its callers are
  where a curve bug would live. **This is the largest unexamined surface in the graph and the right target for a
  follow-up once those facets are verified.** Nothing in the audited contracts depends on them for the conclusions above,
  because `Max` is already in `DEX` status and its live path never re-enters Portal (`deflationBps = 0` kills the only
  `swapExactInput` call sites).
- **`swapRegistry` implementation `0x9a68…a67a65` is unverified bytecode.** Dead for this token (§4.13).
- **`ADMIN_IMPL` / `DISPATCH_IMPL` are not Etherscan-verified at their deployed addresses**; the audit assumes they are
  the `TaxProcessorAdminImpl` / `TaxProcessorV2DispatchImpl` contracts present in the verified `TaxProcessorUniV2`
  bundle. Live reads of `feeConfigV3()`, `dispatchThreshold()` and `minBuyBackQuote()` return values consistent with that
  source, which is corroboration, not proof.

**Conditional on configuration** — `dividendBps`, `lpBps` and `deflationBps` all read `0` today, which is what makes
§4.2, §4.7 and part of §4.1 unreachable. These are `onlyOwner` (Portal) values. If Portal ever sets `dividendBps > 0`,
§4.2's arithmetic should be re-run against the reserves of that day; the ratio stays adverse to the attacker unless
`totalShares` collapses relative to the pair's MAX reserve, but it stops being adverse by four orders of magnitude.

---

## 7. Live state read at audit time

Read directly via BSC JSON-RPC (`bsc-rpc.publicnode.com`), not taken from the map document.

| Contract | Field | Value |
|---|---|---|
| Pair `0xa2b1…761D` | `getReserves()` | `106.2536012500309` WBNB / `44,905,745.84009092` MAX (`token0 = WBNB`) |
| Token | `balanceOf(self)` (pending tax) | `336,866.043180` MAX — below threshold, no liquidation armed |
| Token | `liquidationThreshold` | `392,040` MAX ≈ `0.9276` BNB |
| Dividend | `totalShares` | `953,119,450.5607718` MAX |
| Dividend | `magnifiedDividendPerShare` | `0` |
| Dividend | `totalDividendsDistributed` | `0` |
| Dividend | `minimumShareBalance` | `10,000` MAX |
| TaxProcessor | `feeConfigV3()` | `mktBps1 = 10000`, `mktBps2/3/4 = 0`, **`deflationBps = 0`**, **`lpBps = 0`**, **`dividendBps = 0`**, `feeRate = 1000`, `isWeth = true`, `commissionBps = 0` |
| TaxProcessor | `totalDividendTokenSent` | `0` |
| TaxProcessor | all six quote buckets | `0` |
| TaxProcessor | `deferredTaxTokenBalance`, `balanceOf(MAX)` | `0`, `0` |
| TaxProcessor | `liqSmoothingGapQuote` | `1.599808` BNB (⇒ `gapInTokens ≈ 688,196` MAX > threshold ⇒ `returnedToToken = 0`, smoothing is a no-op) |
| TaxProcessor | `dispatchThreshold` / `minBuyBackQuote` | `0.079990` / `0.039995` BNB |

---

## 8. Calibration

Severity was reserved for the disproportionality scale defined in the mandate; no candidate reached it, so no severity
is assigned to anything in this document. Confidence in the *negative* result is high for
`FlapTaxTokenV3`, `Dividend`, `TaxProcessorBase`/`TaxProcessorUniV2` and `FlapBlackHole` — all read in full, with the
value-carrying call graph traced end to end and the two quantitative claims (§4.2, §4.5) computed against live state.
Confidence is **not** transferable to the Portal facets listed in §6, which were not available to read.
