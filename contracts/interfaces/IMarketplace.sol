pragma solidity ^0.8.0;

interface IMarketplace {
  function withdrawableBalance() external view returns (uint256);

  function withdrawerRole() external view returns (bytes32);

  function _offerIds(uint256) external view returns (bytes32);
}
