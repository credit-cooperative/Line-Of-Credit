const { ethers, upgrades } = require("hardhat");

async function main() {
    // Deploying the implementation contract
    const HumaRainPoolImplementation = await ethers.getContractFactory("HumaRainPoolImplementation");
    const humaRainPoolImplementation = await upgrades.deployProxy(HumaRainPoolImplementation, [/* constructor arguments */], { initializer: 'initialize' });
    await humaRainPoolImplementation.deployed();

    console.log("HumaRainPoolImplementation deployed to:", humaRainPoolImplementation.address);

    // Deploying the TransparentUpgradeableProxy
    // The OpenZeppelin upgrades plugin handles this for you
    // The address of the proxy is the address of humaRainPoolImplementation
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
