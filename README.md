# 🪙 Decentralized Stable Coin System (DSC)

## Overview

The **Decentralized Stable Coin System (DSC)** is a minimal, algorithmic, and exogenously collateralized stablecoin protocol pegged to the USD. It includes:

* `DecentralizedStableCoin`: An ERC20 token that represents the stablecoin (DSC).
* `DSCEngine`: The core engine that manages collateral deposits, minting, redemption, and liquidation.

Users must remain overcollateralized to avoid liquidation, and health factors are enforced to maintain system stability.

---

## Getting Started

Ensure you have [Foundry](https://book.getfoundry.sh/) installed. If not:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 1. Install Dependencies

```bash
forge install
```

### 2. Set Up Environment (Optional for Mainnet Forking)

```bash
cp .env.example .env
```

Then edit `.env` to include:

```env
MAINNET_RPC_URL=<your_rpc_url>
PRIVATE_KEY=<your_private_key>
ETHERSCAN_API_KEY=<your_key> # If using verification
```

### 3. Run Tests

```bash
forge test -vv
```

---

## Contracts

### 🔹 `DecentralizedStableCoin.sol`

* Standard ERC20 token with `mint()` and `burn()` restricted to the owner (`DSCEngine`).

### 🔸 `DSCEngine.sol`

Core logic for:

* Collateral deposits
* DSC minting & burning
* Collateral redemption
* Health factor enforcement
* Liquidation of undercollateralized accounts

---

## Key Constants

| Constant                | Value      | Description                                     |
| ----------------------- | ---------- | ----------------------------------------------- |
| `LIQUIDATION_THRESHOLD` | 50         | Collateral must be worth 200% of the debt       |
| `LIQUIDATION_BONUS`     | 10         | Liquidators get a 10% bonus                     |
| `MINIMUM_HEALTH_FACTOR` | 1e18 (1.0) | Minimum safe health factor to avoid liquidation |

---

## Example Usage

```solidity
// 1. Deposit collateral
dsce.depositCollateral(WETH, 10 ether);

// 2. Mint stablecoins
dsce.mintDsc(5000e18);

// 3. Burn stablecoins
dsce.burnDsc(1000e18);

// 4. Redeem collateral
dsce.redeemCollateral(WETH, 1 ether);

// 5. Liquidate user
dsce.liquidate(WETH, userToLiquidate, 2500e18);
```

---

## Testing Notes

* All tests are located in `test/` and use Forge’s cheatcodes and mainnet forking.
* Tests cover collateralization logic, edge cases, and liquidation flows.

```bash
forge test -vv
```

---

## Deployment

You can deploy using Forge scripts:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

---