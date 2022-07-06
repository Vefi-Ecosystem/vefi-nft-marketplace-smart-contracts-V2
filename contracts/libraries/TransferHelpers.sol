pragma solidity ^0.8.0;

library TransferHelpers {
  function _safeTransferEther(address to, uint256 amount) internal returns (bool success) {
    (success, ) = to.call{value: amount}(new bytes(0));
    require(success, 'failed to transfer ether');
  }
}
