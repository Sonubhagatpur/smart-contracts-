// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Simple ERC-20 token interface
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address receiver, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenSwap {
    address public tokenAddress; // Address of the ERC-20 token to be traded
    uint256 public tokenPrice;   // Price of 1 token in wei

    address public owner;        // Address of the contract owner

    event TokensBought(address indexed buyer, uint256 amount);
    event TokensSold(address indexed seller, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can execute this.");
        _;
    }

    constructor(address _tokenAddress, uint256 _tokenPrice) {
        tokenAddress = _tokenAddress;
        tokenPrice = _tokenPrice;
        owner = msg.sender;
    }

    function buyTokens(uint256 numTokens) external payable {
        uint256 totalPrice = numTokens * tokenPrice;
        require(msg.value >= totalPrice, "Insufficient BNB to buy tokens.");

        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= numTokens, "Insufficient contract balance.");

        // Transfer tokens from contract to buyer
        require(token.transferFrom(address(this), msg.sender, numTokens), "Token transfer failed.");

        // Refund excess BNB to the buyer
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit TokensBought(msg.sender, numTokens);
    }

    function sellTokens(uint256 numTokens) external {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(msg.sender) >= numTokens, "Insufficient tokens to sell.");

        // Transfer tokens from seller to contract
        require(token.transferFrom(msg.sender, address(this), numTokens), "Token transfer failed.");

        // Send BNB to the seller
        payable(msg.sender).transfer(numTokens * tokenPrice);

        emit TokensSold(msg.sender, numTokens);
    }

    function setTokenPrice(uint256 newPrice) external onlyOwner {
        tokenPrice = newPrice;
    }

    // Function to withdraw BNB from the contract (only available to the contract owner)
    function withdrawBNB(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract balance.");
        payable(owner).transfer(amount);
    }

    // Function to withdraw ERC-20 tokens from the contract (only available to the contract owner)
    function withdrawTokens(address _tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient contract balance.");
        require(token.transfer(owner, amount), "Token transfer failed.");
    }
}
