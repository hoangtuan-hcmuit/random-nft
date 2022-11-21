// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract ERC1155r is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {
  // dat la commiments di thay, de public luon, viet tiep , cham phay dau thay, chua doi mapping kia
  struct CommitInfo {
    bytes32 commit;
    uint256 blockNumberStart;
    uint256 blockNumberEnd;
  }

  mapping(address => CommitInfo) public commitments;

  event Commited(address indexed user, CommitInfo indexed commitment);

  constructor() ERC1155("") {}

  function setURI(string memory newuri) public onlyOwner {
    _setURI(newuri);
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  // h viet ham reveal, tham so dau vao la so user (userSeed), so cua minh (houseSeed) r ktra xem hash(userSeed, houseSeed) co bang commit k
  // require block number luc goi phai > block start va be hon block end

  //store c vao mapping di https://solidity-by-example.org/events/
  // z v thay, pure sai r, view. pure ko dc vi no phai doc data onchain. chi can return commitments[msg.sender] la dc ma. z a' define lai mapping di thay
  function commit(bytes32 commitment_) external {
    CommitInfo memory commitInfo = CommitInfo({
      commit: commitment_,
      blockNumberStart: block.number + 1,
      blockNumberEnd: block.number + 15
    });
    emit Commited(msg.sender, commitInfo);

    commitments[msg.sender] = commitInfo;
  }

  // ok chua thay
  function reveal(uint256 userSeed, uint256 houseSeed) external {
    require(block.number > commitments[msg.sender].blockNumberStart);
    require(block.number < commitments[msg.sender].blockNumberEnd);
    bytes32 commitment = commitments[msg.sender].commit;
    require(keccak256(abi.encode(userSeed, houseSeed)) == commitment);
    // if (ECDSA.recover(keccak256(abi.encode(userSeed, houseSeed)), signature) != msg.sender) revert();
  }

  function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
    _mint(account, id, amount, data);
  }

  function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
    _mintBatch(to, ids, amounts, data);
  }

  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }
}
