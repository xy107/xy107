import { parseAbi } from 'viem'
export const nftAbi = parseAbi([
  'function heroMintCount() view returns (uint256)',
  'function MINT_PRICE_ETH() view returns (uint256)',
  'function ownerOf(uint256) view returns (address)',
  'function metadata(uint256) view returns (string name, string description, bytes32 imageHash)',
  'function imageBaseURI() view returns (string)',
  'function hasMintedHero(address) view returns (bool)',
  'function mint(uint256) payable',
  'error InvalidToken()',
  'error InvalidState()',
  'error ERC721NonexistentToken(uint256 tokenId)',
])
export const xyAbi = parseAbi([
  'function totalRaisedEth() view returns (uint256)',
  'function ROUND_CAP_ETH() view returns (uint256)',
  'function XY_BASE_UNITS_PER_ETH() view returns (uint256)',
  'function trancheRemaining(uint8) view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
  'function contribute() payable',
  'event Contributed(address indexed sender, uint256 acceptedEth, uint256 refundedEth, uint256 receivedXy, uint256 totalRaisedEth)',
  'error InvalidState()',
  'error InvalidInput()',
])
