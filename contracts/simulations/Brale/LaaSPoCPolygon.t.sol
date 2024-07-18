pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {LineFactory} from "../../modules/factories/LineFactory.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IPolygonOracle} from "../../interfaces/IPolygonOracle.sol";
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
import {ILineFactory} from "../../interfaces/ILineFactory.sol";
import {SBCPriceFeedPolygon} from "../../modules/oracle/SBCPriceFeedPolygon.sol";


contract BralePolygonSimple is Test {
    IPolygonOracle public oracle;
    IERC20 public usdc;
    IERC20 public SBC;
    ISecuredLine public securedLine;
    ISpigotedLine public spigotedLine;
    IEscrow public escrow;
    ISpigot public spigot;
    ISpigot.Setting private settings;
    ILineFactory public lineFactory;
    SecuredLine public line;

    uint256 MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    address constant lineFactoryAddress = 0x3e59121ce72F1a66F0eb14b5130C142542F93aD6;
    uint256 ttl = 60 days;

    address constant SBC  = 0xfdcC3dd6671eaB0709A4C0f3F53De9a333d80798;
    address constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    address constant arbiter = 0xFE002526dEc5B3e4b5134b75b20c065178323343;
    address borrower;
    address lender;

    SBCPriceFeedPolygon public priceFeed;
    address public polygonOracle = 0x034e4164f84580D22251ca944186Bb137d74A586; 
    address public oracleOwner = 0xf44B95991CaDD73ed769454A03b3820997f00873; 

    uint256 FORK_BLOCK_NUMBER = 59_496_579;
    uint256 polygonFork;
    uint256 lentAmount = 100000 * 1e6; // 100k USDC
    uint256 MARGIN_OF_ERROR = 0.001e18; //.1% margin of error (1e18 is 100%)
    address lineAddress;

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("POLYGON_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(polygonFork);

        oracle = IPolygonOracle(polygonOracle);

        priceFeed = new SBCPriceFeedPolygon();
        vm.startPrank(oracleOwner);
        oracle.setPriceFeed(SBC, address(priceFeed));
        vm.stopPrank();

        borrower = makeAddr('borrower');
        lender = makeAddr('lender');

        deal(USDC, lender, lentAmount);
        deal(SBC, borrower, lentAmount);

        // NOTE: Leftover from before deploying the line on Arbitrum
        ILineFactory.CoreLineParams memory coreParams = ILineFactory.CoreLineParams({
            borrower: borrower,
            ttl: ttl,
            cratio: 2000,
            revenueSplit: 0
        });
        
        lineAddress = ILineFactory(lineFactoryAddress).deploySecuredLineWithConfig(coreParams);

        line = SecuredLine(payable(lineAddress));

        escrow = line.escrow();

        _mintAndApprove();

    }

    function _mintAndApprove() public {
        vm.startPrank(lender);
        IERC20(USDC).approve(address(line), MAX_INT);
        vm.stopPrank();

        vm.startPrank(borrower);
        IERC20(SBC).approve(address(line.escrow()), MAX_INT);
        vm.stopPrank();
    }

    function _addCredit() internal {
        vm.startPrank(lender);
        ILineOfCredit(lineAddress).addCredit(700, 700, lentAmount, USDC, lender);
        vm.stopPrank();

        vm.startPrank(borrower);
        ILineOfCredit(lineAddress).addCredit(700, 700, lentAmount, USDC, lender);
        vm.stopPrank();
    }

    // NOTE: This is a simple end to end test of D8X
    function test_brale_credit_line() public {

        // TODO borrower needs to add SBC to escrow

        vm.startPrank(arbiter);
        escrow.enableCollateral(SBC);
        vm.stopPrank();

        vm.startPrank(borrower);
        escrow.addCollateral(20001 ether, SBC);
        vm.stopPrank();

        assertEq(IERC20(SBC).balanceOf(address(escrow)), 20001 ether);


        _addCredit();

        bytes32 id = line.ids(0);

        vm.startPrank(borrower);
        emit log_named_string('\n \u2713 borrower draws funds', '');
        ILineOfCredit(lineAddress).borrow(id, lentAmount);
        vm.stopPrank();

        assertGt(escrow.getCollateralRatio(), escrow.minimumCollateralRatio());
        assertEq(IERC20(USDC).balanceOf(borrower), lentAmount);
    }
}