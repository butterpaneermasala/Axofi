# Research-Inspired Directions (Axofi + alternative ideas)

This document has two goals:
1) Collect a few concrete preprints/papers that are *directly relevant* to what we’re building.
2) Propose 2–3 protocol directions that are plausibly unique (or at least under-served on Mantle), including one that can be separate from Axofi.

---

## A. What Axofi is today (snapshot)
See [docs/axofi-idea.md](docs/axofi-idea.md).

In one line: split a yield-bearing stable into PT (principal) and YT (yield risk), then (in the demo) auto-sell YT to lock a fixed return at deposit time.

---

## B. Papers / preprints worth reading (with why they matter)

### 1) Yield tokenization & fixed rate theory
- **Split the Yield, Share the Risk: Pricing, Hedging and Fixed rates in DeFi** (arXiv:2505.22784)
  - Link: https://arxiv.org/abs/2505.22784
  - Why it matters:
    - Formalizes *yield tokenization* (PT/YT splitting) with a no-arbitrage pricing view.
    - Frames YT as an instrument for hedging yield volatility / interest rate risk.
    - Discusses AMMs / bonding curves for trading yield tokens and yield futures.
  - Axofi takeaway:
    - The “fixed yield” should emerge from pricing YT as a function of expected yield and time-to-maturity, not a constant 5%.

- **Design of a Decentralized Fixed-Income Lending AMM Protocol Supporting Arbitrary Maturities** (arXiv:2512.16080)
  - Link: https://arxiv.org/abs/2512.16080
  - Why it matters:
    - Proposes an AMM approach for fixed-income lending that supports *arbitrary maturities* (term structure) in one contract.
  - Axofi takeaway:
    - If you want “real DeFi fixed income”, maturity is not optional; it’s the product.

### 2) MEV, sandwich attacks, and LP fairness
- **RediSwap: MEV Redistribution Mechanism for CFMMs** (arXiv:2410.18434)
  - Link: https://arxiv.org/abs/2410.18434
  - Why it matters:
    - Designs an AMM that captures MEV at the application level and refunds it to users/LPs.
  - Axofi takeaway:
    - If you build any YT/term AMM, MEV is a first-order UX + LP return issue.

- **Arbitrageurs' profits, LVR, and sandwich attacks: batch trading as an AMM design response** (arXiv:2307.02074)
  - Link: https://arxiv.org/abs/2307.02074
  - Why it matters:
    - Shows batching trades can reduce LVR and sandwich attacks.
  - Axofi takeaway:
    - For thin-liquidity assets (USDY/mUSD on Mantle is currently thin), MEV can dominate. Batch-auction style execution is a strong design lever.

- **Towards a Theory of Maximal Extractable Value I: Constant Function Market Makers** (arXiv:2207.11835)
  - Link: https://arxiv.org/abs/2207.11835
  - Why it matters:
    - Game-theoretic analysis of MEV in CFMMs.
  - Axofi takeaway:
    - “Uniswap fork” without MEV thinking is usually a trap.

### 3) Stablecoin / system risk framing
- **A DeFi Bank Run: Iron Finance, IRON Stablecoin, and the Fall of TITAN** (SSRN 3888089)
  - Link: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3888089
  - Why it matters:
    - Shows how “fixed value liabilities backed by uncertain assets” create run dynamics.
  - Axofi takeaway:
    - If PT is redeemable 1:1 and YT is risky, you must clearly define what backs PT under stress (liquidity + asset risk + pricing assumptions).

- **Where do DeFi Stablecoins Go? A Closer Look at What DeFi Composability Really Means** (SSRN 3893487)
  - Link: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3893487
  - Why it matters:
    - Highlights that “composability” in practice often becomes yield-chasing and complex inter-protocol exposure.
  - Axofi takeaway:
    - Being “composable” is good; being “composable without guardrails” can be how systemic risk enters.

---

## C. What seems under-served (especially on Mantle)
This is phrased carefully: I can’t *prove* nobody is doing it without a full ecosystem audit, but these appear underbuilt or at least not mainstream on Mantle.

### Observation 1 — Real fixed income needs term structure
Many DeFi “fixed” products are actually either:
- fixed for short windows,
- fixed only after incentives,
- or synthetic fixed created by selling yield at a moment in time.

The papers above argue the missing primitive is a term-structure market (multiple maturities).

### Observation 2 — If liquidity is thin, MEV + execution dominates
If USDY/mUSD liquidity is thin, then building a vanilla AMM for YT will likely:
- leak value to MEV,
- give bad execution to users,
- and provide weak LP returns.

So a “better execution / MEV redistribution” design may be more impactful than yet-another AMM.

---

## D. 3 protocol directions you can build (1 can be separate from Axofi)

### Idea 1 (Axofi++): Oracle-based fixed yield with maturity (no need for deep YT AMM)
**Pitch:** Use onchain rate/oracle updates to quote a fixed rate for maturity $T$, mint PT that redeems at maturity, and optionally mint YT for traders. Avoid depending on deep YT AMM liquidity.

- Why it’s unique-ish:
  - Most hackathon PT/YT demos hardcode a constant yield or require liquid YT markets. This direction turns it into a fixed-income product with explicit maturity.
- Why it’s feasible:
  - Implement pricing/settlement first, add an AMM later.
- Paper inspiration:
  - arXiv:2505.22784 (pricing/hedging lens)
  - arXiv:2512.16080 (arbitrary maturities as first-class)

### Idea 2 (Separate protocol): MEV-redistributing swap venue for “difficult assets” (rebasing + restricted tokens)
**Pitch:** A Mantle-native swap venue / router that executes trades in batches (or with MEV redistribution), explicitly targeting assets where execution quality matters: rebasing tokens, oracle-priced RWAs, low-liquidity stables.

- Why it’s unique-ish:
  - Most DEX UX focuses on price and fees; fewer protocols explicitly sell “execution quality” and MEV fairness as the core product.
- Why it’s feasible:
  - Batch execution + a simplified redistribution scheme can be demoed without building a full DEX ecosystem.
- Paper inspiration:
  - arXiv:2410.18434 (MEV redistribution)
  - arXiv:2307.02074 (batch trading)
  - arXiv:2207.11835 (MEV theory)

### Idea 3 (Axofi-adjacent or separate): Rebase-safe accounting + lending primitives (“shares everywhere”)
**Pitch:** Build a minimal money-market / vault standard that treats rebasing tokens in **share units** (like the logic you already started with gons/fragments), so protocols stop breaking on rebases.

- Why it’s unique-ish:
  - Many protocols avoid rebasing assets; a shared “rebase-safe building block” unlocks integrations.
- Why it’s feasible:
  - You can ship a reference vault + adapter + invariant tests.
- Paper inspiration:
  - While not directly a rebasing-token design paper, this relates to the “shares-based rebasing” mechanism described in Ondo’s USDY/rUSDY docs and the general design approach discussed in rebasing literature.

---

## E. Recommendation (if you want to stay close to Axofi)
- Keep Axofi as the PT/YT story, but **make maturity explicit** and **replace the hardcoded YT price** with an oracle/forward-based quote.
- Keep “YT trading” as an optional extension (later), because early liquidity is usually the hardest part.
- If you want a clean “separate idea”, Idea 2 (MEV-redistributing swap execution on Mantle) is the most distinct from the current Axofi vault.
