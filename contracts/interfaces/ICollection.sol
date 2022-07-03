pragma solidity ^0.8.0;

interface ICollection {
  function maxSupply() external view returns (uint256);

  function mintStartTime() external view returns (uint256);

  function minterRole() external view returns (bytes32);

  function royaltySetterRole() external view returns (bytes32);

  function royaltyNumerator() external view returns (uint96);
}
