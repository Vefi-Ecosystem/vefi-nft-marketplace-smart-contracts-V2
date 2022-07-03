pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';

library ActionHelpers {
  using Address for address;

  function _safeDeployCollection(
    address actionContract,
    string memory name,
    string memory symbol,
    address owner,
    uint256 maxSupply,
    uint256 mintStartTime,
    string memory metadataURI
  ) internal returns (address collectionId) {
    require(actionContract.isContract(), 'call_to_non_contract');
    (bool success, bytes memory data) = actionContract.call(
      abi.encodeWithSelector(
        bytes4(keccak256(bytes('string,string,address,uint256,uint256,string'))),
        name,
        symbol,
        owner,
        maxSupply,
        mintStartTime,
        metadataURI
      )
    );
    require(success, 'low_level_contract_call_failed');
    collectionId = abi.decode(data, (address));
  }
}
