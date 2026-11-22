# OmniLit Finance — Litepaper

**Live App:** https://omnilit-finance.xyz/
**Network:** LitVM LiteForge Testnet (Chain ID: 4441)
**Contract:** OmniLitFinance.sol (Solidity ^0.8.24)

---

## Why We Built This

Most DeFi apps force you to jump between five different pages just to swap, stake, add liquidity, and borrow. OmniLit Finance puts all of those core actions into a single smart contract (`OmniLitFinance.sol`) on LitVM LiteForge (Chain ID 4441), paired with an on-chain AI strategy logger.

Everything is tracked per wallet inside one unified `UserVault` structure—no scattered approvals across multiple contracts, no bloated multi-hop routing.

---

## How the Protocol Works

Users work with native **zkLTC** and protocol-accounted **aUSD** (fixed in-contract at **1 zkLTC = 85 aUSD**). Every state-changing transaction automatically syncs your accrued staking yield before updating balances.

### 1. Instant Swap (`0.3%` Fee)
- **Contract function:** `swapZklForUsd()`
- Send native `zkLTC` and receive `aUSD` straight into your vault balance.
- A flat **0.3% fee** is deducted (`99.7%` net conversion at `1 zkLTC = 85 aUSD`).

### 2. Liquidity Pool
- **Contract functions:** `addLiquidity()` and `removeLiquidity(uint256 lpAmount)`
- Deposit `zkLTC` to mint `1:1` `lpShares` in the shared pool.
- Withdraw your `zkLTC` anytime by burning your `lpShares`.

### 3. Staking Vault (`19.20%` APY)
- **Contract functions:** `stakeZkl()`, `claimYield()`, or direct transfer (`receive()`)
- Stake `zkLTC` (or simply send `zkLTC` directly to the contract address) to earn **19.20% APY** paid in `aUSD`.
- Yield accrues every second and can be claimed into your spendable `aUSD` balance whenever you want.

### 4. Collateral Borrowing (`65%` Max LTV)
- **Contract functions:** `borrowUsd(uint256 aUsdAmount)` and `repayUsd(uint256 aUsdAmount)`
- Use your staked `zkLTC` as collateral to borrow up to **65% LTV** in `aUSD`.
- Repay your `aUSD` debt at any time to free up your borrowing limit.

### 5. On-Chain AI Risk Strategist
- **Contract functions:** `commitAiStrategy(bytes32 strategyHash, uint256 riskScore)` and `totalAiSignals()`
- Run a strategy profile, get a **0 to 100** risk score, and anchor the strategy hash permanently on-chain with your wallet address and timestamp.

### 6. Single-Call Vault Snapshot
- **Contract function:** `getVaultState(address user)`
- Reads your full position (`aUsdBalance`, `lpShares`, `stakedZkl`, live uncollected yield, `borrowedUsd`, `maxBorrowUsd`, and `aiSignalsLogged`) in one RPC call.

---

## Key Numbers

- **Exchange Rate:** `1 zkLTC = 85 aUSD`
- **Swap Fee:** `0.3%`
- **Staking APY:** `19.20%`
- **Max Borrow LTV:** `65%`
- **Chain ID:** `4441` (LitVM LiteForge Testnet)
- **RPC:** https://rpc.testnet.liteforge.zeeve.net/
- **Explorer:** https://explorer.testnet.liteforge.zeeve.net

---

## Things to Keep in Mind

- **Testnet Build:** This contract runs on LitVM LiteForge Testnet (`4441`) for testing and iteration.
- **Internal aUSD Ledger:** `aUSD` is tracked inside `UserVault` balances rather than as a separate ERC-20 token contract.
- **Fixed Rate:** The `85 aUSD` per `zkLTC` conversion rate is hardcoded for deterministic testnet behavior.
- **Staked Principal:** In v1, staked `zkLTC` stays locked as your permanent yield and borrow collateral base (unlike `lpShares`, which can be withdrawn via `removeLiquidity`).


