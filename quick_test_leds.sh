#!/bin/bash
# Quick test script for LED control via MIDI CC

echo "🧪 Quick LED Test via MIDI CC"
echo "=============================="
echo ""
echo "This will test LED control by sending MIDI CC messages"
echo "Make sure bt4bridge is running in another terminal!"
echo ""

# Use the Swift tool we created
SEND_CC="./send_cc.swift"

if [ ! -f "$SEND_CC" ]; then
    echo "❌ send_cc.swift not found"
    exit 1
fi

echo "Testing LEDs (watch the device and the bridge terminal)..."
echo ""

# Test each LED
for led in 1 2 3 4; do
    cc=$((15 + led))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    echo "Testing LED $led (CC $cc)"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "Turning ON..."
    swift $SEND_CC $cc 127
    sleep 2
    
    echo "Turning OFF..."
    swift $SEND_CC $cc 0
    sleep 1
    echo ""
done

echo "✅ Test complete!"
echo ""
echo "Did the LEDs respond? Check the bt4bridge terminal for logs."
