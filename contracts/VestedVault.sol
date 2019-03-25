pragma solidity 0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/common/SafeERC20.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import "@aragon/os/contracts/lib/token/ERC20.sol";

contract VestedVault is AragonApp {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  bytes32 constant public RELEASE_TOKENS_ROLE = keccak256("RELEASE_TOKENS_ROLE");

  event Released(uint256 amount);

  // beneficiary of tokens after they are released
  address public beneficiary;
  address public token;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;
  uint256 public released;

  /**
   * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
     @param _token address of the ERC20 token
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   */
  function initialize(
    address _token,
    address _beneficiary,
    uint256 _start,
    uint256 _cliff,
    uint256 _duration
  )
    public onlyInit
  {
    require(_beneficiary != address(0));
    require(_token != address(0));
    require(_cliff <= _duration);

    initialized();

    beneficiary = _beneficiary;
    token = _token;
    duration = _duration;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /**
   * @notice Transfers vested tokens to beneficiary.
   */
  function release() auth(RELEASE_TOKENS_ROLE) isInitialized external {
    uint256 unreleased = releasableAmount();

    require(unreleased > 0);

    released = released.add(unreleased);

    ERC20(token).safeTransfer(beneficiary, unreleased);

    emit Released(unreleased);
  }

  /**
   * @dev Calculates the amount that has already vested but hasn't been released yet.
   */
  function releasableAmount() public view returns (uint256) {
    return vestedAmount().sub(released);
  }

  /**
   * @dev Calculates the amount that has already vested.
   */
  function vestedAmount() public view returns (uint256) {
    uint256 currentBalance = ERC20(token).balanceOf(address(this));
    uint256 totalBalance = currentBalance.add(released);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration)) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}