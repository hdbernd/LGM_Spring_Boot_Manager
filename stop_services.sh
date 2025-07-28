#!/bin/bash

# Spring Boot Services Stopper
# This script stops all Spring Boot services that were started with start_services.sh

# Removed set -e to prevent script exit on kill command failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$SCRIPT_DIR/pids"

echo "🛑 Stopping Spring Boot services..."

# Check if PID directory exists
if [[ ! -d "$PID_DIR" ]]; then
    echo "❌ No PID directory found. Services may not be running or were not started with start_services.sh"
    exit 1
fi

# Function to stop a service
stop_service() {
    local pid_file="$1"
    local service_name=$(basename "$pid_file" .pid)
    local run_script="$PID_DIR/run_$service_name.sh"
    
    if [[ ! -f "$pid_file" ]]; then
        return
    fi
    
    local pid=$(cat "$pid_file")
    
    # First try to find and kill the actual mvn process
    local mvn_pids=$(pgrep -f "mvn spring-boot:run.*$service_name")
    if [[ -n "$mvn_pids" ]]; then
        echo "🔄 Stopping $service_name (Maven process)..."
        for mvn_pid in $mvn_pids; do
            kill "$mvn_pid" 2>/dev/null || true
            
            # Wait for process to stop
            local count=0
            while ps -p "$mvn_pid" > /dev/null 2>&1 && [[ $count -lt 15 ]]; do
                sleep 1
                ((count++))
            done
            
            if ps -p "$mvn_pid" > /dev/null 2>&1; then
                echo "⚠️  Force killing Maven process..."
                kill -9 "$mvn_pid" 2>/dev/null || true
            fi
        done
        echo "✅ Stopped $service_name"
    else
        # Fallback: try to kill the terminal/recorded PID
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "🔄 Stopping $service_name terminal (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            echo "✅ Stopped $service_name terminal"
        else
            echo "⚠️  $service_name was not running"
        fi
    fi
    
    # Clean up files
    rm -f "$pid_file"
    rm -f "$run_script"
}

# Stop all services
for pid_file in "$PID_DIR"/*.pid; do
    if [[ -f "$pid_file" ]]; then
        stop_service "$pid_file"
    fi
done

# Clean up log files (optional - comment out if you want to keep logs)
echo "🧹 Cleaning up log files..."
rm -f "$PID_DIR"/*.log

echo ""
echo "🎉 All services stopped!"