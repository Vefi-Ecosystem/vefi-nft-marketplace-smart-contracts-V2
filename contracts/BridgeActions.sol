pragma solidity ^0.8.0;

import './WrappedCollection.sol';

contract BridgeActions {
  event WrappedCollectionDeployed(address collection, string name, string symbol, address owner, string metadataURI);

  function _deployWrappedCollection(
    string memory name,
    string memory symbol,
    string memory metadataURI,
    address wrapped
  ) private returns (address collectionId) {
    bytes memory bytecode = abi.encodePacked(
      type(WrappedCollection).creationCode,
      abi.encode(name, symbol, metadataURI)
    );
    bytes32 salt = keccak256(abi.encodePacked(name, symbol, wrapped, block.timestamp));
    assembly {
      collectionId := create2(0, add(bytecode, 32), mload(bytecode), salt)
      if iszero(extcodesize(collectionId)) {
        revert(0, 0)
      }
    }

    emit WrappedCollectionDeployed(collectionId, name, symbol, address(this), metadataURI);
  }
}
