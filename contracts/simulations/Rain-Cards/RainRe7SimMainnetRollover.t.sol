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
    address public securedLineAddress = 0xbF2d49EcfE657132F34863263D654d8e2eb1D72e; // Line address, to be defined in setUp()
    address public spigotAddress = 0x78176f8723F48a72FE9d2bE10D456529a77F7458;
    address public escrowAddress = 0xf60e510104776414d4947Ca81C9066C8e7e05aFd;
    address public lineFactory = 0x07d5c33a3AFa24A25163D2afDD663BAb4C17b6d5;

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
    uint256 constant FORK_BLOCK_NUMBER = 19_591_810; // Forking mainnet at block on 7/6/23 at 7 40 PM EST
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
        line = ILineOfCredit(address(securedLineAddress));
        factory = ILineFactory(address(lineFactory));


        console.log("1");
        // Deal assets to all 3 parties (borrower, lender, arbiter)
        vm.deal(arbiterAddress, 100 ether);
        vm.deal(lenderAddress, 100 ether);
        vm.deal(rainBorrower, 100 ether);

        console.log("2");

        deal(USDC, lenderAddress, 2000000 * 10 ** 6);
        deal(USDC, rainBorrower, 2000000 * 10 ** 6);

        console.log("3");

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

    function test_rain_rollover_simulation_mainnet() public {
        // repay existing line
        vm.startPrank(lenderAddress);
        IERC20(USDC).approve(rainBorrower, 2000000 * 10 ** 6);
        IERC20(USDC).transfer(rainBorrower, 2000000 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(rainBorrower);
    
        line.depositAndClose();
        
        
    
        // call rollover on the factory

        address newLine = factory.rolloverSecuredLine(payable(securedLineAddress), rainBorrower, ttl);
        ISecuredLine(securedLineAddress).rollover(newLine);
        vm.stopPrank();

        // confirm new line is created
        console.log("new line address is not equal to address(0)");
        assertEq(newLine != address(0), true, "new line not created");
        // confirm new line owns old modules
        console.log("escrowAddress is owned by newLine");
        assertEq(IEscrow(escrowAddress).line(), newLine, "escrowAddress not transferred");
        console.log("spigotAddress is owned by newLine");
        assertEq(ISpigot(spigotAddress).owner(), newLine, "spigot not transferred");
    
        // confirm new line has same borrower
        console.log("newLine borrower is rainBorrower");
        assertEq(ILineOfCredit(newLine).borrower(), rainBorrower, "borrower not transferred");

        //confirm line is active
        console.log("newLine status is active");
        assertEq(uint256(ILineOfCredit(newLine).status()), 1, "line not active");
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