#!/usr/bin/env bash
# Saves or restores agent task memory from the .hall-memory.json file.
# Required env: MODE (save|restore), MEMORY_JSON (required when MODE=save)
# Output when MODE=restore (GITHUB_OUTPUT): memory-json<<EOF_MEMORY ... EOF_MEMORY
set -euo pipefail

if [[ "${MODE}" == "save" ]]; then
  echo "${MEMORY_JSON}" > .hall-memory.json

elif [[ "${MODE}" == "restore" ]]; then
  if [[ -f .hall-memory.json ]]; then
    CONTENT=$(cat .hall-memory.json)
  else
    CONTENT=""
  fi
  # Use a delimiter to safely handle multi-line JSON in GITHUB_OUTPUT
  echo "memory-json<<EOF_MEMORY" >> "${GITHUB_OUTPUT}"
  echo "${CONTENT}"              >> "${GITHUB_OUTPUT}"
  echo "EOF_MEMORY"              >> "${GITHUB_OUTPUT}"
fi
