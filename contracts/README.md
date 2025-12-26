AxoFi - The Volatility Dam for Mantle Network

Regenerate your savings with guaranteed returns.

AxoFi is a consumer-facing Fixed Yield Savings Protocol built on Mantle Network. It acts as a "Volatility Dam," stripping the variable yield from assets like mUSD and mETH to offer users a secure, fixed-term deposit product.

Why AxoFi?

- Predictability: Convert volatile, variable yields into a known, fixed return so users can plan finances without uncertainty.
- Simplicity: Deposit a supported asset and receive a principal token that represents a guaranteed payout at maturity.
- Safety: The protocol separates risky future yield from the safe principal immediately, reducing exposure to future market fluctuations.

How it helps users

- Lock in returns today: Users receive a clear, fixed outcome for their deposit rather than exposure to future APY swings.
- Composability: Principal tokens are ERC-20 compatible and can be used across DeFi for lending, collateral, or trading.
- Test-friendly: Demo tools and mocks let users and auditors reproduce economic scenarios in local/testnet environments.

Roadmap (high level)

- Mainnet integration: Replace mocks with real market makers and router integrations.
- Term options: Add multiple fixed-term maturities (3m / 6m / 12m).
- Better UX: Zappers and fiat onboarding to make deposits seamless.

License

MIT License. Built for experimentation and testing in the Mantle ecosystem.

How?
=> user1 deposit mUSD, locks it for t1 time and gets pt and yt
=> we can build a AMM to swap the yt for more pt (protocol will automatically do this for user1)
=> user2 can swap mnt-yt, yt-pt, pt-mnt, and trade
=> user1 does not like risk, use2 likes risk
=> what about claiming?
=> so what we will be doing is, the user can wait the t1 time to claim their mUSD back by depositing pt, pt:mUSD = 1:1, pt is tradeble anw, using our swap anyone can trade pt-mt and so can use defi apps
=> should we use exitsting AMM or build our own tho?
=> then this makes our protcol a what? a idk what to call + AMM, should we make a trade page too?
====> quesiton, what about yt? if someone buys yt, they will price of yt = AYP of mUSD ?
===> should i build my own AMM or fork uniswap v3