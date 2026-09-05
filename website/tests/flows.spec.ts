import AxeBuilder from '@axe-core/playwright'
import { test, expect } from '@playwright/test'
import { createPublicClient, http, parseAbi, parseEther } from 'viem'
import { anvil } from 'viem/chains'
import { readFileSync } from 'node:fs'
const env = Object.fromEntries(
  readFileSync('.env.local', 'utf8')
    .trim()
    .split('\n')
    .map((line) => line.split('=')),
)
const client = createPublicClient({ chain: anvil, transport: http('http://127.0.0.1:8545') })
const account = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'
test.beforeEach(async ({ page }) => {
  await page.addInitScript(
    ({ account }) => {
      let connected = false
      let rejectNext = false
      const provider = {
        isMetaMask: true,
        on() {},
        removeListener() {},
        async request({ method, params }: { method: string; params?: unknown[] }) {
          if (method === 'eth_requestAccounts') {
            connected = true
            return [account]
          }
          if (method === 'eth_accounts') return connected ? [account] : []
          if (method === 'wallet_requestPermissions') {
            connected = true
            return [{ parentCapability: 'eth_accounts' }]
          }
          if (method === 'wallet_getPermissions')
            return connected ? [{ parentCapability: 'eth_accounts' }] : []
          if (method === 'wallet_switchEthereumChain') return null
          if (method === 'test_rejectNext') {
            rejectNext = true
            return null
          }
          if (method === 'eth_sendTransaction' && rejectNext) {
            rejectNext = false
            throw Object.assign(new Error('User rejected the request.'), { code: 4001 })
          }
          const response = await fetch('http://127.0.0.1:8545', {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params: params ?? [] }),
          })
          const json = await response.json()
          if (json.error)
            throw Object.assign(new Error(json.error.message), { code: json.error.code })
          return json.result
        },
      }
      Object.defineProperty(window, 'ethereum', { value: provider })
    },
    { account },
  )
})
test('collection, wallet mint, rejection recovery and contribution execute on Anvil', async ({
  page,
}) => {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  await page.goto('./')
  await expect(page.locator('.nft-card')).toHaveCount(108)
  await expect(page.getByRole('button', { name: 'Open Local Hero 002, Committed' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Open Songjiang, Pending metadata' })).toBeVisible()
  await page.getByRole('button', { name: 'Available', exact: true }).click()
  await expect(page.locator('.nft-card')).toHaveCount(106)
  await page.getByRole('button', { name: 'Open Hero 003, Available' }).click()
  await expect(page.getByRole('dialog')).toContainText('Connect your wallet')
  await page.getByRole('button', { name: 'Browser wallet' }).click()
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await page.getByRole('button', { name: 'Open Hero 003, Available' }).click()
  await page.getByRole('button', { name: 'Confirm mint', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Recorded on-chain' })).toBeVisible()
  await expect(page.getByRole('dialog').getByRole('alert')).toHaveCount(0)
  await page.getByRole('button', { name: 'Done', exact: true }).click()
  await expect(page.locator('.nft-card')).toHaveCount(105)
  const owner = await client.readContract({
    address: env.VITE_XY107_ADDRESS as `0x${string}`,
    abi: parseAbi(['function ownerOf(uint256) view returns (address)']),
    functionName: 'ownerOf',
    args: [3n],
  })
  expect(owner.toLowerCase()).toBe(account)
  await page.getByRole('link', { name: 'Token sale', exact: true }).click()
  await page.getByLabel('Contribution amount').fill('0.1')
  await expect(page.locator('.conversion')).toContainText('1,000')
  await page.getByRole('button', { name: 'Review contribution' }).click()
  await page.evaluate(async () => {
    await (
      window as unknown as { ethereum: { request: (arg: { method: string }) => Promise<unknown> } }
    ).ethereum.request({ method: 'test_rejectNext' })
  })
  await page.getByRole('button', { name: 'Confirm contribution', exact: true }).click()
  await expect(page.getByRole('dialog').getByRole('alert')).toContainText('rejected')
  await page.getByRole('button', { name: 'Confirm contribution', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Recorded on-chain' })).toBeVisible()
  await expect(page.getByRole('dialog').getByRole('alert')).toHaveCount(0)
  await page.getByRole('button', { name: 'Done', exact: true }).click()
  await expect(page.locator('.metrics')).toContainText('0.1 ETH')
  const raised = await client.readContract({
    address: env.VITE_XY_ADDRESS as `0x${string}`,
    abi: parseAbi(['function totalRaisedEth() view returns (uint256)']),
    functionName: 'totalRaisedEth',
  })
  expect(raised).toBe(parseEther('0.1'))
  const balance = await client.readContract({
    address: env.VITE_XY_ADDRESS as `0x${string}`,
    abi: parseAbi(['function balanceOf(address) view returns (uint256)']),
    functionName: 'balanceOf',
    args: [account],
  })
  expect(balance).toBe(1_001_000n * 10n ** 8n)
  expect(errors).toEqual([])
})
test('mobile navigation, empty search, image and direct contribution route', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('./')
  await expect(page.getByRole('button', { name: 'Open Local Hero 002, Committed' })).toBeVisible()
  await page.getByRole('button', { name: 'Open menu' }).click()
  await expect(page.getByRole('link', { name: 'Project README' })).toBeVisible()
  await page.getByRole('button', { name: 'Close menu' }).click()
  await page
    .getByRole('textbox', { name: 'Search heroes by name or number' })
    .fill('nothing-matches')
  await expect(page.getByText('No heroes found')).toBeVisible()
  await page.getByRole('button', { name: 'Clear filters' }).click()
  await expect(page.locator('.nft-card')).toHaveCount(108)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.screenshot({ path: 'test-results/mobile.png', fullPage: false })
  await page.goto('contribute')
  await expect(page.getByRole('heading', { name: 'Contribute to XY' })).toBeVisible()
  const saleAccessibility = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
    .analyze()
  expect(saleAccessibility.violations.map(({ id }) => id)).toEqual([])
  await page.screenshot({ path: 'test-results/contribute-mobile.png', fullPage: true })
  await page.getByLabel('Contribution amount').fill('0.00001')
  await expect(page.getByText('Enter a valid amount')).toBeVisible()
  await page.setViewportSize({ width: 1440, height: 1000 })
  await page.goto('./')
  await expect(page.getByRole('button', { name: 'Open Local Hero 002, Committed' })).toBeVisible()
  await page.screenshot({ path: 'test-results/desktop.png', fullPage: false })
  const accessibility = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
    .analyze()
  expect(
    accessibility.violations.map(({ id, nodes }) => ({
      id,
      elements: nodes.map((node) => node.target),
    })),
  ).toEqual([])
})

test('RPC failure never presents unminted state as live availability', async ({ page }) => {
  await page.route('http://127.0.0.1:8545/**', (route) => route.abort())
  await page.goto('./')
  await expect(page.getByText('Live data is unavailable.', { exact: false })).toBeVisible({
    timeout: 30_000,
  })
  await expect(page.getByRole('button', { name: 'Open Hero 004, state unavailable' })).toBeVisible()
  await expect(page.locator('.mint-hover')).toHaveCount(0)
})
