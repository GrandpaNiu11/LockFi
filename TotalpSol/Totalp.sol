// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // 必须导入这个
contract StakingRewards {
    using SafeERC20 for IERC20; // ✅ 必须添加这一行！
    IERC20 public stakingToken;
    IERC20 public rewardsToken;
    address public  owner;

    struct Pledgor {
        // 质押数
        uint256 amount;
        //开始质押时间
        uint256 Pledgetime;
    }

    mapping(address => Pledgor) public  addrpledgor;
    uint256 public constant PRECISION = 1e18; // 18位小数精度
    // 当前速率 (每秒给你多少token)
    uint256 public  rate = 0;
    // 池子里剩余toekn数
    uint256 public  remainingBalance = 0;
    //已经消耗的token数
    uint256 public  tokensLocked = 0;
    //总发送token数
    uint256 public  TotalBalance = 0;
    // 结束时间
    uint256 public  endtime = 0;
    // 总质押token数
    uint256 public  Totalpledge = 0;
    //速率时间段
    uint256[] public  ratetime;
    //每一个时间段的速率
    mapping(uint256 => uint256) public  rateMap;
    //上一次添加代币的时间
    uint256 public  lasttimeAdd = 0;
    //最小质押代币数
    uint256 public  minStakeAmount = 5 * 1e18;
    //上次结算剩余余额日期
    uint256 public  lastSettlementTime = 0;
    constructor(address _stakingToken, address _rewardsToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }
    modifier mocalculateRewards(){

        if (lastSettlementTime == 0) {
            lastSettlementTime = block.timestamp;
        } else {
            uint256 xiaohao = calculateRewards(lastSettlementTime);
            lastSettlementTime = block.timestamp;
            tokensLocked += xiaohao;
        }

        _;
    }

    // 添加时间
    function addtime(uint256 _ratetime) external onlyOwner {
        if (block.timestamp >= endtime) {
            //更新速率时间段
            ratetime.push(endtime);
            rateMap[endtime] = rate;
            //更新时间
            endtime = block.timestamp + _ratetime;

        } else {

            uint256 remainingTime = endtime - block.timestamp;
            uint256 totalNewTime = remainingTime + _ratetime;
            // 重新计算rate，保持总奖励不变
            rate = (rate * remainingTime) / totalNewTime;
            // 更新结束时间
            endtime = block.timestamp + totalNewTime;
            //更新速率时间段
            ratetime.push(block.timestamp);
            rateMap[block.timestamp] = rate;
        }
    }
    //添加代币
    function addToken(uint _t okenBalance) external onlyOwner mocalculateRewards {
require(block.timestamp < endtime, "The contract has ended and cannot be added.");
// 计算当前可分配奖励（剩余余额减去已锁定奖励）
uint256 availableRewards = remainingBalance > tokensLocked ? remainingBalance - tokensLocked : 0;
uint256 remainingTime = endtime - block.timestamp;
//    判断池子里面是否还有代币数
if (availableRewards <= 0){
remainingBalance = _tokenBalance;
//   计算速率
rate = (_tokenBalance * PRECISION) / remainingTime / Totalpledge;
}else {
//池子里面还有
//   计算出还剩余多少个balance
// 重新计算rate，保持总奖励不变
uint256 sum = rate * Totalpledge * remainingBalance;
sum = sum + _tokenBalance;
// 计算利率
rate = sum / remainingTime  / Totalpledge;
}
//更新速率时间段
ratetime.push(block.timestamp);
rateMap[block.timestamp] = rate;
//   转账erc
// 检查授权额度是否足够
uint256 allowance = rewardsToken.allowance(msg.sender, address(this));
require(allowance >= _tokenBalance, "Token allowance too low");

// 检查发送者余额是否足够
uint256 balance = rewardsToken.balanceOf(msg.sender);
require(balance >= _tokenBalance, "Insufficient token balance");

// 执行安全转账
rewardsToken.safeTransferFrom(msg.sender, address(this), _tokenBalance);

// 更新剩余余额
remainingBalance += _tokenBalance;
}





// 计算从开始时间到当前时间的总奖励
function calculateRewards(uint256 startTime) public view returns (uint256) {
require(startTime <= block.timestamp, "Start time must be in the past");
require(ratetime.length > 0, "No rate data available");

uint256 totalRewards = 0;
uint256 currentTime = block.timestamp;

// 找到开始时间所在的区间
uint256 startIndex = _findTimeInterval(startTime);

// 遍历所有速率区间计算奖励
for (uint256 i = startIndex; i < ratetime.length - 1; i++) {
uint256 intervalStart = ratetime[i];
uint256 intervalEnd = ratetime[i + 1];
uint256 intervalRate = rateMap[intervalStart];

// 计算这个区间的有效时间
uint256 effectiveStart = (startTime > intervalStart) ? startTime : intervalStart;
uint256 effectiveEnd = (currentTime < intervalEnd) ? currentTime : intervalEnd;

if (effectiveEnd > effectiveStart) {
uint256 intervalDuration = effectiveEnd - effectiveStart;
totalRewards += intervalRate * intervalDuration * Totalpledge;
}
}

// 处理最后一个区间（到当前时间）
uint256 lastTimePoint = ratetime[ratetime.length - 1];
if (currentTime > lastTimePoint) {
uint256 lastRate = rateMap[lastTimePoint];
uint256 lastDuration = currentTime - (startTime > lastTimePoint ? startTime : lastTimePoint);
totalRewards += lastRate * lastDuration * Totalpledge;
}
totalRewards = totalRewards / PRECISION;

return totalRewards;
}
// 二分查找时间点所在的区间
function _findTimeInterval(uint256 timestamp) internal view returns (uint256) {
if (ratetime.length == 0 || timestamp < ratetime[0]) {
return 0;
}
if (timestamp >= ratetime[ratetime.length - 1]) {
return ratetime.length - 1;
}

// 二分查找
uint256 low = 0;
uint256 high = ratetime.length - 1;

while (low <= high) {
uint256 mid = (low + high) / 2;

if (ratetime[mid] == timestamp) {
return mid;
} else if (ratetime[mid] < timestamp) {
low = mid + 1;
} else {
high = mid - 1;
}
}

return high; // 返回最后一个小于等于timestamp的索引
}


}