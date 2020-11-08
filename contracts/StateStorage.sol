// SPDX-License-Identifier: MIT
pragma solidity  >=0.4.22 <0.8.0;

import "./Ownable.sol";

contract StateStorage is Ownable {
    modifier onlyVerifiedTrader() {
        require(verifiedUsers[msg.sender].isCompany == false);
        require(verifiedUsers[msg.sender].isVerified == true);
        _;
    }
    modifier onlyVerifiedCompany() {
        require(verifiedUsers[msg.sender].isCompany == true);
        require(verifiedUsers[msg.sender].isVerified == true);
        _;
    }
    modifier onlyState(address _address) {
        require(isState(_address));
        _;
    }
    modifier onlyApplicationState(address _userAddress) {
        require(isState(msg.sender));
        require(verifiedUsers[_userAddress].stateAddress == msg.sender);
        _;
    }
    //total distributionRatio sums up to 100%
    modifier sumIsHundredPercent(uint256[] memory _distributionRatio) {
        uint256 percent = 0;
        for (uint256 i = 0; i < _distributionRatio.length; i++) {
        percent += _distributionRatio[i];
        }
        require(percent == 10000);
        _;
    }
    //argument array has same length as memberStates
    modifier arrayLengthIsCorrect(uint256[] memory _distributionRatio) {
        require(_distributionRatio.length == memberStates.length);
        _;
    }
    struct State {
        bytes32 name;
        address stateAddress;
        uint256 distributionRatio;
        uint256 VAT;
    }
    struct KYC {
        address stateAddress;
        //true if Company, false if Trader
        bool isCompany;
        bool isVerified;
        string idHash;
    }

    //Public Variables
    State[] public memberStates;
    mapping(address => KYC) public verifiedUsers;
    event NewApplication(address _user, address indexed _state);

    //For dev purposes, can be deleted
    constructor() {
    
        //Germany as a test member state which gets the full distributionRatio and has 20% VAT
        State memory newState = State("Germany", 0x00010270Fe7FaD6dc2c7a5FC19bD1fca8306363a, 10000, 2000);
        memberStates.push(newState);

        //Test Verified Trader in Germany
        KYC memory trader = KYC(0x00010270Fe7FaD6dc2c7a5FC19bD1fca8306363a, false, true, "abc");
        verifiedUsers[0x23B1F3B731470B4979F84bd2B1722683b2CbF4a7] = trader;

        //Test Verified Company in Germany
        KYC memory company = KYC(0x00010270Fe7FaD6dc2c7a5FC19bD1fca8306363a, true, true, "abc");
        verifiedUsers[0x56384e06754e292D37A45940AB2630A0F1F04941] = company;
    }

    function getMemberStatesLength() public view returns(uint256) {
        return memberStates.length;
    }

    //0 distributionRatio because total can not exceed 100% - own function for distributionRatio
    function addState(bytes32 _name, address _stateAddress, uint256 _VAT) onlyOwner public {
        State memory newState = State(_name, _stateAddress, 0, _VAT);
        memberStates.push(newState);
    }

    //setDistributionRatio for Allocation of EUA's
    function setDistributionRatio(uint256[] memory _distributionRatio)
    onlyOwner
    sumIsHundredPercent(_distributionRatio)
    arrayLengthIsCorrect(_distributionRatio) public {

        for (uint256 i; i < memberStates.length; i++) {
            memberStates[i].distributionRatio = _distributionRatio[i];
        }
    }

    function isState(address _address) public view returns(bool) {
        for (uint256 i; i < memberStates.length; i++) {
            if (memberStates[i].stateAddress == _address) {
            return true;
            }
        }
    return false;
    }

    //Functions for KYC
    function applyForKYC(address _stateAddress, bool _isCompany, string memory _idHash)
    onlyState(_stateAddress) public {
        KYC memory application = KYC(_stateAddress, _isCompany, false, _idHash);
        verifiedUsers[msg.sender] = application;
        emit NewApplication(msg.sender, _stateAddress);
    }

    function verifyKYC(address _userAddress) onlyApplicationState(_userAddress) public {
        verifiedUsers[_userAddress].isVerified = true;
    }
    function getMemberStateLength() public view returns(uint256) {
        return memberStates.length;
    }
    function getMemberStateAddress(uint256 _i) public view returns(address) {
        return memberStates[_i].stateAddress;
    }
    function getMemberStateDistributionRatio(uint256 _i) public view returns(uint256) {
        return memberStates[_i].distributionRatio;
    }
    function getVATofMemberState(address _state) external view returns(uint256) {
        for (uint256 i = 0; i < memberStates.length; i++) { 
            if (memberStates[i].stateAddress == _state) {
                return memberStates[i].VAT;
            }   
        }
    }
    function getStateOfUser(address _user) external view returns(address) {
        return verifiedUsers[_user].stateAddress;
    }
    function isVerified(address _userAddress) public view returns(bool) {
        return verifiedUsers[_userAddress].isVerified;
    }
}