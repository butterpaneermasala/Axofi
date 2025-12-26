# Axofi (Mantle) — Current Protocol Idea

## One-liner
A Mantle-native “volatility dam” that converts variable yield (e.g., Ondo USDY/mUSD-style) into a predictable, upfront fixed outcome by splitting principal vs yield risk into two ERC-20s.

## Problem
Yield-bearing assets pay *variable* yield. Most users want predictable outcomes (fixed return, fixed redemption value). Risk-takers may want exposure to yield changes.

## Core Concept
Split an underlying yield-bearing asset into:
- **PT (Principal Token)**: claim on principal (intended: redeem 1:1 for underlying).
- **YT (Yield Token)**: claim on the yield stream / rate risk.

The protocol “strips” yield by selling YT to the market (or a pricing mechanism) and gives the depositor additional PT, thereby locking a fixed return at deposit time.

## Actors
- **Depositor (risk-averse)**: wants fixed payout.
- **Trader / risk-taker**: buys YT to speculate on future yield (or uses it as a hedge).
- **Market maker / AMM**: provides liquidity for YT↔cash swaps.
- **Vault (AxoVault)**: orchestrates splitting and redemption.

## Current Demo Mechanics (what’s implemented)
Your contracts implement a simplified “fixed-yield deposit”:

1. User deposits underlying asset into the vault.
2. Vault mints:
   - PT to the user (1:1 with deposit amount)
   - YT to the vault (1:1 with deposit amount)
3. Vault immediately sells YT to an AMM for underlying cash.
4. Vault mints *extra PT* to the user equal to the cash received.

Net result (demo):
- User receives **PT = deposit + (YT sale proceeds)**.
- User holds no YT (the protocol sold it).
- Vault holds more underlying (deposit + sale proceeds), enabling redemption.

## Redemption (demo)
User burns PT to redeem underlying 1:1, provided the vault has enough liquidity.

## Current Assumptions / Simplifications
- **Fixed YT price** in the mock AMM (hardcoded 5% of notional):
  - YT is sold immediately at a constant price, independent of maturity/time.
- **No explicit maturities**: there’s no term structure (3m/6m/12m) implemented yet.
- **Underlying behavior is mocked**: mUSD/price evolution/rebasing are approximations.

## Code Mapping (where things live)
- Vault: `contracts/src/AxoVault.sol`
  - `depositFixed(amount, minPtOut)` mints PT/YT, sells YT, mints extra PT
  - `redeem(ptAmount)` burns PT and transfers underlying
- Token (PT/YT): `contracts/src/AxoToken.sol`
  - Mint/burn controlled by owner (vault owns PT & YT)
- Mock AMM: `contracts/src/mocks/MockAMM.sol`
  - `swapYTforCash(ytAmount)` pays fixed-rate cash
- Mock underlying / rebase modeling:
  - `contracts/src/mocks/MockMUSD.sol`
  - `contracts/src/mocks/MockMUSDEngine.sol`
  - `contracts/src/mocks/MockUSDYOracle.sol`

## Open Questions (already identified)
- Should the protocol use **USDY (accumulating)** or **mUSD (rebasing)** as the canonical underlying on Mantle?
- Should YT pricing come from:
  - an AMM (Uniswap v3 fork or own AMM), or
  - an oracle/forward-style mechanism (less dependent on liquidity)?
- Risk handling:
  - What happens if APY drops? (YT should reprice; fixed leg needs hedging or disclaimers)
  - How does the protocol behave under liquidity stress / bank run?
- Fee model:
  - fees on YT trading?
  - fees on locked-in PT uplift?

## Proposed Near-Term Upgrade (still “same idea”, more realistic)
- Add explicit maturities (e.g., 30/90/180/365 days) and price YT as a function of time-to-maturity.
- Use an oracle-driven model for expected yield instead of hardcoding 5%.
- Support both USDY and mUSD deposits (unwrap/wrap internally) if integrating with Ondo’s Mantle assets.

---

# Axofi v1 — Concrete Protocol Spec (recommended)

This section makes Axofi “real” enough to build:
- explicit maturity/term,
- explicit payout rules for PT vs YT,
- explicit role of Ondo USDY/mUSD on Mantle.

## v1 Design Choice: canonical underlying = mUSD (rebasing), optionally accept USDY

Rationale:
- **mUSD yield accrues as additional token units via rebasing**, which makes “principal vs yield” separation natural.
- PT can be defined as a fixed number of mUSD units (clean UX: 1 PT = 1 mUSD claim), while YT is a claim on the *rebase growth*.

Support both inputs:
- If user has **mUSD**: deposit directly.
- If user has **USDY**: protocol can (optionally) call Ondo’s `wrap()` to convert to mUSD before deposit.

## Instruments

Per maturity (term) $T$ (e.g., 30d / 90d / 180d / 365d):
- `PT_T`: ERC-20 principal token for maturity $T$.
- `YT_T`: ERC-20 yield token for maturity $T$.

## Lifecycle

### 1) Deposit and split
User deposits `amount` of mUSD into the maturity vault `Vault_T`.

Mint:
- `amount` of `PT_T` to the depositor.
- `amount` of `YT_T` to the depositor (or to the vault if we keep “auto-sell” as default).

Accounting requirement (important for rebasing):
- Internally, the vault should track **shares** rather than raw `balanceOf` deltas, so rebases don’t break accounting.

### 2) Getting “fixed” vs “floating” exposure
Two user modes:

**A) Fixed mode (risk-averse user)**
- User sells `YT_T` for immediate cash (mUSD) via a pricing mechanism.
- The cash received is added to their fixed outcome (either minted as extra PT, or simply paid out immediately and PT remains principal-only).

**B) Floating mode (risk-taker)**
- User keeps `YT_T`.
- At maturity, they claim the realized yield residual.

### 3) Maturity settlement
At maturity time `t = start + T`, the vault settles payouts from its mUSD holdings.

Let:
- `principalOwed = totalSupply(PT_T)`
- `vaultAssets = vault.mUSDBalance()` (rebased amount)

Payout rule:
- PT redeems first, up to principalOwed.
- Any residual is claimable by YT holders.

Concretely:
- PT holders can redeem `1 PT_T -> 1 mUSD` while `vaultAssets >= remainingPrincipal`.
- YT holders redeem pro-rata from `max(vaultAssets - principalOwed, 0)`.

If `vaultAssets < principalOwed` (bad outcome), PT is undercollateralized and redeems pro-rata (this is the honest risk statement for “not truly guaranteed”).

## Pricing YT in v1 (how “fixed return” is determined)

You have two viable v1 approaches:

### Option 1 (most buildable): auction / batch execution for YT
- Periodically run a batch auction: users submit sell orders for `YT_T`, buyers submit bids in mUSD.
- Clearing price is uniform; execution is less MEV-prone than a thin AMM.

Why: if liquidity is thin, a Uniswap-style AMM produces bad execution and invites MEV.

### Option 2 (demo-friendly): oracle-quoted YT price with haircut
- Quote an expected yield for term $T$ from an oracle/rate model and apply a conservative haircut.
- `YT_price = haircut * expectedYieldOver(T)`.

This is closest to your current `MockAMM` approach, but with:
- time-to-maturity sensitivity,
- conservative pricing (haircuts) to reduce insolvency risk.

## How this aligns with Ondo on Mantle (constraints you must design for)

From Ondo’s Mantle integration guidelines:
- mUSD is the rebasing variant of USDY and supports `wrap/unwrap` conversion.
- mUSD inherits transfer restrictions (blocklist / transfer hook) similar to USDY.
- mUSD rebases daily (Ondo states 12:00am GMT).

Implication: every transfer/approve/transferFrom can revert for restricted addresses. Axofi must treat this as a first-class integration constraint.

---

# Risk Model (what can go wrong) and what Axofi can do

This is the “make Axofi strong” part: be explicit about risks and mitigations.

## 1) Yield / rate risk (core economic risk)
What can go wrong:
- Realized yield over term $T$ is lower than what YT buyers paid / what fixed users locked in.

Mitigations:
- Price YT conservatively (haircut expected yield).
- Cap total issuance per maturity until secondary liquidity improves.
- Maintain a reserve buffer funded by fees (optional v1.5).

## 2) Liquidity risk (bank-run dynamics)
What can go wrong:
- Users try to redeem PT early (or before maturity) and the vault doesn’t have enough liquid assets.

Mitigations:
- Make PT redeemable **only at maturity** (recommended for a true fixed-term product).
- If you allow early exit, do it via a secondary market (sell PT), not via the vault.

## 3) Oracle / pricing manipulation risk
What can go wrong:
- If you quote YT prices from an oracle, bad/malicious updates or time-window manipulation can create unfair pricing and insolvency.

Mitigations:
- Prefer auction/batch execution for YT.
- If oracle-quoted: use TWAP-like smoothing, conservative haircuts, and per-epoch caps.

## 4) Rebasing integration risk (accounting bugs)
What can go wrong:
- Using raw `balanceOf` deltas for a rebasing asset can break invariants and allow value leakage.

Mitigations:
- Track shares internally.
- Build invariant tests for “rebases do not change relative ownership”.

## 5) Transfer restriction / blocklist risk (Ondo constraint)
What can go wrong:
- Deposits, withdrawals, or AMM transfers revert due to transfer restrictions.
- Some venues refuse to integrate.

Mitigations:
- Fail fast with clear errors on deposit (check restrictions where possible).
- Avoid designs that require transferring tokens to arbitrary addresses in large fan-outs.

## 6) Smart contract risk
What can go wrong:
- Reentrancy, approval issues, admin abuse, upgrade mistakes.

Mitigations:
- Reentrancy guards on deposit/redeem.
- Minimal privileged roles; timelocked admin changes.
- Emergency pause only as a last resort.

---

# What we should build next (to match this spec)

1) Add maturity vault(s) and define settlement rules (PT first, YT residual).
2) Replace `MockAMM` fixed price with either (a) batch auction module, or (b) oracle-quoted term pricing with haircut.
3) Update tests to reflect maturity + settlement.
4) Decide whether fixed mode auto-sells YT by default, or whether users choose.


# Notes on Mantle + Ondo Alignment (for later)
- Ondo describes USDY (accumulating) and mUSD (rebasing) on Mantle, with wrap/unwrap conversions and transfer restrictions. If Axofi integrates with these assets, the vault and any AMM must tolerate transfer hooks and rebasing/accounting realities.
