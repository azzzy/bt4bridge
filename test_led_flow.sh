#!/bin/bash

echo "Testing LED Control Flow"
echo "========================"
echo ""

# Check if bridge is built
if [ ! -f .build/release/bt4bridge ]; then
    echo "❌ Bridge not built. Building now..."
    swift build -c release
fi

echo "✅ Bridge executable found"
echo ""
echo "To test LED control:"
echo "1. Terminal 1: Run '.build/release/bt4bridge'"
echo "2. Wait for 'PG_BT4 connected' message"
echo "3. Terminal 2: Run './send_cc.swift 16 127'"
echo "4. You should see:"
echo "   - In bridge logs: 'LED 1 ON' or similar"
echo "   - Physical LED 1 should turn ON"
echo ""
echo "LED Command Reference:"
echo "  CC 16 = LED 1"
echo "  CC 17 = LED 2"
echo "  CC 18 = LED 3"
echo "  CC 19 = LED 4"
echo "  Value >= 64 = ON, < 64 = OFF"
echo ""
echo "Expected LED commands sent to device:"
echo "  LED ON:  A2 1X 00  (reversed logic!)"
echo "  LED OFF: A2 1X 01"
