# -*- mode: sh; -*-

# Dracula Theme v1.2.5
#
# https://github.com/dracula/dracula-theme
#
# Copyright 2019, All rights reserved
#
# Code licensed under the MIT license
# http://zenorocha.mit-license.org
#
# @author Zeno Rocha <hi@zenorocha.com>
# @maintainer Aidan Williams <aidanwillie0317@protonmail.com>

# Initialization {{{
source ${0:A:h}/lib/async.zsh
autoload -Uz add-zsh-hook
setopt PROMPT_SUBST
async_init
# }}}

# Options {{{
# Set to 1 to show the date
DRACULA_DISPLAY_TIME=${DRACULA_DISPLAY_TIME:-0}

# Set to 1 to show the 'context' segment
DRACULA_DISPLAY_CONTEXT=${DRACULA_DISPLAY_CONTEXT:-0}

# Changes the arrow icon
DRACULA_ARROW_ICON=${DRACULA_ARROW_ICON:-➜ }

# function to detect if git has support for --no-optional-locks
dracula_test_git_optional_lock() {
  local git_version=${DEBUG_OVERRIDE_V:-"$(git version | cut -d' ' -f3)"}
  local git_version="$(git version | cut -d' ' -f3)"
  # test for git versions < 2.14.0
  case "$git_version" in
    [0-1].*)
      echo 0
      return 1
      ;;
    2.[0-9].*)
      echo 0
      return 1
      ;;
    2.1[0-3].*)
      echo 0
      return 1
      ;;
  esac

  # if version > 2.14.0 return true
  echo 1
}

# use --no-optional-locks flag on git
DRACULA_GIT_NOLOCK=${DRACULA_GIT_NOLOCK:-$(dracula_test_git_optional_lock)}
# }}}
RPS1=''
PS1=''

# Async terraform segment {{{
dracula_aws_status() {
  cd "$1"
  
  local workspace
  if [[ ! -z "$AWS_PROFILE" ]]; then
    echo -n "${ZSH_THEME_AWS_PROMPT_PREFIX}${AWS_PROFILE}${ZSH_THEME_AWS_PROMPT_SUFFIX}"
  fi
}

dracula_aws_callback() {
  DRACULA_AWS_STATUS="$3"
  if [[ -z "$3" ]]; then
    DRACULA_AWS_STATUS_LEN="0"
    else
    DRACULA_AWS_STATUS_LEN=$(( $(echo -n "$3" | wc -m) - ZSH_THEME_AWS_PROMPT_OFFSET ))
  fi
  zle && zle reset-prompt
  async_stop_worker dracula_aws_worker dracula_aws_status "$(pwd)"
}

dracula_aws_async() {
  async_start_worker dracula_aws_worker -n
  async_register_callback dracula_aws_worker dracula_aws_callback
  async_job dracula_aws_worker dracula_aws_status "$(pwd)"
}

RPS1+='$DRACULA_AWS_STATUS'
ZSH_THEME_AWS_PROMPT_PREFIX=" %F{214}%Baws[%f%b"
ZSH_THEME_AWS_PROMPT_SUFFIX="%F{214}] "
ZSH_THEME_AWS_PROMPT_OFFSET="27"
# }}}

# Async terraform segment {{{
dracula_tf_status() {
  cd "$1"
  
  local workspace
  
  workspace=$(=terraform workspace show 2>/tmp/tf-errors)
  if [[ -n $workspace ]]; then
    if [[ "$workspace" != "default" ]]; then
        echo -n "${ZSH_THEME_TF_PROMPT_PREFIX}${workspace}${ZSH_THEME_TF_PROMPT_SUFFIX}"
    fi
  fi
}

dracula_tf_callback() {
  DRACULA_TF_STATUS="$3"
  if [[ -z "$3" ]]; then
    DRACULA_TF_STATUS_LEN="0"
    else
    DRACULA_TF_STATUS_LEN=$(( $(echo -n "$3" | wc -m) - ZSH_THEME_TF_PROMPT_OFFSET ))
  fi
  zle && zle reset-prompt
  async_stop_worker dracula_tf_worker dracula_tf_status "$(pwd)"
}

dracula_tf_async() {
  async_start_worker dracula_tf_worker -n
  async_register_callback dracula_tf_worker dracula_tf_callback
  async_job dracula_tf_worker dracula_tf_status "$(pwd)"
}
RPS1+='$DRACULA_TF_STATUS'
ZSH_THEME_TF_PROMPT_PREFIX=" %F{098}%Btf[%f%b"
ZSH_THEME_TF_PROMPT_SUFFIX="%F{098}]"
ZSH_THEME_TF_PROMPT_OFFSET="27"
# }}}

# # PROMPT+='─%.s' {1..$(tput cols)}
# PS1+='%F{237}${(l.$((COLUMNS - 3 - DRACULA_AWS_STATUS_LEN - DRACULA_TF_STATUS_LEN))..─.)}┐%f
# '

# Status segment {{{
# arrow is green if last command was successful, red if not, 
# turns yellow in vi command mode
PS1+='%(1V:%F{yellow}:%(?:%F{green}:%F{red}))${DRACULA_ARROW_ICON}'
# }}}

# Time segment {{{
dracula_time_segment() {
  if (( DRACULA_DISPLAY_TIME )); then
    if [[ -z "$TIME_FORMAT" ]]; then
      TIME_FORMAT="%k:M"
      
      # check if locale uses AM and PM
      if ! locale -ck LC_TIME | grep 'am_pm=";"'; then
        TIME_FORMAT="%l:%M%p"
      fi
    fi

    print -P "%D{$TIME_FORMAT}"
  fi
}

PS1+='%F{green}%B$(dracula_time_segment) '
# }}}

# User context segment {{{
dracula_context() {
  if (( DRACULA_DISPLAY_CONTEXT )); then
    if [[ -n "${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-}" ]] || (( EUID == 0 )); then
      echo '%n@%m '
    else
      echo '%n '
    fi
  fi
}

PS1+='%F{magenta}%B$(dracula_context)'
# }}}

# Directory segment {{{
PS1+='%F{blue}%B%c '
# }}}

# Async git segment {{{

dracula_git_status() {
  cd "$1"
  
  local ref branch lockflag
  
  (( DRACULA_GIT_NOLOCK )) && lockflag="--no-optional-locks"

  ref=$(=git $lockflag symbolic-ref --quiet HEAD 2>/tmp/git-errors)

  case $? in
    0)   ;;
    128) return ;;
    *)   ref=$(=git $lockflag rev-parse --short HEAD 2>/tmp/git-errors) || return ;;
  esac

  branch=${ref#refs/heads/}
  
  if [[ -n $branch ]]; then
    echo -n "${ZSH_THEME_GIT_PROMPT_PREFIX}${branch}"

    local git_status icon
    git_status="$(LC_ALL=C =git $lockflag status 2>&1)"
    
    if [[ "$git_status" =~ 'new file:|deleted:|modified:|renamed:|Untracked files:' ]]; then
      echo -n "$ZSH_THEME_GIT_PROMPT_DIRTY"
    else
      echo -n "$ZSH_THEME_GIT_PROMPT_CLEAN"
    fi

    echo -n "$ZSH_THEME_GIT_PROMPT_SUFFIX"
  fi
}

dracula_git_callback() {
  DRACULA_GIT_STATUS="$3"
  zle && zle reset-prompt
  async_stop_worker dracula_git_worker dracula_git_status "$(pwd)"
}

dracula_git_async() {
  async_start_worker dracula_git_worker -n
  async_register_callback dracula_git_worker dracula_git_callback
  async_job dracula_git_worker dracula_git_status "$(pwd)"
}

PS1+='$DRACULA_GIT_STATUS'


ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY="%F{yellow}*"
ZSH_THEME_GIT_PROMPT_PREFIX="%F{cyan}(%f%b"
ZSH_THEME_GIT_PROMPT_SUFFIX="%F{cyan})%f%b "

# }}}

precmd() {
  dracula_git_async
  dracula_aws_async
  dracula_tf_async
}

ZLE_RPROMPT_INDENT=0

# ensure vi mode is handled by prompt
function zle-keymap-select zle-line-init {
  if [[ $KEYMAP = vicmd ]]; then
    psvar[1]=vicmd
  else
    psvar[1]=''
  fi

  zle reset-prompt
  zle -R
}

zle -N zle-line-init
zle -N zle-keymap-select

# Ensure effects are reset
PROMPT+='%f%b'

