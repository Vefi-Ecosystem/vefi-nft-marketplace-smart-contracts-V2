pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import './Collection.sol';
import './interfaces/ICollection.sol';
import './libraries/TransferHelpers.sol';

contract Actions is Ownable {
  event CollectionDeployed(address collectionId, string name, string symbol, address owner, uint256 mintStartTime, string metadataURI);

  event NFTCreated(address collection, address to, uint256 tokenId, string tokenURI);

  address[] public collections;

  function _deployCollection(
    string memory name_,
    string memory symbol_,
    address owner_,
    uint256 maxSupply_,
    uint256 mintStartTime_,
    string memory metadataURI_,
    uint256 maxBalance_,
    uint96 royaltyNumerator_
  ) external returns (address collection) {
    bytes memory _byteCode = abi.encodePacked(
      type(Collection).creationCode,
      abi.encode(name_, symbol_, owner_, maxSupply_, mintStartTime_, metadataURI_, maxBalance_, royaltyNumerator_)
    );
    bytes32 _salt = keccak256(abi.encode(name_, symbol_, owner_, block.timestamp, address(this)));

    assembly {
      collection := create2(0, add(_byteCode, 32), mload(_byteCode), _salt)
      if iszero(extcodesize(collection)) {
        revert(0, 0)
      }
    }
    collections.push(collection);
    emit CollectionDeployed(collection, name_, symbol_, owner_, mintStartTime_, metadataURI_);
  }

  function withdrawERC20(
    address token,
    address to,
    uint256 amount
  ) external onlyOwner {
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  function _mintNFT(
    address collection_,
    address to_,
    string memory tokenURI_
  ) external returns (uint256 tokenId) {
    tokenId = ICollection(collection_).mint(to_, tokenURI_);
    emit NFTCreated(collection_, to_, tokenId, tokenURI_);
  }

  function allCollections() external view returns (address[] memory) {
    return collections;
  }
}
