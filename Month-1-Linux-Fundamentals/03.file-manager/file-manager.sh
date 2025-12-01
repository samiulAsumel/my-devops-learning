#!/bin/bash

# File Management Automation Script
# Purpose: Automate daily file operations
# Author: samiulAsumel

# ==============================
# Color code for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base directory
BASE_DIR="/company-data"

# Function: Display menu
show_menu() {
    echo "==============================="
    echo "TechCorp File Manager"
    echo "==============================="
    echo "1. Backup configuration files"
    echo "2. Archive old logs (>7 days)"
    echo "3. Create new project structure"
    echo "4. Find files larger than 10MB"
    echo "5. List recent files"
    echo "6. Exit"
    echo "==============================="
}

# Function: Backup configs
backup_configs() {
    echo -e "${YELLOW}Backing up configuration files...${NC}"
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="$BASE_DIR/backups/daily/configs-$BACKUP_DATE"

    mkdir -p "$BACKUP_DIR"
    cp -r "$BASE_DIR/config/"* "$BACKUP_DIR" 2>/dev/null || true

    echo -e "${GREEN}Backup created successfully at: $BACKUP_DIR${NC}"
}

# Function: Archive old logs
archive_old_logs() {
    echo -e "${YELLOW}Archiving logs older than 7 days...${NC}"
    ARCHIVE_DIR="$BASE_DIR/logs/application/archive"

    mkdir -p "$ARCHIVE_DIR"

    # Find and move old logs
    find "$BASE_DIR/logs/application" -name "*.log" -mtime +7 -exec mv {} "$ARCHIVE_DIR" \;

    echo -e "${GREEN}Old logs archived successfully at: $ARCHIVE_DIR${NC}"
}

# Function create project structure
create_project() {
	read -p "Enter new project name: " PROJECT_NAME
	PROJECT_PATH="$BASE_DIR/projects/$PROJECT_NAME"

	if [ -d "$PROJECT_PATH" ]; then
		echo -e "${RED}Project already exists at: $PROJECT_PATH${NC}"
		return
	fi

	echo -e "${YELLOW}Creating project structure...${NC}"
	mkdir -p "$PROJECT_PATH"/{bin,configs,docs,scripts,logs,backups}

	# Create README
	echo "# $PROJECT_NAME" > "$PROJECT_PATH/README.md"
	echo "Project created on $(date)" >> "$PROJECT_PATH/README.md"

	echo -e "${GREEN}Project created successfully at: $PROJECT_PATH${NC}"
	tree "$PROJECT_PATH" 2>/dev/null || ls -la "$PROJECT_PATH"
}

# Function: Find large files
find_large_files() {
	echo -e "${YELLOW}Finding files larger than 10MB...${NC}"
	find "$BASE_DIR" -type f -size +10M -exec ls -lh {} \; | awk '{print $5, $NF}'
}

# Function: List recent logs
list_recent_logs() {
	echo -e "${YELLOW}Recent log files (last 24 hours):${NC}"
	find "$BASE_DIR/logs" -name "*.log" -mtime -1 -exec ls -lh {} \;
}

# Main program loop
while true; do
	show_menu
	read -p "Enter choice [1-6]: " choice

	case $choice in
		1) backup_configs;;
		2) archive_old_logs;;
		3) create_project;;
		4) find_large_files;;
		5) list_recent_logs;;
		6) echo "Exiting..."; exit 0;;
		*) echo -e "${RED}Invalid choice. Please try again.${NC}";;
	esac

	echo ""
	read -p "Press Enter to continue..."
	clear
done