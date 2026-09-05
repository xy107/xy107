import { createConfig, http } from 'wagmi'
import { injected } from 'wagmi/connectors/injected'
import { walletConnect } from 'wagmi/connectors/walletConnect'
import { anvil, mainnet } from 'wagmi/chains'
import { createPublicClient, isAddress, zeroAddress, type Chain } from 'viem'
export const chain: Chain = import.meta.env.VITE_CHAIN_ID === '31337' ? anvil : mainnet
export const defaultRpc = import.meta.env.VITE_RPC_URL || chain.rpcUrls.default.http[0]
const rpcStorageKey = 'xy107.rpcUrl'
export function isValidRpcUrl(value: string) {
  try {
    const url = new URL(value)
    return url.protocol === 'https:' || url.protocol === 'http:'
  } catch {
    return false
  }
}
function storedRpc() {
  if (typeof window === 'undefined') return undefined
  const value = window.localStorage.getItem(rpcStorageKey)?.trim()
  return value && isValidRpcUrl(value) ? value : undefined
}
export const rpc = storedRpc() || defaultRpc
export const customRpc = storedRpc()
export { rpcStorageKey }
const address = (value: string | undefined) =>
  value && isAddress(value) && value !== zeroAddress ? value : undefined
export const nftAddress = address(import.meta.env.VITE_XY107_ADDRESS)
export const xyAddress = address(import.meta.env.VITE_XY_ADDRESS)
export const configured = Boolean(nftAddress && xyAddress)
export const deploymentBlock = BigInt(import.meta.env.VITE_DEPLOYMENT_BLOCK || '0')
const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID
export const config = createConfig({
  chains: [chain],
  connectors: [injected(), ...(projectId ? [walletConnect({ projectId, showQrModal: true })] : [])],
  transports: { [chain.id]: http(rpc) },
})
export const client = createPublicClient({ chain, transport: http(rpc, { batch: true }) })
export const links = {
  x: 'https://x.com/xy107_2026',
  github: 'https://github.com/xy107/xy107',
  readme: 'https://github.com/xy107/xy107/blob/main/README.md',
  whitepaper: 'https://github.com/xy107/xy107/blob/main/whitepaper.md',
  events: 'https://github.com/xy107/xy107/blob/main/event.md',
}
