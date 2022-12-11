## Requirements

You would probably need at least a normal version of vim 8.2 to use
the plugin ("normal" refers to which set of features is included,
quite commonly "big" and "huge" versions of vim are used, which
contains the "normal" features set). I've gotten the plugin working on
a normal version of vim 8.2.0000. The listener feature which the
plugin relies on is introduced in a late patch to vim 8.1 so the
requirement can be only scarcely reduced.

`unitex` needs to be installed. See
<https://github.com/juiyung/unitex> for installing it. Vim's
`'encoding'` needs to be "utf-8", as well as the file's encoding.

## Installation

If you use a plugin manager, just use it and there are no special
notes. Otherwise you may try out
[vim-plug](https://github.com/junegunn/vim-plug) or alike, follow the
manager's guidance to install the plugin.

Alternatively you could use vim's own package managing system
available since vim 8. Suppose your vim files are in the `~/.vim`
directory (this depends on your `'runtimepath'`, see `:help rtp` in
vim) you can install this plugin through:

    mkdir -p ~/.vim/pack/foo/start
    cd ~/.vim/pack/foo/start
    git clone https://github.com/juiyung/vim-unitex.git

The name "foo" is arbitrary.

## Quick Start

With requirements met and the plugin installed, start editing a
(La)TeX document and execute in the command-line

    :Unitex on

Then the unusual "syntax concealment" provided by the plugin is turned
on. You may save the document then `less` it in a terminal, you would
see that no actual Unicode replacement is there, which means you can
compile the document like usual.

You could add to your vimrc

    au FileType tex Unitex on

or add

    Unitex on

to your `ftplugin/tex.vim` file so that---assuming you have `filetype
plugin on` somewhere---the unitex concealment would be automatically
turned on for (La)TeX documents. You could also have the following
mappings, in `ftplugin/tex.vim` or in FileType autocommands in vimrc:

    imap <buffer> <C-g>p <Plug>(unitex-peek)
    nmap <buffer> <Leader>p <Plug>(unitex-peek)

So that you can use `<C-g>p` in insert-mode and `<Leader>p` in normal
mode to unconceal the line of the cursor (`<Leader>` is backslash by
default, `:help <Leader>` tells you more), which may be occasionally
useful. The keys `<C-g>p` and `<Leader>p` are examples here, you are
supposed to pick your preferred keys to map to `<Plug>(unitex-peek)`.

A tip for using this plugin is to insert Unicode symbols directly into
the document, for example instead of inserting `\varepsilon` you could
type `Ctrl-k` + `e` + `*` in insert-mode to get `ε` (need digraph
support). Insert-mode mappings, abbreviations, keymaps, digraphs,
input methods, other plugins, there are many possiblilities and you
may begin to find doing so more convenient. The role of this plugin
then is to make it needless for you to insert all symbols as Unicode
characters in order to obtain a consistent looking of documents, and
to ease compilation of documents with unicode symbols by making a
restored version be written (this requires Unicode characters directly
inserted be covered by `unitex`'s rules).

## Description

The `:Unitex on` command turns "unitex concealment" on, it starts
running `unitex` as a job on the background (one is reused if
previously started by the plugin) with a channel to communicate with
it, filters the buffer content through the channel, and sets up a
listener (a subroutine responding to buffer changes) for the buffer.
Subsequent changes you make to the buffer is recorded, and each time
nothing is pending (SafeState), for example the instance after you
navigate to another line or by pressing Enter in insert-mode, lines
having been changed since last SafeState that are not under the cursor
are passed to `unitex` through the channel, and the result are then
substituted into the buffer.

All these attempts to achieve this: As you view and edit the document
it feels like vim's syntax concealment is turned on, but unlike in
syntax concealment those Unicode symbols are not fake, and you can not
only see them but also edit text containning them. More differences
between the effect created by this plugin and vim's syntax concealment
are discussed in [a later section](#comp).

A mapping `<Plug>(unitex-peek)` is provided to restore the line under
cursor when unitex concealment is turned on. The background job
started is still used, as `unitex` has been written to restore lines
prepended with a special code (ETX). Effort is made to approporiately
position the cursor in the restored line. This restoration is always
counted as a change to the buffer, so the line gets concealed again
when you leave it. (Be aware that this also means using the mapping
after undoing some changes creates a new undo branch. In case you run
into a problem for this, the `:earlier` command can help.)

Undoing amounts to a change to the buffer and the listener gets
notified, however, such changes are not recorded, and in SafeState if
it's detected that there are still redoable changes the substitution
wouldn't be made, so that redoing wouldn't be accidentally messed up.
When the substitution does take place it's joined with the previous
undo block so an extra step of undoing substitutions is not
introduced, and there is thus no need to detect changes caused by
undoing, as unconverted text wouldn't be revealed by undoing (unless
you keep undoing till past the point when unitex concealment has been
turned on).

The plugin handles the writing of buffer to disk file, so as to make
the disk file always contain the unconcealed content (`'buftype'` is
set to "acwrite" to achieve this, so beware if the option is set
otherwise as possibly done by other plugins, the described behavior
would be broken). Currently writing or appending a range of lines to a
file is however not handled specially.

## Unicode Rendering Issues

If you got "tofu"s where Unicode characters are substituted into the
text, you would need to look for fonts supporting them. You don't
necessarily need to replace your favorite font if it doesn't cover
enough Unicode characters. In gvim there is a fallback mechanism for
fonts, the `'guifont'` option is a list of fonts where a character not
found in one would be looked up in the next. If you are using terminal
vim, the terminal emulator might provide the same mechanism as well,
`urxvt` does, for example.

In the rules file shipped with `unitex`, combining grapheme joiner
(CGJ) is currently used in many places. Many fonts cover it, however I
found that some fonts though does contain CGJ somehow doesn't make it
invisible, if this turns out a problem in your case the font would
need to be replaced, unless you managed to avoid CGJ.

## <a id="comp">Comparison with Vim's Syntax Concealment</a>

First of all, although you might feel like making the plugin a
replacement for vim's syntax concealment, the plugin doesn't mean to
replace syntax concealment. There are certainly some disadvantages of
the plugin if it's used alone, for example it's unsuitable for
hiding some text---hiding is possible by substitution with blank
characters but that would generally bring inconvenience or troubles
for editing---but you could use syntax concealment to do that if you
want. As drawbacks may be compensated by syntax concealment, mostly
advantages of this plugin are presented, that is, why you might find
using this plugin better than using vim's syntax concealment alone.

Using vim's syntax concealment, visually you can set the
`'concealcursor'` option in order to achieve a close effect as the
plugin provides, but that would cause a separation of the text you
edit and the text you see, more specifically, the left and right
motions of cursor and effects of deletion and insertion become
unintuitive, you would encounter situations where pressing `l` many
times in normal mode is needed just to move across one visual
character, and deletion of one visual character cannot not be done by
pressing Backspace once in insert-mode. With what's provided by this
plugin, there is not such separation, what you see is what you edit.

If `'concealcursor'` is not set, the difference is only more obvious.
You still have unintuitive cursor motion when moving the cursor
between lines. More significantly you don't have concealment for the
line you are editing, having which, I suppose, is generally wanted if
without the subsequent quirks of setting `'concealcursor'` that make
it not really a choice for many people. In a situation where the
unconcealed text is more convenient or you want to check the
underlying text, the mapping `<Plug>(unitex-peek)` can be used.

A minor point: Vim's syntax concealment highlights all concealment
characters with a single highlight group that might not always fit
into the context, whereas characters substituted into the document
naturally gets highlighted according to the context, so this plugin
may provide a better visual effect than syntax concealment does.

## Quickfix Issue

`:Unitex on` sets `'buftype'` to "acwrite", this might cause trouble
when the quickfix feature is also used. There is an issue in vim's
official repository closely related to this problem
(<https://github.com/vim/vim/issues/516>), which by the time this
plugin is written has remained open for quite a few years. I suppose
vim developers will eventually fix it but before that we need to
resort to a workaround. I found the plugin
[QFEnter](https://github.com/yssl/QFEnter) helpful.
