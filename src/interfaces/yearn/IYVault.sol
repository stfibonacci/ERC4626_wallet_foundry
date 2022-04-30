// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IYVault {
    function deposit(uint256) external;

    function withdraw(uint256) external;

    function pricePerShare() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}
