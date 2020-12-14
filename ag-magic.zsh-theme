# ag-magic.zsh-theme

# settings
typeset +H return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"
typeset +H my_gray="%F{237}"
typeset +H my_orange="%F{214}"
typeset +H aws="%F{214}"
typeset +H tf_purple="%F{098}"
typeset +H rst="%{$reset_color%}"

function tf_prompt_info() {
    # dont show 'default' workspace in home dir
    [[ "$PWD" == ~ ]] && return
    # check if in terraform dir
    if [ -d .terraform ]; then
      local workspace=$(terraform workspace show 2> /dev/null) || return
	  _build_profile "%F{098}" "tf" "$workspace" "" " "
    fi
}

function aws_prompt_info() {
	[[ -z "$AWS_PROFILE" ]] && return
	_build_profile "%F{214}" "aws" "$AWS_PROFILE" "" " "
}

function _tf_workspace() {
	# dont show 'default' workspace in home dir
    [[ "$PWD" == ~ ]] && return
    # check if in terraform dir
    if [ -d .terraform ]; then
      local workspace=$(terraform workspace show 2> /dev/null) || return
	  _build_profile "%F{098}" "tf" "$workspace" "" " "
    fi
}
function _tf_workspace_len() {
	[[ "$PWD" == ~ ]] && echo "$((0))" && return;
    # check if in terraform dir
    if [ -d .terraform ]; then
		local workspace=$(terraform workspace show 2> /dev/null) || return
	  echo "$(( ${#workspace} + 5 ))"
	else
		echo "$((0))"
	fi
}

function _aws_profile() {
	[[ -z "$AWS_PROFILE" ]] && return
	_build_profile "%F{214}" "aws" "$AWS_PROFILE" "" " "
}

function _aws_profile_len() {
	if [[ -z "$AWS_PROFILE" ]]; then
		echo "$((0))"
	else
		echo "$(( ${#AWS_PROFILE} + 6 ))"
	fi
}

function _build_profile() {
	local color=$1
	local name=$2
	local value=$3
	local left_pad=$4
	local right_pad=$5

	echo "${left_pad}${color}${name}[%{$reset_color%}${value}${color}]%{$reset_color%}${right_pad}"
}

function _build_profile_segment() {
	echo "$(tf_prompt_info)$(aws_prompt_info)%F{yellow}%n@%m%{$reset_color%}"
}

function _build_first_line() {
	local l="┌"
	local r="┐"
	local h="─"
	local v="│"

	local profile_segment="$(_build_profile_segment)"
	local profile_segment_len="$(( $(_aws_profile_len) + $(_tf_workspace_len) + ${#NAME} + ${#USER}))"
	[[ "$TERM_PROGRAM" == "vscode" ]] && local wonkey="11" || wonkey="6"
	local count=$(( COLUMNS - ${profile_segment_len} - ${wonkey} ))
	echo "%F{237}${(l.${count}..─.)}%{$reset_color%} ${profile_segment} "
}

function _build_second_line() {
	echo "%F{blue}%B%c$(git_prompt_info) %F{105}%(!.#.»)%{$reset_color%} "
}

function _build_prompt_segment_1() {
	echo "%F{237}┌%{$reset_color%}$(_build_first_line)%F{237}┐%{$reset_color%}
%F{237}└┤%{$bg[grey]%} $(_build_second_line)"
}
# primary prompt
PS1='$(_build_prompt_segment_1)'


PS2='%{$fg[red]%} %{$reset_color%}'
RPS1='${return_code} %F{237}┘'

# git settings
ZSH_THEME_GIT_PROMPT_PREFIX=" %{$reset_color%}%F{239}[%F{078}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY="${aws_orange}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%F{239}]%{$reset_color%}"
