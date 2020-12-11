# ag-magic.zsh-theme

# settings
typeset +H return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"
typeset +H my_gray="$FG[237]"
typeset +H my_orange="$FG[214]"
typeset +H aws_orange="$FG[214]"
typeset +H tf_purple="$FG[098]"
typeset +H rst="%{$reset_color%}"

# separator dashes size
function afmagic_dashes {
  local offset=$(( COLUMNS - ${#USER} - ${#NAME} - 3 ))

	if [[ -n "$AWS_PROFILE" ]]; then
    offset=$(( $offset - ${#AWS_PROFILE} - 5 ))
	fi

  if [[ ! "$PWD" == ~ && -d .terraform ]]; then
    local workspace=$(terraform workspace show 2> /dev/null)
    offset=$(( $offset - ${#workspace} - 5 ))
  fi

  echo $offset
}

function tf_prompt_info() {
    # dont show 'default' workspace in home dir
    [[ "$PWD" == ~ ]] && return
    # check if in terraform dir
    if [ -d .terraform ]; then
      local workspace=$(terraform workspace show 2> /dev/null) || return
      echo "${tf_purple}tf[%{$reset_color%}${workspace}${tf_purple}]%{$reset_color%} "
    fi
}

function aws_key_age() {
	key_id=$(aws configure get aws_access_key_id)
	key_creation_date=$(aws iam list-access-keys --query="AccessKeyMetadata[?AccessKeyId =='$key_id'].CreateDate | [0]" | tr -d \")
	# start_date=$(date +%s -d"2020-09-25T18:12:01+00:00")
	start_date=$(date +%s -d$key_creation_date)
	current_date=$(date +%s)
	date_diff=$(( ($current_date - $start_date)/60/60/24 ))
	[[ date_diff -gt 25200 ]] && echo "$fg[red]Old access key detected!$reset_color Consider rotating your credentials."
	echo "$date_diff day$([[ date_diff -eq 1 ]] || echo 's') old"
}

function aws_profiles() {
  [[ -r "${AWS_CONFIG_FILE:-$HOME/.aws/config}" ]] || return 1
  grep '\[profile' "${AWS_CONFIG_FILE:-$HOME/.aws/config}"|sed -e 's/.*profile \([a-zA-Z0-9@_\.\:\/\-]*\).*/\1/'
  [[ -r "${AWS_CONFIG_FILE:-$HOME/.aws/credentials}" ]] && \
  grep '\[' "${AWS_CONFIG_FILE:-$HOME/.aws/credentials}"|sed -e 's/\[\([a-zA-Z0-9@_\.\:\/\-]*\).*/\1/'

}

function asp() {
  if [[ -z "$1" ]]; then
    unset AWS_DEFAULT_PROFILE AWS_PROFILE AWS_EB_PROFILE
    echo AWS profile cleared.
    return
  fi

  local -a available_profiles
  available_profiles=($(aws_profiles))
  if [[ -z "${available_profiles[(r)$1]}" ]]; then
    echo "${fg[red]}Profile '$1' not found in '${AWS_CONFIG_FILE:-$HOME/.aws/config}'" >&2
    echo "Available profiles: ${(j:, :)available_profiles:-no profiles found}${reset_color}" >&2
    return 1
  fi

  export AWS_DEFAULT_PROFILE=$1
  export AWS_PROFILE=$1
  export AWS_EB_PROFILE=$1
}

function _aws_profiles() {
  reply=($(aws_profiles))
}
compctl -K _aws_profiles asp aws_change_access_key


function aws_key_rotate() {
	local AWS_PAGER=""
	echo Reading current access key...
	old_key_id=$(aws configure get aws_access_key_id)
	echo "Old => $fg[blue]$old_key_id%{$reset_color%}"
    output=$(aws iam create-access-key || echo '')
	[[ -n $output ]] && echo "Creating new access key..." || ( echo "Failed to create new access key." && return 1 )
    new_key_id=$(echo $output | jq -r '.AccessKey.AccessKeyId')
    new_key_secret=$(echo $output | jq -r '.AccessKey.SecretAccessKey')
	echo "New => $fg[blue]$new_key_id\%{$reset_color%}"
	echo Updating the profile configuration...
    aws configure set aws_access_key_id $new_key_id
    aws configure set aws_secret_access_key $new_key_secret
	echo "Done!"
	return 0
}

function aws_key_clean() {
	local AWS_PAGER=""
	current_key_id=$(aws configure get aws_access_key_id) || ( echo "No current access key set." && return 1 )
	old_key_id=$(aws iam list-access-keys --query="AccessKeyMetadata[?AccessKeyId !='$current_key_id'].AccessKeyId | [0]" | tr -d \")
	[[ -n $old_key_id ]] && echo "Removing old key." || ( echo "No old keys found." && return 1 )
	AWS_PAGER="" aws iam delete-access-key --access-key-id $old_key_id
	echo "Done!"
	return 0
}

function aws_key_rollback() {
	local AWS_PAGER=""
	current_key_id=$(aws configure get aws_access_key_id)

    output=$(aws iam create-access-key || return)

    new_key_id=$(echo $output | jq -r '.AccessKey.AccessKeyId')
    new_key_secret=$(echo $output | jq -r '.AccessKey.SecretAccessKey')

    aws configure set aws_access_key_id $new_key_id
    aws configure set aws_secret_access_key $new_key_secret

    echo You can now safely delete the old access key running \`aws iam delete-access-key --access-key-id $current_key_id\`
    echo Your current keys are:
    aws iam list-access-keys
}

function aws_prompt_info() {
	[[ -z "$AWS_PROFILE" ]] && return

	if [[ $AWS_PROFILE == prod-* ]]
	then
		color="%{$fg[red]%}" 
	elif [[ $AWS_PROFILE == test-* ]]
	then
		color="%{$fg[green]%}"
	elif [[ $AWS_PROFILE == stage-* ]]
	then
		color="%{$fg[yellow]%}"
	else
		color="%{$reset_color%}"
	fi

	echo "${aws_orange}aws[${color}$AWS_PROFILE${aws_orange}]%{$reset_color%} "
}

# primary prompt
PS1='$FG[237]${(l.$(afmagic_dashes)..-.)} $(tf_prompt_info)$(aws_prompt_info)%F{yellow}%n@%m%{$reset_color%}
%F{blue}%B%c$(git_prompt_info) $FG[105]%(!.#.»)%{$reset_color%} '
PS2='%{$fg[red]%}\ %{$reset_color%}'
RPS1='${return_code}'

# git settings
ZSH_THEME_GIT_PROMPT_PREFIX=" %{$reset_color%}$FG[239][$FG[078]"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY="${aws_orange}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="$FG[239]]%{$reset_color%}"

ZSH_THEME_AWS_PREFIX="$FG[214]aws["
ZSH_THEME_AWS_SUFFIX="]%{$reset_color%}"


