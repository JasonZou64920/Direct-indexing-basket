#!/usr/bin/env bash
# Install the direct-index-basket skill into the local Claude skills directory.
# Usage:
#   ./install.sh                              # installs to ~/.claude/skills/direct-index-basket
#   CLAUDE_SKILLS_DIR=/custom/path ./install.sh
set -euo pipefail

SKILL_NAME="direct-index-basket"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SRC_DIR}/skills/${SKILL_NAME}/SKILL.md"

DEST_ROOT="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DEST="${DEST_ROOT}/${SKILL_NAME}"

if [[ ! -f "$SRC" ]]; then
  echo "error: source SKILL.md not found at ${SRC}" >&2
  exit 1
fi

mkdir -p "$DEST"
cp -f "$SRC" "$DEST/SKILL.md"

echo "Installed ${SKILL_NAME} -> ${DEST}/SKILL.md"
echo
echo "Next steps:"
echo "  1. Restart Cowork / Claude Code so the skill is picked up."
echo "  2. Optional: pip install yfinance --break-system-packages   # default data source"
echo "  3. Try it: 'Build a 60-name S&P 500 tracking basket.'"
