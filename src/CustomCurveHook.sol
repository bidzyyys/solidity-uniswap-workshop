// SPDX-License-Identifier: MIT

// Based on https://www.v4-by-example.org/hooks/custom-curve
pragma solidity ^0.8.24;

import "../lib/uniswap-hooks/src/base/BaseHook.sol";

import {
    toBeforeSwapDelta,
    BeforeSwapDelta,
    BeforeSwapDeltaLibrary
} from "../lib/uniswap-hooks/lib/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "../lib/uniswap-hooks/lib/v4-core/src/types/PoolOperation.sol";
import {Currency, CurrencyLibrary} from "../lib/uniswap-hooks/lib/v4-core/src/types/Currency.sol";
import {CurrencySettler} from "../lib/uniswap-hooks/src/utils/CurrencySettler.sol";
import {SafeCast} from "../lib/uniswap-hooks/lib/v4-core/src/libraries/SafeCast.sol";

contract CustomCurveHook is BaseHook {
    using CurrencyLibrary for Currency;
    using SafeCast for uint256;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true, // -- disable v4 liquidity with a revert -- //
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true, // -- Custom Curve Handler --  //
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true, // -- Enables Custom Curves --  //
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @dev Facilitate a custom curve via beforeSwap + return delta.
    /// @dev input tokens are taken from the PoolManager, creating a debt paid by the swapper.
    /// @dev output takens are transferred from the hook to the PoolManager, creating a credit claimed by the swapper.
    function beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        bool exactInput = params.amountSpecified < 0;
        (Currency specified, Currency unspecified) =
            (params.zeroForOne == exactInput) ? (key.currency0, key.currency1) : (key.currency1, key.currency0);

        uint256 specifiedAmount = exactInput ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
        uint256 unspecifiedAmount;
        BeforeSwapDelta returnDelta;
        if (exactInput) {
            // in exact-input swaps, the specified token is a debt that gets paid down by the swapper
            // the unspecified token is credited to the PoolManager, that is claimed by the swapper
            unspecifiedAmount = getAmountOutFromExactInput(specifiedAmount, specified, unspecified, params.zeroForOne);
            CurrencySettler.take(specified, poolManager, address(this), specifiedAmount, true);
            CurrencySettler.settle(unspecified, poolManager, address(this), unspecifiedAmount, true);

            returnDelta = toBeforeSwapDelta(specifiedAmount.toInt128(), -unspecifiedAmount.toInt128());
        } else {
            // exactOutput
            // in exact-output swaps, the unspecified token is a debt that gets paid down by the swapper
            // the specified token is credited to the PoolManager, that is claimed by the swapper
            unspecifiedAmount = getAmountInForExactOutput(specifiedAmount, unspecified, specified, params.zeroForOne);
            CurrencySettler.take(unspecified, poolManager, address(this), unspecifiedAmount, true);
            CurrencySettler.settle(specified, poolManager, address(this), specifiedAmount, true);

            returnDelta = toBeforeSwapDelta(-specifiedAmount.toInt128(), unspecifiedAmount.toInt128());
        }

        return (BaseHook.beforeSwap.selector, returnDelta, 0);
    }

    /// @notice No liquidity will be managed by v4 PoolManager
    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert("No v4 Liquidity allowed");
    }

    /// @notice Returns the amount of output tokens for an exact-input swap.
    function getAmountOutFromExactInput(uint256 amountIn, Currency, Currency, bool)
        internal
        pure
        returns (uint256 amountOut)
    {
        // in constant-sum curve, tokens trade exactly 1:1
        amountOut = amountIn;
    }

    /// @notice Returns the amount of input tokens for an exact-output swap.
    function getAmountInForExactOutput(uint256 amountOut, Currency, Currency, bool)
        internal
        pure
        returns (uint256 amountIn)
    {
        // in constant-sum curve, tokens trade exactly 1:1
        amountIn = amountOut;
    }

    /// @notice Add liquidity through the hook
    /// @dev Not production-ready, only serves an example of hook-owned liquidity
    function addLiquidity(PoolKey calldata key, uint256 amount0, uint256 amount1) external {
        poolManager.unlock(
            abi.encodeCall(this.handleAddLiquidity, (key.currency0, key.currency1, amount0, amount1, msg.sender))
        );
    }

    /// @dev Handle liquidity addition by taking tokens from the sender and claiming ERC6909 to the hook address
    function handleAddLiquidity(
        Currency currency0,
        Currency currency1,
        uint256 amount0,
        uint256 amount1,
        address sender
    ) external returns (bytes memory) {
        CurrencySettler.settle(currency0, poolManager, sender, amount0, false);
        CurrencySettler.take(currency0, poolManager, address(this), amount0, true);

        CurrencySettler.settle(currency1, poolManager, sender, amount1, false);
        CurrencySettler.take(currency1, poolManager, address(this), amount1, true);

        return abi.encode(amount0, amount1);
    }
}
