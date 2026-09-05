import { useQuery } from '@tanstack/react-query'
import { BaseError, ContractFunctionRevertedError, zeroHash, type Address } from 'viem'
import { client, configured, nftAddress, xyAddress, deploymentBlock, chain } from './config'
import { nftAbi, xyAbi } from './contracts'
export type Hero = {
  id: number
  state: 'available' | 'pending' | 'committed' | 'burned'
  name: string
  description: string
  hash: string
  image: string
  owner?: Address
}
export const collectionKey = ['collection', chain.id, nftAddress]
export function safeImage(uri: string) {
  const value = uri.startsWith('ipfs://') ? `https://ipfs.io/ipfs/${uri.slice(7)}` : uri
  try {
    const url = new URL(value)
    return url.protocol === 'https:' || (chain.id === 31337 && url.protocol === 'http:')
      ? url.href
      : ''
  } catch {
    return ''
  }
}
export function useCollection() {
  return useQuery({
    queryKey: collectionKey,
    enabled: configured,
    staleTime: 10_000,
    refetchInterval: 15_000,
    queryFn: async () => {
      const blockNumber = await client.getBlockNumber()
      const read = { address: nftAddress!, abi: nftAbi, blockNumber }
      const [count, price, base] = await Promise.all([
        client.readContract({ ...read, functionName: 'heroMintCount' }),
        client.readContract({ ...read, functionName: 'MINT_PRICE_ETH' }),
        client.readContract({ ...read, functionName: 'imageBaseURI' }),
      ])
      const heroes: Hero[] = []
      for (let start = 1; start <= 108; start += 12) {
        const group = await Promise.all(
          Array.from({ length: Math.min(12, 109 - start) }, async (_, offset): Promise<Hero> => {
            const id = start + offset
            let owner: Address | undefined
            try {
              owner = await client.readContract({
                ...read,
                functionName: 'ownerOf',
                args: [BigInt(id)],
              })
            } catch (error) {
              const revert =
                error instanceof BaseError
                  ? error.walk((e) => e instanceof ContractFunctionRevertedError)
                  : undefined
              if (
                !(revert instanceof ContractFunctionRevertedError) ||
                revert.data?.errorName !== 'ERC721NonexistentToken'
              )
                throw error
            }
            const [name, description, hash] = await client.readContract({
              ...read,
              functionName: 'metadata',
              args: [BigInt(id)],
            })
            return {
              id,
              owner,
              name: name || (id === 1 ? 'Songjiang' : `Hero ${String(id).padStart(3, '0')}`),
              description,
              hash,
              image: hash !== zeroHash && base ? safeImage(`${base}/${id}`) : '',
              state: !owner
                ? id === 1
                  ? 'burned'
                  : 'available'
                : hash === zeroHash
                  ? 'pending'
                  : 'committed',
            }
          }),
        )
        heroes.push(...group)
      }
      return { count: Number(count), price, heroes }
    },
  })
}
export function useSale() {
  return useQuery({
    queryKey: ['sale', chain.id, xyAddress],
    enabled: configured,
    refetchInterval: 12_000,
    queryFn: async () => {
      const blockNumber = await client.getBlockNumber()
      const read = { address: xyAddress!, abi: xyAbi, blockNumber }
      const [raised, cap, rate, remaining] = await Promise.all([
        client.readContract({ ...read, functionName: 'totalRaisedEth' }),
        client.readContract({ ...read, functionName: 'ROUND_CAP_ETH' }),
        client.readContract({ ...read, functionName: 'XY_BASE_UNITS_PER_ETH' }),
        client.readContract({ ...read, functionName: 'trancheRemaining', args: [1] }),
      ])
      return { raised, cap, rate, remaining }
    },
  })
}
export function usePersonal(address?: Address) {
  return useQuery({
    queryKey: ['personal', chain.id, xyAddress, address],
    enabled: configured && !!address,
    refetchInterval: 15_000,
    queryFn: async () => {
      const latest = await client.getBlockNumber()
      let contributed = 0n
      // Bounded ranges support public RPC providers that restrict eth_getLogs spans.
      for (let fromBlock = deploymentBlock; fromBlock <= latest; fromBlock += 10_000n) {
        const toBlock = fromBlock + 9_999n < latest ? fromBlock + 9_999n : latest
        const logs = await client.getContractEvents({
          address: xyAddress!,
          abi: xyAbi,
          eventName: 'Contributed',
          args: { sender: address! },
          fromBlock,
          toBlock,
        })
        contributed += logs.reduce((sum, log) => sum + (log.args.acceptedEth ?? 0n), 0n)
      }
      return contributed
    },
  })
}
export function message(error: unknown) {
  return error instanceof BaseError
    ? error.shortMessage
    : error instanceof Error
      ? error.message
      : 'Unable to complete the request. Please try again.'
}
