pragma solidity ^0.5.15;

import "ds-test/test.sol";
import "./ProtocolTokenAuthority.sol";

import "./ProtocolTokenAuthority.sol";
import "./DebtAuctionHouse.sol";
import {SurplusAuctionHouse} from "./SurplusAuctionHouse.sol";

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

contract ProtocolTokenBurner {
    function burn(address protocolToken) external;
}

contract ProtocolTokenAuthorityTest is DSTest {
    // Test with this:
    // It uses the Multisig as the caller
    // dapp build
    // DAPP_TEST_TIMESTAMP=$(seth block latest timestamp) DAPP_TEST_NUMBER=$(seth block latest number) DAPP_TEST_ADDRESS=0x8EE7D9235e01e6B42345120b5d270bdB763624C7 hevm dapp-test --rpc=$ETH_RPC_URL --json-file=out/dapp.sol.json

    ERC20 protocolToken;
    ProtocolTokenBurner tokenBurner;
    User user1;
    User user2;
    ProtocolTokenAuthority auth;

    function setUp() public {
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

    function testCanBurnPit() public {
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

    function testFullMetaAuthTest() public {
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

        //create a flopper
        Flopper flop = new Flopper(address(this), address(protocolToken));
        auth.rely(address(flop));

        //call flop.kick() and flop.deal() which will in turn test the protocolToken.mint() function
        flop.kick(address(this), 1, 1);
        flop.deal(1);

        //create a flapper
        // SurplusAuctionHouse flap = new SurplusAuctionHouse(address(this), address(protocolToken));
        // auth.rely(address(flop));

        // TODO
        //call flap.kick() which will in turn test the protocolToken.burn() function
        // flap.kick(1);
        // flop.deal(1);
    }
}
