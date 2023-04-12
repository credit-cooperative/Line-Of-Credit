pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Spigot} from "../modules/spigot/Spigot.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {MockRegistry} from "../mock/MockRegistry.sol";
import {ILineFactory} from "../interfaces/ILineFactory.sol";
import {ModuleFactory} from "../modules/factories/ModuleFactory.sol";
import {LineOfCredit} from "../modules/credit/LineOfCredit.sol";
import {SpigotedLine} from "../modules/credit/SpigotedLine.sol";
import {SecuredLine} from "../modules/credit/SecuredLine.sol";
import {ZeroEx} from "../mock/ZeroEx.sol";
import {ISpigotedLine} from "../interfaces/ISpigotedLine.sol";
import {IEscrow} from "../interfaces/IEscrow.sol";
import {ISpigot} from "../interfaces/ISpigot.sol";
import {ILineOfCredit} from "../interfaces/ILineOfCredit.sol";
import {ISecuredLine} from "../interfaces/ISecuredLine.sol";

interface IWeth {
    function deposit() external payable;
}

interface IdsETH {
    function setManager(address _manager) external;
} //  TODO - define this

interface IdsETHFeeSplitExtension {

    // READ
    function owner() external view returns (address);

    function operatorFeeRecipient() external view returns (address);

    // WRITE
    function transferOwnership(address newOwner) external;
    // function updateFeeRecipient(address _newFeeRecipient) external;
    function updateOperatorFeeRecipient(address _newFeeRecipient) external;
    function accrueFeesAndDistribute() external;
}

interface IManager {
    function operator() external view returns (address);
    function setOperator(address _newOperator) external;
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

    IdsETHFeeSplitExtension dsETH;
    IManager manager;


    // Credit Coop Infra Addresses

    address constant lineFactoryAddress = 0x89989dBe4CFa289dE6179e8d54EE755E471a4251;
    address constant oracleAddress = 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;


    // Borrower and Lender Addresses

    // address borrowerAddress = makeAddr("borrower"); // TODO  - Mock Borrower Address
    address lenderAddress = makeAddr("lender"); // TODO - Mock Lender Address


    // Index Address(s)
    address constant indexCoopOperations = 0xFafd604d1CC8b6B3B6CC859cF80Fd902972371C1; // Index Coop Operations Multisig


   // dsETH Addresses
    address constant dsETHToken = 0x341c05c0E9b33C0E38d64de76516b2Ce970bB3BE;  // dsETH Address
    address constant dsETHFeeSplitExtension  = 0xFCDEE96D9df5b318ea0EEB39d5d7642d9AFd7FdA; // FeeSplitExtensionAddress
    address constant feeSplitExtensionOwner = 0x4e59b44847b379578588920cA78FbF26c0B4956C; // Owner of the dsETH fee split extension
    address constant dsETHManager = 0xBB6134ba82192E0ab23De846f1Cae7aa9Ae383d5; // Manager of the dsETH product
    address constant dsETHOperator = 0x6904110f17feD2162a11B5FA66B188d801443Ea4;// Operator of the dsETH product


    // Credit Coop Addresses
    address constant arbiterAddress = 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a ; // Credit Coop MultiSig
    address public securedLineAddress; // Line address, to be defined in setUp()


    // Asset Addresses
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;


    // Money Vars
    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 collateralAmtDAI = 50000000000000000000000; // 50,000 DAI --> 50000000000000000000000


    // Loan Terms

    uint256 ttl = 90 days;
    uint32 minCRatio = 1250; // BPS
    uint8 revenueSplit = 100;
    uint256 loanSizeInWETH = 200 ether;
    uint128 dRate = 1250; // BPS
    uint128 fRate = 1250; // BPS


    // Fork Settings

    // uint256 constant FORK_BLOCK_NUMBER = 16_991_081; // Forking mainnet at block right after Line Factory was deployed
    uint256 constant FORK_BLOCK_NUMBER = 17_032_817; // Forking mainnet at block on 4/12/23 at 11 30 AM EST
    uint256 ethMainnetFork;

    event log_named_bytes4(string key, bytes4 value);

    constructor() {
        ethMainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(ethMainnetFork);

        emit log_named_string("rpc", vm.envString("MAINNET_RPC_URL"));

        emit log_named_address("borrower", indexCoopOperations);
        emit log_named_address("lender", lenderAddress);
    }

    function setUp() public {
        // Create  Interfaces for CC infra

        oracle = IOracle(address(oracleAddress));
        lineFactory = ILineFactory(address(lineFactoryAddress));


        // Deal assets to all 3 parties (borrower, lender, arbiter) NOTE: will use actual address of parties whhen they are known

        // vm.deal(borrowerAddress, 100 ether);
        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);

        // deal(DAI, borrowerAddress, 200000000000000000000000);
        // deal(WETH, borrowerAddress, 100 ether);
        deal(WETH, lenderAddress, 10000 ether);
        deal(WETH, indexCoopOperations, 10 ether);


        // Borrower Deploys Line of Credit

        vm.startPrank(indexCoopOperations);

        securedLineAddress = _deployLoCWithConfig();


        // Define interfaces for all CC modules

        securedLine = ISecuredLine(securedLineAddress);
        line = ILineOfCredit(securedLineAddress);
        spigotedLine = ISpigotedLine(securedLineAddress);
        escrow = IEscrow(address(securedLine.escrow()));
        spigot = ISpigot(address(securedLine.spigot()));


        // Define Interfaces for Index Coop Modules

        dsETH = IdsETHFeeSplitExtension(dsETHFeeSplitExtension);
        manager = IManager(dsETHManager);


        // Check status after creation

        uint256 status = uint256(line.status());
        console.log("status", status);

        vm.stopPrank();

    }

    ///////////////////////////////////////////////////////
    //             S C E N A R I O   T E S T             //
    ///////////////////////////////////////////////////////

    function test_index_re7_simulation() public {

        // arbiter enables collateral

        vm.startPrank(arbiterAddress);
        bool collateralEnabled = escrow.enableCollateral(DAI);
        assertEq(true, collateralEnabled);
        vm.stopPrank();

        uint256 dsETHBalance = IERC20(dsETHToken).totalSupply();
        emit log_named_uint("total Supply of dsETH ", dsETHBalance);
        // index deposits collateral

        vm.startPrank(indexCoopOperations);
        IERC20(DAI).approve(address(securedLine.escrow()), MAX_INT);
        escrow.addCollateral(collateralAmtDAI, DAI);
        vm.stopPrank();

        // TODO - Work with Index team to get spigot sorted

        // // arbiter adds spigot (dsETH)

        vm.startPrank(arbiterAddress);
        uint8 split = 100;

        // do not care
        bytes4 claimFunc = 0x000000;

        // setOperator
        //bytes4 newOwnerFunc = _getSelector("transferOwnership(address newOwner)");
        bytes4 newOwnerFunc = _getSelector("setOperator(address)");

        _initSpigot(split, claimFunc, newOwnerFunc);

        vm.stopPrank();


        // index transfers ownership of dsETH to spigot

        // vm.startPrank(feeSplitExtensionOwner);
        // dsETH.transferOwnership(address(securedLine.spigot()));
        // vm.stopPrank();



        // 1. Index Coop changes updateOperatorFeeRecipient to Spigot address in Fee Split Extension
        vm.startPrank(dsETHOperator);
        dsETH.updateOperatorFeeRecipient(address(securedLine.spigot()));
        assertEq(address(securedLine.spigot()), dsETH.operatorFeeRecipient());


        // 2. Index Coop changes dsETH operator revenue to spigot address via setOperator function
        manager.setOperator(address(securedLine.spigot()));
        vm.stopPrank();


        // re7 proposes position
        // index accepts position

        bytes32 positionId =  _lenderFundLoan();

        // check that the line position has the credit funds
        uint256 balance = IERC20(WETH).balanceOf(securedLineAddress);
        console.log(balance);


        // index draws down full amount

        vm.startPrank(indexCoopOperations);

        line.borrow(positionId, 200 ether);
        vm.stopPrank();

        // fast forward 3 months

        vm.warp(block.timestamp + (ttl - 1 days));

        vm.startPrank(indexCoopOperations);

        dsETH.accrueFeesAndDistribute();

        vm.stopPrank();

        // claim revenue

        _claimRevenueOnBehalfOfSpigot(claimFunc);

        // claim and repay

    // TODO: Figure out why 0x trade is failing


    //     vm.startPrank(arbiterAddress);
    //     uint claimable = spigot.getOwnerTokens(dsETHToken);
    //     emit log_named_uint("Owner Tokens in Spigot: ", claimable);

    //     bytes memory tradeData = abi.encodeWithSignature(
    //     'trade(address,address,uint256,uint256)',
    //     address(dsETHToken),
    //     address(WETH),
    //     claimable,
    //     1
    //   );
    //     spigotedLine.claimAndRepay(address(dsETHToken), tradeData);

    //     vm.stopPrank();


        // index repaysAndCloses line

        uint256 amountOwed = line.interestAccrued(positionId);

        emit log_named_uint("Interest ", amountOwed);

        vm.startPrank(indexCoopOperations);
        IERC20(WETH).approve(securedLineAddress, MAX_INT);
        line.depositAndClose();
        vm.stopPrank();


        // Lender withdraws principal + interest owed

        vm.startPrank(lenderAddress);
        line.withdraw(positionId, amountOwed);
        vm.stopPrank();

        // Borrower Releases Collateral
        vm.startPrank(indexCoopOperations);
        escrow.releaseCollateral(collateralAmtDAI, DAI, indexCoopOperations);
        spigotedLine.releaseSpigot(indexCoopOperations);
        address whoIsOperator = manager.operator();
        emit log_named_address("The Operator of dsETH is ", whoIsOperator);
        emit log_named_address("Spigot address is ", address(securedLine.spigot()));
        emit log_named_string("                ", "           ");
        spigot.removeSpigot(dsETHManager);
        whoIsOperator = manager.operator();

        emit log_named_address("The Operator of dsETH is ", whoIsOperator);
        emit log_named_address("Spigot address is ", indexCoopOperations);
        emit log_named_string("                ", "             ");
        // feeRecipient: indexCoopOperations

        dsETH.updateOperatorFeeRecipient(indexCoopOperations);
        assertEq(indexCoopOperations, dsETH.operatorFeeRecipient());

        manager.setOperator(dsETHOperator);
        whoIsOperator = manager.operator();
        emit log_named_address("The Operator of dsETH is ", whoIsOperator);
        emit log_named_address("Spigot address is ", dsETHOperator);
        vm.stopPrank();

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
        vm.startPrank(indexCoopOperations);
        securedLineAddress = _deployLoCWithConfig();

        assertEq(indexCoopOperations, line.borrower());
        assertEq(arbiterAddress, line.arbiter());

        // assertEq(ttl, ILineOfCredit(address(securedLine)).arbiter()); // TODO: check ttl
        // assertEq(mincRatio, ILineOfCredit(address(securedLine)).arbiter()); // TODO: check minCRatio
    }

    function test_arbiter_enables_stablecoin_collateral() public {
        // vm.startPrank(indexCoopOperations);
        // securedLine = _deployLoCWithConfig();
        // vm.stopPrank();

        vm.startPrank(arbiterAddress);
        bool collateralEnabled = escrow.enableCollateral(DAI);
        assertEq(true, collateralEnabled);
    }


    function test_borrower_can_draw_on_credit() public {

    }

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

    ///////////////////////////////////////////////////////
    //          I N T E R N A L   H E L P E R S          //
    ///////////////////////////////////////////////////////

    function _deployLoCWithConfig() internal returns (address){
        ILineFactory.CoreLineParams memory coreParams = ILineFactory.CoreLineParams({
            borrower: indexCoopOperations,
            ttl: ttl, // time to live
            cratio: minCRatio, // uint32(creditRatio),
            revenueSplit: revenueSplit // uint8(revenueSplit) - 100% to spigot
        });

        securedLineAddress = lineFactory.deploySecuredLineWithConfig(coreParams);
        return securedLineAddress;
    }

    function _borrowerDrawsOnCredit(bytes32 id, uint256 amount) internal returns (bool) {

    }

    function _depoistAndRepay(uint256 amount) internal {

    }

    function _depositAndClose() internal {

    }

    function _lenderWithdraws(bytes32 id, uint256 amount) internal {

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
        emit log_named_uint("amount claimed from FeeSplitExtension ", claimed);
    }


    // fund a loan as a lender
    function _lenderFundLoan() internal returns (bytes32 id) {
        assertEq(vm.activeFork(), ethMainnetFork, "mainnet fork is not active");

        vm.startPrank(indexCoopOperations);
        line.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInWETH, // amount
            WETH, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        vm.startPrank(lenderAddress);
        IERC20(WETH).approve(address(line), loanSizeInWETH);
        id = line.addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInWETH, // amount
            WETH, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        assertEq(IERC20(WETH).balanceOf(address(line)), loanSizeInWETH, "LoC balance doesn't match");
        emit log_named_bytes32("credit id", id);
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
            spigotedLine.addSpigot(dsETHManager, settings),
            "Failed to add spigot"
        );

        // give spigot ownership to claim revenue
        // dsETHFeeSplitExtension.call(
        //     abi.encodeWithSelector(newOwnerFunc, spigot)
        // );
    }
}