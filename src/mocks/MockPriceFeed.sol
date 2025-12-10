// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title MockPriceFeed - Simule un oracle Chainlink pour les prix des tokens
contract MockPriceFeed {
    mapping(address => uint256) public prices;

    /// @notice Configure le prix d'un token (en USD, 18 décimales)
    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    /// @notice Récupère le prix d'un token
    function getPrice(address token) external view returns (uint256) {
        require(prices[token] > 0, "Price not set");
        return prices[token];
    }
}