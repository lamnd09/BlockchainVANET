// SPDX-License-Identifier: MIT
pragma solidity  >=0.4.22 <0.8.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./CappedToken.sol";
import "./StateStorage.sol";

contract Exchange is Ownable {
using SafeMath for uint256;
//###################
//######MODIFIER#####
//###################
modifier sufficientETH(uint256 _ETH) {
require(_ETH > 0 && balanceETHfromAddress[msg.sender] >= _ETH);
_;
}
modifier sufficientEUA(uint256 _EUA) {
require(_EUA > 0 && balanceEUAfromAddress[msg.sender] >= _EUA);
_;
}
modifier onlyTokenContract() {
require(msg.sender == tokenAddress);
_;
}
modifier isVerified() {
require(stateStorage.isVerified(msg.sender));
_;
}
//##########################
//######STRUCTS############
//###########################
struct Order {
uint256 price;
address maker;
uint256 volume;
}
//##########################
//######PUBLIC VARIABLES#####
//###########################
mapping(address => uint256) public balanceETHfromAddress;
mapping(address => uint256) public balanceEUAfromAddress;
Order[] public buyBook;
Order[] public sellBook;
//Linked Contracts
CappedToken public token;
StateStorage public stateStorage;
//Public Variables
address public tokenAddress;
uint256 public maxPriceBuy;
uint256 public minPriceSell;
uint256 public lowestActiveBuyId;
uint256 public lowestActiveSellId;
//##########################
//######EVENTS##############
//###########################
event Withdraw(address _address, uint256 _ETH, uint256 _timestamp);
event Deposit(address _address, uint256 _ETH, uint256 _timestamp);
event DepositEUA(address _address, uint256 _amountEUA, uint256 _timestamp);
event WithdrawEUA(address _address, uint256 _amountEUA, uint256 _timestamp);
event VATReverseCharge(address _address, uint256 _ETH, uint256 _timestamp);
//###################
//#####FUNCTIONS#####
//###################
constructor(address _token, address _stateStorage) public {
tokenAddress = _token;
token = CappedToken(_token);
stateStorage = StateStorage(_stateStorage);
maxPriceBuy = 0;
minPriceSell = 9999999999;
lowestActiveBuyId = 0;
lowestActiveSellId = 0;
}
function depositETH() external payable {
address depositAddress = msg.sender;
uint256 _WEI = msg.value;
balanceETHfromAddress[depositAddress] = balanceETHfromAddress[depositAddress]
.add(_WEI);
emit Deposit(depositAddress, _WEI, now);
}
function withdrawETH(uint256 _WEI) external sufficientETH(_WEI) {
address withdrawAddress = msg.sender;
balanceETHfromAddress[withdrawAddress] = balanceETHfromAddress[withdrawAddress]
.sub(_WEI);
withdrawAddress.transfer(_WEI);
emit Withdraw(withdrawAddress, _WEI, now);
}
function depositEUA(uint256 _amountEUA, address _sender) external onlyTokenContract {
require(balanceEUAfromAddress[_sender] + _amountEUA
>= balanceEUAfromAddress[_sender]);
// Credit the DEX token balance for the callinging address with the transferred amount
balanceEUAfromAddress[_sender] = balanceEUAfromAddress[_sender].add(_amountEUA);
emit DepositEUA(_sender, _amountEUA, now);
}
function withdrawEUA(uint256 _amountEUA) external sufficientEUA(_amountEUA) {
balanceEUAfromAddress[msg.sender] = balanceEUAfromAddress[msg.sender]
.sub(_amountEUA);
token.transfer(msg.sender, _amountEUA);
emit WithdrawEUA(msg.sender, _amountEUA, now);
}
function buyOrder(uint256 _price, uint256 _volume) external
sufficientETH(_price * _volume) isVerified() {
uint availableETH = _price.mul(_volume);
uint valueTx;
uint tax;
uint possibleVolume;
uint sellEther;
uint taxPrice;
address stateAddress = stateStorage.getStateOfUser(msg.sender);
uint VATofState = stateStorage.getVATofMemberState(stateAddress);
balanceETHfromAddress[msg.sender] = balanceETHfromAddress[msg.sender]
.sub(availableETH);
//First check if it can match sell order
if (_price >= minPriceSell) {
for (uint256 i = lowestActiveSellId; i < sellBook.length && availableETH > _price;
i++) {
if (sellBook[i].price != 0 &&
sellBook[i].price <= _price &&
sellBook[i].volume > 0) {
//check for VAT reverse Charge mechanism
if (stateAddress == stateStorage.getStateOfUser(sellBook[i].maker)) {
//Sell Order can be filled completly
if (availableETH >=
sellBook[i].volume.mul(addVAT(sellBook[i].price, VATofState))) {
valueTx = sellBook[i].volume.mul(sellBook[i].price);
availableETH = availableETH.sub(addVAT(valueTx, VATofState));
balanceETHfromAddress[sellBook[i].maker] =
balanceETHfromAddress[sellBook[i].maker].add(valueTx);
balanceEUAfromAddress[msg.sender] =
balanceEUAfromAddress[msg.sender].add(sellBook[i].volume);
//send VAT directly to state
stateAddress.transfer(valueTx.mul(VATofState).div(10000));
emit VATReverseCharge(msg.sender, valueTx.mul(VATofState).div(10000), now);
//sell Order has no remaining volume
delete sellBook[i];
}
//Sell order can only be filled partially
else {
taxPrice = addVAT(sellBook[i].price, VATofState);
possibleVolume = availableETH.div(taxPrice);
sellEther = possibleVolume.mul(sellBook[i].price);
tax = availableETH.sub(sellEther);
balanceETHfromAddress[sellBook[i].maker] =
balanceETHfromAddress[sellBook[i].maker].add(sellEther);
balanceEUAfromAddress[msg.sender] =
balanceEUAfromAddress[msg.sender].add(possibleVolume);
//sell order loses volume of buyOrder
sellBook[i].volume = sellBook[i].volume.sub(possibleVolume);
stateAddress.transfer(tax);
emit VATReverseCharge(msg.sender, tax, now);
availableETH = 0;
}
} else {
//Sell Order can be filled completly
if (availableETH >= sellBook[i].volume.mul(sellBook[i].price)) {
valueTx = sellBook[i].volume.mul(sellBook[i].price);
availableETH = availableETH.sub(valueTx);
balanceETHfromAddress[sellBook[i].maker] =
balanceETHfromAddress[sellBook[i].maker].add(valueTx);
balanceEUAfromAddress[msg.sender] =
balanceEUAfromAddress[msg.sender].add(sellBook[i].volume);
//sell Order has no remaining volume
delete sellBook[i];
}
//Sell Order can only be filled partially
else {
balanceETHfromAddress[sellBook[i].maker] =
balanceETHfromAddress[sellBook[i].maker].add(availableETH);
balanceEUAfromAddress[msg.sender] =
balanceEUAfromAddress[msg.sender]
.add(availableETH.div(sellBook[i].price));
//sell order loses volume of buyOrder
sellBook[i].volume =
sellBook[i].volume.sub(availableETH.div(sellBook[i].price));
availableETH = 0;
}
}
}
}
if (availableETH > _price) {
//There should no sell orders with minPriceSell be available anymore
minPriceSell = findLowestSellOrder();
addToBuyBook(_price, msg.sender, (availableETH.div(_price)));
}
} else {
addToBuyBook(_price, msg.sender, _volume);
}
}
function sellOrder(uint256 _price, uint256 _volume) external sufficientEUA(_volume)
isVerified() {
uint256 volume = _volume;
uint256 possibleVolume;
uint256 tax;
uint256 taxPrice;
address stateAddress = stateStorage.getStateOfUser(msg.sender);
uint256 VATofState = stateStorage.getVATofMemberState(stateAddress);
uint256 valueTx;
balanceEUAfromAddress[msg.sender] = balanceEUAfromAddress[msg.sender].sub(_volume);
//First check if it can match sell order
if (_price <= maxPriceBuy) {
for (uint256 i = lowestActiveBuyId; i < buyBook.length && volume > 0; i++) {
if (buyBook[i].price != 0 && buyBook[i].price >= _price
&& buyBook[i].volume > 0) {
//check for VAT reverse Charge mechanism
if (stateAddress == stateStorage.getStateOfUser(buyBook[i].maker)) {
//Buy Order can be filled completly
if (_volume.mul(addVAT(_price, VATofState)) >=
buyBook[i].volume.mul(buyBook[i].price)) {
valueTx = buyBook[i].volume.mul(buyBook[i].price);
taxPrice = addVAT(_price, VATofState);
possibleVolume = valueTx.div(taxPrice);
balanceEUAfromAddress[buyBook[i].maker] =
balanceEUAfromAddress[buyBook[i].maker].add(possibleVolume);
balanceETHfromAddress[msg.sender] =
balanceETHfromAddress[msg.sender]
.add(_price.mul(possibleVolume));
tax = valueTx.sub(_price.mul(possibleVolume));
//send VAT directly to state
stateAddress.transfer(tax);
emit VATReverseCharge(buyBook[i].maker, tax, now);
//remove EUA's from this order
volume = volume.sub(possibleVolume);
//sell Order has no remaining volume
delete buyBook[i];
}
//Buy order can only be filled partially
else {
valueTx = _price.mul(volume);
tax = (valueTx.mul(VATofState)).div(10000);
balanceEUAfromAddress[buyBook[i].maker] =
balanceEUAfromAddress[buyBook[i].maker].add(volume);
balanceETHfromAddress[msg.sender] =
balanceETHfromAddress[msg.sender].add(valueTx);
//sell order loses volume of buyOrder
buyBook[i].volume =
buyBook[i].volume
.sub(valueTx.add(tax).div(buyBook[i].price));
if (valueTx.add(tax) % buyBook[i].price != 0) {
buyBook[i].volume = buyBook[i].volume.sub(1);
}
volume = 0;
stateAddress.transfer(tax);
emit VATReverseCharge(buyBook[i].maker, tax, now);
}
} else {
//Buy Order can be filled completly
if (volume > buyBook[i].volume) {
valueTx = buyBook[i].volume.mul(buyBook[i].price);
volume = volume.sub(buyBook[i].volume);
balanceEUAfromAddress[buyBook[i].maker] =
balanceEUAfromAddress[buyBook[i].maker].add(buyBook[i].volume);
balanceETHfromAddress[msg.sender] =
balanceETHfromAddress[msg.sender].add(valueTx);
//sell Order has no remaining volume
delete buyBook[i];
}
//Buy Order can only be filled partially
else {
balanceEUAfromAddress[buyBook[i].maker] =
balanceEUAfromAddress[buyBook[i].maker].add(volume);
balanceETHfromAddress[msg.sender] =
balanceETHfromAddress[msg.sender]
.add(buyBook[i].price.mul(volume));
//buy order loses volume of sell Order
buyBook[i].volume = buyBook[i].volume.sub(volume);
volume = 0;
}
}
}
}
if (volume > 0) {
//There should no sell orders with minPriceSell be available anymore
maxPriceBuy = findHighestBuyOrder();
addToSellBook(_price, msg.sender, volume);
}
} else {
addToSellBook(_price, msg.sender, _volume);
}
}
function addVAT(uint256 _price, uint256 _VAT) internal pure returns(uint256) {
uint256 base = 10000;
uint256 factor = base.add(_VAT);
uint256 price = _price.mul(factor);
price = price.div(base);
return price;
}
function addToBuyBook(uint256 _price, address _maker, uint256 _volume) internal {
if (_price > maxPriceBuy) {
maxPriceBuy = _price;
}
Order memory order = Order(_price, _maker, _volume);
buyBook.push(order);
}
function addToSellBook(uint256 _price, address _maker, uint256 _volume) internal {
if (_price < minPriceSell) {
minPriceSell = _price;
}
Order memory order = Order(_price, _maker, _volume);
sellBook.push(order);
}
function findLowestSellOrder() internal view returns(uint256) {
uint256 price = 9999999999;
for (uint256 i = lowestActiveSellId; i < sellBook.length; i++) {
if (price > sellBook[i].price && sellBook[i].price != 0) {
price = sellBook[i].price;
}
}
return price;
}
function findHighestBuyOrder() internal view returns(uint256) {
uint256 price = 0;
for (uint256 i = lowestActiveBuyId; i < buyBook.length; i++) {
if (price < buyBook[i].price) {
price = buyBook[i].price;
}
}
return price;
}
}