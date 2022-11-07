pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './libraries/ActionHelpers.sol';
import './libraries/TransferHelpers.sol';

contract ClosedActions is Ownable, AccessControl {
  using SafeMath for uint256;

  address public action;
  uint256 private fee;
  bytes32 public feeTakerRole = keccak256(abi.encodePacked('FEE_TAKER_ROLE'));
  bytes32 public feeSetterRole = keccak256(abi.encodePacked('FEE_SETTER_ROLE'));
  address public discountToken;
  uint8 public discount;
  uint256 public requiredAmountOfDiscountToken;

  constructor(
    address _action,
    uint256 _fee,
    address _token,
    uint8 _discount,
    uint256 _requiredAmountOfDiscountToken
  ) {
    action = _action;
    fee = _fee;
    discountToken = _token;
    discount = _discount;
    requiredAmountOfDiscountToken = _requiredAmountOfDiscountToken;
    _grantRole(feeTakerRole, _msgSender());
    _grantRole(feeSetterRole, _msgSender());
  }

  function deployCollection(
    string memory name,
    string memory symbol,
    uint256 maxSupply,
    uint256 mintStartTime,
    string memory metadataURI,
    uint256 maxBalance,
    uint96 royaltyNumerator
  ) external payable returns (address collectionId) {
    uint256 feeToPay = getFee(_msgSender());
    require(msg.value >= feeToPay, 'fee');
    collectionId = ActionHelpers._safeDeployCollection(
      action,
      name,
      symbol,
      _msgSender(),
      maxSupply,
      mintStartTime,
      metadataURI,
      maxBalance,
      royaltyNumerator
    );
  }

  function getFee(address account) public view returns (uint256 feeToPay) {
    if (discountToken != address(0) && IERC20(discountToken).balanceOf(account) >= requiredAmountOfDiscountToken) {
      uint256 val = fee.mul(discount).div(100);
      feeToPay = fee.sub(val);
    } else feeToPay = fee;
  }

  function setFee(uint256 _fee) external {
    require(hasRole(feeSetterRole, _msgSender()), 'not_fee_setter');
    fee = _fee;
  }

  function addFeeTaker(address account) external onlyOwner {
    require(!hasRole(feeTakerRole, account), 'already_fee_taker');
    _grantRole(feeTakerRole, account);
  }

  function removeFeeTaker(address account) external onlyOwner {
    require(hasRole(feeTakerRole, account), 'not_fee_taker');
    _revokeRole(feeTakerRole, account);
  }

  function addFeeSetter(address account) external onlyOwner {
    require(!hasRole(feeSetterRole, account), 'already_fee_setter');
    _grantRole(feeSetterRole, account);
  }

  function removeFeeSetter(address account) external onlyOwner {
    require(hasRole(feeSetterRole, account), 'not_fee_setter');
    _revokeRole(feeSetterRole, account);
  }

  function withdrawEther(address to, uint256 amount) external {
    require(hasRole(feeTakerRole, _msgSender()), 'only_fee_taker');
    TransferHelpers._safeTransferEther(to, amount);
  }

  function setDiscountToken(address token) external onlyOwner {
    discountToken = token;
  }

  function setRequiredHold(uint256 _requiredHold) external onlyOwner {
    requiredAmountOfDiscountToken = _requiredHold;
  }

  function setDiscount(uint8 _discount) external onlyOwner {
    discount = _discount;
  }

  function withdrawERC20(
    address token,
    address to,
    uint256 amount
  ) external {
    require(hasRole(feeTakerRole, _msgSender()), 'only_fee_taker');
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  receive() external payable {}
}
