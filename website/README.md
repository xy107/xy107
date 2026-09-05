# XY107 website

React, TypeScript, Vite, Tailwind CSS, Wagmi, Viem, TanStack Query, Radix Dialog, and Sonner. All website code lives here. Pages deployment is `.github/workflows/pages.yml` at the repository root. The Solidity contracts in `../src` remain the source of truth.

## Local development

Requires Node.js 22.12+ (tested on 24), npm, and Foundry on PATH.

```sh
cd website
npm ci
anvil --host 127.0.0.1 --port 8545
# In another terminal, from website:
npm run local:deploy
npm run dev
```

Open http://127.0.0.1:5173/xy107/. Add Anvil (chain 31337, RPC http://127.0.0.1:8545) to a development wallet. Use an Anvil-funded account only for local testing. The deployment script uses unlocked local RPC accounts, refuses other chains, builds the existing contracts, deploys and links both, and writes ignored `.env.local`. It seeds token 2 with explicitly labeled local test artwork; token 1 is pending; tokens 3–108 are available. Local artwork reuses `../assets/logos/08.png` and is not collection artwork.

```sh
npx playwright install chromium
npm run test:e2e
npm run build
npm run test:pages
```

Run `local:deploy` again before repeating transaction tests: tests intentionally mint and contribute. Restart Vite after redeployment. Browser tests inject an EIP-1193 test provider backed by real Anvil RPC; no testing connector or private key ships in the application. Tests verify collection states, filters, wallet connection, mint ownership, rejection recovery, contribution balances, mobile overflow and direct routes. Screenshots and traces go to ignored `test-results/`.

## Ethereum mainnet

Configure `.env.local` with the deployed and linked XY and XY107 addresses, deployment block, an appropriate RPC endpoint, and a WalletConnect project ID from Reown if QR/mobile wallets are needed. Public browser RPC credentials and WalletConnect project IDs are public configuration, never secrets. Configure provider origin restrictions for `https://xy107.github.io`.

```sh
npm run build
npm run preview
```

The production build targets Ethereum mainnet. Empty addresses deliberately disable live reads and transactions. The RPC needs `eth_call`, gas estimation, receipts and `eth_getLogs`; personal contribution history scans 10,000-block ranges from `VITE_DEPLOYMENT_BLOCK`. Set the correct deployment block to avoid unnecessary historical scans. A history failure is shown separately from sale availability. The public endpoint is a starting configuration; choose a provider with sufficient limits for production traffic.

## GitHub Pages

Target: https://xy107.github.io/xy107/ (repository https://github.com/xy107/xy107).

`vite.config.ts` sets `/xy107/` as the base. The build emits `contribute/index.html` for direct navigation to `/xy107/contribute/`, plus `404.html` for the client router. Navigation uses clean paths and browser back/forward, with an accessible not-found view. Static assets use the repository prefix.

`.github/workflows/pages.yml` deploys when a GitHub Release is published whose tag is `vMAJOR.MINOR.PATCH.website` (example: `v1.0.1.website`). Other releases are ignored. In the repository, set Settings → Pages → Source to **GitHub Actions**. Then open Settings → Environments → github-pages → Deployment branches and tags, and either allow all tags or add a tag rule for `v*.*.*.website`. The default rule only allows `main`, so website release tags are rejected until this is changed. The production build loads mainnet configuration from `.env`.

## Contract behavior represented

- All 108 records are rendered. Only IDs 2–108 can be minted, at the on-chain price (currently 1 ETH); each wallet can mint once, even if it later transfers the NFT.
- `ownerOf` and `metadata.imageHash` determine available, pending, and committed states. Only the specific nonexistent-token revert means unminted; RPC failures never imply availability.
- Songjiang is reserved, and its eventual burn is represented separately. Public mint stats exclude it.
- Committed artwork resolves from the contract's image base URI and token ID. HTTPS and IPFS are allowed; HTTP is limited to local mode. Metadata is rendered as text. The committed hash is displayed, but the UI does not independently verify remote image bytes against it. Missing or failed artwork has an explicit state.
- The public sale uses 8 XY decimals, a 428 ETH cap, and 10,000 XY per ETH. No countdown or soft cap exists in the contract. The 360-day allocation deadline does **not** end the public sale.
- Conversion calculations use bigint throughout. Final allocation and excess-ETH refund behavior match `contribute()`; gas is estimated in the review dialog, and the contract is simulated again immediately before signing.
- Personal contributions sum accepted ETH from `Contributed` events, rather than treating transferable XY balances as purchase history.
- Wallet switching, insufficient funds, rejection, RPC errors, pending receipts and reverts are surfaced. A successful receipt invalidates cached reads. Polling keeps external changes visible.

## Design

See `DESIGN.md` for the visual direction and component rules. Fonts are self-hosted, dialogs use Radix focus management, controls have keyboard focus states, mobile layouts support 320px+, and reduced motion is respected.

## References

- [Wagmi documentation](https://wagmi.sh/react/getting-started)
- [Viem simulation](https://viem.sh/docs/contract/simulateContract)
- [Vite GitHub Pages deployment](https://vite.dev/guide/static-deploy#github-pages)

The optional Coinbase SDK pulled in by WalletConnect pins an older Axios. A targeted override keeps it on patched Axios 1.x; retain the override until upstream updates the pin.

## Verification performed

- Strict TypeScript and production mainnet builds passed, including a build with the WalletConnect code path enabled.
- Three Anvil browser tests passed: real mint/contribution transactions, rejection recovery, collection states and filters, mobile layouts, accessibility scans on both pages, and RPC failure handling.
- One production-build browser test passed: mainnet configuration, wallet dialog, repository-prefixed direct contribution route and reload, and the not-found route.
- `npm audit` reported zero vulnerabilities after the targeted Axios override.
- Desktop and mobile screenshots were reviewed. The normal entry bundle is approximately 200 KB gzip; Vite reports an uncompressed chunk-size advisory for the Web3 client bundle.

No live mainnet transaction or third-party QR wallet session was performed. GitHub Pages publication happens from a `vMAJOR.MINOR.PATCH.website` release after Pages is set to GitHub Actions.
