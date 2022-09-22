pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import './libraries/ECDSAHelpers.sol';

contract Bridge is Ownable, IERC721Receiver {
  using SafeMath for uint256;
  using ECDSAHelpers for bytes32;
  using Address for address;

  mapping(address => mapping(uint256 => bool)) nonceUsed;
  mapping(address => uint256) nextNonce;
  mapping(address => address) wrappedCollections;

  uint256 chainId;
  uint256 bridgingFee;
  address action;

  event BridgeRequested(
    uint256 destinationChain,
    bytes signature,
    address collection,
    uint256 tokenId,
    address signer,
    uint256 nonce,
    string tokenURI
  );
  event Redeemed(
    uint256 destinationChain,
    bytes signature,
    address collection,
    uint256 tokenId,
    address signer,
    uint256 nonce,
    string tokenURI
  );

  constructor(
    uint256 _chainId,
    uint256 _bridgingFee,
    address _action
  ) {
    require(_action.isContract());
    chainId = _chainId;
    bridgingFee = _bridgingFee;
    action = _action;
  }

  function _deployWrappedCollection(
    string memory name,
    string memory symbol,
    string memory metadataURI,
    address collection
  ) private returns (address collectionId) {
    (bool success, bytes memory data) = action.call(
      abi.encodeWithSelector(
        bytes4(keccak256(bytes('_deployWrappedCollection(string,string,string,address)'))),
        name,
        symbol,
        metadataURI,
        collection
      )
    );
    require(success, 'low_level_contract_call_failed');
    collectionId = abi.decode(data, (address));
  }

  function _safeMintNFT(
    address collection,
    address to,
    string memory tokenURI,
    uint256 tId
  ) private returns (uint256 tokenId) {
    (bool success, bytes memory data) = collection.call(
      abi.encodeWithSelector(bytes4(keccak256(bytes('mint(address,string,uint256)'))), to, tokenURI, tId)
    );
    require(success);
    tokenId = abi.decode(data, (uint256));
  }

  function request(
    address collection,
    uint256 tokenId,
    uint256 destinationChain,
    uint256 nonce,
    bytes memory signature
  ) external payable {
    require(collection.isContract());
    require(msg.value >= bridgingFee);
    bytes32 messageHash = keccak256(abi.encodePacked(collection, tokenId, destinationChain, nonce));
    bytes32 prefixedHash = messageHash.prefixed();
    address recoveredSigner = prefixedHash.recover(signature);

    require(recoveredSigner == _msgSender());
    require(!nonceUsed[recoveredSigner][nonce]);
    require(IERC721(collection).isApprovedForAll(_msgSender(), address(this)));
    IERC721(collection).safeTransferFrom(recoveredSigner, address(this), tokenId);
    nonceUsed[recoveredSigner][nonce] = true;
    nextNonce[recoveredSigner] = nextNonce[recoveredSigner].add(1);

    string memory tokenURI = IERC721Metadata(collection).tokenURI(tokenId);
    emit BridgeRequested(destinationChain, signature, collection, tokenId, recoveredSigner, nonce, tokenURI);
  }

  function redeem(
    address collection,
    uint256 tokenId,
    uint256 nonce,
    bytes memory signature,
    string memory tokenURI
  ) external {
    bytes32 messageHash = keccak256(abi.encodePacked(collection, tokenId, chainId, nonce));
    bytes32 prefixedHash = messageHash.prefixed();
    address recoveredSigner = prefixedHash.recover(signature);

    require(recoveredSigner == _msgSender());
    require(!nonceUsed[recoveredSigner][nonce]);

    address wrappedCollection = wrappedCollections[collection];

    if (wrappedCollection == address(0)) {
      wrappedCollection = _deployWrappedCollection(
        string.concat('Wrapped', string(abi.encodePacked(collection))),
        string.concat('w', string(abi.encodePacked(collection))),
        '',
        collection
      );
      wrappedCollections[collection] = wrappedCollection;
    }
    _safeMintNFT(wrappedCollection, recoveredSigner, tokenURI, tokenId);
    nonceUsed[recoveredSigner][nonce] = true;
    nextNonce[recoveredSigner] = nextNonce[recoveredSigner].add(1);
    emit Redeemed(chainId, signature, collection, tokenId, recoveredSigner, nonce, tokenURI);
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }
}
