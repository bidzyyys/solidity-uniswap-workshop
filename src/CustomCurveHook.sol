// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../lib/uniswap-hooks/src/base/BaseHook.sol";

import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "../lib/uniswap-hooks/lib/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "../lib/uniswap-hooks/lib/v4-core/src/types/PoolOperation.sol";

contract CustomCurveHook is BaseHook {
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    uint24 public swapNumber = 1;

    error MaxNumberReached();

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function beforeSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        bytes calldata
    )
        external
        view
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (swapNumber >= 10) {
            revert MaxNumberReached();
        }
        return (
            BaseHook.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            0
        );
    }

    function afterSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        swapNumber++;
        return (BaseHook.afterSwap.selector, 0);
    }
}
