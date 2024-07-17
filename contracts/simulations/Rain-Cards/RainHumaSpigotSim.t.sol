pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IOracle} from "../../interfaces/IOracle.sol";
import {PolygonOracle} from "../../modules/oracle/PolygonOracle.sol";
import {MockRegistry} from "../../mock/MockRegistry.sol";
import {ILineFactory} from "../../interfaces/ILineFactory.sol";
import {LineFactory} from "../../modules/factories/LineFactory.sol";
import {ModuleFactory} from "../../modules/factories/ModuleFactory.sol";
import {LineOfCredit} from "../../modules/credit/LineOfCredit.sol";
import {SpigotedLine} from "../../modules/credit/SpigotedLine.sol";
import {SecuredLine} from "../../modules/credit/SecuredLine.sol";
import {ZeroEx} from "../../mock/ZeroEx.sol";
import {ISpigotedLine} from "../../interfaces/ISpigotedLine.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {Escrow} from "../../modules/escrow/Escrow.sol";
import {ISpigot} from "../../interfaces/ISpigot.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {ILineOfCredit} from "../../interfaces/ILineOfCredit.sol";
import {ISecuredLine} from "../../interfaces/ISecuredLine.sol";

interface IRainCollateralController {
    function owner() external view returns (address);

    function controllerAdmin() external view returns (address);

    function treasury() external view returns (address);

    function nonce(address _collateralProxy) external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function updateControllerAdmin(address _controllerAdmin) external;

    function updateTreasury(address _treasury) external;

    function increaseNonce(address _collateralProxy) external;

    function liquidateAsset(address _collateralProxy, address[] calldata _assets, uint256[] calldata _amounts) external;
}

interface IHumaPool {
    function makePayment(address borrower, uint256 amount) public;
}

interface IHumaConfig {
    function setPDSServiceAccount(address accountAddress) external;
}

interface IUSDC {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract RainRe7SimPolygon is Test {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // ISpigot spigot;
    ISpigot.Setting private settings1;
    ISpigot.Setting private settings2;
    ISpigot.Setting private settings3;

    Spigot spigot;

    IRainCollateralController rainCollateralController;

    // Huma Pool Address
    address humaPoolAddress = 0x82a76045Dc4543FA4776DF1bcaD11F2AA6EA51d2;
    address humaConfigOwnerAddress = 0x4730Ba92780b6783Ce97bD5f7AaD75337d6D180A;
    address humaConfig = 0x03D80E259E34354B552fE5d152D7484192535393;

    // Polygon USDC Address
    address polygonUSDCAddress = '';

    // Rain Controller Contract & Associated Addresses
    address rainCollateralControllerAddress = 0x5d5Cef756412045617415FC78D510003238EAfFd;
    address rainControllerAdminAddress = 0xB92949bdF09F4193599Ae7700211751ab5F74aCd;
    address rainControllerOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;
    address rainTreasuryContractAddress = 0x318ea64575feA5333c845bccEb5A6211952283AD;


    // Rain Collateral Contracts 0 - 3:
    address rainCollateralContract0 = 0x3423097c1631629295185e8ae8a2586e30436f95;
    address rainCollateralContract1 = 0x22fF15C7bfDf0bfF13FfFB80ec2bC53AD1ae80C2;
    address rainCollateralContract2 = 0xc3b07b1c03E6611EE242736f94617B26668F3D03;
    address rainCollateralContract3 = 0xf2a289df573bE02Bc4ec5C1025e3298dD243a00d;
    address rainCollateralContract4 = 0x8eD1b998afB9A606B4e976AfcAccFE4b39069513;

    // Rain (Fake) User Addresses
    address rainUser0 = makeAddr("rainUser0");
    address rainUser1 = makeAddr("rainUser1");
    address rainUser2 = makeAddr("rainUser2");
    address rainUser3 = makeAddr("rainUser3");
    address rainUser4 = makeAddr("rainUser4");

    uint256 rainUser0Amount = (30000 / 5) * 10 ** 6;
    uint256 rainUser1Amount = (170000 / 5) * 10 ** 6;
    uint256 rainUser2Amount = (120000 / 5) * 10 ** 6;
    uint256 rainUser3Amount = (80000 / 5) * 10 ** 6;
    uint256 rainUser4Amount = (20000 / 5) * 10 ** 6;
    uint256 finalSpigotBalance =
        rainUser0Amount + rainUser1Amount + rainUser2Amount + rainUser3Amount + rainUser4Amount;
    uint256 finalOperatorTokensBalance = finalSpigotBalance / 2;
    uint256 finalOwnerTokensBalance = finalSpigotBalance / 2;

    // Credit Coop Addresses
    address constant arbiterAddress = 0xFE002526dEc5B3e4b5134b75b20c065178323343; // Credit Coop MultiSig

    // Asset Addresses
    address constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant MATIC = 0x0000000000000000000000000000000000001010;

    // Money Vars
    uint256 MAX_INT = type(uint256).max;

    // Loan Terms

    uint8 revenueSplit = 100;

    // Fork Settings
    // uint256 constant FORK_BLOCK_NUMBER = 45_626_437; //17_638_122; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
    uint256 constant FORK_BLOCK_NUMBER = 45_828_079; //17_638_122; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
    uint256 polygonFork;

    event log_named_bytes4(string key, bytes4 value);

    constructor() {}

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(polygonFork);

        emit log_named_string("- rpc", vm.envString("MAINNET_RPC_URL"));
        // Create  Interfaces for CC infra

        // Deal MATIC assets to all 3 parties (borrower, lender, arbiter)
        vm.deal(arbiterAddress, 100 ether);

        deal(USDC, lenderAddress, loanSizeInUSDC);

        // Deal USDC to Rain (Fake) User Addresses
        deal(USDC, rainUser0, rainUser0Amount);
        deal(USDC, rainUser1, rainUser1Amount);
        deal(USDC, rainUser2, rainUser2Amount);
        deal(USDC, rainUser3, rainUser3Amount);
        deal(USDC, rainUser4, rainUser4Amount);

        // Define Interface for Rain Collateral Factory & Controller
        rainCollateralController = IRainCollateralController(rainCollateralControllerAddress);
    }

    function test_rain_huma_spigot_simulation_polygon() public {
        spigot = new Spigot(arbiter, arbiter);

        bytes4 claimFunc = bytes4(0);
        bytes4 transferOwnerFunc = bytes4(0x12345678);
        uint8 split = 100;

        _initSpigot(split, claimFunc, transferOwnerFunc);
    }

    ///////////////////////////////////////////////////////
    //                      U T I L S                    //
    ///////////////////////////////////////////////////////

    // returns the function selector (first 4 bytes) of the hashed signature
    function _getSelector(string memory _signature) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(_signature)));
    }

    function _initSpigot(uint8 split, bytes4 claimFunc, bytes4 newOwnerFunc) internal
    {
        settings1 = ISpigot.Setting(split, claimFunc, newOwnerFunc);
        settings2 = ISpigot.Setting(0, claimFunc, newOwnerFunc);
        settings3 = ISpigot.Setting(0, claimFunc, newOwnerFunc);


        // add spigot for revenue contract
        require(spigot.addSpigot(rainCollateralControllerAddress, settings1), "Failed to add spigot");
        require(spigot.addSpigot(humaPoolAddress, settings2), "Failed to add spigot");
        require(spigot.addSpigot(polygonUSDCAddress, settings3), "Failed to add spigot");

        spigot.updateWhitelistedFunction(humaPoolAddress, IHumaPool.makePayment.selector, true);
        spigot.updateWhitelistedFunction(polygonUSDCAddress, IUSDC.approve.selector, true);
        spigot.updateWhitelistedFunction(polygonUSDCAddress, IUSDC.transfer.selector, false);


    }
}