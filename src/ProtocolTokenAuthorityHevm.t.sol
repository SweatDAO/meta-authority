pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "./ProtocolTokenAuthority.sol";

import "./ProtocolTokenAuthority.sol";
import "./geb/MockDebtAuctionHouse.sol";
import {MockSurplusAuctionHouseOne} from "./geb/MockSurplusAuctionHouse.sol";

interface ERC20 {
    function setAuthority(address whom) external;
    function setOwner(address whom) external;
    function owner() external returns(address);
    function authority() external returns(address);
    function balanceOf( address who ) external view returns (uint value);
    function mint(address usr, uint256 wad) external;
    function burn(address usr, uint256 wad) external;
    function burn(uint256 wad) external;
    function stop() external;
    function approve(address whom, uint256 wad) external returns (bool);
    function transfer(address whom, uint256 wad) external returns (bool);
}

contract User {
    ERC20 protocolToken;
    ProtocolTokenBurner tokenBurner;

    constructor(ERC20 protocolToken_, ProtocolTokenBurner tokenBurner_) public {
        protocolToken = protocolToken_;
        tokenBurner = tokenBurner_;
    }

    function doApprove(address whom, uint256 wad) external returns (bool) {
        protocolToken.approve(whom, wad);
    }

    function doMint(uint256 wad) external {
        protocolToken.mint(address(this), wad);
    }

    function doBurn(uint256 wad) external {
        protocolToken.burn(wad);
    }

    function doBurn(address whom, uint256 wad) external {
        protocolToken.burn(whom, wad);
    }

    function burnProtocolBurner() external {
        tokenBurner.burn(address(protocolToken));
    }
}

abstract contract ProtocolTokenBurner {
    function burn(address protocolToken) virtual external;
}

contract ProtocolTokenAuthorityTest {
    // Test with this:
    // It uses the Multisig as the caller
    // dapp build
    // DAPP_TEST_TIMESTAMP=$(seth block latest timestamp) DAPP_TEST_NUMBER=$(seth block latest number) DAPP_TEST_ADDRESS=0x8EE7D9235e01e6B42345120b5d270bdB763624C7 hevm dapp-test --rpc=$ETH_RPC_URL --json-file=out/dapp.sol.json

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
    ERC20 protocolToken;
    ProtocolTokenBurner tokenBurner;
    User user1;
    User user2;
    ProtocolTokenAuthority auth;

    function setUp() public {
        IS_TEST = true;
        SUPPRESS_SETUP_WARNING = true;  // totally unused by anything

        protocolToken = ERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
        tokenBurner = ProtocolTokenBurner(0x69076e44a9C70a67D5b79d95795Aba299083c275);
        user1 = new User(protocolToken, tokenBurner);
        user2 = new User(protocolToken, tokenBurner);

        auth = new ProtocolTokenAuthority();
        protocolToken.setAuthority(address(auth));
        protocolToken.setOwner(address(0));
    }

    function testCanChangeAuthority() public {
        ProtocolTokenAuthority newAuth = new ProtocolTokenAuthority();
        protocolToken.setAuthority(address(newAuth));
        assertTrue(ProtocolTokenAuthority(protocolToken.authority()) == newAuth);
    }

    function testCanChangeOwner() public {
        protocolToken.setOwner(msg.sender);
        assertTrue(protocolToken.owner() == msg.sender);
    }

    function testCanBurnOwn() public {
        assertTrue(ProtocolTokenAuthority(protocolToken.authority()) == auth);

        assertTrue(protocolToken.owner() == address(0));

        protocolToken.transfer(address(user1), 1);
        user1.doBurn(1);
    }

    function testCanBurnFromOwn() public {
        protocolToken.transfer(address(user1), 1);
        user1.doBurn(address(user1), 1);
    }

    function testCanBurnTokenBurner() public {
        assertEq(protocolToken.balanceOf(address(user1)), 0);

        uint256 tokenBurnerBalance = protocolToken.balanceOf(address(tokenBurner));
        assertTrue(tokenBurnerBalance > 0);

        user1.burnProtocolBurner();
        assertEq(protocolToken.balanceOf(address(tokenBurner)), 0);
    }

    function testFailNoApproveAndBurn() public {
        protocolToken.transfer(address(user1), 1);

        assertEq(protocolToken.balanceOf(address(user1)), 1);
        assertEq(protocolToken.balanceOf(address(user2)), 0);

        user2.doBurn(address(user1), 1);
    }

    function testFailNoMint() public {
        user1.doMint(1);
    }

    function testApproveAndBurn() public {
        protocolToken.transfer(address(user1), 1);

        assertEq(protocolToken.balanceOf(address(user1)), 1);
        assertEq(protocolToken.balanceOf(address(user2)), 0);

        user1.doApprove(address(user2), 1);
        user2.doBurn(address(user1), 1);

        assertEq(protocolToken.balanceOf(address(user1)), 0);
        assertEq(protocolToken.balanceOf(address(user2)), 0);
    }

    function testFullProtocolTokenAuthTest() public {
        //update the authority
        //this works because HEVM allows us to set the caller address
        protocolToken.setAuthority(address(auth));
        assertTrue(address(protocolToken.authority()) == address(auth));
        protocolToken.setOwner(address(0));
        assertTrue(address(protocolToken.owner()) == address(0));

        //get the balance of this contract for some asserts
        uint balance = protocolToken.balanceOf(address(this));

        //test that we are allowed to mint
        protocolToken.mint(address(this), 10);
        assertEq(balance + 10, protocolToken.balanceOf(address(this)));

        //test that we are allowed to burn
        protocolToken.burn(address(this), 1);
        assertEq(balance + 9, protocolToken.balanceOf(address(this)));

        //create a debtAuctionHouse
        MockDebtAuctionHouse debtAuctionHouse = new MockDebtAuctionHouse(address(this), address(protocolToken));
        auth.addAuthorization(address(debtAuctionHouse));

        //call debtAuctionHouse.startAuction() and debtAuctionHouse.settleAuction() which will in turn test the protocolToken.mint() function
        debtAuctionHouse.startAuction(address(this), 1, 1);
        debtAuctionHouse.settleAuction(1);

        //create a surplus auction
        MockSurplusAuctionHouseOne surplusAuctionHouse = new MockSurplusAuctionHouseOne(address(this), address(protocolToken));
        auth.addAuthorization(address(debtAuctionHouse));

        //call surplusAuctionHouse.startAuction() which will in turn test the protocolToken.burn() function
        surplusAuctionHouse.startAuction(1, 1);
        debtAuctionHouse.settleAuction(1);
    }
}
