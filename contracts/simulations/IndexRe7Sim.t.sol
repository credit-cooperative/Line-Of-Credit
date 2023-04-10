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

contract IndexRe7Sim is Test {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    ILineFactory lineFactory;
    IOracle oracle;
    ISpigot.Setting private settings;

    address constant lineFactoryAddress = 0x89989dBe4CFa289dE6179e8d54EE755E471a4251; 
    address constant oracleAddress = 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    address borrowerAddress = makeAddr("borrower"); // TODO  - Index Coop Multisig
    address lenderAddress = makeAddr("lender"); // TODO - Re7 Depositer Address
    address constant revenueContractAddress = 0x341c05c0E9b33C0E38d64de76516b2Ce970bB3BE;  // dsETH Address 
    address constant arbiterAddress = 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a ; // Credit Coop MultiSig

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    uint256 ttl = 90 days;
    uint32 minCRatio = 1250; // BPS
    uint8 revenueSplit = 100;
    uint256 loanSizeInWETH = 200 ether; 
    uint128 dRate = 1250; // BPS
    uint128 fRate = 1250; // BPS

    address public securedLine;

    uint256 constant FORK_BLOCK_NUMBER = 16_991_081;


    // fork settings
    uint256 ethMainnetFork;

    event log_named_bytes4(string key, bytes4 value);

    constructor() {
        ethMainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(ethMainnetFork);

        emit log_named_string("rpc", vm.envString("MAINNET_RPC_URL"));

        emit log_named_address("borrower", borrowerAddress);
        emit log_named_address("lender", lenderAddress);

    }

    function setUp() public {
        // perform the tests on the mainnet fork
        oracle = IOracle(address(oracleAddress));
        lineFactory = ILineFactory(address(lineFactoryAddress));

        vm.deal(borrowerAddress, 100 ether);
        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);

        deal(DAI, borrowerAddress, 200000000000000000000000);
        deal(WETH, borrowerAddress, 100 ether);
        deal(WETH, lenderAddress, 10000 ether);

        vm.startPrank(borrowerAddress);
        securedLine = _deployLoCWithConfig();
        uint256 status = uint256(ILineOfCredit(securedLine).status());
        console.log("status", status);

        vm.stopPrank();

    }

    ///////////////////////////////////////////////////////
    //             S C E N A R I O   T E S T             //
    ///////////////////////////////////////////////////////

    function test_index_re7_simulation() public {

        // arbiter enables collateral
        vm.startPrank(arbiterAddress);
        address escrowAddress = address(ISecuredLine(address(securedLine)).escrow());
        address spigotAddress = address(ISecuredLine(address(securedLine)).spigot());
      

        bool collateralEnabled = IEscrow(address(escrowAddress)).enableCollateral(DAI);
        vm.stopPrank();

        // index deposits collateral
        vm.startPrank(borrowerAddress);
        IERC20(DAI).approve(address(escrowAddress), MAX_INT);
        IEscrow(escrowAddress).addCollateral(190000000000000000000000, DAI); // 190,000 DAI --> 190000000000000000000000
        vm.stopPrank();

        // TODO - Work with Index team to get spigot sorted

        // // arbiter adds spigot (dsETH)
        // vm.startPrank(arbiterAddress);
        // ISpigot(spigotAddress).addSpigot();
        // index transfers ownership of dsETH to spigot

        // re7 proposes position
        // index accepts position
        bytes32 positionId =  _lenderFundLoan(securedLine);

        uint256 balance = IERC20(WETH).balanceOf(securedLine);
        console.log(balance);

        // index draws down full amount
        vm.startPrank(borrowerAddress);

        // ILineOfCredit(securedLine).healthcheck();
        // uint256 status2 = uint256(ILineOfCredit(securedLine).status());
        // console.log("status  before borrow", status2);

        ILineOfCredit(securedLine).borrow(positionId, 200 ether);
        vm.stopPrank();
        
        // fast forward 3 months
        vm.warp(block.timestamp + (ttl - 1 days));

        // index repaysAndCloses line

        uint256 amountOwed = ILineOfCredit(securedLine).interestAccrued(positionId);

        emit log_named_uint("Principal + Interest: ", amountOwed);

        vm.startPrank(borrowerAddress);
        IERC20(WETH).approve(securedLine, MAX_INT);
        ILineOfCredit(securedLine).depositAndClose();
        vm.stopPrank();

        vm.startPrank(lenderAddress);
        ILineOfCredit(securedLine).withdraw(positionId, amountOwed);

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
        vm.startPrank(borrowerAddress);
        securedLine = _deployLoCWithConfig();

        assertEq(borrowerAddress, ILineOfCredit(address(securedLine)).borrower());
        assertEq(arbiterAddress, ILineOfCredit(address(securedLine)).arbiter());
        
        // assertEq(ttl, ILineOfCredit(address(securedLine)).arbiter()); // TODO: check ttl
        // assertEq(mincRatio, ILineOfCredit(address(securedLine)).arbiter()); // TODO: check minCRatio
    }

    function test_arbiter_enables_stablecoin_collateral() public {
        // vm.startPrank(borrowerAddress);
        // securedLine = _deployLoCWithConfig();
        // vm.stopPrank();

        vm.startPrank(arbiterAddress);
        address escrowAddress = address(ISecuredLine(address(securedLine)).escrow());
        bool collateralEnabled = IEscrow(address(escrowAddress)).enableCollateral(DAI);
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
            borrower: borrowerAddress,
            ttl: ttl, // time to live
            cratio: minCRatio, // uint32(creditRatio),
            revenueSplit: revenueSplit // uint8(revenueSplit) - 100% to spigot
        });

        securedLine = lineFactory.deploySecuredLineWithConfig(coreParams);
        return securedLine;
    }


    function _addSpigot(address _lineOfCredit) internal returns (bool){

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
        vm.deal(revenueContractAddress, amt + 0.5 ether); // add a bit to cover gas

        vm.prank(revenueContractAddress);
        revenue = amt;
        IWeth(WETH).deposit{value: revenue}();

        assertEq(IERC20(WETH).balanceOf(revenueContractAddress), revenue, "fee collector balance should match revenue");
    }

    /// @dev    Because they claim function is not set in the spigot, this will be a push payment only
    /// @dev    We need to call `deposit()` manually before claiming revenue, or there will be no revenue
    ///         to claim (because calling `deposit()` distribute revenue to beneficiaires,of which the spigot is one)
    function _claimRevenueOnBehalfOfSpigot(address _spigot, uint256 _expectedRevenue) internal {
        bytes memory data = abi.encodePacked("");
        ISpigot(_spigot).claimRevenue(revenueContractAddress, WETH, data);
        assertEq(_expectedRevenue, IERC20(WETH).balanceOf(_spigot), "balance of spigot should match expected revenue");
    }

    
    // fund a loan as a lender
    function _lenderFundLoan(address _lineOfCredit) internal returns (bytes32 id) {
        assertEq(vm.activeFork(), ethMainnetFork, "mainnet fork is not active");

        // vm.roll(block.number + 5000);

        vm.startPrank(borrowerAddress);
        ILineOfCredit(_lineOfCredit).addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInWETH, // amount
            WETH, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        vm.startPrank(lenderAddress);
        IERC20(WETH).approve(_lineOfCredit, loanSizeInWETH);
        id = ILineOfCredit(_lineOfCredit).addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInWETH, // amount
            WETH, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        assertEq(IERC20(WETH).balanceOf(address(_lineOfCredit)), loanSizeInWETH, "LoC balance doesn't match");
        return id;

        emit log_named_bytes32("credit id", id);
    }



    ///////////////////////////////////////////////////////
    //                      U T I L S                    //
    ///////////////////////////////////////////////////////

    // returns the function selector (first 4 bytes) of the hashed signature
    function _getSelector(string memory _signature) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(_signature)));
    }

    function _initSpigot(
    
        address spigot,
        uint8 split,
        bytes4 claimFunc,
        bytes4 newOwnerFunc
        // bytes4[] memory _whitelist
    ) internal {
        
        settings = ISpigot.Setting(split, claimFunc, newOwnerFunc);

        // add spigot for revenue contract
        require(
            ISpigot(spigot).addSpigot(revenueContractAddress, settings),
            "Failed to add spigot"
        );

        // give spigot ownership to claim revenue
        revenueContractAddress.call(
            abi.encodeWithSelector(newOwnerFunc, spigot)
        );
    }
}