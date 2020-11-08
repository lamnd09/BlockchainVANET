// SPDX-License-Identifier: MIT
pragma solidity  >=0.4.22 <0.8.0;

import "./Ownable.sol";
import "./CappedToken.sol";
import "./StateStorage.sol";

contract Auction is Ownable {
    modifier largerThan(uint256 _x, uint256 _y) {
    require(_x > _y);
    _;
}

modifier hasEnded() {
    require(now > endingTime);
    _;
}

modifier hasNotEnded() {
    require(now < endingTime);
    _;
}
modifier notCancelled() {
    require(!cancelled);
    _;
}

modifier notFinalized() {
    require(!finalized);
    _;
}

modifier isIncrementalStep(uint256 _bid) {
require(_bid % incrementalSteps == 0);
_;
}
modifier onlyState() {
require(msg.sender == state);
_;
}
modifier isVerified() {
require(stateStorage.isVerified(msg.sender));
_;
}
//Linked Contracts
CappedToken public token;
StateStorage public stateStorage;
//Public Variables
address public state;
address public highestBidder;
uint256 public startingPrice;
uint256 public currentBid;
uint256 public incrementalSteps;
uint256 public endingTime;
bool public cancelled;
bool public finalized;

constructor(uint256 _startingPrice, uint256 _daysDuration,
address _state, address _token, address _storage, uint256 _incrementalSteps)
public {
startingPrice = _startingPrice;
currentBid = 0;
incrementalSteps = _incrementalSteps;
endingTime = now + _daysDuration * 1 days;
state = _state;
token = CappedToken(_token);
stateStorage = StateStorage(_storage);
cancelled = false;
finalized = false;
}
function bid() public payable largerThan(msg.value, currentBid)
largerThan(msg.value, startingPrice - 1)
isIncrementalStep(msg.value)
isVerified()
hasNotEnded {
address oldBidder = highestBidder;
uint256 oldBid = currentBid;
highestBidder = msg.sender;
currentBid = msg.value;
if (oldBidder != address(0)) {
oldBidder.transfer(oldBid);
}
}
function cancel() public onlyState notCancelled hasNotEnded {
cancelled = true;
highestBidder.transfer(currentBid);
token.transfer(state, getAmountEUA());
}
function getAmountEUA() public view returns(uint256) {
return token.balanceOf(this);
}
function finalize() public notCancelled notFinalized hasEnded {
finalized = true;
state.transfer(currentBid);
if (highestBidder != address(0)) {
token.transfer(highestBidder, getAmountEUA());
} else {
token.transfer(state, getAmountEUA());
}
}
function timeNow() public view returns(uint256) {
return now;
}
}
contract AuctionHouse is Ownable {
//Linked Contracts
address public cappedToken;
StateStorage public stateStorage;
//Public Variables
address[] public auctions;
constructor(address _token, address _stateStorage) public {
cappedToken = _token;
stateStorage = StateStorage(_stateStorage);
}

modifier isState() {
require(stateStorage.isState(msg.sender));
_;
}
event NewAuction(address _auction, address indexed _state);
function createAuction(uint256 _startingPrice, uint256 _daysDuration,
uint256 _incrementalSteps)
public isState {
Auction a = new Auction(_startingPrice, _daysDuration, msg.sender,
cappedToken, stateStorage, _incrementalSteps);
auctions.push(a);
emit NewAuction(a, msg.sender);
}
function getAuctionsLength() public view returns(uint256) {
return auctions.length;
}
}