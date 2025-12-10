// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./mocks/MockPool.sol";
import "./mocks/MockPriceFeed.sol";

/// @title VulnerableOracle - Oracle LP naïf (VULNÉRABLE)
/// @notice Calcule le prix LP via somme des valeurs - MANIPULABLE
/// @dev C'est exactement cette logique qui a été exploitée sur Vicuna Finance
contract VulnerableOracle {
    MockPriceFeed public priceFeed;

    constructor(address _priceFeed) {
        priceFeed = MockPriceFeed(_priceFeed);
    }

    /// @notice Calcule le prix d'un LP token (VULNÉRABLE)
    /// @dev Formule naïve: (reserve0 * price0 + reserve1 * price1) / totalSupply
    /// @dev Cette formule est manipulable car elle dépend directement des réserves
    function getLPPrice(address pool) external view returns (uint256) {
        MockPool _pool = MockPool(pool);
        
        (uint256 reserve0, uint256 reserve1) = _pool.getReserves();
        address token0 = _pool.token0();
        address token1 = _pool.token1();
        uint256 totalSupply = _pool.totalSupply();

        uint256 price0 = priceFeed.getPrice(token0);
        uint256 price1 = priceFeed.getPrice(token1);

        // VULNÉRABLE: Le prix dépend directement des réserves
        // Un attaquant peut manipuler les réserves via un gros swap
        // puis utiliser ce prix gonflé comme collatéral
        uint256 totalValue = (reserve0 * price0) + (reserve1 * price1);
        
        return totalValue / totalSupply;
    }
}