import { useEffect, useState } from 'react'
import { useAccount } from 'wagmi'
import { Wallet, List, X, ArrowSquareOut, GearSix } from '@phosphor-icons/react'
import { chain, configured, links } from './config'
import { Collection } from './Collection'
import { Contribute } from './Contribute'
import { RpcSettingsModal, WalletModal } from './ui'
import { Transaction, type Intent } from './Transaction'
export default function App() {
  const [path, setPath] = useState(location.pathname)
  const [walletOpen, setWalletOpen] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [intent, setIntent] = useState<Intent>()
  const { address } = useAccount()
  const base = import.meta.env.BASE_URL
  const route = path.slice(base.length).replace(/\/$/, '')
  const sale = route === 'contribute'
  const notFound = route !== '' && !sale
  useEffect(() => {
    const pop = () => setPath(location.pathname)
    window.addEventListener('popstate', pop)
    return () => window.removeEventListener('popstate', pop)
  }, [])
  useEffect(() => {
    document.title = `${sale ? 'Contribute to XY' : notFound ? 'Page not found' : 'The heroes remain'} | XY107`
  }, [sale, notFound])
  function navigate(event: React.MouseEvent<HTMLAnchorElement>, target: string) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    history.pushState({}, '', target)
    setPath(target)
    setMenuOpen(false)
    window.scrollTo(0, 0)
  }
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="header">
        <a className="brand" href={base} onClick={(e) => navigate(e, base)}>
          xy<span>107</span>
        </a>
        <nav className="primary-nav" aria-label="Main navigation">
          <a
            aria-current={!sale && !notFound ? 'page' : undefined}
            href={base}
            onClick={(e) => navigate(e, base)}
          >
            Minting
          </a>
          <a
            aria-current={sale ? 'page' : undefined}
            href={`${base}contribute`}
            onClick={(e) => navigate(e, `${base}contribute`)}
          >
            Token sale
          </a>
        </nav>
        <nav className="external-nav" aria-label="Project links">
          {Object.entries(links).map(([name, href]) => (
            <a key={name} href={href} target="_blank" rel="noreferrer">
              {
                {
                  x: 'X',
                  github: 'GitHub',
                  readme: 'README',
                  whitepaper: 'Whitepaper',
                  events: 'Events',
                }[name]
              }
            </a>
          ))}
        </nav>
        <button className="button wallet-button" onClick={() => setWalletOpen(true)}>
          <Wallet size={19} />
          {address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'Connect wallet'}
        </button>
        <button
          className="icon-button settings-button"
          aria-label="Open network settings"
          onClick={() => setSettingsOpen(true)}
        >
          <GearSix size={21} />
        </button>
        <button
          className="icon-button menu-button"
          aria-expanded={menuOpen}
          aria-controls="mobile-links"
          aria-label={menuOpen ? 'Close menu' : 'Open menu'}
          onClick={() => setMenuOpen(!menuOpen)}
        >
          {menuOpen ? <X size={24} /> : <List size={24} />}
        </button>
      </header>
      {menuOpen && (
        <nav id="mobile-links" className="mobile-links" aria-label="Project links">
          {Object.entries(links).map(([name, href]) => (
            <a key={name} href={href} target="_blank" rel="noreferrer">
              {
                {
                  x: 'X (Twitter)',
                  github: 'GitHub',
                  readme: 'Project README',
                  whitepaper: 'Whitepaper',
                  events: 'Events',
                }[name]
              }
              <ArrowSquareOut size={16} />
            </a>
          ))}
        </nav>
      )}
      <main id="main">
        <div className="network-strip">
          <span className="network-indicator" />
          {chain.name}
          {chain.id !== 1 && ' · Test network'}
          <span className="network-message">Record, and encourage change.</span>
        </div>
        {!configured && (
          <div className="notice">
            Contracts are not configured for this network. Explore the collection; live statistics
            and transactions become available after deployment.
          </div>
        )}
        {notFound ? (
          <section className="empty">
            <h1>Page not found</h1>
            <a href={base} onClick={(e) => navigate(e, base)}>
              Return to the collection
            </a>
          </section>
        ) : sale ? (
          <Contribute connect={() => setWalletOpen(true)} transact={setIntent} />
        ) : (
          <Collection connect={() => setWalletOpen(true)} transact={setIntent} />
        )}
      </main>
      <footer>
        <a className="brand" href={base} onClick={(e) => navigate(e, base)}>
          xy<span>107</span>
        </a>
        <p lang="zh">记录，行动，促进好的改变。</p>
        <a href={links.github} target="_blank" rel="noreferrer">
          Open source. On-chain. <ArrowSquareOut size={16} />
        </a>
      </footer>
      <WalletModal open={walletOpen} onOpenChange={setWalletOpen} />
      <RpcSettingsModal open={settingsOpen} onOpenChange={setSettingsOpen} />
      {intent && <Transaction intent={intent} close={() => setIntent(undefined)} />}
    </>
  )
}
