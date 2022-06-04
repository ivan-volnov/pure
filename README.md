# Pure

> Pretty, minimal and fast ZSH prompt. Even much pure and minimal now

<img src="screenshot.png" width="864">

---

## Overview

Most prompts are cluttered, ugly and slow. We wanted something visually pleasing that stayed out of our way.

### Why?

- Comes with the perfect prompt character.
  Author went through the whole Unicode range to find it.
- Prompt character turns red if the last command didn't exit with `0`.
- Command execution time will be displayed if it exceeds the set threshold.
- Username and host only displayed when in an SSH session or a container.
- Shows the current path in the title and the [current folder & command](screenshot-title-cmd.png) when a process is running.
- Support VI-mode indication by reverse prompt symbol (Zsh 5.3+).
- Makes an excellent starting point for your own custom prompt.

### The fork goal

- Remove a useless zsh subprocess per each instance (async workers)
- Code cleanup and simplicity

## Install

### Manually

1. Clone this repo somewhere. Here we'll use `$HOME/.config/zsh/pure`.

```sh
mkdir -p "$HOME/.config/zsh"
git clone https://github.com/ivan-volnov/pure.git "$HOME/.config/zsh/pure"
```

2. Add the path of the cloned repo to `$fpath` in `$HOME/.zshrc`.
```sh
# .zshrc
fpath+=$HOME/.config/zsh/pure
```

## Getting started

Initialize the prompt system (if not so already) and choose `pure`:

```sh
# .zshrc
autoload -U promptinit; promptinit
prompt pure
```

## Options

| Option                           | Description                                                                                    | Default value  |
| :------------------------------- | :--------------------------------------------------------------------------------------------- | :------------- |
| **`PURE_CMD_MAX_EXEC_TIME`**     | The max execution time of a process before its run time is shown when it exits.                | `5` seconds    |
| **`PURE_PROMPT_SYMBOL`**         | Defines the prompt symbol.                                                                     | `❯`            |
| **`PURE_PROMPT_VICMD_SYMBOL`**   | Defines the prompt symbol used when the `vicmd` keymap is active (VI-mode).                    | `❮`            |

## Zstyle options

You can set Pure to only `git fetch` the upstream branch of the current local branch. In some cases, this can result in faster updates for Git arrows, but for most users, it's better to leave this setting disabled. You can enable it with:

`zstyle :prompt:pure:git:fetch only_upstream yes`

`nix-shell` integration adds the shell name to the prompt when used from within a nix shell. It is enabled by default, you can disable it with:

`zstyle :prompt:pure:environment:nix-shell show no`

## Colors

As explained in ZSH's [manual](http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html#Character-Highlighting), color values can be:
- A decimal integer corresponding to the color index of your terminal. If your `$TERM` is `xterm-256color`, see this [chart](https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg).
- The name of one of the following nine colors: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, and `default` (the terminal’s default foreground)
- `#` followed by an RGB triplet in hexadecimal format, for example `#424242`. Only if your terminal supports 24-bit colors (true color) or when the [`zsh/nearcolor` module](http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fnearcolor-Module) is loaded.

Colors can be changed by using [`zstyle`](http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fzutil-Module) with a pattern of the form `:prompt:pure:$color_name` and style `color`. The color names, their default, and what part they affect are:
- `execution_time` (yellow) - The execution time of the last command when exceeding `PURE_CMD_MAX_EXEC_TIME`.
- `git:branch` (242) - The name of the current branch when in a Git repository.
- `host` (242) - The hostname when on a remote machine.
- `path` (blue) - The current path, for example, `PWD`.
- `prompt:error` (red) - The `PURE_PROMPT_SYMBOL` when the previous command has *failed*.
- `prompt:success` (magenta) - The `PURE_PROMPT_SYMBOL` when the previous command has *succeeded*.
- `prompt:continuation` (242) - The color for showing the state of the parser in the continuation prompt (PS2). It's the pink part in [this screenshot](https://user-images.githubusercontent.com/147409/70068574-ebc74800-15f8-11ea-84c0-8b94a4b57ff4.png), it appears in the same spot as `virtualenv`. You could for example matching both colors so that Pure has a uniform look.
- `suspended_jobs` (red) - The `✦` symbol indicates that jobs are running in the background.
- `user` (242) - The username when on remote machine.
- `user:root` (default) - The username when the user is root.
- `virtualenv` (242) - The name of the Python `virtualenv` when in use.

The following diagram shows where each color is applied on the prompt:

```
┌─────────────────────────────────────────────────── user
│      ┌──────────────────────────────────────────── host
│      │           ┌──────────────────────────────── path
│      │           │          ┌───────────────────── git:branch
│      │           │          │
│      │           │          │
│      │           │          │
│      │           │          │
│      │           │          │      ┌────────────── execution_time
│      │           │          │      │
zaphod@heartofgold ~/dev/pure master 42s
venv ❯
│    │
│    └────────────────────────────────────────────── prompt
└─────────────────────────────────────────────────── virtualenv (or prompt:continuation)
```

### RGB colors

There are two ways to use RGB colors with the hexadecimal format. The correct way is to use a [terminal that support 24-bit colors](https://gist.github.com/XVilka/8346728) and enable this feature as explained in the terminal's documentation.

If you can't use such terminal, the module [`zsh/nearcolor`](http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fnearcolor-Module) can be useful. It will map any hexadecimal color to the nearest color in the 88 or 256 color palettes of your terminal, but without using the first 16 colors, since their values can be modified by the user. Keep in mind that when using this module you won't be able to display true RGB colors. It only allows you to specify colors in a more convenient way. The following is an example on how to use this module:

```sh
# .zshrc
zmodload zsh/nearcolor
zstyle :prompt:pure:path color '#FF0000'
```

## Example

```sh
# .zshrc

autoload -U promptinit; promptinit

# optionally define some options
PURE_CMD_MAX_EXEC_TIME=10

# change the path color
zstyle :prompt:pure:path color white

# change the color for both `prompt:success` and `prompt:error`
zstyle ':prompt:pure:prompt:*' color cyan

prompt pure
```

## Integration

### [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)

1. Set `ZSH_THEME=""` in your `.zshrc` to disable oh-my-zsh themes.
2. Follow the Pure [Install](#install) instructions.
3. Do not enable the following (incompatible) plugins: `vi-mode`, `virtualenv`.

**NOTE:** `oh-my-zsh` overrides the prompt so Pure must be activated *after* `source $ZSH/oh-my-zsh.sh`.

### [zim](https://github.com/Eriner/zim)

Add `zmodule ivan-volnov/pure --source async.zsh --source pure.zsh` to your `.zimrc` and run `zimfw install`.

### [zplug](https://github.com/zplug/zplug)

Update your `.zshrc` file with the following two lines:

```sh
zplug mafredri/zsh-async, from:github
zplug ivan-volnov/pure, use:pure.zsh, from:github, as:theme
```

### [zinit](https://github.com/zdharma/zinit)

Update your `.zshrc` file with the following two lines (order matters):

```sh
zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zinit light ivan-volnov/pure
```
