// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./interfaces/ILock.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Lock is ILock {
  uint public unlockTime;
  address payable public owner;
  enum IdRarity {
    Rare
  }
  mapping(uint256 => uint256) public rarity;

  constructor(uint unlockTime_) payable {
    require(block.timestamp < unlockTime_, "Unlock time should be in the future");

    unlockTime = unlockTime_;
    owner = payable(msg.sender);
  }

  function withdraw() external {
    // Uncomment this line, and the import of "hardhat/console.sol", to print a log in your terminal
    // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);

    require(block.timestamp >= unlockTime, "You can't withdraw yet");
    address payable _owner = owner;
    require(msg.sender == _owner, "You aren't the owner");

    emit Withdrawal(address(this).balance, block.timestamp);

    _owner.transfer(address(this).balance);

    uint256 randomNumber = uint256(keccak256(abi.encode(blockhash(block.number + 5))));
  }

  function commit(bytes signature) external {
    uint256 targetBlock = block.number + 17;
    userCommitments[msg.sender] = signature;
  }

  function reveal(uint256 numberSigned, uint256 houseSigned) external {
    bytes memory signature = userCommitments[msg.sender];
    if (ECDSA.recover(keccak256(abi.encode(numberSigned, houseSigned)), signature) != msg.sender) revert();
    uint256 seed = keccak256(abi.encode(gasPrice(), numberSigned, msg.sender, numberSigned * uint256(msg.sender)));
  }

  function mint(uint256 seed_) external {
    uint256 id = uint256(keccak256(abi.encode(seed_, block.timetamp ^ seed_)));
    if (id < 25) rarity[id] = uint256(IdRarity.Rare);
    uint256 attribute = uint256(keccak256(abi.encode(seed_, msg.sender, block.timestamp, seed_ ^ msg.sender)));
  }
}
