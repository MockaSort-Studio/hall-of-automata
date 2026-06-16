#!/usr/bin/env bash
# setup-lsp-elixir.sh — install ElixirLS and mcp-language-server for Elixir LSP support.
# Called by invoke.yml when the dispatched agent declares an LSP server with this setup script.
set -euo pipefail

ELIXIR_LS_DIR="/usr/local/lib/elixir-ls"
ELIXIR_LS_BIN="/usr/local/bin/elixir-ls"

echo "[lsp-elixir] installing elixir runtime"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends elixir unzip

echo "[lsp-elixir] installing elixir-ls"
curl -fsSL "https://github.com/elixir-lsp/elixir-ls/releases/latest/download/elixir-ls.zip" \
  -o /tmp/elixir-ls.zip
sudo mkdir -p "${ELIXIR_LS_DIR}"
sudo unzip -o /tmp/elixir-ls.zip -d "${ELIXIR_LS_DIR}" > /dev/null
sudo chmod +x "${ELIXIR_LS_DIR}/language_server.sh"
sudo ln -sf "${ELIXIR_LS_DIR}/language_server.sh" "${ELIXIR_LS_BIN}"
rm /tmp/elixir-ls.zip

echo "[lsp-elixir] installing mcp-language-server"
go install github.com/isaacphi/mcp-language-server@latest

echo "[lsp-elixir] verifying binaries"
command -v elixir-ls >/dev/null 2>&1 || { echo "[lsp-elixir] ERROR: elixir-ls not found in PATH"; exit 1; }
command -v mcp-language-server >/dev/null 2>&1 || { echo "[lsp-elixir] ERROR: mcp-language-server not found in PATH"; exit 1; }

echo "[lsp-elixir] LSP setup complete"
# Snowball 🐷 — sudo and a real language server: two lines that save the windmill.
