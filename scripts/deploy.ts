import { Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";

async function main() {
  //const [deployer] = await ethers.getSigner
  //s();
  const ERC721R: ContractFactory = await ethers.getContractFactory("ERC721R");
  const nftRandom: Contract = await upgrades.deployProxy(
    ERC721R,
    ["WC22 Pieces", "PIECES", "ipfs://bafybeih7yufwy72kb3dxxmkecc7hffbl6irbktqvhb2l5uefvxf4e4td6e", ".json"],
    { kind: "uups", initializer: "init" },
  );
  await nftRandom.deployed();

  console.log("ERC721R Proxy Contract deployed to: ", nftRandom.address);
  console.log(
    "ERC721R Implementation deployed to: ",
    await upgrades.erc1967.getImplementationAddress(nftRandom.address),
  );

  // const CommitUtil: ContractFactory = await ethers.getContractFactory("CommitUtil");
  // const commitUtil: Contract = await CommitUtil.deploy();
  // await commitUtil.deployed();
  // console.log("CommitUtil deployed to ", commitUtil.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
