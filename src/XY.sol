// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IXY} from "./interfaces/IXY.sol";
import {IXY107} from "./interfaces/IXY107.sol";

contract XY is ERC20, ReentrancyGuard, IXY {
    using Address for address payable;
    enum Tranche {
        SONGJIANG,
        PUBLIC,
        SEED_SUPPORTER,
        SPREADER,
        YU,
        ARTIST
    }

    uint256 public constant TOTAL_SUPPLY = 21_000_000e8;
    uint256 public constant SONGJIANG_AMOUNT = 8_520_000e8;
    uint256 public constant PUBLIC_AMOUNT = 4_280_000e8;
    uint256 public constant SEED_SUPPORTER_TOTAL_AMOUNT = 1_200_000e8;
    uint256 public constant SPREADER_TOTAL_AMOUNT = 4_000_000e8;
    uint256 public constant YU_AMOUNT = 1_000_000e8;
    uint256 public constant ARTIST_AMOUNT = 1_000_000e8;
    uint256 public constant CREATOR_AMOUNT = 1_000_000e8;
    uint256 public constant SPREADER_AMOUNT = 40_000e8;
    uint256 public constant MIN_PURCHASE_XY = 1e8;
    uint256 public constant XY_BASE_UNITS_PER_ETH = 10_000e8;
    uint256 public constant SLOT_PAYOUT_ETH = 4 ether;
    uint256 public constant ROUND_CAP_ETH = 428 ether;
    uint256 public constant ALLOCATION_PERIOD = 360 days;
    uint256 public constant MAX_SPREADER_COUNT = 100;

    address public immutable CREATOR;
    address public xy107;
    address public admin;
    bytes32 public xAccount;
    uint256 public immutable ALLOCATION_DEADLINE;

    mapping(Tranche => uint256) public trancheRemaining;
    uint256 public totalBurned;
    uint256 public payoutPoolEth;
    uint256 public totalRaisedEth;
    uint256 public totalRoundAllocatedXy;
    bytes32 public paidSlotBitmap;
    bool public yuReleased;
    uint8 public paidSeedSupporterBitmap;
    uint256 public spreaderPaidCount;
    bool public artistPaid;

    event Contributed(
        address indexed sender,
        uint256 acceptedEth,
        uint256 refundedEth,
        uint256 receivedXy,
        uint256 totalRaisedEth
    );
    event SlotPaid(uint256 indexed index, address indexed recipient, uint256 amountEth);
    event YuReleased(address indexed to, uint256 amount);
    event YuBurned(uint256 amount);
    event SeedSupporterPaid(uint8 indexed index, address indexed recipient, uint256 amount);
    event ListDistributed(Tranche indexed tranche, uint256 count, uint256 total);
    event ListBurned(Tranche indexed tranche, uint256 amount);
    event ArtistPaid(address indexed to, uint256 amount);
    event CreatorPaid(address indexed to, uint256 amount);
    event AdminTransferred(address indexed from, address indexed to);
    event XAccountUpdated(bytes32 indexed hash);
    event XY107Set(address indexed xy107);
    event SongjiangBurned(uint256 amount);
    event Burn(Tranche indexed tranche, uint256 amount);

    error Unauthorized();
    error InvalidAddress();
    error InvalidState();
    error InvalidInput();

    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    function _checkOperator() private view {
        if (msg.sender != operator()) revert Unauthorized();
    }

    constructor(string memory name_, string memory symbol_, bytes32 xAccount_)
        ERC20(name_, symbol_)
    {
        if (xAccount_ == bytes32(0)) revert InvalidInput();
        CREATOR = msg.sender;
        xAccount = xAccount_;
        ALLOCATION_DEADLINE = block.timestamp + ALLOCATION_PERIOD;

        trancheRemaining[Tranche.SONGJIANG] = SONGJIANG_AMOUNT;
        trancheRemaining[Tranche.PUBLIC] = PUBLIC_AMOUNT;
        trancheRemaining[Tranche.SEED_SUPPORTER] = SEED_SUPPORTER_TOTAL_AMOUNT;
        trancheRemaining[Tranche.SPREADER] = SPREADER_TOTAL_AMOUNT;
        trancheRemaining[Tranche.YU] = YU_AMOUNT;
        trancheRemaining[Tranche.ARTIST] = ARTIST_AMOUNT;

        _mint(address(this), TOTAL_SUPPLY);
        _transfer(address(this), msg.sender, CREATOR_AMOUNT);
        emit CreatorPaid(msg.sender, CREATOR_AMOUNT);
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function setXy107(address xy107_) external {
        if (msg.sender != CREATOR) revert Unauthorized();
        if (xy107 != address(0) || xy107_ == address(0) || xy107_.code.length == 0) {
            revert InvalidAddress();
        }
        try IXY107(xy107_).XY() returns (IXY linkedXy) {
            if (address(linkedXy) != address(this)) revert InvalidAddress();
        } catch {
            revert InvalidAddress();
        }
        xy107 = xy107_;
        emit XY107Set(xy107_);
    }

    function contribute() external payable nonReentrant {
        if (trancheRemaining[Tranche.PUBLIC] == 0 || msg.value == 0) revert InvalidState();
        uint256 remainingEth = ROUND_CAP_ETH - totalRaisedEth;
        uint256 acceptedEth = msg.value > remainingEth ? remainingEth : msg.value;
        uint256 refundedEth = msg.value - acceptedEth;
        uint256 xyAmount = acceptedEth == remainingEth
            ? trancheRemaining[Tranche.PUBLIC]
            : acceptedEth * XY_BASE_UNITS_PER_ETH / 1 ether;
        if (xyAmount == 0 || (xyAmount < MIN_PURCHASE_XY && acceptedEth != remainingEth)) {
            revert InvalidInput();
        }

        trancheRemaining[Tranche.PUBLIC] -= xyAmount;
        totalRoundAllocatedXy += xyAmount;
        payoutPoolEth += acceptedEth;
        totalRaisedEth += acceptedEth;
        _transferTranche(msg.sender, xyAmount);

        if (refundedEth != 0) _sendEth(msg.sender, refundedEth);
        emit Contributed(msg.sender, acceptedEth, refundedEth, xyAmount, totalRaisedEth);
    }

    function paySlot(uint256 index, address recipient) external nonReentrant onlyOperator {
        if (index < 2 || index > 108 || recipient == address(0) || payoutPoolEth < SLOT_PAYOUT_ETH)
        {
            revert InvalidInput();
        }
        uint256 mask = 1 << (index - 2);
        if (uint256(paidSlotBitmap) & mask != 0) revert InvalidState();
        paidSlotBitmap = bytes32(uint256(paidSlotBitmap) | mask);
        payoutPoolEth -= SLOT_PAYOUT_ETH;
        emit SlotPaid(index, recipient, SLOT_PAYOUT_ETH);
        _sendEth(recipient, SLOT_PAYOUT_ETH);
    }

    function releaseYu(address to) external onlyOperator {
        // Allocation windows intentionally use timestamp-level precision.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= ALLOCATION_DEADLINE) revert InvalidState();
        if (to == address(0)) revert InvalidInput();
        if (yuReleased || trancheRemaining[Tranche.YU] != YU_AMOUNT) revert InvalidState();
        yuReleased = true;
        trancheRemaining[Tranche.YU] = 0;
        _transferTranche(to, YU_AMOUNT);
        emit YuReleased(to, YU_AMOUNT);
    }

    function burnYu() external {
        // Allocation windows intentionally use timestamp-level precision.
        if (
            // forge-lint: disable-next-line(block-timestamp)
            block.timestamp < ALLOCATION_DEADLINE || yuReleased || trancheRemaining[Tranche.YU] == 0
        ) {
            revert InvalidState();
        }
        uint256 amount = trancheRemaining[Tranche.YU];
        _burnTranche(Tranche.YU, amount);
        emit YuBurned(amount);
    }

    function paySeedSupporter(address recipient, uint8 index) external {
        if (recipient == address(0)) revert InvalidAddress();
        if (index > 2) revert InvalidInput();
        // Allocation windows intentionally use timestamp-level precision.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= ALLOCATION_DEADLINE) revert InvalidState();
        if (msg.sender != CREATOR) revert Unauthorized();

        uint8 seatBit = uint8(1 << index);
        if (paidSeedSupporterBitmap & seatBit != 0) revert InvalidState();
        uint256 amount = index == 0 ? 600_000e8 : index == 1 ? 400_000e8 : 200_000e8;
        paidSeedSupporterBitmap |= seatBit;
        // SeedSupporterPaid below records this access-controlled accounting change.
        // forge-lint: disable-next-line(missing-events-access-control)
        trancheRemaining[Tranche.SEED_SUPPORTER] -= amount;
        _transferTranche(recipient, amount);
        emit SeedSupporterPaid(index, recipient, amount);
    }

    function distributeSpreaders(address[] calldata recipients) external onlyOperator {
        uint256 length = recipients.length;
        if (length == 0 || spreaderPaidCount + length > MAX_SPREADER_COUNT) {
            revert InvalidInput();
        }
        // Allocation windows intentionally use timestamp-level precision.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= ALLOCATION_DEADLINE) revert InvalidState();

        uint256 total = length * SPREADER_AMOUNT;
        if (total > trancheRemaining[Tranche.SPREADER]) revert InvalidInput();
        spreaderPaidCount += length;
        // ListDistributed below records this access-controlled accounting change.
        // forge-lint: disable-next-line(missing-events-access-control)
        trancheRemaining[Tranche.SPREADER] -= total;
        for (uint256 i = 0; i < length; ++i) {
            // Input validation necessarily occurs while processing each list item.
            // forge-lint: disable-next-line(require-revert-in-loop)
            if (recipients[i] == address(0)) revert InvalidAddress();
            _transferTranche(recipients[i], SPREADER_AMOUNT);
        }
        emit ListDistributed(Tranche.SPREADER, length, total);
    }

    function payArtist(address to) external onlyOperator {
        if (to == address(0)) revert InvalidAddress();
        if (artistPaid || trancheRemaining[Tranche.ARTIST] != ARTIST_AMOUNT) {
            revert InvalidState();
        }
        artistPaid = true;
        trancheRemaining[Tranche.ARTIST] = 0;
        _transferTranche(to, ARTIST_AMOUNT);
        emit ArtistPaid(to, ARTIST_AMOUNT);
    }

    function burnSpreaderRemainder() external {
        // Allocation windows intentionally use timestamp-level precision.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < ALLOCATION_DEADLINE || trancheRemaining[Tranche.SPREADER] == 0) {
            revert InvalidState();
        }
        uint256 amount = trancheRemaining[Tranche.SPREADER];
        _burnTranche(Tranche.SPREADER, amount);
        emit ListBurned(Tranche.SPREADER, amount);
    }

    function burnSeedSupporterRemainder() external {
        // Allocation windows intentionally use timestamp-level precision.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < ALLOCATION_DEADLINE || trancheRemaining[Tranche.SEED_SUPPORTER] == 0)
        {
            revert InvalidState();
        }
        uint256 amount = trancheRemaining[Tranche.SEED_SUPPORTER];
        _burnTranche(Tranche.SEED_SUPPORTER, amount);
        emit ListBurned(Tranche.SEED_SUPPORTER, amount);
    }

    function transferAdmin(address newAdmin) external onlyOperator {
        if (newAdmin == address(0)) revert InvalidAddress();
        address old = admin;
        admin = newAdmin;
        emit AdminTransferred(old, newAdmin);
    }

    function setXAccount(bytes32 hash) external onlyOperator {
        if (hash == bytes32(0)) revert InvalidInput();
        xAccount = hash;
        emit XAccountUpdated(hash);
    }

    function burnSongjiangLock() external {
        if (msg.sender != xy107 || trancheRemaining[Tranche.SONGJIANG] != SONGJIANG_AMOUNT) {
            revert Unauthorized();
        }
        _burnTranche(Tranche.SONGJIANG, SONGJIANG_AMOUNT);
        emit SongjiangBurned(SONGJIANG_AMOUNT);
    }

    function operator() public view returns (address) {
        return admin == address(0) ? CREATOR : admin;
    }

    function _transferTranche(address to, uint256 amount) private {
        _transfer(address(this), to, amount);
    }

    function _burnTranche(Tranche trancheType, uint256 amount) private {
        // The caller emits a tranche-specific event and Burn records the supply change.
        // forge-lint: disable-next-line(missing-events-access-control)
        trancheRemaining[trancheType] = 0;
        totalBurned += amount;
        _burn(address(this), amount);
        emit Burn(trancheType, amount);
    }

    function _sendEth(address recipient, uint256 amountEth) private {
        // Recipients are deliberately selected by contributors or the authorized operator.
        // forge-lint: disable-next-line(arbitrary-send-eth)
        payable(recipient).sendValue(amountEth);
    }
}
