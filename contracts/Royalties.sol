pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import './interfaces/IRoyalties.sol';

contract Royalties is IRoyalties, Context, AccessControl {
  mapping(address => mapping(uint256 => address)) private royalties;

  bytes32 public modRole = keccak256(abi.encode('MOD_ROLE'));
  bytes32 public adminRole = keccak256(abi.encode('ADMIN_ROLE'));

  modifier onlyAdminOrMod() {
    require(hasRole(adminRole, _msgSender()) || hasRole(modRole, _msgSender()), 'only_admin_or_mod_can_call');
    _;
  }

  constructor(address mod) {
    _grantRole(adminRole, _msgSender());
    _grantRole(modRole, mod);
    _setRoleAdmin(modRole, adminRole);
  }

  function addRoyalty(
    address collectionId,
    uint256 tokenId,
    address originalMiner
  ) external onlyAdminOrMod returns (bool) {
    royalties[collectionId][tokenId] = originalMiner;
    return true;
  }

  function getRoyalty(address collectionId, uint256 tokenId) external view returns (address) {
    return royalties[collectionId][tokenId];
  }
}
