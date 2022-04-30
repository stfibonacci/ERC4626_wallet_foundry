// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import {ERC4626Wallet} from "../ERC4626Wallet.sol";
import {YearnStrategy} from "../YearnStrategy.sol";
import {GearboxYearnStrategy} from "../GearboxYearnStrategy.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC4626} from "solmate/test/utils/mocks/MockERC4626.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {IYVault} from "../interfaces/yearn/IYVault.sol";
import {ICreditAccount} from "../interfaces/gearbox/ICreditAccount.sol";
import {ICreditFilter} from "../interfaces/gearbox/ICreditFilter.sol";
import {ICreditManager} from "../interfaces/gearbox/ICreditManager.sol";

contract ERC4626WalletTest is DSTest {
    ERC4626Wallet wallet;
    MockERC20 asset;
    MockERC4626 yearnStrategy;
    MockERC4626 gearboxStrategy;
    uint256 assets;

    function setUp() public {
        asset = new MockERC20("Mock Dai", "MDAI", 18);
        wallet = new ERC4626Wallet(asset, "ERC4626 DAI Wallet", "wDAI");
        assets = 100 * 1e18;

        yearnStrategy = new MockERC4626(asset, "Yearn DAI", "gyDAI1");
        gearboxStrategy = new MockERC4626(
            asset,
            "Gearbox Leverage Yearn DAI",
            "gyDAI2"
        );
        wallet.addStrategy(yearnStrategy);
        wallet.addStrategy(gearboxStrategy);
    }

    function testExample() public {
        assertTrue(true);
    }

    function testCheckStrategy1() public {
        assertEq(address(wallet.getStrategy(0)), address(yearnStrategy));
    }

    function testCheckStrategy2() public {
        assertEq(address(wallet.getStrategy(1)), address(gearboxStrategy));
    }

    function testDepositWithdraw() public {
        asset.mint(address(this), assets);
        asset.approve(address(wallet), assets);

        wallet.deposit(assets, address(this));

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), assets);
        assertEq(
            wallet.convertToAssets(wallet.balanceOf(address(this))),
            assets
        );
        assertEq(wallet.availableAssets(), assets);
        assertEq(wallet.totalStrategyAssets(), 0);
        assertEq(wallet.totalAssets(), assets);

        wallet.withdraw(assets, address(this), address(this));

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), 0);
        assertEq(wallet.convertToAssets(wallet.balanceOf(address(this))), 0);
        assertEq(wallet.availableAssets(), 0);
        assertEq(wallet.totalStrategyAssets(), 0);
        assertEq(wallet.totalAssets(), 0);
    }

    function testDepositRedeem() public {
        asset.mint(address(this), assets);
        asset.approve(address(wallet), assets);

        wallet.deposit(assets, address(this));

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(
            wallet.convertToAssets(wallet.balanceOf(address(this))),
            assets
        );
        assertEq(wallet.availableAssets(), assets);
        assertEq(wallet.totalStrategyAssets(), 0);
        assertEq(wallet.totalAssets(), assets);

        wallet.redeem(assets, address(this), address(this));

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), 0);
        assertEq(wallet.convertToAssets(wallet.balanceOf(address(this))), 0);
        assertEq(wallet.availableAssets(), 0);
        assertEq(wallet.totalStrategyAssets(), 0);
        assertEq(wallet.totalAssets(), 0);
    }

    function testFailDepositWithNotEnoughApproval() public {
        asset.mint(address(this), assets / 2);
        asset.approve(address(wallet), assets / 2);

        wallet.deposit(assets, address(this));
    }

    function testFailWithdrawWithNotEnoughBalance() public {
        asset.mint(address(this), assets / 2);
        asset.approve(address(wallet), assets / 2);

        wallet.deposit(assets / 2, address(this));

        wallet.withdraw(assets, address(this), address(this));
    }

    function testFailRedeemWithNotEnoughBalance() public {
        asset.mint(address(this), assets / 2);
        asset.approve(address(wallet), assets / 2);

        wallet.deposit(assets / 2, address(this));

        wallet.redeem(assets, address(this), address(this));
    }

    function testFailWithdrawWithNoBalance() public {
        wallet.withdraw(assets, address(this), address(this));
    }

    function testFailRedeemWithNoBalance() public {
        wallet.redeem(assets, address(this), address(this));
    }

    function testFailDepositWithNoApproval() public {
        wallet.deposit(assets, address(this));
    }

    function testDepositWithdrawSingleStrategy() public {
        asset.mint(address(this), assets);
        asset.approve(address(wallet), assets);
        wallet.deposit(assets, address(this));

        wallet.depositIntoStrategy(0, assets);

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), assets);
        assertEq(
            wallet.convertToAssets(wallet.balanceOf(address(this))),
            assets
        );
        assertEq(wallet.availableAssets(), 0);
        assertEq(wallet.totalStrategyAssets(), assets);
        assertEq(wallet.totalAssets(), assets);

        wallet.withdrawFromStrategy(0, assets);

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), assets);
        assertEq(
            wallet.convertToAssets(wallet.balanceOf(address(this))),
            assets
        );
        assertEq(wallet.availableAssets(), assets);
        assertEq(wallet.totalStrategyAssets(), 0);
        assertEq(wallet.totalAssets(), assets);
    }

    function testDepositWithdrawMultipleStrategy() public {
        asset.mint(address(this), assets);
        asset.approve(address(wallet), assets);
        wallet.deposit(assets, address(this));

        wallet.depositIntoStrategy(0, assets / 2);

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), assets);
        assertEq(
            wallet.convertToAssets(wallet.balanceOf(address(this))),
            assets
        );
        assertEq(wallet.availableAssets(), assets / 2);
        assertEq(wallet.totalStrategyAssets(), assets / 2);
        assertEq(wallet.totalAssets(), assets);

        wallet.depositIntoStrategy(1, assets / 2);

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), assets);
        assertEq(
            wallet.convertToAssets(wallet.balanceOf(address(this))),
            assets
        );
        assertEq(wallet.availableAssets(), 0);
        assertEq(wallet.totalStrategyAssets(), assets);
        assertEq(wallet.totalAssets(), assets);

        wallet.withdrawFromStrategy(0, assets / 2);

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), assets);
        assertEq(
            wallet.convertToAssets(wallet.balanceOf(address(this))),
            assets
        );
        assertEq(wallet.availableAssets(), assets / 2);
        assertEq(wallet.totalStrategyAssets(), assets / 2);
        assertEq(wallet.totalAssets(), assets);

        wallet.withdrawFromStrategy(1, assets / 2);

        assertEq(wallet.convertToAssets(10**wallet.decimals()), 1e18);
        assertEq(wallet.balanceOf(address(this)), assets);
        assertEq(
            wallet.convertToAssets(wallet.balanceOf(address(this))),
            assets
        );
        assertEq(wallet.availableAssets(), assets);
        assertEq(wallet.totalStrategyAssets(), 0);
        assertEq(wallet.totalAssets(), assets);
    }

    function testFailDepositIntoStrategyWithNotEnoughBalance() public {
        asset.mint(address(this), assets / 2);
        asset.approve(address(wallet), assets / 2);

        wallet.deposit(assets / 2, address(this));

        wallet.depositIntoStrategy(0, assets);
    }

    function testFailWithdrawFromStrategyWithNotEnoughBalance() public {
        asset.mint(address(this), assets / 2);
        asset.approve(address(wallet), assets / 2);

        wallet.deposit(assets, address(this));

        wallet.depositIntoStrategy(0, assets / 2);
        wallet.withdrawFromStrategy(0, assets);
    }

    function testFailDepositIntoStrategyWithNoBalance() public {
        wallet.depositIntoStrategy(0, assets);
    }

    function testFailWithdrawFromStrategyWithNoBalance() public {
        wallet.withdrawFromStrategy(0, assets);
    }
}
