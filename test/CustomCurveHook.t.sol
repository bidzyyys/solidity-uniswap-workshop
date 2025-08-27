// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CustomCurveHook} from "../src/CustomCurveHook.sol";
import {Hooks} from "../lib/uniswap-hooks/lib/v4-core/src/libraries/Hooks.sol";
import {Currency} from "../lib/uniswap-hooks/lib/v4-core/src/types/Currency.sol";
import {Deployers} from "../lib/uniswap-hooks/lib/v4-core/test/utils/Deployers.sol";
import {IHooks} from "../lib/uniswap-hooks/lib/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "../lib/uniswap-hooks/lib/v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolSwapTest} from "../lib/uniswap-hooks/lib/v4-core/src/test/PoolSwapTest.sol";

contract CustomCurveHookTest is Test, Deployers {
    CustomCurveHook hook;

    function setUp() public {
        deployFreshManagerAndRouters();

        hook = CustomCurveHook(
            address(uint160(Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_FLAG))
        );

        deployCodeTo(
            "CustomCurveHook.sol:CustomCurveHook",
            abi.encode(manager),
            address(hook)
        );

        deployMintAndApprove2Currencies();
        vm.label(Currency.unwrap(currency0), "currency0");
        vm.label(Currency.unwrap(currency1), "currency1");
    }

    function test_swap_counter() public {
        (key, ) = initPoolAndAddLiquidity(
            currency0,
            currency1,
            IHooks(address(hook)),
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            SQRT_PRICE_1_1
        );

        // Number is 1 initially.
        assertEq(1, hook.swapNumber());

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        swapRouter.swap(key, SWAP_PARAMS, testSettings, ZERO_BYTES);

        // Number is 2 after the swap.
        assertEq(2, hook.swapNumber());
    }

    function test_10_swaps_reverts() public {
        (key, ) = initPoolAndAddLiquidity(
            currency0,
            currency1,
            IHooks(address(hook)),
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            SQRT_PRICE_1_1
        );

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        for (uint24 i = 0; i < 9; i++) {
            swapRouter.swap(key, SWAP_PARAMS, testSettings, ZERO_BYTES);
        }

        // Number is 10 after 10 swaps.
        assertEq(10, hook.swapNumber());

        // 10th swap should revert.
        vm.expectRevert();
        swapRouter.swap(key, SWAP_PARAMS, testSettings, ZERO_BYTES);

        // Check specific error.
        vm.prank(address(manager));
        vm.expectRevert(CustomCurveHook.MaxNumberReached.selector);
        hook.beforeSwap(address(this), key, SWAP_PARAMS, ZERO_BYTES);

        // Number is still 10 after the revert.
        assertEq(10, hook.swapNumber());
    }
}
