#!/bin/bash
echo "Starting bridge in background..."
.build/release/bt4bridge > /tmp/bridge_test.log 2>&1 &
BRIDGE_PID=$!

echo "Waiting for connection (15 seconds)..."
sleep 15

echo ""
echo "=== Bridge Logs ==="
cat /tmp/bridge_test.log | grep -E "(Using write|Initializing LED|Sending LED|A2|A1|characteristic)"

echo ""
echo "=== Sending test LED command ==="
./send_cc.swift 16 127

sleep 2

echo ""
echo "=== Recent logs after sending command ==="
tail -20 /tmp/bridge_test.log | grep -E "(LED|CC16|A2)"

echo ""
echo "Stopping bridge..."
kill $BRIDGE_PID 2>/dev/null
rm /tmp/bridge_test.log
