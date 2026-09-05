import { useState } from 'react'
import { useAccount } from 'wagmi'
import { formatEther, formatUnits, parseEther } from 'viem'
import { ArrowUpRight, ShieldCheck } from '@phosphor-icons/react'
import { useSale, usePersonal } from './data'
import { configured, links, xyAddress } from './config'
import { ContractAddress, Metrics, ReadStatus, WalletBalance } from './ui'
import type { Intent } from './Transaction'
export function Contribute({
  connect,
  transact,
}: {
  connect: () => void
  transact: (intent: Intent) => void
}) {
  const { address } = useAccount()
  const sale = useSale()
  const personal = usePersonal(address)
  const [amount, setAmount] = useState('0.1')
  let value = 0n
  const valid =
    /^(?:\d+\.?\d*|\.\d{1,18})$/.test(amount) && (amount.split('.')[1]?.length ?? 0) <= 18
  if (valid) {
    try {
      value = parseEther(amount)
    } catch {
      /* Invalid input remains zero. */
    }
  }
  const data = sale.data
  const remaining = data ? data.cap - data.raised : 0n
  const accepted = value > remaining ? remaining : value
  const tokens = data
    ? accepted === remaining
      ? data.remaining
      : (accepted * data.rate) / 10n ** 18n
    : 0n
  const soldOut = data?.remaining === 0n
  const invalid =
    !valid || value <= 0n || (!!data && !soldOut && tokens < 10n ** 8n && accepted !== remaining)
  return (
    <>
      <section className="sale-heading">
        <h1>
          Attention becomes
          <br />
          participation.
        </h1>
        <p>Contribute ETH. Receive XY directly in your wallet.</p>
      </section>
      <Metrics
        items={[
          {
            label: 'Total raised',
            value: data ? `${formatEther(data.raised)} ETH` : '–',
            note: 'Public sale contributions',
          },
          {
            label: 'Your contribution',
            value: !address
              ? 'Connect wallet'
              : personal.data !== undefined
                ? `${formatEther(personal.data)} ETH`
                : personal.isError
                  ? 'Unavailable'
                  : 'Loading…',
            note: 'Accepted ETH, from sale events',
          },
          {
            label: 'Hard cap',
            value: data ? `${formatEther(data.cap)} ETH` : '–',
            note: 'No soft cap',
          },
          {
            label: 'Conversion rate',
            value: data ? `${Number(formatUnits(data.rate, 8)).toLocaleString()} XY` : '–',
            note: 'Per 1 ETH',
          },
        ]}
      />
      <ReadStatus
        error={sale.isError}
        loading={configured && sale.isPending}
        retry={() => void sale.refetch()}
      />
      <div className="sale-layout">
        <section className="sale-context">
          <h2>
            A fixed supply.
            <br />
            An open invitation.
          </h2>
          <p>
            4,280,000 XY are allocated to the public sale. Contributions fund a pool for the 107
            participants described in the whitepaper.
          </p>
          <dl className="sale-facts">
            <div>
              <dt>Sale period</dt>
              <dd>Open until sold out</dd>
            </div>
            <div>
              <dt>Minimum purchase</dt>
              <dd>1 XY (0.0001 ETH)*</dd>
            </div>
            <div>
              <dt>Token delivery</dt>
              <dd>In the same transaction</dd>
            </div>
            <div>
              <dt>Token decimals</dt>
              <dd>8</dd>
            </div>
          </dl>
          <p className="fine">
            *The final remaining allocation may be smaller. Excess ETH above the hard cap is
            refunded by the contract.
          </p>
          <a href={links.whitepaper} target="_blank" rel="noreferrer">
            Understand the allocation <ArrowUpRight size={17} />
          </a>
          <ContractAddress name="XY" address={xyAddress} />
        </section>
        <form
          className="contribution-panel"
          onSubmit={(event) => {
            event.preventDefault()
            if (!address) connect()
            else if (!invalid && data && !soldOut && !sale.isError)
              transact({ kind: 'contribute', value })
          }}
        >
          <h2>Contribute to XY</h2>
          <p>
            {soldOut
              ? 'The public allocation is sold out.'
              : 'Choose the amount you want to contribute.'}
          </p>
          <WalletBalance />
          <label htmlFor="eth-amount">Contribution amount</label>
          <div className="amount-input">
            <input
              id="eth-amount"
              inputMode="decimal"
              autoComplete="off"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              aria-describedby="amount-help"
              aria-invalid={invalid}
            />
            <span>ETH</span>
          </div>
          <div className="presets">
            {['0.01', '0.1', '1'].map((preset) => (
              <button
                key={preset}
                type="button"
                aria-pressed={amount === preset}
                onClick={() => setAmount(preset)}
              >
                {preset} ETH
              </button>
            ))}
          </div>
          <p id="amount-help" className={invalid ? 'error fine' : 'fine'}>
            {invalid
              ? 'Enter a valid amount of at least 0.0001 ETH (up to 18 decimals).'
              : 'Keep some ETH in your wallet for the network fee.'}
          </p>
          <dl className="conversion">
            <dt>You receive</dt>
            <dd>
              {data && !invalid
                ? Number(formatUnits(tokens, 8)).toLocaleString(undefined, {
                    maximumFractionDigits: 8,
                  })
                : '–'}{' '}
              <span>XY</span>
            </dd>
          </dl>
          {data && value > remaining && (
            <p className="notice">
              {formatEther(value - remaining)} ETH will be refunded. The sale accepts{' '}
              {formatEther(accepted)} ETH.
            </p>
          )}
          <div className="fee-note">
            <ShieldCheck size={20} />
            <span>Gas is estimated in the transaction review.</span>
          </div>
          <button
            className="button full"
            disabled={!!address && (invalid || !data || sale.isError || soldOut)}
          >
            {!address ? 'Connect wallet' : soldOut ? 'Sale complete' : 'Review contribution'}
          </button>
          <p className="fine centered">You approve the final transaction in your wallet.</p>
        </form>
      </div>
      {personal.isError && (
        <p className="notice error">
          Your contribution history could not be read.{' '}
          <button onClick={() => void personal.refetch()}>Retry history</button>
        </p>
      )}
    </>
  )
}
