import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction} from 'hardhat-deploy/types';
import { utils } from "ethers";
import { ethers } from 'hardhat';
const toWei = (n: number) => utils.formatUnits(n, "wei");

const oneDayInSec = 60*60*24;
const deployTestLine: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
}) {
  const { deploy, execute } = deployments;
  console.log('deployments', deployments);
  const { deployer } = await getNamedAccounts();
  const [_,__,___,debf] = await getUnnamedAccounts();
  const from = deployer || debf;
  console.log('accounts', deployer, debf, from);
  // TODO abstract token and oracle deployment into separate scripts as dependencies
  const token = await deploy('RevenueToken', { from });

  console.log('deploy token', token.address);
  
  console.log('Deploying Oracle with pricing for token and ETH...');
  const oracle = await deploy('SimpleOracle', {
    from,
    args: [token.address, "0x0000000000000000000000000000000000000000"]
  });
  console.log('Oracle Deployed', oracle.address);
  
  console.log('Deploying Library...');
  const lib = await deploy('LoanLib', { from });
  console.log('Library deploydr', lib.address);

  console.log('Deploying Line of Credit for token...');
  const line = await deploy('SecuredLoan', {
    from,
    libraries: {
      'LoanLib': lib.address,
    },
    args: [
      oracle.address,
      from,             // borrower
      from,             // arbiter
      oracle.address,   // no swaps
      0,                // 0% min cratio
      oneDayInSec * 90, // 90d term length
      90,               // 90% rev to repay debt
    ],
  });
  console.log('deploy line', line);

  if(token.newlyDeployed) {
    console.log('Token just deployed. Minting to deployer...');
    // await token.mint(deployer, 5); // mint so we can borrow/lend/collateralize
    console.log('Token just deployed. Approving LoC...');
    // await token.approve(line.address, toWei(100))
  }

  const toLine = { from, to: line.address }

  // add line of credit
  const addCredit = () => execute(
    'SecuredLoan',
    toLine,
    'addCredit',
    // 10%, 5%
    [1000, 500, 10, token.address, deployer]
  );

  console.log('Adding LoC for token to deployer...');
  const res = await Promise.all([addCredit(), addCredit()]);
  
  console.log('Borrowing as deployer...');
  await execute(
    'SecuredLoan',
    toLine,
    'borrow',
    // positionId, amount
    [res[1], 5] // literally only 5, not 5 ether. Gorli ETH = mainnet ETH kekek
  );
};

// TODO setup scripts for initialization
// module.exports.dependencies = ['TestTokens', 'TestOracle'];
export default deployTestLine;
