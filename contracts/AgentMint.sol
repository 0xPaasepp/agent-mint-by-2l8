// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Minimal interface of the SPACE ID Agent ID registry (BNB Chain).
/// @dev Agent ID is a non-transferable ERC-721. An address holds an Agent ID
///      if and only if balanceOf(address) > 0.
interface IAgentID {
    function balanceOf(address account) external view returns (uint256);
}

/// @title Agent Mint by 2l8
/// @notice A FREE ERC-721 badge, mintable only by wallets that hold a Binance
///         Agent ID (name.ai). One badge per wallet, minter pays gas only.
///         Built for the Binance Agent ID Hackathon (2026-11-18 to 2026-12-09).
/// @dev Metadata is fully on-chain: tokenURI returns a data-URI JSON document
///      with an embedded base64 SVG badge. No external hosting, no IPFS, no
///      off-chain dependency of any kind.
///
///      OWNER PERMISSIONS — full disclosure (hackathon red-line requirement):
///      The owner can ONLY call withdraw(), which sends BNB that was
///      accidentally sent to this contract to the owner. The owner CANNOT:
///        - mint tokens (minting is open to any Agent ID holder),
///        - change the Agent ID gate or the registry address (immutable),
///        - change any token's metadata (fully on-chain, no setter),
///        - pause minting, freeze, or burn anyone's token,
///        - set or change any price (there is no price; mint is free),
///        - collect any fee from mints.
///      There is no proxy, no upgrade path, no pausing, no allowlist admin.
contract AgentMint is ERC721, Ownable {
    using Strings for uint256;

    /// @notice The SPACE ID Agent ID registry on BNB Chain.
    IAgentID public immutable agentId;

    /// @notice Hard cap on badges. 10,000 is a safety bound; the cap is
    ///         deliberately far above any realistic hackathon mint count.
    uint256 public constant MAX_SUPPLY = 10000;

    /// @notice Next token id to mint (starts at 1).
    uint256 private _nextTokenId;

    /// @notice True once an address has minted its one badge.
    mapping(address => bool) public hasMinted;

    event Minted(address indexed minter, uint256 indexed tokenId);

    error NotAgentIdHolder();
    error AlreadyMinted();
    error MaxSupplyReached();

    /// @param agentIdAddress The SPACE ID Agent ID registry:
    ///        0x60b9262456de011f7d15a54cdd8c48baaa8b022f on BNB Chain.
    constructor(address agentIdAddress) ERC721("Agent Mint by 2l8", "2L8MINT") Ownable(msg.sender) {
        require(agentIdAddress != address(0), "zero agent id address");
        agentId = IAgentID(agentIdAddress);
    }

    /// @notice Mint the caller's one free badge. Value must be 0; there is no
    ///         price and this function is not payable.
    /// @dev Reverts if the caller holds no Agent ID, already minted, or the
    ///      cap is reached. Each successful mint is one Agent ID address
    ///      interacting with this contract (the hackathon's growth metric).
    function mint() external {
        if (agentId.balanceOf(msg.sender) == 0) revert NotAgentIdHolder();
        if (hasMinted[msg.sender]) revert AlreadyMinted();
        uint256 tokenId = ++_nextTokenId;
        if (tokenId > MAX_SUPPLY) revert MaxSupplyReached();
        hasMinted[msg.sender] = true;
        _safeMint(msg.sender, tokenId);
        emit Minted(msg.sender, tokenId);
    }

    /// @notice Number of badges minted so far.
    function totalMinted() external view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice Fully on-chain metadata: data-URI JSON with an embedded SVG.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory svg = _svg(tokenId);
        string memory json = string(
            abi.encodePacked(
                '{"name":"Agent Mint by 2l8 #',
                tokenId.toString(),
                '","description":"Free badge minted by a Binance Agent ID holder. One per wallet, gas only. A collectible proof of Agent ID - no value, reward, or return is promised.","image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '","attributes":[{"trait_type":"Badge","value":"Agent Mint"},{"trait_type":"Gate","value":"Agent ID holder"}]}'
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Recover BNB that was accidentally sent to this contract.
    /// @dev The ONLY owner-only function. The contract has no price and no
    ///      fee, so in normal operation its balance is always zero.
    function withdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "nothing to withdraw");
        (bool ok, ) = owner().call{value: bal}("");
        require(ok, "withdraw failed");
    }

    /// @dev Accept accidental BNB transfers so they can be recovered via
    ///      withdraw() instead of being locked forever.
    receive() external payable {}

    function _svg(uint256 tokenId) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">',
                    '<rect width="512" height="512" fill="#0F2A44"/>',
                    '<circle cx="256" cy="256" r="200" fill="none" stroke="#0E7C7B" stroke-width="10"/>',
                    '<circle cx="256" cy="256" r="176" fill="none" stroke="#FFD23A" stroke-width="3"/>',
                    '<text x="256" y="215" font-family="Arial,sans-serif" font-size="96" font-weight="bold" fill="#FFFFFF" text-anchor="middle">2l8</text>',
                    '<text x="256" y="280" font-family="Arial,sans-serif" font-size="34" font-weight="bold" fill="#7DFF8A" text-anchor="middle">AGENT MINT</text>',
                    '<text x="256" y="325" font-family="Arial,sans-serif" font-size="22" fill="#CFE8FF" text-anchor="middle">AGENT ID VERIFIED</text>',
                    '<text x="256" y="395" font-family="Arial,sans-serif" font-size="26" fill="#FFD23A" text-anchor="middle">#',
                    tokenId.toString(),
                    "</text>",
                    "</svg>"
                )
            );
    }
}
