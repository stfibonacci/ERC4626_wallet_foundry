// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {IYVault} from "./interfaces/yearn/IYVault.sol";

contract YearnStrategy is ERC4626, Ownable {
    address public manager;
    IYVault public yVault;

    constructor(ERC20 _asset, address _yVault)
        ERC4626(_asset, "Simple Yearn DAI", "syDAI")
    {
        manager = msg.sender;

        yVault = IYVault(_yVault);
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only Manager");
        _;
    }

    function afterDeposit(uint256 assets, uint256) internal override {
        investToYearn(assets);
    }

    function beforeWithdraw(uint256 assets, uint256) internal override {
        uint256 _availableAssets = availableAssets();

        if (assets > _availableAssets) {
            withdrawFromYearn(assets - _availableAssets);
        }
    }

    function withdrawFromYearn(uint256 assets) internal {
        uint256 yBalance = YTokenBalance();
        uint256 balanceInAsset = YTokenBalanceInAsset();
        require(balanceInAsset >= assets, "insufficient funds");
        uint256 amount = (yBalance * assets) / balanceInAsset;
        yVault.withdraw(amount);
    }

    function investToYearn(uint256 assets) internal {
        asset.approve(address(yVault), assets);
        yVault.deposit(assets);
    }

    function forceWithdraw() external onlyManager {
        uint256 yAssets = YTokenBalance();
        yVault.withdraw(yAssets);
    }

    function forceInvest() external onlyManager {
        uint256 _availableAssets = availableAssets();
        asset.approve(address(yVault), _availableAssets);
        yVault.deposit(_availableAssets);
    }

    function YTokenBalance() public view returns (uint256) {
        return yVault.balanceOf(address(this));
    }

    function YTokenBalanceInAsset() public view returns (uint256) {
        uint256 balance = YTokenBalance();
        if (balance > 0) {
            balance = (YTokenBalance() * yVault.pricePerShare()) / (1e18);
        }
        return balance;
    }

    function availableAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function totalAssets() public view override returns (uint256) {
        return availableAssets() + YTokenBalanceInAsset();
    }
}
