import { mkdir, copyFile } from 'node:fs/promises'
await mkdir('dist/contribute', { recursive: true })
await copyFile('dist/index.html', 'dist/contribute/index.html')
await copyFile('dist/index.html', 'dist/404.html')
