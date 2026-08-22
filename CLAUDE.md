# Home Hub Dashboard

This repo already has a thorough handoff doc — don't duplicate it here, just
pull it in automatically so every Claude Code session in this repo has it
without you pasting anything.

@HANDOFF.md

## Notes for Claude Code sessions here

- Family/household context (who Nash/Nellie/Logan are, training philosophy,
  the kitchen touchscreen, design taste) lives in the user-level
  `~/.claude/CLAUDE.md` — don't duplicate it, it's already loaded
  automatically.
- This is the "parent" screen for the Home Hub family of apps — it launches
  into `HomeHub-Web`, `football-practice-planner`, and `maple-grove-crimson`
  (siblings under `C:\Users\Owner\source\repos\`) rather than duplicating
  their functionality. If a change here should also apply to a sibling, flag
  it rather than silently doing both.
- Keep HANDOFF.md itself up to date as this project evolves — it's both the
  human-facing handoff doc and (via the import above) Claude Code's context
  for this repo.

## Where things live (workflow, same pattern as sibling repos)

- **Code, this repo's CLAUDE.md/HANDOFF.md, git history** → here, on this
  PC, under `C:\Users\Owner\source\repos\home-hub-dashboard`. Nothing here
  is mirrored to Drive automatically.
- **This app has no live data source** — everything on screen (clock, date,
  weather) is computed/fetched client-side. No Sheet, no Apps Script.
- **Input files for this project** (design ideas, screenshots) → Google
  Drive, "Claude Tools & Instructions/Home Hub Dashboard" (create this
  subfolder if it doesn't exist yet).
- **Instructional/reference docs** → Drive, "Claude Tools & Instructions/
  Instructions & Guides" — same shared docs used by every project in this
  family.
