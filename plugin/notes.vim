" notes.vim: Note taking plugin
" Author: Hari Krishna (hari_vim at yahoo dot com)
" Last Change: 06-Aug-2009 @ 15:23
" Created:     21-Jul-2009
" Requires:    Vim-7.0, genutils.vim(2.3)
" Version:     1.0.5
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org//script.php?script_id=
" Usage:
"   - In vimrc, let g:notesRoot to the root directory holding/containing all your notes.
"   - Use ":Note" command to create or open notes.
"   - All note files are regular text files, but they are special to the
"     plugin only if they live under the g:notesRoot directory.
"   - You can also open existing note files by using regular vim commands or
"     file browsers. However, ":Note" command provides completion that could
"     make it easier to find a note.
"   - Usage: Note [<path>]
"       - With no arguments, it creates a new note in the root.
"       - When the <path> is not absolute, it is handled relative to the root.
"         - When <path> resolves to an existing directory, a new note is
"           created in that directory.
"         - When <path> resolves to an existing file, the file is opened as a
"           note.
"         - When <path> resolves to a non existing name, a new note is created
"           with that name.
"       - Absolute paths to (existing or non-existing) files or (existing)
"         directories can also be specified, but they should refer to paths
"         under the root.
"   - You can use ":NoteNewFolder" to create subdirectories under the root with
"     the convenience of completion. This works very much like mkdir command
"     and specifying "!" is equivalent to "-p" option.
"   - Use ":NoteMove <path>" to move the current note to the destination. It
"     behaves pretty much like the mv command except that relative paths are
"     relative to the root of the notes directory (g:notesRoot) and provides
"     directory name completion.
"   - Use :NoteAsNew command instead of :w to save notes taken in an unnamed
"     buffer with an auto-generated name under the root directory.
"   - ":NoteGrep[!] <pat>" command is a shortcut to invoke :vimgrep on the
"     subfolder. If the pattern is not enclosed, it will be automatically
"     enclosed in /'es.  If the pattern itself has /'es or you need to pass
"     flags, then you need to enclose the pattern yourself with any flags at
"     the end. See help on :vimgrep for details.
"   - ":NoteBrowse" is a simple shortcut to open the root directory, which
"     will open the directory in your default file explorer.
"   - ":NoteSyncFilename" sync the filename of the note to the first line in
"     the note. This is to manually trigger the process when
"     g:notesSyncNameAndTitle is disabled (see below).
"
"   Settings:
"   - g:notesRoot - Sets the root directory path.
"   - g:notesDefaultName - The default name used for notes (without any
"                          extension)
"   - g:notesMaxNameLenth - An integer that limits the length of generated names.
"   - g:notesSyncNameAndTitle - Allows automatically renaming notes on save,
"                               based on the first non-empty line. When
"                               disabled, use :NoteSyncFilename to manually
"                               trigger this.
" TODO:
" - With 'autowrite' if BufWritePost gets triggered when the cursor is in a
"   non-note buffer, there is no easy way to sync filename. Renaming is
"   disabled in this case.
"     

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

if exists('loaded_notes')
  finish
endif
if v:version < 700
  echomsg 'notes: You need at least Vim 7.0'
  finish
endif
if !exists('loaded_genutils')
  runtime plugin/genutils.vim
endif
if !exists('loaded_genutils') || loaded_genutils < 203
  echomsg 'notes: You need a newer version of genutils.vim plugin'
  finish
endif

if !exists('g:notesRoot') || !isdirectory(g:notesRoot)
  echomsg "Notes: Configured root doesn't exist or is not a directory" .
        \ (exists('g:notesRoot') ? ':'.g:notesRoot : '')
  finish
endif

let g:loaded_notes = 105
"let g:notesRoot = 'c:/tmp/root' " Please, no trailing-slash for now.

if !exists('g:notesDefaultName')
  let g:notesDefaultName = 'New Note' " Add .txt automatically.
endif
if !exists('g:notesMaxNameLenth')
  let g:notesMaxNameLenth = 100
endif
if !exists('g:notesSyncNameAndTitle')
  let g:notesSyncNameAndTitle = 1
endif

command! -nargs=? -complete=custom,notes#NoteComplete Note :call notes#OpenNote('<args>')
command! NoteSyncFilename :call notes#SyncNoteName()
command! -bang -nargs=1 -complete=custom,notes#NoteFolderComplete NoteNewFolder :call notes#NewFolder(expand('<bang>') == '!' ? 1 : 0, '<args>')
command! -nargs=1 -complete=custom,notes#NoteFolderComplete NoteMove :call notes#MoveTo('<args>')
command! NoteAsNew :call notes#SaveAsNew()
command! -bang -nargs=1 NoteGrep :call notes#VimGrep(expand('<bang>'), '<args>')
command! NoteBrowse :exec 'sp' g:notesRoot

if !exists('g:notesNoFileMonitoring') || !g:notesNoFileMonitoring
  aug NotesFileMonitoring
    au!
    au BufNewFile *.txt :call notes#MonitorCurrentFile()
    au BufRead *.txt :call notes#MonitorCurrentFile()
  aug END
endif

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim6:fdm=marker et sw=2
