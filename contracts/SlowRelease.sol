// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Administrable.sol";
import "./IRewardHandler.sol";

interface IERC721 {
  function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract RewardHandler_SlowRelease is Administrable, IRewardHandler {
    address override public nft;
    address rewardToken; // trusted erc20 token
    event LogWithdrawReward(uint256 amount);

    struct Info {
        uint256 amount;
        uint64 startTime;
        uint64 endTime;
    }

    mapping(address => Info) public rewardInfo;
    mapping(uint256 => uint256) public lastClaimTime;

    constructor (address nft_, address rewardToken_) {
        rewardToken = rewardToken_;
        nft = nft_;
        setAdmin(msg.sender);
    }

    function setReward(address[] calldata owner, uint256 amount, uint256 startTime, uint256 endTime) onlyAdmin external {
        for (uint i = 0; i < owner.length; i++) {
            rewardInfo[owner[i]] = Info(amount, uint64(startTime), uint64(endTime));
        }
    }

    function withdrawReward(uint256 amount) onlyAdmin external {
        IERC20(rewardToken).transfer(msg.sender, amount);
        emit LogWithdrawReward(amount);
    }

    function claimable(uint256 tokenId) override public view returns(uint256) {
        Info memory info = rewardInfo[IERC721(nft).ownerOf(tokenId)];
        uint256 start = uint256(info.startTime);
        uint256 end = uint256(info.endTime);
        uint256 length = end - start;
        if (start < lastClaimTime[tokenId]) {
            start = lastClaimTime[tokenId];
        }
        if (end > block.timestamp) {
            end = block.timestamp;
        }
        return info.amount * (end - start) / length;
    }

    function claimReward(uint256 tokenId) override external {
        lastClaimTime[tokenId] = block.timestamp;
        uint256 amount = claimable(tokenId);
        IERC20(rewardToken).transfer(IERC721(nft).ownerOf(tokenId), amount);
    }
}

contract RewardHandler_Factory_SlowRelease {
    function getBytecode(address nft, address rewardToken) public pure returns (bytes memory) {
        bytes memory bytecode = type(RewardHandler_SlowRelease).creationCode;
        return abi.encodePacked(bytecode, abi.encode(nft), abi.encode(rewardToken));
    }

    function create(address nft, address rewardToken, uint salt) payable public returns (address) {
        address addr;
        bytes memory bytecode = getBytecode(nft, rewardToken);
        assembly {
            addr := create2(
                callvalue(),
                add(bytecode, 0x20),
                mload(bytecode),
                salt
            )

            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        return addr;
    }
}