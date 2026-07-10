#!/bin/bash
export DB_HOST=localhost
export DB_PORT=3306
export DB_USERNAME=root
export DB_PASSWORD=Chen_20040601
export DB_NAME=bird_kingdom
export JWT_SECRET='your-super-secret-jwt-key-change-in-production-birdkingdom-2024'

pkill -f BirdKingdomServer || true
sleep 1
cd /root/bird-kingdom-swift
nohup ./.build/release/BirdKingdomServer serve --env production --hostname 0.0.0.0 --port 8080 > /root/swift-backend.log 2>&1 &
echo "Started! Check log: tail -f /root/swift-backend.log"
