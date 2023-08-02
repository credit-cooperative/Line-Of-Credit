pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IOracle} from "../../interfaces/IOracle.sol";
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

    function liquidateAsset(
        address _collateralProxy,
        address[] calldata _assets,
        uint256[] calldata _amounts
    ) external;
}

interface IRainCollateralFactory {
    function controller() external view returns (address);
    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;
    function updateController(address _controller) external;
}


contract RainRe7Sim is Test {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // Interfaces
    IOracle oracle;

    // ISpigot spigot;
    ISpigot.Setting private settings;
    // ISecuredLine securedLine;
    ILineOfCredit line;
    // ISpigotedLine spigotedLine;
    // IEscrow escrow;

    // LineOfCredit line;
    SecuredLine securedLine;
    Escrow escrow;
    Spigot spigot;

    IRainCollateralFactory rainCollateralFactory;
    IRainCollateralController rainCollateralController;

    // Credit Coop Infra Addresses
    address constant oracleAddress = 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
    // Old Line Factory Address
    // address constant lineFactoryAddress = 0x89989dBe4CFa289dE6179e8d54EE755E471a4251;

    // Rain Cards Borrower Address
    address constant rainBorrower = 0x0204C22BE67968C3B787D2699Bd05cf2b9432c60; // Rain Borrower Address
    address lenderAddress = makeAddr("lender");

    // Rain Controller Contract & Associated Addresses
    address rainCollateralFactoryAddress = 0x31EBf70312f488D0bdAc374b340f0D01dBf153B5;
    address rainCollateralControllerAddress = 0xE5D3d7da4b24bc9D2FDA0e206680CD8A00C0FeBD;
    address rainControllerAdminAddress = 0xB92949bdF09F4193599Ae7700211751ab5F74aCd;
    address rainFactoryOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;
    address rainControllerOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;
    address rainTreasuryContractAddress = 0x0204C22BE67968C3B787D2699Bd05cf2b9432c60;

    // Rain Collateral Contracts 0 - 3:
    address rainCollateralContract0 = 0xbAf9c4b4318AEfCd3a7c2ABec68eFE567c797d74;
    address rainCollateralContract1 = 0x9bf0fA5bBd9448190C9CBFe3adE8D7466913d861;
    address rainCollateralContract2 = 0x5C82f4928899a91752083dd8F1b6D8bf23D4eeb2;
    address rainCollateralContract3 = 0xCF3d82CD86b25c87dcf2Fc6d9Abe9580a8e0E981;
    address rainCollateralContract4 = 0x7030f1486Cc691F8C3e0D703671B5E6f45C940e8;

    // Rain (Fake) User Addresses
    address rainUser0 = makeAddr("rainUser0");
    address rainUser1 = makeAddr("rainUser1");
    address rainUser2 = makeAddr("rainUser2");
    address rainUser3 = makeAddr("rainUser3");
    address rainUser4 = makeAddr("rainUser4");

    uint256 rainUser0Amount = 30000 * 10 ** 6;
    uint256 rainUser1Amount = 170000 * 10 ** 6;
    uint256 rainUser2Amount = 120000 * 10 ** 6;
    uint256 rainUser3Amount = 80000 * 10 ** 6;
    uint256 rainUser4Amount = 20000 * 10 ** 6;
    uint256 finalSpigotBalance = rainUser0Amount + rainUser1Amount + rainUser2Amount + rainUser3Amount + rainUser4Amount;
    uint256 finalOperatorTokensBalance = finalSpigotBalance / 2;
    uint256 finalOwnerTokensBalance = finalSpigotBalance / 2;

    // Credit Coop Addresses
    address constant arbiterAddress = 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a ; // Credit Coop MultiSig
    address public securedLineAddress; // Line address, to be defined in setUp()

    // Asset Addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Money Vars
    uint256 MAX_INT = type(uint256).max;

    // Loan Terms
    uint256 ttl = 45 days;
    uint32 minCRatio = 0; // BPS
    uint8 revenueSplit = 50;
    uint256 loanSizeInUSDC = 200000 * 10 ** 6;
    uint128 dRate = 1000; // BPS
    uint128 fRate = 1000; // BPS

    // Fork Settings
    uint256 constant FORK_BLOCK_NUMBER = 17_638_122; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
    uint256 ethMainnetFork;

    event log_named_bytes4(string key, bytes4 value);

    constructor() {

    }

    function setUp() public {
        ethMainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(ethMainnetFork);

        emit log_named_string("- rpc", vm.envString("MAINNET_RPC_URL"));
        emit log_named_address("- borrower", rainBorrower);
        emit log_named_address("- lender", lenderAddress);

        // Create  Interfaces for CC infra
        oracle = IOracle(address(oracleAddress));

        // Deal assets to all 3 parties (borrower, lender, arbiter)
        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);

        deal(USDC, lenderAddress, 200000 * 10 ** 6);

        // Deal USDC to Rain (Fake) User Addresses
        deal(USDC, rainUser0, 30000 * 10 ** 6);
        deal(USDC, rainUser1, 170000 * 10 ** 6);
        deal(USDC, rainUser2, 120000 * 10 ** 6);
        deal(USDC, rainUser3, 80000 * 10 ** 6);
        deal(USDC, rainUser4, 20000 * 10 ** 6);

        // Define Interface for Rain Collateral Factory & Controller
        rainCollateralFactory = IRainCollateralFactory(rainCollateralFactoryAddress);
        rainCollateralController = IRainCollateralController(rainCollateralControllerAddress);

    }

    ///////////////////////////////////////////////////////
    //             S C E N A R I O   T E S T             //
    ///////////////////////////////////////////////////////

    function test_rain_re7_simulation_mainnet() public {

        // Deploy Credit Coop Factory Contracts
        ModuleFactory moduleFactory = new ModuleFactory();
        LineFactory lineFactory = new LineFactory(address(moduleFactory), arbiterAddress, oracleAddress, payable(zeroExSwapTarget));

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
        bytes4 whitelistedFunc = _getSelector("increaseNonce(address)");
        securedLine.updateWhitelist(whitelistedFunc, true);
        assertEq(true, ISpigot(securedLine.spigot()).isWhitelisted(whitelistedFunc));
        delete whitelistedFunc;

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

        // Re7 proposes position
        // Rain accepts position
        bytes32 positionId =  _lenderFundLoan();

        // check that the line position has the credit funds
        uint256 balance = IERC20(USDC).balanceOf(securedLineAddress);
        emit log_named_uint("- balance of Line of Credit (USDC): ", balance);
        assertEq(balance, loanSizeInUSDC);

        // Rain draws down full amount
        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 Borrower Borrows Full Amount from Line of Credit", "");
        securedLine.borrow(positionId, 200000 * 10 ** 6);
        emit log_named_uint("- Rain Borrower Ending Balance ", IERC20(USDC).balanceOf(rainBorrower));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Line Operator Calls increaseNonce Function on Rain Collateral Contract 0", "");

        vm.startPrank(rainControllerOwnerAddress);
        uint256 startingNonce = rainCollateralController.nonce(rainCollateralContract0);
        emit log_named_uint("- Rain Collateral 0 - Starting Nonce", startingNonce);

        bytes4 increaseNonceFunc = rainCollateralController.increaseNonce.selector;
        bytes memory increaseNonceData = abi.encodeWithSelector(
            increaseNonceFunc,
            address(rainCollateralContract0)
        );
        bool isNonceIncreased = spigot.operate(rainCollateralControllerAddress, increaseNonceData);
        uint256 endingNonce = rainCollateralController.nonce(rainCollateralContract0);
        emit log_named_uint("- Rain Collateral 0 - Ending Nonce", endingNonce);
        assertEq(true, isNonceIncreased);
        assertEq(endingNonce, startingNonce + 1);
        vm.stopPrank();

        // fast forward 45 days
        emit log_named_string("\n<---------- Fast Forward 45 Days --------------------> ", "");
        vm.warp(block.timestamp + (ttl - 1 days));

        emit log_named_string("\n \u2713 Line Operator Calls increaseNonce Function on Rain Collateral Contract 1", "");
        vm.startPrank(rainControllerOwnerAddress);
        uint256 startingNonce1 = rainCollateralController.nonce(rainCollateralContract1);
        emit log_named_uint("- Rain Collateral 1 - Starting Nonce", startingNonce1);
        bytes memory increaseNonceData1 = abi.encodeWithSelector(
            increaseNonceFunc,
            address(rainCollateralContract1)
        );
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
        emit log_named_uint("- Rain Collateral Contract 0 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract0));
        IERC20(USDC).transfer(address(rainCollateralContract0), rainUser0Amount);
        emit log_named_uint("- Rain User 0 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser0));
        emit log_named_uint("- Rain Collateral Contract 0 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract0));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 1 Transfers USDC to Rain Collateral Contract 1", "");
        vm.startPrank(rainUser1);
        emit log_named_uint("- Rain User 1 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser1));
        emit log_named_uint("- Rain Collateral Contract 1 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract1));
        IERC20(USDC).transfer(address(rainCollateralContract1), rainUser1Amount);
        emit log_named_uint("- Rain User 1 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser1));
        emit log_named_uint("- Rain Collateral Contract 1 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract1));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 2 Transfers USDC to Rain Collateral Contract 2 ", "");
        vm.startPrank(rainUser2);
        emit log_named_uint("- Rain User 2 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser2));
        emit log_named_uint("- Rain Collateral Contract 2 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract2));
        IERC20(USDC).transfer(address(rainCollateralContract2), rainUser2Amount);
        emit log_named_uint("- Rain User 2 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser2));
        emit log_named_uint("- Rain Collateral Contract 2 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract2));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 3 Transfers USDC to Rain Collateral Contract 3", "");
        vm.startPrank(rainUser3);
        emit log_named_uint("- Rain User 3 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser3));
        emit log_named_uint("- Rain Collateral Contract 3 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract3));
        IERC20(USDC).transfer(address(rainCollateralContract3), rainUser3Amount);
        emit log_named_uint("- Rain User 3 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser3));
        emit log_named_uint("- Rain Collateral Contract 3 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract3));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 4 Transfers USDC to Rain Collateral Contract 3", "");
        vm.startPrank(rainUser4);
        emit log_named_uint("- Rain User 4 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser4));
        emit log_named_uint("- Rain Collateral Contract 4 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract4));
        IERC20(USDC).transfer(address(rainCollateralContract4), rainUser4Amount);
        emit log_named_uint("- Rain User 4 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser4));
        emit log_named_uint("- Rain Collateral Contract 4 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract4));
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

        // bytes4 liquidateFunc = _getSelector("liquidateAsset(address,address[],uint256[])");

        // address[] memory assets = new address[](1);
        // uint256[] memory amounts = new uint256[](1);
        // assets[0] = address(USDC);

        // uint256 claimed0 = _claimRevenueOnBehalfOfSpigot(liquidateFunc, rainCollateralContract0, rainUser0Amount, assets, amounts);
        // assertEq(rainUser0Amount, claimed0);

        // uint256 claimed1 = _claimRevenueOnBehalfOfSpigot(liquidateFunc, rainCollateralContract1, rainUser1Amount, assets, amounts);
        // assertEq(rainUser1Amount, claimed1);

        // uint256 claimed2 = _claimRevenueOnBehalfOfSpigot(liquidateFunc, rainCollateralContract2, rainUser2Amount, assets, amounts);
        // assertEq(rainUser2Amount, claimed2);

        // uint256 claimed3 = _claimRevenueOnBehalfOfSpigot(liquidateFunc, rainCollateralContract3, rainUser3Amount, assets, amounts);
        // assertEq(rainUser3Amount, claimed3);

        // uint256 claimed4 = _claimRevenueOnBehalfOfSpigot(liquidateFunc, rainCollateralContract4, rainUser4Amount, assets, amounts);
        // assertEq(rainUser4Amount, claimed4);
        // assertEq(finalSpigotBalance, IERC20(USDC).balanceOf(address(spigot)));

        vm.stopPrank();

        // Rain claims their portion of cash flows from Spigot w/ claimOperatorTokens
        vm.startPrank(rainControllerOwnerAddress);
        emit log_named_string("\n \u2713 [Borrower] Calls the Spigot Claim Operator Tokens Function", "");
        uint256 claimedOperatorTokens = spigot.claimOperatorTokens(address(USDC));
        emit log_named_uint("- Rain Borrower - Claimed Operator Tokens ", claimedOperatorTokens);
        assertEq(claimedOperatorTokens, finalOperatorTokensBalance);
        assertEq(finalOperatorTokensBalance, IERC20(USDC).balanceOf(address(spigot)));
        vm.stopPrank();

        // interest accrued
        bytes32 creditPositionId = 0xaa91a43200d4f9f507d37cc534c773fae8d778cf8f94e15a093ac6f64a1524a6;
        uint256 interestAccrued = securedLine.interestAccrued(creditPositionId);
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
        securedLine.close(creditPositionId);

        // Check status == REPAID after position is repaid and closed
        uint256 statusIsRepaid = uint256(securedLine.status());
        assertEq(3, statusIsRepaid);
        emit log_named_uint("- status (3 == REPAID) ", statusIsRepaid);

        vm.stopPrank();

        // Rain sweeps the remaining unused assets from the line of credit
        emit log_named_string("\n \u2713 Borrower Calls sweep Function to Regain Ownership of Unused Assets From Line of Credit", "");
        vm.startPrank(rainBorrower);

        uint256 unusedTokensAfterClose0 = securedLine.unused(USDC);

        emit log_named_uint(" - Unused Tokens after Position is closed and line is repaid (before sweep)", unusedTokensAfterClose0);

        securedLine.sweep(rainBorrower, address(USDC), unusedTokensAfterClose0);

        uint256 unusedTokensAfterClose1 = securedLine.unused(USDC);

        emit log_named_uint(" - Unused Tokens after Position is closed and line is repaid (after sweep)", unusedTokensAfterClose1);

        assertEq(0, unusedTokensAfterClose1);
        emit log_named_uint(" - remaining spigot assets ", IERC20(USDC).balanceOf(address(spigot)));
        emit log_named_uint(" - remaining line assets ", IERC20(USDC).balanceOf(address(securedLine)));

        vm.stopPrank();


        // Lender withdraws principal + interest owed
        vm.startPrank(lenderAddress);
        emit log_named_string("\n \u2713 Lender Withdraws All Repaid Principal and Interest", "");
        securedLine.withdraw(creditPositionId, interestAccrued + loanSizeInUSDC);
        uint256 lenderBalanceAfterRepayment = IERC20(USDC).balanceOf(lenderAddress);
        uint256 borrowerBalanceAfterRepayment = IERC20(USDC).balanceOf(rainBorrower);

        // check that the lender balance is principal + interest
        emit log_named_uint(" - Lender Balance After Repayment ", lenderBalanceAfterRepayment);
        emit log_named_uint(" - Borrower Repayment Amount ", borrowerBalanceAfterRepayment - rainBorrowerStartingBalance);
        emit log_named_uint(" - Line Balance After Repayment ", IERC20(USDC).balanceOf(address(securedLine)));
        assertEq(lenderBalanceAfterRepayment, loanSizeInUSDC + interestAccrued, "Lender has not been fully repaid");
        assertEq(finalOperatorTokensBalance, lenderBalanceAfterRepayment + borrowerBalanceAfterRepayment - rainBorrowerStartingBalance);
        vm.stopPrank();

        // Borrower Releases Spigot
        vm.startPrank(rainBorrower);

        emit log_named_string("\n \u2713 Borrower Releases Spigot to Rain Collateral Controller Owner Address", "");
        securedLine.releaseSpigot(rainControllerOwnerAddress);
        vm.stopPrank();

        vm.startPrank(rainControllerOwnerAddress);
        emit log_named_string("\n \u2713 Borrower Removes Rain Collateral Controller from Spigot", "");
        spigot.removeSpigot(rainCollateralControllerAddress);

        assertEq(rainControllerOwnerAddress, rainCollateralController.owner());

        vm.stopPrank();

        // OPTIONAL - Joint Multisig Transfers Ownership of Rain Collateral Factory Back to Rain Collateral Factory Owner Address
        // TODO

    }


    ///////////////////////////////////////////////////////
    //          I N T E R N A L   H E L P E R S          //
    ///////////////////////////////////////////////////////

    function _deployLoCWithConfig(LineFactory lineFactory) internal returns (address){
        // create Escrow and Spigot
        escrow = new Escrow(minCRatio, oracleAddress, rainControllerOwnerAddress, rainBorrower);
        spigot = new Spigot(rainControllerOwnerAddress, rainControllerOwnerAddress);

        // create SecuredLine
        securedLine = new SecuredLine(oracleAddress, arbiterAddress, rainBorrower, payable(zeroExSwapTarget), address(spigot), address(escrow), ttl, revenueSplit);

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

        lineFactory.registerSecuredLine(address(securedLine), address(spigot), address(escrow), rainBorrower, revenueSplit, minCRatio);

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

    // function _claimRevenueOnBehalfOfSpigot(bytes4 claimFunc, address rainCollateralContract, uint256 amount, address[] memory assets, uint256[] memory amounts) internal returns (uint256){
    //     amounts[0] = amount;
    //     bytes memory claimFuncData = abi.encodeWithSelector(
    //         claimFunc,
    //         rainCollateralContract,
    //         assets,
    //         amounts
    //     );

    //     emit log_named_address("\n - Rain Collateral Contract ", rainCollateralContract);
    //     uint256 startingSpigotBalance = IERC20(USDC).balanceOf(address(spigot));
    //     uint256 claimed = spigot.claimRevenue(rainCollateralControllerAddress, USDC, claimFuncData);
    //     uint256 endingSpigotBalance = IERC20(USDC).balanceOf(address(spigot));
    //     emit log_named_uint("- starting Spigot balance ", startingSpigotBalance);
    //     emit log_named_uint("- amount claimed from Rain Collateral Controller ", claimed);
    //     emit log_named_uint("- ending Spigot balance ", endingSpigotBalance);
    //     return claimed;
    // }


    // fund a loan as a lender
    function _lenderFundLoan() internal returns (bytes32 id) {
        assertEq(vm.activeFork(), ethMainnetFork, "mainnet fork is not active");

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

        id = securedLine.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInUSDC, // amount
            USDC, // token
            lenderAddress // lender
        );
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

    function _initSpigot(
        uint8 split,
        bytes4 claimFunc,
        bytes4 newOwnerFunc
        // bytes4[] memory _whitelist
    ) internal {

        settings = ISpigot.Setting(split, claimFunc, newOwnerFunc);

        // add spigot for revenue contract
        require(
            securedLine.addSpigot(rainCollateralControllerAddress, settings),
            "Failed to add spigot"
        );

    }


}