# Pure
# https://github.com/ivan-volnov/pure
# MIT License

# For my own and others sanity
# git:
# %b => current branch
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on the current line
# \e[2K => clear everything on the current line


# Turns seconds into human readable time.
# 165392 => 1d 21h 56m 32s
prompt_pure_human_time_to_var() {
	local human total_seconds=$1 var=$2
	local days=$(( total_seconds / 60 / 60 / 24 ))
	local hours=$(( total_seconds / 60 / 60 % 24 ))
	local minutes=$(( total_seconds / 60 % 60 ))
	local seconds=$(( total_seconds % 60 ))
	(( days > 0 )) && human+="${days}d "
	(( hours > 0 )) && human+="${hours}h "
	(( minutes > 0 )) && human+="${minutes}m "
	human+="${seconds}s"

	# Store human readable time in a variable as specified by the caller
	typeset -g "${var}"="${human}"
}

# Stores (into prompt_pure_cmd_exec_time) the execution
# time of the last command if set threshold was exceeded.
prompt_pure_check_cmd_exec_time() {
	integer elapsed
	(( elapsed = EPOCHSECONDS - ${prompt_pure_cmd_timestamp:-$EPOCHSECONDS} ))
	typeset -g prompt_pure_cmd_exec_time=
	(( elapsed > ${PURE_CMD_MAX_EXEC_TIME:-5} )) && {
		prompt_pure_human_time_to_var $elapsed "prompt_pure_cmd_exec_time"
	}
}

prompt_pure_set_title() {
	setopt localoptions noshwordsplit

	# Emacs terminal does not support settings the title.
	(( ${+EMACS} || ${+INSIDE_EMACS} )) && return

	case $TTY in
		# Don't set title over serial console.
		/dev/ttyS[0-9]*) return;;
	esac

	# Show hostname if connected via SSH.
	local hostname=
	if [[ -n $prompt_pure_state[username] ]]; then
		# Expand in-place in case ignore-escape is used.
		hostname="${(%):-(%m) }"
	fi

	local -a opts
	case $1 in
		expand-prompt) opts=(-P);;
		ignore-escape) opts=(-r);;
	esac

	# Set title atomically in one print statement so that it works when XTRACE is enabled.
	print -n $opts $'\e]0;'${hostname}${2}$'\a'
}

prompt_pure_preexec() {
	typeset -g prompt_pure_cmd_timestamp=$EPOCHSECONDS

	# Shows the current directory and executed command in the title while a process is active.
	prompt_pure_set_title 'ignore-escape' "$PWD:t: $2"

	# Disallow Python virtualenv from updating the prompt. Set it to 12 if
	# untouched by the user to indicate that Pure modified it. Here we use
	# the magic number 12, same as in `psvar`.
	export VIRTUAL_ENV_DISABLE_PROMPT=${VIRTUAL_ENV_DISABLE_PROMPT:-12}
}

prompt_pure_preprompt_render() {
	setopt localoptions noshwordsplit

	# Initialize the preprompt array.
	local -a preprompt_parts

	# Suspended jobs in background.
	if ((${(M)#jobstates:#suspended:*} != 0)); then
		preprompt_parts+='%F{$prompt_pure_colors[suspended_jobs]}✦'
	fi

	# Username and machine, if applicable.
	[[ -n $prompt_pure_state[username] ]] && preprompt_parts+=($prompt_pure_state[username])

	# Set the path.
	preprompt_parts+=('%F{${prompt_pure_colors[path]}}%~%f')

	# Git branch status info.
    preprompt_parts+=("%F{$prompt_pure_colors[git:branch]}"'${vcs_info_msg_0_//\%/%%}''%f')

	# Execution time.
	[[ -n $prompt_pure_cmd_exec_time ]] && preprompt_parts+=('%F{$prompt_pure_colors[execution_time]}${prompt_pure_cmd_exec_time}%f')

	local cleaned_ps1=$PROMPT
	local -H MATCH MBEGIN MEND
	if [[ $PROMPT = *$prompt_newline* ]]; then
		# Remove everything from the prompt until the newline. This
		# removes the preprompt and only the original PROMPT remains.
		cleaned_ps1=${PROMPT##*${prompt_newline}}
	fi
	unset MATCH MBEGIN MEND

	# Construct the new prompt with a clean preprompt.
	local -ah ps1
	ps1=(
		${(j. .)preprompt_parts}  # Join parts, space separated.
		$prompt_newline           # Separate preprompt and prompt.
		$cleaned_ps1
	)

	PROMPT="${(j..)ps1}"

	# Expand the prompt for future comparision.
	local expanded_prompt
	expanded_prompt="${(S%%)PROMPT}"

	if [[ $1 == precmd ]]; then
		# Initial newline, for spaciousness.
		print
	elif [[ $prompt_pure_last_prompt != $expanded_prompt ]]; then
		# Redraw the prompt.
		prompt_pure_reset_prompt
	fi

	typeset -g prompt_pure_last_prompt=$expanded_prompt
}

prompt_pure_precmd() {
	setopt localoptions noshwordsplit

	# Check execution time and store it in a variable.
	prompt_pure_check_cmd_exec_time
	unset prompt_pure_cmd_timestamp

	# Shows the full path in the title.
	prompt_pure_set_title 'expand-prompt' '%~'

	# Configure `vcs_info`. This frees up `vcs_info`
	# to be used or configured as the user pleases.
	zstyle ':vcs_info:*' enable git
	zstyle ':vcs_info:*' use-simple true
	# Only export four message variables from `vcs_info`.
	zstyle ':vcs_info:*' max-exports 1
	# Export branch (%b)
	zstyle ':vcs_info:git*' formats '%b'
	zstyle ':vcs_info:git*' actionformats '%b'

	vcs_info

	# Check if we should display the virtual env. We use a sufficiently high
	# index of psvar (12) here to avoid collisions with user defined entries.
	psvar[12]=
	# Check if a Conda environment is active and display its name.
	if [[ -n $CONDA_DEFAULT_ENV ]]; then
		psvar[12]="${CONDA_DEFAULT_ENV//[$'\t\r\n']}"
	fi
	# When VIRTUAL_ENV_DISABLE_PROMPT is empty, it was unset by the user and
	# Pure should take back control.
	if [[ -n $VIRTUAL_ENV ]] && [[ -z $VIRTUAL_ENV_DISABLE_PROMPT || $VIRTUAL_ENV_DISABLE_PROMPT = 12 ]]; then
		psvar[12]="${VIRTUAL_ENV:t}"
		export VIRTUAL_ENV_DISABLE_PROMPT=12
	fi

	# Make sure VIM prompt is reset.
	prompt_pure_reset_prompt_symbol

	# Print the preprompt.
	prompt_pure_preprompt_render "precmd"

	if [[ -n $ZSH_THEME ]]; then
		print "WARNING: Oh My Zsh themes are enabled (ZSH_THEME='${ZSH_THEME}'). Pure might not be working correctly."
		unset ZSH_THEME  # Only show this warning once.
	fi
}

prompt_pure_reset_prompt() {
	if [[ $CONTEXT == cont ]]; then
		# When the context is "cont", PS2 is active and calling
		# reset-prompt will have no effect on PS1, but it will
		# reset the execution context (%_) of PS2 which we don't
		# want. Unfortunately, we can't save the output of "%_"
		# either because it is only ever rendered as part of the
		# prompt, expanding in-place won't work.
		return
	fi

	zle && zle .reset-prompt
}

prompt_pure_reset_prompt_symbol() {
	prompt_pure_state[prompt]=${PURE_PROMPT_SYMBOL:-❯}
}

prompt_pure_update_vim_prompt_widget() {
	setopt localoptions noshwordsplit
	prompt_pure_state[prompt]=${${KEYMAP/vicmd/${PURE_PROMPT_VICMD_SYMBOL:-❮}}/(main|viins)/${PURE_PROMPT_SYMBOL:-❯}}

	prompt_pure_reset_prompt
}

prompt_pure_reset_vim_prompt_widget() {
	setopt localoptions noshwordsplit
	prompt_pure_reset_prompt_symbol

	# We can't perform a prompt reset at this point because it
	# removes the prompt marks inserted by macOS Terminal.
}

prompt_pure_state_setup() {
	setopt localoptions noshwordsplit

	# Check SSH_CONNECTION and the current state.
	local ssh_connection=${SSH_CONNECTION:-$PROMPT_PURE_SSH_CONNECTION}
	local username hostname
	if [[ -z $ssh_connection ]] && (( $+commands[who] )); then
		# When changing user on a remote system, the $SSH_CONNECTION
		# environment variable can be lost. Attempt detection via `who`.
		local who_out
		who_out=$(who -m 2>/dev/null)
		if (( $? )); then
			# Who am I not supported, fallback to plain who.
			local -a who_in
			who_in=( ${(f)"$(who 2>/dev/null)"} )
			who_out="${(M)who_in:#*[[:space:]]${TTY#/dev/}[[:space:]]*}"
		fi

		local reIPv6='(([0-9a-fA-F]+:)|:){2,}[0-9a-fA-F]+'  # Simplified, only checks partial pattern.
		local reIPv4='([0-9]{1,3}\.){3}[0-9]+'   # Simplified, allows invalid ranges.
		# Here we assume two non-consecutive periods represents a
		# hostname. This matches `foo.bar.baz`, but not `foo.bar`.
		local reHostname='([.][^. ]+){2}'

		# Usually the remote address is surrounded by parenthesis, but
		# not on all systems (e.g. busybox).
		local -H MATCH MBEGIN MEND
		if [[ $who_out =~ "\(?($reIPv4|$reIPv6|$reHostname)\)?\$" ]]; then
			ssh_connection=$MATCH

			# Export variable to allow detection propagation inside
			# shells spawned by this one (e.g. tmux does not always
			# inherit the same tty, which breaks detection).
			export PROMPT_PURE_SSH_CONNECTION=$ssh_connection
		fi
		unset MATCH MBEGIN MEND
	fi

	hostname='%F{$prompt_pure_colors[host]}@%m%f'
	# Show `username@host` if logged in through SSH.
	[[ -n $ssh_connection ]] && username='%F{$prompt_pure_colors[user]}%n%f'"$hostname"

	# Show `username@host` if inside a container and not in GitHub Codespaces.
	[[ -z "${CODESPACES}" ]] && prompt_pure_is_inside_container && username='%F{$prompt_pure_colors[user]}%n%f'"$hostname"

	# Show `username@host` if root, with username in default color.
	[[ $UID -eq 0 ]] && username='%F{$prompt_pure_colors[user:root]}%n%f'"$hostname"

	typeset -gA prompt_pure_state
	prompt_pure_state+=(
		username "$username"
		prompt	 "${PURE_PROMPT_SYMBOL:-❯}"
	)
}

# Return true if executing inside a Docker, LXC or systemd-nspawn container.
prompt_pure_is_inside_container() {
	local -r cgroup_file='/proc/1/cgroup'
	local -r nspawn_file='/run/host/container-manager'
	[[ -r "$cgroup_file" && "$(< $cgroup_file)" = *(lxc|docker)* ]] \
		|| [[ "$container" == "lxc" ]] \
		|| [[ -r "$nspawn_file" ]]
}

prompt_pure_setup() {
	# Prevent percentage showing up if output doesn't end with a newline.
	export PROMPT_EOL_MARK=''

	prompt_opts=(subst percent)

	# Borrowed from `promptinit`. Sets the prompt options in case Pure was not
	# initialized via `promptinit`.
	setopt noprompt{bang,cr,percent,subst} "prompt${^prompt_opts[@]}"

	if [[ -z $prompt_newline ]]; then
		# This variable needs to be set, usually set by promptinit.
		typeset -g prompt_newline=$'\n%{\r%}'
	fi

	zmodload zsh/datetime
	zmodload zsh/zle
	zmodload zsh/parameter
	zmodload zsh/zutil

	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info

	# The `add-zle-hook-widget` function is not guaranteed to be available.
	# It was added in Zsh 5.3.
	autoload -Uz +X add-zle-hook-widget 2>/dev/null

	# Set the colors.
	typeset -gA prompt_pure_colors
	prompt_pure_colors=(
		execution_time       yellow
		git:branch           242
		host                 242
		path                 blue
		prompt:error         red
		prompt:success       magenta
		prompt:continuation  242
		suspended_jobs       red
		user                 242
		user:root            default
		virtualenv           242
	)

	add-zsh-hook precmd prompt_pure_precmd
	add-zsh-hook preexec prompt_pure_preexec

	prompt_pure_state_setup

	zle -N prompt_pure_reset_prompt
	zle -N prompt_pure_update_vim_prompt_widget
	zle -N prompt_pure_reset_vim_prompt_widget
	if (( $+functions[add-zle-hook-widget] )); then
		add-zle-hook-widget zle-line-finish prompt_pure_reset_vim_prompt_widget
		add-zle-hook-widget zle-keymap-select prompt_pure_update_vim_prompt_widget
	fi

	# If a virtualenv is activated, display it in grey.
	PROMPT='%(12V.%F{$prompt_pure_colors[virtualenv]}%12v%f .)'

	# Prompt turns red if the previous command didn't exit with 0.
	local prompt_indicator='%(?.%F{$prompt_pure_colors[prompt:success]}.%F{$prompt_pure_colors[prompt:error]})${prompt_pure_state[prompt]}%f '
	PROMPT+=$prompt_indicator

	# Indicate continuation prompt by … and use a darker color for it.
	PROMPT2='%F{$prompt_pure_colors[prompt:continuation]}… %(1_.%_ .%_)%f'$prompt_indicator

	# Store prompt expansion symbols for in-place expansion via (%). For
	# some reason it does not work without storing them in a variable first.
	typeset -ga prompt_pure_debug_depth
	prompt_pure_debug_depth=('%e' '%N' '%x')

	# Compare is used to check if %N equals %x. When they differ, the main
	# prompt is used to allow displaying both filename and function. When
	# they match, we use the secondary prompt to avoid displaying duplicate
	# information.
	local -A ps4_parts
	ps4_parts=(
		depth 	  '%F{yellow}${(l:${(%)prompt_pure_debug_depth[1]}::+:)}%f'
		compare   '${${(%)prompt_pure_debug_depth[2]}:#${(%)prompt_pure_debug_depth[3]}}'
		main      '%F{blue}${${(%)prompt_pure_debug_depth[3]}:t}%f%F{242}:%I%f %F{242}@%f%F{blue}%N%f%F{242}:%i%f'
		secondary '%F{blue}%N%f%F{242}:%i'
		prompt 	  '%F{242}>%f '
	)
	# Combine the parts with conditional logic. First the `:+` operator is
	# used to replace `compare` either with `main` or an ampty string. Then
	# the `:-` operator is used so that if `compare` becomes an empty
	# string, it is replaced with `secondary`.
	local ps4_symbols='${${'${ps4_parts[compare]}':+"'${ps4_parts[main]}'"}:-"'${ps4_parts[secondary]}'"}'

	# Improve the debug prompt (PS4), show depth by repeating the +-sign and
	# add colors to highlight essential parts like file and function name.
	PROMPT4="${ps4_parts[depth]} ${ps4_symbols}${ps4_parts[prompt]}"

	# Guard against Oh My Zsh themes overriding Pure.
	unset ZSH_THEME

	# Guard against (ana)conda changing the PS1 prompt
	# (we manually insert the env when it's available).
	export CONDA_CHANGEPS1=no
}

prompt_pure_setup "$@"
