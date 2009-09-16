
" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

function! notes#OpenNote(notePath) " {{{
  let notePath = notes#ResolvePath(a:notePath, 0, g:notesDefaultName)
  if notePath == ''
    return
  endif
  " If the note is already loaded into Vim, then using sbuf will avoid
  " reloading the buffer.
  try
    exec 'sbuf' fnameescape(notePath)
  catch
    exec 'sp' fnameescape(notePath)
  endtry
  call notes#InstallAutoCmd()
  if g:notesFileType != ''
    exec 'set ft='.g:notesFileType
  endif
endfunction " }}}

function! notes#VimGrep(bang, ...) " {{{
  let pat = a:0 == 0 ? @/ : a:1
  let pat = (pat[0] =~ '\i') ? ('/'.pat.'/') : pat
  let files = a:0 > 1 ? a:000[1:] : [s:NotesRoot()]
  " Resolve, filter invalid paths and take care of dirs.
  call map(map(filter(map(files, 'notes#ResolvePath(v:val, 0, "")'),
        \             'v:val != ""'),
        \ 'isdirectory(v:val) ? v:val."/**" : v:val'), 'escape(v:val, " ")')
  try
    exec 'vimgrep'.a:bang.' '.pat.' '.join(files, ' ')
  catch
    echohl ErrorMsg | echo "\<CR>".substitute(v:exception, '^[^:]\+:', '', '')
          \ | echohl NONE
  endtry
endfunction " }}}

function! notes#NewFolder(bangP, folderPath) " {{{
  if !exists("*mkdir")
    echohl ErrorMsg | echo "mkdir() function not availble" | echohl NONE
  endif
  let folderPath = notes#ResolvePath(a:folderPath, 1, '')
  if folderPath == ''
    return
  endif
  if isdirectory(folderPath)
    echohl ErrorMsg | echo 'Folder already existing: '.folderPath
          \ | echohl NONE
    return
  endif
  try
    call mkdir(folderPath, a:bangP ? 'p' : '')
  catch
      echohl ErrorMsg | echo 'Error creating directory: '.
            \ substitute(v:exception, '^[^:]\+:', '', '') | echohl NONE
  endtry
endfunction " }}}

function! notes#RemoveCurrent(okForModified) " {{{
  if !s:IsValidNotePath(expand('%:p'))
    return
  endif
  if &modified && !a:okForModified
    echohl ErrorMsg | echo 'Buffer currently modified, save it first' | echohl NONE
    return
  endif

  let name = expand('%:t')
  let choice = confirm('Are you sure you want to remove "'.name.'"?', "&Yes\n&No", 2)
  if choice == 1
    let notePath = expand('%:p')
    if delete(notePath) != 0
      echohl ErrorMsg | echo 'FAILURE: file: "'.notePath."\" couldn't be removed" | echohl NONE
      return
    endif
    silent bw! %
    redraw | echo 'SUCCESS: file "'.notePath.'" removed.'
  endif
endfunction " }}}

" Look at the first non-empty line and sync the filename to it.
function! notes#SyncCurrentNoteName() " {{{
  if !s:IsValidNotePath(expand('%:p'))
    return
  endif

  let name = notes#GenerateNoteName()
  if name != ''
    let prevNotePath = expand('%:p')
    if name == s:NoteRootName(prevNotePath)
      return
    endif
    let newNotePath = notes#NewName(expand('%:h'), name)
    call s:MoveTo(newNotePath, 0)
  endif
endfunction " }}}

function! notes#SaveCurrentAs(path) " {{{
  " On unnamed buffers, it is nicer to use 0 for leaveSource, as that is what
  " actually happens anyway (when you write an unnamed buffer, the same buffer
  " gets a name, instead of a new buffer getting created). And this is what
  " the user would expect as well.
  call s:SaveCurrentAs(path, expand('%') == "" ? 0 : 1)
endfunction " }}}

function! notes#MoveCurrentTo(path) " {{{
  if expand('%') == '' || &buftype != '' || !s:IsValidNotePath(expand('%'))
    echohl ErrorMsg | echo 'This command works only on existing notes' | echohl NONE
    return
  endif
  call s:SaveCurrentAs(a:path, 0)
endfunction " }}}

" leaveSource == 1 means copyMode. This makes the note open in a split window.
" leaveSource == 0 means moveMode. This makes the note open in the same window.
function! s:SaveCurrentAs(path, leaveSource) " {{{
  let newNotePath = notes#ResolvePath(a:path, 0, s:NoteRootName(expand('%:t')))
  if newNotePath == ''
    return
  endif
  if s:FileExists(newNotePath)
    echohl ErrorMsg | echo "File exists: ".newNotePath | echohl NONE
    return
  endif
  " For 'buftype' buffers alone, we always default to a copy, because it is
  " not wise to delete the buffer and confuse the plugin that generated it.
  let copyMode = (&buftype != '') ? 1 : a:leaveSource
  call s:MoveTo(newNotePath, copyMode)
endfunction " }}}

" CAUTION: No checks, leave as script local method.
function! s:MoveTo(path, leaveSource) " {{{
  let prevBufnr = bufnr('%')
  let newNotePath = a:path
  if s:FileExists(newNotePath)
    " All our operations involve generating new names, so this should help
    " catch any bugs if they result in resolving to existing files.
    " NOTE: We allow empty files because notes#NewName() actually generates an
    " empty file to reserve the name.
    throw 'Notes:Move aborted, destination file has non-zero size'
  endif
  try
    " Since we already verified that the destination file doesn't exist, it is
    " ok to use bang. In fact, we HAVE to use bang, because we always create
    " an empty file in advance.
    exec 'w!' fnameescape(newNotePath)
  catch
    echohl ErrorMsg | echomsg 'Error writing to file: '.newNotePath |
          \ echomsg v:exception | echohl NONE
    return 1
  endtry

  " Success copying the contents, we can now switch to the new
  " note and remove the previous buffer
  try
    if a:leaveSource
      exec 'split' fnameescape(newNotePath)
    else
      let curpos = getpos('.')
      setl bufhidden=hide
      exec 'edit' fnameescape(newNotePath)
      call setpos('.', curpos)
    endif
    call notes#InstallAutoCmd()
  catch
    " We might end up leaving the temporary file, but this situation should
    " be rare, so it is better to be safe than sorry.
    echohl ErrorMsg
    if filereadable(newNotePath)
      echomsg 'An unexpected error aborted the move, a '.
            \ 'manual intervention may be required to remove: '.newNotePath
    else
      echomsg 'Aborted move on an unxpected error, old path: '.
            \ (bufname(prevBufnr) == '' ? '[No Name]' : bufname(prevBufnr)).
            \ ' new path:'.newNotePath
    endif
    echomsg v:exception | echohl NONE
    return 1
  endtry

  " Switched successfully to the new buffer, the old one can be removed. A
  " failure here is NOT fatal.
  let prevNotePath = expand('#'.prevBufnr.':p')
  try
    " If the previous path is not an unnamed buffer and is already saved then,
    " delete it. For unnamed buffers, the same bufnr results in getting
    " renamed, so be careful with it.
    if !a:leaveSource && bufnr('%') != prevBufnr && filereadable(prevNotePath)
      if delete(prevNotePath) != 0
        throw "Notes:Couldn't delete: ".prevNotePath " To be caught below.
      endif
      " Now delete the buffer as well.
      silent bw! #
    endif
  catch
    echohl WarningMsg | echomsg 'Error cleaning up old path: '. prevNotePath |
          \ echomsg v:exception | echohl NONE
  endtry
  return 0
endfunction " }}}

function! notes#NoteBrowse(path)
  let path = a:path == '' ? s:prevBrowseDir : notes#ResolvePath(a:path, 1, '')
  if !s:IsValidNotePath(path)
    let path = s:NotesRoot()
  endif
  let s:prevBrowseDir = path
  exec 'sp' path
endfunction

" When asDir==1, notePrefix is not used
function! notes#ResolvePath(path, asDir, notePrefix) " {{{
  if a:path == '' || a:path == '.'
    let path = s:NotesRoot()
  else
    if genutils#PathIsAbsolute(a:path)
      let path = genutils#CleanupFileName(a:path)
      if !s:IsValidNotePath(path)
        return ''
      endif
    else
      let path = s:NotesRoot().'/'.a:path
    endif
  endif
  if isdirectory(path)
    let path = substitute(path, '/\+$', '', '')
    if !a:asDir && a:notePrefix != ''
      let path = notes#NewName(path, a:notePrefix)
    endif
  else
    if g:notesFileExtension != ''
      let path .= ((a:asDir || path[-strlen(g:notesFileExtension):] == g:notesFileExtension) ? '' : g:notesFileExtension)
    endif
  endif
  return path
endfunction " }}}

function! notes#InstallAutoCmd() " {{{
  call notes#UninstallAutoCmd() " Avoid adding multiple.
  aug NoteSync
    au BufWritePost <buffer> :call <SID>HandleWrite()
  aug END
endfunction " }}}

function! s:HandleWrite() " {{{
  " Prevent a whole slew of problems that arise when cursor is not in the
  " buffer for which the autocommand is triggered (e.g., due to 'autowrite').
  if bufnr('%') != expand('<abuf>')
    return
  endif

  " Need to check for modified flag as BufWritePost gets triggered even when
  " the user chooses not to write when the file is updated outside.
  if !&modified && expand('%:p') == fnamemodify(expand('<afile>'), ':p') &&
        \ g:notesSyncNameAndTitle
    call feedkeys(":call notes#SyncCurrentNoteName()\<CR>\<C-G>", 'n')
  endif
endfunction " }}}

function! notes#UninstallAutoCmd() " {{{
  aug NoteSync
    au! BufWritePost <buffer>
  aug END
endfunction " }}}

function! notes#MonitorCurrentFile() " {{{
  if &buftype != ''
    " Excludes plugin and directory buffers.
    return
  endif
  if genutils#CommonPath(expand('%'), s:NotesRoot()) == genutils#CleanupFileName(s:NotesRoot())
    call notes#InstallAutoCmd()
    if &ft != 'note' && g:notesFileType != ''
      exec 'set ft='.g:notesFileType
    endif
  endif
endfunction " }}}

" Generate new (root) name from the current buffer contents.
function! notes#GenerateNoteName() " {{{
  for lineNr in range(1, line('$'))
    let line = getline(lineNr) 
    if line =~ '\w'
      let name = substitute(line, '[^[:alnum:]_ ]', '', 'g')
      let name = substitute(name, '^\s\+\|\s\+$', '', 'g')
      if name != ''
        return name[: g:notesMaxNameLenth-1]
      endif
    endif
  endfor
  return ''
endfunction " }}}

function! notes#NoteComplete(ArgLead, CmdLine, CursorPos) " {{{
  return s:NoteComplete(a:ArgLead, a:CmdLine, a:CursorPos, 0)
endfunction

function! notes#FolderCompleteForGrep(ArgLead, CmdLine, CursorPos)
  " Determine if we are completing a file or still in the pattern.
  let sepRE = genutils#CrUnProtectedCharsPattern(' ')
  let str = a:CmdLine[0 : a:CursorPos]
  let nWords = len(split(str, sepRE))
  if nWords > 2 || (nWords == 2 && str =~ sepRE.'$')
    return map(s:NoteComplete(a:ArgLead, a:CmdLine, a:CursorPos, 0), 'genutils#Escape(v:val, " ")')
  else
    return []
  endif
endfunction

function! notes#NoteFolderComplete(ArgLead, CmdLine, CursorPos)
  return s:NoteComplete(a:ArgLead, a:CmdLine, a:CursorPos, 1)
endfunction

function! s:NoteComplete(ArgLead, CmdLine, CursorPos, onlyDirs)
  return genutils#UserFileComplete2(a:ArgLead, a:CmdLine, a:CursorPos,
        \ {'searchPath': s:NotesRoot(), 'relativePaths': 1,
        \  'completionTypes': ['dir'] + (a:onlyDirs ? [] : ['file']),
        \  'anchorAtStart': g:notesCompleteAnchortAtStart})
endfunction " }}}

" Creates a new note and returns the path.
" This should really be the job of tempname(), but it doesn't accept the
" directory and prefix (like the Java's utility does)
function! notes#NewName(dir, prefix) " {{{
  let prefix = (a:prefix == '') ? g:notesDefaultName : a:prefix
  let prefix = substitute(prefix, ' ', g:notesWordSeparator, 'g')
  let pat = '^.*'.g:notesWordSeparator.'\(\d\+\)'.(g:notesFileExtension == '' ? '' : ((g:notesFileExtension[0] == '.' ? '\' : '') . g:notesFileExtension)).'$'
  let curSuffixes = sort(
        \ map(
        \     map(split(glob(a:dir.'/'.prefix.'*'.g:notesFileExtension), "\<NL>"),
        \         'substitute(v:val, pat, "\\1", "")'),
        \     'v:val + 0'),
        \ 's:NumCompare')
  let newSuffix = (len(curSuffixes) == 0) ? '' : g:notesWordSeparator.(curSuffixes[-1] + 1)
  let newNamePath = a:dir . '/' . prefix . newSuffix  . g:notesFileExtension
  " Just make sure we will not accidentally overwrite an existing file.
  if glob(newNamePath) != ''
    throw "Notes:Couldn't create a new note, found an existing note with the same name: " . newNamePath
  endif
  " This works like a touch command.
  if writefile([], newNamePath) != 0
    throw "Notes:writefile() failed to create new note: " . newNamePath
  endif
  return newNamePath
endfunction " }}}

function! s:NumCompare(i1, i2) " {{{
  return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunc " }}}

function! s:NoteRootName(noteName) " {{{
  let noteName = fnamemodify(a:noteName, ':t:r')
  return substitute(noteName, g:notesWordSeparator.'\d\+'.g:notesWordSeparator.'$', '', '')
endfunction " }}}

function! s:FileExists(file)
  let sizeCheck = getfsize(a:file)
  if sizeCheck == -2 || sizeCheck > 0
    return 1
  else
    return 0
  endif
endfunction

function! s:IsValidNotePath(path)
  if genutils#CommonPath(s:NotesRoot(), a:path) != genutils#CleanupFileName(s:NotesRoot())
    echohl ErrorMsg | echo 'Absolute path: ' . a:path .
          \ ' not under g:notesRoot: '.s:NotesRoot() | echohl NONE
    return 0
  endif
  return 1
endfunction

let s:_prevNotesRoot = ''
let s:_expandedNotesRoot = ''
function! s:NotesRoot()
  if s:_prevNotesRoot != g:notesRoot
    let s:_expandedNotesRoot = genutils#CleanupFileName(g:notesRoot)
    let s:_prevNotesRoot = g:notesRoot
  endif
  return s:_expandedNotesRoot
endfunction

let s:prevBrowseDir = s:NotesRoot()

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim6:fdm=marker et sw=2
