# Check if required tools are installed
(( ! $+commands[fzf] )) && return
(( ! $+commands[curl] )) && return

# Check if if OpenAi API key ist set
(( ! ${+ZSH_AI_COMMANDS_OPENAI_API_KEY} )) && echo "zsh-ai-commands::Error::No API key set in the env var ZSH_AI_COMMANDS_OPENAI_API_KEY. Plugin will not be loaded" && return

(( ! ${+ZSH_AI_COMMANDS_HOTKEY} )) && typeset -g ZSH_AI_COMMANDS_HOTKEY='^o'

(( ! ${+ZSH_AI_COMMANDS_LLM_NAME} )) && typeset -g ZSH_AI_COMMANDS_LLM_NAME='gpt-4o'

(( ! ${+ZSH_AI_COMMANDS_N_GENERATIONS} )) && typeset -g ZSH_AI_COMMANDS_N_GENERATIONS=5

(( ! ${+ZSH_AI_COMMANDS_EXPLAINER} )) && typeset -g ZSH_AI_COMMANDS_EXPLAINER=true

fzf_ai_commands() {
  setopt extendedglob

  [ -n "$BUFFER" ] || { echo "Empty prompt" ; return }

  ZSH_AI_COMMANDS_USER_QUERY=$BUFFER

  # FIXME: For some reason the buffer is only updated if zsh-autosuggestions is enabled
  BUFFER="Asking $ZSH_AI_COMMANDS_LLM_NAME for a command to do: $ZSH_AI_COMMANDS_USER_QUERY. Please wait..."
  zle end-of-line
  zle reset-prompt

  if [ $ZSH_AI_COMMANDS_EXPLAINER = true ]
  then
    ZSH_AI_COMMANDS_GPT_SYSTEM="You only answer 1 appropriate shell one liner that does what the user asks for. The command has to work with the $(basename $SHELL) terminal. Don't wrap your answer in anything, dont acknowledge those rules, don't format your answer. Just reply the plaintext command. If your command is complicated and uses arguments, you MUST end your shell command with a shell comment starting with ## with a very concise explanation but your whole answer must remain a oneliner. Consider each new question from the user as independant."
  ZSH_AI_COMMANDS_GPT_USER="Description of what the command should do:\n'''\n$ZSH_AI_COMMANDS_USER_QUERY\n'''\nGive me the appropriate command."
    ZSH_AI_COMMANDS_GPT_REQUEST_BODY='{
    "model": "'$ZSH_AI_COMMANDS_LLM_NAME'",
    "n": '$ZSH_AI_COMMANDS_N_GENERATIONS',
    "temperature": 1,
    "messages": [
      {
        "role": "system",
        "content": "'$ZSH_AI_COMMANDS_GPT_SYSTEM'"
      },
      {
        "role": "user",
        "content": "Description of what the command should do:\n'''"\nlist files, sort by descending size\n"'''\nGive me the appropriate command."
      },
      {
        "role": "assistant",
        "content": "ls -lS ## -l long listing -S sort by file size -r reverse order"
      },
      {
        "role": "user",
        "content": "'$ZSH_AI_COMMANDS_GPT_USER'"
      }
    ]
  }'
  else
    ZSH_AI_COMMANDS_GPT_SYSTEM="You only answer 1 appropriate shell one liner that does what the user asks for. The command has to work with the $(basename $SHELL) terminal. Don't wrap your answer in anything, dont acknowledge those rules, don't format your answer. Just reply the plaintext command."
  ZSH_AI_COMMANDS_GPT_USER="Description of what the command should do:\n'''\n$ZSH_AI_COMMANDS_USER_QUERY\n'''\nGive me the appropriate command."
  ZSH_AI_COMMANDS_GPT_REQUEST_BODY='{
    "model": "'$ZSH_AI_COMMANDS_LLM_NAME'",
    "n": '$ZSH_AI_COMMANDS_N_GENERATIONS',
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


  fi



  ZSH_AI_COMMANDS_GPT_RESPONSE=$(curl -q --silent https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ZSH_AI_COMMANDS_OPENAI_API_KEY" \
    -d "$ZSH_AI_COMMANDS_GPT_REQUEST_BODY")
  local ret=$?

  if [ $ZSH_AI_COMMANDS_EXPLAINER = true ]
  then
    ZSH_AI_COMMANDS_SUGGESTIONS=$(echo $ZSH_AI_COMMANDS_GPT_RESPONSE | jq -r '.choices[].message.content' | uniq | sort | awk -F ' *## ' '!seen[$1]++' -)
    ZSH_AI_COMMANDS_SELECTED=$(echo $ZSH_AI_COMMANDS_SUGGESTIONS | fzf --reverse --height=100% --preview-window down:wrap --preview 'echo {} | awk -F " ## " "{print \$2}"')
  else
    ZSH_AI_COMMANDS_SUGGESTIONS=$(echo $ZSH_AI_COMMANDS_GPT_RESPONSE | jq -r '.choices[].message.content' | uniq)
    ZSH_AI_COMMANDS_SELECTED=$(echo $ZSH_AI_COMMANDS_SUGGESTIONS | fzf --reverse --height=100%)
  fi


  # get the answers
  BUFFER=$ZSH_AI_COMMANDS_SELECTED

  zle end-of-line
  zle reset-prompt
  return $ret
}

autoload fzf_ai_commands
zle -N fzf_ai_commands

bindkey $ZSH_AI_COMMANDS_HOTKEY fzf_ai_commands
