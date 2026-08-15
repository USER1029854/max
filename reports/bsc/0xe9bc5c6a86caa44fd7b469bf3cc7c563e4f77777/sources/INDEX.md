# Complete verified source — index

Every directory below is the **exact, unmodified verified source** pulled live from BscScan (Etherscan V2 API, `contract.getsourcecode`, chainid=56) for one address in the graph, unpacked from Etherscan's multi-file JSON bundle back into its original file tree (imports and all — that's why each directory repeats its own copy of the OpenZeppelin/Uniswap dependency files it was compiled against; Solidity verification bundles are not deduplicated across separate deployments, so this is a faithful reproduction, not redundancy we introduced).

Each directory also contains `_meta.json` (compiler version, optimization settings, license, and Etherscan's own proxy/implementation flags for that address) and `_abi_raw.txt` (the raw ABI as returned).

See [`../README.md`](../README.md) for the narrative analysis and [`../evidence/contract-registry.json`](../evidence/contract-registry.json) for the machine-readable graph this indexes.

## Target

| Directory | Address | Role |
|---|---|---|
| [`token-implementation-0x024f...6422/`](./token-implementation-0x024f18294970b5c76c0691b87f138a0317156422/) | `0x024f18294970b5c76c0691b87f138a0317156422` | `FlapTaxTokenV3` — the logic the target token clone (`0xe9Bc...77777`) delegatecalls into. The clone itself is 45 bytes of standard EIP-1167 bytecode with no independent "source" beyond that — see `../README.md` §3.1 for the raw bytecode. |

## Downstream — what the target leans on

| Directory | Address | Role |
|---|---|---|
| [`wbnb-0xbb4C...095c/`](./wbnb-0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c/) | `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c` | WBNB (quoteToken) — confirmed genuine, see README §3.2 |
| [`pancake-pair-0xa2b1...761D/`](./pancake-pair-0xa2b1926Cb477e92445Cf70602f1A7200361F761D/) | `0xa2b1926Cb477e92445Cf70602f1A7200361F761D` | PancakePair (mainPool) — confirmed genuine, see README §3.3 |
| [`pancake-router-0x10ED...6024e/`](./pancake-router-0x10ED43C718714eb63d5aA57B78B54704E256024e/) | `0x10ED43C718714eb63d5aA57B78B54704E256024e` | PancakeRouter (v2Router) — confirmed genuine, see README §3.4 |
| [`taxprocessor-clone-0xD0e4...9A2f1/`](./taxprocessor-clone-0xD0e4Bd493D25b7E53Fa8531e6dbC808Da549A2f1/) | `0xD0e4Bd493D25b7E53Fa8531e6dbC808Da549A2f1` | TaxProcessorUniV2 clone (Etherscan-resolved source, same as its implementation below) |
| [`taxprocessor-implementation-0x28af...37ae4/`](./taxprocessor-implementation-0x28aff2817dc5b17de15194ac2861a9caa8307ae4/) | `0x28aff2817dc5b17de15194ac2861a9caa8307ae4` | TaxProcessorUniV2 implementation — contains `TaxProcessorBaseStorage`, `TaxProcessorAdminImpl`, `TaxProcessorV2DispatchImpl`, `TaxProcessorCore`, `TaxProcessorUniV2` (see README §3.5) |
| [`dividend-clone-0xCbd8...863c9/`](./dividend-clone-0xCbd8C6c8B216c29A27ee4f41fb9515E6c6a863c9/) | `0xCbd8C6c8B216c29A27ee4f41fb9515E6c6a863c9` | Dividend clone |
| [`dividend-implementation-0x0116...dea65/`](./dividend-implementation-0x0116f1e42977eccdfd926fef688c6a7d289dea65/) | `0x0116f1e42977eccdfd926fef688c6a7d289dea65` | Dividend implementation — see README §3.6 |
| [`flapblackhole-0x0057...00DEad/`](./flapblackhole-0x00576E4Fb32296Cd973A0d413D0379609400DEad/) | `0x00576E4Fb32296Cd973A0d413D0379609400DEad` | FlapBlackHole (`eradicate()`, BURNER_ROLE-gated) — see README §3.8 |
| [`swapregistry-proxy-0x644A...fBEB6/`](./swapregistry-proxy-0x644A8f560138418bAD4EdEFC7c17878a3c2fBEB6/) | `0x644A8f560138418bAD4EdEFC7c17878a3c2fBEB6` | SwapRegistry `TransparentUpgradeableProxy` shell only — its implementation is unverified, see gap list below |
| [`swapregistry-proxyadmin-0x830C...49d95/`](./swapregistry-proxyadmin-0x830C709805612ab460C3C1e249cfC058CB049d95/) | `0x830C709805612ab460C3C1e249cfC058CB049d95` | SwapRegistry's `ProxyAdmin` (standard OZ) — owned by a lone EOA, see README §3.7 |

## Upstream — who holds power over the target

| Directory | Address | Role |
|---|---|---|
| [`portal-proxy-0xe2cE...9De0/`](./portal-proxy-0xe2cE6ab80874Fa9Fa2aAE65D277Dd6B8e65C9De0/) | `0xe2cE6ab80874Fa9Fa2aAE65D277Dd6B8e65C9De0` | Portal `TransparentUpgradeableProxy` shell — owns both taxProcessor and dividendContract; never named in the target's own code |
| [`portal-implementation-0x1533...5b74f/`](./portal-implementation-0x153378bbfa36411d34c20862725223E11665b74f/) | `0x153378bbfa36411d34c20862725223E11665b74f` | `Portal` — the ~1,400-line central Flap launchpad contract, plus its full 49-file dependency bundle (`Portal.sol`, `PortalBase.sol`, `PortalCommon.sol`, `IPortal.sol`, and every OZ/Uniswap/PancakeV3 interface it imports). See README §4.1–4.3. |
| [`portal-proxyadmin-0xB248...39bD4/`](./portal-proxyadmin-0xB2480c2D17BF4510701c4Def374DE6d22E039bD4/) | `0xB2480c2D17BF4510701c4Def374DE6d22E039bD4` | Portal's `ProxyAdmin` — owner is the master Safe below |
| [`safe-feereceiver-proxy-0x8a08...7aB0E/`](./safe-feereceiver-proxy-0x8a08D98CBB218fceB318Ecf3aBc1BA43D8A7aB0E/) | `0x8a08D98CBB218fceB318Ecf3aBc1BA43D8A7aB0E` | `feeReceiver` — Gnosis Safe proxy shell (v1.3.0), 3-of-4 |
| [`safe-marketaddress-proxy-0xC7f5...bF4A4/`](./safe-marketaddress-proxy-0xC7f501D25Ea088aeFCa8B4b3ebD936aAe12bF4A4/) | `0xC7f501D25Ea088aeFCa8B4b3ebD936aAe12bF4A4` | `marketAddress` — Safe proxy shell (v1.4.1), 2-of-5, also holds 5% of supply directly |
| [`safe-master-proxy-0x1f96...08A3b/`](./safe-master-proxy-0x1f96BC88f0794060433Be5F3EC9159a9C4f08A3b/) | `0x1f96BC88f0794060433Be5F3EC9159a9C4f08A3b` | Portal ProxyAdmin owner + Portal `DEFAULT_ADMIN_ROLE` — Safe proxy shell (v1.4.1), 3-of-4 |
| [`safe-singleton-GnosisSafeL2-v1.3.0-0x3E5c...D36E/`](./safe-singleton-GnosisSafeL2-v1.3.0-0x3E5c63644E683549055b9Be8653de26E0B4CD36E/) | `0x3E5c63644E683549055b9Be8653de26E0B4CD36E` | The actual `GnosisSafeL2` v1.3.0 singleton logic that `feeReceiver`'s proxy delegates into (read live from the proxy's storage slot 0, not assumed) |
| [`safe-singleton-SafeL2-v1.4.1-0x29fc...0C762/`](./safe-singleton-SafeL2-v1.4.1-0x29fcB43b46531BcA003ddC8FCB67FFE91900C762/) | `0x29fcB43b46531BcA003ddC8FCB67FFE91900C762` | The actual `SafeL2` v1.4.1 singleton logic that both `marketAddress` and the master Safe delegate into |

## No source available (documented gap, not an omission)

| Address | Why |
|---|---|
| `0x9a681bC1350636BBf81085207cde7485dAa67a65` | SwapRegistry implementation — **unverified on BscScan**, bytecode only |
| `0xa56B1cb37947A659CC0b5c5BbE48D44Fc31837b2` | TaxProcessor `ADMIN_IMPL` facet — **unverified at this address**; a matching contract (`TaxProcessorAdminImpl`) exists in the `taxprocessor-implementation` bundle above, but that's an inference, not an Etherscan bytecode-match certification |
| `0xAb8FF2bd20B8eDF958Adf9c373f0d78b8B3bFfb0` | TaxProcessor `DISPATCH_IMPL` facet — same caveat, likely matches `TaxProcessorV2DispatchImpl` in the same bundle |
| `PORTAL_TWEAK` (address unknown) | The facet Portal delegates `changeMarketWallet`/`updateTaxTokenAddresses`/etc. into — an internal immutable with no public getter; we couldn't even get the address, let alone the source. See README §4.3 and §6 item 1. |
| `0x182c13150CE95D3b90A6fcc3259f4Dc8Ef8A4f58` | Token creator/deployer — plain EOA, no code, nothing to verify |

`swapregistry-proxy` and `taxprocessor-clone`/`dividend-clone` above are Etherscan-resolved (it auto-matches a proxy's display to its implementation's source); their *own* bytecode is either the proxy shell or a 45-byte EIP-1167 clone respectively, not the logic shown.
