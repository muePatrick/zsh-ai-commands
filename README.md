# ZSH AI Commands
![zsh-ai-commands-demo](./zsh-ai-commands-demo.gif)

This plugin works by asking GPT (*gpt-4o*) for terminal commands that achieve the described target action.

To use it just type what you want to do (e.g. `list all files in this directory`) and hit the configured hotkey (default: `Ctrl+o`).
When GPT responds with its suggestions just select the one from the list you want to use.

## Requirements
* [curl](https://curl.se/)
* [fzf](https://github.com/junegunn/fzf)
  * note: you need a recent version of fzf (the apt version for example is fairly old and will not work)
* awk

## Installation

### oh-my-zsh

Clone the repository to you oh-my-zsh custom plugins folder:

``` sh
git clone https://github.com/muePatrick/zsh-ai-commands ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-ai-commands
```

Enable it in your `.zshrc` by adding it to your plugin list:

```
plugins=(... zsh-ai-commands ...)
```

Set the API key in your by setting:

```
ZSH_AI_COMMANDS_OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

Replace the placeholder with your own key.
The config can be set e.g in your `.zshrc` in this case be careful to not leak the key should you be sharing your config files.

## Configuration Variables

| Variable                                  | Default                                 | Description                                                                                                |
| ----------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `ZSH_AI_COMMANDS_OPENAI_API_KEY` | `-/-` (not set) | OpenAI API key |
| `ZSH_AI_COMMANDS_HOTKEY` | `'^o'` (Ctrl+o) | Hotkey to trigger the request |
| `ZSH_AI_COMMANDS_LLM_NAME` | `gpt-4o` | LLM name |
| `ZSH_AI_COMMANDS_N_GENERATIONS` | `5` | Number of completions to ask for |
| `ZSH_AI_COMMANDS_EXPLAINER` | `true` | If true, GPT will comment the command |


## Known Bugs
- [ ] Sometimes the commands in the response have to much / unexpected special characters and the string is not preprocessed enough. In this case the fzf list stays empty.
- [ ] The placeholder message, that should be shown while the GPT request is running, is not always shown. For me it only works if `zsh-autosuggestions` is enabled.
