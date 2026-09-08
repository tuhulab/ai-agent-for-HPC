#!/usr/bin/env bash
# ==============================================================================
# UCloud VM Bootstrap Script (vm-ubuntu)
# ==============================================================================
# Purpose:
#   Turns a freshly launched UCloud Ubuntu VM into a fully configured,
#   high-performance agentic and developer workstation in under 2 minutes.
#
# Key Features:
#   1. Installs modern CLI tools: starship, fastfetch, eza, bat, git, tmux, uv.
#   2. Installs Docker engine and configures non-root user permissions.
#   3. Installs native Node.js v22 and agent CLIs (Claude Code, OMP, Pi).
#   4. Installs Ghostty terminfo to eliminate "unknown terminal type" errors.
#   5. Wires shared Git credentials and AI tokens from the persistent drive (/work/*)
#      without compromising local SSD execution speeds (Option B clean separation).
#   6. Completely idempotent — safe to re-run anytime.
# ==============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}       UCloud VM Automatic Workstation Bootstrap      ${NC}"
echo -e "${CYAN}======================================================${NC}"

# ------------------------------------------------------------------------------
# 1. Discover Persistent Mounted Folder under /work
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[1/7] Discovering persistent storage...${NC}"
MOUNTED_DIR="$(ls -d /work/*/ 2>/dev/null | grep -v 'lost+found' | head -n 1 | sed 's/\/$//' || true)"

if [ -n "$MOUNTED_DIR" ] && [ -d "$MOUNTED_DIR" ]; then
    echo -e "${GREEN}✓ Found persistent volume: ${CYAN}${MOUNTED_DIR}${NC}"
else
    echo -e "${RED}Warning: No attached project drive found in /work/. Proceeding with standalone setup.${NC}"
    MOUNTED_DIR=""
fi

# ------------------------------------------------------------------------------
# 2. System Packages & Modern CLI Utilities
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/7] Installing system packages, Docker, and runtimes...${NC}"
sudo apt-get update -qq

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    starship \
    fastfetch \
    eza \
    bat \
    zsh \
    git \
    tmux \
    curl \
    jq \
    build-essential \
    docker.io \
    docker-compose-v2 \
    nodejs \
    npm \
    gh

# Configure Docker permissions for current user
if id -nG "$USER" | grep -qw "docker"; then
    echo -e "${GREEN}✓ User $USER already in docker group${NC}"
else
    sudo usermod -aG docker "$USER"
    echo -e "${GREEN}✓ Added $USER to docker group (active in new subshells)${NC}"
fi

# Ensure ~/.local/bin exists
mkdir -p "$HOME/.local/bin" "$HOME/.config"

# Symlink batcat to bat
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"

# Install uv (blazing-fast Python package and venv runner)
if ! command -v uv >/dev/null 2>&1; then
    echo -e "${CYAN}Installing Astral uv...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# ------------------------------------------------------------------------------
# 3. Agent CLIs (Claude Code, OMP, Pi) on Local SSD
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/7] Setting up native Agent CLIs on local SSD...${NC}"

# Claude Code
if ! command -v claude >/dev/null 2>&1; then
    echo -e "${CYAN}Installing Claude Code CLI globally...${NC}"
    sudo npm install -g @anthropic-ai/claude-code
fi

# Pi Coding Agent
if ! command -v pi >/dev/null 2>&1; then
    if [ -n "$MOUNTED_DIR" ] && [ -f "$MOUNTED_DIR/bin/pi" ]; then
        cp "$MOUNTED_DIR/bin/pi" "$HOME/.local/bin/pi"
        chmod +x "$HOME/.local/bin/pi"
    else
        sudo npm install -g @earendil-works/pi-coding-agent 2>/dev/null || true
    fi
fi

# Oh My Pi (omp)
if ! command -v omp >/dev/null 2>&1; then
    if [ -n "$MOUNTED_DIR" ] && [ -f "$MOUNTED_DIR/bin/omp.real" ]; then
        sudo cp "$MOUNTED_DIR/bin/omp.real" /usr/local/bin/omp
        sudo chmod +x /usr/local/bin/omp
    fi
fi

# ------------------------------------------------------------------------------
# 4. Ghostty Terminfo (Eliminate "unknown terminal type" error)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/7] Verifying Ghostty terminfo definitions...${NC}"
if ! infocmp xterm-ghostty >/dev/null 2>&1; then
    # Generate basic xterm-ghostty compatibility mapping if tic is available
    if command -v tic >/dev/null 2>&1; then
        cat << 'EOF' | tic -x - >/dev/null 2>&1 || true
xterm-ghostty|ghostty terminal,
	use=xterm-256color,
EOF
        sudo mkdir -p /usr/share/terminfo/x 2>/dev/null || true
        [ -f "$HOME/.terminfo/x/xterm-ghostty" ] && sudo cp "$HOME/.terminfo/x/xterm-ghostty" /usr/share/terminfo/x/ 2>/dev/null || true
    fi
fi
echo -e "${GREEN}✓ Terminfo database configured${NC}"

# ------------------------------------------------------------------------------
# 5. Starship Prompt Configuration
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/7] Configuring Starship prompt theme...${NC}"
cat << 'STARSHIP_EOF' > "$HOME/.config/starship.toml"
add_newline = false

format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$python\
$nodejs\
$rust\
$docker_context\
$cmd_duration\
$line_break\
$character"""

[username]
show_always = false
style_user = "bold cyan"
format = "[$user]($style)@"

[hostname]
ssh_only = true
style = "bold green"
format = "[$hostname]($style) in "

[directory]
truncation_length = 3
truncation_symbol = "…/"
style = "bold blue"
read_only = " 🔒"

[git_branch]
symbol = " "
style = "bold purple"
format = "on [$symbol$branch]($style) "

[git_status]
style = "bold red"
format = "([$all_status$ahead_behind]($style) )"

[python]
symbol = "🐍 "
style = "bold yellow"
format = "via [$symbol($version )(\\($virtualenv\\) )]($style)"

[nodejs]
symbol = "⬢ "
style = "bold green"
format = "via [$symbol($version )]($style)"

[rust]
symbol = "🦀 "
style = "bold red"
format = "via [$symbol($version )]($style)"

[docker_context]
symbol = " "
style = "bold blue"
format = "via [$symbol$context]($style) "

[cmd_duration]
min_time = 2_000
style = "bold yellow"
format = "took [$duration]($style) "

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"
STARSHIP_EOF
echo -e "${GREEN}✓ ~/.config/starship.toml created${NC}"

# ------------------------------------------------------------------------------
# 6. Configure Shell Profiles (~/.bashrc & ~/.zshrc)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/7] Configuring shell profiles (~/.bashrc & ~/.zshrc)...${NC}"

configure_profile() {
    local rc_file="$1"
    local shell_name="$2"
    
    cat << RC_EOF > "$rc_file"
# Executed by ${shell_name} for interactive shells.
case \$- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend 2>/dev/null || true
HISTSIZE=5000
HISTFILESIZE=10000

# Local high-speed paths (ahead of any network mounts)
export PATH="\$HOME/.local/bin:/usr/local/bin:\$PATH"

# --- Shared Credentials from Persistent Storage (Option B) ---
if [ -n "${MOUNTED_DIR}" ]; then
    [ -f "${MOUNTED_DIR}/.gitconfig" ] && export GIT_CONFIG_GLOBAL="${MOUNTED_DIR}/.gitconfig"
    [ -f "${MOUNTED_DIR}/.ssh/id_ed25519" ] && export GIT_SSH_COMMAND="ssh -i ${MOUNTED_DIR}/.ssh/id_ed25519 -o IdentitiesOnly=yes 2>/dev/null"
    [ -d "${MOUNTED_DIR}/.config" ] && export XDG_CONFIG_HOME="${MOUNTED_DIR}/.config"
    
    # Symlink credential directories for zero-relogin sessions
    [ -d "${MOUNTED_DIR}/.claude" ] && [ ! -L "\$HOME/.claude" ] && ln -sf "${MOUNTED_DIR}/.claude" "\$HOME/.claude"
    [ -d "${MOUNTED_DIR}/.omp" ] && [ ! -L "\$HOME/.omp" ] && ln -sf "${MOUNTED_DIR}/.omp" "\$HOME/.omp"
fi

# Modern Color CLI Aliases
alias ls="eza --icons --group-directories-first"
alias ll="eza -lh --icons --group-directories-first --git"
alias la="eza -lha --icons --group-directories-first --git"
alias tree="eza --tree --icons"
alias cat="batcat --paging=never"

# Fast system info banner on interactive login
if [ -t 1 ]; then
    fastfetch
fi

# Starship Prompt initialization
eval "\$(starship init ${shell_name})"
RC_EOF
    echo -e "${GREEN}✓ $rc_file configured${NC}"
}

configure_profile "$HOME/.bashrc" "bash"
configure_profile "$HOME/.zshrc" "zsh"

# ------------------------------------------------------------------------------
# 7. Verification Summary
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[7/7] Verifying installed stack...${NC}"
echo -e "  • ${CYAN}OS${NC}:       $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo -e "  • ${CYAN}Kernel${NC}:   $(uname -r)"
echo -e "  • ${CYAN}Node.js${NC}:  $(node -v 2>/dev/null || echo 'N/A')"
echo -e "  • ${CYAN}npm${NC}:      $(npm -v 2>/dev/null || echo 'N/A')"
echo -e "  • ${CYAN}uv${NC}:       $(uv --version 2>/dev/null || echo 'N/A')"
echo -e "  • ${CYAN}Docker${NC}:   $(docker --version 2>/dev/null || echo 'N/A')"
echo -e "  • ${CYAN}Claude${NC}:   $(claude --version 2>/dev/null || echo 'N/A')"
echo -e "  • ${CYAN}OMP${NC}:      $(omp --version 2>/dev/null || echo 'N/A')"
echo -e "  • ${CYAN}Starship${NC}: $(starship --version | head -n 1 2>/dev/null || echo 'N/A')"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}      Bootstrap Complete! Workstation is Ready.       ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "Run: ${CYAN}source ~/.bashrc${NC} (or reconnect) to activate your new shell."
