pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './libraries/ActionHelpers.sol';
import './libraries/TransferHelpers.sol';

contract Launchpad is Ownable, AccessControl {
  using SafeMath for uint256;

  struct LaunchInfo {
    address _collection;
    string[] _tokenURIs;
    uint256 _startTime;
    uint256 _endTime;
    uint256 _price;
    uint256 _nextTokenURIIndex;
  }

  event LaunchItemCreated(
    bytes32 _launchId,
    address _collection,
    string[] _tokenURIs,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _price
  );

  event LaunchItemFinalized(bytes32 _launchId);

  address action;
  mapping(bytes32 => LaunchInfo) private launches;
  mapping(bytes32 => uint256) private balances;
  mapping(bytes32 => bool) private finality;

  uint256 private withdrawableBalance;

  bytes32 public actionSetterRole = keccak256(abi.encode('ACTION_SETTER_ROLE'));
  bytes32 public launchCreatorRole = keccak256(abi.encode('LAUNCH_CREATOR_ROLE'));
  bytes32 public finalizerRole = keccak256(abi.encode('FINALIZER_ROLE'));

  constructor(address action_) {
    action = action_;
    _grantRole(actionSetterRole, _msgSender());
    _grantRole(launchCreatorRole, _msgSender());
    _grantRole(finalizerRole, _msgSender());
  }

  function createLaunchItem(
    string memory name,
    string memory symbol,
    address owner_,
    uint256 maxSupply,
    uint256 mintStartTime,
    string memory metadataURI,
    uint256 launchStartTime,
    int256 daysForLaunch,
    string[] memory tokenURIs,
    uint256 _pricePerToken
  ) external {
    require(hasRole(launchCreatorRole, _msgSender()), 'only_launch_creator');
    require(tokenURIs.length == maxSupply, 'length_of_uris_must_be_same_as_max_supply');
    require(mintStartTime == launchStartTime, 'minting_time_must_be_same_as_launch_time');
    address _collection = ActionHelpers._safeDeployCollection(
      action,
      name,
      symbol,
      owner_,
      maxSupply,
      mintStartTime,
      metadataURI
    );
    bytes32 _launchId = keccak256(
      abi.encodePacked(_collection, name, symbol, owner_, mintStartTime, metadataURI, address(this))
    );
    launches[_launchId] = LaunchInfo(
      _collection,
      tokenURIs,
      launchStartTime,
      launchStartTime.add(uint256(daysForLaunch).mul(60).mul(60).mul(24)),
      _pricePerToken,
      0
    );

    emit LaunchItemCreated(
      _launchId,
      _collection,
      tokenURIs,
      launchStartTime,
      launches[_launchId]._endTime,
      _pricePerToken
    );
  }

  function mint(bytes32 _launchId) external payable returns (uint256 tokenId) {
    LaunchInfo storage _launchInfo = launches[_launchId];
    require(_launchInfo._startTime <= block.timestamp, 'not_time_to_mint');
    require(msg.value == _launchInfo._price, 'must_pay_exact_price_for_token');
    tokenId = ActionHelpers._safeMintNFT(
      action,
      _launchInfo._collection,
      _msgSender(),
      _launchInfo._tokenURIs[_launchInfo._nextTokenURIIndex]
    );
    balances[_launchId] = balances[_launchId].add(msg.value);
    _launchInfo._nextTokenURIIndex = _launchInfo._nextTokenURIIndex.add(1);
  }

  function finalize(bytes32 _launchId) external returns (bool) {
    require(hasRole(finalizerRole, _msgSender()), 'only_finalizer');
    require(!finality[_launchId], 'already_finalized');
    LaunchInfo storage _launchInfo = launches[_launchId];
    require(_launchInfo._endTime <= block.timestamp, 'cannot_finalize_now');

    uint256 _fee = balances[_launchId].mul(30) / 100;
    uint256 _profit = balances[_launchId].sub(_fee);

    Ownable ownable = Ownable(_launchInfo._collection);

    require(TransferHelpers._safeTransferEther(ownable.owner(), _profit), 'could_not_transfer_ether');
    withdrawableBalance = withdrawableBalance.add(_fee);
    finality[_launchId] = true;

    emit LaunchItemFinalized(_launchId);

    return true;
  }
}
