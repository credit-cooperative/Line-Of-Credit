// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit/blob/master/COPYRIGHT.md

 // TODO: Imports for development purpose only
 import "forge-std/console.sol";

import {Denominations} from "chainlink/Denominations.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";

import {LineLib} from "../../utils/LineLib.sol";
import {CreditLib} from "../../utils/CreditLib.sol";
import {CreditListLib} from "../../utils/CreditListLib.sol";
import {MutualConsent} from "../../utils/MutualConsent.sol";
import {InterestRateCredit} from "../interest-rate/InterestRateCredit.sol";

import {IOracle} from "../../interfaces/IOracle.sol";
import {ILineOfCredit} from "../../interfaces/ILineOfCredit.sol";
import {LendingPositionToken} from "../tokenized-positions/LendingPositionToken.sol";

/**
 * @title  - Credit Cooperative Unsecured Line of Credit
 * @notice - Core credit facility logic for proposing, depositing, borrowing, and repaying debt.
 *         - Contains core financial covnenants around term length (`deadline`), collateral ratios, liquidations, etc.
 * @dev    - contains internal functions overwritten by SecuredLine, SpigotedLine, and EscrowedLine
 */
contract LineOfCredit is ILineOfCredit, MutualConsent, ReentrancyGuard {
    using SafeERC20 for IERC20;

    using CreditListLib for bytes32[];

    /// @notice - the timestamp that all creditors must be repaid by
    uint256 public deadline;

    uint256 public deadlineExtension = 0;

    uint256 constant ONE_YEAR = 365.25 days;
    // Must divide by 100 too offset bps in numerator and divide by another 100 to offset % and get actual token amount
    uint256 constant BASE_DENOMINATOR = 10000;
    // = 31557600 * 10000 = 315576000000;
    uint256 constant INTEREST_DENOMINATOR = ONE_YEAR * BASE_DENOMINATOR;

    /// @notice - the account that can drawdown and manage debt positions
    address public borrower;

    LendingPositionToken public tokenContract;
    mapping(uint256 => bytes32) public tokenToPosition;

    /// @notice - neutral 3rd party that mediates btw borrower and all lenders
    address public immutable arbiter;

    /// @notice - price feed to use for valuing credit tokens
    IOracle public immutable oracle;

    /// @notice - contract responsible for calculating interest owed on debt positions
    InterestRateCredit public immutable interestRate;

    /// @notice - current amount of active positions (aka non-null ids) in `ids` list
    uint256 public count;

    /// @notice - positions ids of all open credit lines.
    /// @dev    - may contain null elements
    bytes32[] public ids;

    // NOTE: ITS IS 0 FOR TESTING PURPOSES. Otherwise all other tests break
    uint128 public orginiationFee = 0; // in BPS 4 decimals  fee = 50 loan amount = 10000 * (5000/100)
    uint128 public servicingFee = 0; // in BPS 4 decimals  fee = 50 loan amount = 10000 * (5000/100)
    uint128 public swapFee = 0; // in BPS 4 decimals  fee = 50 loan amount = 10000 * (5000/100)

    /// @notice id -> position data
    mapping(bytes32 => Credit) public credits;

    /// @notice - current health status of line
    LineLib.STATUS public status;

    /**
     * @notice            - How to deploy a Line of Credit
     * @dev               - A Borrower and a first Lender agree on terms. Then the Borrower deploys the contract using the constructor below.
     *                      Later, both Lender and Borrower must call _mutualConsent() during addCredit() to actually enable funds to be deposited.
     * @param oracle_     - The price oracle to use for getting all token values.
     * @param arbiter_    - A neutral party with some special priviliges on behalf of Borrower and Lender.
     * @param borrower_   - The debitor for all credit lines in this contract.
     * @param ttl_        - The time to live for all credit lines for the Line of Credit facility (sets the maturity/term of the Line of Credit)
     */
    constructor(address oracle_, address arbiter_, address borrower_, uint256 ttl_) {
        oracle = IOracle(oracle_);
        arbiter = arbiter_;
        borrower = borrower_;
        deadline = block.timestamp + ttl_; //the deadline is the term/maturity/expiry date of the Line of Credit facility
        interestRate = new InterestRateCredit();
        
        emit DeployLine(oracle_, arbiter_, borrower_);
    }

    function init() external virtual {
        if (status != LineLib.STATUS.UNINITIALIZED) {
            revert AlreadyInitialized();
        }
        _init();
        _updateStatus(LineLib.STATUS.ACTIVE);
    }

    function setFees(uint128 _originationFee) external onlyBorrowerOrArbiter mutualConsent(arbiter, borrower) {
        //TODO: do we need this logic? Doesnt effectt lenders at all. If borrower and servicer agree, who cares?
        
        // if (count > 0) {
        //     revert CannotSetOriginationFee();   
        // }
        orginiationFee = _originationFee;

        // servicingFee = fee;
        // swapFee = fee;
    }

    function initTokenizedPosition(address _tokenAddress) external onlyArbiter {
        require (address(tokenContract) == address(0));
        tokenContract = LendingPositionToken(_tokenAddress);
    }

    function _init() internal virtual {
        // If no collateral or Spigot then Line of Credit is immediately active
        return;
    }

    ///////////////
    // MODIFIERS //
    ///////////////

    modifier whileActive() {
        if (status != LineLib.STATUS.ACTIVE) {
            revert NotActive();
        }
        _;
    }

    modifier whileBorrowing() {
        if (count == 0 || credits[ids[0]].principal == 0) {
            revert NotBorrowing();
        }
        _;
    }

    modifier onlyBorrower() {
        if (msg.sender != borrower) {
            revert CallerAccessDenied();
        }
        _;
    }

    modifier onlyBorrowerOrArbiter() {
        if (msg.sender != borrower && msg.sender != arbiter) {
            revert CallerAccessDenied();
        }
        _;
    }

    modifier onlyArbiter() {
        if (msg.sender != arbiter) {
            revert CallerAccessDenied();
        }
        _;
    }

    modifier onlyTokenHolder(uint256 tokenId) {
        if (tokenContract.ownerOf(tokenId) != msg.sender) {
            revert CallerAccessDenied();
        }
        _;
    }

    modifier onlyTokenHolderOrBorrower(uint256 tokenId) {
        if (tokenContract.ownerOf(tokenId) != msg.sender && msg.sender != borrower) {
            revert CallerAccessDenied();
        }
        _;
    }

    /**
     * @notice - mutualConsent() but hardcodes borrower address and uses the position id to
                 get Lender address instead of passing it in directly
     * @param tokenId - the id of the token that owns the position
    */
    modifier mutualConsentById(uint256 tokenId) {
        if (msg.sender != borrower) {
            tokenContract.openProposal(tokenId);
        }
        
        address lender = tokenContract.ownerOf(tokenId);
        if (_mutualConsent(borrower, lender)) {
            // Run whatever code is needed for the 2/2 consent
            _;
        }
    }

    /**
     * @notice - Allows borrower to extend the deadline of the line.
     * @dev - callable by `borrower`
     * @dev - requires line to not have open, active credit positions
     * @param ttlExtension The amount of time to extend the line by
     * @return true is line is extended and set to ACTIVE status.
     */
    function extend(uint256 ttlExtension) external onlyBorrower virtual returns (bool) {
        if (count == 0) {
            if (proposalCount > 0) {
                _clearProposals();
            }
            bool isExtended = _extend(ttlExtension);
            return isExtended;
        }
        revert CannotExtendLine();
    }

    function _extend(uint256 ttlExtension) internal returns (bool) {
        deadline = deadline + ttlExtension;
        if (status != LineLib.STATUS.ACTIVE) {
            _updateStatus(LineLib.STATUS.ACTIVE);
        }
        emit ExtendLine(address(this), borrower, deadline);
        return true;
    }

    /**
     * @notice - Allows borrower to update their address.
     * @dev - callable by `borrower`
     * @dev - cannot be called if new borrower is zero address
     * @param newBorrower The new address of the borrower
     */
    function updateBorrower(address newBorrower) public onlyBorrower {
        if (newBorrower == address(0)) {
            revert InvalidBorrower();
        }
        borrower = newBorrower;
        emit UpdateBorrower(borrower, newBorrower);
    }

    /**
     * @notice - Revokes all mutual consent proposals for the line.
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @dev - prevents a borrower from maliciously changing deal terms after a lender has proposed a credit position by calling amend, extend, or amendAndExtend functions
     */
    function _clearProposals() internal {
        // clear all mutual consent proposals to add credit
        for (uint256 i = 0; i < mutualConsentProposalIds.length; i++) {
            // remove mutual consent proposal for all active credits
            bytes32 proposalIdToDelete = mutualConsentProposalIds[i];
            delete mutualConsentProposals[proposalIdToDelete];

            // TODO: is this an appropriate use of this event? Or should it be a separate event?
            emit MutualConsentRevoked(proposalIdToDelete);
        }
        // reset the array of proposal ids to length 0
        delete mutualConsentProposalIds;
        proposalCount = 0;
    }

    /**
     * @notice - evaluates all covenants encoded in _healthcheck from different Line variants
     * @dev - updates `status` variable in storage if current status is diferent from existing status
     * @return - current health status of Line
     */
    function healthcheck() external returns (LineLib.STATUS) {
        // can only check if the line has been initialized
        require(uint256(status) >= uint256(LineLib.STATUS.ACTIVE));
        return _updateStatus(_healthcheck());
    }

    function _healthcheck() internal virtual returns (LineLib.STATUS) {
        // if line is in a final end state then do not run _healthcheck()
        LineLib.STATUS s = status;
        if (
            s == LineLib.STATUS.REPAID || // end state - good
            s == LineLib.STATUS.INSOLVENT || // end state - bad
            s == LineLib.STATUS.ABORTED // end state - bad
        ) {
            return s;
        }

        // Liquidate if all credit lines aren't closed by deadline
        if (block.timestamp >= deadline && count != 0) {
            emit Default(ids[0]); // can query all defaulted positions offchain once event picked up
            return LineLib.STATUS.LIQUIDATABLE;
        }

        // if nothing wrong, return to healthy ACTIVE state
        return LineLib.STATUS.ACTIVE;
    }

    /// see ILineOfCredit.declareInsolvent
    function declareInsolvent() external {
        if (arbiter != msg.sender) {
            revert CallerAccessDenied();
        }
        if (LineLib.STATUS.LIQUIDATABLE != _updateStatus(_healthcheck())) {
            revert NotLiquidatable();
        }

        if (_canDeclareInsolvent()) {
            _updateStatus(LineLib.STATUS.INSOLVENT);
        }
    }

    function _canDeclareInsolvent() internal virtual returns (bool) {
        // logic updated in Spigoted and Escrowed lines
        return true;
    }

    /// see ILineOfCredit.updateOutstandingDebt
    function updateOutstandingDebt() external override returns (uint256, uint256) {
        return _updateOutstandingDebt();
    }

    function _updateOutstandingDebt() internal returns (uint256 principal, uint256 interest) {
        // use full length not count because positions might not be packed in order
        uint256 len = ids.length;
        if (len == 0) return (0, 0);

        bytes32 id;
        for (uint256 i; i < len; ++i) {
            id = ids[i];

            // null element in array from closing a position. skip for gas savings
            if (id == bytes32(0)) {
                continue;
            }

            (Credit memory c, uint256 _p, uint256 _i) = CreditLib.getOutstandingDebt(
                credits[id],
                id,
                address(oracle),
                address(interestRate)
            );

            // update total outstanding debt
            principal += _p;
            interest += _i;
            // save changes to storage
            credits[id] = c;
        }
    }

    /// see ILineOfCredit.accrueInterest
    function accrueInterest() external override {
        uint256 len = ids.length;
        bytes32 id;
        for (uint256 i; i < len; ++i) {
            id = ids[i];
            Credit memory credit = credits[id];
            credits[id] = _accrue(credit, id);
        }
    }

    /// see ILineOfCredit.addCredit


    function _calculateOriginationFee(uint256 amount) internal returns (uint256) {
        require(deadline > block.timestamp, "deadline has passed");
        return (amount * orginiationFee * (deadline - block.timestamp)) / INTEREST_DENOMINATOR;
    }

    function _calculateServicingFee(uint256 amount) internal returns (uint256) {
       // TODO: do we need a require of any kind?
        return (amount * servicingFee)/10000;
    }
    
    function addCredit(
        uint128 drate,
        uint128 frate,
        uint256 amount,
        address token,
        address lender
    ) external payable override nonReentrant whileActive mutualConsent(lender, borrower) returns (uint256) {
        uint256 tokenId = tokenContract.mint(msg.sender, address(this));
        
        bytes32 id = _createCredit(tokenId, token, amount);

        uint256 fee = 0;
        
        if (orginiationFee > 0){
            
            fee = _calculateOriginationFee(amount);
            console.log("fee", fee);
        }
        
        
        tokenToPosition[tokenId] = id;
        _setRates(id, drate, frate);

        if (fee > 0) {
            IERC20(token).safeTransferFrom(lender, arbiter, fee); // NOTE: send fee from lender to treasury (arbiter for now)
            emit Fee(fee);
        }

        LineLib.receiveTokenOrETH(token, lender, amount - fee); // send amount - fee from lender to line

        
        return tokenId;
    }

    /// see ILineOfCredit.setRates
    function setRates(uint256 tokenId, uint128 drate, uint128 frate) external override onlyTokenHolderOrBorrower(tokenId) mutualConsentById(tokenId) {
        bytes32 id = tokenToPosition[tokenId];
        credits[id] = _accrue(credits[id], id);
        tokenContract.closeProposal(tokenId); //TODO: where should this happen?
        _setRates(id, drate, frate);
    }

    /// see ILineOfCredit.setRates
    function _setRates(bytes32 id, uint128 drate, uint128 frate) internal {
        interestRate.setRate(id, drate, frate);
        emit SetRates(id, drate, frate);
    }

    /// see ILineOfCredit.increaseCredit
    function increaseCredit(
        uint256 tokenId,
        uint256 amount
    ) external payable override nonReentrant whileActive onlyTokenHolderOrBorrower(tokenId) mutualConsentById(tokenId) {
        address lender = getTokenHolder(tokenId);
        tokenContract.closeProposal(tokenId); //TODO: where should this happen?
        bytes32 id = tokenToPosition[tokenId];
        Credit memory credit = _accrue(credits[id], id);

        credit.deposit += amount;

        credits[id] = credit;

        LineLib.receiveTokenOrETH(credit.token, lender, amount);

        emit IncreaseCredit(id, amount);

    }

    function revokeConsent(uint256 tokenId, bytes calldata _reconstrucedMsgData) override(MutualConsent) public onlyTokenHolderOrBorrower(tokenId) {
        super.revokeConsent(tokenId, _reconstrucedMsgData);
        tokenContract.closeProposal(tokenId);
    }


    ///////////////
    // REPAYMENT //
    ///////////////

    /// see ILineOfCredit.depositAndClose
    function depositAndClose() external payable override nonReentrant whileBorrowing onlyBorrowerOrArbiter {
        bytes32 id = ids[0];
        Credit memory credit = _accrue(credits[id], id);

        // Borrower deposits the outstanding balance not already repaid
        uint256 totalOwed = credit.principal + credit.interestAccrued;

        // Borrower clears the debt then closes the credit line

        credits[id] = _close(_repay(credit, id, totalOwed, borrower), id); // NOTE: the fee is in addition to the totalOwed bc we need to close the line
    }

    /// see ILineOfCredit.close
    function close(bytes32 id) external payable override nonReentrant onlyBorrowerOrArbiter {
        Credit memory credit = _accrue(credits[id], id);

        uint256 facilityFee = credit.interestAccrued;

        // clear facility fees and close position
        credits[id] = _close(_repay(credit, id, facilityFee, borrower), id);
    }

    /// see ILineOfCredit.closeLine
    function closeLine() external payable override nonReentrant onlyBorrowerOrArbiter {
        if (count == 0) {
            _updateStatus(LineLib.STATUS.REPAID);
        }

        emit CloseLine(address(this));
    }

    /// see ILineOfCredit.depositAndRepay
    function depositAndRepay(uint256 amount) external payable override nonReentrant whileBorrowing {
        bytes32 id = ids[0];
        Credit memory credit = _accrue(credits[id], id);

        if (amount > credit.principal + credit.interestAccrued) {
            revert RepayAmountExceedsDebt(credit.principal + credit.interestAccrued);
        }

        credits[id] = _repay(credit, id, amount, msg.sender);
    }

    function getExtension() external view returns (uint256) {
        return deadline + deadlineExtension;
    }


    ////////////////////
    // FUND TRANSFERS //
    ////////////////////

    /// see ILineOfCredit.borrow
    function borrow(bytes32 id, uint256 amount, address to) external override nonReentrant whileActive onlyBorrower {
        Credit memory credit = _accrue(credits[id], id);
        if (!credit.isOpen) {
            revert PositionIsClosed();
        }
        if (amount > credit.deposit - credit.principal) {
            revert NoLiquidity();
        }
        credit.principal += amount;

        // save new debt before healthcheck and token transfer
        credits[id] = credit;

        // ensure that borrowing doesnt cause Line to be LIQUIDATABLE
        if (_updateStatus(_healthcheck()) != LineLib.STATUS.ACTIVE) {
            revert BorrowFailed();
        }

        // If the "to" address is not provided (i.e., it's the zero address), set it to the borrower.
        if (to == address(0)) {
            to = borrower;
        }

        LineLib.sendOutTokenOrETH(credit.token, to, amount);

        emit Borrow(id, amount, to);

        _sortIntoQ(id);
    }

    /// see ILineOfCredit.withdraw
    function withdraw(uint256 tokenId, uint256 amount) external override onlyTokenHolder(tokenId) nonReentrant {
        // accrues interest and transfer funds to Lender addres
        bytes32 id = tokenToPosition[tokenId];
        
        credits[id] = CreditLib.withdraw(_accrue(credits[id], id), id, tokenId, msg.sender, amount);
    }

    // for abort Scenario

    function recoverTokens(address[] memory tokens) external override nonReentrant {
        require (msg.sender == arbiter);
        require (status == LineLib.STATUS.ABORTED);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amount = IERC20(tokens[i]).balanceOf(address(this));
            IERC20(tokens[i]).safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice  - Steps the Queue be replacing the first element with the next valid credit line's ID
     * @dev     - Only works if the first element in the queue is null
     */
    function stepQ() external {
        ids.stepQ();
    }

    //////////////////////
    //  Internal  funcs //
    //////////////////////

    /**
     * @notice - updates `status` variable in storage if current status is diferent from existing status.
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @dev - does not save new status if it is the same as current status
     * @return status - the current status of the line after updating
     */
    function _updateStatus(LineLib.STATUS status_) internal returns (LineLib.STATUS) {
        if (status == status_) return status_;
        emit UpdateStatus(uint256(status_));
        return (status = status_);
    }

    /**
     * @notice - Generates position id and stores lender's position
     * @dev - positions have unique composite-index on [owner, lenderAddress, tokenAddress]
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @param tokenId - id of 721 that will own and manage position
     * @param token - ERC20 token that is being lent and borrower
     * @param amount - amount of tokens lender will initially deposit
     */
    function _createCredit(uint256 tokenId, address token, uint256 amount) internal returns (bytes32 id) {
        id = CreditLib.computeId(address(this), tokenId, token);
        address lender = getTokenHolder(tokenId);
        // MUST not double add the credit line. once lender is set it cant be deleted even if position is closed.
        if (lender != address(0) && credits[id].isOpen) {
            revert PositionExists();
        }

        credits[id] = CreditLib.create(id, amount, tokenId, token, address(oracle));

        ids.push(id); // add lender to end of repayment queue

        // if positions was 1st in Q, cycle to next valid position
        if (ids[0] == bytes32(0)) ids.stepQ();

        // TODO: remove this
        unchecked {
            ++count;
        }

        return id;
    }

    /**
    * @dev - Reduces `principal` and/or `interestAccrued` on a credit line.
                Expects checks for conditions of repaying and param sanitizing before calling
                e.g. early repayment of principal, tokens have actually been paid by borrower, etc.
    * @dev - privileged internal function. MUST check params and logic flow before calling
    * @dev syntatic sugar
    * @param id - position id with all data pertaining to line
    * @param amount - amount of Credit Token being repaid on credit line
    * @return credit - position struct in memory with updated values
    */
    function _repay(Credit memory credit, bytes32 id, uint256 amount, address payer) internal returns (Credit memory) {
        return CreditLib.repay(credit, id, amount, payer);
    }

    /**
     * @notice - accrues token demoninated interest on a lender's position.
     * @dev MUST call any time a position balance or interest rate changes
     * @dev syntatic sugar
     * @param credit - the lender position that is accruing interest
     * @param id - the position id for credit position
     */
    function _accrue(Credit memory credit, bytes32 id) internal returns (Credit memory) {
        return CreditLib.accrue(credit, id, address(interestRate));
    }

    /**
     * @notice - checks that a credit line is fully repaid and removes it
     * @dev deletes credit storage. Store any data u might need later in call before _close()
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @dev - when the line being closed is at the 0-index in the ids array, the null index is replaced using `.stepQ`
     * @return credit - position struct in memory with updated values
     */
    function _close(Credit memory credit, bytes32 id) internal virtual returns (Credit memory) {
        // update position data in state
        if (!credit.isOpen) {
            revert PositionIsClosed();
        }
        if (credit.principal != 0) {
            revert CloseFailedWithPrincipal();
        }

        credit.isOpen = false;

        // nullify the element for `id`
        ids.removePosition(id);

        // if positions was 1st in Q, cycle to next valid position
        if (ids[0] == bytes32(0)) ids.stepQ();

        unchecked {
            --count;
        }

        // If all credit lines are closed the the overall Line of Credit facility is declared 'repaid'.
        if (count == 0) {
            _updateStatus(LineLib.STATUS.REPAID);
        }

        emit CloseCreditPosition(id);

        return credit;
    }

    /**
     * @notice - Insert `p` into the next availble FIFO position in the repayment queue
               - once earliest slot is found, swap places with `p` and position in slot.
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @param p - position id that we are trying to find appropriate place for
     */
    function _sortIntoQ(bytes32 p) internal {
        uint256 lastSpot = ids.length - 1;
        uint256 nextQSpot = lastSpot;
        bytes32 id;
        for (uint256 i; i <= lastSpot; ++i) {
            id = ids[i];
            if (p != id) {
                if (
                    id == bytes32(0) || // deleted element. In the middle of the q because it was closed.
                    nextQSpot != lastSpot || // position already found. skip to find `p` asap
                    credits[id].principal != 0 //`id` should be placed before `p`
                ) continue;
                nextQSpot = i; // index of first undrawn line found
            } else {
                // nothing to update
                if (nextQSpot == lastSpot) return; // nothing to update
                // get id value being swapped with `p`
                bytes32 oldPositionId = ids[nextQSpot];
                // swap positions
                ids[i] = oldPositionId; // id put into old `p` position
                ids[nextQSpot] = p; // p put at target index

                emit SortedIntoQ(p, nextQSpot, i, oldPositionId);
            }
        }
    }



    /* GETTERS */

    /// see ILineOfCredit.interestAccrued
    function interestAccrued(bytes32 id) external view returns (uint256) {
        return CreditLib.interestAccrued(credits[id], id, address(interestRate));
    }

    function getPositionFromTokenId(uint256 tokenId) external view returns (Credit memory, bytes32) {
        bytes32 id = tokenToPosition[tokenId];
        return (credits[id], id);
    }

    function getRates(bytes32 id) external view returns (uint128, uint128) {
        return interestRate.getRates(id);
    }

    /// see ILineOfCredit.counts
    function counts() external view returns (uint256, uint256) {
        return (count, ids.length);
    }

    function getTokenHolder(uint256 tokenId) public view returns (address) {
        return tokenContract.ownerOf(tokenId);
    }

    /// see ILineOfCredit.available
    function available(bytes32 id) external view returns (uint256, uint256) {
        return (credits[id].deposit - credits[id].principal, credits[id].interestRepaid);
    }

    function nextInQ() external view returns (bytes32, uint256, address, uint256, uint256, uint256, uint128, uint128) {
        bytes32 next = ids[0];
        Credit memory credit = credits[next];
        // Add to docs that this view revertts if no queue
        (uint128 dRate, uint128 fRate) = CreditLib.getNextRateInQ(credit.principal, next, address(interestRate));
        return (
            next,
            credit.tokenId,
            credit.token,
            credit.principal,
            credit.deposit,
            CreditLib.interestAccrued(credit, next, address(interestRate)),
            dRate,
            fRate
        );
    }
}
