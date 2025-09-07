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
        uint256  Pledgetime;
        uint256  claimedRewards;
    }
    mapping  (address => Pledgor) public  addrpledgor;
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
    uint256[] public  ratetime ;
    //每一个时间段的速率
    mapping  (uint256 => uint256) public  rateMap;
    //上一次添加代币的时间
    uint256 public  lasttimeAdd = 0;
    //最小质押代币数
    uint256 public  minStakeAmount = 5 * 1e18;
    //上次结算剩余余额日期
    uint256 public  lastSettlementTime =0;
    constructor(address _stakingToken ,address _rewardsToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }
    modifier mocalculateRewards(){

        if (lastSettlementTime ==0){
            lastSettlementTime =block.timestamp;
        }else {
            uint256  xiaohao = calculateRewards(lastSettlementTime,Totalpledge);
            lastSettlementTime =block.timestamp;
            tokensLocked += xiaohao;
            remainingBalance -= xiaohao;
        }

        _;
    }

    // 添加时间
    function  addtime(uint256 _ratetime) external onlyOwner {
        if (block.timestamp >= endtime){
            //更新速率时间段
            ratetime.push(endtime);
            rateMap[endtime] = rate;
            //更新时间
            endtime = block.timestamp+_ratetime;

        }else {

            uint256 remainingTime = endtime - block.timestamp;
            uint256 totalNewTime = remainingTime + _ratetime;
            // 重新计算rate，保持总奖励不变
            rate = (rate * remainingTime  ) / totalNewTime ;
            // 更新结束时间
            endtime = block.timestamp + totalNewTime;
            //更新速率时间段
            ratetime.push(block.timestamp);
            rateMap[block.timestamp] = rate;
        }
    }
    //添加代币
    function addToken(uint _tokenBalance) external onlyOwner   mocalculateRewards {
        require(block.timestamp < endtime, "The contract has ended and cannot be added.");
        uint256 remainingTime = endtime - block.timestamp;
        if (Totalpledge ==0) {
            rate=0;
        }else if (remainingBalance <= 0){

            //   计算速率
            rate = ( _tokenBalance * PRECISION) /remainingTime  /Totalpledge;
        }else {
            //池子里面还有
            //   计算出还剩余多少个balance
            // 重新计算rate，保持总奖励不变
            // 计算利率
            rate = (remainingBalance +_tokenBalance)* PRECISION  / remainingTime  /Totalpledge;
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



    //目前是一个用户只能质押一次
    function adduser(uint256 _tokenBalance) external {
        require(minStakeAmount<=_tokenBalance,"Stake amount too low");
        require(addrpledgor[msg.sender].amount ==0, "You have already participated in staking.");

        // 检查授权额度是否足够
        uint256 allowance = stakingToken.allowance(msg.sender, address(this));
        require(allowance >= _tokenBalance, "Token allowance too low");
        // 检查发送者余额是否足够
        uint256 balance = stakingToken.balanceOf(msg.sender);
        require(balance >= _tokenBalance, "Insufficient token balance");
        // 执行安全转账
        stakingToken.safeTransferFrom(msg.sender, address(this), _tokenBalance);
        Pledgor memory a= Pledgor ({
            amount :_tokenBalance,
            Pledgetime : block.timestamp,
            claimedRewards: 0
        });
        // 更新用户质押信息
        addrpledgor[msg.sender] = a;

        // 更新总质押量
        Totalpledge += _tokenBalance;
        //更新利率值
        updateRewardRate();

    }


    //计算用户该提走多少token
    function calculateWithdrawableTokens() public view returns (uint256) {
        require(addrpledgor[msg.sender].amount !=0, "You haven't staked any tokens yet. Please stake to start earning rewards.");
        uint256  count= addrpledgor[msg.sender].amount;
        uint256  pledgetime= addrpledgor[msg.sender].Pledgetime;
        uint256 totalRewards= calculateRewards(pledgetime,count);
        return totalRewards;
    }
    // 提取奖励函数
    function claimRewards() public {
        require(addrpledgor[msg.sender].amount > 0, "You haven't staked any tokens yet.");

        // 计算可提取的奖励
        uint256 withdrawableRewards = calculateWithdrawableTokens();
        require(withdrawableRewards > 0, "No rewards to claim");
        require(rewardsToken.balanceOf(address(this)) >= withdrawableRewards, "Insufficient reward tokens");

        // 更新已领取奖励
        addrpledgor[msg.sender].claimedRewards += withdrawableRewards;

        // 发放奖励（使用 rewardsToken）
        rewardsToken.safeTransfer(msg.sender, withdrawableRewards);

    }
    // 提取质押本金函数
    function withdrawStake() public {
        require(addrpledgor[msg.sender].amount > 0, "No stake to withdraw");

        uint256 stakeAmount = addrpledgor[msg.sender].amount;

        // 先让用户领取所有未领取的奖励
        claimRewards();

        // 更新总质押量
        Totalpledge -= stakeAmount;

        // 清除用户质押信息
        delete addrpledgor[msg.sender];

        // 返还质押代币（使用 stakingToken）
        stakingToken.safeTransfer(msg.sender, stakeAmount);


    }


    // 内部函数：更新奖励速率
    function updateRewardRate() internal  mocalculateRewards{
        if (Totalpledge > 0 && endtime > block.timestamp) {
            uint256 remainingTime = endtime - block.timestamp;
            rate = (remainingBalance * PRECISION) / remainingTime / Totalpledge;

            // 记录当前时间点的速率
            ratetime.push(block.timestamp);
            rateMap[block.timestamp] = rate;
        }else {
            rate =0;
        }
    }
    // 计算从开始时间到当前时间的总奖励
    function calculateRewards(uint256 startTime,uint256 _Totalpledge) public view returns (uint256) {
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
                totalRewards += intervalRate * intervalDuration * _Totalpledge;
            }
        }

        // 处理最后一个区间（到当前时间）
        uint256 lastTimePoint = ratetime[ratetime.length - 1];
        if (currentTime > lastTimePoint) {
            uint256 lastRate = rateMap[lastTimePoint];
            uint256 lastDuration = currentTime - (startTime > lastTimePoint ? startTime : lastTimePoint);
            totalRewards += lastRate * lastDuration * _Totalpledge;
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