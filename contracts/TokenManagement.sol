// SPDX-License-Identifier: MIT
pragma solidity  >=0.4.22 <0.8.0;

import "./Ownable.sol";
import "./StateStorage.sol";
import "./CappedToken.sol";

contract TokenManagement is Ownable {
modifier yearHasPassed() {
//for testin one minutes, normal one years
require(now > lastDistribution + 1 minutes);
_;
}
modifier isPercentage(uint256 _percentage) {
require(10000 > _percentage && _percentage > 0);
_;
}
//Linked Contracts
address public cappedToken;
//Public Variables
//Linear Reduction Factor
uint256 public lrf;
//time of last distribution
uint256 public lastDistribution;
constructor(uint256 _lrf) isPercentage(_lrf) public {
lrf = _lrf;
//So that initial distribution can be done instantly after deploying
lastDistribution = now - 1; // years;
}
//EU Commission mints new EUA's every year
function annualDistribution() onlyOwner yearHasPassed public {
CappedToken(cappedToken).mintStates();
CappedToken(cappedToken).reduceCAP(lrf);
lastDistribution = now;
}
function setNewLRF(uint256 _lrf) onlyOwner isPercentage(_lrf) public {
    lrf = _lrf;
}
function setCappedToken(address _address) onlyOwner public {
cappedToken = _address;
}
//To get the current timestamp of the blockchain
function getNowTimestamp() view public returns(uint256) {
return now;
}
}