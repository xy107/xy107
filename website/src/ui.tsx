import * as Dialog from '@radix-ui/react-dialog'
import { X, Wallet, ArrowSquareOut } from '@phosphor-icons/react'
import { useConnect, useAccount, useDisconnect, useBalance } from 'wagmi'
import { formatEther, type Address } from 'viem'
import { useRef, useState, type ReactNode } from 'react'
import { chain, customRpc, defaultRpc, isValidRpcUrl, rpcStorageKey } from './config'
import { message } from './data'
export function WalletBalance() {
  const { address } = useAccount()
  const balance = useBalance({
    address,
    chainId: chain.id,
    query: { enabled: !!address, refetchInterval: 12_000 },
  })
  return (
    <div className="wallet-balance" role="status">
      <span>
        Your ETH balance <span className="balance-network">({chain.name})</span>
      </span>
      <span>
        {!address
          ? 'Connect wallet to view'
          : balance.isError
            ? 'Unavailable'
            : balance.data
              ? `${Number(formatEther(balance.data.value)).toFixed(6)} ETH`
              : 'Loading…'}
      </span>
    </div>
  )
}
export function RpcSettingsModal({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const [value, setValue] = useState(customRpc || defaultRpc)
  const [error, setError] = useState('')
  function save(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const next = value.trim()
    if (!isValidRpcUrl(next)) {
      setError('Enter a valid HTTP or HTTPS RPC URL.')
      return
    }
    window.localStorage.setItem(rpcStorageKey, next)
    location.reload()
  }
  function reset() {
    window.localStorage.removeItem(rpcStorageKey)
    location.reload()
  }
  return (
    <Modal
      open={open}
      onOpenChange={onOpenChange}
      title="Network settings"
      description="Use your own Ethereum RPC endpoint when the public endpoint is slow or rate limited."
    >
      <form className="settings-form" onSubmit={save}>
        <label htmlFor="rpc-url">RPC URL</label>
        <input
          id="rpc-url"
          type="url"
          value={value}
          onChange={(event) => {
            setValue(event.target.value)
            setError('')
          }}
          placeholder="https://your-rpc.example"
          spellCheck={false}
          autoComplete="off"
          aria-invalid={Boolean(error)}
          aria-describedby={error ? 'rpc-error' : 'rpc-help'}
        />
        <p id="rpc-help" className="fine">
          This setting is saved only in this browser. Your RPC provider may require an API key.
        </p>
        {error && (
          <p id="rpc-error" className="error" role="alert">
            {error}
          </p>
        )}
        <div className="settings-actions">
          <button className="button secondary" type="button" onClick={reset} disabled={!customRpc}>
            Use default
          </button>
          <button className="button" type="submit">
            Save and reload
          </button>
        </div>
      </form>
    </Modal>
  )
}
export function ContractAddress({ name, address }: { name: string; address?: Address }) {
  if (!address) return null
  const explorer = chain.blockExplorers?.default
  return (
    <p className="contract-address">
      <span>{name} contract</span>
      {explorer ? (
        <a
          href={`${explorer.url}/address/${address}#code`}
          target="_blank"
          rel="noreferrer"
          aria-label={`${name} contract source code on ${explorer.name}: ${address}`}
        >
          {address} <ArrowSquareOut size={14} aria-hidden="true" />
        </a>
      ) : (
        <span>{address}</span>
      )}
    </p>
  )
}
export function Modal({
  open,
  onOpenChange,
  title,
  description,
  children,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description: string
  children: ReactNode
}) {
  const returnFocus = useRef<HTMLElement | null>(null)
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="modal-overlay" />
        <Dialog.Content
          className="modal"
          onOpenAutoFocus={() => {
            returnFocus.current = document.activeElement as HTMLElement
          }}
          onCloseAutoFocus={(event) => {
            if (returnFocus.current?.isConnected) {
              event.preventDefault()
              returnFocus.current.focus()
            }
          }}
        >
          <Dialog.Title>{title}</Dialog.Title>
          <Dialog.Description>{description}</Dialog.Description>
          <Dialog.Close className="icon-button modal-close" aria-label="Close dialog">
            <X size={22} />
          </Dialog.Close>
          {children}
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
export function WalletModal({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
}) {
  const { connectors, connectAsync, isPending } = useConnect()
  const { address } = useAccount()
  const { disconnect } = useDisconnect()
  const [error, setError] = useState('')
  return (
    <Modal
      open={open}
      onOpenChange={onOpenChange}
      title={address ? 'Your wallet' : 'Connect your wallet'}
      description={`Participate on ${chain.name}. You approve each transaction in your wallet.`}
    >
      {address ? (
        <>
          <p className="address">{address}</p>
          <button
            className="button full"
            onClick={() => {
              disconnect()
              onOpenChange(false)
            }}
          >
            Disconnect
          </button>
        </>
      ) : (
        <div className="wallet-list">
          {connectors.map((connector) => (
            <button
              className="wallet-option"
              disabled={isPending}
              key={connector.uid}
              onClick={async () => {
                setError('')
                // Release Radix focus trapping before the provider opens its own QR modal.
                if (connector.id === 'walletConnect') onOpenChange(false)
                try {
                  await connectAsync({ connector })
                  onOpenChange(false)
                } catch (e) {
                  setError(message(e))
                  onOpenChange(true)
                }
              }}
            >
              <Wallet size={22} />
              <span>{connector.name === 'Injected' ? 'Browser wallet' : connector.name}</span>
              <ArrowSquareOut size={18} />
            </button>
          ))}
          <p>Choose a browser wallet or scan with WalletConnect when available.</p>
        </div>
      )}
      {isPending && <p role="status">Continue in your wallet…</p>}
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
    </Modal>
  )
}
export function Metrics({ items }: { items: { label: string; value: string; note?: string }[] }) {
  return (
    <dl className="metrics">
      {items.map((item) => (
        <div key={item.label}>
          <dt>{item.label}</dt>
          <dd>
            {item.value}
            {item.note && <span>{item.note}</span>}
          </dd>
        </div>
      ))}
    </dl>
  )
}
export function ReadStatus({
  error,
  loading,
  retry,
}: {
  error: boolean
  loading: boolean
  retry: () => void
}) {
  return error ? (
    <div className="notice error" role="alert">
      Live data is unavailable. Transactions are paused until reads recover.{' '}
      <button onClick={retry}>Retry</button>
    </div>
  ) : loading ? (
    <div className="notice" role="status">
      Reading the latest on-chain state…
    </div>
  ) : null
}
