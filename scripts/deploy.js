const { ethers } = require("hardhat");

async function main() {
  const ArtLinkProtocol = await ethers.getContractFactory("ArtLinkProtocol");
  const artLinkProtocol = await ArtLinkProtocol.deploy();

  await artLinkProtocol.deployed();

  console.log("ArtLinkProtocol contract deployed to:", artLinkProtocol.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
