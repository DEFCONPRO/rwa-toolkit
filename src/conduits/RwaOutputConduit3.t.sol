// SPDX-License-Identifier: AGPL-3.0-or-later
//
// RwaUrn.t.sol -- Tests for the Urn contract
//
// Copyright (C) 2020-2021 Lev Livnev <lev@liv.nev.org.uk>
// Copyright (C) 2021-2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.6.12;

import "forge-std/Test.sol";
import "ds-token/token.sol";
import "ds-math/math.sol";
import "ds-value/value.sol";

import {Vat} from "dss/vat.sol";
import {Jug} from "dss/jug.sol";
import {Spotter} from "dss/spot.sol";
import {Vow} from "dss/vow.sol";
import {GemJoin, DaiJoin} from "dss/join.sol";
import {Dai} from "dss/dai.sol";

import {RwaOutputConduit3} from "./RwaOutputConduit3.sol";

import {DssPsm} from "dss-psm/psm.sol";
import {AuthGemJoin5} from "dss-psm/join-5-auth.sol";

contract TestToken is DSToken {
    constructor(string memory symbol_, uint8 decimals_) public DSToken(symbol_) {
        decimals = decimals_;
    }
}

contract TestVat is Vat {
    function mint(address usr, uint256 rad) public {
        dai[usr] += rad;
    }
}

contract TestVow is Vow {
    constructor(
        address vat,
        address flapper,
        address flopper
    ) public Vow(vat, flapper, flopper) {}

    // Total deficit
    function Awe() public view returns (uint256) {
        return vat.sin(address(this));
    }

    // Total surplus
    function Joy() public view returns (uint256) {
        return vat.dai(address(this));
    }

    // Unqueued, pre-auction debt
    function Woe() public view returns (uint256) {
        return sub(sub(Awe(), Sin), Ash);
    }
}

contract TestUrn {
    function balance(address gem) public view returns (uint256) {
        return DSToken(gem).balanceOf(address(this));
    }
}

contract RwaOutputConduit3Test is Test, DSMath {
    address me;

    TestVat vat;
    Spotter spot;
    TestVow vow;
    DSValue pip;
    TestToken usdx;
    DaiJoin daiJoin;
    Dai dai;

    AuthGemJoin5 joinA;
    DssPsm psmA;
    RwaOutputConduit3 outputConduit;
    TestUrn testUrn;

    bytes32 constant ilk = "usdx";

    uint256 constant USDX_BASE_UNIT = 10**6;
    uint256 constant USDX_MINT_AMOUNT = 1000 * USDX_BASE_UNIT;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Mate(address indexed usr);
    event Hate(address indexed usr);
    event Push(address indexed to, uint256 wad);
    event File(bytes32 indexed what, address data);
    event Quit(address indexed quitTo, uint256 wad);

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10**9;
    }

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10**27;
    }

    function setUpMCDandPSM() internal {
        me = address(this);

        vat = new TestVat();
        vat = vat;

        spot = new Spotter(address(vat));
        vat.rely(address(spot));

        vow = new TestVow(address(vat), address(0), address(0));

        usdx = new TestToken("USDX", 6);
        usdx.mint(USDX_MINT_AMOUNT);

        vat.init(ilk);

        joinA = new AuthGemJoin5(address(vat), ilk, address(usdx));
        vat.rely(address(joinA));

        dai = new Dai(0);
        daiJoin = new DaiJoin(address(vat), address(dai));
        vat.rely(address(daiJoin));
        dai.rely(address(daiJoin));

        psmA = new DssPsm(address(joinA), address(daiJoin), address(vow));
        joinA.rely(address(psmA));
        joinA.deny(me);

        pip = new DSValue();
        pip.poke(bytes32(uint256(1 ether))); // Spot = $1

        spot.file(ilk, bytes32("pip"), address(pip));
        spot.file(ilk, bytes32("mat"), ray(1 ether));
        spot.poke(ilk);

        vat.file(ilk, "line", rad(1000 ether));
        vat.file("Line", rad(1000 ether));
    }

    function setUp() public {
        setUpMCDandPSM();

        testUrn = new TestUrn();
        outputConduit = new RwaOutputConduit3(address(psmA), address(testUrn));
        outputConduit.mate(me);
        outputConduit.file(bytes32("to"), me);

        usdx.approve(address(joinA));
        psmA.sellGem(me, USDX_MINT_AMOUNT);
    }

    function testSetWardAndEmitRelyOnDeploy() public {
        vm.expectEmit(true, false, false, false);
        emit Rely(address(this));

        RwaOutputConduit3 c = new RwaOutputConduit3(address(psmA), address(testUrn));

        assertEq(c.wards(address(this)), 1);
    }

    function testGiveUnlimitedApprovalToPsmDaiJoinOnDeploy() public {
        assertEq(dai.allowance(address(outputConduit), address(psmA)), type(uint256).max);
    }

    function testRelyDeny() public {
        assertEq(outputConduit.wards(address(0)), 0);

        vm.expectEmit(true, false, false, false);
        emit Rely(address(0));

        outputConduit.rely(address(0));

        assertEq(outputConduit.wards(address(0)), 1);

        vm.expectEmit(true, false, false, false);
        emit Deny(address(0));

        outputConduit.deny(address(0));

        assertEq(outputConduit.wards(address(0)), 0);
    }

    function testMateHate() public {
        assertEq(outputConduit.may(address(0)), 0);

        vm.expectEmit(true, false, false, false);
        emit Mate(address(0));

        outputConduit.mate(address(0));

        assertEq(outputConduit.may(address(0)), 1);

        vm.expectEmit(true, false, false, false);
        emit Hate(address(0));

        outputConduit.hate(address(0));

        assertEq(outputConduit.may(address(0)), 0);
    }

    function testFile() public {
        assertEq(outputConduit.quitTo(), address(testUrn));

        address quitToAddress = vm.addr(1);
        vm.expectEmit(true, true, false, false);
        emit File(bytes32("quitTo"), quitToAddress);

        outputConduit.file(bytes32("quitTo"), quitToAddress);

        assertEq(outputConduit.quitTo(), quitToAddress);

        address to = vm.addr(2);
        vm.expectEmit(true, true, false, false);
        emit File(bytes32("to"), to);

        outputConduit.file(bytes32("to"), to);

        assertEq(outputConduit.to(), to);
    }

    function testRevertOnFileUnrecognisedParam() public {
        vm.expectRevert("RwaOutputConduit3/unrecognised-param");
        outputConduit.file(bytes32("random"), address(0));
    }

    function testRevertOnFileQuitToZeroAddress() public {
        vm.expectRevert("RwaOutputConduit3/invalid-quit-to-address");
        outputConduit.file(bytes32("quitTo"), address(0));
    }

    function testRevertOnFileToAddressZeroAddress() public {
        vm.expectRevert("RwaOutputConduit3/invalid-to-address");
        outputConduit.file(bytes32("to"), address(0));
    }

    function testRevertOnUnauthorizedMethods() public {
        vm.startPrank(address(0));

        vm.expectRevert("RwaOutputConduit3/not-authorized");
        outputConduit.rely(address(0));

        vm.expectRevert("RwaOutputConduit3/not-authorized");
        outputConduit.deny(address(0));

        vm.expectRevert("RwaOutputConduit3/not-authorized");
        outputConduit.hate(address(0));

        vm.expectRevert("RwaOutputConduit3/not-authorized");
        outputConduit.mate(address(0));

        vm.expectRevert("RwaOutputConduit3/not-authorized");
        outputConduit.file(bytes32("quitTo"), address(0));
    }

    function testRevertOnNotMateMethods() public {
        vm.startPrank(address(0));

        vm.expectRevert("RwaOutputConduit3/not-mate");
        outputConduit.push();

        vm.expectRevert("RwaOutputConduit3/not-mate");
        outputConduit.quit();
    }

    function testPush() public {
        assertEq(usdx.balanceOf(me), 0);
        assertEq(usdx.balanceOf(address(outputConduit)), 0);
        assertEq(dai.balanceOf(address(me)), 1000 ether);

        dai.transfer(address(outputConduit), 500 ether);

        assertEq(dai.balanceOf(me), 500 ether);
        assertEq(dai.balanceOf(address(outputConduit)), 500 ether);

        vm.expectEmit(true, true, false, false);
        emit Push(address(me), 500 * USDX_BASE_UNIT);
        outputConduit.push();

        assertEq(usdx.balanceOf(address(me)), 500 * USDX_BASE_UNIT);
    }

    function testRevertOnInsufficientSwapGemAmount() public {
        assertEq(usdx.balanceOf(me), 0);
        assertEq(usdx.balanceOf(address(outputConduit)), 0);
        assertEq(dai.balanceOf(address(me)), 1000 ether);

        dai.transfer(address(outputConduit), 500);

        assertEq(dai.balanceOf(address(outputConduit)), 500);

        vm.expectRevert("RwaOutputConduit3/insufficient-swap-gem-amount");
        outputConduit.push();

        assertEq(dai.balanceOf(address(outputConduit)), 500);
    }

    function testRevertOnInsufficientGemAmountInPsm() private {
        dai.mint(me, 100 ether);

        assertEq(usdx.balanceOf(me), 0);
        assertEq(usdx.balanceOf(address(outputConduit)), 0);
        assertEq(dai.balanceOf(address(me)), 1100 ether);

        dai.transfer(address(outputConduit), 1100 ether);

        assertEq(dai.balanceOf(address(outputConduit)), 1100 ether);

        vat.mint(address(daiJoin), 1100 ether * 10**27);

        outputConduit.push();

        assertEq(dai.balanceOf(address(outputConduit)), 1100 ether);
    }

    function testQuit() public {
        assertEq(dai.balanceOf(outputConduit.quitTo()), 0);

        dai.transfer(address(outputConduit), 1000 ether);

        assertEq(outputConduit.quitTo(), address(testUrn));
        assertEq(dai.balanceOf(address(outputConduit)), 1000 ether);

        outputConduit.quit();

        assertEq(dai.balanceOf(outputConduit.quitTo()), 1000 ether);
    }
}
