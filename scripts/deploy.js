const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const Asset = await hre.ethers.getContractFactory("Asset");
    const asset = await Asset.deploy("Asset", "AST");
    await asset.deployed();
    console.log("Asset contract deployed at:", asset.address);

    const AssetMarketplace = await hre.ethers.getContractFactory("AssetMarketplace");
    const assetMarketplace = await AssetMarketplace.deploy();
    await assetMarketplace.deployed();
    console.log("AssetMarketplace contract deployed at:", assetMarketplace.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
