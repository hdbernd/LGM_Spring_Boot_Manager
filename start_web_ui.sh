#!/bin/bash

# LGM Spring Boot Service Manager - Web UI Launcher
# This script starts the web interface for the service manager

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 LGM Spring Boot Service Manager - Web UI${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Error: Python 3 is required but not installed${NC}"
    echo -e "${YELLOW}💡 Please install Python 3 and try again${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Python 3 found: $(python3 --version)${NC}"

# Check if Flask is installed
if ! python3 -c "import flask" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Flask not found, installing requirements...${NC}"
    
    # Try to install Flask using pip
    if command -v pip3 &> /dev/null; then
        pip3 install -r requirements.txt
    elif command -v pip &> /dev/null; then
        pip install -r requirements.txt
    else
        echo -e "${RED}❌ Error: pip not found. Please install Flask manually:${NC}"
        echo -e "${YELLOW}   pip3 install Flask==3.0.0${NC}"
        exit 1
    fi
fi

# Check if service manager script exists
if [[ ! -f "service_manager.sh" ]]; then
    echo -e "${RED}❌ Error: service_manager.sh not found in current directory${NC}"
    echo -e "${YELLOW}💡 Please run this script from the LGM service manager directory${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Service manager script found${NC}"
echo ""

# Start the web UI
echo -e "${GREEN}🚀 Starting web interface...${NC}"
echo -e "${BLUE}📱 Open your browser and go to: ${YELLOW}http://localhost:8080${NC}"
echo -e "${BLUE}🛑 Press Ctrl+C to stop the web server${NC}"
echo ""

# Make sure the web UI script is executable
chmod +x web_ui.py

# Start the Flask application
python3 web_ui.py