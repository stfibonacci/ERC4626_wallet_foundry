// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStrategy {
    function deposit(uint256, address) external;

    function withdraw(
        uint256,
        address,
        address
    ) external;

    function balanceOf() external view returns (uint256);

    function availableAssets(address) external view returns (uint256);

    function totalAssets() external view returns (uint256);
}
