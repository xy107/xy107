import { readFile, writeFile } from 'node:fs/promises'
import { execFileSync } from 'node:child_process'
import {
  createPublicClient,
  createWalletClient,
  http,
  keccak256,
  stringToHex,
  parseEther,
} from 'viem'
import { anvil } from 'viem/chains'
const rpc = 'http://127.0.0.1:8545'
const client = createPublicClient({ chain: anvil, transport: http(rpc) })
if ((await client.getChainId()) !== 31337)
  throw new Error('Local deployment requires Anvil chain 31337')
const wallet = createWalletClient({ chain: anvil, transport: http(rpc) })
const [account, fixtureAccount] = await wallet.getAddresses()
if (!account) throw new Error('Anvil must expose unlocked local accounts')
execFileSync('forge', ['build', '--quiet'], { cwd: '..', stdio: 'inherit' })
const artifact = async (name) =>
  JSON.parse(await readFile(`../out/${name}.sol/${name}.json`, 'utf8'))
const xy = await artifact('XY'),
  nft = await artifact('XY107')
async function deploy(contract, args) {
  const hash = await wallet.deployContract({
    account,
    abi: contract.abi,
    bytecode: contract.bytecode.object,
    args,
  })
  const receipt = await client.waitForTransactionReceipt({ hash })
  if (!receipt.contractAddress) throw new Error('Deployment failed')
  return receipt.contractAddress
}
const start = await client.getBlockNumber()
const xyAddress = await deploy(xy, ['XY', 'XY', keccak256(stringToHex('xy107_2026'))])
const nftAddress = await deploy(nft, ['XY107', 'XY107', xyAddress])
async function write(address, abi, functionName, args = [], sender = account, value = 0n) {
  const hash = await wallet.writeContract({
    account: sender,
    address,
    abi,
    functionName,
    args,
    value,
  })
  const receipt = await client.waitForTransactionReceipt({ hash })
  if (receipt.status !== 'success') throw new Error(`${functionName} failed`)
}
await write(xyAddress, xy.abi, 'setXy107', [nftAddress])
// A single committed fixture plus the reserved pending token exercises every grid state.
await write(nftAddress, nft.abi, 'mint', [2n], fixtureAccount, parseEther('1'))
const artwork = await readFile('public/local-art/2')
await write(nftAddress, nft.abi, 'setImageBaseURI', ['http://127.0.0.1:5173/xy107/local-art'])
await write(nftAddress, nft.abi, 'commitMetadata', [
  2n,
  'Local Hero 002',
  'Local integration-test artwork. This is not production collection art.',
  keccak256(artwork),
])
await writeFile(
  '.env.local',
  `VITE_CHAIN_ID=31337\nVITE_RPC_URL=${rpc}\nVITE_XY_ADDRESS=${xyAddress}\nVITE_XY107_ADDRESS=${nftAddress}\nVITE_DEPLOYMENT_BLOCK=${start}\n`,
)
console.log(
  `Local contracts deployed and linked. XY: ${xyAddress}; XY107: ${nftAddress}. Restart Vite to load .env.local.`,
)
