pragma solidity ^0.8.0;

interface IBridge {
  function nextNonce(address) external returns (uint256);
}
