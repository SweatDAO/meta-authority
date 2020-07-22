/// MockDebtAuctionHouse.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
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

pragma solidity ^0.6.7;

import "./Logging.sol";

abstract contract CDPEngineLike {
    function transferInternalCoins(address,address,uint) virtual external;
    function createUnbackedDebt(address,address,uint) virtual external;
}
abstract contract TokenLike {
    function mint(address,uint) virtual external;
}
abstract contract AccountingEngineLike {
    function totalOnAuctionDebt() virtual public returns (uint);
    function cancelAuctionedDebtWithSurplus(uint) virtual external;
}

/*
   This thing creates protocol tokens on demand in return for system coins
*/

contract MockDebtAuctionHouse is Logging {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address account) external emitLog isAuthorized {
      authorizedAccounts[account] = 1;
    }
    function removeAuthorization(address account) external emitLog isAuthorized {
      authorizedAccounts[account] = 0;
    }
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "MockDebtAuctionHouse/account-not-authorized");
        _;
    }

    // --- Data ---
    struct Bid {
        uint256 bidAmount;
        uint256 amountToSell;
        address highBidder;
        uint48  bidExpiry;
        uint48  auctionDeadline;
    }

    mapping (uint => Bid) public bids;

    CDPEngineLike public cdpEngine;
    TokenLike public protocolToken;
    AccountingEngineLike public accountingEngine;

    uint256  constant ONE = 1.00E18;
    uint256  public   bidDecrease = 1.05E18;
    uint256  public   amountSoldIncrease = 1.50E18;
    uint48   public   bidDuration = 3 hours;
    uint48   public   totalAuctionLength = 2 days;
    uint256  public   auctionsStarted = 0;
    // Accumulator for all debt auctions currently not settled
    uint256  public   activeDebtAuctions;
    uint256  public   contractEnabled;

    bytes32 public constant AUCTION_HOUSE_TYPE = bytes32("DEBT");

    // --- Events ---
    event StartAuction(
      uint256 id,
      uint256 amountToSell,
      uint256 initialBid,
      address indexed incomeReceiver
    );

    // --- Init ---
    constructor(address cdpEngine_, address protocolToken_) public {
        authorizedAccounts[msg.sender] = 1;
        cdpEngine = CDPEngineLike(cdpEngine_);
        protocolToken = TokenLike(protocolToken_);
        contractEnabled = 1;
    }

    // --- Math ---
    function addUint48(uint48 x, uint48 y) internal pure returns (uint48 z) {
        require((z = x + y) >= x);
    }
    function addUint256(uint256 x, uint256 y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function subtract(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function minimum(uint x, uint y) internal pure returns (uint z) {
        if (x > y) { z = y; } else { z = x; }
    }

    // --- Admin ---
    function modifyParameters(bytes32 parameter, uint data) external emitLog isAuthorized {
        if (parameter == "bidDecrease") bidDecrease = data;
        else if (parameter == "amountSoldIncrease") amountSoldIncrease = data;
        else if (parameter == "bidDuration") bidDuration = uint48(data);
        else if (parameter == "totalAuctionLength") totalAuctionLength = uint48(data);
        else revert("MockDebtAuctionHouse/modify-unrecognized-param");
    }
    function modifyParameters(bytes32 parameter, address addr) external emitLog isAuthorized {
        require(contractEnabled == 1, "MockDebtAuctionHouse/contract-not-enabled");
        if (parameter == "protocolToken") protocolToken = TokenLike(addr);
        else if (parameter == "accountingEngine") accountingEngine = AccountingEngineLike(addr);
        else revert("MockDebtAuctionHouse/modify-unrecognized-param");
    }

    // --- Auction ---
    function startAuction(
        address incomeReceiver,
        uint amountToSell,
        uint initialBid
    ) external isAuthorized returns (uint id) {
        require(contractEnabled == 1, "MockDebtAuctionHouse/contract-not-enabled");
        require(auctionsStarted < uint(-1), "MockDebtAuctionHouse/overflow");
        id = ++auctionsStarted;

        bids[id].bidAmount = initialBid;
        bids[id].amountToSell = amountToSell;
        bids[id].highBidder = incomeReceiver;
        bids[id].auctionDeadline = addUint48(uint48(now), totalAuctionLength);

        activeDebtAuctions = addUint256(activeDebtAuctions, 1);

        emit StartAuction(id, amountToSell, initialBid, incomeReceiver);
    }
    function restartAuction(uint id) external emitLog {
        require(bids[id].auctionDeadline < now, "MockDebtAuctionHouse/not-finished");
        require(bids[id].bidExpiry == 0, "MockDebtAuctionHouse/bid-already-placed");
        bids[id].amountToSell = multiply(amountSoldIncrease, bids[id].amountToSell) / ONE;
        bids[id].auctionDeadline = addUint48(uint48(now), totalAuctionLength);
    }
    function decreaseSoldAmount(uint id, uint amountToBuy, uint bid) external emitLog {
        require(contractEnabled == 1, "MockDebtAuctionHouse/contract-not-enabled");
        require(bids[id].highBidder != address(0), "MockDebtAuctionHouse/high-bidder-not-set");
        require(bids[id].bidExpiry > now || bids[id].bidExpiry == 0, "MockDebtAuctionHouse/bid-already-expired");
        require(bids[id].auctionDeadline > now, "MockDebtAuctionHouse/auction-already-expired");

        require(bid == bids[id].bidAmount, "MockDebtAuctionHouse/not-matching-bid");
        require(amountToBuy <  bids[id].amountToSell, "MockDebtAuctionHouse/amount-bought-not-lower");
        require(multiply(bidDecrease, amountToBuy) <= multiply(bids[id].amountToSell, ONE), "MockDebtAuctionHouse/insufficient-decrease");

        cdpEngine.transferInternalCoins(msg.sender, bids[id].highBidder, bid);

        // on first bid submitted, clear as much totalOnAuctionDebt as possible
        if (bids[id].bidExpiry == 0) {
            uint totalOnAuctionDebt = AccountingEngineLike(bids[id].highBidder).totalOnAuctionDebt();
            AccountingEngineLike(bids[id].highBidder).cancelAuctionedDebtWithSurplus(minimum(bid, totalOnAuctionDebt));
        }

        bids[id].highBidder = msg.sender;
        bids[id].amountToSell = amountToBuy;
        bids[id].bidExpiry = addUint48(uint48(now), bidDuration);
    }
    function settleAuction(uint id) external emitLog {
        require(contractEnabled == 1, "MockDebtAuctionHouse/not-live");
        require(bids[id].bidExpiry != 0 && (bids[id].bidExpiry < now || bids[id].auctionDeadline < now), "MockDebtAuctionHouse/not-finished");
        protocolToken.mint(bids[id].highBidder, bids[id].amountToSell);
        activeDebtAuctions = subtract(activeDebtAuctions, 1);
        delete bids[id];
    }

    // --- Shutdown ---
    function disableContract() external emitLog isAuthorized {
        contractEnabled = 0;
        accountingEngine = AccountingEngineLike(msg.sender);
    }
    function terminateAuctionPrematurely(uint id) external emitLog {
        require(contractEnabled == 0, "MockDebtAuctionHouse/contract-still-enabled");
        require(bids[id].highBidder != address(0), "MockDebtAuctionHouse/high-bidder-not-set");
        cdpEngine.createUnbackedDebt(address(accountingEngine), bids[id].highBidder, bids[id].bidAmount);
        activeDebtAuctions = subtract(activeDebtAuctions, 1);
        delete bids[id];
    }
}
