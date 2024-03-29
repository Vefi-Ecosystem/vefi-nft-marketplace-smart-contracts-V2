pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

// Only intent is to wrap a collection
contract WrappedCollection is ERC721URIStorage, ERC721Enumerable, ERC721Royalty, Ownable, AccessControl {
  using SafeMath for uint256;

  // uint256 public maxSupply;
  // uint256 public mintStartTime;
  // uint256 public maxBalance;

  bytes32 public minterRole = keccak256(abi.encode('MINTER_ROLE'));
  bytes32 public royaltySetterRole = keccak256(abi.encode('ROYALTY_SETTER_ROLE'));

  uint96 public royaltyNumerator = 2000;

  string public metadataURI;

  modifier ownerOrMinter() {
    require(owner() == _msgSender() || hasRole(minterRole, _msgSender()));
    _;
  }

  modifier onlyRoyaltySetter() {
    require(hasRole(royaltySetterRole, _msgSender()));
    _;
  }

  constructor(
    string memory name_,
    string memory symbol_,
    string memory metadataURI_
  ) Ownable() ERC721(name_, symbol_) {
    metadataURI = metadataURI_;
    _grantRole(minterRole, _msgSender());
    _grantRole(royaltySetterRole, _msgSender());
  }

  function mint(
    address _to,
    string memory _tokenURI,
    uint256 tId
  ) external ownerOrMinter returns (uint256 tokenId) {
    tokenId = tId;
    _safeMint(_to, tokenId);
    _setTokenURI(tokenId, _tokenURI);
    _setTokenRoyalty(tokenId, _to, royaltyNumerator);
  }

  function burn(uint256 _tokenId) external onlyOwner {
    require(_exists(_tokenId));
    _burn(_tokenId);
  }

  function addMinter(address _minter) external onlyOwner {
    require(!hasRole(minterRole, _minter));
    _grantRole(minterRole, _minter);
  }

  function removeMinter(address _minter) external onlyOwner {
    require(hasRole(minterRole, _minter));
    _revokeRole(minterRole, _minter);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721, ERC721Enumerable, ERC721Royalty) returns (bool) {
    return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
  }

  function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage, ERC721Royalty) {
    return super._burn(tokenId);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721, ERC721Enumerable) {
    return super._beforeTokenTransfer(from, to, tokenId);
  }

  function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
    return super.tokenURI(tokenId);
  }
}
