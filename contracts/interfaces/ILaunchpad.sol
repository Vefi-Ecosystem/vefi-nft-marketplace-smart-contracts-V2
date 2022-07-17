pragma solidity ^0.8.0;

interface ILaunchpad {
  function withdrawableBalance() external view returns (uint256);

  function actionSetterRole() external view returns (bytes32);

  function launchCreatorRole() external view returns (bytes32);

  function withdrawerRole() external view returns (bytes32);

  function finalizerRole() external view returns (bytes32);

  function launchIds(uint256) external view returns (bytes32);
}
