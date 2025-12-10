# Vicuna Finance Oracle Manipulation PoC

## Overview

This repository contains a Proof of Concept (PoC) demonstrating the oracle manipulation vulnerability that led to a **$700,000 exploit** on Vicuna Finance (Sonic chain) on March 28, 2025.

**Original post-mortem:** [D23E - Vicuna Finance Post Mortem](https://d23e.ch/research/vicuna-post-mortem)

## The Vulnerability

Vicuna Finance used a **naive LP token pricing formula** that calculated the LP token value as the sum of underlying assets:
```
price_lp = (reserve0 * price0 + reserve1 * price1) / totalSupply
```

This formula is vulnerable because an attacker can **manipulate the reserves** via a large swap, temporarily inflating the LP token's perceived value.

### Attack Flow
```
┌─────────────────────────────────────────────────────────────────┐
│                    ORACLE MANIPULATION ATTACK                   │
└─────────────────────────────────────────────────────────────────┘

1. INITIAL STATE
   ┌─────────────────┐
   │   Beets Pool    │
   │  S: 1,000,000   │
   │ stS: 1,000,000  │
   │ LP Price: $2.00 │
   └─────────────────┘

2. MANIPULATE POOL (Flash Loan)
   ┌─────────────────┐
   │ Attacker swaps  │
   │ 900k S → stS    │
   └────────┬────────┘
            │
            ▼
   ┌─────────────────┐
   │   Beets Pool    │
   │  S: 1,900,000   │  ← Reserves manipulated
   │ stS: 527,064    │
   │ LP Price: $2.42 │  ← +21% inflated
   └─────────────────┘

3. EXPLOIT INFLATED PRICE
   ┌─────────────────┐
   │ Deposit LP as   │
   │ collateral      │
   │ Borrow against  │
   │ inflated value  │
   └────────┬────────┘
            │
            ▼
   ┌─────────────────┐
   │ Attacker borrows│
   │ $182 instead of │
   │ $150 (per 100LP)│
   └─────────────────┘

4. RESTORE POOL & PROFIT
   ┌─────────────────┐
   │ Reverse swap    │
   │ Repay flash loan│
   │ Keep profits    │
   │ Leave bad debt  │
   └─────────────────┘
```

## The Fix: Fair LP Pricing

The secure approach uses the **pool invariant (k = x * y)** instead of raw reserves:
```
price_lp = 2 * sqrt(k * price0 * price1) / totalSupply
```

This formula is manipulation-resistant because:
- The invariant `k` remains constant during swaps (minus fees)
- Manipulating reserves doesn't change `k`, so the price stays stable

**Reference:** [Alpha Finance - Fair LP Token Pricing](https://blog.alphaventuredao.io/fair-lp-token-pricing/)

## Repository Structure
```
vicuna-poc/
├── src/
│   ├── VulnerableOracle.sol    # Naive oracle (exploited)
│   ├── FixedOracle.sol         # Fair pricing oracle (secure)
│   └── mocks/
│       ├── MockPool.sol        # Simulated AMM pool
│       └── MockPriceFeed.sol   # Price feed for underlying tokens
├── test/
│   └── OracleManipulation.t.sol # PoC tests
└── README.md
```

## Running the PoC

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation
```bash
git clone <repo>
cd vicuna-poc
forge install
```

### Run Tests
```bash
forge test -vvv
```

### Expected Output
```
[PASS] test_OracleManipulationAttack()
Logs:
  === ATTAQUE ORACLE MANIPULATION ===
  
  AVANT MANIPULATION:
    Reserve0: 1000000
    Reserve1: 1000000
    Prix LP (vulnerable): 2 USD
    Prix LP (fixed): 2 USD
  
  APRES MANIPULATION (swap 900k token0):
    Reserve0: 1900000
    Reserve1: 527064
    Prix LP (vulnerable): 2 USD (+21%)
    Prix LP (fixed): 2 USD (stable)
```

## Key Findings

| Metric | Before Attack | After Manipulation | Change |
|--------|---------------|-------------------|--------|
| Reserve0 | 1,000,000 | 1,900,000 | +90% |
| Reserve1 | 1,000,000 | 527,064 | -47% |
| K (invariant) | 1e12 | ~1e12 | ~0% |
| Vulnerable Oracle | $2.00 | $2.42 | **+21%** |
| Fixed Oracle | $2.00 | $2.00 | **0%** |

## Lessons Learned

1. **Never price LP tokens using raw reserves** — always use invariant-based fair pricing
2. **Audit new market deployments** — Vicuna's core protocol may have been audited, but the new LP markets introduced the vulnerability
3. **Implement deployment delays** — a timelock would have given white hats time to identify the issue
4. **Monitor for large swaps** — on-chain monitoring could have detected the manipulation in real-time

## Timeline

| Time (UTC) | Event |
|------------|-------|
| Mar 27, 17:28 | Vulnerable LP market deployed |
| Mar 28, 11:52 | Attacker executes exploit |
| Mar 28, 12:08 | Funds bridged to Ethereum (~367 ETH) |
| Mar 28, 13:03 | Markets paused by admin |

**Window of opportunity:** ~18 hours between deployment and exploit.

## Disclaimer

This PoC is for **educational purposes only**. It demonstrates a known vulnerability to help developers and auditors understand and prevent similar issues.

## Author

Security research by [Dayeneris] — Smart Contract Auditor

## References

- [D23E Post Mortem](https://d23e.ch/research/vicuna-post-mortem)
- [Alpha Finance - Fair LP Token Pricing](https://blog.alphaventuredao.io/fair-lp-token-pricing/)
- [Vicuna Finance Twitter](https://x.com/VicunaFinance)# vicuna-oracle-manipulation-poc
