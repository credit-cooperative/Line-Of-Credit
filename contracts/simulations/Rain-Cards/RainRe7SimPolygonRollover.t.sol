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

interface IRainCollateralFactory {
    function controller() external view returns (address);

    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function updateController(address _controller) external;

    function createCollateralContract(string calldata _name, address _user) external returns (address);
}

interface IRainCollateralBeacon {
    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;
}

contract RainRe7SimPolygon is Test {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // Interfaces
    // PolygonOracle oracle;

    // ISpigot spigot;
    ISpigot.Setting private settings1;
    ISpigot.Setting private settings2;
    ISpigot.Setting private settings3;
    // ISecuredLine securedLine;
    ILineOfCredit line;
    // ISpigotedLine spigotedLine;
    // IEscrow escrow;

    // LineOfCredit line;
    SecuredLine securedLine;
    LineOfCredit newLine;
    Escrow escrow;
    Spigot spigot;

    IRainCollateralFactory rainCollateralFactory;
    IRainCollateralController rainCollateralController;
    IRainCollateralBeacon rainCollateralBeacon;

    // Credit Coop Infra Addresses
    PolygonOracle oracle;

    // address constant oracleAddress = 0x570ff5021d3F4bAFb8c688d73ECD13A43FaB4304;
    // address oracleAddress;
    address constant oracleAddress = 0xF1baA8242e3AAF65D4Eb030459854cddE209acb9;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    // Rain Cards Borrower Address
    address constant rainBorrower = 0x318ea64575feA5333c845bccEb5A6211952283AD; // Rain Borrower Address
    address lenderAddress = makeAddr("lender");

    // Rain Controller Contract & Associated Addresses
    address rainCollateralFactoryAddress = 0x3F95401d768F90Ab529060121499CDa7Dc8d95b1;
    address rainCollateralControllerAddress = 0x5d5Cef756412045617415FC78D510003238EAfFd;
    address rainCollateralBeaconAddress = 0xD75242e1814aa587905d9Fbd6be6D456063F50f1;
    address rainControllerAdminAddress = 0xB92949bdF09F4193599Ae7700211751ab5F74aCd;
    address rainFactoryOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;
    address rainControllerOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;
    address rainTreasuryContractAddress = 0x318ea64575feA5333c845bccEb5A6211952283AD;
    address rainCollateralBeaconOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;

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
    address public securedLineAddress; // Line address, to be defined in setUp()

    // Asset Addresses
    address constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant MATIC = 0x0000000000000000000000000000000000001010;

    // Money Vars
    uint256 MAX_INT = type(uint256).max;

    // Loan Terms
    uint256 ttl = 45 days;
    uint32 minCRatio = 0; // BPS
    uint8 revenueSplit = 50;
    uint256 loanSizeInUSDC = 40000 * 10 ** 6; // TODO: 40000
    uint128 dRate = 1000; // BPS
    uint128 fRate = 1000; // BPS

    // Fork Settings
    // uint256 constant FORK_BLOCK_NUMBER = 45_626_437; //17_638_122; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
    uint256 constant FORK_BLOCK_NUMBER = 45_828_079; //17_638_122; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
    uint256 polygonFork;

    event log_named_bytes4(string key, bytes4 value);

    constructor() {}

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(polygonFork);
        // oracle = new PolygonOracle();
        // oracleAddress = address(oracle);
        // int256 price = oracle.getLatestAnswer(USDC);

        emit log_named_string("- rpc", vm.envString("MAINNET_RPC_URL"));
        emit log_named_address("- borrower", rainBorrower);
        emit log_named_address("- lender", lenderAddress);

        // Create  Interfaces for CC infra

        // Deal MATIC assets to all 3 parties (borrower, lender, arbiter)
        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);
        // vm.deal(rainControllerOwnerAddress, 100 ether);
        // deal(MATIC, rainControllerOwnerAddress, 100 ether);

        deal(USDC, lenderAddress, loanSizeInUSDC);

        // Deal USDC to Rain (Fake) User Addresses
        deal(USDC, rainUser0, rainUser0Amount);
        deal(USDC, rainUser1, rainUser1Amount);
        deal(USDC, rainUser2, rainUser2Amount);
        deal(USDC, rainUser3, rainUser3Amount);
        deal(USDC, rainUser4, rainUser4Amount);

        // Define Interface for Rain Collateral Factory & Controller
        rainCollateralFactory = IRainCollateralFactory(rainCollateralFactoryAddress);
        rainCollateralController = IRainCollateralController(rainCollateralControllerAddress);
        rainCollateralBeacon = IRainCollateralBeacon(rainCollateralBeaconAddress);
    }

    ///////////////////////////////////////////////////////
    //             S C E N A R I O   T E S T             //
    ///////////////////////////////////////////////////////

    function test_rain_re7_simulation_polygon() public {
        // Deploy Credit Coop Factory Contracts
        ModuleFactory moduleFactory = new ModuleFactory();
        LineFactory lineFactory = new LineFactory(
            address(moduleFactory),
            arbiterAddress,
            oracleAddress,
            payable(zeroExSwapTarget)
        );

        // Borrower Deploys Line of Credit
        emit log_named_string("\n \u2713 Borrower Deploys Line of Credit", "");
        securedLineAddress = _deployLoCWithConfig(lineFactory);

        // Define interfaces for all CC modules
        line = ILineOfCredit(securedLineAddress);

        // Check status == ACTIVE after LOC is deployed
        uint256 status = uint256(line.status());
        assertEq(1, status);
        emit log_named_uint("- status (1 == ACTIVE) ", status);
        delete status;

        // Credit Coop Arbiter adds Rain Collateral Controller to Spigot
        vm.startPrank(arbiterAddress);
        // bytes4 claimFunc = _getSelector("liquidateAsset(address,address[],uint256[])");
        // push payment
        bytes4 claimFunc = bytes4(0);
        bytes4 newOwnerFunc = _getSelector("transferOwnership(address)");

        emit log_named_string("\n \u2713 Arbiter Adds Rain Collateral Controller as Revenue Contract to Spigot", "");
        _initSpigot(revenueSplit, claimFunc, newOwnerFunc);

        // Credit Coop Arbiter Whitelists Functions for Rain's Normal Operations
        emit log_named_string("\n \u2713 Arbiter Whitelists increaseNonce function", "");
        bytes4 whitelistedFunc1 = _getSelector("increaseNonce(address)");
        securedLine.updateWhitelist(whitelistedFunc1, true);
        assertEq(true, ISpigot(securedLine.spigot()).isWhitelisted(whitelistedFunc1));
        delete whitelistedFunc1;

        emit log_named_string("\n \u2713 Arbiter Whitelists creaetCollateralContract function", "");
        bytes4 whitelistedFunc2 = _getSelector("createCollateralContract(string,address)");
        securedLine.updateWhitelist(whitelistedFunc2, true);
        assertEq(true, ISpigot(securedLine.spigot()).isWhitelisted(whitelistedFunc2));
        delete whitelistedFunc2;

        vm.stopPrank();

        // OPTIONAL - Rain transfers ownership of Rain Collateral Factory to a Joint Multisig
        // TODO

        // Rain transfers ownership of Rain Collateral Controller to Spigot
        // Rain updates updateTreasury to Spigot address in Rain Collateral Controller
        // Rain updates updateControllerAdmin to Spigot address in Rain Collateral Controller
        vm.startPrank(rainControllerOwnerAddress);
        emit log_named_string("\n \u2713 Rain Collateral Controller Owner Sets Spigot as Treasury", "");
        rainCollateralController.updateTreasury(address(securedLine.spigot()));
        assertEq(address(securedLine.spigot()), rainCollateralController.treasury());

        // TODO: Skip this step because Rain will call liquidateAsset directly from the Controller contract
        // emit log_named_string("\n \u2713 Rain Collateral Controller Owner Sets Controller Admin as Spigot", "");
        // rainCollateralController.updateControllerAdmin(address(securedLine.spigot()));
        // assertEq(address(securedLine.spigot()), rainCollateralController.controllerAdmin());

        emit log_named_string("\n \u2713 Rain Collateral Controller Owner Transfers Ownership to Spigot", "");
        rainCollateralController.transferOwnership(address(securedLine.spigot()));
        assertEq(address(securedLine.spigot()), rainCollateralController.owner());

        vm.stopPrank();

        // Rain Collateral Factory Owner Transfers Ownership to Rain Collateral Controller Owner
        vm.startPrank(rainFactoryOwnerAddress);
        rainCollateralFactory.transferOwnership(address(securedLine.spigot()));
        assertEq(address(securedLine.spigot()), rainCollateralFactory.owner());

        vm.stopPrank();

        // Rain Collateral Beacon Owner Transfers Ownership to Rain Collateral Controller Owner

        vm.startPrank(rainCollateralBeaconOwnerAddress);

        rainCollateralBeacon.transferOwnership(address(securedLine.spigot()));
        assertEq(address(securedLine.spigot()), rainCollateralBeacon.owner());

        vm.stopPrank();


        // Re7 proposes position
        // Rain accepts position
        bytes32 positionId = _lenderFundLoan();
        emit log_named_bytes32("- positionId ", positionId);

        // check that the line position has the credit funds
        uint256 balance = IERC20(USDC).balanceOf(securedLineAddress);
        emit log_named_uint("- balance of Line of Credit (USDC): ", balance);
        assertEq(balance, loanSizeInUSDC);

        // Rain draws down full amount
        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 Borrower Borrows Full Amount from Line of Credit", "");
        securedLine.borrow(positionId, loanSizeInUSDC);
        emit log_named_uint("- Rain Borrower Ending Balance ", IERC20(USDC).balanceOf(rainBorrower));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Line Operator Calls increaseNonce Function on Rain Collateral Contract 0", "");

        vm.startPrank(rainControllerOwnerAddress);
        uint256 startingNonce = rainCollateralController.nonce(rainCollateralContract0);
        emit log_named_uint("- Rain Collateral 0 - Starting Nonce", startingNonce);

        bytes4 increaseNonceFunc = rainCollateralController.increaseNonce.selector;
        bytes memory increaseNonceData = abi.encodeWithSelector(increaseNonceFunc, address(rainCollateralContract0));
        bool isNonceIncreased = spigot.operate(rainCollateralControllerAddress, increaseNonceData);
        uint256 endingNonce = rainCollateralController.nonce(rainCollateralContract0);
        emit log_named_uint("- Rain Collateral 0 - Ending Nonce", endingNonce);
        assertEq(true, isNonceIncreased);
        assertEq(endingNonce, startingNonce + 1);

        bytes4 createCollateralContractFunc = rainCollateralFactory.createCollateralContract.selector;
        bytes memory createCollateralContractData = abi.encodeWithSelector(
            createCollateralContractFunc,
            "Rain Collateral 1",
            address(10)
        );
        bool isCollateralContractCreated = spigot.operate(rainCollateralFactoryAddress, createCollateralContractData);
        assertEq(true, isCollateralContractCreated);

        vm.stopPrank();

        // fast forward 45 days
        emit log_named_string("\n<---------- Fast Forward 45 Days --------------------> ", "");
        vm.warp(block.timestamp + (ttl - 1 days));

        emit log_named_string("\n \u2713 Line Operator Calls increaseNonce Function on Rain Collateral Contract 1", "");
        vm.startPrank(rainControllerOwnerAddress);
        uint256 startingNonce1 = rainCollateralController.nonce(rainCollateralContract1);
        emit log_named_uint("- Rain Collateral 1 - Starting Nonce", startingNonce1);
        bytes memory increaseNonceData1 = abi.encodeWithSelector(increaseNonceFunc, address(rainCollateralContract1));
        bool isNonceIncreased1 = spigot.operate(rainCollateralControllerAddress, increaseNonceData1);
        uint256 endingNonce1 = rainCollateralController.nonce(rainCollateralContract1);
        emit log_named_uint("- Rain Collateral 1 - Ending Nonce", endingNonce1);
        assertEq(true, isNonceIncreased1);
        assertEq(endingNonce1, startingNonce1 + 1);
        vm.stopPrank();

        // Rain Collateral Contracts 0 - 3 receive USDC deposits from Rain Card users
        emit log_named_string("\n \u2713 Rain User 0 Transfers USDC to Rain Collateral Contract 0 ", "");
        vm.startPrank(rainUser0);
        emit log_named_uint("- Rain User 0 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser0));
        emit log_named_uint(
            "- Rain Collateral Contract 0 - Starting USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract0)
        );
        IERC20(USDC).transfer(address(rainCollateralContract0), rainUser0Amount);
        emit log_named_uint("- Rain User 0 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser0));
        emit log_named_uint(
            "- Rain Collateral Contract 0 - Ending USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract0)
        );
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 1 Transfers USDC to Rain Collateral Contract 1", "");
        vm.startPrank(rainUser1);
        emit log_named_uint("- Rain User 1 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser1));
        emit log_named_uint(
            "- Rain Collateral Contract 1 - Starting USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract1)
        );
        IERC20(USDC).transfer(address(rainCollateralContract1), rainUser1Amount);
        emit log_named_uint("- Rain User 1 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser1));
        emit log_named_uint(
            "- Rain Collateral Contract 1 - Ending USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract1)
        );
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 2 Transfers USDC to Rain Collateral Contract 2 ", "");
        vm.startPrank(rainUser2);
        emit log_named_uint("- Rain User 2 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser2));
        emit log_named_uint(
            "- Rain Collateral Contract 2 - Starting USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract2)
        );
        IERC20(USDC).transfer(address(rainCollateralContract2), rainUser2Amount);
        emit log_named_uint("- Rain User 2 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser2));
        emit log_named_uint(
            "- Rain Collateral Contract 2 - Ending USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract2)
        );
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 3 Transfers USDC to Rain Collateral Contract 3", "");
        vm.startPrank(rainUser3);
        emit log_named_uint("- Rain User 3 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser3));
        emit log_named_uint(
            "- Rain Collateral Contract 3 - Starting USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract3)
        );
        IERC20(USDC).transfer(address(rainCollateralContract3), rainUser3Amount);
        emit log_named_uint("- Rain User 3 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser3));
        emit log_named_uint(
            "- Rain Collateral Contract 3 - Ending USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract3)
        );
        emit log_named_string("\n \u2713 Rain User 4 Transfers USDC to Rain Collateral Contract 4", "");
        vm.startPrank(rainUser4);
        emit log_named_uint("- Rain User 4 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser4));
        emit log_named_uint(
            "- Rain Collateral Contract 4 - Starting USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract4)
        );
        IERC20(USDC).transfer(address(rainCollateralContract4), rainUser4Amount);
        emit log_named_uint("- Rain User 4 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser4));
        emit log_named_uint(
            "- Rain Collateral Contract 4 - Ending USDC Balance ",
            IERC20(USDC).balanceOf(rainCollateralContract4)
        );
        vm.stopPrank();

        // Rain calls liquidateAsset function on each Rain Collateral Contract to transfer USDC to Treasury (Spigot)
        emit log_named_string("\n \u2713 Rain Calls liquidateAsset on Rain Collateral Contracts", "");
        vm.startPrank(rainControllerAdminAddress);
        address admin = rainCollateralController.controllerAdmin();
        emit log_named_address("- Rain Collateral Controller Admin", admin);
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        assets[0] = address(USDC);
        amounts[0] = rainUser0Amount;

        (uint256 startingSpigotBalance0, uint256 endingSpigotSpigotBalance0) = _liquidateCollateralContractAssets(rainCollateralContract0, rainUser0Amount, assets, amounts);

        (uint256 startingSpigotBalance1, uint256 endingSpigotSpigotBalance1) = _liquidateCollateralContractAssets(rainCollateralContract1, rainUser1Amount, assets, amounts);

        (uint256 startingSpigotBalance2, uint256 endingSpigotSpigotBalance2) = _liquidateCollateralContractAssets(rainCollateralContract2, rainUser2Amount, assets, amounts);

        (uint256 startingSpigotBalance3, uint256 endingSpigotSpigotBalance3) = _liquidateCollateralContractAssets(rainCollateralContract3, rainUser3Amount, assets, amounts);

        (uint256 startingSpigotBalance4, uint256 endingSpigotSpigotBalance4) = _liquidateCollateralContractAssets(rainCollateralContract4, rainUser4Amount, assets, amounts);

        vm.stopPrank();

        // Rain calls claimRevenue function on Spigot which calls liquidateAsset (Spigot) to transfer USDC from Rain Collateral Contracts to Treasury (Spigot)
        // TODO: convert memory to calldata to save gas
        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 [Borrower] Calls the Spigot Claim Function", "");

        uint256 claimedFromSpigot = _claimRevenueOnBehalfOfSpigot(
            bytes4(0),
            rainCollateralContract0
        );
        assertEq(finalSpigotBalance, IERC20(USDC).balanceOf(address(spigot)));

        vm.stopPrank();

        // Rain claims their portion of cash flows from Spigot w/ claimOperatorTokens
        vm.startPrank(rainControllerOwnerAddress);
        emit log_named_string("\n \u2713 [Borrower] Calls the Spigot Claim Operator Tokens Function", "");
        emit log_named_uint("- Spigot USDC balance: ", IERC20(USDC).balanceOf(address(spigot)));
        emit log_named_address("- Spigot operator: ", spigot.operator());
        emit log_named_address("- rain controller owner: ", rainControllerOwnerAddress);
        uint256 claimedOperatorTokens = spigot.claimOperatorTokens(address(USDC));
        emit log_named_uint("- Rain Borrower - Claimed Operator Tokens ", claimedOperatorTokens);
        assertEq(claimedOperatorTokens, finalOperatorTokensBalance);
        assertEq(finalOperatorTokensBalance, IERC20(USDC).balanceOf(address(spigot)));
        vm.stopPrank();

        // interest accrued
        bytes32 id = securedLine.ids(0);
        emit log_named_bytes32("id", id);
        uint256 interestAccrued = securedLine.interestAccrued(id);
        emit log_named_uint("- Interest Accrued ", interestAccrued);

        // Rain claims and repay the full balance, principal plus interest, of the Line of Credit
        emit log_named_string("\n \u2713 Arbiter Calls ClaimAndRepay to Repay Line of Credit with Spigot Revenue", "");
        vm.startPrank(arbiterAddress);
        emit log_named_uint("- Owner Tokens in Spigot before repayment: ", spigot.getOwnerTokens(USDC));
        assertEq(finalOwnerTokensBalance, spigot.getOwnerTokens(USDC));
        uint256 rainBorrowerStartingBalance = IERC20(USDC).balanceOf(rainBorrower);

        securedLine.claimAndRepay(address(USDC), "");
        assertEq(0, spigot.getOwnerTokens(USDC));
        emit log_named_uint("- Owner Tokens in Spigot after repayment: ", spigot.getOwnerTokens(USDC));
        vm.stopPrank();

        // Rain closes the Line of Credit
        emit log_named_string("\n \u2713 Borrower Calls close Function to Close Line of Credit", "");
        vm.startPrank(rainBorrower);
 

        securedLine.close(id);

        // Check status == REPAID after position is repaid and closed
        uint256 statusIsRepaid = uint256(securedLine.status());
        assertEq(3, statusIsRepaid);
        emit log_named_uint("- status (3 == REPAID) ", statusIsRepaid);

        vm.stopPrank();

        // Rain sweeps the remaining unused assets from the line of credit
        emit log_named_string(
            "\n \u2713 Borrower Calls sweep Function to Regain Ownership of Unused Assets From Line of Credit",
            ""
        );
        vm.startPrank(rainBorrower);

        uint256 unusedTokensAfterClose0 = securedLine.unused(USDC);

        emit log_named_uint(
            " - Unused Tokens after Position is closed and line is repaid (before sweep)",
            unusedTokensAfterClose0
        );

        securedLine.sweep(rainBorrower, address(USDC), unusedTokensAfterClose0);

        uint256 unusedTokensAfterClose1 = securedLine.unused(USDC);

        emit log_named_uint(
            " - Unused Tokens after Position is closed and line is repaid (after sweep)",
            unusedTokensAfterClose1
        );

        assertEq(0, unusedTokensAfterClose1);
        emit log_named_uint(" - remaining spigot assets ", IERC20(USDC).balanceOf(address(spigot)));
        emit log_named_uint(" - remaining line assets ", IERC20(USDC).balanceOf(address(securedLine)));

        vm.stopPrank();

        // Lender withdraws principal + interest owed
        vm.startPrank(lenderAddress);
        emit log_named_string("\n \u2713 Lender Withdraws All Repaid Principal and Interest", "");
        emit log_named_uint("- Withdrawal Amount: ", interestAccrued + loanSizeInUSDC);
        securedLine.withdraw(id, interestAccrued + loanSizeInUSDC);
        uint256 lenderBalanceAfterRepayment = IERC20(USDC).balanceOf(lenderAddress);
        uint256 borrowerBalanceAfterRepayment = IERC20(USDC).balanceOf(rainBorrower);

        // check that the lender balance is principal + interest
        emit log_named_uint(" - Lender Balance After Repayment ", lenderBalanceAfterRepayment);
        emit log_named_uint(
            " - Borrower Repayment Amount ",
            borrowerBalanceAfterRepayment - rainBorrowerStartingBalance
        );
        emit log_named_uint(" - Line Balance After Repayment ", IERC20(USDC).balanceOf(address(securedLine)));
        assertEq(lenderBalanceAfterRepayment, loanSizeInUSDC + interestAccrued, "Lender has not been fully repaid");
        assertEq(
            finalOwnerTokensBalance,
            lenderBalanceAfterRepayment + borrowerBalanceAfterRepayment - rainBorrowerStartingBalance
        );
        vm.stopPrank();

        // Borrower Rolls Over to new LoC


        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 Borrower rolls over Spigot and Escrow modules to a new LoC", "");
        newLine = new LineOfCredit(
            address(oracle),
            arbiterAddress,
            rainBorrower,
            ttl
        );

        securedLine.rollover(address(newLine));

        vm.stopPrank();

    }

    ///////////////////////////////////////////////////////
    //          I N T E R N A L   H E L P E R S          //
    ///////////////////////////////////////////////////////

    function _deployLoCWithConfig(LineFactory lineFactory) internal returns (address) {
        // create Escrow and Spigot
        escrow = new Escrow(minCRatio, oracleAddress, rainControllerOwnerAddress, rainBorrower);
        spigot = new Spigot(rainControllerOwnerAddress, rainControllerOwnerAddress);

        // create SecuredLine
        emit log_named_address(" - create new line with oracle ", oracleAddress);
        securedLine = new SecuredLine(
            oracleAddress,
            arbiterAddress,
            rainBorrower,
            payable(zeroExSwapTarget),
            address(spigot),
            address(escrow),
            ttl,
            revenueSplit
        );

        // transfer ownership of both Spigot and Escrow to SecuredLine
        vm.startPrank(rainControllerOwnerAddress);
        spigot.updateOwner(address(securedLine));
        escrow.updateLine(address(securedLine));
        vm.stopPrank();

        // call init() on Line of Credit, register on Line Factory
        securedLine.init();
        console.log("3");

        // Arbiter registers Spigot, Escrow, and SecuredLine using Factory Contracts to appear in Subgraph & Dapp
        vm.startPrank(arbiterAddress);

        lineFactory.registerSecuredLine(
            address(securedLine),
            address(spigot),
            address(escrow),
            rainBorrower,
            rainBorrower,
            revenueSplit,
            minCRatio
        );

        vm.stopPrank();

        return address(securedLine);
    }

    function _liquidateCollateralContractAssets(
        address rainCollateralContract,
        uint256 amount,
        address[] memory assets,
        uint256[] memory amounts
    ) internal returns (uint256, uint256) {
        emit log_named_address("\n - Rain Collateral Contract ", rainCollateralContract);
        amounts[0] = amount;
        uint256 startingSpigotBalance = IERC20(USDC).balanceOf(address(spigot));
        emit log_named_uint("- starting Spigot balance ", startingSpigotBalance);
        rainCollateralController.liquidateAsset(rainCollateralContract, assets, amounts);
        uint256 endingSpigotBalance = IERC20(USDC).balanceOf(address(spigot));
        emit log_named_uint("- ending Spigot balance ", endingSpigotBalance);
        return (startingSpigotBalance, endingSpigotBalance);
    }

    function _claimRevenueOnBehalfOfSpigot(
        bytes4 claimFunc,
        address rainCollateralContract
    ) internal returns (uint256) {
        bytes memory claimFuncData = abi.encodeWithSelector(claimFunc);

        emit log_named_address("\n - Rain Collateral Contract ", rainCollateralContract);
        uint256 startingSpigotBalance = IERC20(USDC).balanceOf(address(spigot));
        emit log_named_uint("- starting Spigot balance ", startingSpigotBalance);
        uint256 claimed = spigot.claimRevenue(rainCollateralControllerAddress, USDC, claimFuncData);
        uint256 endingSpigotBalance = IERC20(USDC).balanceOf(address(spigot));
        emit log_named_uint("- amount claimed from Rain Collateral Controller ", claimed);
        emit log_named_uint("- ending Spigot balance ", endingSpigotBalance);
        return claimed;
    }

    // fund a loan as a lender
    function _lenderFundLoan() internal returns (bytes32 id) {
        assertEq(vm.activeFork(), polygonFork, "mainnet fork is not active");

        emit log_named_string("\n \u2713 Lender Proposes Position to Line of Credit", "");
        vm.startPrank(lenderAddress);
        IERC20(USDC).approve(address(line), loanSizeInUSDC);
        securedLine.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInUSDC, // amount
            USDC, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        emit log_named_string("\n \u2713 Borrower Accepts Lender Proposal to Line of Credit", "");
        vm.startPrank(rainBorrower);
        emit log_named_address("- lender 1", lenderAddress);
        // int256 price = oracle.getLatestAnswer(USDC);
        int256 price = IOracle(oracleAddress).getLatestAnswer(USDC);
        emit log_named_int("- price", price);
        emit log_named_address("- USDC", USDC);
        emit log_named_uint("- loan size", loanSizeInUSDC);
        emit log_named_address("- oracleAddress", oracleAddress);
        id = securedLine.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInUSDC, // amount
            USDC, // token
            lenderAddress // lender
        );
        emit log_named_address("- lender 2", lenderAddress);
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(address(securedLine)), loanSizeInUSDC, "LoC balance doesn't match");
        emit log_named_bytes32("- credit id", id);
        return id;
    }

    ///////////////////////////////////////////////////////
    //                      U T I L S                    //
    ///////////////////////////////////////////////////////

    // returns the function selector (first 4 bytes) of the hashed signature
    function _getSelector(string memory _signature) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(_signature)));
    }

    function _initSpigot(uint8 split, bytes4 claimFunc, bytes4 newOwnerFunc) internal // bytes4[] memory _whitelist
    {
        settings1 = ISpigot.Setting(split, claimFunc, newOwnerFunc);
        settings2 = ISpigot.Setting(0, claimFunc, newOwnerFunc);
        settings3 = ISpigot.Setting(0, claimFunc, newOwnerFunc);


        // add spigot for revenue contract
        require(securedLine.addSpigot(rainCollateralControllerAddress, settings1), "Failed to add spigot");
        require(securedLine.addSpigot(rainCollateralBeaconAddress, settings2), "Failed to add spigot");
        require(securedLine.addSpigot(rainCollateralFactoryAddress, settings3), "Failed to add spigot");
    }
}
