# AxoFi — End-to-end Protocol Flow (Batch Auction + Maturity)

This doc explains what AxoFi is doing, *end to end*, and how the pieces connect.

## One sentence
AxoFi converts a variable-yield asset into a fixed-term product by splitting each deposit into **PT (principal claim)** and **YT (yield claim)**, then (for fixed users) selling YT via a **batch auction** to lock a fixed outcome at deposit time.

---

## Components (what each contract does)

### Vault (the product)
- **Contract:** `contracts/src/AxoVault.sol`
- **Job:**
  - Accept deposits of the underlying asset (e.g., mUSD).
  - Mint **PT** and **YT**.
  - Offer two modes:
    - **Fixed mode:** auto-sell YT via auction, mint extra PT to the depositor (locks fixed outcome).
    - **Floating mode:** give user PT + YT and do *not* sell YT.
  - Enforce **maturity**: redemptions happen at/after a timestamp.
  - Settle at maturity with **PT senior, YT residual**.

### PT / YT (the instruments)
- **Contract:** `contracts/src/AxoToken.sol`
- **Job:** ERC-20 tokens whose mint/burn is controlled by the vault (the vault is the token owner).
  - PT represents the depositor’s principal claim.
  - YT represents the residual/yield claim.

### Batch auction (the pricing + execution venue)
- **Contract:** `contracts/src/AxoBatchAuction.sol`
- **Interface:** `contracts/src/interfaces/IAxoAuction.sol`
- **Job:** A simple batch-clearing mechanism where:
  - Buyers deposit **cash** (same token as underlying in this v1).
  - Sellers deposit **YT**.
  - When both sides exist, anyone can `clear()` the epoch.
  - Users `claim()` pro-rata results at a uniform clearing price.

---

## Why this solves the core problems

### Problem 1: Variable yield is unpredictable
Users don’t want to bet on future APY.

**Solution:** split the position:
- PT = principal-like claim
- YT = yield/rate-risk claim

The protocol can then sell YT immediately for “cash today” to create a fixed outcome.

### Problem 2: Thin liquidity + AMMs cause bad execution / MEV
If YT is thinly traded, AMM execution can be poor and MEV-prone.

**Solution:** batch auctions reduce some MEV paths and give uniform clearing.

### Problem 3: Fixed products need a term
Without maturity, “fixed yield” is ambiguous and can create run/liquidity issues.

**Solution:** the vault has a maturity timestamp `I_MATURITY`.
- Redemptions are only allowed at/after maturity.
- Settlement rule is explicit.

---

## Main flows

### Flow A — Fixed deposit (risk-averse)
Goal: user locks in a fixed outcome *now*.

1) User calls `depositFixed(amount, minPtOut)`
2) Vault transfers `amount` underlying from user to vault
3) Vault mints:
   - `amount` PT to user
   - `amount` YT to **vault** (because vault will sell it)
4) Vault sells YT via auction:
   - `depositYT(ytAmount)` into current epoch
   - if there are no bids, the vault reverts (`AxoVault__InsufficientLiquidity`)
   - `clear()` epoch
   - `claim()` cash from the auction
5) Vault mints extra PT to user equal to auction cash received
6) User ends with a larger PT balance (principal + fixed uplift)

At maturity:
- user redeems PT for underlying using `redeem(ptAmount)`

### Flow B — Floating deposit (yield exposure)
Goal: user keeps yield exposure instead of selling it.

1) User calls `depositFloating(amount)`
2) Vault transfers `amount` underlying from user to vault
3) Vault mints:
   - `amount` PT to user
   - `amount` YT to user

At maturity:
- user redeems PT using `redeem(ptAmount)`
- user redeems YT using `redeemYield(ytAmount, minAssetsOut)`

### Flow C — Maturity settlement rule (PT senior, YT residual)
At the time of a YT redemption, vault computes:

- `vaultAssets = balanceOf(underlying, vault)`
- `outstandingPT = PT.totalSupply()`
- `yieldAvailable = max(vaultAssets - outstandingPT, 0)`

YT holder burning `ytAmount` receives:

$$
assetsOut = ytAmount \cdot \frac{yieldAvailable}{YT.totalSupply()}
$$

This ensures:
- YT cannot drain principal (PT remains redeemable if the vault is solvent)
- YT gets whatever remains above the principal requirement

---

## What’s “real” vs “still simplified”

What’s real already:
- All of the mechanics run onchain: PT/YT minting, auction clearing, maturity gating, pro-rata settlement.

What’s still simplified (intentionally for v1):
- The auction is a simple pro-rata batch clear (no limit prices / no order cancellation / no min duration).
- Underlying yield in tests is simulated by minting extra underlying into the vault; in production this would come from a rebasing/yield-bearing asset (e.g., mUSD behavior).

---

## How to read the code
- Vault product logic: `contracts/src/AxoVault.sol`
  - `depositFixed`
  - `depositFloating`
  - `redeem` (PT only, at/after maturity)
  - `redeemYield` (YT residual, at/after maturity)
- Auction execution: `contracts/src/AxoBatchAuction.sol`

