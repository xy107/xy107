import { useRef, useState } from 'react'
import { useAccount, useSwitchChain, useWalletClient } from 'wagmi'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { formatEther, type Hash } from 'viem'
import { toast } from 'sonner'
import { chain, client, nftAddress, xyAddress } from './config'
import { nftAbi, xyAbi } from './contracts'
import { message } from './data'
import { Modal, WalletBalance } from './ui'
const transactionAbi = [...nftAbi, ...xyAbi] as const
export type Intent =
  { kind: 'mint'; id: number; value: bigint } | { kind: 'contribute'; value: bigint }
export function Transaction({ intent, close }: { intent: Intent; close: () => void }) {
  const { address, chainId } = useAccount()
  const { data: wallet } = useWalletClient()
  const { switchChainAsync } = useSwitchChain()
  const cache = useQueryClient()
  const [stage, setStage] = useState<
    'review' | 'wallet' | 'pending' | 'unconfirmed' | 'failed' | 'success'
  >('review')
  const [error, setError] = useState('')
  const [hash, setHash] = useState<Hash>()
  const replacementChanged = useRef(false)
  const wrongChain = chainId !== chain.id
  const params =
    intent.kind === 'mint'
      ? {
          address: nftAddress!,
          abi: transactionAbi,
          functionName: 'mint' as const,
          args: [BigInt(intent.id)] as const,
          value: intent.value,
        }
      : {
          address: xyAddress!,
          abi: transactionAbi,
          functionName: 'contribute' as const,
          value: intent.value,
        }
  const estimate = useQuery({
    queryKey: [
      'estimate',
      address,
      intent.kind,
      intent.kind === 'mint' ? intent.id : '',
      intent.value.toString(),
    ],
    enabled: !!address && !wrongChain && stage === 'review',
    retry: false,
    queryFn: async () => {
      const [gas, gasPrice, balance] = await Promise.all([
        client.estimateContractGas({ ...params, account: address! }),
        client.getGasPrice(),
        client.getBalance({ address: address! }),
      ])
      return { fee: gas * gasPrice, sufficient: balance >= intent.value + gas * gasPrice }
    },
  })
  async function confirm(tx: Hash) {
    setError('')
    setStage('pending')
    try {
      const receipt = await client.waitForTransactionReceipt({
        hash: tx,
        timeout: 120_000,
        onReplaced: (replacement) => {
          setHash(replacement.transaction.hash)
          if (replacement.reason !== 'repriced') replacementChanged.current = true
        },
      })
      if (replacementChanged.current || receipt.status !== 'success') {
        setStage('failed')
        setError(
          replacementChanged.current
            ? 'The transaction was cancelled or replaced with a different action. This purchase was not confirmed.'
            : 'Transaction reverted. No purchase was completed.',
        )
        await cache.invalidateQueries({ predicate: (query) => query.queryKey[0] !== 'estimate' })
        return
      }
      setStage('success')
      toast.success(intent.kind === 'mint' ? 'Hero minted successfully' : 'Contribution confirmed')
      await cache.invalidateQueries({ predicate: (query) => query.queryKey[0] !== 'estimate' })
    } catch (e) {
      setError(
        `Confirmation is unavailable. Your transaction may still complete. Check its status before making another transaction. ${message(e)}`,
      )
      setStage('unconfirmed')
    }
  }
  async function submit() {
    if (!wallet || !address || wrongChain) return
    setError('')
    try {
      setStage('wallet')
      const { request } = await client.simulateContract({ ...params, account: address })
      const tx = await wallet.writeContract(request)
      setHash(tx)
      await confirm(tx)
    } catch (e) {
      setError(message(e))
      setStage('review')
      toast.error(message(e))
    }
  }
  const busy = stage === 'wallet' || stage === 'pending'
  return (
    <Modal
      open
      onOpenChange={(open) => {
        if (!open && !busy) close()
      }}
      title={
        stage === 'success'
          ? 'Recorded on-chain'
          : intent.kind === 'mint'
            ? `Mint Hero ${String(intent.id).padStart(3, '0')}`
            : 'Review contribution'
      }
      description={
        stage === 'success'
          ? 'Your transaction is confirmed. Live statistics will refresh automatically.'
          : `Review your transaction on ${chain.name} before approving it.`
      }
    >
      <WalletBalance />
      <dl className="review">
        <div>
          <dt>{intent.kind === 'mint' ? 'Mint price' : 'Contribution'}</dt>
          <dd>{formatEther(intent.value)} ETH</dd>
        </div>
        <div>
          <dt>Estimated network fee</dt>
          <dd>
            {estimate.data
              ? `${Number(formatEther(estimate.data.fee)).toFixed(7)} ETH`
              : 'Unavailable'}
          </dd>
        </div>
      </dl>
      {intent.kind === 'mint' && stage !== 'success' && (
        <p>One Hero per wallet. Artwork appears after the operator commits metadata.</p>
      )}
      {hash && (
        <p className="address">
          {chain.blockExplorers ? (
            <a
              href={`${chain.blockExplorers.default.url}/tx/${hash}`}
              target="_blank"
              rel="noreferrer"
            >
              View transaction
            </a>
          ) : (
            `Transaction: ${hash}`
          )}
        </p>
      )}
      <div role="status">
        {stage === 'wallet' && <p>Approve the transaction in your wallet…</p>}
        {stage === 'pending' && <p>Waiting for on-chain confirmation…</p>}
      </div>
      {(error || estimate.error) && (
        <p className="error" role="alert">
          {error || message(estimate.error)}
        </p>
      )}
      {estimate.data && !estimate.data.sufficient && (
        <p className="error">Insufficient ETH for the amount and estimated gas.</p>
      )}
      {stage === 'unconfirmed' && hash ? (
        <button className="button full" onClick={() => void confirm(hash)}>
          Check confirmation
        </button>
      ) : stage === 'failed' ? (
        <button className="button full" onClick={close}>
          Close review
        </button>
      ) : stage === 'success' ? (
        <button className="button full" onClick={close}>
          Done
        </button>
      ) : wrongChain ? (
        <button
          className="button full"
          onClick={() => switchChainAsync({ chainId: chain.id }).catch((e) => setError(message(e)))}
        >
          Switch to {chain.name}
        </button>
      ) : (
        <button
          className="button full"
          disabled={busy || !wallet || !estimate.data?.sufficient || estimate.isError}
          onClick={submit}
        >
          {busy
            ? 'Transaction in progress…'
            : estimate.isPending
              ? 'Estimating gas…'
              : intent.kind === 'mint'
                ? 'Confirm mint'
                : 'Confirm contribution'}
        </button>
      )}
    </Modal>
  )
}
