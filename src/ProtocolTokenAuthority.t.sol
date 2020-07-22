// Copyright (C) 2019 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./ProtocolTokenAuthority.sol";

contract DSAuthority {
  function canCall(address src, address dst, bytes4 sig) public view returns (bool) {}
}

contract Tester {
  ProtocolTokenAuthority authority;
  constructor(ProtocolTokenAuthority authority_) public { authority = authority_; }
  function setRoot(address usr) public { authority.setRoot(usr); }
  function setOwner(address usr) public { authority.setOwner(usr); }
  function addAuthorization(address usr) public { authority.addAuthorization(usr); }
  function removeAuthorization(address usr) public { authority.removeAuthorization(usr); }

  modifier auth {
    require(authority.canCall(msg.sender, address(this), msg.sig));
    _;
  }

  function mint(address usr, uint256 wad) external auth {}
  function burn(uint256 wad) external auth {}
  function burn(address usr, uint256 wad) external auth {}
  function notMintOrBurn() auth public {}
}

contract ProtocolTokenAuthorityTest {
  // --- DS Test Content ---
  event eventListener          (address target, bool exact);
  event logs                   (bytes);
  event log_bytes32            (bytes32);
  event log_named_address      (bytes32 key, address val);
  event log_named_bytes32      (bytes32 key, bytes32 val);
  event log_named_decimal_int  (bytes32 key, int val, uint decimals);
  event log_named_decimal_uint (bytes32 key, uint val, uint decimals);
  event log_named_int          (bytes32 key, int val);
  event log_named_uint         (bytes32 key, uint val);

  bool public IS_TEST;
  bool public failed;
  bool SUPPRESS_SETUP_WARNING;  // hack for solc pure restriction warning

  function fail() internal {
      failed = true;
  }

  function expectEventsExact(address target) internal {
      emit eventListener(target, true);
  }

  modifier logs_gas() {
      uint startGas = gasleft();
      _;
      uint endGas = gasleft();
      emit log_named_uint("gas", startGas - endGas);
  }

  function assertTrue(bool condition) internal {
      if (!condition) {
          emit log_bytes32("Assertion failed");
          fail();
      }
  }

  function assertEq(address a, address b) internal {
      if (a != b) {
          emit log_bytes32("Error: Wrong `address' value");
          emit log_named_address("  Expected", b);
          emit log_named_address("    Actual", a);
          fail();
      }
  }

  function assertEq32(bytes32 a, bytes32 b) internal {
      assertEq(a, b);
  }

  function assertEq(bytes32 a, bytes32 b) internal {
      if (a != b) {
          emit log_bytes32("Error: Wrong `bytes32' value");
          emit log_named_bytes32("  Expected", b);
          emit log_named_bytes32("    Actual", a);
          fail();
      }
  }

  function assertEqDecimal(int a, int b, uint decimals) internal {
      if (a != b) {
          emit log_bytes32("Error: Wrong fixed-point decimal");
          emit log_named_decimal_int("  Expected", b, decimals);
          emit log_named_decimal_int("    Actual", a, decimals);
          fail();
      }
  }

  function assertEqDecimal(uint a, uint b, uint decimals) internal {
      if (a != b) {
          emit log_bytes32("Error: Wrong fixed-point decimal");
          emit log_named_decimal_uint("  Expected", b, decimals);
          emit log_named_decimal_uint("    Actual", a, decimals);
          fail();
      }
  }

  function assertEq(int a, int b) internal {
      if (a != b) {
          emit log_bytes32("Error: Wrong `int' value");
          emit log_named_int("  Expected", b);
          emit log_named_int("    Actual", a);
          fail();
      }
  }

  function assertEq(uint a, uint b) internal {
      if (a != b) {
          emit log_bytes32("Error: Wrong `uint' value");
          emit log_named_uint("  Expected", b);
          emit log_named_uint("    Actual", a);
          fail();
      }
  }

  function assertEq0(bytes memory a, bytes memory b) internal {
      bool ok = true;

      if (a.length == b.length) {
          for (uint i = 0; i < a.length; i++) {
              if (a[i] != b[i]) {
                  ok = false;
              }
          }
      } else {
          ok = false;
      }

      if (!ok) {
          emit log_bytes32("Error: Wrong `bytes' value");
          emit log_named_bytes32("  Expected", "[cannot show `bytes' value]");
          emit log_named_bytes32("  Actual", "[cannot show `bytes' value]");
          fail();
      }
  }

  // --- Authority Content ---
  ProtocolTokenAuthority authority;
  Tester tester;

  function setUp() public {
    authority = new ProtocolTokenAuthority();
    tester = new Tester(authority);
  }

  function testSetRoot() public {
    assertTrue(authority.root() == address(this));
    authority.setRoot(address(tester));
    assertTrue(authority.root() == address(tester));
  }

  function testFailSetRoot() public {
    assertTrue(authority.root() != address(tester));
    tester.setRoot(address(tester));
  }

  function testFailSetRootAsOwner() public {
    authority.setOwner(address(tester));
    authority.setRoot(address(0));
    tester.setRoot(address(tester));
  }

  function testSetOwner() public {
    assertTrue(authority.owner() == address(0));
    authority.setOwner(address(tester));
    assertTrue(authority.owner() == address(tester));
    assertEq(authority.authorizedAccounts(address(tester)), 0);
  }

  function testFailSetOnwer() public {
    assertTrue(authority.owner() != address(tester));
    tester.setOwner(address(tester));
  }

  function testRemoveOwnerByOwner() public {
    authority.setOwner(address(tester));
    authority.setRoot(address(0));
    tester.setOwner(address(0));
    assertTrue(authority.owner() == address(0));
  }

  function testAddAuth() public {
    assertEq(authority.authorizedAccounts(address(tester)), 0);
    authority.addAuthorization(address(tester));
    assertEq(authority.authorizedAccounts(address(tester)), 1);
  }

  function testFailAddAuth() public {
    // tester is not authority's root, so cannot call rely
    tester.addAuthorization(address(tester));
  }

  function testAddAuthOwner() public {
    authority.setOwner(address(tester));
    tester.addAuthorization(address(tester));
    assertEq(authority.authorizedAccounts(address(tester)), 1);
  }

  function testRemoveAuth() public {
    authority.addAuthorization(address(tester));
    authority.removeAuthorization(address(tester));
    assertEq(authority.authorizedAccounts(address(tester)), 0);
  }

  function testFailRemoveAuth() public {
    // tester is not authority's root, so cannot call removeAuthorization
    tester.removeAuthorization(address(tester));
  }

  function testRemoveAuthOwner() public {
    authority.setOwner(address(tester));
    tester.addAuthorization(address(tester));
    tester.removeAuthorization(address(tester));
    assertEq(authority.authorizedAccounts(address(tester)), 0);
  }

  function testMintAsRoot() public {
    assertEq(authority.authorizedAccounts(address(this)), 0);
    tester.mint(address(this), 1);
  }

  function testMintAsOnwer() public {
    Tester owner = new Tester(authority);
    authority.setOwner(address(owner));
    authority.addAuthorization(address(owner));
    owner.mint(address(this), 1);
  }

  function testMintAsAuthorizedAccount() public {
    authority.addAuthorization(address(this));
    authority.setRoot(address(0));
    tester.mint(address(this), 1);
  }

  function testFailMintNotAuthedNotRootNotOwner() public {
    authority.setRoot(address(0));
    tester.mint(address(this), 1);
  }

  function testBurn() public {
    authority.addAuthorization(address(this));
    tester.burn(address(this), 1);
    authority.removeAuthorization(address(this));
    tester.burn(address(this), 1);
    tester.burn(1);
  }

  function testRootCanCallAnything() public {
    tester.notMintOrBurn();
  }
}
