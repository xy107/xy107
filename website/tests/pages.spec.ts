import { test, expect } from '@playwright/test'
import { existsSync } from 'node:fs'
import { loadEnv } from 'vite'
import { decodeFunctionData, encodeFunctionResult, multicall3Abi, type Hex } from 'viem'
const env = loadEnv('production', process.cwd())
test('mainnet production build serves repository-prefixed clean routes', async ({ page }) => {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  expect(existsSync('dist/contribute/index.html')).toBe(true)
  expect(existsSync('dist/404.html')).toBe(true)
  await page.goto('./')
  await expect(page.locator('.network-strip')).toContainText('Ethereum')
  await expect(page.locator('.nft-card')).toHaveCount(108)
  await page.getByRole('button', { name: 'Open network settings' }).click()
  await expect(page.getByRole('heading', { name: 'Network settings' })).toBeVisible()
  await expect(page.getByLabel('RPC URL')).toHaveValue(/https?:\/\//)
  await page.getByRole('button', { name: 'Close dialog' }).click()
  await expect(page.getByRole('link', { name: /^XY107 contract source code/ })).toHaveAttribute(
    'href',
    `https://etherscan.io/address/${env.VITE_XY107_ADDRESS}#code`,
  )
  await page.getByRole('button', { name: 'Connect wallet', exact: true }).click()
  await expect(page.getByRole('dialog')).toBeVisible()
  await page.getByRole('button', { name: 'Close dialog' }).click()
  await page.goto('contribute/')
  await expect(page.getByRole('heading', { name: 'Contribute to XY' })).toBeVisible()
  await expect(page.getByRole('link', { name: /^XY contract source code/ })).toHaveAttribute(
    'href',
    `https://etherscan.io/address/${env.VITE_XY_ADDRESS}#code`,
  )
  await expect(page.locator('.contribution-panel .wallet-balance')).toContainText(
    'Connect wallet to view',
  )
  await page.reload()
  await expect(page.getByRole('heading', { name: 'Contribute to XY' })).toBeVisible()
  await page.goto('not-a-route')
  await expect(page.getByRole('heading', { name: 'Page not found' })).toBeVisible()
  expect(errors).toEqual([])
})

test('sale card displays wallet ETH, including zero and read failures, on mobile', async ({
  page,
}) => {
  test.setTimeout(60_000)
  await page.setViewportSize({ width: 320, height: 780 })
  await page.addInitScript(() => {
    let connected = false
    Object.defineProperty(window, 'ethereum', {
      value: {
        isMetaMask: true,
        on() {},
        removeListener() {},
        async request({ method }: { method: string }) {
          if (method === 'eth_chainId') return '0x1'
          if (method === 'eth_requestAccounts') connected = true
          if (method === 'wallet_requestPermissions') {
            connected = true
            return [{ parentCapability: 'eth_accounts' }]
          }
          if (method === 'wallet_getPermissions')
            return connected ? [{ parentCapability: 'eth_accounts' }] : []
          if (method === 'eth_accounts' || method === 'eth_requestAccounts')
            return connected ? ['0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'] : []
          throw new Error(`Unexpected wallet request: ${method}`)
        },
      },
    })
  })
  let balance: string | undefined = '0x112210f47de98115' // 1.234567890123456789 ETH
  await page.route('**/*', async (route) => {
    if (route.request().method() !== 'POST') return route.continue()
    const body = route.request().postDataJSON()
    const requests = Array.isArray(body) ? body : [body]
    function balanceResult(request: { method: string; params?: { data?: Hex }[] }) {
      if (request.method === 'eth_getBalance') return balance
      if (request.method !== 'eth_call' || !request.params?.[0]?.data) return undefined
      try {
        const decoded = decodeFunctionData({ abi: multicall3Abi, data: request.params[0].data })
        const result = encodeFunctionResult({
          abi: multicall3Abi,
          functionName: 'getEthBalance',
          result: BigInt(balance ?? '0x0'),
        })
        if (decoded.functionName === 'getEthBalance') return result
        if (decoded.functionName === 'aggregate3') {
          const results = decoded.args[0].map((call) => {
            const inner = decodeFunctionData({ abi: multicall3Abi, data: call.callData })
            if (inner.functionName !== 'getEthBalance') throw new Error('Not a balance call')
            return { success: true, returnData: result }
          })
          return encodeFunctionResult({
            abi: multicall3Abi,
            functionName: 'aggregate3',
            result: results,
          })
        }
      } catch {
        return undefined
      }
    }
    if (!requests.some((request) => balanceResult(request) !== undefined)) return route.continue()
    const responses = requests.map((request) => ({
      jsonrpc: '2.0',
      id: request.id,
      ...(balance !== undefined
        ? { result: balanceResult(request) }
        : { error: { code: -32000, message: 'Balance unavailable' } }),
    }))
    await route.fulfill({ json: Array.isArray(body) ? responses : responses[0] })
  })
  await page.goto('contribute/')
  await page.locator('.contribution-panel').getByRole('button', { name: 'Connect wallet' }).click()
  await page.getByRole('button', { name: 'Browser wallet' }).click()
  const display = page.locator('.contribution-panel .wallet-balance')
  await expect(display).toContainText('1.234568 ETH')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.screenshot({ path: 'test-results/pages/balance-mobile.png', fullPage: true })
  balance = '0x0'
  await expect(display).toContainText('0.000000 ETH', { timeout: 20_000 })
  balance = undefined
  await expect(display).toContainText('Unavailable', { timeout: 30_000 })
})
