pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './libraries/TransferHelpers.sol';
import './MintableBabyVEF.sol';

contract Staking is IERC721Receiver, Ownable, AccessControl, ReentrancyGuard {
  struct StakeInfo {
    address collection;
    uint256 tokenId;
    uint256 stakedSince;
    uint256 nextWithdrawalTime;
    address staker;
  }

  using SafeMath for uint256;

  address public rewardToken;
  address public stakeFeeToken;

  uint256 public immutable multiplier;
  uint256 public stakeFee;
  uint256 public withdrawalIntervals;

  mapping(address => StakeInfo[]) public stakings;
  mapping(bytes32 => StakeInfo) public stakes;

  bytes32 public feeTakerRole = keccak256(abi.encode('FEE_TAKER_ROLE'));
  bytes32 public feeSetterRole = keccak256(abi.encode('FEE_SETTER_ROLE'));

  event Staked(address indexed account, address indexed collection, uint256 tokenId, bytes32 stakeId);

  constructor(
    address _rewardToken,
    uint8 _multiplier,
    address _stakeFeeToken,
    uint256 _stakeFee,
    uint256 _withdrawalIntervals
  ) {
    rewardToken = _rewardToken;
    multiplier = uint256(_multiplier).mul(1000);
    stakeFeeToken = _stakeFeeToken;
    stakeFee = _stakeFee;
    withdrawalIntervals = _withdrawalIntervals;
    _grantRole(feeTakerRole, _msgSender());
    _grantRole(feeSetterRole, _msgSender());
  }

  function sqrt(uint256 y) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    }
  }

  function calculateReward(bytes32 stakeId) public view returns (uint256 reward) {
    StakeInfo memory stakeInfo = stakes[stakeId];
    uint256 _days = block.timestamp.sub(stakeInfo.stakedSince);
    reward = sqrt(_days.div(365 days).mul(multiplier)).mul(10**ERC20(stakeFeeToken).decimals());
  }

  function stake(address collection, uint256 tokenId) external nonReentrant returns (bytes32 stakeId) {
    require(IERC20(stakeFeeToken).allowance(_msgSender(), address(this)) >= stakeFee, 'not_enough_allowance');
    require(IERC721(collection).ownerOf(tokenId) == _msgSender(), 'not_token_owner');
    require(IERC721(collection).isApprovedForAll(_msgSender(), address(this)), 'no_approval_given');
    TransferHelpers._safeTransferFromERC20(stakeFeeToken, _msgSender(), address(this), stakeFee);
    IERC721(collection).safeTransferFrom(_msgSender(), address(this), tokenId);
    StakeInfo memory stakeInfo = StakeInfo({
      collection: collection,
      tokenId: tokenId,
      stakedSince: block.timestamp,
      nextWithdrawalTime: block.timestamp.add(withdrawalIntervals),
      staker: _msgSender()
    });
    stakeId = keccak256(abi.encodePacked(stakeInfo.collection, stakeInfo.tokenId, _msgSender(), stakeInfo.stakedSince));
    stakes[stakeId] = stakeInfo;

    StakeInfo[] storage usersStakes = stakings[_msgSender()];
    usersStakes.push(stakeInfo);
    emit Staked(_msgSender(), collection, tokenId, stakeId);
  }

  function withdrawReward(bytes32 stakeId) external nonReentrant {
    StakeInfo storage stakeInfo = stakes[stakeId];
    require(stakeInfo.staker == _msgSender(), 'only_stake_owner');
    require(block.timestamp >= stakeInfo.nextWithdrawalTime, 'not_time_for_withdrawals');
    uint256 reward = calculateReward(stakeId);
    MintableBabyVEF(payable(stakeFeeToken)).mint(_msgSender(), reward);
    stakeInfo.stakedSince = block.timestamp;
    stakeInfo.nextWithdrawalTime = block.timestamp.add(withdrawalIntervals);
  }

  function unstake(bytes32 stakeId) external nonReentrant {
    StakeInfo memory stakeInfo = stakes[stakeId];
    require(stakeInfo.staker == _msgSender(), 'only_stake_owner');
    IERC721(stakeInfo.collection).transferFrom(address(this), _msgSender(), stakeInfo.tokenId);
    delete stakes[stakeId];
  }

  function retrieveERC20(
    address token,
    address to,
    uint256 amount
  ) external nonReentrant {
    require(hasRole(feeTakerRole, _msgSender()), 'only_fee_taker');
    TransferHelpers._safeTransferERC20(token, to, amount);
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
