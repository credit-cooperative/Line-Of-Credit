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
    SecuredLine line;
    // ISpigotedLine spigotedLine;
    // IEscrow escrow;

    // LineOfCredit line;

    SecuredLine securedLine;
    Escrow escrow;
    Spigot spigot;
    ILineFactory factory;

    IRainCollateralFactory rainCollateralFactory;
    IRainCollateralController rainCollateralController;

    // Credit Coop Infra Addresses
    address constant oracleAddress = 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
    // Old Line Factory Address
    // address constant lineFactoryAddress = 0x89989dBe4CFa289dE6179e8d54EE755E471a4251;

    // Rain Cards Borrower Address
    address rainBorrower = 0x34FB953287cF28B3404C1D21E56c495545CCb600; // Rain Borrower Address
    address lenderAddress = 0xb8dEF7C89A5ddC324Bd12A0F47CD1CF2063bf38e; // Lender Address re7
    address lenderAddress2 = 0xb991B5dD8e6cb2d9D517572CD736f37480bF07DD; // Lender Address nate

    // Rain Controller Contract & Associated Addresses
    address rainCollateralFactoryAddress = 0x31EBf70312f488D0bdAc374b340f0D01dBf153B5;
    address rainCollateralControllerAddress = 0xE5D3d7da4b24bc9D2FDA0e206680CD8A00C0FeBD;
    address rainControllerAdminAddress = 0xB92949bdF09F4193599Ae7700211751ab5F74aCd;
    // address rainFactoryOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;
    address rainControllerOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc;
    // address rainTreasuryContractAddress = 0x0204C22BE67968C3B787D2699Bd05cf2b9432c60;


    // Credit Coop Addresses
    address constant arbiterAddress = 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a ; // Credit Coop MultiSig
    address public securedLineAddress = 0x7e43D0C5860002796A749c6D8e0e864210c85c6A; // Line address, to be defined in setUp()
    address public spigotAddress = 0x78176f8723F48a72FE9d2bE10D456529a77F7458;
    address public escrowAddress = 0xf60e510104776414d4947Ca81C9066C8e7e05aFd;
    address public lineFactory = 0x07d5c33a3AFa24A25163D2afDD663BAb4C17b6d5;
    address public zeroEx = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    // Asset Addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Money Vars
    uint256 MAX_INT = type(uint256).max;

    // Loan Terms
    uint256 ttl = 120 days;
    uint32 minCRatio = 0; // BPS
    uint8 revenueSplit = 100;
    uint256 loanSizeInUSDC = 3750000 * 10 ** 6;
    uint128 dRate = 1000; // BPS
    uint128 fRate = 1000; // BPS

    // Fork Settings
    uint256 constant FORK_BLOCK_NUMBER = 21525850; // Block number to fork at 12/31/2024
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

        console.log("0");

        // Create  Interfaces for CC infra
        oracle = IOracle(address(oracleAddress));
        line = SecuredLine(payable(securedLineAddress));
        factory = ILineFactory(address(lineFactory));
        spigot = Spigot(payable(spigotAddress));

        console.log("1");
        // Deal assets to all 3 parties (borrower, lender, arbiter)
        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);
        vm.deal(rainBorrower, 100 ether);

        console.log("2");

        deal(USDC, lenderAddress, 4000000 * 10 ** 6);
        // deal(USDC, rainBorrower, 2000000 * 10 ** 6);

        console.log("3");

        // Define Interface for Rain Collateral Factory & Controller
        rainCollateralFactory = IRainCollateralFactory(rainCollateralFactoryAddress);
        rainCollateralController = IRainCollateralController(rainCollateralControllerAddress);
    }

    ///////////////////////////////////////////////////////
    //             S C E N A R I O   T E S T             //
    ///////////////////////////////////////////////////////

    function test_get_rain_credit_balances() public {

        bytes32 id = line.ids(0);
        bytes32 id2 = line.ids(1);


        (uint256 deposit1,uint256 principal1,uint256 interestAccruedPosition1,uint256 interestRepaid1,,,,) = line.credits(id);
        (uint256 deposit2,uint256 principal2,uint256 interestAccruedPosition2,uint256 interestRepaid2,,,,) = line.credits(id2);

        uint256 interestAccrued1 = line.interestAccrued(id);
        uint256 interestAccrued2 = line.interestAccrued(id2);

        uint256 total1 = principal1 + principal2 + interestAccruedPosition1 + interestAccruedPosition2;
        uint256 total2 = principal1 + principal2 + interestAccrued1 + interestAccrued2;
        emit log_named_uint("Total Credit Balance on Secured Line 1", total1);
        emit log_named_uint("Total Credit Balance on Secured Line 2", total2);
        emit log_named_uint("Total Principal Balance on Secured Line 2", principal1 + principal2);
        emit log_named_uint("Total Deposit on Secured Line 1: %s", deposit1 + deposit2);
        emit log_named_uint("Credit 1 - Deposit", deposit1);
        emit log_named_uint("Credit 1 - Principal", principal1);
        emit log_named_uint("Credit 1 - Interest Accrued", interestAccrued1);
        emit log_named_uint("Credit 2 - Deposit", deposit2);
        emit log_named_uint("Credit 2 - Principal", principal2);
        emit log_named_uint("Credit 2 - Interest Accrued", interestAccrued2);


    }


    ///////////////////////////////////////////////////////
    //          I N T E R N A L   H E L P E R S          //
    ///////////////////////////////////////////////////////

    function _deployLoCWithConfig(LineFactory lineFactory) internal returns (address){
        // create Escrow and Spigot
        escrow = new Escrow(minCRatio, oracleAddress, rainControllerOwnerAddress, rainBorrower);
        spigot = new Spigot(rainControllerOwnerAddress, rainControllerOwnerAddress);

        // create SecuredLine
        securedLine = new SecuredLine(oracleAddress, arbiterAddress, rainBorrower, payable(zeroExSwapTarget), address(spigot), address(escrowAddress), ttl, revenueSplit);

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

        lineFactory.registerSecuredLine(address(securedLine), address(spigot), address(escrowAddress), rainBorrower, rainBorrower, revenueSplit, minCRatio);

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
    function _lenderFundLoan(address newLine) internal returns (bytes32 id) {
        assertEq(vm.activeFork(), ethMainnetFork, "mainnet fork is not active");

        emit log_named_string("\n \u2713 Lender Proposes Position to Line of Credit", "");
        vm.startPrank(lenderAddress);
        console.log('6.1');
        IERC20(USDC).approve(address(newLine), loanSizeInUSDC);
        emit log_named_uint("- lender balance before addCredit", IERC20(USDC).balanceOf(lenderAddress));
        console.log('6.2');
        ILineOfCredit(newLine).addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInUSDC, // amount
            USDC, // token
            lenderAddress // lender
        );
        vm.stopPrank();
        console.log('6.3');

        emit log_named_string("\n \u2713 Borrower Accepts Lender Proposal to Line of Credit", "");
        vm.startPrank(rainBorrower);

        id = ILineOfCredit(newLine).addCredit(
            dRate, // drate
            fRate, // frate
            loanSizeInUSDC, // amount
            USDC, // token
            lenderAddress // lender
        );
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(address(newLine)), loanSizeInUSDC, "LoC balance doesn't match");
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