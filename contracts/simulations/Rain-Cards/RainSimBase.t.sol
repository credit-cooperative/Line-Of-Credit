pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IBaseOracle} from "../../interfaces/IBaseOracle.sol";
import {BaseOracle} from "../../modules/oracle/BaseOracle.sol";
import {MockRegistry} from "../../mock/MockRegistry.sol";
import {ILineFactory} from "../../interfaces/ILineFactory.sol";
import {LineFactory} from "../../modules/factories/LineFactory.sol";
import {ModuleFactory} from "../../modules/factories/ModuleFactory.sol";
import {LineOfCredit} from "../../modules/credit/LineOfCredit.sol";
import {SpigotedLine} from "../../modules/credit/SpigotedLine.sol";
import {SecuredLine} from "../../modules/credit/SecuredLine.sol";
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


contract RainSimBase is Test {
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
    BaseOracle oracle;

    address constant oracleAddress = 0xb370B80f85cD2A312f6B5f017D8AD5BD827F954C;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    // Rain Cards Borrower Address
    address constant rainBorrower ; // Rain Borrower Address
    address lenderAddress = makeAddr("lender");

    // Rain Controller Contract & Associated Addresses
    address rainCollateralControllerAddress = 0x5d5Cef756412045617415FC78D510003238EAfFd;


    // Credit Coop Addresses
    address constant arbiterAddress; // Credit Coop MultiSig
    address public securedLineAddress; // Line address, to be defined in setUp()

    // Asset Addresses
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant rUSD = 0xd899C2254C1F4B11FfF038571D6cb02aB8860eC8;

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
    uint256 constant FORK_BLOCK_NUMBER; //17_638_122; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
    uint256 BaseFork;

    event log_named_bytes4(string key, bytes4 value);

    constructor() {}

    function setUp() public {
        BaseFork = vm.createFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(BaseFork);
        // oracle = new PolygonOracle();
        // oracleAddress = address(oracle);
        // int256 price = oracle.getLatestAnswer(USDC);

        emit log_named_address("- borrower", rainBorrower);
        emit log_named_address("- lender", lenderAddress);

        // Create  Interfaces for CC infra

        // Deal MATIC assets to all 3 parties (borrower, lender, arbiter)
        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);
        // vm.deal(rainControllerOwnerAddress, 100 ether);
        // deal(MATIC, rainControllerOwnerAddress, 100 ether);

        deal(USDC, lenderAddress, loanSizeInUSDC);


        // Define Interface for Rain Controller
        rainCollateralController = IRainCollateralController(rainCollateralControllerAddress);
    }

    ///////////////////////////////////////////////////////
    //             S C E N A R I O   T E S T             //
    ///////////////////////////////////////////////////////

    function test_rain_simulation_base() public {
        // Deploy Credit Coop Factory Contracts


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

        // Borrower Releases Spigot
        vm.startPrank(rainBorrower);

        emit log_named_string("\n \u2713 Borrower Releases Spigot to Rain Collateral Controller Owner Address", "");
        securedLine.releaseSpigot(rainControllerOwnerAddress);
        vm.stopPrank();

        vm.startPrank(rainControllerOwnerAddress);
        emit log_named_string("\n \u2713 Borrower Removes Rain Collateral Controller from Spigot", "");
        spigot.removeSpigot(rainCollateralControllerAddress);
        spigot.removeSpigot(rainCollateralBeaconAddress);
        spigot.removeSpigot(rainCollateralFactoryAddress);

        assertEq(rainControllerOwnerAddress, rainCollateralController.owner());
        assertEq(rainControllerOwnerAddress, rainCollateralBeacon.owner());
        assertEq(rainControllerOwnerAddress, rainCollateralFactory.owner());

        vm.stopPrank();

        // // OPTIONAL - Joint Multisig Transfers Ownership of Rain Collateral Factory Back to Rain Collateral Factory Owner Address
        // // TODO

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
