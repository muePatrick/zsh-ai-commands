# Check if required tools are installed
(( ! $+commands[fzf] )) && return
(( ! $+commands[curl] )) && return

# Check if if OpenAi API key ist set
(( ! ${+ZSH_AI_COMMANDS_OPENAI_API_KEY} )) && echo "zsh-ai-commands::Error::No API key set. Plugin will not be loaded" && return

(( ! ${+ZSH_AI_COMMANDS_HOTKEY} )) && typeset -g ZSH_AI_COMMANDS_HOTKEY='^o'

fzf_ai_commands() {
  setopt extendedglob

  ZSH_AI_COMMANDS_USER_QUERY=$BUFFER

  # FIXME: For some reason the buffer is only updated if zsh-autosuggestions is enabled
  BUFFER="Asking GPT-4 for a command to do: $ZSH_AI_COMMANDS_USER_QUERY. Please wait..."
  zle end-of-line
  zle reset-prompt

  ZSH_AI_COMMANDS_GPT_MESSAGE_CONTENT="Give me a linux terminal command to do the following: $ZSH_AI_COMMANDS_USER_QUERY. Respond with a json array of possible commands only. Each entry should be a new entry. Each entry should only contain the command. No additional text should be present. Give multiple suggestion if possible. The commands should be for linux."

  ZSH_AI_COMMANDS_GPT_REQUEST_BODY='{
    "model": "gpt-4-turbo-preview",
    "messages": [
      {
        "role": "user",
        "content": "'$ZSH_AI_COMMANDS_GPT_MESSAGE_CONTENT'"
      }
    ]
  }'

  ZSH_AI_COMMANDS_GTP_RESPONSE=$(curl -q --silent https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ZSH_AI_COMMANDS_OPENAI_API_KEY" \
    -d "$ZSH_AI_COMMANDS_GPT_REQUEST_BODY")
  local ret=$?

  # replace all newlines with spaces
  ZSH_AI_COMMANDS_COMMAND_SELECTION=$(echo $ZSH_AI_COMMANDS_GTP_RESPONSE | tr -d '\n')
  # get the first suggestion
  ZSH_AI_COMMANDS_COMMAND_SELECTION=$(echo $ZSH_AI_COMMANDS_COMMAND_SELECTION | jq -r '.choices[0].message.content')
  # remove the string ```json from the beginning of the string
  ZSH_AI_COMMANDS_COMMAND_SELECTION=$(echo $ZSH_AI_COMMANDS_COMMAND_SELECTION | sed 's/```json//g')
  # remove the string ``` from the end of the string
  ZSH_AI_COMMANDS_COMMAND_SELECTION=$(echo $ZSH_AI_COMMANDS_COMMAND_SELECTION | sed 's/```//g')

  # FIXME: The json array cannot be parsed if there are too many / unexpected special characters in the response
  ZSH_AI_COMMANDS_SELECTED_COMMAND=$(echo $ZSH_AI_COMMANDS_COMMAND_SELECTION | jq -r '.[]' | fzf)
  BUFFER=$ZSH_AI_COMMANDS_SELECTED_COMMAND

  zle end-of-line
  zle reset-prompt
  return $ret
}

autoload fzf_ai_commands
zle -N fzf_ai_commands

bindkey $ZSH_AI_COMMANDS_HOTKEY fzf_ai_commands
