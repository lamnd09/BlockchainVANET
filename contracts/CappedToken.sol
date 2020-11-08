// SPDX-License-Identifier: MIT
pragma solidity  >=0.4.22 <0.8.0;

import './Ownable.sol';
import "./MintableToken.sol";
import "./StateStorage.sol";
import "./Exchange.sol";
/**
* @title Capped token
* @dev Mintable token with a token cap.
*/
contract CappedToken is MintableToken {
    event Burn(address indexed burner, uint256 value);
    modifier onlyTokenManager() {
        require(msg.sender == tokenManager);
        _;
    }

    modifier exchangeSet() {
        require(exchange != address(0));
        _;
    }

    //Linked Contracts
    address public stateStorage;
    address public tokenManager;
    address public exchange;

    //Public Variables
    uint256 public cap;

    constructor(uint256 _cap, address _stateStorage, address _tokenManager) public {
        require(_cap > 0);
        cap = _cap;
        stateStorage = _stateStorage;
        tokenManager = _tokenManager;
    }

    function mintStates() onlyTokenManager public {
        uint256 _supply = totalSupply_;
        for (uint256 i = 0; i < StateStorage(stateStorage).getMemberStateLength(); i++) {
            //so no zero-value tx is created
            if (StateStorage(stateStorage).getMemberStateDistributionRatio(i) != 0) {
                mint(StateStorage(stateStorage).getMemberStateAddress(i), StateStorage(stateStorage).getMemberStateDistributionRatio(i) * (cap - _supply) / 10000);
                }
            }
    }

    function mint(address _to, uint256 _amount) virtual onlyTokenManager canMint internal override returns(bool) {
        require(totalSupply_.add(_amount) <= cap);
        return super.mint(_to, _amount);
    }

    function setTokenManager(address _address) onlyOwner public {
        tokenManager = _address;
    }

    function setExchange(address _address) onlyOwner public {
        exchange = _address;
    }

    //send EUA's to Exchange
    function sendToExchange(uint256 _amount) exchangeSet public {
        transfer(exchange, _amount);
        Exchange(exchange).depositEUA(_amount, msg.sender);
    }

    function reduceCAP(uint256 _lrf) onlyTokenManager public {
        cap = cap - (cap * _lrf / 10000);
    }

    function burn(uint256 _value) public {
        require(_value <= balances[msg.sender]);
        // no need to require value <= totalSupply, since that would imply the
        // sender's balance is greater than the totalSupply, which *should* be an assertion failure
        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply_ = totalSupply_.sub(_value);
        emit Burn(burner, _value);
        }
}