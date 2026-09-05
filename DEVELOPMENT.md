# Contract development

The contracts use Foundry and OpenZeppelin Contracts.

Clone with the pinned dependencies:

```sh
git clone --recurse-submodules <repository-url>
```

For an existing clone, initialize them with `git submodule update --init --recursive`.

```sh
forge build
forge test
forge fmt --check
```

Deploy with:

```sh
cp .env.example .env.mainnet
set -a; source .env.mainnet; set +a
forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast
```

`.env.mainnet` is ignored by Git. `X_ACCOUNT_ID` is the project's exact official X account ID. The script hashes it with Keccak-256, deploys `XY`, deploys `XY107`, and then permanently sets the ERC721 pointer on `XY`. The creator is the initial operator and can appoint an admin with `transferAdmin()`.
