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
import {IEscrowedLine} from "../../interfaces/IEscrowedLine.sol";
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
    ISecuredLine securedLine1;
    ILineOfCredit line;
    // ISpigotedLine spigotedLine;
    // IEscrow escrow;

    // LineOfCredit line;
    // SecuredLine securedLine1;
    // SecuredLine securedLine2;
    ISecuredLine securedLine2;
    IEscrow escrow;
    ISpigot spigot;

    IRainCollateralFactory rainCollateralFactory;
    IRainCollateralController rainCollateralController;

    // Credit Coop Infra Addresses
    address constant oracleAddress = 0x5a4AAF300473eaF8A9763318e7F30FA8a3f5Dd48;
    address constant zeroExSwapTarget = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
    // Old Line Factory Address
    // address constant lineFactoryAddress = 0x89989dBe4CFa289dE6179e8d54EE755E471a4251;

    // Rain Cards Borrower Address
    address constant rainBorrower = 0x34FB953287cF28B3404C1D21E56c495545CCb600; // Rain Borrower Address
    address lenderAddress = makeAddr("lender");

    // Rain Controller Contract & Associated Addresses
    address rainCollateralFactoryAddress = 0x31EBf70312f488D0bdAc374b340f0D01dBf153B5;
    address rainCollateralControllerAddress = 0xE5D3d7da4b24bc9D2FDA0e206680CD8A00C0FeBD;
    address rainControllerAdminAddress = 0xB92949bdF09F4193599Ae7700211751ab5F74aCd; //TBD
    address rainFactoryOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc; //TBD
    address rainControllerOwnerAddress = 0x21ebc2f23a91fD7eB8406CDCE2FD653de280B5fc; //TBD
    address rainTreasuryContractAddress = 0x0204C22BE67968C3B787D2699Bd05cf2b9432c60; //TBD

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

    uint256 rainUser0Amount = 700000 * 10 ** 6;
    uint256 finalSpigotBalance = rainUser0Amount;

    // Credit Coop Addresses
    address constant arbiterAddress = 0xeb0566b1EF38B95da2ed631eBB8114f3ac7b9a8a ; // Credit Coop MultiSig
    address public securedLineAddress1 = 0xdf29e982784DD0D344F2FD7a0E5B9aff6208E463; // Line address, to be defined in setUp()
    address public securedLineAddress2 = 0xbF2d49EcfE657132F34863263D654d8e2eb1D72e;
    address public spigotAddress = 0x78176f8723F48a72FE9d2bE10D456529a77F7458;
    address public escrowAddress = 0xf60e510104776414d4947Ca81C9066C8e7e05aFd;

    // Contract Address
    // securedLineAddress1 = 0xdf29e982784dd0d344f2fd7a0e5b9aff6208e463;
    // spigotAddress = 0x78176f8723F48a72FE9d2bE10D456529a77F7458;
    // escrowAddress = 0xf60e510104776414d4947Ca81C9066C8e7e05aFd;

    // Asset Addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Money Vars
    uint256 MAX_INT = type(uint256).max;

    // Loan Terms
    uint256 ttl = 60 days;
    uint32 minCRatio = 0; // BPS
    uint8 revenueSplit = 100;
    uint256 loanSizeInUSDC = 600000 * 10 ** 6;
    uint128 dRate = 1500; // BPS
    uint128 fRate = 1500; // BPS

    // Fork Settings
    uint256 constant FORK_BLOCK_NUMBER = 18_772_855; // Forking mainnet at block on 12/8/23 at 8 30 AM PST
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

        deal(USDC, lenderAddress, 600000 * 10 ** 6);

        // Deal USDC to Rain (Fake) User Addresses
        deal(USDC, rainUser0, 700000 * 10 ** 6);

        // Define Interface for Rain Collateral Factory & Controller
        rainCollateralFactory = IRainCollateralFactory(rainCollateralFactoryAddress);
        rainCollateralController = IRainCollateralController(rainCollateralControllerAddress);

    }

    ///////////////////////////////////////////////////////
    //             S C E N A R I O   T E S T             //
    ///////////////////////////////////////////////////////

    function test_rain_re7_simulation_mainnet_rollover() public {

        // // Deploy Credit Coop Factory Contracts
        // ModuleFactory moduleFactory = new ModuleFactory();
        // LineFactory lineFactory = new LineFactory(address(moduleFactory), arbiterAddress, oracleAddress, payable(zeroExSwapTarget));

        // // Borrower Deploys Line of Credit
        // emit log_named_string("\n \u2713 Borrower Deploys Line of Credit", "");
        // securedLineAddress = _deployLoCWithConfig(lineFactory);

        // Define interfaces for all CC modules
        // securedLine1 = ILineOfCredit(securedLineAddress1);
        spigot = ISpigot(spigotAddress);
        escrow = IEscrow(escrowAddress);

        // Check status == REPAID after position is repaid and closed
        uint256 statusIsRepaid = uint256(ILineOfCredit(securedLineAddress1).status());
        assertEq(3, statusIsRepaid);
        emit log_named_uint("- status (3 == REPAID) ", statusIsRepaid);

        // Credit Coop deploys new Line of Credit
        // securedLine2 = new SecuredLine(oracleAddress, arbiterAddress, rainBorrower, payable(zeroExSwapTarget), spigotAddress, escrowAddress, ttl, revenueSplit);

        securedLine2 = ISecuredLine(securedLineAddress2);
        emit log_named_address('secured line 2 ', securedLineAddress2);
        // emit log_named_uint('secured line 2 - status ', uint256(ILineOfCredit(securedLineAddress2).status()));

        // Borrower calls rollover to transfer escrow and spigot to securedLine2
        vm.startPrank(rainBorrower);
        emit log_named_string("\n \u2713 Borrower Calls rollover Function to Transfer Escrow and Spigot to New Line of Credit", "");
        emit log_named_address('borrower address 1: ', ILineOfCredit(securedLineAddress1).borrower());
        emit log_named_address('borrower address 2: ', ILineOfCredit(securedLineAddress2).borrower());
        emit log_named_address('rain borrower: ', rainBorrower);

        ISecuredLine(securedLineAddress1).rollover(securedLineAddress2);
        console.log('do I get here 0');
        // assertEq(ISpigotedLine(securedLineAddress2).spigot(), spigotAddress);
        // assertEq(IEscrowedLine(securedLineAddress2).escrow(), escrowAddress);
        vm.stopPrank();

        // Spigot and Escrow owned by new line
        assertEq(ISpigot(spigotAddress).owner(), securedLineAddress2);
        assertEq(IEscrow(escrowAddress).line(), securedLineAddress2);

        // Check that line is active
        console.log('do I get here 1');
        emit log_named_uint('secured line 2 - status ACTIVE ', uint256(ILineOfCredit(securedLineAddress2).status()));

        // // Rain sweeps the remaining unused assets from the line of credit
        // emit log_named_string("\n \u2713 Borrower Calls sweep Function to Regain Ownership of Unused Assets From Line of Credit", "");
        // vm.startPrank(rainBorrower);

        // uint256 unusedTokensAfterClose0 = securedLine.unused(USDC);

        // emit log_named_uint(" - Unused Tokens after Position is closed and line is repaid (before sweep)", unusedTokensAfterClose0);

        // securedLine.sweep(rainBorrower, address(USDC), unusedTokensAfterClose0);

        // uint256 unusedTokensAfterClose1 = securedLine.unused(USDC);

        // emit log_named_uint(" - Unused Tokens after Position is closed and line is repaid (after sweep)", unusedTokensAfterClose1);

        // assertEq(0, unusedTokensAfterClose1);
        // emit log_named_uint(" - remaining spigot assets ", IERC20(USDC).balanceOf(address(spigot)));
        // emit log_named_uint(" - remaining line assets ", IERC20(USDC).balanceOf(address(securedLine)));

        // vm.stopPrank();


        // // Lender withdraws principal + interest owed
        // vm.startPrank(lenderAddress);
        // emit log_named_string("\n \u2713 Lender Withdraws All Repaid Principal and Interest", "");
        // securedLine.withdraw(creditPositionId, interestAccrued + loanSizeInUSDC);
        // uint256 lenderBalanceAfterRepayment = IERC20(USDC).balanceOf(lenderAddress);
        // uint256 borrowerBalanceAfterRepayment = IERC20(USDC).balanceOf(rainBorrower);

        // // check that the lender balance is principal + interest
        // emit log_named_uint(" - Lender Balance After Repayment ", lenderBalanceAfterRepayment);
        // emit log_named_uint(" - Borrower Repayment Amount ", borrowerBalanceAfterRepayment - rainBorrowerStartingBalance);
        // emit log_named_uint(" - Line Balance After Repayment ", IERC20(USDC).balanceOf(address(securedLine)));
        // assertEq(lenderBalanceAfterRepayment, loanSizeInUSDC + interestAccrued, "Lender has not been fully repaid");
        // assertEq(finalOperatorTokensBalance, lenderBalanceAfterRepayment + borrowerBalanceAfterRepayment - rainBorrowerStartingBalance);
        // vm.stopPrank();

        // // Borrower Releases Spigot
        // vm.startPrank(rainBorrower);

        // emit log_named_string("\n \u2713 Borrower Releases Spigot to Rain Collateral Controller Owner Address", "");
        // securedLine.releaseSpigot(rainControllerOwnerAddress);
        // vm.stopPrank();

        // vm.startPrank(rainControllerOwnerAddress);
        // emit log_named_string("\n \u2713 Borrower Removes Rain Collateral Controller from Spigot", "");
        // spigot.removeSpigot(rainCollateralControllerAddress);

        // assertEq(rainControllerOwnerAddress, rainCollateralController.owner());

        // vm.stopPrank();

        // // OPTIONAL - Joint Multisig Transfers Ownership of Rain Collateral Factory Back to Rain Collateral Factory Owner Address
        // // TODO

    }


    ///////////////////////////////////////////////////////
    //          I N T E R N A L   H E L P E R S          //
    ///////////////////////////////////////////////////////

    // function _deployLoCWithConfig(LineFactory lineFactory) internal returns (address){
    //     // create Escrow and Spigot
    //     escrow = new Escrow(minCRatio, oracleAddress, rainControllerOwnerAddress, rainBorrower);
    //     spigot = new Spigot(rainControllerOwnerAddress, rainControllerOwnerAddress);

    //     // create SecuredLine
    //     securedLine2 = new SecuredLine(oracleAddress, arbiterAddress, rainBorrower, payable(zeroExSwapTarget), address(spigot), address(escrow), ttl, revenueSplit);

    //     // transfer ownership of both Spigot and Escrow to SecuredLine
    //     vm.startPrank(rainControllerOwnerAddress);
    //     spigot.updateOwner(address(securedLine2));
    //     escrow.updateLine(address(securedLine2));
    //     vm.stopPrank();

    //     // call init() on Line of Credit, register on Line Factory
    //     securedLine2.init();
    //     console.log("3");

    //     // Arbiter registers Spigot, Escrow, and SecuredLine using Factory Contracts to appear in Subgraph & Dapp
    //     vm.startPrank(arbiterAddress);

    //     lineFactory.registerSecuredLine(address(securedLine2), address(spigot), address(escrow), rainBorrower, rainBorrower, revenueSplit, minCRatio);

    //     vm.stopPrank();

    //     return address(securedLine2);
    // }

    // function _deployLoCWithConfigRollover(LineFactory lineFactory) internal returns (address){

    //     // create SecuredLine
    //     securedLine2 = new SecuredLine(oracleAddress, arbiterAddress, rainBorrower, payable(zeroExSwapTarget), spigotAddress, escrowAddress, ttl, revenueSplit);


    //     // call init() on Line of Credit, register on Line Factory
    //     securedLine2.init();
    //     console.log("3");

    //     // Arbiter registers Spigot, Escrow, and SecuredLine using Factory Contracts to appear in Subgraph & Dapp
    //     vm.startPrank(arbiterAddress);

    //     lineFactory.registerSecuredLine(address(securedLine2), spigotAddress, escrowAddress, rainBorrower, rainBorrower, revenueSplit, minCRatio);

    //     vm.stopPrank();

    //     return address(securedLine2);
    // }


    function _liquidateCollateralContractAssets(
        address rainCollateralContract,
        uint256 amount,
        address[] memory assets,
        uint256[] memory amounts
    ) internal returns (uint256, uint256) {
        emit log_named_address("\n - Rain Collateral Contract ", rainCollateralContract);
        amounts[0] = amount;
        uint256 startingSpigotBalance = IERC20(USDC).balanceOf(spigotAddress) + rainUser0Amount;
        emit log_named_uint("- starting Spigot balance ", startingSpigotBalance);
        rainCollateralController.liquidateAsset(rainCollateralContract, assets, amounts);
        uint256 endingSpigotBalance = IERC20(USDC).balanceOf(spigotAddress);
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


    // // fund a loan as a lender
    // function _lenderFundLoan() internal returns (bytes32 id) {
    //     assertEq(vm.activeFork(), ethMainnetFork, "mainnet fork is not active");

    //     emit log_named_string("\n \u2713 Lender Proposes Position to Line of Credit", "");
    //     vm.startPrank(lenderAddress);
    //     IERC20(USDC).approve(address(line), loanSizeInUSDC);
    //     securedLine.addCredit(
    //         dRate, // drate
    //         fRate, // frate
    //         loanSizeInUSDC, // amount
    //         USDC, // token
    //         lenderAddress // lender
    //     );
    //     vm.stopPrank();

    //     emit log_named_string("\n \u2713 Borrower Accepts Lender Proposal to Line of Credit", "");
    //     vm.startPrank(rainBorrower);

    //     id = securedLine.addCredit(
    //         dRate, // drate
    //         fRate, // frate
    //         loanSizeInUSDC, // amount
    //         USDC, // token
    //         lenderAddress // lender
    //     );
    //     vm.stopPrank();

    //     assertEq(IERC20(USDC).balanceOf(address(securedLine)), loanSizeInUSDC, "LoC balance doesn't match");
    //     emit log_named_bytes32("- credit id", id);
    //     return id;
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
            securedLine2.addSpigot(rainCollateralControllerAddress, settings),
            "Failed to add spigot"
        );

    }


}