# Agent Mint by 2l8

**One-line description:** A free ERC-721 badge that any wallet holding a Binance
Agent ID (`name.ai`) can mint — one per wallet, gas only, no price, no fee.
Each mint is one Agent ID address interacting with the contract, which is
exactly what the Binance Agent ID Hackathon's growth ranking measures.

- Hackathon: Binance Agent ID Hackathon, 60,000 USDC total rewards.
  Submission period 2026-11-18 08:00 UTC → 2026-12-09 08:00 UTC.
  Official announcement:
  https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf
- Builder: Agent ID `2l8.ai`, deployer wallet
  `0x5466Ea60e14E8d63847b60Ead5f0E62c77bcb8Bf` (BSC).
- Status: **BUILT, NOT DEPLOYED.** Nothing here has spent anything, touched
  any wallet, or been submitted anywhere.

## How Agent ID is used

The contract reads the SPACE ID Agent ID registry on BNB Chain,
`0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (ERC-721, non-transferable).
`mint()` requires `agentId.balanceOf(msg.sender) > 0` — the exact check the
official announcement documents. No Agent ID, no mint. One badge per wallet
(`hasMinted` mapping). There is no allowlist, no off-chain server, and no
signature scheme: the chain itself is the gate.

The frontend does the same check off-chain (an `eth_call` to `balanceOf`)
before enabling the mint button, so ineligible wallets see why they can't
mint instead of wasting gas on a revert.

## What is in this repo

```
contracts/AgentMint.sol   — the badge contract (Solidity ^0.8.20, OpenZeppelin 5.4.0)
frontend/index.html       — static mint page, no build step, no backend
compile.js                — compile with solc-js (solc 0.8.26, optimizer runs 200, evmVersion Shanghai)
test.js                   — local Ganache test: deploy + gate + 1-per-wallet + metadata (TEST ONLY)
estimate.js               — BSC mainnet deployment-cost estimate via eth_estimateGas (read-only)
build/AgentMint.json      — compiled ABI + bytecode (regenerate with node compile.js)
```

### Contract — `contracts/AgentMint.sol`

- ERC-721 (`Agent Mint by 2l8`, symbol `2L8MINT`), max supply 10,000.
- `mint()` — free (not payable, value must be 0). Reverts `NotAgentIdHolder`,
  `AlreadyMinted`, `MaxSupplyReached`. Emits `Minted(minter, tokenId)`.
- `tokenURI(tokenId)` — fully **on-chain** metadata: a `data:application/json;base64`
  document with an embedded base64 SVG badge (navy/teal, "2l8", "AGENT MINT",
  "AGENT ID VERIFIED", token number). No IPFS, no external hosting.
- `totalMinted()`, `hasMinted(address)` — public views for the frontend.
- **Owner permissions (full disclosure, as the hackathon rules require):**
  the owner can ONLY call `withdraw()`, which recovers BNB accidentally sent
  to the contract. The owner CANNOT mint, change the Agent ID gate (immutable),
  change metadata (no setter, fully on-chain), pause, freeze, burn, or set any
  price. No proxy, no upgrade path, no allowlist admin. In normal operation
  the contract balance is always zero (mint is free).

### Frontend — `frontend/index.html`

Static page, zero dependencies (no CDN libraries, no build). It uses
`window.ethereum` directly:
1. Connect wallet → 2. check BSC mainnet (offers a chain switch) → 3. read
   Agent ID status (`balanceOf`) and mint status (`hasMinted`) → 4. mint
   button sends one `mint()` transaction (`value: 0x0`) which the user sees
   and confirms in their own wallet.
- Before deployment, `CONTRACT_ADDRESS` is the zero address and the page
  shows "not deployed yet" while still letting anyone check their Agent ID.
  After deployment, replace the placeholder with the real contract address.

## Build & test (done)

```
npm install
node compile.js   # -> build/AgentMint.json (solc 0.8.26, OZ 5.4.0)
node test.js      # local Ganache: all checks pass (see below)
node estimate.js  # BSC mainnet cost estimate (read-only RPC)
```

Local test results (Ganache, Shanghai hardfork): deploy 1,744,540 gas;
mint #1 (first minter, cold storage) **119,947 gas**; mint #2 (second
minter) **102,847 gas**; non-holder mint reverts; second mint by the same
wallet reverts on-chain; `tokenURI(1)` decodes to valid JSON + SVG
(`Agent Mint by 2l8 #1`); `tokenURI(999)` reverts; non-owner `withdraw()`
reverts. Bytecode: 8,252 bytes creation / 7,447 bytes deployed (under the
24,576-byte limit). `evmVersion: shanghai` — no Cancun-only opcodes, so the
bytecode runs on every BSC node and older local EVMs.

## Gas / deployment cost (measured 2026-11-18 ~12:10 UTC, BSC mainnet RPC)

Both `bsc-dataseed.binance.org` and `bsc.publicnode.com` agreed exactly:

| Item | Value |
| --- | --- |
| `eth_estimateGas` (deployment) | **1,759,553 gas** |
| `eth_gasPrice` at measurement | **0.05 gwei** (50,000,000 wei) |
| **Deployment cost at 0.05 gwei** | **0.000087978 BNB** |
| Deployer balance (verified on-chain) | 0.000091353 BNB |
| Balance left after deploy at 0.05 gwei | 0.000003375 BNB |
| Deployment cost at 1 gwei | 0.001759553 BNB |
| Deployment cost at 3 gwei | 0.005278659 BNB |
| One mint, first minter (119,947 gas) | ~0.0000060 BNB at 0.05 gwei |
| One mint, later minter (102,847 gas) | ~0.0000051 BNB at 0.05 gwei |

**Deployment note (deployed 2026-11-18):** the Binance Agentic Wallet CLI
(`baw`) cannot deploy contracts — its `contract-call` requires a `to`
address — so the contract was deployed from the project's raw local-signer
wallet `0xBfc132F770022C6c0eF1D405A8E9341E91b51adf`, funded with 0.0004 BNB
from the Agent ID wallet `0x5466Ea60e14E8d63847b60Ead5f0E62c77bcb8Bf` (funding
tx `0x92e3ac1568f1a6cf37e71c9d4fa93549ad623c8953e60fdec46a354fcdfc66b6`;
leftover 0.000311723 BNB sent back afterwards). Deployment cost 1,744,540
gas @ 0.05 gwei (~0.0000872 BNB).

Also verified on-chain via BSC RPC: `balanceOf(deployer)` on the Agent ID
contract returns **1** — the Agent ID wallet holds `2l8.ai`, so it can mint
its own badge (once it has gas for the mint, ~0.000006 BNB).

## Deployed (live since 2026-11-18 ~19:35 WIB)

- **Contract:** `0x0A46aC17ee0b484971E7163D64fFEc69Ca7f0A86` (BNB Smart Chain)
- **Deploy tx:** `0x3b7e039ca4560e1d5cacd188e0aaa305c8b6f235e9a06585e081cd0dfcfbcebf`, block 134310901, 1,744,540 gas @ 0.05 gwei
- **Constructor argument:** `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (the Agent ID registry)
- **Compiler:** solc 0.8.26, optimizer enabled (200 runs), `evmVersion: shanghai`
- **Source verified on Sourcify** (exact match, creation + runtime): https://sourcify.dev/server/v2/contract/56/0x0A46aC17ee0b484971E7163D64fFEc69Ca7f0A86 — BscScan's own verify form was blocked by a Cloudflare bot check; BscScan mirrors Sourcify verification.
- **Website:** https://0xpaasepp.github.io/agent-mint-by-2l8/
- **Mint gate verified on-chain:** a wallet without an Agent ID reverts on `mint()`; the `2l8.ai` holder's call passes.

Remaining: submit the project (see below) with project name, website URL,
contract address, Agent ID usage description, and reward receiving address.
During the submission period, guide Agent ID holders to mint. The
Innovation Award needs a live product + **at least 30 Agent ID addresses**
interacting with the contract; the Pioneer Award ranks on interacting
Agent ID addresses, transaction volume, and transaction count.

## Project submission — form link (GAP, read carefully)

The official announcement instructs projects to "submit your project name,
website, contract address(es), Agent ID usage description, and other required
materials during the Submission Period" and says "no registration needed" —
**but it publishes no dedicated project-submission form URL.** The only
official survey link in the announcement is the campaign survey for the
X-promotion award:
`https://app.binance.com/uni-qr/user-survey/ff6832f8d2984af289068c9450a3c98c`
(a fetch of that URL timed out on 2026-11-18, so it is **not verified**
whether it also accepts project submissions — do not assume it does).
**Before submitting, confirm the project-submission channel from an official
source** (Binance Wallet on X, BNB Chain channels, or a follow-up Binance
announcement) and record it here. Submission deadline: **2026-12-09 08:00 UTC**.

## Red-line compliance notes

Checked against the hackathon's safety red lines in the official announcement:

- **No web QR-code login.** The frontend uses the visitor's own installed
  wallet (`window.ethereum`). No QR codes, no pairing codes, no sessions
  stored anywhere.
- **No bypassing user confirmation.** The mint is a normal transaction the
  user sees and confirms in their own wallet. Nothing is auto-signed.
- **No unauthorized transfers.** `mint()` moves no BNB and no tokens except
  minting the badge to the caller. No approvals are requested anywhere.
- **Contracts open-source, owner permissions disclosed.** Source is in this
  repo and will be verified on BscScan; the only owner function
  (`withdraw()` for accidental BNB) is documented in the contract comments
  and above.
- **No brand impersonation.** The project is named "Agent Mint by 2l8" —
  it does not use "Binance" or "BNB" in its name, token name, or symbol.
- **No credential collection.** Nothing in the project asks for, stores, or
  transmits seed phrases, private keys, API secrets, or pairing codes.
- **No promised returns.** The badge is a free collectible. All copy says
  "no value, reward, or return is promised" — no "passive income" or
  money-making language anywhere.
- **No name-lookup tool.** Agent ID is used only as a mint gate
  (`balanceOf > 0`), never to look up other people's wallets by name.

## Name check

"Agent Mint by 2l8": no existing project with this exact name was found
(web search 2026-11-18). The Agent ID free-mint space is crowded with
similarly named projects (AgentForge, MOLT AGENT, Agentic Gangster, hackou,
AGC, and an "AI Mint" reported by Odaily) — the "by 2l8" suffix and the
`2l8.ai` deployer identity are what distinguish this entry. Keep the suffix.
