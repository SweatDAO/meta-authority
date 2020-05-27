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

pragma solidity ^0.5.15;

import "ds-test/test.sol";

import "./ProtocolTokenAuthority.sol";

contract DSAuthority {
  function canCall(address src, address dst, bytes4 sig) public view returns (bool) {}
}

contract Tester {
  ProtocolTokenAuthority authority;
  constructor(ProtocolTokenAuthority authority_) public { authority = authority_; }
  function setRoot(address usr) public { authority.setRoot(usr); }
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

contract ProtocolTokenAuthorityTest is DSTest {
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

  function testRely() public {
    assertEq(authority.authorizedAccounts(address(tester)), 0);
    authority.addAuthorization(address(tester));
    assertEq(authority.authorizedAccounts(address(tester)), 1);
  }

  function testFailRely() public {
    // tester is not authority's root, so cannot call rely
    tester.addAuthorization(address(tester));
  }

  function testDeny() public {
    authority.addAuthorization(address(tester));
    authority.removeAuthorization(address(tester));
    assertEq(authority.authorizedAccounts(address(tester)), 0);
  }

  function testFailDeny() public {
    // tester is not authority's root, so cannot call deny
    tester.removeAuthorization(address(tester));
  }

  function testMintAsRoot() public {
    tester.mint(address(this), 1);
  }

  function testMintAsWard() public {
    authority.addAuthorization(address(this));
    authority.setRoot(address(0));
    tester.mint(address(this), 1);
  }

  function testFailMintNotWardNotRoot() public {
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
