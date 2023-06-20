pragma solidity 0.8.16;

import {ISocket} from "../../interfaces/ISocket.sol";
import {ISpigot} from "../../interfaces/ISpigot.sol";

contract CreditPlug {
    ISocket public socket;
    address public owner;
    uint256 public destGasLimit = 100000;

    // CHAIN B
    uint32 public remoteChainSlug;
    address public spigotedLineOnChainA;
    ISpigot public spigot;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Chain A
    modifier onlySpigottedLine() {
        require(msg.sender == spigotedLineOnChainA, "Not spigotedLine");
        _;
    }

    // Chain B
    modifier onlySocket() {
        require(msg.sender == address(socket), "Not Socket");
        _;
    }

    event AddSpigotInitiated(address indexed revenueContract);
    event SpigotNotAdded();

    constructor(
        address socket_,
        address spigotedLineOnChainA_,
        address spigot_
    ) {
        owner = msg.sender;
        socket = ISocket(socket_);
        spigot = ISpigot(spigot_);
        spigotedLineOnChainA = spigotedLineOnChainA_;
    }

    /************************************************************************
        Config Functions 
    ************************************************************************/

    /**
     * see LineOfCredit._init and Securedline.init
     * @notice requires this Line is owner of the Escrowed collateral else Line will not init
     */
    function connectToSocket(
        uint32 siblingChainSlug_,
        address siblingPlug_,
        address inboundSwitchboard_,
        address outboundSwitchboard_
    ) external onlyOwner {
        remoteChainSlug = siblingChainSlug_;
        ISocket(socket).connect(
            siblingChainSlug_,
            siblingPlug_,
            inboundSwitchboard_,
            outboundSwitchboard_
        );
    }

    function setDestChainLimit(uint256 _limit) public onlyOwner {
        destGasLimit = _limit;
    }

    function setSpigotedLine(address _sl) public onlyOwner {
        spigotedLineOnChainA = _sl;
    }

    function setSpigot(address _s) public onlyOwner {
        spigot = ISpigot(_s);
    }

    /************************************************************************
        SocketDL Functions 
    ************************************************************************/

    // SK_WIP check where msg.value comes from
    function sendSocketMessage(bytes memory payload_) internal returns (bool) {
        try
            socket.outbound{value: msg.value}(
                remoteChainSlug,
                destGasLimit, // SK_WIP gasLimit assumed so far
                bytes32(0),
                payload_
            )
        {
            return true;
        } catch {
            return false;
        }
    }

    // TODO: Change this function to unpack payload and make a low level call (?) to th
    function inbound(
        uint32 siblingChainSlug_,
        bytes calldata payload_
    ) public onlySocket {
        (
            address _sender,
            address _revenueContract,
            ISpigot.Setting memory _setting
        ) = abi.decode(payload_, (address, address, ISpigot.Setting));

        require(
            _sender == spigotedLineOnChainA,
            "Sender of message not spigotedLine"
        );

        addSpigotChainB(_revenueContract, _setting);
    }

    /************************************************************************
        Chain A Functions -- SpigotedLine.sol
    ************************************************************************/

    // Setter Functions

    function addSpigot(
        address revenueContract,
        ISpigot.Setting calldata setting
    ) public payable onlySpigottedLine returns (bool) {
        bytes memory payload = abi.encode(msg.sender, revenueContract, setting);

        bool success = sendSocketMessage(payload);
        if (success) emit AddSpigotInitiated(revenueContract);
        return success;
    }

    function updateOwner(
        address newOwner
    ) external payable onlySpigottedLine returns (bool) {
        
    }

    function updateWhitelist(
        bytes4 func, 
        bool allowed
    ) public payable onlySpigottedLine returns (bool) {
        bytes memory payload = abi.encode(msg.sender, func, allowed);

        bool success = sendSocketMessage(payload);
        return success;
    }

    function updateOwnerSplit(
        address revenueContract,
        uint8 defaultSplit
    ) external payable onlySpigottedLine returns (bool) {
        bytes memory payload = abi.encode(msg.sender, revenueContract, defaultSplit);
        bool success = sendSocketMessage(payload);
        return success;
    }

    //Claim

    function claimOwnerTokens(
        address  token
    ) external payable onlySpigottedLine returns (bool) {

    }

    // Getter

    function getOperatorTokens(
        address token 
    ) external payable onlySpigottedLine returns (bool) {

    }

    function getOwnerTokens(
        address token 
    ) external payable onlySpigottedLine returns (bool) {

    }   

    function isWhiteListed(
        bytes4 func 
    ) external payable onlySpigottedLine returns (bool) {

    }

    function getSetting(
        address revenueToken 
    ) external payable onlySpigottedLine returns (bool) {

    }


    /************************************************************************
        Chain B Functions -- Spigoted.sol
    ************************************************************************/

    function addSpigotChainB(
        address _revenueContract,
        ISpigot.Setting memory _setting
    ) internal {
        try spigot.addSpigot(_revenueContract, _setting) {} catch {
            emit SpigotNotAdded();
        }
    }


    function updateOwnerChainB(

    ) internal {

    }


    function updateWhitelistChainB(

    ) internal {

    }


    function updateOwnerSplitChainB(

    ) internal {

    }

    //Claim

    function claimOwnerTokensChainB(
        address  token
    ) external payable onlySpigottedLine returns (bool) {

    }

    // Getter

    function getOperatorTokensChainB(
        address token 
    ) external payable onlySpigottedLine returns (bool) {

    }

    function getOwnerTokensChainB(
        address token 
    ) external payable onlySpigottedLine returns (bool) {

    }   

    function isWhiteListedChainB(
        bytes4 func 
    ) external payable onlySpigottedLine returns (bool) {

    }

    function getSettingChainB(
        address revenueToken 
    ) external payable onlySpigottedLine returns (bool) {

    }

}
