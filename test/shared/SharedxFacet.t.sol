// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Base.t.sol";
import {console} from "forge-std/console.sol";

contract SharedxFacetTest is Base {
    function setUp() public override {
        deployXDiamonds();
    }

    function test_sharedxFacet() public {
        console.log("sharedxFacet");
    }
}
