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

import {MockCurve} from "./MockCurve.sol";

contract CustomCurveHookTest is Test, Deployers {
    CustomCurveHook hook;

    function setUp() public {
        deployFreshManagerAndRouters();

        hook = CustomCurveHook(
            address(
                uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
            )
        );

        // Deploy mocked Custom Curve contract
        address customCurveContract = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        deployCodeTo("MockCurve.sol:MockCurve", abi.encode(), customCurveContract);

        deployCodeTo("CustomCurveHook.sol:CustomCurveHook", abi.encode(manager, customCurveContract), address(hook));

        deployMintAndApprove2Currencies();
        vm.label(Currency.unwrap(currency0), "currency0");
        vm.label(Currency.unwrap(currency1), "currency1");
    }
}
