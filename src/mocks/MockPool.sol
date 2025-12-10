// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title MockPool - Simule un pool AMM style Uniswap V2 / Beets
/// @notice Permet de manipuler les réserves pour démontrer l'attaque
contract MockPool {
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    
    address public token0;
    address public token1;

    constructor(
        address _token0,
        address _token1,
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 _totalSupply
    ) {
        token0 = _token0;
        token1 = _token1;
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        totalSupply = _totalSupply;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    /// @notice Simule un swap qui déséquilibre le pool
    /// @dev L'attaquant swap une grande quantité de token0 contre token1
    function simulateSwap(uint256 amountIn, bool zeroForOne) external {
        if (zeroForOne) {
            // Swap token0 -> token1 (ajoute reserve0, retire reserve1)
            uint256 amountOut = getAmountOut(amountIn, reserve0, reserve1);
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            // Swap token1 -> token0
            uint256 amountOut = getAmountOut(amountIn, reserve1, reserve0);
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }
    }

    /// @notice Calcul AMM constant product (x * y = k)
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    /// @notice Retourne le k (invariant) du pool
    function getK() external view returns (uint256) {
        return reserve0 * reserve1;
    }
}