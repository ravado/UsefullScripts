# Token Optimization Guide

## Quick Reference

### Configuration Applied
- **Default model**: Haiku (75% token savings on simple tasks)
- **Plan mode**: Auto-switches to Sonnet
- **Read limit**: 150 lines for scripts, 200 for docs
- **Parallel reads**: Up to 5 concurrent file reads
- **Search optimization**: Grep with 20-result limit, 2 context lines

### Expected Savings
- **Simple tasks** (70% of work): ~75% reduction
- **File reads**: ~40% reduction
- **Exploration**: ~75% reduction
- **Overall**: **55-65% fewer tokens**

---

## Usage by Task Type

### Use Haiku (Automatic Default)
```bash
# Reading sensor scripts
claude "Show me all sensor scripts"

# Single-file edits
claude "Fix the indentation in mount_nas.sh"

# Git operations
claude "Create a commit for the config changes"

# Documentation updates
claude "Update README with new script descriptions"
```
**Expected**: 500-2,000 tokens/task

### Use Sonnet (Auto-switches or manual)
```bash
# Plan mode (auto-switches to Sonnet)
claude "/plan Fix PhotoFrame migration issues"

# Complex multi-file changes
claude "Refactor Proxmox GPU passthrough setup"

# Architecture decisions
claude "Design a new component for certificate renewal"
```
**Expected**: 10,000-30,000 tokens/task

---

## Model Switching Behavior

| Context | Model | Why |
|---------|-------|-----|
| Default conversation | Haiku | Most scripts are simple |
| Plan mode (`/plan`) | Sonnet | Needs architectural thinking |
| Proxmox/** tasks | Sonnet | Complex orchestration (825-line scripts) |
| PhotoFrame/** tasks | Haiku | Small focused scripts |
| StoikVisnyk/** tasks | Haiku | Simple Python bot |
| Sensor scripts (read_*.py) | Haiku | 11-21 line utilities |

---

## Read Limits in Action

### Small files (< 150 lines)
```bash
claude "Read PhotoFrame/read_sensor.py"
```
→ Full file loaded (23 lines)

### Medium files (150-200 lines)
```bash
claude "Read PhotoFrame/migration/0_prepare.sh"
```
→ First 150 lines loaded, prompt to read more if needed

### Large files (> 200 lines)
```bash
claude "Read Proxmox/Proxic/0_prepare_proxic.sh"
```
→ Chunked reading strategy (file is 825 lines)

---

## Parallel Operations

### Independent components
```bash
claude "Analyze PhotoFrame, Proxmox, and StoikVisnyk structures"
```
→ Reads happen in parallel (up to 5 concurrent)

### Multiple sensor scripts
```bash
claude "Read all read_*.py files"
```
→ All 10 sensor scripts loaded simultaneously

---

## Search Optimization

### Before (inefficient)
```bash
claude "Find all scripts with color output"
```
→ Reads all files, searches entire codebase

### After (optimized)
```bash
# Uses grep with head_limit: 20, contextLines: 2
claude "Find all scripts with color output"
```
→ Grep search, shows first 20 matches, 2 lines context

---

## Common Patterns (Pre-configured)

You can reference these patterns directly:

```bash
# Find scripts with environment loading
claude "Show files using env_loading pattern"
→ Searches for: source.*env_loader

# Find scripts with error handling
claude "Show files using error_handling pattern"
→ Searches for: set -euo pipefail

# Find numbered scripts
claude "Show numbered_scripts"
→ Searches for: [0-9]_.*\.sh
```

---

## Verification Commands

### Test Haiku on simple task
```bash
claude "Read PhotoFrame/read_sensor.py"
# Check model used (should be Haiku)
```

### Test Sonnet switch
```bash
claude "/plan Implement new feature"
# Check model used (should be Sonnet)
```

### Test parallel reads
```bash
claude "Read all sensor scripts"
# Check if reads happen concurrently
```

### Test read limits
```bash
claude "Read Proxmox/Proxic/0_prepare_proxic.sh"
# Should chunk the 825-line file
```

---

## Rollback Instructions

If you need to revert to previous settings:

```bash
cp .claude/settings.json.backup .claude/settings.json
```

---

## Excluded Patterns

These files are automatically excluded from reads:
- `*.png, *.jpg, *.jpeg, *.gif, *.bmp` - Image files
- `**/__pycache__/**` - Python cache
- `**/node_modules/**` - Node dependencies
- `**/.venv/**, **/venv/**` - Python virtual environments

---

## Context Budget

- **Max tokens per file**: 2,000
- **Max total context**: 10,000 tokens
- Prevents context explosion on large operations

---

## Auto-loaded Context

When working on specific components, these files load automatically:

### Migration tasks
- `PhotoFrame/migration/env_loader.sh`
- `TASK-001.md`

### Proxmox tasks
- `Proxmox/README.md`

### Bot tasks
- `StoikVisnyk/dailyMotivationApp/README.md`

---

## Monitoring Token Usage

After each session, check:
```bash
# Token usage shown in Claude output
# Compare to previous sessions
# Adjust settings if needed
```

Look for:
- Model used (Haiku vs Sonnet)
- Number of tokens consumed
- Whether chunking occurred
- Parallel operation indicators

---

## Tips for Maximum Savings

1. **Be specific**: "Read mount_nas.sh" (not "Show me mounting scripts")
2. **Use patterns**: Reference pre-configured patterns
3. **Trust defaults**: Haiku handles 70% of tasks
4. **Let plan mode switch**: Don't manually request Sonnet
5. **Check first 20**: Most searches covered by head_limit

---

## Settings Files

- **Active config**: `.claude/settings.json`
- **Backup**: `.claude/settings.json.backup`
- **This guide**: `.claude/TOKEN_OPTIMIZATION_GUIDE.md`

---

## Support

If settings cause issues:
1. Check token usage reports
2. Verify model switching behavior
3. Adjust `defaultReadLimit` if needed
4. Restore backup if necessary

For help: https://github.com/anthropics/claude-code/issues
