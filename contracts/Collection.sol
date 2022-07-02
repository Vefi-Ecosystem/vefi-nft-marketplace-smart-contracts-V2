pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Collection is ERC721URIStorage, ERC721Enumerable, ERC721Royalty, Ownable, ReentrancyGuard, AccessControl {
  using Counters for Counters.Counter;
  using SafeMath for uint256;

  Counters.Counter private tokenIds;

  uint256 public maxSupply;
  uint256 public mintStartTime;

  bytes32 public minterRole = keccak256(abi.encode('MINTER_ROLE'));
  bytes32 public royaltySetterRole = keccak256(abi.encode('ROYALTY_SETTER_ROLE'));

  uint96 public royaltyNumerator = 2000;

  modifier ownerOrMinter() {
    require(owner() == _msgSender() || hasRole(minterRole, _msgSender()), 'must_be_owner_or_minter');
    _;
  }

  modifier onlyRoyaltySetter() {
    require(hasRole(royaltySetterRole, _msgSender()), 'only_royalty_setter');
    _;
  }

  constructor(
    string memory name_,
    string memory symbol_,
    address owner_,
    uint256 maxSupply_,
    uint256 mintStartTime_
  ) Ownable() ERC721(name_, symbol_) {
    maxSupply = maxSupply_;
    mintStartTime = mintStartTime_;
    _grantRole(minterRole, _msgSender());
    _grantRole(royaltySetterRole, _msgSender());
    _transferOwnership(owner_);
    _grantRole(royaltySetterRole, owner_);
  }

  function mint(address _to, string memory _tokenURI) external nonReentrant ownerOrMinter returns (uint256 tokenId) {
    require(totalSupply() <= maxSupply, 'cannot_exceed_maximum_number_of_items_in_collection');
    require(block.timestamp >= mintStartTime, 'not_open_for_minting');
    tokenIds.increment();
    tokenId = tokenIds.current();
    _safeMint(_to, tokenId);
    _setTokenURI(tokenId, _tokenURI);
    _setTokenRoyalty(tokenId, _to, royaltyNumerator);
  }

  function burn(uint256 _tokenId) external nonReentrant onlyOwner {
    require(_exists(_tokenId), 'token_must_exist');
    _burn(_tokenId);
  }

  function addMinter(address _minter) external onlyOwner {
    require(!hasRole(minterRole, _minter), 'already_minter');
    _grantRole(minterRole, _minter);
  }

  function removeMinter(address _minter) external onlyOwner {
    require(hasRole(minterRole, _minter), 'not_a_minter');
    _revokeRole(minterRole, _minter);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControl, ERC721, ERC721Enumerable, ERC721Royalty)
    returns (bool)
  {
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

  function setRoyalty(uint96 royalty) external onlyRoyaltySetter returns (bool) {
    royaltyNumerator = royalty;

    if (totalSupply() > 0) {
      for (uint256 i = 0; i < totalSupply(); i++) {
        (address receiver, ) = royaltyInfo(tokenByIndex(i), 0);
        _setTokenRoyalty(tokenByIndex(i), receiver, royalty);
      }
    }
    return true;
  }
}
