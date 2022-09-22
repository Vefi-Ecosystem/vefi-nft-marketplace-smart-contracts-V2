pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import './libraries/ECDSAHelpers.sol';
import './libraries/TransferHelpers.sol';
import './interfaces/IBridge.sol';

contract Bridge is Ownable, IERC721Receiver, AccessControl, IBridge {
  using SafeMath for uint256;
  using ECDSAHelpers for bytes32;
  using Address for address;

  mapping(address => mapping(uint256 => bool)) nonceUsed;
  mapping(address => uint256) public nextNonce;
  mapping(address => address) wrappedCollections;
  mapping(address => mapping(uint256 => address)) previousOwner;
  mapping(address => mapping(address => uint256)) originChain;

  uint256 chainId;
  uint256 private bridgingFee;
  address action;

  bytes32 public feeTakerRole = keccak256(abi.encodePacked('FEE_TAKER_ROLE'));
  bytes32 public feeSetterRole = keccak256(abi.encodePacked('FEE_SETTER_ROLE'));

  event BridgeRequested(
    uint256 destinationChain,
    bytes signature,
    address collection,
    uint256 tokenId,
    address signer,
    uint256 nonce,
    string tokenURI
  );
  event Redeemed(uint256 destinationChain, bytes signature, address collection, uint256 tokenId, address signer, uint256 nonce, string tokenURI);
  event Unwrapped(uint256 originChain, bytes signature, address collection, uint256 tokenId, address signer, uint256 nonce);

  constructor(
    uint256 _chainId,
    uint256 _bridgingFee,
    address _action
  ) {
    require(_action.isContract());
    chainId = _chainId;
    bridgingFee = _bridgingFee;
    action = _action;
    _grantRole(feeSetterRole, _msgSender());
    _grantRole(feeTakerRole, _msgSender());
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

  function _safeBurn(address collection, uint256 tokenId) private {
    (bool success, ) = collection.call(abi.encodeWithSelector(bytes4(keccak256(bytes('burn(uint256)'))), tokenId));
    require(success);
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
    bytes32 messageHash = keccak256(abi.encodePacked(collection, tokenId, chainId, destinationChain, nonce));
    bytes32 prefixedHash = messageHash.prefixed();
    address recoveredSigner = prefixedHash.recover(signature);

    require(recoveredSigner == _msgSender());
    require(!nonceUsed[recoveredSigner][nonce]);
    require(IERC721(collection).ownerOf(tokenId) == recoveredSigner);
    require(IERC721(collection).isApprovedForAll(_msgSender(), address(this)));
    IERC721(collection).safeTransferFrom(recoveredSigner, address(this), tokenId);
    nonceUsed[recoveredSigner][nonce] = true;
    nextNonce[recoveredSigner] = nextNonce[recoveredSigner].add(1);
    previousOwner[collection][tokenId] = recoveredSigner;

    string memory tokenURI = IERC721Metadata(collection).tokenURI(tokenId);
    emit BridgeRequested(destinationChain, signature, collection, tokenId, recoveredSigner, nonce, tokenURI);
  }

  function redeem(
    address collection,
    uint256 tokenId,
    uint256 nonce,
    uint256 originChainId,
    bytes memory signature,
    string memory tokenURI
  ) external {
    bytes32 messageHash = keccak256(abi.encodePacked(collection, tokenId, originChainId, chainId, nonce));
    bytes32 prefixedHash = messageHash.prefixed();
    address recoveredSigner = prefixedHash.recover(signature);

    require(recoveredSigner == _msgSender());
    require(!nonceUsed[recoveredSigner][nonce]);

    address wrappedCollection = wrappedCollections[collection];

    if (wrappedCollection == address(0)) {
      wrappedCollection = _deployWrappedCollection(
        string.concat('Wrapped ', string(abi.encodePacked(collection))),
        string.concat('w', string(abi.encodePacked(collection))),
        '',
        collection
      );
      wrappedCollections[collection] = wrappedCollection;
      wrappedCollections[wrappedCollection] = collection;
      originChain[collection][wrappedCollection] = originChainId;
    }
    _safeMintNFT(wrappedCollection, recoveredSigner, tokenURI, tokenId);
    nonceUsed[recoveredSigner][nonce] = true;
    nextNonce[recoveredSigner] = nextNonce[recoveredSigner].add(1);
    emit Redeemed(chainId, signature, collection, tokenId, recoveredSigner, nonce, tokenURI);
  }

  function unwrap(
    address collection,
    uint256 tokenId,
    uint256 nonce
  ) external {
    require(collection.isContract());
    require(IERC721(collection).ownerOf(tokenId) == _msgSender());
    _safeBurn(collection, tokenId);
    require(!nonceUsed[_msgSender()][nonce]);

    address wrappedCollection = wrappedCollections[collection];
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function getFee() external view returns (uint256) {
    return bridgingFee;
  }

  function setFee(uint256 _fee) external {
    require(hasRole(feeSetterRole, _msgSender()));
    bridgingFee = _fee;
  }

  function setFeeTaker(address account) external onlyOwner {
    require(!hasRole(feeTakerRole, account));
    _grantRole(feeTakerRole, account);
  }

  function removeFeeTaker(address account) external onlyOwner {
    require(hasRole(feeTakerRole, account));
    _revokeRole(feeTakerRole, account);
  }

  function setFeeSetter(address account) external onlyOwner {
    require(!hasRole(feeSetterRole, account));
    _grantRole(feeSetterRole, account);
  }

  function removeFeeSetter(address account) external onlyOwner {
    require(hasRole(feeSetterRole, account));
    _revokeRole(feeSetterRole, account);
  }

  function withdrawEther(address to, uint256 amount) external {
    require(hasRole(feeTakerRole, _msgSender()));
    TransferHelpers._safeTransferEther(to, amount);
  }

  function withdrawERC20(
    address token,
    address to,
    uint256 amount
  ) external {
    require(hasRole(feeTakerRole, _msgSender()));
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  receive() external payable {}
}
