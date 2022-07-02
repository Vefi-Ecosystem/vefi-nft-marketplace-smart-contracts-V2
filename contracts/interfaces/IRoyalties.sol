pragma solidity ^0.8.0;

interface IRoyalties {
  function getRoyalty(address collectionId, uint256 tokenId) external view returns (address);

  function addRoyalty(
    address collectionId,
    uint256 tokenId,
    address originalMiner
  ) external returns (bool);
}
