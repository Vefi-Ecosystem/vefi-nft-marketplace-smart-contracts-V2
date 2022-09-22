pragma solidity ^0.8.0;

contract Staking {
  struct Stake {
    mapping(address => uint256[]) stakedTokens;
    uint256 totalMarketValue;
  }

  mapping(address => Stake) public userStakes;
}
