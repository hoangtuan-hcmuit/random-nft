// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./interfaces/IERC721R.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

/// @custom:security-contact tuanmeo@gmail.com
contract ERC721R is
  IERC721R,
  UUPSUpgradeable,
  EIP712Upgradeable,
  ERC721Upgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable,
  ERC721BurnableUpgradeable,
  ERC721EnumerableUpgradeable
{
  using ECDSAUpgradeable for *;
  using MerkleProofUpgradeable for *;

  /// @dev value is equal to keccak256("ERC721R_v1")
  bytes32 public constant VERSION = 0x5e0552f6dd362c5662d2fa5933e126337ae8694639a8f14cda60fa3df2995615;

  /// @dev value is equal to keccak256("PAUSER_ROLE")
  bytes32 public constant PAUSER_ROLE = 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;
  /// @dev value is equal to keccak256("MINTER_ROLE")
  bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
  /// @dev value is equal to keccak256("UPGRADER_ROLE")
  bytes32 public constant UPGRADER_ROLE = 0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3;
  /// @dev value is equal to keccak256("OPERATOR_ROLE")
  bytes32 public constant OPERATOR_ROLE = 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;

  uint256 private constant __RANDOM_BIT = 64;
  uint256 private constant __CUP_MASK = 0xccccccccccccccc; // 5%
  uint256 private constant __MASCOT_MASK = 0x1999999999999999; // 5%
  uint256 private constant __QATAR_MASK = 0x4ccccccccccccccc; // 20%
  uint256 private constant __SHOE_MASK = 0x7fffffffffffffff; // 20%

  /// @dev value is equal to keccak256("Permit(address user,uint256 userSeed,bytes32 houseSeed,uint256 deadline,uint256 nonce)")
  bytes32 private constant __PERMIT_TYPE_HASH = 0xc02a18540b1f8010e03e4c5817e47f97371234f484e9bfa5b8d7423d54fad488;

  bytes32 public root;
  address public signer;
  uint256 public globalNonces;
  uint256 public tokenIdTracker;

  mapping(address => uint256) public signingNonces;
  mapping(address => CommitInfo) public commitments;
  mapping(uint8 => uint64[]) public attributePercentageMask;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() payable {
    _disableInitializers();
  }

  function initialize() external initializer {
    __Pausable_init_unchained();
    __AccessControl_init_unchained();
    __ERC721Burnable_init_unchained();
    __UUPSUpgradeable_init_unchained();
    __ERC721Enumerable_init_unchained();
    __ERC721_init_unchained("ERC721R", "MTK");
    __EIP712_init_unchained(type(ERC721R).name, "1");

    address sender = _msgSender();
    _grantRole(PAUSER_ROLE, sender);
    _grantRole(MINTER_ROLE, sender);
    _grantRole(UPGRADER_ROLE, sender);
    _grantRole(OPERATOR_ROLE, sender);
    _grantRole(DEFAULT_ADMIN_ROLE, sender);
  }

  function setSigner(address signer_) external onlyRole(OPERATOR_ROLE) {
    signer = signer_;
  }

  function commit(bytes32 commitment_) external {
    address user = _msgSender();
    CommitInfo memory commitInfo;
    unchecked {
      commitInfo = CommitInfo({
        commit: commitment_,
        blockNumberStart: block.number + 1,
        blockNumberEnd: block.number + 15
      });
    }
    emit Commited(user, commitInfo);

    commitments[user] = commitInfo;
  }

  function mintRandom(uint256 userSeed_, bytes32 houseSeed_, uint256 deadline_, bytes calldata signature_) external {
    address user = _msgSender();
    require(block.timestamp < deadline_, "NFT: EXPIRED");

    CommitInfo memory commitInfo = commitments[user];
    require(
      _hashTypedDataV4(
        keccak256(abi.encode(__PERMIT_TYPE_HASH, user, userSeed_, houseSeed_, deadline_, ++signingNonces[user]))
      ).recover(signature_) == signer,
      "NFT: INVALID_SIGNATURE"
    );

    __mintRandom(commitInfo, user, userSeed_, houseSeed_);
  }

  // ok chua thay
  function mintRandom(uint256 userSeed_, bytes32 houseSeed_, bytes32[] calldata proofs_) external {
    require(proofs_.verify(root, houseSeed_), "NFT: INVALID_HOUSE_SEED");

    address user = _msgSender();
    CommitInfo memory commitInfo = commitments[user];
    __mintRandom(commitInfo, user, userSeed_, houseSeed_);
  }

  function metadataOf(uint256 tokenId_) external view returns (uint256 rarity_, uint256 attributeId_) {
    require(ownerOf(tokenId_) != address(0), "NFT: NOT_EXISTED");
    unchecked {
      rarity_ = tokenId_ & ((1 << 3) - 1);
      attributeId_ = (tokenId_ >> 3) & ((1 << 3) - 1);
    }
  }

  function updateAttributePercentMask(
    uint256 rarity_,
    uint64[] memory percentageMask_
  ) external onlyRole(OPERATOR_ROLE) {
    attributePercentageMask[uint8(rarity_)] = percentageMask_;
  }

  function setRoot(bytes32 root_) external onlyRole(OPERATOR_ROLE) {
    root = root_;
  }

  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function safeMint(address to_, uint256 tokenId_) external onlyRole(MINTER_ROLE) {
    _safeMint(to_, tokenId_);
  }

  function __mintRandom(CommitInfo memory commitInfo, address user, uint256 userSeed_, bytes32 houseSeed_) private {
    uint256 revealBlock;
    unchecked {
      revealBlock = (commitInfo.blockNumberEnd - commitInfo.blockNumberStart) >> 1;
    }
    assert(blockhash(revealBlock) != 0);

    require(block.number > revealBlock, "NFT: REVEAL_NOT_YET_STARTED");
    require(block.number < commitInfo.blockNumberEnd, "NFT: REVEAL_EXPIRED");

    require(keccak256(abi.encode(houseSeed_, userSeed_, user)) == commitInfo.commit, "NFT: INVALID_REVEAL");
    delete commitments[user];

    uint256 seed;
    unchecked {
      seed = uint256(
        keccak256(
          abi.encode(
            user,
            ++globalNonces,
            userSeed_,
            houseSeed_,
            address(this),
            blockhash(revealBlock),
            blockhash(block.number - 1),
            blockhash(block.number - 2)
          )
        )
      );
    }

    seed <<= 96;
    seed >>= 96;

    uint256 rarity;
    if (seed < __CUP_MASK) rarity = uint256(Rarity.CUP);
    if (seed < __MASCOT_MASK) rarity = uint256(Rarity.MASCOT);
    if (seed < __QATAR_MASK) rarity = uint256(Rarity.QATAR);
    if (seed < __SHOE_MASK) rarity = uint256(Rarity.SHOE);
    else rarity = uint256(Rarity.BALL);

    seed = uint256(keccak256(abi.encode(seed ^ block.timestamp, user)));
    seed <<= 96;
    seed >>= 96;

    uint256 attributeId;
    uint64[] memory percentageMask = attributePercentageMask[uint8(rarity)];
    uint256 length = percentageMask.length;
    for (uint256 i; i < length; ) {
      if (seed < percentageMask[i]) {
        attributeId = i;
        break;
      }
      unchecked {
        ++i;
      }
    }
    uint256 tokenId;
    unchecked {
      tokenId = (++tokenIdTracker << 6) | (attributeId << 3) | rarity;
    }

    _mint(user, tokenId);

    emit Unboxed(user, tokenId, rarity, attributeId);
  }

  function _beforeTokenTransfer(
    address from_,
    address to_,
    uint256 tokenId_,
    uint256 batchSize_
  ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) whenNotPaused {
    super._beforeTokenTransfer(from_, to_, tokenId_, batchSize_);
  }

  function _authorizeUpgrade(address newImplementation_) internal override onlyRole(UPGRADER_ROLE) {}

  // The following functions are overrides required by Solidity.

  function supportsInterface(
    bytes4 interfaceId_
  ) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId_);
  }
}
