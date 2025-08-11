# Tile Game – Known Issues

## 1. Manual Game Start
Owner must manually initialize each round.  
**Fix:** Integrate Chainlink Automation to auto-start/reset rounds.

## 2. No Round Tracking
No `roundNumber` stored, so player data persists between rounds.  
**Fix:** Add `currentRound` and store `players`/`tiles` per round.

## 3. Player Data Not Cleared
`resetGame()` only clears tiles, not `players`.  
Old purchases let new players open more tiles than bought.  
**Fix:** Track `playerList` per round and `delete` entries, or use round-based mappings.

---

### Recommended
- Add Chainlink Automation
- Implement round isolation
- Use VRF mocks for local testing
