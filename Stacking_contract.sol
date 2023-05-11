/**
 *Submitted for verification at BscScan.com on 2023-05-10
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(address newOwner) {
        _setOwner(newOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
}

abstract contract Pausable is Context {
    event Paused(address account);

    event Unpaused(address account);

    bool private _paused;

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

contract CIK_Staking is Ownable, Pausable {
    using SafeMath for uint256;

    IERC20 public CIKToken;
    IERC20 public FCFToken;

    uint256 public APY = 1700; //default: 17%

    uint256 public stakeFees = 200; //default: 2%
    uint256 public withdrawFees = 200; //default: 2%

    uint256 public FCFReverseFees = 200; //default: 2% for deposit
    uint256 private CIKTOFCF = 200; //as 100 CIK equal to 100 FCF Token for reward

    uint256 public divider = 10000;

    constructor() Ownable(msg.sender) {
        CIKToken = IERC20(0xc80a813b69EDc8eC391306210Cb4010B704cb4E7);
        FCFToken = IERC20(0x4673f018cc6d401AAD0402BdBf2abcBF43dd69F3);
    }

    function changeCIK(address _token) external onlyOwner {
        require(
            IERC20(_token) != CIKToken,
            "This token is already use in the contract"
        );
        CIKToken = IERC20(_token);
    }

    function changeFCF(address _newtoken) external onlyOwner {
        require(
            IERC20(_newtoken) != FCFToken,
            "This token is already use in the contract"
        );
        FCFToken = IERC20(_newtoken);
    }

    function setFCFReverseTokenPercentage(uint256 percentage)
        external
        onlyOwner
    {
        FCFReverseFees = percentage;
    }

    function setTax(uint256 _stakeFees, uint256 _withFees) external onlyOwner {
        stakeFees = _stakeFees;
        withdrawFees = _withFees;
    }

    function setCIKTOFCF(uint256 _tokenNum) external onlyOwner {
        require(_tokenNum > 0, "set a valid number");
        CIKTOFCF = _tokenNum;
    }

    function setAPY(uint256 _apy) external onlyOwner returns (bool) {
        require(_apy > 0, "Please set a valid APY");
        APY = _apy;
        return true;
    }

    function pause() external onlyOwner returns (bool success) {
        _pause();
        return true;
    }

    function unpause() external onlyOwner returns (bool success) {
        _unpause();
        return true;
    }

    function FCFPublicityPercent() public view returns (uint256 percentage) {
        return CIKTOFCF;
    }

    struct user {
        address userAddress;
        uint256 amount;
        uint256 stktime;
    }
    mapping(address => user[]) public investment;

    function getContractCIKBalacne() public view returns (uint256) {
        return CIKToken.balanceOf(address(this));
    }

    function getContractFCFBalacne() public view returns (uint256) {
        return FCFToken.balanceOf(address(this));
    }

    function ContractBalacne() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawBNB() public onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "This contract balance is ZERO BNB");
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Failed to withdraw BNB");
    }

    function withdraw() external onlyOwner {
        uint256 amount = CIKToken.balanceOf(address(this));
        require(amount > 0, "This contract balance is ZERO CIK");
        bool success = CIKToken.transfer(owner(), amount);
        require(success, "Failed to withdraw CIK");
    }

    function invest(uint256 _amount) external {
        require(!paused(), "Pausable: paused");
        require(
            _amount > 0 ,
            "please stake valid amount and select time"
        );
        require(
            _amount <= CIKToken.allowance(msg.sender, address(this)),
            "Insufficient Allowence to the contract"
        );
        uint256 tax = _amount.mul(stakeFees).div(divider);
        if (tax > 0) {
            CIKToken.transferFrom(msg.sender, owner(), tax);
        }
        uint256 reverseFCF = _amount.mul(FCFReverseFees).div(divider);
        if (reverseFCF > 0) {
            FCFTokenWithdraw(msg.sender, reverseFCF);
        }
        CIKToken.transferFrom(msg.sender, address(this), _amount.sub(tax));
        investment[msg.sender].push(
            user({
                userAddress: msg.sender,
                amount: _amount.sub(tax),
                stktime: block.timestamp
            })
        );
    }

    function FCFTokenWithdraw(address _user, uint256 reverseFCF) internal {
        require(
            reverseFCF <= getContractFCFBalacne(),
            "Not Enough FCF Token for withdraw from contract please try after some time"
        );
        FCFToken.transfer(_user, reverseFCF.mul(1e9));
    }

    function removeId(uint256 indexnum) internal {
        for (uint256 i = indexnum; i < investment[msg.sender].length - 1; i++) {
            investment[msg.sender][i] = investment[msg.sender][i + 1];
        }
        investment[msg.sender].pop();
    }

    function withdrawCIK(uint256 id) external returns (bool) {
        require(!paused(), "Pausable: paused");
        user memory users = investment[msg.sender][id];
        require(id < investment[msg.sender].length, "Invalid enter Id");
        uint256 reward = calculateRewardSpecificId(id, msg.sender);
        uint256 rewardWithAmount = users.amount.add(reward);
        require(
            rewardWithAmount <= getContractCIKBalacne(),
            "Not Enough Token for withdraw from contract please try after some time"
        );
        uint256 tax = rewardWithAmount.mul(withdrawFees).div(divider);
        if (tax > 0) {
            CIKToken.transfer(owner(), tax);
        }
        CIKToken.transfer(msg.sender, rewardWithAmount.sub(tax));
        uint256 fcfToken = reward.mul(CIKTOFCF).div(divider);
        FCFTokenWithdraw(msg.sender, fcfToken);
        removeId(id);
        return true;
    }

    function calculateReward(address _user) public view returns (uint256) {
        uint256 index = investment[_user].length;
        uint256 reward;
        for (uint256 i = 0; i < index; i++) {
            user memory users = investment[_user][i];
            uint256 time = block.timestamp.sub(users.stktime);
            reward += users.amount.mul(APY).div(divider).mul(time).div(1 days);
        }
        return reward;
    }

    function calculateRewardSpecificId(uint256 id, address _user)
        public
        view
        returns (uint256)
    {
        require(id < investment[_user].length, "Invalid enter Id");
        user memory users = investment[_user][id];
        uint256 time = block.timestamp.sub(users.stktime);
        uint256 reward = users.amount.mul(APY).div(divider).mul(time).div(
            1 days
        );
        return reward;
    }

    function depositAddAmount(address _user)
        public
        view
        returns (uint256 amount)
    {
        uint256 index = investment[_user].length;
        for (uint256 i = 0; i < index; i++) {
            user memory users = investment[_user][i];
            amount += users.amount;
        }
        return amount;
    }

    function userIndex(address _user) public view returns (uint256) {
        return investment[_user].length;
    }

    receive() external payable {
        payable(msg.sender);
    }
}
