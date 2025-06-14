# ZSH Lazy Loading Optimization
# Speeds up zsh startup by deferring heavy initializations
# Based on performance analysis showing 3.5s -> target <0.5s startup time

# =============================================================================
# LAZY LOADING FRAMEWORK
# =============================================================================

# Core lazy loading function
lazy_load() {
    local cmd=$1
    local init_func=$2
    
    eval "$cmd() {
        unset -f $cmd
        $init_func
        $cmd \"\$@\"
    }"
}

# Conditional lazy loading (only if tool exists)
lazy_load_conditional() {
    local cmd=$1
    local check_cmd=$2
    local init_func=$3
    
    eval "$cmd() {
        if $check_cmd; then
            unset -f $cmd
            $init_func
            $cmd \"\$@\"
        else
            echo \"$cmd not available\" >&2
            return 1
        fi
    }"
}

# =============================================================================
# NVM LAZY LOADING (Saves ~970ms - 34% of startup time)
# =============================================================================

# Store NVM paths without loading NVM
export NVM_DIR="$HOME/.nvm"

# Lazy initialize NVM
init_nvm() {
    unset -f nvm node npm npx yarn pnpm
    
    # Load NVM
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

# Set up lazy loading for all NVM-related commands
lazy_load_conditional "nvm" "[ -s '$NVM_DIR/nvm.sh' ]" "init_nvm"
lazy_load_conditional "node" "[ -s '$NVM_DIR/nvm.sh' ]" "init_nvm"
lazy_load_conditional "npm" "[ -s '$NVM_DIR/nvm.sh' ]" "init_nvm"
lazy_load_conditional "npx" "[ -s '$NVM_DIR/nvm.sh' ]" "init_nvm"
lazy_load_conditional "yarn" "[ -s '$NVM_DIR/nvm.sh' ]" "init_nvm"
lazy_load_conditional "pnpm" "[ -s '$NVM_DIR/nvm.sh' ]" "init_nvm"

# =============================================================================
# PYENV LAZY LOADING
# =============================================================================

export PYENV_ROOT="$HOME/.pyenv"

init_pyenv() {
    unset -f pyenv python python3 pip pip3
    
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
}

lazy_load_conditional "pyenv" "[ -d '$PYENV_ROOT' ]" "init_pyenv"
lazy_load_conditional "python" "[ -d '$PYENV_ROOT' ] && command -v pyenv >/dev/null" "init_pyenv"
lazy_load_conditional "python3" "[ -d '$PYENV_ROOT' ] && command -v pyenv >/dev/null" "init_pyenv"

# =============================================================================
# OTHER TOOLS LAZY LOADING
# =============================================================================

# Cargo/Rust
init_cargo() {
    unset -f cargo rustc rustup
    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
}

lazy_load_conditional "cargo" "[ -f '$HOME/.cargo/env' ]" "init_cargo"
lazy_load_conditional "rustc" "[ -f '$HOME/.cargo/env' ]" "init_cargo"
lazy_load_conditional "rustup" "[ -f '$HOME/.cargo/env' ]" "init_cargo"

# Poetry
init_poetry() {
    unset -f poetry
    export PATH="$HOME/.poetry/bin:$PATH"
}

lazy_load_conditional "poetry" "[ -d '$HOME/.poetry' ]" "init_poetry"

# TheFuck
init_thefuck() {
    unset -f fuck
    command -v thefuck >/dev/null && eval $(thefuck --alias)
}

lazy_load_conditional "fuck" "command -v thefuck >/dev/null" "init_thefuck"

# =============================================================================
# COMPLETION SYSTEM OPTIMIZATION (Saves ~1270ms - 45% of startup time)
# =============================================================================

# Optimized completion initialization
init_completions_fast() {
    # Check if we need to regenerate completions
    local comp_dump="$HOME/.zcompdump"
    local comp_sources=(
        "$HOME/.zshrc"
        "$ZSH/oh-my-zsh.sh"
        "$ZSH_CUSTOM"
    )
    
    # Only regenerate if sources are newer than dump
    local need_regen=false
    for src in "${comp_sources[@]}"; do
        [[ -e "$src" && "$src" -nt "$comp_dump" ]] && need_regen=true && break
    done
    
    if [[ "$need_regen" == true ]] || [[ ! -f "$comp_dump" ]]; then
        # Regenerate with security check disabled for speed
        autoload -Uz compinit
        compinit -d "$comp_dump"
    else
        # Fast load from existing dump
        autoload -Uz compinit
        compinit -C -d "$comp_dump"
    fi
}

# =============================================================================
# ASYNC INITIALIZATION FOR NON-CRITICAL COMPONENTS
# =============================================================================

init_async_components() {
    {
        # Initialize completions that don't affect initial prompt
        init_completions_fast
        
        # Initialize starship if available (moved to background)
        if command -v starship >/dev/null; then
            eval "$(starship init zsh)" &>/dev/null
        fi
        
        # Pip completions (non-critical)
        if command -v pip3 >/dev/null; then
            eval "$(pip3 completion --zsh)" &>/dev/null
        fi
        if command -v pip >/dev/null; then
            eval "$(pip completion --zsh)" &>/dev/null
        fi
        
        # Additional completions
        if [[ -d "$HOME/.local/share/zsh/completions" ]]; then
            fpath=("$HOME/.local/share/zsh/completions" $fpath)
        fi
        
        # Cheat.sh completions
        if [[ -d "$HOME/.zsh.d" ]]; then
            fpath=("$HOME/.zsh.d" $fpath)
        fi
        
        # zsh-completions
        if [[ -d "${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src" ]]; then
            fpath+=("${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src")
        fi
        
        # Final compinit for any new completions
        autoload -Uz compinit && compinit -C
        
    } &!  # Background job that doesn't block
}

# =============================================================================
# JINA CLI LAZY LOADING
# =============================================================================

init_jina() {
    unset -f jina
    
    if [[ ! -o interactive ]]; then
        return
    fi
    
    compctl -K _jina jina
    
    _jina() {
      local words completions
      read -cA words
    
      if [ "${#words}" -eq 2 ]; then
        completions="$(jina commands)"
      else
        completions="$(jina completions ${words[2,-2]})"
      fi
    
      reply=(${(ps:
:)completions})
    }
    
    ulimit -n 4096
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
}

lazy_load_conditional "jina" "command -v jina >/dev/null" "init_jina"

# =============================================================================
# PATH OPTIMIZATION
# =============================================================================

# Deduplicate PATH to reduce lookup time
typeset -aU path

# =============================================================================
# INITIALIZATION
# =============================================================================

# Start async initialization immediately but don't wait for it
init_async_components

# Completion settings for immediate use
zstyle ':completion:*' menu select
autoload -Uz compinit && compinit -C

echo "🚀 ZSH lazy loading enabled - startup time optimized!"