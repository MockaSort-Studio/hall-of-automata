#!/usr/bin/env bash
# setup-lsp-elixir.sh — install ElixirLS and mcp-language-server for Elixir LSP support.
# Called by invoke.yml when the dispatched agent declares an LSP server with this setup script.
set -euo pipefail

echo "[lsp-elixir] installing elixir"
apt-get update > /dev/null
apt-get install -y --no-install-recommends elixir > /dev/null

echo "[lsp-elixir] installing mcp-language-server"
go install github.com/isaacphi/mcp-language-server@latest

echo "[lsp-elixir] LSP setup complete"
