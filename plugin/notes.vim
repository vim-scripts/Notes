" notes.vim: Lightweight note taker plugin
" Author: Hari Krishna (hari dot vim at gmail dot com)
" Last Change: 16-Sep-2009 @ 18:07
" Created:     21-Jul-2009
" Requires:    Vim-7.2, genutils.vim(2.5)
" Version:     2.1.0
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org//script.php?script_id=2732
" Usage:
"   See :help |notes.txt|

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

if exists('loaded_notes')
  finish
endif
if v:version < 702
  echomsg 'notes: You need at least Vim 7.2'
  finish
endif
if !exists('loaded_genutils')
  runtime plugin/genutils.vim
endif
if !exists('loaded_genutils') || loaded_genutils < 205
  echomsg 'notes: You need a newer version of genutils.vim plugin'
  finish
endif

if !exists('g:notesRoot') || !isdirectory(expand(g:notesRoot))
  echomsg "Notes: Configured root doesn't exist or is not a directory" .
        \ (exists('g:notesRoot') ? ':'.g:notesRoot : '')
  finish
endif

let g:loaded_notes = 201
"let g:notesRoot = 'c:/tmp/root' " Please, no trailing-slash for now.

if !exists('g:notesDefaultName')
  let g:notesDefaultName = 'New Note' " Without extension.
endif
if !exists('g:notesMaxNameLenth')
  let g:notesMaxNameLenth = 100
endif
if !exists('g:notesSyncNameAndTitle')
  let g:notesSyncNameAndTitle = 1
endif
if !exists('g:notesFileExtension')
  let g:notesFileExtension = '.txt'
endif
if !exists('g:notesFileType')
  let g:notesFileType = 'note'
endif
if !exists('g:notesWordSeparator')
  let g:notesWordSeparator = ' '
endif
if !exists('g:notesCompleteAnchortAtStart')
  let g:notesCompleteAnchortAtStart = 0
endif

command! -nargs=? -complete=customlist,notes#NoteComplete Note :call notes#OpenNote('<args>')
command! NoteSyncFilename :call notes#SyncCurrentNoteName()
command! -bang -nargs=1 -complete=customlist,notes#NoteFolderComplete NoteNewFolder :call notes#NewFolder(expand('<bang>') == '!' ? 1 : 0, '<args>')
command! -nargs=1 -complete=customlist,notes#NoteFolderComplete NoteMove :call notes#MoveCurrentTo('<args>')
command! -complete=customlist,notes#NoteFolderComplete NoteAsNew :call notes#SaveCurrentAs('<args>')
command! -complete=customlist,notes#NoteFolderComplete NoteSaveAs :call notes#SaveCurrentAs('<args>')
command! -bang -complete=customlist,notes#FolderCompleteForGrep -nargs=* NoteGrep :call notes#VimGrep(expand('<bang>'), <f-args>)
command! -nargs=? -complete=customlist,notes#NoteFolderComplete NoteBrowse :call notes#NoteBrowse('<args>')
command! -bang NoteRemove :call notes#RemoveCurrent(expand('<bang>') == '!')
command! -nargs=1 -complete=customlist,genutils#UserDirComplete2 NoteChangeRoot :let g:notesRoot = '<args>'

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
