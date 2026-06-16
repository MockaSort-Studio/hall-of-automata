#!/usr/bin/env bash
# setup-lsp-elixir.sh — install ElixirLS and mcp-language-server for Elixir LSP support.
# Called by invoke.yml when the dispatched agent declares an LSP server with this setup script.
set -euo pipefail

ELIXIR_LS_DIR="/usr/local/lib/elixir-ls"
ELIXIR_LS_BIN="/usr/local/bin/elixir-ls"

echo "[lsp-elixir] installing erlang runtime (apt)"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  erlang-base erlang-dev erlang-parsetools erlang-tools

echo "[lsp-elixir] installing elixir via mise"
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"
mise use --global elixir@latest

echo "[lsp-elixir] installing elixir-ls"
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/elixir-lsp/elixir-ls/releases/latest" \
  | grep browser_download_url | grep '\.zip"' | head -1 | cut -d'"' -f4)
[ -z "$DOWNLOAD_URL" ] && { echo "[lsp-elixir] ERROR: could not resolve elixir-ls download URL"; exit 1; }
curl -fsSL "$DOWNLOAD_URL" -o /tmp/elixir-ls.zip
sudo mkdir -p "${ELIXIR_LS_DIR}"
sudo unzip -o /tmp/elixir-ls.zip -d "${ELIXIR_LS_DIR}" > /dev/null
sudo chmod +x "${ELIXIR_LS_DIR}/language_server.sh"
sudo ln -sf "${ELIXIR_LS_DIR}/language_server.sh" "${ELIXIR_LS_BIN}"
rm /tmp/elixir-ls.zip

echo "[lsp-elixir] installing mcp-language-server"
go install github.com/isaacphi/mcp-language-server@latest

echo "[lsp-elixir] verifying binaries"
command -v elixir-ls    >/dev/null 2>&1 || { echo "[lsp-elixir] ERROR: elixir-ls not found in PATH"; exit 1; }
command -v mcp-language-server >/dev/null 2>&1 || { echo "[lsp-elixir] ERROR: mcp-language-server not found in PATH"; exit 1; }

echo "[lsp-elixir] LSP setup complete"
# Snowball 🐷 — dynamic resolution over hardcoded assumptions: the script now finds reality instead of guessing it.
