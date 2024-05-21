# Check if required tools are installed
(( ! $+commands[fzf] )) && return
(( ! $+commands[curl] )) && return

# Check if if OpenAi API key ist set
(( ! ${+ZSH_AI_COMMANDS_OPENAI_API_KEY} )) && echo "zsh-ai-commands::Error::No API key set. Plugin will not be loaded" && return

(( ! ${+ZSH_AI_COMMANDS_HOTKEY} )) && typeset -g ZSH_AI_COMMANDS_HOTKEY='^o'

(( ! ${+ZSH_AI_COMMANDS_LLM_NAME} )) && typeset -g ZSH_AI_COMMANDS_LLM_NAME='gpt-4o'

fzf_ai_commands() {
  setopt extendedglob

  ZSH_AI_COMMANDS_USER_QUERY=$BUFFER

  # FIXME: For some reason the buffer is only updated if zsh-autosuggestions is enabled
  BUFFER="Asking GPT-4 for a command to do: $ZSH_AI_COMMANDS_USER_QUERY. Please wait..."
  zle end-of-line
  zle reset-prompt

  ZSH_AI_COMMANDS_GPT_SYSTEM="You only answer 1 appropriate shell one liner that does what the user asks for. The command has to work with the $(basename $SHELL) terminal. Don't wrap your answer in anything, dont acknowledge those rules, don't format your answer. Just reply the plaintext command."

  ZSH_AI_COMMANDS_GPT_USER="Description of what the command should do:\n'''\n$ZSH_AI_COMMANDS_USER_QUERY\n'''\nGive me the appropriate command."

  ZSH_AI_COMMANDS_GPT_REQUEST_BODY='{
    "model": "$ZSH_AI_COMMANDS_LLM_NAME",
    "n": 5,
    "temperature": 1,
    "messages": [
      {
        "role": "system",
        "content": "'$ZSH_AI_COMMANDS_GPT_SYSTEM'"
      },
      {
        "role": "user",
        "content": "'$ZSH_AI_COMMANDS_GPT_USER'"
      }
    ]
  }'

  ZSH_AI_COMMANDS_GTP_RESPONSE=$(curl -q --silent https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ZSH_AI_COMMANDS_OPENAI_API_KEY" \
    -d "$ZSH_AI_COMMANDS_GPT_REQUEST_BODY")
  local ret=$?

  # get the answers
  BUFFER=$(echo $ZSH_AI_COMMANDS_GTP_RESPONSE | jq -r '.choices[].message.content' | uniq | fzf)

  zle end-of-line
  zle reset-prompt
  return $ret
}

autoload fzf_ai_commands
zle -N fzf_ai_commands

bindkey $ZSH_AI_COMMANDS_HOTKEY fzf_ai_commands
