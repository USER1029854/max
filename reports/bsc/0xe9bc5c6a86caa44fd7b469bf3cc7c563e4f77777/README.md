# Contract security map — "Max" / Giggle Mascot (BSC)

**Target:** `0xe9Bc5C6A86caA44fD7b469bf3cc7c563E4F77777` (BNB Smart Chain, chainid 56)
**Pair given:** `0xa2b1926Cb477e92445Cf70602f1A7200361F761D`
**Quote token given:** `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c` (claimed WBNB)
**Mapped:** 2026-08-15, at BSC block ≈116,122,699
**Purpose:** full graph resolution for audit hand-off. **No exploitability judgment is made here** — this is scope, not risk-rating.

Data sources: BscScan/Etherscan V2 `getsourcecode` API (chainid=56), direct BSC JSON-RPC (`eth_call`/`eth_getStorageAt`/`eth_getCode`) against `bsc-rpc.publicnode.com` / `1rpc.io/bnb` / `bsc-dataseed.binance.org`, GoPlus Security token-security API, DexScreener public API, and general web research. All addresses below were extracted programmatically from ABI-decoded call results, not hand-copied, and re-validated for correct length — see [Methodology note](#methodology-note).

---

## 1. Executive snapshot

The discovery note's hunch was right: this **is** a `FlapTaxTokenV3` deployment, from the **Flap** launchpad (flap.sh, live on BNB Chain since Jan 2024). It is an EIP-1167 minimal-proxy clone of a shared, verified implementation.

The token's **own** code is clean and, as of now, inert on the "rug vector" the discovery note flagged:
- `startMigration()` / `finalizeMigration()` are `onlyOwner`.
- `owner()` currently returns `address(0)` — **ownership has been renounced**, and nothing else in the token's own code is owner-gated. Migration is already complete (state 2/5, past the bonding-curve and migration phases).

But the token leans on two more clones (`taxProcessor`, `dividendContract`) whose combined owner is a large, **upgradeable**, role-gated central protocol contract (`Portal`) that was **never named anywhere in the token's own code**, plus two Gnosis Safe multisigs and one lone EOA with real standing power. That's exactly the second, easy-to-miss direction this mapping exists to catch — see [§4](#4-upstream--who-holds-power-over-this-token-without-being-it).

---

## 2. Full graph

```mermaid
graph TD
    TOKEN["<b>TARGET</b><br/>Token clone<br/>0xe9Bc..77777<br/>owner=renounced"]
    TOKENIMPL["FlapTaxTokenV3 impl<br/>0x024f..6422<br/>✅ verified, matches"]
    WBNB["WBNB<br/>0xbb4C..095c<br/>✅ genuine (=router.WETH())"]
    PAIR["PancakePair (mainPool)<br/>0xa2b1..761D<br/>✅ genuine, LP 99.99% burned"]
    ROUTER["PancakeRouter<br/>0x10ED..6024e<br/>✅ genuine"]
    TAXPROC["TaxProcessorUniV2 clone<br/>0xD0e4..9A2f1"]
    TAXPROCIMPL["TaxProcessorUniV2 impl<br/>0x28af..37ae4<br/>✅ verified"]
    DIV["Dividend clone<br/>0xCbd8..863c9"]
    DIVIMPL["Dividend impl<br/>0x0116..dea65<br/>✅ verified"]
    ADMINIMPL["ADMIN_IMPL facet<br/>0xa56B..837b2<br/>⚠️ unverified at addr<br/>(likely source known)"]
    DISPATCHIMPL["DISPATCH_IMPL facet<br/>0xAb8F..Bffb0<br/>⚠️ unverified at addr<br/>(likely source known)"]
    FEESAFE["feeReceiver<br/>Gnosis Safe 3-of-4<br/>0x8a08..7aB0E"]
    MKTSAFE["marketAddress<br/>Gnosis Safe 2-of-5<br/>0xC7f5..bF4A4<br/>holds 5% of supply"]
    SWAPREG["swapRegistry proxy<br/>0x644A..fBEB6"]
    SWAPREGIMPL["impl<br/>0x9a68..a67a65<br/>❌ UNVERIFIED"]
    SWAPADMIN["ProxyAdmin<br/>0x830C..49d95"]
    SWAPEOA["owner: single EOA<br/>0x8187..46063<br/>❌ NOT a multisig"]
    BH["FlapBlackHole<br/>0x0057..00DEad<br/>✅ verified, BURNER_ROLE-gated"]
    PORTAL["Portal proxy<br/>0xe2cE..9De0<br/>owns taxProc + dividend"]
    PORTALIMPL["Portal impl<br/>0x1533..5b74f<br/>✅ verified, ~1400 lines,<br/>huge admin surface"]
    TWEAK["PORTAL_TWEAK facet<br/>❌ ADDRESS UNKNOWN<br/>controls changeMarketWallet,<br/>updateTaxTokenAddresses,<br/>setTokenDividendToken, etc."]
    PORTALADMIN["ProxyAdmin<br/>0xB248..39bD4"]
    MASTERSAFE["MASTER Safe 3-of-4<br/>0x1f96..08A3b<br/>upgrade key + DEFAULT_ADMIN_ROLE"]

    TOKEN -->|delegatecall, immutable, fixed forever| TOKENIMPL
    TOKEN -->|quoteToken| WBNB
    TOKEN -->|mainPool| PAIR
    TOKEN -->|v2Router ref| ROUTER
    TOKEN -->|unlimited standing approval<br/>on its own tax balance| TAXPROC
    TOKEN -->|setShare() every transfer;<br/>revert here reverts the transfer| DIV
    PAIR -->|factory/token0/token1 cross-checked| ROUTER

    TAXPROC -->|delegatecall, immutable| TAXPROCIMPL
    TAXPROCIMPL -.->|internal delegate| ADMINIMPL
    TAXPROCIMPL -.->|internal delegate| DISPATCHIMPL
    TAXPROC -->|feeReceiver| FEESAFE
    TAXPROC -->|marketAddress| MKTSAFE
    TAXPROC -->|swapRegistry ref, not active now| SWAPREG
    SWAPREG -->|impl| SWAPREGIMPL
    SWAPREG -->|admin| SWAPADMIN
    SWAPADMIN -->|owner| SWAPEOA
    TAXPROC -->|owner + portal| PORTAL

    DIV -->|owner| PORTAL
    DIV -->|flapBlackHole| BH

    PORTAL -->|impl| PORTALIMPL
    PORTALIMPL -.->|internal delegate, unresolved| TWEAK
    PORTAL -->|ProxyAdmin| PORTALADMIN
    PORTALADMIN -->|owner| MASTERSAFE

    classDef verified fill:#1e3a1e,stroke:#4ade80,color:#e5ffe5
    classDef unverified fill:#3a1e1e,stroke:#f87171,color:#ffe5e5
    classDef power fill:#1e2a3a,stroke:#60a5fa,color:#e5f0ff
    classDef target fill:#3a2e1e,stroke:#fbbf24,color:#fff5e0
    class TOKEN target
    class TOKENIMPL,WBNB,PAIR,ROUTER,TAXPROCIMPL,DIVIMPL,BH verified
    class SWAPREGIMPL,ADMINIMPL,DISPATCHIMPL,TWEAK,SWAPEOA unverified
    class FEESAFE,MKTSAFE,PORTAL,PORTALIMPL,MASTERSAFE,TAXPROC,DIV,SWAPREG,SWAPADMIN,PORTALADMIN power
```

Solid arrows = direct on-chain reference/call. Dashed arrows = internal delegatecall facet the resolved contract's own source routes into.

---

## 3. The target and its downstream (what it leans on)

### 3.1 Token — `0xe9Bc5C6A86caA44fD7b469bf3cc7c563E4F77777`

- **Type:** EIP-1167 minimal-proxy clone (45-byte bytecode: `363d3d373d3d3d363d73` + address + `5af43d82803e903d91602b57fd5bf3`, the exact standard template — not EIP-1967).
- **Implementation:** `0x024f18294970b5c76c0691b87f138a0317156422` — verified `FlapTaxTokenV3`, byte-identical ABI to the clone. Its constructor calls `_disableInitializers()`, so the raw implementation can't be hijacked by calling `initialize()` directly on it.
- **Contract name:** `FlapTaxTokenV3` (Solidity 0.8.24), an `OwnableUpgradeable` + `ERC20PermitUpgradeable` token forked from `FlapTaxTokenV2`.

**What the code actually does** (full 468-line contract read, not just the ABI):

- `initialize()` mints the entire 1B fixed max supply to `msg.sender` once, sets `taxProcessor`, `dividendContract`, `quoteToken`, `v2Router`, `mainPool`/`pools[]`, and starting tax rates. There is **no function anywhere in this contract that can change the buy/sell tax rate after initialization** — no setter exists for it.
- `startMigration()` / `finalizeMigration()` are `onlyOwner` and drive a 5-state lifecycle (`BondingCurve → Migrating → TaxEnforcedAntiFarmer → TaxEnforced → TaxFree`), used by the launchpad's Portal contract to graduate a token from its pre-market bonding curve onto the real PancakeSwap pair. **Already executed** — current state is `TaxEnforcedAntiFarmer` (2/5).
- On every taxed transfer, the tax cut is held in the token contract's own balance, and once it crosses `liquidationThreshold` it's swept by approving **`taxProcessor` for `type(uint256).max`** (renewed automatically each time) and calling `processTaxTokens()`. This is a genuine standing unlimited approval — but it is mechanically bounded to whatever tax balance is sitting on the token contract at that moment (typically small; current threshold ≈392,040 tokens ≈ $562 at snapshot price, roughly 0.3% of the pair's 24h volume), not the total supply or any user's balance.
- `_afterTokenTransfer` calls `IDividend(dividendContract).setShare(...)` on (almost) every transfer, and **a revert from that call reverts the whole transfer** (`try/catch { revert DividendShareUpdateFailed }`). This gives `dividendContract` a soft veto over transferability that is invisible if you only read the token's own ABI — see §3.3.
- Tax duration was configured for **~99.9 years** (`taxExpirationTime` = 2126-07-08); for any realistic horizon the 3%/3% buy/sell tax does not expire on its own. The "anti-farmer" broadened scope (tax on transfers touching *any* pool, not just `mainPool`) narrows back to `mainPool`-only after 2026-08-31 — but only lazily, on the next sell into `mainPool` after that date (the state write only happens inside `_liquidateTax` when `to == mainPool`), not on a timer.
- No blacklist, no max-tx/max-wallet, no fee-exemption list, no hidden mint path.

### 3.2 quoteToken — WBNB `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c`

Verified `WBNB` (Solidity 0.4.18, the original 2020 WBNB deploy compiler). **Confirmed genuine**, not by trusting the label, but by calling `PancakeRouter.WETH()` live and getting this exact address back byte-for-byte.

### 3.3 mainPool — PancakeSwap V2 pair `0xa2b1926Cb477e92445Cf70602f1A7200361F761D`

Verified `PancakePair`. Genuineness was checked transitively, without relying on any hand-typed "known" factory address:

| Check | Result |
|---|---|
| `router.factory()` == `pair.factory()` | ✅ match (`0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73`) |
| `factory.getPair(token, wbnb)` == given pair | ✅ exact match |
| `{token0, token1}` == `{target token, WBNB}` | ✅ exact match |
| `getReserves()` vs actual live `balanceOf()` on both sides | ✅ **diff = 0** on both — no skim/donation manipulation |
| DexScreener independent classification | `dexId: pancakeswap`, `labels: ["v2"]` |
| LP token holders | 99.99% (56,565 of 56,571 LP) held by `0x000...dEaD` (burned); remainder is dust |

`token.pools(mainPool)` reads `true` on-chain, consistent with the contract's own state.

### 3.4 v2Router — `0x10ED43C718714eb63d5aA57B78B54704E256024e`

Verified `PancakeRouter` (Solidity 0.6.6), the standard 24-function Uniswap-V2-style router interface. Self-consistent with the pair/factory chain above and corroborated by DexScreener's independent `pancakeswap` tag.

### 3.5 taxProcessor — `0xD0e4Bd493D25b7E53Fa8531e6dbC808Da549A2f1`

Another EIP-1167 clone → implementation `0x28aff2817dc5b17de15194ac2861a9caa8307ae4`, verified `TaxProcessorUniV2`. Full source read (`TaxProcessorBase.sol`, `TaxProcessorUniV2.sol`). Live state:

| Field | Value |
|---|---|
| `owner()` / `portal()` | `0xe2cE6ab80874Fa9Fa2aAE65D277Dd6B8e65C9De0` (Portal proxy — see §4) |
| `feeReceiver` | `0x8a08D98CBB218fceB318Ecf3aBc1BA43D8A7aB0E` — Gnosis Safe 3-of-4 |
| `marketAddress` | `0xC7f501D25Ea088aeFCa8B4b3ebD936aAe12bF4A4` — Gnosis Safe 2-of-5, **also independently holds 5% of total token supply** |
| `dividendToken` / `weth` | WBNB (same as quoteToken; no extra swap-router trust needed here) |
| `swapRegistry` | `0x644A8f560138418bAD4EdEFC7c17878a3c2fBEB6` (see §3.7 — referenced, not currently exercised: `converter()` = zero) |
| `commissionReceiver` / `converter` | zero (disabled) |
| current balances (fee/lp/market/commission/dividend) | all **0** right now — nothing hot sitting in the processor at snapshot time |
| `dispatchThreshold` / `minBuyBackQuote` | ≈0.080 / ≈0.040 BNB |

`owner()` here is **not renounced** — it is the Portal proxy, which is fully live (see §4). The onlyOwner surface on this contract is extensive: `setReceivers`, `setWalletConfig`, `setTaxConfig`, `setFeeRate`, `setCommissionConfig`, `setDividendToken`, `setConverter`, `withdrawAll(token, to)`, and more — all real, all currently exercisable by whoever can act as Portal.

**Internal delegate facets** (constants read live off the clone, not guessed): `ADMIN_IMPL = 0xa56B1cb37947A659CC0b5c5BbE48D44Fc31837b2`, `DISPATCH_IMPL = 0xAb8FF2bd20B8eDF958Adf9c373f0d78b8B3bFfb0`. Neither is independently verified *at that address* on BscScan. However, the verified `TaxProcessorUniV2` source bundle we already have literally contains full contract definitions named `TaxProcessorAdminImpl` and `TaxProcessorV2DispatchImpl` (in `TaxProcessorBase.sol`) that match this exact purpose — very likely (but not Etherscan-certified) what's actually deployed at those two addresses. Access control for the delegated setters (`onlyOwner`) is defined in that same source, and because these are reached via `delegatecall` from the clone, `msg.sender`/storage context resolve correctly against the clone's own owner. See [§6](#6-explicit-gaps--what-we-could-not-resolve) for the precise caveat.

### 3.6 dividendContract — `0xCbd8C6c8B216c29A27ee4f41fb9515E6c6a863c9`

EIP-1167 clone → implementation `0x0116f1e42977eccdfd926fef688c6a7d289dea65`, verified `Dividend`. Live state:

| Field | Value |
|---|---|
| `owner()` | `0xe2cE6ab80874Fa9Fa2aAE65D277Dd6B8e65C9De0` — **same Portal proxy** as taxProcessor |
| `dividendToken` / `weth` | WBNB |
| `flapBlackHole` | `0x00576E4Fb32296Cd973A0d413D0379609400DEad` — a **different, non-standard** address from taxProcessor's black hole (see §3.8) |
| `minimumShareBalance` | 10,000 tokens |
| `totalShares` | ≈954.3M tokens (~95.4% of supply) tracked as dividend-eligible |
| `totalDividendsDistributed` | 0 (nothing paid out yet — token migrated ~2 weeks ago) |

The `onlyOwner` surface here includes `setShare` (called by the token every transfer — see §3.1), `setMinimumShareBalance`, `setDividendToken`, `excludeAddress`/`unexcludeAddress`, and **`emergencyWithdraw(token, amount, to)`** — a generic "pull any ERC-20 balance held by this contract to an arbitrary address" function, all gated to the same Portal-controlled owner.

### 3.7 swapRegistry — `0x644A8f560138418bAD4EdEFC7c17878a3c2fBEB6`

`TransparentUpgradeableProxy` (verified shell). EIP-1967 slots read live:
- **implementation:** `0x9a681bC1350636BBf81085207cde7485dAa67a65` — **unverified, no source available** (gap).
- **admin (ProxyAdmin):** `0x830C709805612ab460C3C1e249cfC058CB049d95` (verified `ProxyAdmin`) → `.owner()` = **`0x8187F13ed6C7C9554AfE4Dd4C4D4960174846063`, a plain EOA** — not a Safe, not overlapping with any multisig signer identified elsewhere in this graph. A single private key can swap SwapRegistry's logic to anything, at any time. Not currently exercised by this specific token (`converter = 0`), but the standing capability exists.

### 3.8 FlapBlackHole (dividend's) — `0x00576E4Fb32296Cd973A0d413D0379609400DEad`

Verified source (`FlapBlackHole.sol`). Uses OpenZeppelin `AccessControl` (`DEFAULT_ADMIN_ROLE`, `BURNER_ROLE`). Its one non-view function:

```solidity
function eradicate(address token) external onlyRole(BURNER_ROLE) {
    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
        IERC20(token).safeTransfer(address(0x000000000000000000000000000000000000dEaD), balance);
    }
}
```

This is a clean, honest sweep-to-burn — role-gated on *when* it fires, not on *where funds go* (always the standard dead address). We could **not identify who currently holds `BURNER_ROLE` or `DEFAULT_ADMIN_ROLE`** on it (see §6).

---

## 4. Upstream — who holds power over this token without being it

This is the direction the token's own ABI will never show you.

### 4.1 Portal — `0xe2cE6ab80874Fa9Fa2aAE65D277Dd6B8e65C9De0`

Both `taxProcessor.owner()` and `dividendContract.owner()` point here, and `taxProcessor.portal()` independently confirms the same address. **Nothing in the token's own source ever names this address** — it only surfaces by walking one hop past `taxProcessor`/`dividendContract`.

- **Type:** `TransparentUpgradeableProxy`, EIP-1967 slots read live:
  - implementation: `0x153378bbfa36411d34c20862725223E11665b74f` — verified `Portal` (Solidity 0.8.26, ~1,400 lines, part of a much larger multi-file bundle).
  - admin: `0xB2480c2D17BF4510701c4Def374DE6d22E039bD4` — verified `ProxyAdmin`.
- **What it is:** the Flap launchpad's central factory/broker contract — identified via web research as flap.sh's core protocol contract (function names `newTokenV2` through `newTokenV7`, `buy`/`sell`/`redeem`/`claim` on bonding curves, match Flap's own public docs describing "Portal v5.9.0+" and "Tax Token V3"). This is very likely what called `initialize()` on the token clone (making it the original `owner()` and initial mint recipient), then drove `startMigration()`/`finalizeMigration()`, then renounced.
- **Access control:** OpenZeppelin `AccessControl` with roles `DEFAULT_ADMIN_ROLE`, `GUARDIAN_ROLE`, `MANAGE_ROLE`, `MODERATOR_ROLE`, `TOKEN_FLAP_FEE_SETTER_ROLE`. Role IDs were read live off the contract (not guessed); holder confirmed for one role only (see table in §4.2) — the other four are unresolved (§6).
- **What it can still do to *this* token, right now**, per functions defined directly in `Portal.sol` (names only — see §4.3 for why we can't see the gating logic): `updateTaxTokenAddresses`, `changeMarketWallet`, `setTokenDividendToken`, `setTaxTokenDividendReceiver`, `setTaxTokenDividendKeeper`, `recoverStuckTaxProcessor` / `recoverStuckTaxProcessorToTaxToken`, `recoverStuckDividend`, `recoverStuckTaxToken`, `burnStuckTaxToken`, `setFeeExemption`, `setTokenMaxBuyBps`, `setSpammerBlockedBatch`, `excludeAddressFromDividends`, `retuneTaxThresholds`. `halt()` is directly gated in `Portal.sol` itself: `hasRole(GUARDIAN_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender)`.

  This means: even with the token's own `owner()` renounced, Portal retains a purpose-built administrative path to **redirect the market wallet, redirect the dividend token/receiver/keeper, and pull tokens back out of taxProcessor/dividendContract** for this specific token — none of which requires the token's own owner key, because it was never the token's owner that mattered for these particular levers.

### 4.2 Who controls Portal

| Layer | Address | Type | Detail |
|---|---|---|---|
| Upgrade key (ProxyAdmin owner) | `0x1f96BC88f0794060433Be5F3EC9159a9C4f08A3b` | Gnosis Safe **3-of-4** | v1.4.1, nonce=76 (actively used). Can replace Portal's entire implementation via `ProxyAdmin.upgrade()`. |
| Portal `DEFAULT_ADMIN_ROLE` | same address, `0x1f96BC88f0794060433Be5F3EC9159a9C4f08A3b` | — | Confirmed live via `hasRole()`. Same Safe holds both the upgrade key *and* the top role. |
| Portal `GUARDIAN_ROLE` / `MANAGE_ROLE` / `MODERATOR_ROLE` / `TOKEN_FLAP_FEE_SETTER_ROLE` | not identified | — | Tested against 3 plausible candidates (ProxyAdmin owners, token creator EOA) — all negative. Gap (§6). |

Safe signers (3-of-4): `0xA85c06f58B6A2F1BF577B15F20F4AA66D8a334Ec`, `0x29a64981d327c2B4893F1bB84aa9A6266EFBb491`, `0x01db37579E55cE13f4504019025e36047bDaD845`, `0x705163Cf642a975d2F0570463BE93AAb7993D1c2`.

**Notable concentration:** this Safe shares **3 of its 4 signers** with the `feeReceiver` Safe (§3.5) — only one signer differs on each side. In practice, a small, largely-overlapping group of ~5 individuals collectively controls (a) the ability to upgrade Portal to arbitrary logic, (b) Portal's top AccessControl role, and (c) the protocol fee treasury. This is a normal shape for a real team's operational wallets, not inherently a red flag, but it is a real concentration the audit should weigh — compromising ~3 of those ~5 keys reaches all three.

### 4.3 PORTAL_TWEAK — the facet we could not resolve

`Portal.sol`'s implementations of every function listed at the end of §4.1 are one-liners: `_delegateToImpl(PORTAL_TWEAK);` — where `PORTAL_TWEAK` is an `internal immutable address`, set once in the constructor from deploy-time params, **with no public getter anywhere in the ABI**. We confirmed (by grepping the entire 49-file verified source bundle) that no `PortalTweak` contract implementation is present in what BscScan has — only the name and the `IPortalTweak` interface stub. This means: **we can name exactly which powers live behind this facet (the list in §4.1), but we cannot see its address, its code, or its access-control gating.** This is the single most important open item in this whole map — flagged explicitly in §6.

### 4.4 feeReceiver and marketAddress (recap from §3.5, listed here because they hold power, not because the token names them)

- `feeReceiver` `0x8a08D98CBB218fceB318Ecf3aBc1BA43D8A7aB0E` — Gnosis Safe 3-of-4, nonce=203 (mature, actively used).
- `marketAddress` `0xC7f501D25Ea088aeFCa8B4b3ebD936aAe12bF4A4` — Gnosis Safe **2-of-5** (weaker threshold than the other two Safes in this graph), nonce=108, **and directly holds 5% of total token supply** independent of the ongoing tax flow it also receives.

### 4.5 swapRegistry's single-EOA ProxyAdmin owner (recap from §3.7)

`0x8187F13ed6C7C9554AfE4Dd4C4D4960174846063` — a bare EOA, not a multisig, holds unilateral upgrade rights over SwapRegistry's implementation. Distinct from every other signer identified in this graph.

---

## 5. Ecosystem / platform context

- **Platform identity:** "Flap" = **flap.sh**, a modular meme-token launchpad live on BNB Chain since January 2024 (since expanded to X Layer, Monad, Morph, Robinhood Chain). DappBay describes it as "a leading token launch and trading platform on BNB Chain... known for creator revenue sharing and tax token standards." DeFiLlama shows ~$977K TVL, ~$5.6M fees/30d at time of research.
- **Audits — partial coverage only.** Flap's own audit page lists CertiK coverage of "Flap Launchpad Protocol V2, V4" and "Flap Tax Token **V1**," and BlockSec coverage of "Flap Tax Token V1" and "Flap Launchpad Protocol **V5** (incl. Tax Token V2 and PreLaunch V1)." CertiK Skynet lists a score of 75.74 (BBB), 12 findings across 3 audits (0 critical/major, 1 acknowledged centralization issue), **team not KYC-verified**, **no bug bounty**. **We found no audit that explicitly names Tax Token V3 or the current Portal implementation** — i.e., no confirmed audit coverage of the exact code this specific token runs. Worth confirming directly with Flap.
- **Known ecosystem warning:** BSC trading tool GMGN.ai has publicly warned that *some* Flap-launched tokens can carry admin-configurable dynamic tax up to 100% sell tax, and dropped Flap from its default filters over it. Directly relevant given this is a tax token — but as documented in §3.1, **this specific token's own contract has no post-deploy tax-rate setter at all**; we could not fully rule out an indirect path via the unresolved `PORTAL_TWEAK` facet (§4.3), but nothing in `Portal.sol`'s own visible function list operates on buy/sell tax rate directly (`retuneTaxThresholds` affects liquidation thresholds, not tax rate; `setTaxConfig` on taxProcessor affects the *split* of collected tax, not the rate charged to traders).
- **"bBroker" and "GMEB"** (named in the original discovery note as siblings in the FlapTaxTokenV3 family): research indicates **bBroker is not a separate token** — it's Flap's own "bBroker Vault" product (burn tax tokens → mint an NFT → earn dividends from swap fees, redeemable at floor price), consistent with the Dividend/TaxProcessor/redeem machinery mapped above. **GMEB** most likely refers to Binance's bStocks tokenized GameStop stock (ticker GMEB), which Flap's bBroker Vault reportedly integrates as a partner asset — **we could not confirm** GMEB is itself a `77777`-vanity FlapTaxTokenV3 clone versus simply a partner/quote asset. No rug-pull or exploit reports were found for either name.
- **The token's own marketing** (`maxbnb.meme`, `@GiggleMascotBNB`) is visually polished but thin: no team/roadmap/whitepaper, a non-functional "loading..." donation dashboard, ~75 Telegram subscribers with no visible activity, and the site's own disclaimer notes it is "not affiliated with or endorsed by Giggle Academy unless explicitly stated" — undercutting its own branding pitch. This doesn't affect contract mechanics but is relevant surrounding context.

---

## 6. Explicit gaps — what we could not resolve

Ranked roughly by how much it matters:

1. **`PORTAL_TWEAK` facet address and source — unresolved.** This is where `changeMarketWallet`, `updateTaxTokenAddresses`, `setTokenDividendToken`, `setTaxTokenDividendReceiver`, `setTaxTokenDividendKeeper`, `recoverStuckTaxProcessor`/`recoverStuckTaxProcessorToTaxToken`, `recoverStuckDividend`, `recoverStuckTaxToken`, `burnStuckTaxToken`, `setFeeExemption`, `setTokenMaxBuyBps`, `setSpammerBlockedBatch`, `excludeAddressFromDividends`, and `retuneTaxThresholds` actually execute for this token. It's an `internal immutable` in `Portal.sol` with no public getter, and its implementation contract is not present in the verified source bundle we could retrieve. **We can name the exact powers behind this wall but not see the address, the code, or the precise access-control gate.** This is the single biggest blind spot in this map.
2. **Portal's `GUARDIAN_ROLE`, `MANAGE_ROLE`, `MODERATOR_ROLE`, and `TOKEN_FLAP_FEE_SETTER_ROLE` holders — not identified.** Plain OpenZeppelin `AccessControl` isn't enumerable, and historical `RoleGranted` event logs were not retrievable (see item 5). We confirmed `DEFAULT_ADMIN_ROLE` is held by the master Safe via a direct `hasRole()` spot-check, but could not identify holders of the other four roles beyond testing three plausible candidates (all negative). Any of these roles could plausibly touch `setFlapFeeProfile`/`retuneTaxThresholds`/`halt` depending on Portal's internal gating, which we also can't fully see per item 1.
3. **`swapRegistry` implementation (`0x9a681bC1350636BBf81085207cde7485dAa67a65`) is unverified** — bytecode only, no source. Not actively exercised by this token right now (`converter = 0`), but the reference is immutable and the capability exists if that ever changes.
4. **`ADMIN_IMPL` (`0xa56B1cb37947A659CC0b5c5BbE48D44Fc31837b2`) and `DISPATCH_IMPL` (`0xAb8FF2bd20B8eDF958Adf9c373f0d78b8B3bFfb0`) on taxProcessor are unverified at their deployed addresses specifically.** We located contracts with matching names and purpose (`TaxProcessorAdminImpl`, `TaxProcessorV2DispatchImpl`) inside the verified `TaxProcessorUniV2` source bundle, which is very likely what's actually deployed there — but this is a strong inference from a matching source bundle, **not** an Etherscan bytecode-match certification against those specific addresses. Treat as probable, not certain.
5. **No historical event-log access.** The Etherscan V2 API's `proxy`, `account`, and `logs` modules all returned "Free API access is not supported for this chain" on the supplied key (only `contract.getsourcecode`/`getabi` worked). Public BSC RPC nodes enforce a tight `eth_getLogs` block-range cap (a 2,000-block query succeeded; a 50,000-block query hit `-32005 limit exceeded` on every endpoint tried). As a result we could not: pull the exact `OwnershipTransferred`/renounce transaction for the token, enumerate full `RoleGranted` history on Portal, or confirm the FlapBlackHole `BURNER_ROLE`/`DEFAULT_ADMIN_ROLE` holder (tested three candidates, all negative).
6. **No independent, byte-level confirmation of the "canonical" PancakeSwap Router/Factory addresses against an external registry.** Genuineness here rests on self-consistent on-chain cross-references (router↔pair↔factory all agree, reserves match actual balances exactly) plus DexScreener's independent `pancakeswap`/`v2` tagging — not on comparing against an independently-sourced trusted address list. We're confident in this conclusion, but flag the methodology honestly. (Note: an earlier internal draft of this router address, typed from memory rather than decoded on-chain, was off by one character — a good illustration of why every address in this report was extracted programmatically from live call results rather than transcribed by hand; see [Methodology note](#methodology-note).)
7. **No audit found that explicitly covers Tax Token V3 / the current Portal implementation** (§5) — Flap's published CertiK/BlockSec coverage names V1/V2 tax tokens and Launchpad V2/V4/V5, not this specific version.
8. **"GMEB" identity/relationship to the FlapTaxTokenV3 family is unconfirmed** (§5) — plausibly Binance's bStocks tokenized GameStop stock, but not verified as a `77777`-vanity clone sibling as the discovery note's phrasing implied.
9. **Portal's own further immutable delegate targets** (`PORTAL_LAUNCHER`, `PORTAL_LAUNCHER_TWO_STEP`, `PORTAL_TRADE_V2`, `PORTAL_ROLLER`, `PORTAL_DEX_ROUTER`, `PORTAL_LENS`, `PORTAL_LENS_V2`, `PORTAL_UNI_V4_MIGRATOR`, and others) were identified by name in `PortalBase.sol` but **not individually resolved** — they govern buy/sell/redeem/claim trading-path and V4/PCS-Infinity migration functionality that, based on the current lifecycle state (already migrated to a plain V2 pool), does not appear to be in this token's active path. Flagged for completeness rather than because we have reason to believe they're exercised here.

---

## Methodology note

All addresses in this report were extracted programmatically — decoded from ABI-encoded `eth_call` return data or from EIP-1167/EIP-1967 bytecode/storage parsing — and validated for correct 40-hex-character length before use, rather than hand-copied between documents. This was a deliberate fix mid-investigation after a manually-retyped router address was accidentally truncated by one character; every address that follows was re-derived from source data and cross-checked. Live-state reads were taken directly against BSC via public JSON-RPC endpoints (the Etherscan V2 API key supplied only had free-tier access to `contract.getsourcecode`/`getabi` — its `proxy`, `account`, and `logs` modules returned "not supported for this chain" throughout).

Raw evidence (decoded live-state JSON, proxy/admin resolution, Safe signer data, full ABI dumps) is included under [`evidence/`](./evidence/) alongside this report.
