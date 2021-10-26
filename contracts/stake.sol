// SPDX-License-Identifier: AGPLv3"

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IStakeToken is IERC20, IERC20Permit {
}

contract Staking is Context {
    using SafeERC20 for IERC20;
    /**
     * @notice
     * A stake struct is used to represent the way we store stakes, 
     * A Stake will contain the the amount staked and a timestamp, 
     * When which is when the stake was made
     */    
    struct Stake {
        uint256 amount;
        uint256 when;
    }

    /**
     * @notice
     * A reward struct is used to represent the way we store rewards, 
     * A Reward will contain the the amount rewarded, 
     * Who rewarded and when a rewarded timestamp, 
     * Total is whole amount of stakes
     */    
    struct Reward {
        uint256 amount;
        uint256 when;
        uint256 total;
        address who;
    }

    event Deposit(address who, uint256 amount);
    event Withdraw(address who, uint256 amount);
    event Distribute(address who, uint256 amount);

    /**
     * @notice StakeHolder is a staker that has active stakes
     */
    mapping(address=>Stake[]) private stakings;
    Reward[] public rewards;
    uint256 public total;

    IStakeToken public immutable token;

    /**
     * @dev Attaches STK token.
     *
     */
    constructor(address token_) {
        token = IStakeToken(token_);
    }

    /**
     * @notice Allows a user to stake some amount of STK
     * @param amount_  The amount of STK the user wishes to stake
     * @param signature_ The signature is passed for token approval
     */
    function deposit(uint256 amount_, bytes calldata signature_) external {
        require(amount_ > 0, "wrong amount");

        (uint8 v, bytes32 r, bytes32 s) = signature(signature_);
        address sender = _msgSender(); 
        token.permit(sender, address(this), amount_, block.timestamp, v, r, s);
        IERC20(token).safeTransferFrom(sender, address(this), amount_);
        stakings[sender].push(Stake({amount: amount_, when: block.timestamp}));
        total += amount_;

        emit Deposit(_msgSender(), amount_);
    }

    /**
     * @notice Allows a user to unstake some amount of STK
     * @param amount_  The amount of STK the user wishes to unstake
     */
    function withdraw(uint256 amount_) external {
        require(amount_ > 0, "wrong amount");

        address sender = _msgSender(); 
        require(amount_ == balance(sender), "Only whole withdraw available nowadays");
        total -= amount_;
        delete stakings[sender];
        IERC20(token).safeTransfer(sender, amount_);

        emit Withdraw(_msgSender(), amount_);
    }    

    /**
     * @notice Allows a user to reward some amount of STK
     * @param amount_  The amount of STK the user wishes to reward
     * @param signature_ The signature is passed for token approval
     */
    function distribute(uint256 amount_, bytes calldata signature_) external {
        require(amount_ > 0, "wrong amount");

        (uint8 v, bytes32 r, bytes32 s) = signature(signature_);
        address sender = _msgSender(); 
        token.permit(sender, address(this), amount_, block.timestamp, v, r, s);
        IERC20(token).safeTransferFrom(sender, address(this), amount_);
        rewards.push(Reward({amount: amount_, when: block.timestamp, total: total, who: sender}));

        emit Distribute(_msgSender(), amount_);
    }

    /**
     * @notice Allows a user to reward some amount of STK
     * @param staker_  The amount of STK the user wishes to reward
     */
    function balance(address staker_)  public view returns(uint256 balance_) {
        Stake[] storage stakes = stakings[staker_];
        for (uint256 s = 0; s < stakes.length;) {
            Stake storage stake = stakes[s];
            balance_ += stake.amount;

            uint256 r = rewards.length - 1;
            while (r >= 0) {
                Reward storage reward = rewards[r];
                if (reward.when <= stake.when) break;
                balance_ += stake.amount * reward.amount / reward.total;
            }
            unchecked { s++; }
        }
    }

    function signature(bytes memory signature_) internal returns (uint8 v, bytes32 r, bytes32 s) {
        require(signature_.length == 0x41, "slicing out of range");
        uint8 v = uint8(signature_[0]);
        bytes32 r;
        bytes32 s;
        assembly {
            r := mload(add(signature_, add(0x20, 0x1)))
            s := mload(add(signature_, add(0x20, 0x21)))
        }
        return (v, r, s);
    }
}