// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {TransientStateLibrary} from "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";

contract YieldFlowDemoRouter is IUnlockCallback {
    using CurrencyLibrary for Currency;
    using TransientStateLibrary for IPoolManager;

    error NotPoolManager();
    error UnsupportedAction();
    error TokenPaymentFailed();

    enum Action {
        ModifyLiquidity,
        Swap
    }

    struct CallbackData {
        Action action;
        address payer;
        PoolKey key;
        ModifyLiquidityParams liquidityParams;
        SwapParams swapParams;
        bytes hookData;
    }

    IPoolManager public immutable manager;

    constructor(IPoolManager manager_) {
        manager = manager_;
    }

    receive() external payable {}

    function initialize(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24 tick) {
        return manager.initialize(key, sqrtPriceX96);
    }

    function modifyLiquidity(PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData)
        external
        payable
        returns (BalanceDelta delta)
    {
        CallbackData memory data = CallbackData({
            action: Action.ModifyLiquidity,
            payer: msg.sender,
            key: key,
            liquidityParams: params,
            swapParams: SwapParams({zeroForOne: false, amountSpecified: 0, sqrtPriceLimitX96: 0}),
            hookData: hookData
        });

        delta = abi.decode(manager.unlock(abi.encode(data)), (BalanceDelta));
        _refundNative(msg.sender);
    }

    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        payable
        returns (BalanceDelta delta)
    {
        CallbackData memory data = CallbackData({
            action: Action.Swap,
            payer: msg.sender,
            key: key,
            liquidityParams: ModifyLiquidityParams({tickLower: 0, tickUpper: 0, liquidityDelta: 0, salt: bytes32(0)}),
            swapParams: params,
            hookData: hookData
        });

        delta = abi.decode(manager.unlock(abi.encode(data)), (BalanceDelta));
        _refundNative(msg.sender);
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        if (msg.sender != address(manager)) revert NotPoolManager();

        CallbackData memory data = abi.decode(rawData, (CallbackData));
        BalanceDelta delta;

        if (data.action == Action.ModifyLiquidity) {
            (delta,) = manager.modifyLiquidity(data.key, data.liquidityParams, data.hookData);
        } else if (data.action == Action.Swap) {
            delta = manager.swap(data.key, data.swapParams, data.hookData);
        } else {
            revert UnsupportedAction();
        }

        _settleOpenDelta(data.key.currency0, data.payer);
        _settleOpenDelta(data.key.currency1, data.payer);

        return abi.encode(delta);
    }

    function _settleOpenDelta(Currency currency, address payer) internal {
        int256 delta = manager.currencyDelta(address(this), currency);

        if (delta < 0) {
            _pay(currency, payer, uint256(-delta));
        } else if (delta > 0) {
            manager.take(currency, payer, uint256(delta));
        }
    }

    function _pay(Currency currency, address payer, uint256 amount) internal {
        if (currency.isAddressZero()) {
            manager.settle{value: amount}();
            return;
        }

        manager.sync(currency);
        bool ok = IERC20Minimal(Currency.unwrap(currency)).transferFrom(payer, address(manager), amount);
        if (!ok) revert TokenPaymentFailed();
        manager.settle();
    }

    function _refundNative(address recipient) internal {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            CurrencyLibrary.ADDRESS_ZERO.transfer(recipient, balance);
        }
    }
}
