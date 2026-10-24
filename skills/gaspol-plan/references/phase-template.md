# Phase template

The structure every phase follows, copied verbatim. `SKILL.md` states the rules for Deps, Complexity, the TDD step 1 and the Verification block.

```markdown
### Phase A: [Phase Name]

**Deps:** none                           <!-- or: A, B  (phase ids, comma separated, case-sensitive) -->
**Complexity:** medium — [one-sentence reason]   <!-- light | medium | complex, then a dash and WHY -->
**Estimated time:** [X minutes]

**Files:**
- Create: `src/components/SegmentCard.tsx`
- Modify: `src/screens/Workspace/ScriptStep.tsx`
- Test: `src/__tests__/SegmentCard.test.tsx`

**Steps:**
1. Write failing test for SegmentCard rendering. Expected error: `ReferenceError: SegmentCard is not defined`
2. Run test, confirm it fails for the expected reason
3. Implement SegmentCard with real data from useWorkspace()
4. Run tests, confirm all pass
5. Commit: "feat: add SegmentCard with workspace integration"

**Verification:**
- [ ] SegmentCard renders with real data from WorkspaceContext
- [ ] SegmentCard shows the empty state when the workspace has no segments
```
