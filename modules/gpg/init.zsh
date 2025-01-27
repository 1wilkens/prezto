#
# Provides for an easier use of GPG by setting up gpg-agent.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Return if requirements are not found.
if (( ! $+commands[gpg-agent] )); then
  return 1
fi

# Don't start a gpg-agent for root
if [[ "$UID" == 0 ]]; then
  return 1
fi

# Set the default paths to gpg-agent files.
_gpg_agent_conf="${GNUPGHOME:-$HOME/.gnupg}/gpg-agent.conf"
_gpg_agent_env="${XDG_CACHE_HOME:-$HOME/.cache}/prezto/gpg-agent.env"

# Load environment variables from previous run
source "$_gpg_agent_env" 2> /dev/null

# Start gpg-agent if not started.
if [[ -z "$GPG_AGENT_INFO" && ! -S "${GNUPGHOME:-$HOME/.gnupg}/S.gpg-agent" && ! -S "/run/user/${UID}/gnupg/S.gpg-agent" ]]; then
  # Start gpg-agent if not started.
  if ! ps -U "$LOGNAME" -o pid,ucomm | grep -q -- "${${${(s.:.)GPG_AGENT_INFO}[2]}:--1} gpg-agent"; then
    mkdir -p "$_gpg_agent_env:h"
    eval "$(gpg-agent --daemon | tee "$_gpg_agent_env")"
  fi
fi

# Inform gpg-agent of the current TTY for user prompts.
export GPG_TTY=$TTY

# Integrate with the SSH module.
if grep '^enable-ssh-support' "$_gpg_agent_conf" &> /dev/null; then
  # Load required functions.
  autoload -Uz add-zsh-hook

  # Override the ssh-agent environment file default path.
  _ssh_agent_env="$_gpg_agent_env"

  # Load the SSH module for additional processing.
  pmodload 'ssh'

  # Updates the GPG-Agent TTY before every command since SSH does not set it.
  function _gpg-agent-update-tty {
    gpg-connect-agent UPDATESTARTUPTTY /bye >/dev/null
  }
  add-zsh-hook preexec _gpg-agent-update-tty

  # FIXME: Remove this workaround once upstream cleanly handles gpg-agent via systemd
  unset SSH_AGENT_PID && export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"
fi

# Clean up.
unset _gpg_agent_{conf,env}

# Disable GUI prompts inside SSH.
if [[ -n "$SSH_CONNECTION" ]]; then
  export PINENTRY_USER_DATA='USE_CURSES=1'
fi
