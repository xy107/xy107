# Mainnet scripts

These Forge scripts deploy and operate the XY contracts. The commands below target Ethereum
mainnet, but the scripts themselves can run on any EVM-compatible chain. Each script uses the signer
supplied by Forge; no script reads a private key from an environment variable.

## Signer setup

Import an encrypted Foundry account once:

```sh
cast wallet import xy107-deployer --interactive
```

Every real mainnet command must provide an imported account and `--broadcast`. Forge's deterministic
default sender exists only for tests and simulations; Forge does not create a usable mainnet account
when `--account` is omitted. The operator account must equal `XY.operator()` at the time an operator
script runs. Initially the creator is the operator; after `TransferAdmin` runs, the current admin is
the operator.

Copy each environment template once, then replace its placeholders with that network's values:

```sh
cp .env.example .env.mainnet
```

Load the environment for the intended network at the start of each terminal session:

```sh
set -a; source .env.mainnet; set +a
```

Loading `.env.mainnet` exports `RPC_URL`,
`XY_ADDRESS`, `XY107_ADDRESS`, and `X_ACCOUNT_ID` for all subsequent script commands in that
terminal. Script-specific values such as `RECIPIENT` and `TOKEN_ID` can still be supplied
immediately before an individual command.

The commands below are real mainnet broadcasts. Before running one, simulate the exact command by
temporarily removing `--broadcast`; keep `--account` so the simulation uses and validates the actual
sender. Inspect the calls, sender, values, and gas before broadcasting. Forge will prompt for the
encrypted account's password. A hardware wallet can be used instead by replacing `--account
xy107-operator` with `--ledger --sender 0x...`.

## Deploy

`Deploy.s.sol` deploys `XY`, deploys `XY107`, and permanently links `XY107` to `XY`.

```sh
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --account xy107-deployer \
  --broadcast
```

`X_ACCOUNT_ID` is the exact official X account ID. The script hashes it with Keccak-256 before
storing it in the contract. For the current ID, `xy107_2026`, the stored hash is
`0x1a67b4e4631a5f129f00064653087f19b5ea4f3d5565885c01fe23e12f66520f`.

## Operator actions

### PaySlot

`operator/PaySlot.s.sol` pays 4 ETH from the public-sale payout pool to one numbered slot. Valid
slot indices are 2 through 108, and each slot can only be paid once.

```sh
SLOT_INDEX=2 RECIPIENT=0x... \
forge script script/operator/PaySlot.s.sol:PaySlot \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

### ReleaseYu

`operator/ReleaseYu.s.sol` releases the entire Yu allocation to one recipient. It can only run once
and before the allocation deadline.

```sh
RECIPIENT=0x... \
forge script script/operator/ReleaseYu.s.sol:ReleaseYu \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

### DistributeSpreaders

`operator/DistributeSpreaders.s.sol` gives 40,000 XY to each comma-separated recipient. The total
number of paid spreaders cannot exceed 100, and distribution must happen before the allocation
deadline.

```sh
RECIPIENTS=0xRecipient1,0xRecipient2 \
forge script script/operator/DistributeSpreaders.s.sol:DistributeSpreaders \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

### PayArtist

`operator/PayArtist.s.sol` releases the entire artist allocation to one recipient. It can only run
once.

```sh
RECIPIENT=0x... \
forge script script/operator/PayArtist.s.sol:PayArtist \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

### TransferAdmin

`operator/TransferAdmin.s.sol` changes the admin. The new admin immediately becomes the operator
and must sign subsequent operator actions. Supplying the creator address returns operator control
to the creator; the contract does not permit setting the admin to the zero address.

```sh
NEW_ADMIN=0x... \
forge script script/operator/TransferAdmin.s.sol:TransferAdmin \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

### SetXAccount

`operator/SetXAccount.s.sol` replaces the stored hash of the official X account identifier.

```sh
forge script script/operator/SetXAccount.s.sol:SetXAccount \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

### CommitMetadata

`operator/CommitMetadata.s.sol` permanently commits a minted NFT's name, description, and image
hash. `IMAGE_HASH` must be the Keccak-256 hash of the exact, unmodified bytes served by that token's
image URL. Metadata can only be committed once per token.

```sh
TOKEN_ID=2 \
TOKEN_NAME='...' \
TOKEN_DESCRIPTION='...' \
IMAGE_HASH=0x... \
forge script script/operator/CommitMetadata.s.sol:CommitMetadata \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

To calculate an image hash locally:

```sh
cast keccak < path/to/image
```

### SetImageBaseURI

`operator/SetImageBaseURI.s.sol` sets the base URL used to derive NFT image URLs. Do not include a
trailing slash: token IDs are appended as `<base URI>/<token ID>`.

```sh
IMAGE_BASE_URI=https://images.example/xy107 \
forge script script/operator/SetImageBaseURI.s.sol:SetImageBaseURI \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

### SetContractURI

`operator/SetContractURI.s.sol` sets the collection-level metadata URI returned by `contractURI()`.

```sh
CONTRACT_URI=ipfs://... \
forge script script/operator/SetContractURI.s.sol:SetContractURI \
  --rpc-url "$RPC_URL" --account xy107-operator --broadcast
```

Deployment can additionally use `--verify` with an `ETHERSCAN_API_KEY`. Broadcast artifacts are
written under `broadcast/` and are intentionally ignored by Git.

## Permissionless lifecycle actions

These calls do not require the operator role, but a funded account is still required to sign the
mainnet transaction and pay gas. The examples use the already imported `xy107-deployer` account.

### BurnYu

`permissionless/BurnYu.s.sol` burns the Yu allocation after the allocation deadline if it was not
released. The call reverts before the deadline or after the allocation has already been released or
burned.

```sh
forge script script/permissionless/BurnYu.s.sol:BurnYu \
  --rpc-url "$RPC_URL" --account xy107-deployer --broadcast
```

### BurnSpreaderRemainder

`permissionless/BurnSpreaderRemainder.s.sol` burns all undistributed spreader tokens after the
allocation deadline.

```sh
forge script script/permissionless/BurnSpreaderRemainder.s.sol:BurnSpreaderRemainder \
  --rpc-url "$RPC_URL" --account xy107-deployer --broadcast
```

### BurnSeedSupporterRemainder

`permissionless/BurnSeedSupporterRemainder.s.sol` burns all undistributed seed-supporter tokens
after the allocation deadline.

```sh
forge script \
  script/permissionless/BurnSeedSupporterRemainder.s.sol:BurnSeedSupporterRemainder \
  --rpc-url "$RPC_URL" --account xy107-deployer --broadcast
```

### BurnSongjiang

`permissionless/BurnSongjiang.s.sol` burns the locked Songjiang NFT and its associated XY tranche.
Any address, including the creator, may call it after all 107 hero NFTs have been minted. It can
only succeed once.

```sh
forge script script/permissionless/BurnSongjiang.s.sol:BurnSongjiang \
  --rpc-url "$RPC_URL" --account xy107-deployer --broadcast
```

## Testing a fork

`test/ScriptFork.t.sol` runs the deployment and every operator script against an in-process fork of
an EVM-compatible chain. The fork is local and no transaction is broadcast. It uses Foundry's
deterministic test sender, not an imported keystore or real account.

```sh
FORK_RPC_URL=https://your-rpc.example \
forge test --match-path test/ScriptFork.t.sol
```

Forge manages and isolates the fork, so a separate `anvil` process is not required.
