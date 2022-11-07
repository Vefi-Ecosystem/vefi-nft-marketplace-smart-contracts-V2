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
    string memory metadataURI,
    uint256 maxBalance,
    uint96 royaltyNumerator
  ) internal returns (address collectionId) {
    require(actionContract.isContract(), 'call_to_non_contract');
    (bool success, bytes memory data) = actionContract.call(
      abi.encodeWithSelector(
        bytes4(keccak256(bytes('_deployCollection(string,string,address,uint256,uint256,string,uint256,uint96)'))),
        name,
        symbol,
        owner,
        maxSupply,
        mintStartTime,
        metadataURI,
        maxBalance,
        royaltyNumerator
      )
    );
    require(success, 'low_level_contract_call_failed');
    collectionId = abi.decode(data, (address));
  }

  function _safeMintNFT(
    address actionContract,
    address collection,
    address to,
    string memory tokenURI
  ) internal returns (uint256 nftId) {
    require(actionContract.isContract(), 'call_to_non_contract');
    (bool success, bytes memory data) = actionContract.call(
      abi.encodeWithSelector(bytes4(keccak256(bytes('_mintNFT(address,address,string)'))), collection, to, tokenURI)
    );
    require(success, 'low_level_contract_call_failed');
    nftId = abi.decode(data, (uint256));
  }
}
