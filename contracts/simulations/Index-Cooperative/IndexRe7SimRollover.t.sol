pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {Escrow} from "../../modules/escrow/Escrow.sol";
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

interface IWeth {
    function deposit() external payable;
}

interface IdsETH {
    function setManager(address _manager) external;

} //  TODO - define this

interface IdsETHFeeSplitExtension {
    function owner() external view returns (address);
    function operatorFeeSplit() external view returns (uint256);
    function operatorFeeRecipient() external view returns (address);
    function transferOwnership(address newOwner) external;
    function updateOperatorFeeRecipient(address _newFeeRecipient) external;
    function accrueFeesAndDistribute() external;
    function updateFeeSplit(uint256 _newFeeSplit) external;
}

interface IManager {
    function methodologist() external view returns (address);
    function operator() external view returns (address);
    function setOperator(address _newOperator) external;
    function setMethodologist(address _newMethodologist) external;

}

contract IndexRe7Sim is Test {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // Interfaces
    ILineFactory factory;
    IOracle oracle;

    ISpigot spigot;
    ISpigot.Setting private settings;
    ISecuredLine securedLine;
    ISecuredLine securedLine2;
    ILineOfCredit line;
    ILineOfCredit line2;
    ISpigotedLine spigotedLine;
    IEscrow escrow;

    IdsETHFeeSplitExtension dsETH;
    IManager manager;


    // Credit Coop Infra Addresses
    address constant lineFactoryAddress = 0x07d5c33a3AFa24A25163D2afDD663BAb4C17b6d5;
    address constant oracleAddress = 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    // Index Addresses
    address constant indexCoopOperations = 0xFafd604d1CC8b6B3B6CC859cF80Fd902972371C1; // Index Coop Operations Multisig
    address constant indexCoopLiquidityOperations = 0x3a36b94689f303aAf9BFE761068Efb8F78912023; // Index Coop Liquidity Operations Multisig - THIS IS THE BORROWER ADDRESSS

    // Borrower and Lender Addresses
    // address borrowerAddress = makeAddr("borrower"); // TODO  - indexCoopLiquidityOperations
    address borrowerAddress = 0x7ec0D4Fdda3C194408d59241D27CE0d2016D890F; // joing sig
    address lenderAddress = 0x45e5bdB64AF009A5792b650BF5bd110665500Da3; // re7


   // dsETH Addresses
    address constant dsETHToken = 0x341c05c0E9b33C0E38d64de76516b2Ce970bB3BE;  // dsETH Address
    address constant dsETHFeeSplitExtension  = 0xFCDEE96D9df5b318ea0EEB39d5d7642d9AFd7FdA; // FeeSplitExtensionAddress
    address constant feeSplitExtensionOwner = 0x4e59b44847b379578588920cA78FbF26c0B4956C; // Owner of the dsETH fee split extension
    address constant dsETHManager = 0xBB6134ba82192E0ab23De846f1Cae7aa9Ae383d5; // Manager of the dsETH product
    address constant dsETHOperator = 0x6904110f17feD2162a11B5FA66B188d801443Ea4;// Operator of the dsETH product

    // Credit Coop Addresses
    address constant arbiterAddress = 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a; // Credit Coop MultiSig
    address public securedLineAddress = 0xa0bf40bA76F8Fe562c15F029B2e50Fe80b0d600d; // Line address, to be defined in setUp()
    address public deployer = 0x06dae7Ba3958EF288adB0B9b3732eC204E48BC47;

    // Asset Addresses
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Money Vars
    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 collateralAmtDAI = 50_000 ether; // 50,000 DAI --> 50000000000000000000000


    // Loan Terms
    uint256 ttl = 90 days;
    uint32 minCRatio = 1250; // BPS
    uint8 revenueSplit = 100;
    uint256 loanSizeInWETH = 220 ether;
    uint128 dRate = 1250; // BPS
    uint128 fRate = 1250; // BPS

    // Fork Settings

    // uint256 constant FORK_BLOCK_NUMBER = 16_991_081; // Forking mainnet at block right after Line Factory was deployed
    uint256 constant FORK_BLOCK_NUMBER = 20_184_519; // Forking mainnet at block on 6/27/24 at 1 30 AM EST
    uint256 ethMainnetFork;

    event log_named_bytes4(string key, bytes4 value);

    constructor() {

    }

    function setUp() public {
        ethMainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(ethMainnetFork);

        emit log_named_string("- rpc", vm.envString("MAINNET_RPC_URL"));
        emit log_named_address("- borrower", indexCoopOperations);
        emit log_named_address("- lender", lenderAddress);
        // Create  Interfaces for CC infra

        oracle = IOracle(address(oracleAddress));
        factory = ILineFactory(address(lineFactoryAddress));

        // Deal assets to all 3 parties (borrower, lender, arbiter) NOTE: will use actual address of parties whhen they are known

        // vm.deal(borrowerAddress, 100 ether);
        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);

        deal(DAI, indexCoopLiquidityOperations, 50_000 ether);
        // deal(WETH, borrowerAddress, 100 ether);
        deal(WETH, lenderAddress, 10000 ether);
        deal(WETH, indexCoopOperations, 10 ether);
        deal(WETH, borrowerAddress, 10000 ether);



        // Define Interfaces for Index Coop Modules
        dsETH = IdsETHFeeSplitExtension(dsETHFeeSplitExtension);
        manager = IManager(dsETHManager);

        // Borrower Deploys Line of Credit
        vm.startPrank(indexCoopLiquidityOperations);
        emit log_named_string("\n \u2713 Borrower Deploys Line of Credit", "");

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

    function test_index_re7_simulation_rollover() public {

        bytes32 positionId = LineOfCredit(securedLineAddress).ids(0);
        emit log_named_bytes32("- positionId", positionId);
        uint256 interestOwed = line.interestAccrued(positionId);
        emit log_named_uint("- interestAccrued: ", interestOwed);
        emit log_named_uint("- loanSizeInWETH: ", loanSizeInWETH);

        vm.startPrank(borrowerAddress);
        emit log_named_string("\n \u2713 Borrower Calls depositAndClose to Fully Repay and Close Line of Credit", "");
        IERC20(WETH).approve(securedLineAddress, MAX_INT);
        line.depositAndClose();
        vm.stopPrank();

        uint256 status = uint256(line.status());
        assertEq(3, status);
        emit log_named_uint("- status (3 == REPAID) ", status);

        // get lender
        vm.startPrank(lenderAddress);
        emit log_named_string("\n \u2713 Lender Withdraws All Repaid Principal and Interest", "");
       (,,,,,,address lender,) = LineOfCredit(securedLineAddress).credits(positionId);
        emit log_named_address("- lender", lender);
        line.withdraw(positionId, interestOwed + loanSizeInWETH);

        // check that the lender balance is principal + interest
        uint256 lenderBalanceAfterClose = IERC20(WETH).balanceOf(lenderAddress);
        emit log_named_uint("- lender balance after close", lenderBalanceAfterClose);
        vm.stopPrank();

        // call rollover on the factory
        emit log_named_string("\n \u2713 Factory deployer calls deploySecuredLineWithModules", "");
        vm.startPrank(deployer);

        ILineFactory.CoreLineParams memory coreParams = ILineFactory.CoreLineParams({
            borrower: borrowerAddress,
            ttl: ttl,
            cratio: minCRatio,
            revenueSplit: revenueSplit
        });

        emit log_named_address("- escrow: ", address(escrow));
        emit log_named_address("- spigot: ", address(spigot));

        address newLine = factory.deploySecuredLineWithModules(coreParams, address(spigot), address(escrow));
        vm.stopPrank();

        emit log_named_address("- newLine: ", newLine);

        SecuredLine newSecuredLine = SecuredLine(payable(newLine));

        uint256 statusBeforeRollover = uint256(newSecuredLine.status());
        assertEq(0, statusBeforeRollover, "status not active");
        emit log_named_uint("- status before rollover", statusBeforeRollover);



        // borrower calls rollover on old line
        emit log_named_string("\n \u2713 Borrower Calls Rollover", "");
        vm.startPrank(borrowerAddress);
        ISecuredLine(securedLineAddress).rollover(newLine);
        vm.stopPrank();

        uint256 split = newSecuredLine.defaultRevenueSplit();
        assertEq(split, revenueSplit, "revenue split not equal");
        emit log_named_uint("- revenue split", split);

        uint256 minCRatio2 = IEscrow(newSecuredLine.escrow()).minimumCollateralRatio();
        assertEq(minCRatio, minCRatio2, "min c ratio not equal");
        emit log_named_uint("- minCRatio", minCRatio2);

        uint256 cratio2 = IEscrow(newSecuredLine.escrow()).getCollateralRatio();
        assertGt(cratio2, minCRatio, "cratio is below threshold");
        emit log_named_uint("- cRatio", cratio2);

        uint collateralValue = Escrow(address(newSecuredLine.escrow())).getCollateralValue();
        // assertGt(cratio2, minCRatio, "cratio is below threshold");
        emit log_named_uint("- collateralValue", collateralValue);
        emit log_named_uint("- balance of WETH", IERC20(WETH).balanceOf(address(newSecuredLine.escrow())));

        address currentBorrower = newSecuredLine.borrower();
        assertEq(currentBorrower, borrowerAddress, "borrower not equal");

        address currentSpigot = address(newSecuredLine.spigot());
        assertEq(currentSpigot, address(spigot), "spigot not equal");
        emit log_named_address("- spigot", currentSpigot);

        address currentEscrow = address(newSecuredLine.escrow());
        assertEq(currentEscrow, address(escrow), "escrow not equal");
        emit log_named_address("- escrow", currentEscrow);

        uint256 statusAfterRollover = uint256(newSecuredLine.status());
        assertEq(1, statusAfterRollover, "status not active");
        emit log_named_uint("- status after rollover", statusAfterRollover);

        // // check that the owner of the spigot and escrow is the new line
        // assertEq(address(securedLine2), address(spigot.owner()));
        // assertEq(address(securedLine2), address(escrow.line()));
    }


    ///////////////////////////////////////////////////////
    //          I N T E R N A L   H E L P E R S          //
    ///////////////////////////////////////////////////////

    function _deployLoCWithConfig() internal returns (address){
        ILineFactory.CoreLineParams memory coreParams = ILineFactory.CoreLineParams({
            borrower: indexCoopLiquidityOperations,
            ttl: ttl, // time to live
            cratio: minCRatio, // uint32(creditRatio),
            revenueSplit: revenueSplit // uint8(revenueSplit) - 100% to spigot
        });

        securedLineAddress = factory.deploySecuredLineWithConfig(coreParams);
        return securedLineAddress;
    }

    function _borrowerDepositsCollateral() internal {
        emit log_named_string("\n \u2713 Borrower Adds Collateral", "");
        IERC20(DAI).approve(address(securedLine.escrow()), MAX_INT);
        escrow.addCollateral(collateralAmtDAI, DAI);
    }

    function _simulateRevenueGeneration(uint256 amt) internal returns (uint256 revenue) {
        vm.deal(dsETHFeeSplitExtension, amt + 0.5 ether); // add a bit to cover gas

        vm.prank(dsETHFeeSplitExtension);
        revenue = amt;
        IWeth(WETH).deposit{value: revenue}();

        assertEq(IERC20(WETH).balanceOf(dsETHFeeSplitExtension), revenue, "fee collector balance should match revenue");
    }



    /// @dev    Because they claim function is not set in the spigot, this will be a push payment only
    /// @dev    We need to call `deposit()` manually before claiming revenue, or there will be no revenue
    ///         to claim (because calling `deposit()` distribute revenue to beneficiaires,of which the spigot is one)
    function _claimRevenueOnBehalfOfSpigot(bytes4 claimFunc) internal {

        bytes memory data = abi.encodeWithSelector(claimFunc);
        (uint8 _split, bytes4 _claim, bytes4 _transfer) = spigot.getSetting(dsETHManager);
        emit log_named_bytes4("func being called", bytes4(data));
        emit log_named_bytes4("stored value", _claim);
        uint256 claimed = spigot.claimRevenue(dsETHManager, dsETHToken, data);
        // assertEq(_expectedRevenue, IERC20(dsETHToken).balanceOf((address(spigot))), "balance of spigot should match expected revenue");
        emit log_named_uint("- amount claimed from FeeSplitExtension ", claimed);
    }


    // fund a loan as a lender
    function _lenderFundLoan() internal returns (bytes32 id) {
        assertEq(vm.activeFork(), ethMainnetFork, "mainnet fork is not active");

        emit log_named_string("\n \u2713 Lender Proposes Position to Line of Credit", "");
        vm.startPrank( lenderAddress );
        IERC20(WETH).approve(address(line), loanSizeInWETH);
        line.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInWETH, // amount
            WETH, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        emit log_named_string("\n \u2713 Borrower Accepts Lender Proposal to Line of Credit", "");
        vm.startPrank(indexCoopLiquidityOperations);

        id = line.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInWETH, // amount
            WETH, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        assertEq(IERC20(WETH).balanceOf(address(line)), loanSizeInWETH, "LoC balance doesn't match");
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
            spigotedLine.addSpigot(dsETHManager, settings),
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
        int256 daiPrice = oracle.getLatestAnswer(DAI);
        emit log_named_int("DAI price", daiPrice);
        assert(daiPrice > 0);
    }

    function test_borrower_can_deploy_LoC() public {
        vm.startPrank(indexCoopLiquidityOperations);
        securedLineAddress = _deployLoCWithConfig();

        assertEq(indexCoopLiquidityOperations, line.borrower());
        assertEq(arbiterAddress, line.arbiter());

        // assertEq(ttl, ILineOfCredit(address(securedLine)).arbiter()); // TODO: check ttl
        // assertEq(mincRatio, ILineOfCredit(address(securedLine)).arbiter()); // TODO: check minCRatio
    }

    function test_arbiter_enables_stablecoin_collateral() public {
        vm.startPrank(arbiterAddress);
        bool collateralEnabled = escrow.enableCollateral(DAI);
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
        (uint8 split2, bytes4 claimFunc2, bytes4 transferFunc2) = spigot2.getSetting(dsETHManager);
        assertEq(split, split2);
        assertEq(claimFunc, claimFunc2);
        assertEq(newOwnerFunc, transferFunc2);
        vm.stopPrank();
    }

    // TODO: finish this test
    function test_borrower_deposits_collateral() public {
        test_arbiter_enables_stablecoin_collateral();
        vm.startPrank(indexCoopLiquidityOperations);
        IERC20(DAI).approve(address(securedLine.escrow()), MAX_INT);
        escrow.addCollateral(collateralAmtDAI, DAI);
        // TODO: read collateral amount from escrow and assert collateral value
        // mapping(address => IEscrow.Deposit) deposited = escrow.
        // assertEq(collateralAmtDAI, escrow.Deposit.amount);
        vm.stopPrank();
    }

    // TODO: fix this test
    // function test_borrower_can_draw_on_credit() public {
    //     // index draws down full amount
    //     bytes32 positionId =  _lenderFundLoan();
    //     vm.startPrank(indexCoopLiquidityOperations);
    //     emit log_named_bytes32("PositionId: ", positionId);
    //     line.borrow(positionId, 200 ether);
    //     // TODO: read borrowed amount from line and assert equals 200 ether
    //     vm.stopPrank();
    // }

    function test_borrower_can_deposit_and_repay_debt() public {

    }

    function test_claim_spigot_revenue() public {

    }

    function test_arbiter_can_claim_and_trade() public {

    }

    function test_arbiter_can_claim_and_repay() public {

    }

    function test_interest_accrues_correctly() public {
        // borrower deploys line

        // borrower and lender agree to terms of position

        // borrower draws on credit

        // warp time

        // check interest accrued
    }
}