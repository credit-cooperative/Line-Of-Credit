pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Spigot} from "../../modules/spigot/Spigot.sol";
import {IOracle} from "../../interfaces/IOracle.sol";
import {zkEVMOracle} from "../../modules/oracle/zkEVMOracle.sol";
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

// zkevm chainlink usdc price feed 0x0167D934CB7240e65c35e347F00Ca5b12567523a

interface IPerpetualTreasury {
    function addLiquidity(uint8 _poolId, uint256 _tokenAmount) external;
    function withdrawLiquidity(uint8 _poolId, uint256 _shareAmount) external;
    function executeLiquidityWithdrawal(uint8 _poolId, address _lpAddr) external;
    function getTokenAmountToReturn(uint8 _poolId, uint256 _shareAmount) external;
}

contract D8XLAAS is Test {
    IPerpetualTreasury public treasury;
    IOracle public oracle;
    IERC20 public usdc;
    IERC20 public lp;
    ISecuredLine public securedLine;
    ISpigotedLine public spigotedLine;
    IEscrow public escrow;

    treasury = IPerpetualTreasury(0xaB7794EcD2c8e9Decc6B577864b40eBf9204720f);
    usdc = IERC20(0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035);

    address constant borrower = 0xf44B95991CaDD73ed769454A03b3820997f00873;
    address constant lender = 0x9832FD4537F3143b5C2989734b11A54D4E85eEF6;
    address constant operator = 0x97fCbc96ed23e4E9F0714008C8f137D57B4d6C97;

    uint256 FORk_BLOCK_NUMBER = 9770820;
    uint256 zkEVMMainnetFork;

    function setUp{
        zkEVMMainnetFork = vm.createFork(vm.envString("ZKEMV_RPC_URL"), FORK_BLOCK_NUMBER);
        vm.selectFork(zkEVMMainnetFork);
    }






}