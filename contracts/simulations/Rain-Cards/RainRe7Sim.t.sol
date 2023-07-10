pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IOracle} from "../../interfaces/IOracle.sol";
import {MockRegistry} from "../../mock/MockRegistry.sol";
import {ILineFactory} from "../../interfaces/ILineFactory.sol";
import {ModuleFactory} from "../../modules/factories/ModuleFactory.sol";
import {LineOfCredit} from "../../modules/credit/LineOfCredit.sol";
import {SpigotedLine} from "../../modules/credit/SpigotedLine.sol";
import {SecuredLine} from "../../modules/credit/SecuredLine.sol";
import {ZeroEx} from "../../mock/ZeroEx.sol";
import {ISpigotedLine} from "../../interfaces/ISpigotedLine.sol";
import {IEscrow} from "../../interfaces/IEscrow.sol";
import {ISpigot} from "../../interfaces/ISpigot.sol";
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

contract IndexRe7Sim is Test {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // Interfaces
    ILineFactory lineFactory;
    IOracle oracle;

    ISpigot spigot;
    ISpigot.Setting private settings;
    ISecuredLine securedLine;
    ILineOfCredit line;
    ISpigotedLine spigotedLine;
    IEscrow escrow;

    IRainCollateralController rainCollateralController;

    // Credit Coop Infra Addresses
    address constant lineFactoryAddress = 0x89989dBe4CFa289dE6179e8d54EE755E471a4251;
    address constant oracleAddress = 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    // Rain Cards Borrower Address
    address constant rainBorrower = 0x0204C22BE67968C3B787D2699Bd05cf2b9432c60; // Rain Borrower Address

    // Borrower and Lender Addresses
    // address borrowerAddress = makeAddr("borrower"); // TODO  - indexCoopLiquidityOperations
    address lenderAddress = makeAddr("lender"); // TODO - Mock Lender Address

    // Rain Controller Contract & Associated Addresses
    address rainCollateralControllerAddress = 0xE5D3d7da4b24bc9D2FDA0e206680CD8A00C0FeBD;
    address rainControllerAdminAddress = 0xB92949bdF09F4193599Ae7700211751ab5F74aCd;
    address rainControllerOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;
    address rainTreasuryContractAddress = 0x0204C22BE67968C3B787D2699Bd05cf2b9432c60;

    // Rain Collateral Contracts 0 - 3:
    address rainCollateralContract0 = 0xbAf9c4b4318AEfCd3a7c2ABec68eFE567c797d74;
    address rainCollateralContract1 = 0x9bf0fA5bBd9448190C9CBFe3adE8D7466913d861;
    address rainCollateralContract2 = 0x5C82f4928899a91752083dd8F1b6D8bf23D4eeb2;
    address rainCollateralContract3 = 0xCF3d82CD86b25c87dcf2Fc6d9Abe9580a8e0E981;

    // Rain (Fake) User Addresses
    address rainUser0 = makeAddr("rainUser0");
    address rainUser1 = makeAddr("rainUser1");
    address rainUser2 = makeAddr("rainUser2");
    address rainUser3 = makeAddr("rainUser3");
    address rainUser4 = makeAddr("rainUser4");

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

    // uint256 constant FORK_BLOCK_NUMBER = 16_991_081; // Forking mainnet at block right after Line Factory was deployed
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
        lineFactory = ILineFactory(address(lineFactoryAddress));

        // Deal assets to all 3 parties (borrower, lender, arbiter) NOTE: will use actual address of parties whhen they are known

        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);

        deal(USDC, lenderAddress, 200000 * 10 ** 6);

        // Deal USDC to Rain (Fake) User Addresses
        deal(USDC, rainUser0, 30000 * 10 ** 6);
        deal(USDC, rainUser1, 170000 * 10 ** 6);
        deal(USDC, rainUser2, 120000 * 10 ** 6);
        deal(USDC, rainUser3, 80000 * 10 ** 6);

        // Define Interface for Rain Collateral Controller
        rainCollateralController = IRainCollateralController(rainCollateralControllerAddress);

        // Borrower Deploys Line of Credit
        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 Borrower Deploys Line of Credit", "");
        securedLineAddress = _deployLoCWithConfig();

        // Define interfaces for all CC modules
        securedLine = ISecuredLine(securedLineAddress);
        line = ILineOfCredit(securedLineAddress);
        spigotedLine = ISpigotedLine(securedLineAddress);
        escrow = IEscrow(address(securedLine.escrow()));
        spigot = ISpigot(address(securedLine.spigot()));

        // Check status == ACTIVE after LOC is deployed
        uint256 status = uint256(line.status());
        assertEq(1, status);
        emit log_named_uint("- status (1 == ACTIVE) ", status);

        vm.stopPrank();

    }

    ///////////////////////////////////////////////////////
    //             S C E N A R I O   T E S T             //
    ///////////////////////////////////////////////////////

    function test_rain_re7_simulation() public {

        // Credit Coop Arbiter adds Rain Collateral Controller to Spigot
        vm.startPrank(arbiterAddress);
        // uint8 split = 100;
        bytes4 claimFunc = _getSelector("liquidateAsset(address,address[],uint256[])");
        // bytes4 claimFunc = 0x000000;
        bytes4 newOwnerFunc = _getSelector("transferOwnership(address)");

        emit log_named_string("\n \u2713 Arbiter Adds Rain Collateral Controller as Revenue Contract to Spigot", "");
        _initSpigot(revenueSplit, claimFunc, newOwnerFunc);

        // Credit Coop Arbiter Whitelists Functions for Rain's Normal Operations
        emit log_named_string("\n \u2713 Arbiter Whitelists increaseNonce function", "");
        bytes4 whitelistedFunc = _getSelector("increaseNonce(address)");
        securedLine.updateWhitelist(whitelistedFunc, true);
        assertEq(true, ISpigot(securedLine.spigot()).isWhitelisted(whitelistedFunc));

        // whitelist liquidateAsset function
        bytes4 liquidateFunc = _getSelector("liquidateAsset(address,address[],uint256[])");
        // securedLine.updateWhitelist(liquidateFunc, true);
        // assertEq(true, ISpigot(securedLine.spigot()).isWhitelisted(liquidateFunc));

        vm.stopPrank();

        // Rain transfers ownership of Rain Collateral Controller to Spigot
        // Rain updates updateTreasury to Spigot address in Rain Collateral Controller
        // Rain updates updateControllerAdmin to Spigot address in Rain Collateral Controller
        vm.startPrank(rainControllerOwnerAddress);
        emit log_named_string("\n \u2713 Rain Collateral Controller Owner Sets Spigot as Treasury", "");
        rainCollateralController.updateTreasury(address(securedLine.spigot()));
        assertEq(address(securedLine.spigot()), rainCollateralController.treasury());

        emit log_named_string("\n \u2713 Rain Collateral Controller Owner Sets Controller Admin as Spigot", "");
        rainCollateralController.updateControllerAdmin(address(securedLine.spigot()));
        assertEq(address(securedLine.spigot()), rainCollateralController.controllerAdmin());

        emit log_named_string("\n \u2713 Rain Collateral Controller Owner Transfers Ownership to Spigot", "");
        rainCollateralController.transferOwnership(address(securedLine.spigot()));
        assertEq(address(securedLine.spigot()), rainCollateralController.owner());

        vm.stopPrank();

        // re7 proposes position
        // Rain accepts position
        bytes32 positionId =  _lenderFundLoan();

        // check that the line position has the credit funds
        uint256 balance = IERC20(USDC).balanceOf(securedLineAddress);
        emit log_named_uint("- balance of Line of Credit (USDC): ", balance);
        assertEq(balance, loanSizeInUSDC);

        // Rain draws down full amount
        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 Borrower Borrows Full Amount from Line of Credit", "");
        line.borrow(positionId, 200000 * 10 ** 6);
        vm.stopPrank();

        // TODO: Original Rain Controller Address calls increaseNonce through operate() on Line of Credit
        // vm.startPrank(rainControllerOwnerAddress);
        // emit log_named_uint("- Rain Collateral 0 - Starting Nonce", rainCollateralController.nonce(rainCollateralContract0));
        // bytes4 increaseNonceFunc = _getSelector("increaseNonce(address)");
        // bytes memory increaseNonceData = abi.encodeWithSelector(increaseNonceFunc);
        // spigot.operate(rainCollateralControllerAddress, increaseNonceData);
        // emit log_named_uint("- Rain Collateral 0 - Ending Nonce", rainCollateralController.nonce(rainCollateralContract0));
        // vm.stopPrank();

        emit log_named_string("\n \u2713 Line Operator Calls increaseNonce Function on Rain Collateral Contract 0", "");
        // TODO: rainControllerOwnerAddress should call this, not the borrower of the Line of Credit
        // TODO: set rainControllerOwnerAddress as the line operator?
        // TODO: increaseNonce should increase the nonce
        // TODO: fix problem in LoC contracts where operates does not fail, but does not actually call function
        vm.startPrank(rainBorrower);
        // vm.startPrank(rainControllerOwnerAddress);
        uint256 startingNonce = rainCollateralController.nonce(rainCollateralContract0);
        emit log_named_uint("- Rain Collateral 0 - Starting Nonce", startingNonce);
        // rainCollateralController.increaseNonce(rainCollateralContract0);
        // bytes4 increaseNonceFunc = _getSelector("increaseNonce(address)");
        // bytes memory increaseNonceData = abi.encodeWithSelector(increaseNonceFunc);
        // bytes memory increaseNonceData = abi.encode(increaseNonceFunc, rainCollateralContract0);
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

        // TODO: Borrower calls increaseNonce through operate() on Line of Credit
        emit log_named_string("\n \u2713 Line Operator Calls increaseNonce Function on Rain Collateral Contract 1", "");
        vm.startPrank(rainBorrower);
        // vm.startPrank(rainControllerOwnerAddress);
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

        // TODO: Rain Collateral Contracts 0 - 3 receive USDC deposits from Rain Card users

        emit log_named_string("\n \u2713 Rain User 0 Transfers USDC to Rain Collateral Contract 0 ", "");
        vm.startPrank(rainUser0);
        emit log_named_uint("- Rain User 0 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser0));
        emit log_named_uint("- Rain Collateral Contract 0 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract0));
        IERC20(USDC).transfer(address(rainCollateralContract0), 30000 * 10 ** 6);
        emit log_named_uint("- Rain User 0 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser0));
        emit log_named_uint("- Rain Collateral Contract 0 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract0));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 1 Transfers USDC to Rain Collateral Contract 1", "");
        vm.startPrank(rainUser1);
        emit log_named_uint("- Rain User 1 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser1));
        emit log_named_uint("- Rain Collateral Contract 1 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract1));
        IERC20(USDC).transfer(address(rainCollateralContract1), 170000 * 10 ** 6);
        emit log_named_uint("- Rain User 1 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser1));
        emit log_named_uint("- Rain Collateral Contract 1 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract1));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 2 Transfers USDC to Rain Collateral Contract 2 ", "");
        vm.startPrank(rainUser2);
        emit log_named_uint("- Rain User 2 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser2));
        emit log_named_uint("- Rain Collateral Contract 2 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract2));
        IERC20(USDC).transfer(address(rainCollateralContract2), 120000 * 10 ** 6);
        emit log_named_uint("- Rain User 2 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser2));
        emit log_named_uint("- Rain Collateral Contract 2 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract2));
        vm.stopPrank();

        emit log_named_string("\n \u2713 Rain User 3 Transfers USDC to Rain Collateral Contract 3", "");
        vm.startPrank(rainUser3);
        emit log_named_uint("- Rain User 3 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainUser3));
        emit log_named_uint("- Rain Collateral Contract 3 - Starting USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract3));
        IERC20(USDC).transfer(address(rainCollateralContract3), 80000 * 10 ** 6);
        emit log_named_uint("- Rain User 3 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainUser3));
        emit log_named_uint("- Rain Collateral Contract 3 - Ending USDC Balance ", IERC20(USDC).balanceOf(rainCollateralContract3));
        vm.stopPrank();

        // Rain calls claimRevenue function on Spigot which calls liquidateAsset (Spigot) to transfer USDC from Rain Collateral Contracts to Treasury (Spigot)
        // TODO: convert memory to calldata if possible?
        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 [Borrower] Calls the Spigot Claim Function", "");
        bytes4 liquidateFunc0 = _getSelector("liquidateAsset(address,address[],uint256[])");

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        assets[0] = address(USDC);

        uint256 claimed0 = _claimRevenueOnBehalfOfSpigot(liquidateFunc0, rainCollateralContract0, 30000 * 10 ** 6, assets, amounts);
        assertEq(30000 * 10 ** 6, claimed0);

        uint256 claimed1 = _claimRevenueOnBehalfOfSpigot(liquidateFunc0, rainCollateralContract1, 170000 * 10 ** 6, assets, amounts);
        assertEq(170000 * 10 ** 6, claimed1);

        uint256 claimed2 = _claimRevenueOnBehalfOfSpigot(liquidateFunc0, rainCollateralContract2, 120000 * 10 ** 6, assets, amounts);
        assertEq(120000 * 10 ** 6, claimed2);

        uint256 claimed3 = _claimRevenueOnBehalfOfSpigot(liquidateFunc0, rainCollateralContract3, 80000 * 10 ** 6, assets, amounts);
        assertEq(80000 * 10 ** 6, claimed3);
        assertEq(400000 * 10 ** 6, IERC20(USDC).balanceOf(address(spigot)));

        vm.stopPrank();

        // Rain claims their portion of cash flows from Spigot w/ claimOperatorTokens
        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 [Borrower] Calls the Spigot Claim Operator Tokens Function", "");
        uint256 claimedOperatorTokens = spigot.claimOperatorTokens(address(USDC));
        emit log_named_uint("- Rain Borrower - Claimed Operator Tokens ", claimedOperatorTokens);
        assertEq(claimedOperatorTokens, 200000 * 10 ** 6);
        assertEq(200000 * 10 ** 6, IERC20(USDC).balanceOf(address(spigot)));
        vm.stopPrank();

        // Rain claims and repay the full balance of the Line of Credit
        emit log_named_string("\n \u2713 Borrower Calls ClaimAndRepay to Repay Line of Credit with Spigot Revenue", "");
        vm.startPrank(arbiterAddress);
        // uint claimable = spigot.getOwnerTokens(USDC);
        emit log_named_uint("- Owner Tokens in Spigot before repayment: ", spigot.getOwnerTokens(USDC));
        assertEq(200000 * 10 ** 6, spigot.getOwnerTokens(USDC));
        // bytes memory tradeData = "";
        spigotedLine.claimAndRepay(address(USDC), "");
        assertEq(0, spigot.getOwnerTokens(USDC));
        emit log_named_uint("- Owner Tokens in Spigot after repayment: ", spigot.getOwnerTokens(USDC));
        vm.stopPrank();


        // Rain closes the Line of Credit
        // emit log_named_string("\n \u2713 Borrower Calls close Function to Close Line of Credit", "");
        // uint256 interestOwed = line.interestAccrued(positionId);
        // emit log_named_uint("- Interest Owed on Line of Credit ", interestOwed);

        // vm.startPrank(indexCoopLiquidityOperations);
        // emit log_named_string("\n \u2713 Borrower Calls depositAndClose to Fully Repay and Close Line of Credit", "");
        // IERC20(WETH).approve(securedLineAddress, MAX_INT);
        // line.depositAndClose();

        // // Check status == REPAID after position is repaid and closed
        // uint256 statusIsRepaid = uint256(line.status());
        // assertEq(3, statusIsRepaid);
        // emit log_named_uint("- status (3 == REPAID) ", statusIsRepaid);
        // vm.stopPrank();

        // // check reserves

        // // uint256 unusedTokensAfterClose = spigotedLine.unused(dsETHToken);
        // // uint256 ownerTokensAfterClose = spigot.getOwnerTokens(dsETHToken);
        // // uint256 operatorTokensAfterClose = spigot.getOperatorTokens(dsETHToken);

        // // emit log_named_uint("- Unused Tokens after Position is closed and line is repaid", unusedTokensAfterClose);
        // // emit log_named_uint("- Owner Tokens after Position is closed and line is repaid", ownerTokensAfterClose);
        // // emit log_named_uint("- Operator Tokens after Position is closed and line is repaid", operatorTokensAfterClose);

        // // Lender withdraws principal + interest owed
        // vm.startPrank(lenderAddress);
        // emit log_named_string("\n \u2713 Lender Withdraws All Repaid Principal and Interest", "");
        // line.withdraw(positionId, interestOwed + loanSizeInWETH);

        // // check that the lender balance is principal + interest
        // uint256 lenderBalanceAfterClose = IERC20(WETH).balanceOf(lenderAddress);
        // uint256 lenderBalanceAfterRepayment = lenderBalanceAtStart +  interestOwed;
        // assertEq(lenderBalanceAfterClose, lenderBalanceAfterRepayment, "Lender has not been full repaid");
        // vm.stopPrank();

        // // Borrower Releases Collateral
        // vm.startPrank(indexCoopLiquidityOperations);
        // emit log_named_string("\n \u2713 Borrower Releases Collateral", "");
        // escrow.releaseCollateral(collateralAmtDAI, DAI, indexCoopLiquidityOperations);

        // emit log_named_string("\n \u2713 Borrower Releases Spigot", "");
        // spigotedLine.releaseSpigot(indexCoopLiquidityOperations);


        // /*
        //     In the actual scenario, the borrower, Index Coop Liquidity Operations, will call the claimAndRepay function.
        //     For the simulations test, the borrower instead calls depositAndClose to fully repay the lender and close the position.
        //     The borrower then calls the claimOwnerTokens function to claim the revenue from the spigot since they have already fully repaid the lender.
        // */

        // spigot.claimOwnerTokens(dsETHToken);

        // // uint256 ownerTokensAfterRelease = spigot.getOwnerTokens(dsETHToken);
        // emit log_named_uint("- Owner Tokens after Position is closed and line is repaid", spigot.getOwnerTokens(dsETHToken));

        // assertEq(spigot.getOwnerTokens(dsETHToken), 0, "Spigot should not have any owner tokens");

        // uint256 borrowerClaimedTokens = IERC20(dsETHToken).balanceOf(indexCoopLiquidityOperations);
        // emit log_named_uint("- Borrower has tokens after Position is closed and line is repaid", borrowerClaimedTokens);

        // assertEq(borrowerClaimedTokens, spigot.getOwnerTokens(dsETHToken), "Borrower has not claimed correct amount of tokens");

        // // address whoIsOperator = manager.operator();
        // // emit log_named_address("- The Operator of dsETH is ", whoIsOperator);
        // // emit log_named_address("- Spigot address is ", address(securedLine.spigot()));

        // // emit log_named_string("\n \u2713 Borrower Removes Spigot", "");
        // // spigot.removeSpigot(dsETHManager);
        // // whoIsOperator = manager.operator();

        // // emit log_named_address("- The Operator of dsETH is ", whoIsOperator);
        // // emit log_named_address("- Spigot address is ", indexCoopOperations);

        // // emit log_named_string("\n \u2713 OperatorFeeRecipient is set to the original dsETH OperatorFeeRecipient", "");
        // // dsETH.updateOperatorFeeRecipient(indexCoopOperations);
        // // assertEq(indexCoopOperations, dsETH.operatorFeeRecipient());
        // // emit log_named_address("- Index Coop Operations: ", indexCoopOperations);
        // // emit log_named_address("- dsETH operatorFeeRecipient: ", dsETH.operatorFeeRecipient());
        // // assertEq(indexCoopOperations, dsETH.operatorFeeRecipient());

        // // emit log_named_string("\n \u2713 dsETH Operator is set to Original dsETH Operator", "");
        // // manager.setOperator(dsETHOperator);
        // // whoIsOperator = manager.operator();
        // // emit log_named_address("- The Operator of dsETH is ", whoIsOperator);
        // // emit log_named_address("- Spigot address is ", dsETHOperator);
        // // assertEq(dsETHOperator, manager.operator());

        // address whoIsMethodologist = manager.methodologist();
        // emit log_named_address("- The Methodologist of dsETH is ", whoIsMethodologist);
        // emit log_named_address("- Spigot address is ", address(securedLine.spigot()));

        // emit log_named_string("\n \u2713 Borrower Removes Spigot", "");
        // spigot.removeSpigot(dsETHManager);
        // whoIsMethodologist = manager.methodologist();

        // emit log_named_address("- The Methodologist of dsETH is ", whoIsMethodologist);
        // emit log_named_address("- Spigot Owner address is ", indexCoopLiquidityOperations);

        // emit log_named_string("\n \u2713 OperatorFeeSplit is set to 100% to the Operator", "");
        // dsETH.updateFeeSplit(10 ** 18);
        // vm.stopPrank();

        // vm.startPrank(dsETHOperator);
        // dsETH.updateFeeSplit(10 ** 18);
        // vm.stopPrank();

        // assertEq(10 ** 18, dsETH.operatorFeeSplit());
        // emit log_named_address("- Index Coop Operations: ", indexCoopLiquidityOperations);
        // emit log_named_uint("- dsETH operatorFeeSplit: ", dsETH.operatorFeeSplit());
        // // assertEq(indexCoopOperations, dsETH.operatorFeeRecipient());
        // vm.startPrank(indexCoopLiquidityOperations);
        // emit log_named_string("\n \u2713 dsETH Methodologist is set to Original dsETH Operator", "");
        // manager.setMethodologist(dsETHOperator);
        // vm.stopPrank();

        // vm.startPrank(dsETHOperator);
        // manager.setMethodologist(dsETHOperator);
        // vm.stopPrank();

        // // address whoIsOperator = manager.operator();
        // whoIsMethodologist = manager.methodologist();
        // emit log_named_address("- The Operator of dsETH is ", address(manager.operator()));
        // emit log_named_address("- The Methodologist of dsETH is ", whoIsMethodologist);
        // // emit log_named_address("- Spigot Oaddress is ", dsETHOperator);
        // assertEq(dsETHOperator, manager.methodologist());




    }


    ///////////////////////////////////////////////////////
    //          I N T E R N A L   H E L P E R S          //
    ///////////////////////////////////////////////////////

    function _deployLoCWithConfig() internal returns (address){
        ILineFactory.CoreLineParams memory coreParams = ILineFactory.CoreLineParams({
            borrower: rainBorrower,
            ttl: ttl, // time to live
            cratio: minCRatio, // uint32(creditRatio),
            revenueSplit: revenueSplit // uint8(revenueSplit) - 100% to spigot
        });

        securedLineAddress = lineFactory.deploySecuredLineWithConfig(coreParams);
        return securedLineAddress;
    }

    // function _simulateRevenueGeneration(uint256 amt) internal returns (uint256 revenue) {
    //     vm.deal(dsETHFeeSplitExtension, amt + 0.5 ether); // add a bit to cover gas

    //     vm.prank(dsETHFeeSplitExtension);
    //     revenue = amt;
    //     IWeth(WETH).deposit{value: revenue}();

    //     assertEq(IERC20(WETH).balanceOf(dsETHFeeSplitExtension), revenue, "fee collector balance should match revenue");
    // }


    // TODO: convert claimRevenue function from a push payment to a pull payment
    /// @dev    Because they claim function is not set in the spigot, this will be a push payment only
    /// @dev    We need to call `deposit()` manually before claiming revenue, or there will be no revenue
    ///         to claim (because calling `deposit()` distribute revenue to beneficiaires,of which the spigot is one)
    function _claimRevenueOnBehalfOfSpigot(bytes4 claimFunc, address rainCollateralContract, uint256 amount, address[] memory assets, uint256[] memory amounts) internal returns (uint256){
        amounts[0] = amount;
        // uint256[] calldata amounts = [15000 * 10 ** 6];
        bytes memory claimFuncData = abi.encodeWithSelector(
            claimFunc,
            rainCollateralContract,
            assets,
            amounts
        );

        emit log_named_address("\n - Rain Collateral Contract ", rainCollateralContract);
        uint256 startingSpigotBalance = IERC20(USDC).balanceOf(address(spigot));
        uint256 claimed = spigot.claimRevenue(rainCollateralControllerAddress, USDC, claimFuncData);
        uint256 endingSpigotBalance = IERC20(USDC).balanceOf(address(spigot));
        emit log_named_uint("- starting Spigot balance ", startingSpigotBalance);
        emit log_named_uint("- amount claimed from Rain Collateral Controller ", claimed);
        emit log_named_uint("- ending Spigot balance ", endingSpigotBalance);
        return claimed;
    }


    // fund a loan as a lender
    function _lenderFundLoan() internal returns (bytes32 id) {
        assertEq(vm.activeFork(), ethMainnetFork, "mainnet fork is not active");

        emit log_named_string("\n \u2713 Lender Proposes Position to Line of Credit", "");
        vm.startPrank(lenderAddress);
        IERC20(USDC).approve(address(line), loanSizeInUSDC);
        line.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInUSDC, // amount
            USDC, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        emit log_named_string("\n \u2713 Borrower Accepts Lender Proposal to Line of Credit", "");
        vm.startPrank(rainBorrower);

        id = line.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInUSDC, // amount
            USDC, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(address(line)), loanSizeInUSDC, "LoC balance doesn't match");
        emit log_named_bytes32("- credit id", id);
        return id;
    }

    // function _arbiterAddsRevenueContractToSpigot() internal {
    //     emit log_named_string("\n \u2713 Arbiter Adds dsETH Revenue Contract to Spigot", "");
    //     uint8 split = 100;
    //     bytes4 claimFunc = 0x000000;
    //     bytes4 newOwnerFunc = _getSelector("setOperator(address)");
    //     _initSpigot(split, claimFunc, newOwnerFunc);
    // }

    // function _borrowerDrawsOnCredit(bytes32 id, uint256 amount) internal returns (bool) {

    // }

    // function _depositAndRepay(uint256 amount) internal {

    // }

    // function _depositAndClose() internal {

    // }

    // function _lenderWithdraws(bytes32 id, uint256 amount) internal {

    // }

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
            spigotedLine.addSpigot(rainCollateralControllerAddress, settings),
            "Failed to add spigot"
        );

        // give spigot ownership to claim revenue
        // dsETHFeeSplitExtension.call(
        //     abi.encodeWithSelector(newOwnerFunc, spigot)
        // );
    }

    ///////////////////////////////////////////////////////
    //                U N I T   T E S T S                //
    ///////////////////////////////////////////////////////

    // select a specific fork
    function test_can_select_fork() public {
        assertEq(vm.activeFork(), ethMainnetFork);
        assertEq(block.number, FORK_BLOCK_NUMBER);
    }

    function test_chainlink_price_feed() external {
        int256 usdcPrice = oracle.getLatestAnswer(USDC);
        emit log_named_int("USDC price", usdcPrice);
        assert(usdcPrice > 0);
    }

    function test_borrower_can_deploy_LoC() public {
        vm.startPrank(rainBorrower);
        securedLineAddress = _deployLoCWithConfig();

        assertEq(rainBorrower, line.borrower());
        assertEq(arbiterAddress, line.arbiter());

        // assertEq(ttl, ILineOfCredit(address(securedLine)).arbiter()); // TODO: check ttl
        // assertEq(mincRatio, ILineOfCredit(address(securedLine)).arbiter()); // TODO: check minCRatio
    }

    function test_arbiter_enables_stablecoin_collateral() public {
        vm.startPrank(arbiterAddress);
        bool collateralEnabled = escrow.enableCollateral(USDC);
        assertEq(true, collateralEnabled);
        vm.stopPrank();
    }

    function test_arbiter_adds_revenue_contract_to_spigot() public {
        vm.startPrank(arbiterAddress);
        uint8 split = 100;
        bytes4 claimFunc = 0x000000;
        bytes4 newOwnerFunc = _getSelector("setOperator(address)");
        _initSpigot(split, claimFunc, newOwnerFunc);
        ISpigot spigot2 = spigotedLine.spigot();
        (uint8 split2, bytes4 claimFunc2, bytes4 transferFunc2) = spigot2.getSetting(rainCollateralControllerAddress);
        assertEq(split, split2);
        assertEq(claimFunc, claimFunc2);
        assertEq(newOwnerFunc, transferFunc2);
        vm.stopPrank();
    }

}