# OmniLit Finance — Litepaper

**Live App:** https://omnilit-finance.xyz/  
**Network:** LitVM LiteForge Testnet (Chain ID: `4441`)  
**Contract:** `OmniLitFinanceV2` (Solidity `^0.8.24`) — `0x0D977b70A7c8DeDabeE26f84384D65228084Dfd4`

## Why We Built This
Most DeFi apps force you to jump between five different pages just to swap, stake, add liquidity, and borrow. OmniLit Finance puts all of those core actions—alongside on-chain governance voting and zkLink cross-chain relay tracking—into a unified protocol on LitVM LiteForge (Chain ID `4441`).

Everything is tracked per wallet inside one unified `UserVault` structure—no scattered approvals across multiple contracts, no bloated multi-hop routing.

## How the Protocol Works
Users work with native `zkLTC` and protocol-accounted `aUSD` (fixed in-contract at `1 zkLTC = 85 aUSD`). State-changing transactions automatically sync your accrued staking yield before updating balances.

1. **Instant Swap (0.3% Fee)**  
   *Contract function:* `swapZklForUsd()`  
   Send native `zkLTC` and receive `aUSD` straight into your vault balance.  
   A flat `0.3%` fee is deducted (`99.7%` net conversion at `1 zkLTC = 85 aUSD`).

2. **Liquidity Pool**  
   *Contract functions:* `addLiquidity()` and `removeLiquidity(uint256 lpAmount)`  
   Deposit `zkLTC` to mint `lpShares` in the shared pool.  
   Withdraw your `zkLTC` liquidity anytime by burning `lpShares`.

3. **Yield Staking Vault (18.5% APY)**  
   *Contract functions:* `stakeZkl()` and `claimYield()`  
   Stake `zkLTC` to accrue yield continuously at `18.5% APY` (`1850 bps`) and claim accrued rewards into your `aUSD` vault balance whenever you want.

4. **Collateral Borrowing (65% Max LTV)**  
   *Contract functions:* `borrowUsd(uint256 aUsdAmount)` and `repayUsd(uint256 aUsdAmount)`  
   Use your staked `zkLTC` as collateral to borrow up to `65%` LTV in `aUSD`.  
   Repay your `aUSD` debt at any time to free up your borrowing limit.

5. **On-Chain Governance Vote**  
   *Contract functions:* `createProposal(string title, uint256 durationSeconds)`, `vote(uint256 proposalId, bool support)`, `proposalCount()`, and `getProposal(uint256 proposalId)`  
   Create proposals and cast `YES` or `NO` votes directly on-chain on LitVM `4441`.

6. **zkLink Cross-Chain Relay**  
   *Contract function:* `relayFromZkLink(string sourceChain, bytes32 txRef)` and `totalBridgedZkLink()`  
   Submit cross-chain relay deposits from routes such as `zkLink Nova`, `zkLink X`, `Ethereum Sepolia`, and `Arbitrum` to `LitVM 4441` with a generated `txRef` hash.

7. **Single-Call Vault Snapshot**  
   *Contract function:* `getVaultState(address user)`  
   Reads your full vault position (`aUsdBalance`, `lpShares`, `stakedZkl`, live uncollected `yield`, `borrowedUsd`, `maxBorrowUsd`, and proposal count) in a single RPC call.

## Key Numbers
- **Exchange Rate:** `1 zkLTC = 85 aUSD`
- **Swap Fee:** `0.3%` (`30 bps`)
- **Staking APY:** `18.5%` (`1850 bps`)
- **Max Borrow LTV:** `65%` (`6500 bps`)
- **Chain ID:** `4441` (LitVM LiteForge Testnet)
- **RPC:** `https://rpc.testnet.liteforge.zeeve.net/`
- **Explorer:** `https://explorer.testnet.liteforge.zeeve.net`

## Things to Keep in Mind
- **Testnet Build:** This contract runs on LitVM LiteForge Testnet (`4441`) for testing and iteration.
- **Internal aUSD Ledger:** `aUSD` is tracked inside `UserVault` balances rather than as a separate ERC-20 token contract.
- **Fixed Rate:** The `85 aUSD` per `zkLTC` conversion rate is hardcoded for deterministic testnet behavior.
- **Staked Principal:** Staked `zkLTC` serves as your yield and borrow collateral base (unlike `lpShares`, which can be withdrawn via `removeLiquidity`).
