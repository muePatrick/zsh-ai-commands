#!/bin/zsh

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

  BUFFER="$(echo "$BUFFER" | sed 's/^AI_ASK: //g')"

  ZSH_AI_COMMANDS_USER_QUERY=$BUFFER

  # save to history
  echo "AI_ASK: $ZSH_AI_COMMANDS_USER_QUERY" >> $HISTFILE
  # also to atuin's history if installed
  if command -v atuin &> /dev/null;
  then
      atuin_id=$(atuin history start "AI_ASK: $ZSH_AI_COMMANDS_USER_QUERY")
      atuin history end --exit 0 "$atuin_id"
  fi

  # FIXME: For some reason the buffer is only updated if zsh-autosuggestions is enabled
  BUFFER="Asking $ZSH_AI_COMMANDS_LLM_NAME for a command to do: $ZSH_AI_COMMANDS_USER_QUERY. Please wait..."
  ZSH_AI_COMMANDS_USER_QUERY=$(echo "$ZSH_AI_COMMANDS_USER_QUERY" | sed 's/"/\\"/g')
  zle end-of-line
  zle reset-prompt

  if [ $ZSH_AI_COMMANDS_EXPLAINER = true ]
  then
    ZSH_AI_COMMANDS_GPT_SYSTEM="You only answer 1 appropriate shell one liner that does what the user asks for. The command has to work with the $(basename $SHELL) terminal. Don't wrap your answer in code blocks or anything, dont acknowledge those rules, don't format your answer. Just reply the plaintext command. If your answer uses arguments or flags, you MUST end your shell command with a shell comment starting with ## with a ; separated list of concise explanations about each agument. Don't explain obvious placeholders like <ip> or <serverport> etc. Remember that your whole answer MUST remain a oneliner."
    ZSH_AI_COMMANDS_GPT_EX="Description of what the command should do: 'list files, sort by descending size'. Give me the appropriate command."
    ZSH_AI_COMMANDS_GPT_EX_REPLY="ls -lSr ## -l long listing ; -S sort by file size ; -r reverse order"
    ZSH_AI_COMMANDS_GPT_USER="Description of what the command should do: '$ZSH_AI_COMMANDS_USER_QUERY'. Give me the appropriate command."
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
          "content": "'$ZSH_AI_COMMANDS_GPT_EX'"
        },
        {
          "role": "assistant",
          "content": "'$ZSH_AI_COMMANDS_GPT_EX_REPLY'"
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

  # check request is valid json
  {echo "$ZSH_AI_COMMANDS_GPT_REQUEST_BODY" | jq > /dev/null} || {echo "Couldn't parse the body request" ; return}

  ZSH_AI_COMMANDS_GPT_RESPONSE=$(curl -q --silent https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ZSH_AI_COMMANDS_OPENAI_API_KEY" \
    -d "$ZSH_AI_COMMANDS_GPT_REQUEST_BODY")
  local ret=$?

  # if the json parsing fails, we need a desperate parser
  {
      ZSH_AI_COMMANDS_PARSED=$(echo $ZSH_AI_COMMANDS_GPT_RESPONSE | jq -r '.choices[].message.content' | uniq)
  } || {
      ZSH_AI_COMMANDS_PARSED=$(echo $ZSH_AI_COMMANDS_GPT_RESPONSE | ppp -i 'import re' 're.sub("\[\dm|\\\\033|\\\\e", "DELETED", line)' | jq -r '.choices[].message.content' | uniq)
  }

  if [ $ZSH_AI_COMMANDS_EXPLAINER = true ]
  then
    ZSH_AI_COMMANDS_SUGGESTIONS=$(echo $ZSH_AI_COMMANDS_PARSED | sort | awk -F ' *## ' '!seen[$1]++' -)

    ZSH_AI_COMMANDS_SUGG_COMMANDS=$(echo $ZSH_AI_COMMANDS_SUGGESTIONS |  awk -F " ## " "{print \$1}")
    ZSH_AI_COMMANDS_SUGG_COMMENTS=$(echo $ZSH_AI_COMMANDS_SUGGESTIONS |  awk -F " ## " "{print \$2}")

    export ZSH_AI_COMMANDS_SUGG_COMMENTS  # otherwise fzf can't access it
    ZSH_AI_COMMANDS_SELECTED=$(echo $ZSH_AI_COMMANDS_SUGG_COMMANDS | fzf --reverse --height=~100% --preview-window down:wrap --preview 'echo "$ZSH_AI_COMMANDS_SUGG_COMMENTS" | sed -n "$(({n}+1))"p | sed "s/;/\n/g" | sed "s/^\s*//g;s/\s*$//g"')

  else
    ZSH_AI_COMMANDS_SELECTED=$(echo $ZSH_AI_COMMANDS_PARSED | fzf --reverse --height=~100% --preview-window down:wrap --preview 'echo {}')
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
