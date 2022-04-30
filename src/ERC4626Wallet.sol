// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract ERC4626Wallet is ERC4626, Ownable {
    // 0-comp 1-yearn 2-aave 3-curve
    ERC4626[] public strategies;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {}

    function afterDeposit(uint256, uint256) internal override {}

    function beforeWithdraw(uint256 assets, uint256) internal override {
        withdrawAsset(assets);
    }

    function withdrawAsset(uint256 assets) internal {
        // Check available wallet balance
        uint256 _availableAssets = availableAssets();

        if (assets > _availableAssets) {
            uint256 _missingAssets = assets - _availableAssets;
            _withdrawMissingAssets(_missingAssets);
        }
    }

    //////////// withdraw logic from strategies if there is not enough fund in the wallet //////////////
    function _withdrawMissingAssets(uint256 assets) internal {
        uint256 missingAssets = assets;
        uint256 strategyAssets;

        for (uint256 i = 0; i < strategies.length; i++) {
            ERC4626 strategy = strategies[i];

            strategyAssets = strategy.totalAssets();

            if (strategyAssets > 0) {
                if (assets > strategyAssets) {
                    strategy.withdraw(
                        strategyAssets,
                        address(this),
                        address(this)
                    );
                    assets = missingAssets - strategyAssets;
                } else {
                    strategy.withdraw(assets, address(this), address(this));
                }
            }

            if (missingAssets == 0) break;
        }
    }

    function depositIntoStrategy(uint256 _strategyIndex, uint256 assets)
        external
    {
        ERC4626 strategy = strategies[_strategyIndex];
        require(
            address(strategy) != address(0),
            "strategy cannot be zero address"
        );

        asset.approve(address(strategy), assets);
        strategy.deposit(assets, address(this));
    }

    function withdrawFromStrategy(uint256 _strategyIndex, uint256 assets)
        external
        onlyOwner
    {
        ERC4626 strategy = strategies[_strategyIndex];

        strategy.withdraw(assets, address(this), address(this));
    }

    function addStrategy(ERC4626 _newStrategy)
        external
        onlyOwner
        returns (ERC4626)
    {
        ERC4626 strategy = _newStrategy;
        strategies.push(strategy);
        return strategy;
    }

    function getStrategy(uint256 strategyIndex) public view returns (ERC4626) {
        ERC4626 strategy = strategies[strategyIndex];
        return strategy;
    }

    function getStrategies() external view returns (ERC4626[] memory) {
        return strategies;
    }

    /////////////////   BALANCES   /////////////////

    // total available asset balance in the wallet
    function availableAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function totalStrategyAssets() public view returns (uint256) {
        uint256 strategyTotal;
        for (uint256 i = 0; i < strategies.length; i++) {
            ERC4626 strategy = strategies[i];
            strategyTotal = strategyTotal + strategy.totalAssets();
        }
        return strategyTotal;
    }

    // Total wallet balance in asset
    function totalAssets() public view override returns (uint256) {
        return totalStrategyAssets() + availableAssets();
    }

    ///////////////////////////
}
