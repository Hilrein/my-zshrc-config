# ==========================================================
#                    BLUEPRINT ZSH
#                native zsh / no plugins
# ==========================================================

setopt PROMPT_SUBST
zmodload zsh/datetime

# ----------------------------------------------------------
# Colors
# ----------------------------------------------------------

BP_RESET=$'\e[0m'

BP_CYAN=$'\e[36m'
BP_BLUE=$'\e[34m'
BP_WHITE=$'\e[38;5;255m'
BP_GRAY=$'\e[38;5;244m'
BP_GREEN=$'\e[32m'
BP_RED=$'\e[31m'
BP_YELLOW=$'\e[33m'
BP_MAGENTA=$'\e[35m'

# ----------------------------------------------------------
# Runtime state
# ----------------------------------------------------------

BP_EXIT=0
BP_START=0
BP_DURATION=""

# ----------------------------------------------------------
# Helpers
# ----------------------------------------------------------

bp_separator() {
    printf '%s\n' "${BP_GRAY}│${BP_RESET}"
}

# ----------------------------------------------------------
# Git
# ----------------------------------------------------------

bp_git() {

    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

    local branch
    local git_status
    local staged=0
    local modified=0
    local untracked=0
    local ahead=0
    local behind=0
    local details=""
    local sync=""
    local state=""

    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)

    [[ -z "$branch" ]] &&
        branch=$(git rev-parse --short HEAD 2>/dev/null)

    git_status=$(git status --porcelain=v1 2>/dev/null)

    while IFS= read -r line; do

        [[ -z "$line" ]] && continue

        local index="${line[1]}"
        local worktree="${line[2]}"

        if [[ "$index" == "?" ]]; then
            ((untracked++))
        else
            [[ "$index" != " " ]] && ((staged++))
            [[ "$worktree" != " " ]] && ((modified++))
        fi

    done <<< "$git_status"

    if [[ -n "$git_status" ]]; then

        state="${BP_RED}✗${BP_RESET}"

        (( staged > 0 )) &&
            details+=" ${BP_GREEN}+${staged}${BP_RESET}"

        (( modified > 0 )) &&
            details+=" ${BP_YELLOW}~${modified}${BP_RESET}"

        (( untracked > 0 )) &&
            details+=" ${BP_GRAY}?${untracked}${BP_RESET}"

    else

        state="${BP_GREEN}✓${BP_RESET}"

    fi

    if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then

        ahead=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
        behind=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)

        (( ahead > 0 )) &&
            sync+=" ${BP_GREEN}↑${ahead}${BP_RESET}"

        (( behind > 0 )) &&
            sync+=" ${BP_RED}↓${behind}${BP_RESET}"

    fi

    printf '%s\n' \
        "${BP_MAGENTA}git:${BP_RESET}${branch} ${state}${details}${sync}"
}

# ----------------------------------------------------------
# Node.js
# ----------------------------------------------------------

bp_node() {

    [[ -f package.json ]] || return
    command -v node >/dev/null 2>&1 || return

    local version
    version=$(node -v 2>/dev/null | sed 's/^v//')

    printf '%s\n' \
        "${BP_GREEN}node:${BP_RESET}${version}"
}

# ----------------------------------------------------------
# Python
# ----------------------------------------------------------

bp_python() {

    [[ -f pyproject.toml ||
       -f requirements.txt ||
       -f requirements-dev.txt ||
       -f setup.py ||
       -f manage.py ||
       -f .python-version ]] || return

    command -v python3 >/dev/null 2>&1 || return

    local version
    version=$(python3 --version 2>/dev/null | awk '{print $2}')

    printf '%s\n' \
        "${BP_YELLOW}python:${BP_RESET}${version}"
}

# ----------------------------------------------------------
# Python virtual environment
# ----------------------------------------------------------

bp_venv() {

    [[ -n "$VIRTUAL_ENV" ]] || return

    printf '%s\n' \
        "${BP_BLUE}venv:${BP_RESET}$(basename "$VIRTUAL_ENV")"
}

# ----------------------------------------------------------
# Dart
# ----------------------------------------------------------

bp_dart() {

    [[ -f pubspec.yaml ]] || return
    command -v dart >/dev/null 2>&1 || return

    local version
    version=$(dart --version 2>&1 | awk '{print $4}')

    [[ -n "$version" ]] &&
        printf '%s\n' \
            "${BP_CYAN}dart:${BP_RESET}${version}"
}

# ----------------------------------------------------------
# Flutter
# ----------------------------------------------------------

bp_flutter() {

    [[ -f pubspec.yaml ]] || return
    command -v flutter >/dev/null 2>&1 || return

    grep -qE '^[[:space:]]*flutter:' pubspec.yaml 2>/dev/null || return

    local version
    version=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')

    [[ -n "$version" ]] &&
        printf '%s\n' \
            "${BP_CYAN}flutter:${BP_RESET}${version}"
}

# ----------------------------------------------------------
# Rust
# ----------------------------------------------------------

bp_rust() {

    [[ -f Cargo.toml ]] || return
    command -v rustc >/dev/null 2>&1 || return

    local version
    version=$(rustc --version 2>/dev/null | awk '{print $2}')

    printf '%s\n' \
        "${BP_RED}rust:${BP_RESET}${version}"
}

# ----------------------------------------------------------
# Go
# ----------------------------------------------------------

bp_go() {

    [[ -f go.mod ]] || return
    command -v go >/dev/null 2>&1 || return

    local version
    version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')

    printf '%s\n' \
        "${BP_CYAN}go:${BP_RESET}${version}"
}

# ----------------------------------------------------------
# Docker
# ----------------------------------------------------------

bp_docker() {

    [[ -f Dockerfile ||
       -f docker-compose.yml ||
       -f docker-compose.yaml ||
       -f compose.yml ||
       -f compose.yaml ]] || return

    command -v docker >/dev/null 2>&1 || return

    printf '%s\n' "${BP_BLUE}docker${BP_RESET}"
}

# ----------------------------------------------------------
# Command start
# ----------------------------------------------------------

bp_preexec() {
    BP_START=$EPOCHREALTIME
}

# ----------------------------------------------------------
# Prompt
# ----------------------------------------------------------

bp_precmd() {

    local last_exit=$?

    BP_EXIT=$last_exit

    # ------------------------------------------------------
    # Duration
    # ------------------------------------------------------

    if (( BP_START > 0 )); then

        local -F 6 elapsed
        elapsed=$(( EPOCHREALTIME - BP_START ))

        if (( elapsed >= 1.0 )); then
            BP_DURATION=$(printf "%.1fs" "$elapsed")
        else
            BP_DURATION=""
        fi

    else

        BP_DURATION=""

    fi

    BP_START=0

    # ------------------------------------------------------
    # Header
    # ------------------------------------------------------

    local header

    header="${BP_GRAY}┌─${BP_RESET} "
    header+="${BP_CYAN}%n${BP_RESET}@${BP_BLUE}%m${BP_RESET} "
    header+="${BP_WHITE}%~${BP_RESET}"

    # ------------------------------------------------------
    # Context
    # ------------------------------------------------------

    local context=""
    local item

    item=$(bp_git)
    [[ -n "$item" ]] &&
        context+="${item}"

    item=$(bp_node)
    [[ -n "$item" ]] &&
        context+=" ${BP_GRAY}│${BP_RESET} ${item}"

    item=$(bp_python)
    [[ -n "$item" ]] &&
        context+=" ${BP_GRAY}│${BP_RESET} ${item}"

    item=$(bp_venv)
    [[ -n "$item" ]] &&
        context+=" ${BP_GRAY}│${BP_RESET} ${item}"

    item=$(bp_flutter)

    if [[ -n "$item" ]]; then

        context+=" ${BP_GRAY}│${BP_RESET} ${item}"

        item=$(bp_dart)

        [[ -n "$item" ]] &&
            context+=" ${BP_GRAY}│${BP_RESET} ${item}"

    else

        item=$(bp_dart)

        [[ -n "$item" ]] &&
            context+=" ${BP_GRAY}│${BP_RESET} ${item}"

    fi

    item=$(bp_rust)
    [[ -n "$item" ]] &&
        context+=" ${BP_GRAY}│${BP_RESET} ${item}"

    item=$(bp_go)
    [[ -n "$item" ]] &&
        context+=" ${BP_GRAY}│${BP_RESET} ${item}"

    item=$(bp_docker)
    [[ -n "$item" ]] &&
        context+=" ${BP_GRAY}│${BP_RESET} ${item}"

    # ------------------------------------------------------
    # Time
    # ------------------------------------------------------

    context+=" ${BP_GRAY}│${BP_RESET} ${BP_GRAY}$(date '+%H:%M')${BP_RESET}"

    # ------------------------------------------------------
    # Bottom
    # ------------------------------------------------------

    local bottom="${BP_GRAY}└─${BP_RESET}"

    if (( BP_EXIT != 0 )); then
        bottom+=" ${BP_RED}✗${BP_EXIT}${BP_RESET}"
    fi

    if [[ -n "$BP_DURATION" ]]; then
        bottom+=" ${BP_YELLOW}${BP_DURATION}${BP_RESET}"
    fi

    bottom+=" ${BP_GREEN}❯${BP_RESET} "

    # ------------------------------------------------------
    # Final
    # ------------------------------------------------------

    if [[ -n "$context" ]]; then

        PROMPT="${header}
${BP_GRAY}│${BP_RESET} ${context}
${bottom}"

    else

        PROMPT="${header}
${bottom}"

    fi
}

# ----------------------------------------------------------
# Hooks
# ----------------------------------------------------------

preexec_functions+=(bp_preexec)
precmd_functions+=(bp_precmd)













# Add command: furinahelp
# ==========================================================
#                     FURINA HELP
# ==========================================================

furinahelp() {

    case "$1" in

        git)

            echo ""
            echo "╭────────────────────────────────────────────────────╮"
            echo "│                     FURINA GIT                     │"
            echo "╰────────────────────────────────────────────────────╯"
            echo ""

            # ------------------------------------------------
            # Current repository
            # ------------------------------------------------

            if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then

                local repo
                local branch
                local git_status

                local staged=0
                local modified=0
                local untracked=0
                local ahead=0
                local behind=0

                repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
                branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)

                [[ -z "$branch" ]] &&
                    branch=$(git rev-parse --short HEAD 2>/dev/null)

                git_status=$(git status --porcelain=v1 2>/dev/null)

                while IFS= read -r line; do

                    [[ -z "$line" ]] && continue

                    local index="${line[1]}"
                    local worktree="${line[2]}"

                    if [[ "$index" == "?" ]]; then
                        ((untracked++))
                    else
                        [[ "$index" != " " ]] && ((staged++))
                        [[ "$worktree" != " " ]] && ((modified++))
                    fi

                done <<< "$git_status"

                if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
                    ahead=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
                    behind=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
                fi

                echo "  Current repository"
                echo ""
                echo "    Repository   ${repo}"
                echo "    Branch       ${branch}"

                if [[ -n "$git_status" ]]; then
                    echo "    Status       ${BP_RED}dirty ✗${BP_RESET}"
                else
                    echo "    Status       ${BP_GREEN}clean ✓${BP_RESET}"
                fi

                echo "    Staged       ${staged}"
                echo "    Modified     ${modified}"
                echo "    Untracked    ${untracked}"
                echo "    Ahead        ${ahead}"
                echo "    Behind       ${behind}"

                echo ""

            else

                echo "  ${BP_YELLOW}You are not inside a Git repository.${BP_RESET}"
                echo ""

            fi

            # ------------------------------------------------
            # Legend
            # ------------------------------------------------

            echo "  Legend"
            echo ""
            echo "    ${BP_GREEN}✓${BP_RESET}          clean working tree"
            echo "    ${BP_RED}✗${BP_RESET}          uncommitted changes"
            echo ""
            echo "    ${BP_GREEN}+N${BP_RESET}         staged files"
            echo "    ${BP_YELLOW}~N${BP_RESET}         modified files"
            echo "    ${BP_GRAY}?N${BP_RESET}         untracked files"
            echo ""
            echo "    ${BP_GREEN}↑N${BP_RESET}         commits ahead of remote"
            echo "    ${BP_RED}↓N${BP_RESET}         commits behind remote"
            echo ""

            # ------------------------------------------------
            # Commands
            # ------------------------------------------------

            echo "  Useful commands"
            echo ""
            echo "    git status"
            echo "    git add ."
            echo '    git commit -m "message"'
            echo "    git push"
            echo "    git pull"
            echo ""

            ;;

        prompt)

            echo ""
            echo "╭────────────────────────────────────────────────────╮"
            echo "│                    FURINA PROMPT                   │"
            echo "╰────────────────────────────────────────────────────╯"
            echo ""

            echo "  Prompt"
            echo ""
            echo "    ❯          normal prompt"
            echo "    ✗N         previous command exit code"
            echo "    Ns         previous command duration"
            echo ""

            echo "  Git"
            echo ""
            echo "    git:main ✓"
            echo "    git:main ✗ +2 ~3 ?1 ↑1"
            echo ""

            echo "  Project detection"
            echo ""
            echo "    Node.js"
            echo "    Python"
            echo "    Python venv"
            echo "    Dart"
            echo "    Flutter"
            echo "    Rust"
            echo "    Go"
            echo "    Docker"
            echo ""

            echo "  The prompt only shows project-specific"
            echo "  runtimes when it detects them."
            echo ""

            ;;

        project)

            echo ""
            echo "╭────────────────────────────────────────────────────╮"
            echo "│                   FURINA PROJECT                  │"
            echo "╰────────────────────────────────────────────────────╯"
            echo ""

            local found=0

            if [[ -f package.json ]]; then
                echo "    Node.js       detected"
                ((found++))
            fi

            if [[ -f pyproject.toml ||
                  -f requirements.txt ||
                  -f requirements-dev.txt ||
                  -f setup.py ||
                  -f manage.py ||
                  -f .python-version ]]; then
                echo "    Python        detected"
                ((found++))
            fi

            if [[ -f pubspec.yaml ]]; then
                echo "    Dart          detected"

                if grep -qE '^[[:space:]]*flutter:' pubspec.yaml 2>/dev/null; then
                    echo "    Flutter       detected"
                fi

                ((found++))
            fi

            if [[ -f Cargo.toml ]]; then
                echo "    Rust          detected"
                ((found++))
            fi

            if [[ -f go.mod ]]; then
                echo "    Go            detected"
                ((found++))
            fi

            if [[ -f Dockerfile ||
                  -f docker-compose.yml ||
                  -f docker-compose.yaml ||
                  -f compose.yml ||
                  -f compose.yaml ]]; then
                echo "    Docker         detected"
                ((found++))
            fi

            echo ""

            if (( found == 0 )); then
                echo "    No known project environment detected."
            fi

            echo ""

            ;;

        *)

            echo ""
            echo "╭────────────────────────────────────────────────────╮"
            echo "│                    FURINA HELP                    │"
            echo "╰────────────────────────────────────────────────────╯"
            echo ""
            echo "  Commands"
            echo ""
            echo "    furinahelp          general help"
            echo "    furinahelp git      Git status & indicators"
            echo "    furinahelp prompt   prompt documentation"
            echo "    furinahelp project  detected project environment"
            echo ""

            echo "  Git indicators"
            echo ""
            echo "    ✓        clean"
            echo "    ✗        uncommitted changes"
            echo "    +N       staged"
            echo "    ~N       modified"
            echo "    ?N       untracked"
            echo "    ↑N       ahead"
            echo "    ↓N       behind"
            echo ""

            echo "  Examples"
            echo ""
            echo "    furinahelp git"
            echo "    furinahelp prompt"
            echo "    furinahelp project"
            echo ""

            ;;

    esac
}