// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./mocks/MockPool.sol";
import "./mocks/MockPriceFeed.sol";

/// @title FixedOracle - Oracle LP avec Fair Pricing (SÉCURISÉ)
/// @notice Calcule le prix LP via l'invariant - RÉSISTANT À LA MANIPULATION
/// @dev Basé sur: https://blog.alphaventuredao.io/fair-lp-token-pricing/
contract FixedOracle {
    MockPriceFeed public priceFeed;

    constructor(address _priceFeed) {
        priceFeed = MockPriceFeed(_priceFeed);
    }

    /// @notice Calcule le prix d'un LP token (SÉCURISÉ)
    /// @dev Formule fair pricing: 2 * sqrt(k * price0 * price1) / totalSupply
    /// @dev k = reserve0 * reserve1 (invariant constant product)
    function getLPPrice(address pool) external view returns (uint256) {
        MockPool _pool = MockPool(pool);
        
        (uint256 reserve0, uint256 reserve1) = _pool.getReserves();
        address token0 = _pool.token0();
        address token1 = _pool.token1();
        uint256 totalSupply = _pool.totalSupply();

        uint256 price0 = priceFeed.getPrice(token0);
        uint256 price1 = priceFeed.getPrice(token1);

        // SÉCURISÉ: Le prix est basé sur l'invariant k
        // k reste constant lors des swaps (moins les fees)
        // Donc manipuler les réserves ne change pas significativement le prix
        uint256 k = reserve0 * reserve1;
        
        // fair_price = 2 * sqrt(k * price0 * price1) / totalSupply
        uint256 sqrtK = sqrt(k);
        uint256 sqrtPriceProduct = sqrt(price0 * price1);
        
        return (2 * sqrtK * sqrtPriceProduct) / totalSupply;
    }

    /// @notice Babylonian square root
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}