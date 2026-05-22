#!/usr/bin/env bash
# Build the social card (assets/og-card.png) from its Typst source using the
# Typst bundled with Quarto. Run locally and commit the PNG; CI does not build
# it (the runners lack the Inter font).
set -euo pipefail

cd "$(dirname "$0")/.."

quarto typst compile assets/typst/social-card.typ assets/og-card.png --ppi 144

echo "Built assets/og-card.png"
