pragma solidity ^0.5.15;

import "ds-test/test.sol";
import "./MetaAuthority.sol";

import "./MetaAuthority.sol";
import "./flop.sol";
import {Flapper} from "./flap.sol";

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
    ERC20 meta;
    GemPit pit;

    constructor(ERC20 meta_, GemPit pit_) public {
        meta = meta_;
        pit = pit_;
    }

    function doApprove(address whom, uint256 wad) external returns (bool) {
        meta.approve(whom, wad);
    }

    function doMint(uint256 wad) external {
        meta.mint(address(this), wad);
    }

    function doBurn(uint256 wad) external {
        meta.burn(wad);
    }

    function doBurn(address whom, uint256 wad) external {
        meta.burn(whom, wad);
    }

    function burnPit() external {
        pit.burn(address(meta));
    }
}

contract GemPit {
    function burn(address gem) external;
}

contract MetaAuthorityTest is DSTest {
    // Test with this:
    // It uses the Multisig as the caller
    // dapp build
    // DAPP_TEST_TIMESTAMP=$(seth block latest timestamp) DAPP_TEST_NUMBER=$(seth block latest number) DAPP_TEST_ADDRESS=0x8EE7D9235e01e6B42345120b5d270bdB763624C7 hevm dapp-test --rpc=$ETH_RPC_URL --json-file=out/dapp.sol.json

    ERC20 meta;
    GemPit pit;
    User user1;
    User user2;
    MetaAuthority auth;

    function setUp() public {
        meta = ERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
        pit = GemPit(0x69076e44a9C70a67D5b79d95795Aba299083c275);
        user1 = new User(meta, pit);
        user2 = new User(meta, pit);

        auth = new MetaAuthority();
        meta.setAuthority(address(auth));
        meta.setOwner(address(0));
    }

    function testCanChangeAuthority() public {
        MetaAuthority newAuth = new MetaAuthority();
        meta.setAuthority(address(newAuth));
        assertTrue(MetaAuthority(meta.authority()) == newAuth);
    }

    function testCanChangeOwner() public {
        meta.setOwner(msg.sender);
        assertTrue(meta.owner() == msg.sender);
    }

    function testCanBurnOwn() public {
        assertTrue(MetaAuthority(meta.authority()) == auth);

        assertTrue(meta.owner() == address(0));

        meta.transfer(address(user1), 1);
        user1.doBurn(1);
    }

    function testCanBurnFromOwn() public {
        meta.transfer(address(user1), 1);
        user1.doBurn(address(user1), 1);
    }

    function testCanBurnPit() public {
        assertEq(meta.balanceOf(address(user1)), 0);

        uint256 pitBalance = meta.balanceOf(address(pit));
        assertTrue(pitBalance > 0);

        user1.burnPit();
        assertEq(meta.balanceOf(address(pit)), 0);
    }

    function testFailNoApproveAndBurn() public {
        meta.transfer(address(user1), 1);

        assertEq(meta.balanceOf(address(user1)), 1);
        assertEq(meta.balanceOf(address(user2)), 0);

        user2.doBurn(address(user1), 1);
    }

    function testFailNoMint() public {
        user1.doMint(1);
    }

    function testApproveAndBurn() public {
        meta.transfer(address(user1), 1);

        assertEq(meta.balanceOf(address(user1)), 1);
        assertEq(meta.balanceOf(address(user2)), 0);

        user1.doApprove(address(user2), 1);
        user2.doBurn(address(user1), 1);

        assertEq(meta.balanceOf(address(user1)), 0);
        assertEq(meta.balanceOf(address(user2)), 0);
    }

    function testFullMetaAuthTest() public {
        //update the authority
        //this works because HEVM allows us to set the caller address
        meta.setAuthority(address(auth));
        assertTrue(address(meta.authority()) == address(auth));
        meta.setOwner(address(0));
        assertTrue(address(meta.owner()) == address(0));

        //get the balance of this contract for some asserts
        uint balance = meta.balanceOf(address(this));

        //test that we are allowed to mint
        meta.mint(address(this), 10);
        assertEq(balance + 10, meta.balanceOf(address(this)));

        //test that we are allowed to burn
        meta.burn(address(this), 1);
        assertEq(balance + 9, meta.balanceOf(address(this)));

        //create a flopper
        Flopper flop = new Flopper(address(this), address(meta));
        auth.rely(address(flop));

        //call flop.kick() and flop.deal() which will in turn test the meta.mint() function
        flop.kick(address(this), 1, 1);
        flop.deal(1);

        //create a flapper
        // Flapper flap = new Flapper(address(this), address(meta));
        // auth.rely(address(flop));

        // TODO
        //call flap.kick() which will in turn test the meta.burn() function
        // flap.kick(1);
        // flop.deal(1);
    }
}
