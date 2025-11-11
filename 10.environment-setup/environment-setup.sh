#!/bin/bash

################################################
# TechCorp Ltd. - Environment Setup Automation Script
# Purpose: Standardize user environment across all servers
# Author: samiulAsumel
################################################

set -eou pipefail # Exit on error, undefined variable, or pipeline error

# ==============================================
# Configuration
# ==============================================

COMPANY_NAME="TechCorp Ltd."
SCRIPT_VERSION="1.0.0"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================
# Functions
# ==============================================

# Print color messages
print_info() {
	printf "${BLUE}%s${NC}\n" "$1"
}

print_success() {
	printf "${GREEN}%s${NC}\n" "$1"
}

print_warning() {
	printf "${YELLOW}%s${NC}\n" "$1"
}

print_error() {
	printf "${RED}%s${NC}\n" "$1"
}

# Create backup of existing configuration
backup_configs() {
	print_info "Creating backup of existing configuration..."
	mkdir -p "$BACKUP_DIR"

	[ -f ~/.bash_profile ] && cp ~/.bash_profile "$BACKUP_DIR/"
	[ -f ~/.bashrc ] && cp ~/.bashrc "$BACKUP_DIR/"
	[ -f ~/.profile ] && cp ~/.profile "$BACKUP_DIR/"

	print_success "Backup created at $BACKUP_DIR"
}

# Install .bash_profile
setup_bash_profile() {
	print_info "Setting up .bash_profile..."

	cat > ~/.bash_profile << 'PROFILE_EOF'
# .bash_profile - TechCorp Ltd. Standard Configuration

# Environment Variables
export PATH="$PATH:/usr/local/bin:/opt/devops-tools:$HOME/scripts"
export EDITOR="vim"
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups
export HISTTIMEFORMAT="%F %T "

# Company Variables
export COMPANY_NAME="TechCorp Ltd."
export ENVIRONMENT="${ENVIRONMENT:-development}"

# Source .bashrc
if [ -f ~/.bashrc ]; then
	source ~/.bashrc
fi

# Welcome Message
echo "========================================"
echo "  Welcome to $COMPANY_NAME - $(hostname)"
echo "  Environment: $ENVIRONMENT"
echo "  User: $USER"
echo "========================================"
PROFILE_EOF

	print_success ".bash_profile configured"
}

# Install .bashrc
setup_bashrc() {
	print_info "Setting up .bashrc..."

	cat > ~/.bashrc << 'BASHRC_EOF'
# .bashrc - TechCorp Ltd. Standard Configuration

# Aliases
alias ll='ls -lah --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias meminfo='free -h'
alias diskusage='df -h'
alias update='sudo dnf update -y'

# Functions
mkcd() { mkdir -p "$1" && cd "$1"; }

sysinfo() {
	echo "Hostname: $(hostname)"
	echo "OS: $(cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
	echo "Uptime: $(uptime -p)"
	echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
}

# Custom Prompt
export PS1='\[\033[01;32m\]\u\[\033[00m\]@\[\033[01;34m\]\h\[\033[00m\]:\[\033[01;33m\]\w\[\033[00m\]\$ '

# Shell Options
shopt -s histappend
shopt -s checkwinsize
BASHRC_EOF

	print_success ".bashrc configured"
}

# Create useful directories
create_directories() {
	print_info "Creating standard directory structure..."

	mkdir -p ~/scripts
	mkdir -p ~/projects
	mkdir -p ~/logs
	mkdir -p ~/backups
	mkdir -p ~/temp

	print_success "Directory structure created"
}

# Main execution
main() {
	echo "================================================"
	echo "  TechCorp Ltd. Environment Setup Script v${SCRIPT_VERSION}"
	echo "================================================"
	echo

	# Confirm before proceeding
	read -p "This will modify your shell configuration. Continue? (y/N): " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		print_warning "Setup cancelled by user"
		exit 0
	fi

	# Execute setup steps
	backup_configs
	setup_bash_profile
	setup_bashrc
	create_directories

	echo
	print_success "Environment setup complete!"
	echo
	print_info "To apply changes, run: source ~/.bash_profile"
	print_info "Or log out and log back in"
	echo
	print_info "Backup location: $BACKUP_DIR"
}

# Run main function
main "$@"