// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {IYVault} from "./interfaces/yearn/IYVault.sol";
import {ICreditAccount} from "./interfaces/gearbox/ICreditAccount.sol";
import {ICreditFilter} from "./interfaces/gearbox/ICreditFilter.sol";
import {ICreditManager} from "./interfaces/gearbox/ICreditManager.sol";

contract GearboxYearnStrategy is ERC4626, Ownable {
    address public manager;
    IYVault public yearnAdapter; // 0x403E98b110a4DC89da963394dC8518b5f0E2D5fB
    ICreditManager public creditManager; //0x777e23a2acb2fcbb35f6ccf98272d03c722ba6eb
    ICreditFilter public creditFilter;
    address public creditAccount;
    uint256 minInvestment = 1e21;
    uint256 public leverage; //200;

    constructor(
        ERC20 _asset,
        address _yearnAdapter,
        address _creditManager,
        uint256 _leverage
    ) ERC4626(_asset, "Gearbox Leverage Yearn DAI", "gyDAI") {
        manager = msg.sender;
        yearnAdapter = IYVault(_yearnAdapter);
        creditManager = ICreditManager(_creditManager);
        creditFilter = ICreditFilter(creditManager.creditFilter());
        leverage = _leverage;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only Manager");
        _;
    }

    function afterDeposit(uint256 assets, uint256) internal override {
        if (creditManager.hasOpenedCreditAccount(address(this))) {
            addCollateral(assets);
            borrowMore(assets);
        } else {
            openAccount(assets);
        }
        investToYearnWithLev();
    }

    function openAccount(uint256 assets) internal returns (address) {
        asset.approve(address(creditManager), type(uint256).max);
        creditManager.openCreditAccount(assets, address(this), leverage, 0);
        creditAccount = creditManager.creditAccounts(address(this));

        return creditAccount;
    }

    function closeAccount() internal {
        uint256 yAssets = yearnAdapter.balanceOf(creditAccount);
        if (yAssets > 0) withdrawFromYearn();

        creditManager.repayCreditAccount(address(this));
    }

    function addCollateral(uint256 assets) internal returns (uint256) {
        asset.approve(address(creditManager), type(uint256).max);
        creditManager.addCollateral(address(this), address(asset), assets);

        return assets;
    }

    function borrowMore(uint256 assets) internal returns (uint256) {
        uint256 borrowAmount = (leverage * assets) / 100;
        creditManager.increaseBorrowedAmount(borrowAmount);

        return borrowAmount;
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        //withdrawAsset(assets);
        // Check available wallet balance
        uint256 _availableAssets = availableAssets();

        if (assets > _availableAssets) {
            closeAccount();
            uint256 remainingBalance = availableAssets() - assets;
            if (remainingBalance > minInvestment) {
                afterDeposit(remainingBalance, shares);
            }
        }
    }

    function investToYearnWithLev() internal {
        uint256 _assets = asset.balanceOf(creditAccount);
        yearnAdapter.deposit(_assets);
    }

    function withdrawFromYearn() internal {
        uint256 yAssets = yearnAdapter.balanceOf(creditAccount);
        yearnAdapter.withdraw(yAssets);
    }

    function forceClose() external onlyManager {
        closeAccount();
    }

    function forceOpen() external onlyManager {
        uint256 _availableAssets = availableAssets();
        afterDeposit(_availableAssets, 0);
    }

    function getCreditAccount() public view returns (address) {
        return creditManager.creditAccounts(address(this));
    }

    function getHealthFactor() public view returns (uint256) {
        return
            creditFilter.calcCreditAccountHealthFactor(address(creditAccount));
    }

    function getBorrowedAmount() public view returns (uint256) {
        return ICreditAccount(creditAccount).borrowedAmount();
    }

    function getTotalValue() public view returns (uint256) {
        return creditFilter.calcTotalValue(address(creditAccount));
    }

    function getCollateralValue() public view returns (uint256) {
        if (creditManager.hasOpenedCreditAccount(address(this))) {
            uint256 totalValue = getTotalValue();
            //return ((totalValue * 100) / (leverage + 100));
            uint256 totalBorrwed = getBorrowedAmount();
            return ((totalValue - totalBorrwed) * 9999) / 10000;
        } else {
            return 0;
        }
    }

    // total available asset balance in the strategy contract
    function availableAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    // Total strategy balance in asset
    function totalAssets() public view override returns (uint256) {
        return availableAssets() + getCollateralValue();
    }
}
