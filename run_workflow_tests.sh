#!/bin/bash

# Workflow System Test Script
# 工作流系统测试脚本
# Run this script on your Mac to test all workflow components

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          Multi-Agent Workflow System Test                        ║"
echo "║                    gemini-swift ADK                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Set API Key
export GEMINI_API_KEY="AIzaSyCWTzhEIF6crdHk1Wqguo7YKgbgeaxqZhw"

echo "📦 Building project..."
swift build 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    echo "Please check for compilation errors."
    exit 1
fi

echo "✅ Build successful!"
echo ""
echo "🚀 Running workflow tests..."
echo ""

# Run the test runner with option 11 (workflow tests)
echo "11" | swift run GeminiTestRunner

echo ""
echo "✅ Tests completed!"
