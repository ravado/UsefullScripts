# UsefullScripts Project Context

## Overview
Home lab automation repository with Bash/Python scripts for:
- Raspberry Pi photo frames
- Proxmox virtualization
- Telegram bots
- Certificate management

## Key Patterns
- Scripts use numbered prefixes (0_, 1_, 2_) for execution order
- Environment variables in `.env` files (not committed)
- Most scripts use `set -euo pipefail`
- Color-coded output (RED, GREEN, YELLOW)

## Important Files
- `TASK-001.md` - Current issues to fix in PhotoFrame migration
- `PhotoFrame/migration/ANALYSIS_REPORT.md` - Detailed issue analysis

## Flow
Before implementing any feature create an TASK-*.md file with a plan and place it into .claude/steering/plans

## Conventions
- Bash scripts should have `set -euo pipefail`
- Add timeouts to network operations
- Use variables instead of hardcoded paths
- Keep scripts idempotent (safe to re-run)
