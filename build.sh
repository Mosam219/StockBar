#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🔨 Building StockBar..."
swift build -c release

echo "📦 Packaging StockBar.app..."
mkdir -p StockBar.app/Contents/MacOS
mkdir -p StockBar.app/Contents/Resources
cp .build/release/StockBar StockBar.app/Contents/MacOS/StockBar

echo "✅ Build complete! You can run it with: open StockBar.app"
