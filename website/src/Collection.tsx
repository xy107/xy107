import { useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { formatEther } from 'viem'
import { MagnifyingGlass, LockKey, ImageSquare, ArrowDown, Check } from '@phosphor-icons/react'
import { useCollection, type Hero } from './data'
import { configured, nftAddress, chain, links } from './config'
import { nftAbi } from './contracts'
import { ContractAddress, Metrics, Modal, ReadStatus } from './ui'
import type { Intent } from './Transaction'
const stateLabels = {
  available: 'Available',
  pending: 'Pending metadata',
  committed: 'Committed',
  burned: 'Burned',
}
export function Collection({
  connect,
  transact,
}: {
  connect: () => void
  transact: (intent: Intent) => void
}) {
  const query = useCollection()
  const { address } = useAccount()
  const minted = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'hasMintedHero',
    args: address ? [address] : undefined,
    chainId: chain.id,
    query: { enabled: configured && !!address, refetchInterval: 12_000 },
  })
  const [filter, setFilter] = useState('All')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<Hero>()
  const data = query.data
  const heroes =
    data?.heroes ??
    Array.from({ length: 108 }, (_, index): Hero => ({
      id: index + 1,
      name: index === 0 ? 'Songjiang' : `Hero ${String(index + 1).padStart(3, '0')}`,
      description: '',
      hash: '',
      image: '',
      state: 'available',
    }))
  const shown = heroes.filter(
    (hero) =>
      (filter === 'All' ||
        (!!data &&
          (filter === 'Available'
            ? hero.state === 'available'
            : hero.state === 'pending' || hero.state === 'committed'))) &&
      `${hero.id} ${hero.name}`.toLowerCase().includes(search.toLowerCase().replace(/^#/, '')),
  )
  const committed = data?.heroes.filter((hero) => hero.state === 'committed').length
  function choose(hero: Hero) {
    if (!address) {
      connect()
      return
    }
    if (
      data &&
      !query.isError &&
      hero.state === 'available' &&
      hero.id !== 1 &&
      minted.data === false &&
      !minted.isError
    )
      transact({ kind: 'mint', id: hero.id, value: data.price })
    else setSelected(hero)
  }
  return (
    <>
      <section className="hero">
        <div>
          <h1>
            The heroes
            <br />
            remain.
          </h1>
          <p>
            A permanent record of 107 voices.
            <br />
            One collection, for a change worth remembering.
          </p>
          <a className="button" href="#collection">
            Explore the collection <ArrowDown size={18} />
          </a>
        </div>
        <div className="hero-art" aria-label="107 heroes, together with Songjiang, make 108">
          <span className="chinese" lang="zh">
            义
          </span>
          <div className="hero-equation">107 + 1 = 108</div>
          <span className="art-caption">Record, and encourage change.</span>
        </div>
      </section>
      <Metrics
        items={[
          {
            label: 'Heroes minted',
            value: data ? `${data.count} / 107` : '–',
            note: '107 public mints',
          },
          {
            label: 'Available to mint',
            value: data ? String(107 - data.count) : '–',
            note: 'One Hero per wallet',
          },
          {
            label: 'Mint price',
            value: data ? `${formatEther(data.price)} ETH` : '–',
            note: 'Plus network fee',
          },
          {
            label: 'Metadata committed',
            value: data ? `${committed} / 108` : '–',
            note: 'Permanent on-chain records',
          },
        ]}
      />
      <section id="collection" className="collection-section">
        <div className="section-title">
          <h2>The Hero collection</h2>
          <p>108 places in the record. Each with a story of its own.</p>
          <ContractAddress name="XY107" address={nftAddress} />
        </div>
        <div className="toolbar">
          <div className="filters" aria-label="Filter heroes">
            {['All', 'Minted', 'Available'].map((value) => (
              <button key={value} aria-pressed={filter === value} onClick={() => setFilter(value)}>
                {value}
                {value === 'All' && <span>108</span>}
              </button>
            ))}
          </div>
          <label className="search">
            <MagnifyingGlass size={19} />
            <span className="sr-only">Search heroes by name or number</span>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search name or number"
            />
          </label>
        </div>
        <ReadStatus
          error={query.isError}
          loading={configured && query.isPending}
          retry={() => void query.refetch()}
        />
        {minted.data && (
          <p className="notice">
            This wallet has already minted a Hero. You can still explore the collection and
            contribute to the public sale.
          </p>
        )}
        <div className="nft-grid">
          {shown.map((hero) => (
            <button
              className={`nft-card ${data ? hero.state : 'unknown'}`}
              key={hero.id}
              onClick={() => choose(hero)}
              aria-label={`Open ${hero.name}, ${data ? stateLabels[hero.state] : 'state unavailable'}`}
            >
              <div className="card-art">
                {hero.image ? (
                  <Artwork src={hero.image} name={hero.name} />
                ) : (
                  <>
                    <span className="card-number">{String(hero.id).padStart(3, '0')}</span>
                    <span className="placeholder-caption">
                      {hero.id === 1 ? 'Songjiang' : 'Hero record'}
                    </span>
                  </>
                )}
                {data && hero.state === 'available' && hero.id !== 1 && (
                  <span className="mint-hover">Mint Hero · {formatEther(data.price)} ETH</span>
                )}
              </div>
              <div className="card-info">
                <h3>{hero.name}</h3>
                <span className="state">
                  {data &&
                    (hero.state === 'committed' ? (
                      <Check />
                    ) : hero.id === 1 ? (
                      <LockKey />
                    ) : hero.state === 'pending' ? (
                      <ImageSquare />
                    ) : null)}
                  {!data
                    ? 'Awaiting live data'
                    : hero.id === 1 && hero.state !== 'burned'
                      ? `Reserved · ${stateLabels[hero.state]}`
                      : stateLabels[hero.state]}
                </span>
              </div>
            </button>
          ))}
        </div>
        {!shown.length && (
          <div className="empty">
            <h3>No heroes found</h3>
            <p>Try another number, name, or filter.</p>
            <button
              className="button secondary"
              onClick={() => {
                setFilter('All')
                setSearch('')
              }}
            >
              Clear filters
            </button>
          </div>
        )}
      </section>
      <section className="collection-note">
        <LockKey size={26} />
        <div>
          <h3>One reserved place. A shared milestone.</h3>
          <p>
            Songjiang (#001) is held by the contract. After all 107 Heroes are minted, anyone can
            burn it and the associated 8,520,000 XY.
          </p>
          <a href={links.whitepaper} target="_blank" rel="noreferrer">
            Read the project rules
          </a>
        </div>
      </section>
      {selected && (
        <Modal
          open
          onOpenChange={() => setSelected(undefined)}
          title={selected.name}
          description={
            !data
              ? 'Live contract data is not available yet.'
              : selected.id === 1
                ? 'Songjiang is reserved by the contract and cannot be minted.'
                : selected.state === 'available'
                  ? minted.data
                    ? 'This wallet has already used its one Hero mint.'
                    : 'Mint eligibility is unavailable. Retry after the wallet and live reads recover.'
                  : stateLabels[selected.state]
          }
        >
          {selected.image && <Artwork src={selected.image} name={selected.name} />}
          <p>{selected.description || 'Artwork and details appear after metadata is committed.'}</p>
          {selected.owner && <p className="address">Owner: {selected.owner}</p>}
          {selected.state === 'committed' && (
            <p className="address">Committed image hash: {selected.hash}</p>
          )}
        </Modal>
      )}
    </>
  )
}
function Artwork({ src, name }: { src: string; name: string }) {
  const [failed, setFailed] = useState(false)
  return failed ? (
    <div className="image-error">
      <ImageSquare size={32} />
      <span>Artwork unavailable</span>
    </div>
  ) : (
    <img
      src={src}
      alt={name}
      loading="lazy"
      referrerPolicy="no-referrer"
      onError={() => setFailed(true)}
    />
  )
}
