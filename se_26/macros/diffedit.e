////////////////////////////////////////////////////////////////////////////////////
// Copyright 2010 SlickEdit Inc. 
// You may modify, copy, and distribute the Slick-C Code (modified or unmodified) 
// only if all of the following conditions are met: 
//   (1) You do not include the Slick-C Code in any product or application 
//       designed to run independently of SlickEdit software programs; 
//   (2) You do not use the SlickEdit name, logos or other SlickEdit 
//       trademarks to market Your application; 
//   (3) You provide a copy of this license with the Slick-C Code; and 
//   (4) You agree to indemnify, hold harmless and defend SlickEdit from and 
//       against any loss, damage, claims or lawsuits, including attorney's fees, 
//       that arise or result from the use or distribution of Your application.
////////////////////////////////////////////////////////////////////////////////////
#pragma option(pedantic,on)
#region Imports
/**
 * [?4/?27/?2017 4:08 PM]
OK, I do svn-history on macros/diffedit.e (from the trunk), select r61182 and diff with r60875, and it gives me revisions 60875 and 59311.
It claims that it’s giving the right versions, but you can see the $VERSION string that they aren’t.
I mean $Revision comment.

 */
#include "slick.sh"
#include "diff.sh"
#include "markers.sh"
#include "vsevents.sh"
#include "markers.sh"
#import "se/lang/api/LanguageSettings.e"
#import "alias.e"
#import "clipbd.e"
#import "codehelp.e"
#import "compile.e"
#import "complete.e"
#import "context.e"
#import "cua.e"
#import "diff.e"
#import "diffmf.e"
#import "difftags.e"
#import "dlgman.e"
#import "error.e"
#import "fileman.e"
#import "fileproject.e"
#import "files.e"
#import "guifind.e"
#import "guiopen.e"
#import "help.e"
#import "hex.e"
#import "html.e"
#import "keybindings.e"
#import "main.e"
#import "markfilt.e"
#import "menu.e"
#import "mouse.e"
#import "mprompt.e"
#import "picture.e"
#import "pmatch.e"
#import "project.e"
#import "projutil.e"
#import "saveload.e"
#import "search.e"
#import "seek.e"
#import "slickc.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "se/vc/IVersionControl.e"
#import "svc.e"
#import "svcupdate.e"
#import "svcautodetect.e"
#import "tags.e"
#import "util.e"
#import "vicmode.e"
#import "viimode.e"
#import "wfont.e"
#import "window.e"
#import "xml.e"
#import "se/vc/GitClass.e"
#endregion


static const MATCHING_LINE= 0x0;
static const INSERTED_LINE= 0x1;
static const CHANGED_LINE=  0x2;
static const DELETED_LINE=  0x4;


using se.vc.IVersionControl;
using se.lang.api.LanguageSettings;

void _diffedit_UpdateForm();
static bool in_cua_select;
static DIFF_UPDATE_INFO gDiffUpdateInfo={-1};
static int LastActiveEditWindowWID=0;

static void diff_quote_key();
static void diff_select_line();
static void diff_select_word();
static void diff_select_full_word();
static void diff_select_whole_word();
static void diff_select_subword();
static void diff_select_char();
static void diff_cua_select();
static void diff_deselect();
static void diff_mode_split_insert_line();
static void diff_multi_delete(...);
static void diff_rubout();
static void diff_linewrap_rubout();
static void diff_linewrap_delete_char(...);
static void diff_delete_char();
static void diff_cut_line();
static void diff_delete_line();
static void diff_paste();
static void diff_list_clipboards();
static void diff_copy_to_clipboard();
static void diff_copy_word();
static void diff_move_text_tab();
static void diff_ctab();
static void diff_cut_end_line();
static void diff_cut_word();
static void diff_delete_word();
static void diff_prev_word();
static void diff_next_word();
static void diff_complete_prev();
static void diff_complete_next();
static void diff_complete_more();
static int diff_find_next();
static int diff_find_prev();

static void diff_bas_enter();
static void diff_c_enter();
static void diff_cmd_enter();
static void diff_for_enter();
static void diff_pascal_enter();
static void diff_prg_enter();

static void diff_mode_space();
static void diff_expand_alias();
static void diff_undo();
static void diff_undo_cursor();
static void diff_command(...);
static void diff_command_and_update(...);
static void diff_maybe_deselect_command(...);
static void diff_shift_selection_right();
static void diff_shift_selection_left();
static void diff_maybe_complete();
static void diff_close_form();
static void diff_next_window(bool find_backward=false);
static int diff_exit();
static void diff_mou_click();
static void diff_cursor_left();
static void diff_cursor_right();
static void diff_mou_select_word();
static void diff_mou_select_line();
static void diff_end_line();
static void diff_find_matching_paren();
static void diff_join_line();
static void diff_find(...);
static void diff_mou_extend_selection();
static void diff_push_tag();
static void diff_pop_bookmark();
static void diff_cbacktab();
static void diff_next_proc();
static void diff_prev_proc();
static void diff_next_tag();
static void diff_prev_tag();
static void diff_html_key();
static void diff_find_backwards();
static void diff_right_side_of_window();
static void diff_left_side_of_window();
static void diff_vi_restart_word();
static void diff_vi_ptab();
static void diff_vi_pbacktab();
static void diff_vi_begin_next_line();
static void diff_codehelp_complete();
static int diff_quit();
static void diff_gui_goto_line();
static void diff_fast_scroll();
static void diff_scroll_page_down();
static void diff_scroll_page_up();
static int diff_next_difference(_str direction="",_str noMessagesMessage="");
static int diff_prev_difference();
static void diff_paste_replace_word();

struct DiffCommandInfo {
   bool supportedInStandardEdition;
   typeless typelessCommand;
};

//Don't put any of the "maybe-case-word" commands or "maybe-case-backspace"
//commands in this list.
static DiffCommandInfo DiffCommands:[]={
   "wh"                        => { true, wh },
   "list-symbols"              => { false, list_symbols },
   "function-argument-help"    => { false, function_argument_help },
   "quote-key"                 => { false, diff_quote_key },
   "maybe-complete"            => { false, diff_maybe_complete },
   "split-insert-line"         => { false, diff_mode_split_insert_line },
   "maybe-split-insert-line"   => { false, diff_mode_split_insert_line },
   "nosplit-insert-line"       => { false, diff_mode_split_insert_line },
   "nosplit-insert-line-above" => { false, diff_mode_split_insert_line },
   "rubout"                    => { false, diff_rubout },
   "linewrap-rubout"           => { false, diff_linewrap_rubout },
   "linewrap-delete-char"      => { false, diff_linewrap_delete_char },
   "vi-forward-delete-char"    => { false, diff_linewrap_delete_char },
   "delete-char"               => { false, diff_delete_char },
   "cut-line"                  => { false, diff_cut_line },
   "join-line"                 => { false, diff_join_line },
   "cut"                       => { false, diff_cut_line },
   "delete-line"               => { false, diff_delete_line },
   "brief-delete"              => { false, diff_linewrap_delete_char },
   "list-clipboards"           => { false, diff_list_clipboards },
   "paste"                     => { false, diff_paste },
   "paste-replace-word"        => { false, diff_paste_replace_word },
   "brief-paste"               => { false, diff_paste },
   "emacs-paste"               => { false, diff_paste },
   "find-next"                 => { false, diff_find_next },
   "search-again"              => { true, diff_find_next },
   "ispf-rfind"                => { false, diff_find_next },
   "find-prev"                 => { false, diff_find_prev },

   "c-enter"                   => { false, diff_mode_split_insert_line },
   "c-space"                   => { false, diff_mode_space },

   "html-enter"                => { false, diff_mode_split_insert_line },

   "slick-enter"               => { false, diff_mode_split_insert_line },
   "slick-space"               => { false, diff_mode_space },

   "cmd-enter"                 => { false, diff_mode_split_insert_line },
   "cmd-space"                 => { false, diff_mode_space },

   "for-enter"                 => { false, diff_mode_split_insert_line },
   "for-space"                 => { false, diff_mode_space },

   "sql-enter"                 => { false, diff_mode_split_insert_line },
   "sql-space"                 => { false, diff_mode_space },

   "plsql-enter"               => { false, diff_mode_split_insert_line },
   "plsql-space"               => { false, diff_mode_space },

   "sqlserver-enter"           => { false, diff_mode_split_insert_line },
   "sqlserver-space"           => { false, diff_mode_space },

   "pascal-enter"              => { false, diff_mode_split_insert_line },
   "pascal-space"              => { false, diff_mode_space },

   "prg-enter"                 => { false, diff_mode_split_insert_line },
   "prg-space"                 => { false, diff_mode_space },

   "expand-alias"              => { false, diff_expand_alias },

   "undo"                      => { true, diff_undo },
   "undo-cursor"               => { true, diff_undo },
   "select-line"               => { true, diff_select_line },
   "brief-select-line"         => { true, diff_select_line },
   "select-char"               => { true, diff_select_char },
   "brief-select-char"         => { true, diff_select_char },
   "cua-select"                => { true, diff_cua_select },
   "deselect"                  => { true, diff_deselect },
   "shift-selection-right"     => { true, diff_shift_selection_right },
   "shift-selection-left"      => { true, diff_shift_selection_left },
   "copy-to-clipboard"         => { true, diff_copy_to_clipboard },
   "append-to-clipboard"       => { true, diff_append_to_clipboard },
   "copy-word"                 => { true, diff_copy_word },

   "select-word"               => { false, diff_select_word },
   "select-whole-word"         => { false, diff_select_whole_word },
   "select-full-word"          => { false, diff_select_full_word },
   "select-subword"            => { false, diff_select_subword },

   "next-window"               => { true, diff_next_window },
   "prev-window"               => { true, diff_next_window },
   //I can get away with this because there are only 2 windows!!!

   "bottom-of-buffer"          => { true, {diff_maybe_deselect_command,bottom_of_buffer} },

   "top-of-buffer"             => { true, {diff_maybe_deselect_command,top_of_buffer} },

   "page-up"                   => { true, {diff_maybe_deselect_command,page_up} },

   "vi-page-up"                => { true, {diff_maybe_deselect_command,page_up} },

   "page-down"                 => { true, {diff_maybe_deselect_command,page_down} },

   "vi-page-down"              => { true, {diff_maybe_deselect_command,page_down} },

   "cursor-left"               => { true, {diff_maybe_deselect_command,cursor_left} },
   "vi-cursor-left"            => { true, {diff_maybe_deselect_command,cursor_left} },

   "cursor-right"              => { true, {diff_maybe_deselect_command,cursor_right} },
   "vi-cursor-right"           => { true, {diff_maybe_deselect_command,cursor_right} },

   "cursor-up"                 => { true, {diff_maybe_deselect_command,cursor_up} },
   "vi-prev-line"              => { true, {diff_maybe_deselect_command,cursor_up} },

   "cursor-down"               => { true, {diff_maybe_deselect_command,cursor_down} },
   "vi-next-line"              => { true, {diff_maybe_deselect_command,cursor_down} },

   "begin-line"                => { true, {diff_maybe_deselect_command,begin_line} },

   "begin-line-text-toggle"    => { true, {diff_maybe_deselect_command,begin_line_text_toggle} },

   "brief-home"                => { true, {diff_maybe_deselect_command,begin_line} },

   "vi-begin-line"             => { true, {diff_maybe_deselect_command,begin_line} },

   "vi-begin-line-insert-mode" => { true, {diff_maybe_deselect_command,begin_line} },

   "brief-end"                 => { true, {diff_maybe_deselect_command,end_line} },

   //"end-line"                => { true, {diff_maybe_deselect_command,end_line} },

   "end-line"                  => { true, diff_end_line },
   "end-line-text-toggle"      => { true, {diff_maybe_deselect_command,end_line_text_toggle} },
   "end-line-ignore-trailing-blanks" => { true, {diff_maybe_deselect_command,end_line_ignore_trailing_blanks} },

   "vi-end-line"               => { true, {diff_maybe_deselect_command,end_line} },

   "vi-end-line-append-mode"   => { true, {diff_maybe_deselect_command,end_line} },
   "mou-click"                 => { true, diff_mou_click },
   "mou-extend-selection"      => { true, diff_mou_extend_selection },
   "mou-select-word"           => { true, diff_mou_select_word },
   "mou-select-line"           => { true, diff_mou_select_line },
   "move-text-tab"             => { false, diff_move_text_tab },
   "vi-move-text-tab"          => { false, diff_move_text_tab },
   "move-text-tab"             => { false, diff_move_text_tab },
   "ctab"                      => { false, diff_ctab },
   "cbacktab"                  => { false, diff_cbacktab },
   "brief-tab"                 => { false, diff_move_text_tab },
   "smarttab"                  => { false, diff_ctab },
   "gnu-ctab"                  => { false, diff_ctab },
   "c-tab"                     => { false, diff_ctab },
   "cob-tab"                   => { false, diff_ctab },
   "cut-end-line"              => { false, diff_cut_end_line },
   "cut-word"                  => { false, diff_cut_word },
   "delete-word"               => { false, diff_delete_word },
   "prev-word"                 => { true, diff_prev_word },
   "next-word"                 => { true, diff_next_word },
   "complete-prev"             => { false, diff_complete_prev },
   "complete-next"             => { false, diff_complete_next },
   "complete-more"             => { false, diff_complete_more },
   "save"                      => { true, _diff_save },
   "brief-save"                => { true, _diff_save },
   "c-endbrace"                => { false, c_endbrace },
   "find-matching-paren"       => { true, diff_find_matching_paren },
   "gui-find"                  => { true, diff_find },
   "push-tag"                  => { false, diff_push_tag },
   "pop-bookmark"              => { false, diff_pop_bookmark },
   "next-proc"                 => { false, diff_next_proc },
   "prev-proc"                 => { false, diff_prev_proc },
   "next-tag"                  => { false, diff_next_tag },
   "prev-tag"                  => { false, diff_prev_tag },
   "html-key"                  => { false, diff_html_key },
   "search-forward"            => { true, diff_find },
   "search-backward"           => { true, diff_find_backwards },
   "gui-find-backward"         => { true, diff_find_backwards },
   "re-toggle"                 => { true, re_toggle },
   "case-toggle"               => { true, case_toggle },
   "right-side-of-window"      => { true, diff_right_side_of_window },
   "left-side-of-window"       => { true, diff_left_side_of_window },
   "vi-restart-word"           => { true, diff_vi_restart_word },
   "vi-ptab"                   => { false, diff_vi_ptab },
   "vi-pbacktab"               => { false, diff_vi_pbacktab },
   "vi-begin-next-line"        => { true, diff_vi_begin_next_line },
   "codehelp-complete"         => { false, diff_codehelp_complete },
   "quit"                      => { true, diff_quit },
   "close-window"              => { true, diff_quit },
   "safe-exit"                 => { true, diff_quit },
   "insert-toggle"             => { true, insert_toggle },
   "gui-goto-line"             => { true, diff_gui_goto_line },
   "fast-scroll"               => { true, diff_fast_scroll },
   "scroll-page-down"          => { true, diff_scroll_page_down },
   "scroll-page-up"            => { true, diff_scroll_page_up },
   "diff-next-diff"            => { true, diff_next_difference },
   "diff-prev-diff"            => { true, diff_prev_difference },
   "view-specialchars-toggle"  => { false, view_specialchars_toggle },
   "view-line-numbers-toggle"  => { false, view_line_numbers_toggle },
   "diff-close-and-edit"       => { false, diff_close_and_edit },
   "wfont-zoom-in"             => { true, {diff_command_and_update, wfont_zoom_in }},
   "wfont-zoom-out"            => { true, {diff_command_and_update, wfont_zoom_out }},
   "wfont-unzoom"              => { true, {diff_command_and_update, wfont_unzoom }},
};

#if 0 //4:17pm 5/10/2019
/**
 * Commands added here will give a message that the command 
 * cannot be run in diff and offer the user a chance to close 
 * the diff and run the command. 
 * 
 */
static _str DiffCloseAndRunCommands:[]={
   "project-build" =>  1 ,
   "load"          =>  1 ,
};
#endif

static DIFF_DELETE_ITEM gBufferListTable:[][];

static int _dont_use_diff_command=0;

definit()
{
   gDiffUpdateInfo.timer_handle=-1;
   gDiffUpdateInfo.list._makeempty();
   gBufferListTable._makeempty();
   _dont_use_diff_command = 0;
}

#if 0 //4:17pm 5/10/2019
static int diff_close_and_run_command(_str command_name) 
{
   result := _message_box(nls("The %s command cannot be run in diff\n\nWould you like to close diff and run it now?",command_name),"",MB_YESNO);
   if ( result == IDYES ) {
      name_index := find_index(command_name,COMMAND_TYPE);
      diff_close_form();
      if ( _no_child_windows() ) {
         call_index(name_index);
      } else {
         origWID := p_window_id;
         p_window_id = _mdi.p_child;
         call_index(name_index);
         p_window_id = origWID;
      }
      return 1;
   }
   return 0;
}
#endif

static void diffSetSuspendStatus(int bufID,bool suspendStatus,int dataWID)
{
   DIFF_DELETE_ITEM itemList[];
   if ( dataWID==0 ) {
      _nocheck _control _ctlfile1;
      dataWID = _ctlfile1;
   }
   _DiffGetDeleteList(itemList,dataWID);
   
   for ( i:=0;i<itemList._length();++i ) {
      int curBufID;
      if ( itemList[i].isView ) {
         curBufID = itemList[i].item.p_buf_id;
      }else{
         curBufID = itemList[i].item;
      }

      if ( curBufID == bufID ) {
         itemList[i].isSuspended = suspendStatus;
      }
   }

   _DiffSetDeleteList(itemList,dataWID);
}

/**
 * @param bufID id to suspend status for
 * 
 */
void _DiffSuspendDelete(int bufID, int dataWID=0)
{
   diffSetSuspendStatus(bufID,true,dataWID);
}

void _DiffDumpBufferList(_str label="")
{
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   say('_DiffDumpBufferList 'label);
   for ( origBufID:=p_buf_id;; ) {
      say('    p_buf_id='p_buf_id' p_buf_name='p_buf_name);
      _next_buffer('hnr');
      if ( p_buf_id==origBufID ) break;
   }
   p_window_id = origWID;
}

bool _DiffIsDeleteSuspended(int bufID)
{
   DIFF_DELETE_ITEM itemList[];
   _nocheck _control _ctlfile1;
   _DiffGetDeleteList(itemList,_ctlfile1);
   
   for ( i:=0;i<itemList._length();++i ) {
      int curBufID;
      if ( itemList[i].isView ) {
         curBufID = itemList[i].item.p_buf_id;
      }else{
         curBufID = itemList[i].item;
      }

      if ( curBufID == bufID ) {
         return itemList[i].isSuspended;
      }
   }
   return false;
}

static void setMarkerID(int &origFilePosMarker)
{
   save_pos(auto p);
   while ( _lineflags()&NOSAVE_LF ) {
      if ( up() ) break;
   }
   if ( !p_line ) {
      restore_pos(p);
      while ( _lineflags()&NOSAVE_LF ) {
         if ( down() ) break;
      }
   }
   origFilePosMarker=_alloc_selection('B');
   if (origFilePosMarker>=0) {
      _select_char(origFilePosMarker);
   }
   restore_pos(p);
}

defeventtab _diff_form;

void ctloptions.lbutton_up()
{
   orig_diff_flags := def_diff_flags;
   show('-modal _diffsetup_form','',true,false,null,true);
   if ( orig_diff_flags!=def_diff_flags ) {
      _config_modify_flags(CFGMODIFY_DEFVAR);
      result := _message_box(nls("Re-Diff files now?"),"",MB_YESNO);
      if ( result==IDYES ) {
         _control _ctlfile1;
         _SetDialogInfoHt("lastDiffOptions",null,_ctlfile1);
         ctlrediff.call_event(ctlrediff,LBUTTON_UP);
      }
   }
}

static void diff_goto_line(int lineNumber,bool useRLine=true)
{
   _str old_scroll_style=_scroll_style();
   _scroll_style('c');

   if ( useRLine ) {
      p_RLine= lineNumber;
   } else {
      p_line = lineNumber;
   }

   _scroll_style(old_scroll_style);
}

static int getFirstLineOffset(int firstLine)
{
   if ( firstLine==0 ) {
      return 0;
   }
   return firstLine-1;
}

void _ctlfile1line.lbutton_up()
{
   if ( _DiffGetLineNumLabelsMissing()==1 ) {
      // This shouldn't be able to happen
      return;
   }
   editorWID := _control _ctlfile1;
   otherWID  := _control _ctlfile2;
   if ( p_name == "_ctlfile2line" ) {
      editorWID = _control _ctlfile2;
      otherWID  = _control _ctlfile1;
   }
   getFirstLines(auto firstLine1,auto firstLine2);
   currentFirstLine := 0;
   if ( editorWID == _ctlfile1 ) {
      currentFirstLine = firstLine1;
   } else {
      currentFirstLine = firstLine2;
   }

   result := textBoxDialog("Go to line",          // Caption
                           TB_RETRIEVE,
                           0,
                           "line navigation", 
                           prompt1:"-r "currentFirstLine','(editorWID.p_Noflines-editorWID.p_NofNoSave+currentFirstLine-1)" Line Number ("currentFirstLine" - "editorWID.p_RNoflines+currentFirstLine-1'):'editorWID.p_RLine+currentFirstLine-1);
   if ( result==COMMAND_CANCELLED_RC ) {
      return;
   }

   if ( result=="" ) return;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');

   lineNumber := _param1-(currentFirstLine-1);
   _param1 = "";

   editorWID.diff_goto_line(lineNumber);
   otherWID.diff_goto_line(editorWID.p_line,false);

   // Update the line number indicators
   _ctlfile1line.p_caption=_ctlfile1.p_RLine+getFirstLineOffset(firstLine1)'/'(_ctlfile1.p_Noflines-_ctlfile1.p_NofNoSave+getFirstLineOffset(firstLine1));
   _ctlfile2line.p_caption=_ctlfile2.p_RLine+getFirstLineOffset(firstLine2)'/'(_ctlfile2.p_Noflines-_ctlfile2.p_NofNoSave+getFirstLineOffset(firstLine2));
}

int _diff_copy_button(int markerType,int markerIndex)
{
   // Markers are deleted in diff_copy_block


   _control _ctlcopy_left;
   _control _ctlcopy_right;
   copyLeftType := _GetDialogInfoHt("copyLeftType",_ctlfile1);
   copyRightType := _GetDialogInfoHt("copyRightType",_ctlfile1);
   _ctlfile1.diff_deselect();
   _ctlfile2.diff_deselect();
   _LineMarkerGet(markerIndex,auto info);

   _ctlfile1.p_line = info.LineNum;
   _ctlfile2.p_line = info.LineNum;

   status := 0;

   if ( markerType==copyLeftType ) {
      status = _ctlcopy_left.call_event(_ctlcopy_left,LBUTTON_UP);
   } else if ( markerType==copyRightType ) {
      if ( _find_control('_ctlcopy_right') ) {
         status = _ctlcopy_right.call_event(_ctlcopy_right,LBUTTON_UP);
      } else if ( _find_control('ctlCopyBlock') ) {
         _nocheck _control ctlCopyBlock;
         status = ctlCopyBlock.call_event(ctlCopyBlock,LBUTTON_UP);
      } 
   }

   rc = status;
   return status;
}

void ctltypetoggle.lbutton_up()
{
   _SetDialogInfoHt("inTypeToggle",1,_ctlfile1);
   // if file 2 was copy used for Source diff, realFile2Name is set to the the name
   // of the file that it is a copy of
   realFile2Name := "";
   sourceDiff := false;

   // Check the caption.  We don't actually change it because the dialog is 
   // going to be closed and relaunched.
   if ( p_caption=="Source Diff" ) {
      sourceDiff = true;
   }else if ( p_caption=="Line Diff" ) {
      _str FileTitles=_DiffGetDialogTitles();
      File1Title := strip(parse_file(FileTitles),'B','"');
      File2Title := strip(parse_file(FileTitles),'B','"');
      realFile2Name = _DiffStripFileOrBufferFromCaption(File2Title);
   }

   _nocheck _control _ctlfile1;
   _str bufInfo1=_GetDialogInfo(DIFFEDIT_CONST_BUFFER_INFO1,_ctlfile1);
   _str bufInfo2=_GetDialogInfo(DIFFEDIT_CONST_BUFFER_INFO2,_ctlfile1);
   _str VCDiffType=_GetDialogInfo(DIFFEDIT_VC_DIFF_TYPE,_ctlfile1);
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   DIFF_READONLY_TYPE readOnly1=_GetDialogInfo(DIFFEDIT_READONLY1_VALUE,_ctlfile1);
   DIFF_READONLY_TYPE readOnly2=_GetDialogInfo(DIFFEDIT_READONLY2_VALUE,_ctlfile1);
   parse bufInfo1 with auto bufID1 auto file1inmem auto file1readonly;
   parse bufInfo2 with auto bufID2 auto file2inmem auto file2readonly;

   _ctlfile1.setMarkerID(auto origFile1PosMarker);
   _SetDialogInfoHt("origFile1PosMarker",origFile1PosMarker,_ctlfile1);
   seek := _ctlfile1._QROffset();
   bufID1 = misc.buffer1.WholeFileBufId;
   bufID2 = misc.buffer2.WholeFileBufId;
   closeBuffer2Option := misc.closeBuffer2 ? " -internalclosebuffer2 " : "";



   wasModal := p_active_form.p_modal;
   formWID := p_active_form;
   status := _ctlclose.call_event(_ctlclose,LBUTTON_UP);

   // Build string of buffer and window IDs to pass to diff to remember to delete
   // when we aren't toggling
   DIFF_DELETE_ITEM itemList[] = gBufferListTable:[formWID];
   itemListOption := "";
   if ( itemList._length()>0 ) {
      for (i:=0;i<itemList._length();++i) {
         windowStr := itemList[i].isView?"w:":"";
         if (i==0) {
            itemListOption = "-deletebufferlist "windowStr:+itemList[i].item;
         } else {
            itemListOption = itemListOption :+ ","windowStr:+itemList[i].item;
         }
      }
   }
   gBufferListTable._deleteel(formWID);

   if ( VCDiffType!="") {
      // If this is a version control diff, set a global variable for the type
      // The caller will have to call diff again with the proper option.
      _param1 = sourceDiff?"code":"line";
      return;
   }
   // At this point, file 1 is open, because we set its inmem state
   // to 1. File 2 is open if it was a 'real' file.  If it was a
   // copy made for source diff, we let it close

   modalOption :=  wasModal? "-modal":"";
   _str sourceDiffOptions = sourceDiff ? "-sourcediff" : "";
   _str readOnly1Option = readOnly1==DIFF_READONLY_SET_BY_USER ? "-r1" : "";
   _str readOnly2Option = readOnly2==DIFF_READONLY_SET_BY_USER ? "-r2" : "";
   _str diffParentOption = misc.DiffParentWID ? "-RegisterAsMFDChild "misc.DiffParentWID : "";
   file2Option := "";
   file2Spec := "";
   if ( realFile2Name=="" ) {
      file2Spec = bufID2;
      file2Option  = "-bi2";
   }else{
      file2Spec = _maybe_quote_filename(realFile2Name);
   }

   diff(sourceDiffOptions:+' ':+itemListOption:+' ':+readOnly1Option:+' ':+closeBuffer2Option:+' ':+diffParentOption' ':+modalOption:+' -point ':+seek' ':+readOnly2Option:+' -bi1 ':+file2Option:+' -bufferstate1 'file1inmem' -bufferstate2 'file2inmem' 'bufID1' 'file2Spec);
}


static int getDiffFormFromBufID(int bufID)
{
   last := _last_window_id();
   formWID := 0;

   for (i:=1; i<=last; ++i) {
      if (_iswindow_valid(i) && 
          (i.p_name=="_ctlfile1" || i.p_name=="_ctlfile2") &&
          (i.p_parent) && _isdiff_form(i.p_parent.p_name) ) {
         if (!bufID || bufID==i.p_buf_id) {
            if (!i.p_edit && i.p_visible) {
               return i.p_parent;
            }
         }
      }
   }
   return(0);
}

/** 
 * Change the in memory status of bufID.  This is used in case a 
 * file was diffed and not already open in the editor, and then 
 * is opened while the file is being diffed. 
 */
static void changeInMem(int bufID,bool newInMem)
{
   formWID := getDiffFormFromBufID(bufID);
   if (formWID!=null) {
      index := 0;
      if (formWID._ctlfile1.p_buf_id==bufID) {
         index = DIFFEDIT_CONST_BUFFER_INFO1;
      }else if (formWID._ctlfile2.p_buf_id==bufID) {
         index = DIFFEDIT_CONST_BUFFER_INFO2;
      }
      bufInfo := _GetDialogInfo(index,formWID._ctlfile1);
      if (bufInfo!=null) {
         parse bufInfo with auto diffBufID auto fileInMem auto fileReadOnly;
         bufInfo = diffBufID' 'newInMem' 'fileReadOnly;
         _SetDialogInfo(index,bufInfo,formWID._ctlfile1);
      }
   }
}

/** 
 * This is called when a file that was not already open when it 
 * was diffed is opened and unhidden. 
 */
void _cbmdibuffer_unhidden_diffedit()
{
   if (_isdiffed(p_buf_id)) {
      last := _last_window_id();

      // Find the diff dialog that has this buffer
      formWID := getDiffFormFromBufID(p_buf_id);
      if (formWID) {
         // Tell the editor that the file was already in memmory so the 
         // readonly property is reset properly
         changeInMem(p_buf_id,true);

         // Remove the buffer ID from the list of buffers to be deleted
         removeFromDeleteList(p_buf_id,formWID);

         // Set a flag to blast the undo when we close the diff, because since
         // the file was opened after the diff was already opened, we cannot
         // let the user undo into where the imaginary lines were inserted
         _SetDialogInfoHt("blastUndoInfo:"p_buf_id,1,formWID._ctlfile1);
      }
   }
}

static void removeFromDeleteList(int bufID,int formWID)
{
   _DiffGetDeleteList(auto deleteList,formWID._ctlfile1);
   len := deleteList._length();
   for (i:=0;i<len;++i) {
      curBufID := 0;
      if (deleteList[i].isView) {
         curBufID = deleteList[i].item.p_buf_id;
      } else {
         curBufID = deleteList[i].item;
      }
      if ( bufID == curBufID ) {
         deleteList._deleteel(i);
         break;
      }
   }
   _DiffSetDeleteList(deleteList,formWID._ctlfile1);
}

void _ctlfile1_readonly.lbutton_up()
{
   _ctlfile1.p_ProtectReadOnlyMode=(p_value)?VSPROTECTREADONLYMODE_ALWAYS:VSPROTECTREADONLYMODE_NEVER;
}
void _ctlfile2_readonly.lbutton_up()
{
   _ctlfile2.p_ProtectReadOnlyMode=(p_value)?VSPROTECTREADONLYMODE_ALWAYS:VSPROTECTREADONLYMODE_NEVER;
}

const REMOTE_HIDDEN_STRING = "remote/hidden:";
_str _DiffStripFileOrBufferFromCaption(_str name)
{
   
   if ( beginsWith(name,REMOTE_HIDDEN_STRING) ) {
      name = substr(name,length(REMOTE_HIDDEN_STRING)+1);
   }
   p := lastpos('(',name);
   if (p<2) {
      return(name);
   }
   return(substr(name,1,p-1));
}

/**
 * Form with editors and scroll bars must be active when this is called
 */
void _DiffSetupScrollBars()
{
   vscroll1.p_max=_ctlfile1.p_Noflines-_ctlfile1.p_char_height;

   vscroll1.p_large_change=_ctlfile1.p_char_height-1;
   _DiffVscrollSetLast(vscroll1.p_value);

   _DiffHscrollSetLast(hscroll1.p_value);
}

#if 1 /*__MACOSX__*/
    void macSetStandaloneDiffzilla(int formWid);
#endif

static int diff_push_tag_in_file(_str proc_name, _str file_name, _str class_name, _str type_name, int line_no)
{
   diff_push_tag_line(line_no);
   return 0;
}

void _DiffFile1OnCreate(_str name1NoType='', _str name2NoType='', _str diffOptions='')
{
   if (_isMac()) {
      if(_default_option(VSOPTION_MDI_SHOW_WINDOW_FLAGS) == SW_HIDE) {
          macSetStandaloneDiffzilla(p_active_form);
      }
   }
   call_list('_diffOnStart_');
   _DiffSetupScrollBars();
   _DiffSetNeedRefresh(true);
   LastActiveEditWindowWID=_ctlfile1;
   isDiff := diffOptions=='diff';
   isSVCUpdate := diffOptions=='svcupdate';
   if ( _find_control('_ctlfile1label') ) {
      // Because of clipboard inheritance, these may not be there
      _ctlfile1label.p_caption=name1NoType;
      _ctlfile2label.p_caption=name2NoType;
   }else{
      _DiffSetFileLabelsMissing();
   }
   name1NoType=_DiffStripFileOrBufferFromCaption(name1NoType);
   name2NoType=_DiffStripFileOrBufferFromCaption(name2NoType);
   if ( !_find_control('_ctlfile1line') ) {
      _DiffSetLineNumLabelsMissing();
   }
   if ( !_find_control('_ctlfile1_readonly') ) {
      _DiffSetReadOnlyCBMissing();
   }
   if ( !_find_control('_ctlnext_difference') ) {
      _DiffSetNextDiffMissing();
   }
   if ( !_find_control('_ctlclose') ) {
      _DiffSetCloseMissing();
   }
   if ( !_find_control('_ctlcopy_right') ) {
      _DiffSetCopyMissing();
   }
   if ( !_find_control('_ctlcopy_left') ) {
      _DiffSetCopyLeftMissing();
   }

   _DiffSetDialogTitles(name1NoType,name2NoType);
   _ctlfile1.p_scroll_left_edge=-1;
   _ctlfile2.p_scroll_left_edge=-1;

   foundContextCombo := _find_control("ctlcontextCombo1");
   if (_haveCurrentContextToolBar() && foundContextCombo && !(def_diff_edit_flags&DIFFEDIT_HIDE_CURRENT_CONTEXT)) {
      ctlcontextCombo1.context_window_set_editor_wid(_ctlfile1);
      ctlcontextCombo2.context_window_set_editor_wid(_ctlfile2);

      ctlcontextCombo1.context_window_set_push_tag_pointer(diff_push_tag_in_file);
      ctlcontextCombo2.context_window_set_push_tag_pointer(diff_push_tag_in_file);
   } else if (foundContextCombo) {
      ctlcontextCombo1.p_enabled = ctlcontextCombo2.p_enabled = false;
      ctlcontextCombo1.p_visible = ctlcontextCombo2.p_visible = false;
   }

   if ( p_active_form.p_name=='_diff_form' ||
        p_active_form.p_name=='_svc_mfupdate_form') {
      if (!VF_IS_STRUCT(gDiffUpdateInfo)) {
         gDiffUpdateInfo.timer_handle=-1;
      }
      len := gDiffUpdateInfo.list._length();
      gDiffUpdateInfo.list[len].wid = p_active_form;
      gDiffUpdateInfo.list[len].isDiff = isDiff;
      gDiffUpdateInfo.list[len].isSVCUpdate = p_active_form.p_name=='_svc_mfupdate_form';
      gDiffUpdateInfo.list[len].needToSetupHScroll = false;

      if (gDiffUpdateInfo.timer_handle<0) {
         gDiffUpdateInfo.timer_handle=_set_timer(100,_diffedit_UpdateForm);
      }
   }

   _SetDialogInfo(DIFFEDIT_CONST_HAS_MODIFY,false);
}

void _ctlfile1.on_create(_str name1NoType="", _str name2NoType="", _str diffOptions="")
{
   _DiffFile1OnCreate(name1NoType,name2NoType,diffOptions);
}

void _DiffAddWindow(int wid,bool isDiff)
{
   len := gDiffUpdateInfo.list._length();
   gDiffUpdateInfo.list[len].wid=wid;
   gDiffUpdateInfo.list[len].isDiff=isDiff;
   gDiffUpdateInfo.list[len].needToSetupHScroll=false;           
   if (gDiffUpdateInfo.timer_handle<0) {
      gDiffUpdateInfo.timer_handle=_set_timer(100,_diffedit_UpdateForm);
   }
}

void _DiffKillUpdateTimer()
{
   if ( gDiffUpdateInfo.timer_handle>0 ) {
      _kill_timer(gDiffUpdateInfo.timer_handle);
   }
   gDiffUpdateInfo.timer_handle=-1;
}

void _DiffRemoveWindow(int wid,bool isDiff)
{
   for (i:=0;i<gDiffUpdateInfo.list._length();++i) {
      if (gDiffUpdateInfo.list[i].wid==wid) {
         gDiffUpdateInfo.list._deleteel(i);

         break;
      }
   }
   if (!gDiffUpdateInfo.list._length() && gDiffUpdateInfo.timer_handle>-1) {
      _kill_timer(gDiffUpdateInfo.timer_handle);
      gDiffUpdateInfo.timer_handle=-1;
   }
}

static bool isNotFileOrBuffer()
{
   parse p_caption with '(' auto fileBufferOrVersion ')';
   if ( lowcase(fileBufferOrVersion)!="file" && lowcase(fileBufferOrVersion)!="buffer" ) {
      return true;
   }
   return false;
}

/** 
 * Version numbers, not "File" or "Buffer" 
 */
static bool bothSidesHaveVersions()
{
   if (pos('Backup History',p_active_form.p_caption) ) {
      _nocheck _control ctltype_combo;
      return ctltype_combo.p_text != LOCAL_FILE_CAPTION;
   }else{
      return _ctlfile1label.isNotFileOrBuffer() && _ctlfile2label.isNotFileOrBuffer();
   }
}

static edit_window_rbutton_up()
{
   if (!select_active()) {
      mou_click();
   }

   otherwid := GetOtherWid(auto wid);
   otherwid.p_line = p_line;

   inImaginary := _lineflags() & NOSAVE_LF;
   int index=find_index("_diff_menu",oi2type(OI_MENU));
   int menu_handle=_mdi._menu_load(index,'P');
   int x,y;
   mou_get_xy(x,y);
   status := _menu_find(menu_handle,"diff-edit-menu align", auto outputHandle, auto outputMenuPos, 'M');
   if (pos('Backup History',p_active_form.p_caption)) {
      // Have to check for this because we want to allow this for the left 
      // pane in backup history, as long as the left pane is actually the
      // current file.
      _nocheck _control ctltype_combo;
      if (p_name=='_ctlfile2' || ctltype_combo.p_text!=LOCAL_FILE_CAPTION) {
         _menu_delete(outputHandle,outputMenuPos);
      }
   } else {
      if ( p_name=='_ctlfile2' && _ctlfile2_readonly.p_value ) {
         _menu_delete(outputHandle,outputMenuPos);
      }
      if ( bothSidesHaveVersions() ) {
         outputHandle=0;
         outputMenuPos=0;
         status = _menu_find(menu_handle,"diff-edit-menu close-and-edit", outputHandle, outputMenuPos, 'M');
         if (!status) {
            _menu_delete(outputHandle,outputMenuPos);
         }
      }
   }

   alignPending := _ctlfile1.p_mouse_pointer == MP_ARROW || _ctlfile2.p_mouse_pointer == MP_ARROW;

   if ( alignPending ) {
      _menu_delete(menu_handle,0);
      _menu_insert(menu_handle,0,MF_ENABLED,"Cancel Align With","diff_edit_menu cancel-align");
   } else {
      // If we are on an imaginary line, remove the "Align with..." item from the
      // menu.  We know it is the 0th item in the menu.
      if ( inImaginary ) {
         _menu_delete(menu_handle,0);
      }
   }
   status=_menu_show(menu_handle,VPM_RIGHTBUTTON,x-1,y-1);
   _menu_destroy(menu_handle);
}

void _DiffRemoveImaginaryLines()
{
   //No longer need to save_pos and restore_pos because we only do this on the
   //way out, and it sometimes causes invalid point errors
   oldmodify := p_modify;
   top();up();
   while (!down()) {
      if (_lineflags()&NOSAVE_LF) {
         _delete_line();up();
      }
   }
   p_modify=oldmodify;
}

#if 1
void _DiffClearLineFlagsMacro()
{
   save_pos(auto p);
   top();up();
   while (!down()) {
      _lineflags(0,MODIFY_LF|INSERTED_LINE_LF);
   }
   restore_pos(p);
}
#endif

void _DiffUnsuspendItems()
{
   DIFF_DELETE_ITEM itemList[];
   _DiffGetDeleteList(itemList,_ctlfile1);
   for ( i:=0;i<itemList._length();++i ) {
      itemList[i].isSuspended = false;
   }
   _DiffSetDeleteList(itemList,_ctlfile1);
}

static void diffDeleteItems(DIFF_DELETE_ITEM (&itemList)[],INTARRAY &bufferIDsRemoved=null)
{
   deletedBufferList := "";
   INTARRAY bufferIDsToRemoveFromItemList;
   for ( i:=0;i<itemList._length();++i ) {
      if ( !itemList[i].isSuspended ) {
         if ( itemList[i].isView ) {
            if ( !pos(' 'itemList[i].item.p_buf_id' ',' 'deletedBufferList' ') ) {
               deletedBufferList :+= ' 'itemList[i].item.p_buf_id;
               bufferIDsRemoved :+= itemList[i].item.p_buf_id;
               bufferIDsToRemoveFromItemList :+= i;
               itemList[i].item._delete_buffer();
            }
            itemList[i].item._delete_window();
         }else{
            if ( !pos(' 'itemList[i].item' ',' 'deletedBufferList' ') ) {
               if ( !maybeDeleteBuffer(&itemList[i],deletedBufferList, bufferIDsToRemoveFromItemList) ) {
                  bufferIDsRemoved :+= itemList[i].item;
                  bufferIDsToRemoveFromItemList :+= i;
               }
            }
         }
      }
   }

   for ( i=bufferIDsToRemoveFromItemList._length()-1;i>=0;--i ) {
      itemList._deleteel(bufferIDsToRemoveFromItemList[i]);
   }
}

static int maybeDeleteBuffer(DIFF_DELETE_ITEM *pDeleteItem,_str &deletedBufferList, INTARRAY &bufferIDsToRemove)
{
   origWID := p_window_id;
   p_window_id=HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   bufID := pDeleteItem->isView? pDeleteItem->item.p_buf_id:pDeleteItem->item;
   status := load_files('+bi 'bufID);
   if ( !status ) {
      if ( diffSafeToDeleteBuffer(p_buf_id,p_window_id,p_buf_flags) ) {
         deletedBufferList :+= ' 'p_buf_id;
         ARRAY_APPEND(bufferIDsToRemove,p_buf_id);
         _delete_buffer();
         p_window_id = origWID;
         return 0;
      }
   }
   p_window_id=origWID;
   return 1;
}

/**
 * Determines if there is another window viewing a buffer.  This function also
 * searchings windows created by _create_temp_view() and
 * _open_temp_view() functions (for diff).  Also checks MDI
 * children.
 *
 * @param buf_id    Buffer id
 * @param skip_wid  Window to ignore
 *
 * @return Returns true if there is a window other than <i>skip_wid</i> displaying this buffer.
 */
static bool diffDialogViewingBuffer(int buf_id,int skip_wid=0)
{
   int i;
   for (i=1;i<=_last_window_id();++i) {
      if (i!=skip_wid && _iswindow_valid(i) &&
          i.p_HasBuffer && i.p_buf_id==buf_id && i!=VSWID_HIDDEN &&
          !i.p_IsMinimap && i.p_name!='_ctlfile1' && i.p_name!='_ctlfile2'
          ) {
         return(true);
      }
   }
   return(false);
}

/**
 * Tests whether it is safe to delete a buffer currently being
 * viewed by a dialog or a view created by
 * _create_temp_view() or _open_temp_view() (for diff).
 * 
 * Difference for diff is that this will also check MDI
 * children.
 *
 * @param buf_id    Buffer id.  p_buf_id.
 * @param skip_dialog_wid
 *                  Window ID (p_window_id) of the dialog window viewing
 *                  this buffer.  This should be 0 when calling to delete
 *                  a buffer viewed by _create_temp_view() or _open_temp_view().
 * @param buf_flags Buffer flags (p_buf_flags) of the buffer you might delete.
 * @return Returns true if it is safe to delete the buffer.
 */
static bool diffSafeToDeleteBuffer(int buf_id,int skip_dialog_wid=0,int buf_flags=0)
{
   return(!(buf_flags & VSBUFFLAG_KEEP_ON_QUIT) &&
          !diffDialogViewingBuffer(buf_id,skip_dialog_wid));
}

static void cleanupSourceDiffMarkers(_str name)
{
   diffCodeMarkerType := _GetDialogInfoHt(name,_ctlfile2);

   if (diffCodeMarkerType) {
      _StreamMarkerRemoveType(_ctlfile1,diffCodeMarkerType);
      _StreamMarkerRemoveType(_ctlfile2,diffCodeMarkerType);
      _MarkerTypeFree(diffCodeMarkerType);
   }
}
static void cleanupScrollMarkers(_str name)
{
   diffScrollMarkupType := _GetDialogInfoHt(name,_ctlfile1);
   if ( diffScrollMarkupType ) {
      _StreamMarkerRemoveType(_ctlfile1,diffScrollMarkupType);
      _MarkerTypeFree(diffScrollMarkupType);
   }
}

static void saveAllPositions(int bufID, STRHASHTAB &positions)
{
   count := 0;
   for (i:=1;i<=_last_window_id();++i) {
      if ( _iswindow_valid(i) &&
           i != HIDDEN_WINDOW_ID &&
           i.p_object==OI_EDITOR &&
           !i.p_IsMinimap &&
          i.p_HasBuffer && i.p_buf_id == bufID && !i.p_IsTempEditor && !(i.p_buf_flags&VSBUFFLAG_HIDDEN) ) {
         i.save_pos(auto p,1);
         positions:[i] = p;
         ++count;
      }
   }
}

static void restoreAllPositions(int bufID, STRHASHTAB &positionList)
{
   foreach ( auto curWID => auto p in positionList ) {
      if ( curWID.p_buf_id==bufID ) {
         curWID.restore_pos(p);
      }
   }
}

_str _DiffGetFilenameFromDialog(DIFF_SHOWING_INFO &misc,_str which)
{
   origWID := p_window_id;
   filename := "";
   p_window_id = HIDDEN_WINDOW_ID;
   status := 0;

   if ( which=='1' ) {
      if ( misc.buffer1.WholeFileBufId < 0  ) {
         p_window_id = origWID;
         return "";
      }
      status = load_files('+bi 'misc.buffer1.WholeFileBufId);
   } else {
      if ( misc.buffer2.WholeFileBufId < 0  ) {
         p_window_id = origWID;
         return "";
      }
      status = load_files('+bi 'misc.buffer2.WholeFileBufId);
   }
   if (!status) {
      filename = p_buf_name;
   } else {
      // Buffer ID may be invalid
      clear_message();
   }
   p_window_id = origWID;
   return filename;
}

static int resetReadOnly(int bufID,int inmem,int origReadOnly)
{
   status := 0;
   if ( inmem || _DiffIsDeleteSuspended(bufID) ) {
      origWID := p_window_id;
      p_window_id = HIDDEN_WINDOW_ID;
      _safe_hidden_window();
      status = load_files('+bi 'bufID);
      if (!status) {
         p_readonly_mode=origReadOnly!=0;
      }/* else {
         say('resetReadOnly bufID='bufID' status='status);
      }*/
      p_window_id = origWID;
   }
   return status;
}

static void removeMarginButtonFromList(INTARRAY &list)
{
   len := list._length();
   for (i:=0;i<len;++i) {
      VSLINEMARKERINFO info;
      _LineMarkerGet(list[i], info);
      if (info.BMIndex==_pic_merge_left || info.BMIndex==_pic_merge_right) {
         _LineMarkerRemove(list[i]);
      }
   }
}

/** 
 * Removes copy button from margin if it is in the list of 
 * bitmaps 
 * 
 * @param linenum NOT a real line number
 */
static void removeMarginButtonsFromLine(int lineNum)
{
   _LineMarkerFindList(auto list, _ctlfile1, lineNum, VSNULLSEEK, true );
   removeMarginButtonFromList(list);

   list = null;

   _LineMarkerFindList(list, _ctlfile2, lineNum, VSNULLSEEK, true );
   removeMarginButtonFromList(list);
}

static void diffStoreUndeletedItems(DIFF_DELETE_ITEM (&itemList)[])
{

   gBufferListTable:[p_active_form] = itemList;
}

/**
 * 
 * @param symbolBufID the buffer ID being diffed.  For 
 *                    historical purposes this is called the
 *                    symbol buffer ID
 * @param dataWID the window ID to use for _DiffGetAllMiscInfo 
 *                (which uses _GetDialogInfoHt)
 * 
 * @return int Whole buffer ID if found, <0 if not
 */
static int getWholeBufID(int symbolBufID,int which, int dataWID)
{
   if ( which != 1 && which != 2 ) {
      return INVALID_ARGUMENT_RC;
   }
   _DiffGetAllMiscInfo(auto allMiscInfo,dataWID);

   foreach ( auto curBufID => auto curMiscInfo in allMiscInfo ) {
      if ( curBufID==symbolBufID ) {
         if ( which==1 ) {
            return curMiscInfo.buffer1.WholeFileBufId;
         } else {
            return curMiscInfo.buffer2.WholeFileBufId;
         }
      }
   }
   return -1;
}

void _DiffOnDestroy(DIFF_UPDATE_INFO &diffUpdateInfo, DIFF_SHOWING_INFO (&allDiffShowingInfo):[]=null, 
                    DIFF_DELETE_ITEM (&itemList)[]=null, 
                    bool performExitOperations=true,
                    INTARRAY &bufferIDsRemoved=null)
{
   inTypeToggle := 0;
   if ( performExitOperations ) {
      call_list('_diffOnExit_');
      inTypeToggle = _GetDialogInfoHt("inTypeToggle",_ctlfile1);
      if (inTypeToggle==null) inTypeToggle=0;
   }

   if ( allDiffShowingInfo==null ) {
      _DiffGetAllMiscInfo(allDiffShowingInfo,_ctlfile1);
   }

   foreach ( auto curBufID => auto curMiscInfo in allDiffShowingInfo ) {
      modifiedMarkerType := _GetDialogInfoHt("modifiedMarkerType",_ctlfile1);
      insertedMarkerType := _GetDialogInfoHt("insertedMarkerType",_ctlfile1);
      _StreamMarkerRemoveAllType(insertedMarkerType);
      _StreamMarkerRemoveAllType(modifiedMarkerType);
      if (modifiedMarkerType!=null) _MarkerTypeFree(modifiedMarkerType);
      if (insertedMarkerType!=null) _MarkerTypeFree(insertedMarkerType);
      _SetDialogInfoHt("modifiedMarkerType",null,_ctlfile1);
      _SetDialogInfoHt("insertedMarkerType",null,_ctlfile1);

      copyLeftType := _GetDialogInfoHt("copyLeftType",_ctlfile1);
      copyRightType := _GetDialogInfoHt("copyRightType",_ctlfile1);
      if ( copyLeftType!=null ) {
         _LineMarkerRemoveType(_ctlfile2,copyLeftType);
      }
      if ( copyRightType!=null ) {
         _LineMarkerRemoveType(_ctlfile1,copyRightType);
      }
   }

   origFID := p_active_form;
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   curBufID = 0;
   curMiscInfo = null;

   INTARRAY removedBufIDList;
   foreach ( curBufID => curMiscInfo in allDiffShowingInfo ) {
      status := load_files('+bi 'curBufID);
      if ( status ) {
         // 6/10/2021
         // Don't clear the message for now so we can see if there are invalid
         // buffers attempting to be loaded.
//         clear_message();
         continue;
      }

      if (!VF_IS_STRUCT(curMiscInfo)) {
         //Things are not set up correctly
         if ( (!diffUpdateInfo.list._length() || (diffUpdateInfo.list._length()==1 && diffUpdateInfo.list[0].wid==p_active_form) )
              && diffUpdateInfo.timer_handle>-1) {
            _kill_timer(diffUpdateInfo.timer_handle);
            diffUpdateInfo.timer_handle=-1;
            if (diffUpdateInfo.list._length()==1) {
               diffUpdateInfo.list=null;
            }
         }
         break;
      } else {
         if ( origFID.p_name!="_svc_mfupdate_form" ) {
            _DiffRemoveWindow(origFID,true);
         }
      }

      // One buffer at a time
      if (curMiscInfo.buffer1.softWrap!=null) p_SoftWrap=curMiscInfo.buffer1.softWrap;
//      if (curMiscInfo.SoftWrap2!=null) _ctlfile2.p_SoftWrap=curMiscInfo.SoftWrap2;
      _DiffSetBuffersAreDiffed(false, curMiscInfo);

      filename1 := _DiffGetFilenameFromDialog(curMiscInfo,'1');

      filename2 := _DiffGetFilenameFromDialog(curMiscInfo,'2');

//      if ( filename2 == "" ) {
//         // For source diff there will not be a buffer name becuase the buffer 
//         // that is there is the one we balanced
//         filename2 = _GetDialogInfoHt("Buf2Name",_ctlfile1);
//      }

      DIFF_SETUP_FILE_DATA fileInfo1;
      wholeBufID := getWholeBufID(curBufID, 1, origFID._ctlfile1);
      fileInfo1 = _GetDialogInfoHt("fileInfo:"curBufID,origFID._ctlfile1);

      file1inmem := (int)fileInfo1.isBuffer;
      file1readonly := fileInfo1.readOnly;

      DIFF_SETUP_FILE_DATA fileInfo2;
      // We need to find the buffer ID in the 
      bufID := -1; 
      if ( curMiscInfo.buffer2.SymbolViewId!=null && curMiscInfo.buffer2.SymbolViewId!=0 ) {
         bufID = curMiscInfo.buffer2.SymbolViewId.p_buf_id;
      } else {
         bufID = curMiscInfo.buffer2.WholeFileBufId;
      }
      fileInfo2 = _GetDialogInfoHt("fileInfo:"bufID,origFID._ctlfile1);

      file2inmem := (int)fileInfo2.isBuffer;
      file2readonly := fileInfo2.readOnly;
   
      i := 0;
      if (fileInfo1==null && fileInfo2==null) {
         for (i=0;i<diffUpdateInfo.list._length();++i) {
            if (diffUpdateInfo.list[i].wid==origFID) {
               diffUpdateInfo.list._deleteel(i);
               break;
            }
         }
         if (!diffUpdateInfo.list._length() && diffUpdateInfo.timer_handle>-1) {
            _kill_timer(diffUpdateInfo.timer_handle);
            diffUpdateInfo.timer_handle=-1;
         }
         break;
      }
   
      wid := 0;
      if ( inTypeToggle==1 ) {
         if (!file1inmem) {
            _DiffSuspendDelete(curMiscInfo.buffer1.WholeFileBufId,origFID._ctlfile1);
            origFID.resetReadOnly(curMiscInfo.buffer1.WholeFileBufId,file1inmem,file1readonly);
         }
         if (!file2inmem || curMiscInfo.closeBuffer2>=0) {
            _DiffSuspendDelete(curMiscInfo.buffer2.WholeFileBufId,origFID._ctlfile1);
            origFID.resetReadOnly(curMiscInfo.buffer2.WholeFileBufId,file1inmem,file2readonly);
         }
      }
      if (curMiscInfo.buffer1.WholeFileBufId>=0/* && _ctlfile1.p_buf_id != curMiscInfo.WholeFileBufId1*/) {
         //Have to do this because _delete_temp_view will not delete the buffer.
         //DiffQuitView(curMiscInfo.SymbolViewId1);
         // Since we're overlaying the buffer, we have to save the original 
         // file position
         origFID.resetReadOnly(curMiscInfo.buffer1.WholeFileBufId,file1inmem,file1readonly);
      }else{
         x := '';
         ++x;
      }
      if (curMiscInfo.buffer2.WholeFileBufId>=0/* && _ctlfile2.p_buf_id != curMiscInfo.buffer2.WholeFileBufId*/) {
         //Have to do this because _delete_temp_view will not delete the buffer.
         //DiffQuitView(curMiscInfo.SymbolViewId2);
         if (curMiscInfo.buffer2.WholeFileBufId!=curMiscInfo.buffer1.WholeFileBufId) {
            //If the parent file is not the same file
            origFID.resetReadOnly(curMiscInfo.buffer2.WholeFileBufId,file2inmem,file2readonly);
         }
      }
      // This can be a blank filename with a \ appended to it because we do that
      // so we don't confuse files with buffers.
      if ( _DiffGetFilenameFromDialog(curMiscInfo,'1')=="" || filename1=='\' ) {
         _kill_timer(diffUpdateInfo.timer_handle);
         diffUpdateInfo.timer_handle=-1;
         if ( isinteger(curMiscInfo.DiffParentWID) && curMiscInfo.DiffParentWID>0 ) {
            curMiscInfo.DiffParentWID._set_focus();
         }
         break;
      }
   
      typeless File1Date='';
      typeless File2Date='';
      state := 0;
      bm1 := 0;
      BM2 := 0;
      flags := 0;
      if (curMiscInfo!=null && curMiscInfo.DiffParentWID!='' && _iswindow_valid(curMiscInfo.DiffParentWID) &&
          curMiscInfo.DiffParentWID.p_name=='_difftree_output_form' &&
          !curMiscInfo.DiffParentWID.p_edit) {
         _nocheck _control tree1,tree2;
         index1 := index2 := 0;
   
         index1=curMiscInfo.DiffParentWID.tree1._TreeCurIndex();
         index2=curMiscInfo.DiffParentWID.tree2._TreeCurIndex();
         if (DialogIsDiff() || _DiffDialogIsSVCUpdate()) {
            DiffTextChangeCallback(0,_ctlfile1.p_buf_id);
            DiffTextChangeCallback(0,_ctlfile2.p_buf_id);
         }
         if ( curMiscInfo.RefreshTagsOnClose ) {
            origFID._UpdateFileBitmaps(filename1,index1,curMiscInfo.DiffParentWID.tree1,
                                       filename2,index2,curMiscInfo.DiffParentWID.tree2,
                                       pMiscInfo:&curMiscInfo);
         }
         wid=p_window_id;
         p_window_id=curMiscInfo.DiffParentWID;
         tree1._TreeGetInfo(index1,state,bm1,BM2,flags);
   
         tree1._set_focus();
         if (!(flags&TREENODE_HIDDEN) && def_diff_edit_flags&DIFFEDIT_AUTO_JUMP) {
            _nocheck _control ctlnext_mismatch;
            ctlnext_mismatch.call_event(ctlnext_mismatch,LBUTTON_UP);
         }
         p_window_id=wid;
         File1Date=_file_date(filename1,'B');
         File2Date=_file_date(filename2,'B');
         if (File1Date!=curMiscInfo.buffer1.BufStartTime) {
            p_window_id=curMiscInfo.DiffParentWID;
            p_window_id=wid;
         }
         if (File2Date!=curMiscInfo.buffer2.BufStartTime) {
            p_window_id=curMiscInfo.DiffParentWID;
            p_window_id=wid;
         }
         if (_isUnix()) {
            // force the parent windows to be displayed on top of z-order
            curMiscInfo.DiffParentWID._set_foreground_window();
         }
      } else if ( curMiscInfo!=null && curMiscInfo.DiffParentWID!='' && _iswindow_valid(curMiscInfo.DiffParentWID) &&
                  curMiscInfo.DiffParentWID.p_name=='_git_repository_browser_form' &&
                  !curMiscInfo.DiffParentWID.p_edit ) {
         curMiscInfo.DiffParentWID._set_focus();
      }

      _deselect();
      if (_default_option(VSOPTION_MDI_SHOW_WINDOW_FLAGS)==SW_HIDE  &&
          p_active_form.p_visible) {
         x := y := width := height := 0;
         window_state := "";
         _DiffGetDimensionsAndState(x,y,width,height,window_state);
   
         _DiffWriteConfigInfoToIniFile("VSDiffGeometry",x,y,width,height,window_state);
      }
   
      // Clean up any stream markers used by Source Diff
      origFID.cleanupSourceDiffMarkers("diffCodeInsertedMarkerType");
      origFID.cleanupSourceDiffMarkers("diffCodeModifiedMarkerType");
      origFID.cleanupSourceDiffMarkers("diffCodeDeletedMarkerType");

      // Clean up any stream markers used by scroll markup
      origFID.cleanupScrollMarkers("diffScrollMarkupModifiedType");
      origFID.cleanupScrollMarkers("diffScrollMarkupInsertedType");
      origFID.cleanupScrollMarkers("diffScrollMarkupDeletedType");

      // Clean up book mark bitmaps
      if (wid && _iswindow_valid(wid)) {
         bookmarkMarkerType := _GetDialogInfoHt("bookmarkMarkerType",wid.p_active_form);
         if ( bookmarkMarkerType!=null ) {
            _LineMarkerRemoveAllType(bookmarkMarkerType);
         }
      }

      // Clean up markers used for alignments
      DIFF_ALIGN alignments[];
      alignments = _GetDialogInfoHt("alignments");
      len := alignments._length();
      for (i=0;i<len;++i) {
         _free_selection(alignments[i].markid1);
         _free_selection(alignments[i].markid2);
      }
      _SetDialogInfoHt("alignments",null);
      diffHandle := _GetDialogInfoHt("diffHandle",origFID._ctlfile1);
      if (diffHandle!=null && diffHandle>=0) {
         SEDiffFreeInfo(diffHandle);
      }
      balanceHandle  := _GetDialogInfoHt("balanceHandle",origFID._ctlfile1);
      if (balanceHandle!=null && balanceHandle>=0) {
         SEDiffFreeBalanceInfo(balanceHandle);
      }
   }

   blastUndoInfoWID := _GetDialogInfoHt("blastUndoInfo:"p_buf_id,origWID._ctlfile1);
   if ( blastUndoInfoWID!=null ) {
      blastUndoInfoWID._BlastUndoInfo();
   }
   p_window_id = origWID;

   DiffFreeAllColorInfo(_ctlfile1.p_buf_id);
   DiffFreeAllColorInfo(_ctlfile2.p_buf_id);
   if ( itemList==null ) {
      _DiffGetDeleteList(itemList,_ctlfile1);
   }
   diffDeleteItems(itemList,bufferIDsRemoved);
   diffStoreUndeletedItems(itemList);
   _DiffSetDeleteList(itemList,_ctlfile1);

   if ( performExitOperations ) {
      vscroll1._ScrollMarkupUnassociateEditor(_ctlfile1);

      if (_isMac()) {
         if(_default_option(VSOPTION_MDI_SHOW_WINDOW_FLAGS) == SW_HIDE
            && curMiscInfo.DiffParentWID==0) {
             exit(0);
         }
      }
   }
}

void _DiffCloseFileFromSVCUpdate(int infoWID, _str lastLocalFilename, INTARRAY &bufferIDsRemoved)
{
   DIFF_SHOWING_INFO allMiscInfo:[];
   _DiffGetAllMiscInfo(allMiscInfo,infoWID);

   lastBufID1 := _GetDialogInfoHt("lastBufID1:":+lastLocalFilename, _ctlfile1);
   lastBufID2 := _GetDialogInfoHt("lastBufID2:":+lastLocalFilename, _ctlfile1);

   // This means that the file was not modified, and close it like we would with
   // the on_destroy in a normal diff.  We have to close it because a) the user
   // has selected a different file and will be annoyed if he comes back to the
   // file in the editor and is told he can't edit it because it's being diffed,
   // when it's not anymore.  So set these to null so we don't reload them, we
   // have to re-diff them because they may have changed.
   if ( lastBufID1!=null && lastBufID2!=null ) {
      _SetDialogInfoHt("lastBufID1:":+lastLocalFilename, null, _ctlfile1);
      _SetDialogInfoHt("lastBufID2:":+lastLocalFilename, null, _ctlfile1);
   }


   // Figure out what items will be deleted put them in another list 
   STRARRAY allMiscInfoKeysToDelete;
   DIFF_SHOWING_INFO aboutToBeDeletedMiscInfo:[];
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   foreach (auto curIndex => auto curValue in allMiscInfo) {
      if (curValue.buffer1.WholeFileBufId !=0 && curValue.buffer1.SymbolViewId != 0) {
         status := load_files('+bi 'curValue.buffer1.WholeFileBufId);
         if ( _file_eq(lastLocalFilename, p_buf_name) ) {
            aboutToBeDeletedMiscInfo:[curIndex] = curValue;
         } else if (curValue.buffer1.SymbolViewId == 0) {
            // File off of disk, this can remain until cleaned up by on_destroy
         }
      }
   }

   // Figure out what items will be deleted, make a list of which items to 
   // delete.  aboutToBeDeletedItems is from above, the items we will pass into
   // _DiffOnDestroy.  Here accumulate indexes into allDeletedItems and store 
   // them in deletedItemsToRemove;
   DIFF_DELETE_ITEM aboutToBeDeletedItems[];
   _DiffGetDeleteList(auto deletedItemList,infoWID);
   len := deletedItemList._length();
   INTARRAY deletedItemsToRemove;
   for (i:=0;i<len;++i) {
      if ( _file_eq(lastLocalFilename, deletedItemList[i].attachedToBufferName) ) {
         aboutToBeDeletedItems :+= deletedItemList[i];
         aboutToBeDeletedItems[aboutToBeDeletedItems._length()-1].isSuspended = false;
         deletedItemsToRemove :+= i;
      }
   }

   // Go through deletedItemsToRemove and remove those items from 
   // allDeletedItems.  Go through deletedItemsToRemove backwards so
   // the indexes in allDeletedItems do not change as items are removed
   for (i = deletedItemsToRemove._length()-1;i>=0;--i) {
      deletedItemList._deleteel(deletedItemsToRemove[i]);
   }
   p_window_id = origWID;

   _DiffOnDestroy(null,aboutToBeDeletedMiscInfo,aboutToBeDeletedItems,false,bufferIDsRemoved);

   len = bufferIDsRemoved._length();
   for (i=0;i<len;++i) {
      allMiscInfo._deleteel(bufferIDsRemoved[i]);
   }
   
   _DiffSetDeleteList(deletedItemList,_ctlfile1);
   _SetDialogInfoHt(DIFFEDIT_CONST_MISC_INFO,allMiscInfo,infoWID);
}

static bool isHistoryOrBHDialog()
{
   return pos(BACKUP_HISTORY_DIALOG_CAPTION_PREFIX,p_active_form.p_caption)==1 ||
      pos(HISTORY_DIFF_DIALOG_CAPTION_PREFIX,p_active_form.p_caption)==1;
}

void _ctlfile1.on_destroy()
{
   if ( isHistoryOrBHDialog() ) {
      return;
   }
   call_list('_diffOnExit_');
   inTypeToggle := _GetDialogInfoHt("inTypeToggle",_ctlfile1);
   if (inTypeToggle==null) inTypeToggle=0;

   DIFF_SHOWING_INFO allMiscInfo:[];
   _DiffGetAllMiscInfo(allMiscInfo,_ctlfile1);
   DIFF_DELETE_ITEM itemList[];
   _DiffOnDestroy(gDiffUpdateInfo, allMiscInfo, itemList);
   _DiffGetDeleteList(auto deleteList,_ctlfile1);
   if ( p_active_form.p_name=="_svc_mfupdate_form" ) {
      _DiffRemoveWindow(p_active_form,true);
   }
}

void _DiffGetDimensionsAndState(int &DialogX,int &DialogY,int &DialogWidth,int &DialogHeight,
                                 _str &WindowState='')
{
   WindowState=p_active_form.p_window_state;
   if ( WindowState=='M' ) {
      // Have to change the state back so that we can get the info for the
      // normalized dialog
      p_active_form.p_window_state='N';
   }
   DialogX=_lx2dx(SM_TWIP,p_active_form.p_x);
   DialogY=_ly2dy(SM_TWIP,p_active_form.p_y);
   DialogWidth=_lx2dx(SM_TWIP,p_active_form.p_width);
   DialogHeight=_ly2dy(SM_TWIP,p_active_form.p_height);

}

void _DiffSetupHorizontalScrollBar()
{
   longestline1 := _ctlfile1._find_longest_line();
   longestline2 := _ctlfile2._find_longest_line();
   if (!_ctlfile1.p_fixed_font || _ctlfile1.p_UTF8) {
      longestline1=_lx2dx(SM_TWIP,longestline1);
      longestline2=_lx2dx(SM_TWIP,longestline2);
   }else{
      // We want the horizontal scroll bar to scroll the longest line in the 
      // file to the right edge of the screen.  So start with the width of the 
      // longest line, and subtract the width of the buffer plus the width of
      // one character.
      longestline1=(longestline1-(_dx2lx(SM_TWIP,_ctlfile1.p_client_width)-_ctlfile1._text_width("W"))) intdiv _ctlfile1._text_width("W");
      longestline2=(longestline2-(_dx2lx(SM_TWIP,_ctlfile2.p_client_width)-_ctlfile2._text_width("W"))) intdiv _ctlfile2._text_width("W");
   }
   hscroll1.p_max=max(longestline1,longestline2);
   hscroll1.p_min=0;
   if (_ctlfile1.p_fixed_font) {
      hscroll1.p_large_change=_ctlfile1.p_char_height-1;
   }else{
      hscroll1.p_large_change=_dx2lx(SM_TWIP,_ctlfile1.p_client_width);
   }
   SetHScrollFlag(p_active_form,false);
}

void vscroll1.on_change(int reason=0,long seekPos=0)
{
   if ( reason==CHANGE_SCROLL_MARKER_CLICKED ) {
      // User clicked a scroll marker for a difference
      diff_seek(seekPos);
      return ;
   }
   if (p_object==OI_VSCROLL_BAR) {
      int last_vscroll=_DiffVscrollGetLast();

      if (last_vscroll==null || last_vscroll=='') return;

      wid := p_window_id;
      if (vscroll1.p_value<last_vscroll) {
         p_window_id=_ctlfile1;
         _scroll_page('u',last_vscroll-vscroll1.p_value);
         p_window_id=_ctlfile2;
         _scroll_page('u',last_vscroll-vscroll1.p_value);
      }else if (vscroll1.p_value>last_vscroll) {
         p_window_id=_ctlfile1;
         _scroll_page('d',vscroll1.p_value-last_vscroll);
         p_window_id=_ctlfile2;
         _scroll_page('d',vscroll1.p_value-last_vscroll);
      }
      p_window_id=wid;
      _DiffVscrollSetLast(p_value);
   }else if (p_object==OI_HSCROLL_BAR) {
      if (_DiffHscrollGetLast()=='') return;
      _ctlfile1.p_scroll_left_edge=hscroll1.p_value;
      _ctlfile2.p_scroll_left_edge=hscroll1.p_value;
   }
}
vscroll1.on_scroll()
{
   if (p_object==OI_VSCROLL_BAR) {
      int last_vscroll=_DiffVscrollGetLast();

      if (last_vscroll==null || last_vscroll=='') return('');//Cursor moved

      if (vscroll1.p_value<last_vscroll) {
         //Should scroll up
         p_window_id=_ctlfile1;
         _scroll_page('u',last_vscroll-vscroll1.p_value);
         p_window_id=_ctlfile2;
         _scroll_page('u',last_vscroll-vscroll1.p_value);
      }else if (vscroll1.p_value>last_vscroll) {
         //Should scroll down
         p_window_id=_ctlfile1;
         _scroll_page('d',vscroll1.p_value-last_vscroll);
         p_window_id=_ctlfile2;
         _scroll_page('d',vscroll1.p_value-last_vscroll);
      }
      _DiffVscrollSetLast(vscroll1.p_value);
   }else if (p_object==OI_HSCROLL_BAR) {
      if (_DiffHscrollGetLast()=='') return('');//Cursor moved
      _ctlfile1.p_scroll_left_edge=hscroll1.p_value;
      _ctlfile2.p_scroll_left_edge=hscroll1.p_value;
      _DiffHscrollSetLast(hscroll1.p_value);
   }
   p_active_form.refresh();
}

// Making non static for wayback machine use
void _DiffUpdateScrollThumbs(bool updateImmediately=false)
{
   static int numbehind;
   if ( !updateImmediately ) {
      if (numbehind < 50) {
         ++numbehind;
         return;
      }
   }
   numbehind=0;
   _DiffVscrollSetLast('');
   int YInLines=_ctlfile1.p_cursor_y intdiv _ly2dy(SM_TWIP,_ctlfile1._text_height());
   vscroll1.p_value=_ctlfile1.p_line-YInLines;
   _DiffVscrollSetLast(_ctlfile1.p_line-YInLines);
   vscroll1.refresh();
}
static void change_edit_window()
{
   if (_get_focus()==_ctlfile1) {
      _ctlfile2._set_focus();
   }else if (_get_focus()==_ctlfile2) {
      _ctlfile1._set_focus();
   }
   p_active_form.refresh();
}


#if 0
_ctlfile1.TAB()
{
   p_window_id=_ctlfile2;
   _set_focus();
}

_ctlfile2.TAB()
{
   p_window_id=_ctlfile1;
   _set_focus();
}
#endif

static _str DiffMessageBox(_str msg, int mb_flags=MB_OK|MB_ICONEXCLAMATION,int default_button=0)
{
   //refresh();
   return _message_box(nls("%s",msg),"SlickEdit",mb_flags,default_button);
}

static int FindButtonWithShortcut(_str key)
{
   val := (key!='');
   p_enabled=val;
   wid := p_window_id;
   while (p_child) {
      p_window_id=p_child;
      firstwid := p_window_id;
      for (;;) {
         p_window_id=p_next;
         if ( p_object==OI_PICTURE_BOX ) {
            // Have to traverse these in case there is a dialog that inherits 
            // the diff dialog and puts it in a picture box (_svc_mfupdate_form)
            buttonWID := FindButtonWithShortcut(key);
            if ( buttonWID!=0 ) {
               return buttonWID; 
            }
         } else if (p_object==OI_COMMAND_BUTTON) {
            if (pos('&'key,p_caption,1,'i')) {
               rv := p_window_id;
               p_window_id=wid;
               return(rv);
            }
         }
         if (p_window_id==firstwid) break;
      }
   }
   p_window_id=wid;
   return(0);
}

static void _EditControlEventHandler()
{
   origWID := p_window_id;
   lastevent :=  last_event();
   _str eventname=event2name(lastevent);
   //messageNwait("_EditControlEventHandler: eventname="eventname" _select_type()="_select_type());
   if (eventname=='F1') {
      p_active_form.call_event(defeventtab _ainh_dlg_manager,F1,'e');
      return;
      //help('Diff Dialog box');
   }
   if (eventname=='A-F4' || eventname=='ESC') {
      diff_close_form();
      return;
   }
   if (eventname=='MOUSE-MOVE') {
      return;
   }
   if (eventname=='RBUTTON-DOWN') {
      edit_window_rbutton_up();
      return;
   }
   if (eventname=='C-S-LBUTTON-DOWN') {
      diff_mou_click();
      return;
   }
   wid := 0;
   if (substr(eventname,1,2)=='A-') {
      //If we're in an edit control, we still want the buttons to work
      wid=p_active_form.FindButtonWithShortcut(substr(eventname,3));
      if (wid) {
         wid.call_event(wid,lastevent);
         return;
      }
   }
   fid := p_active_form;
   typeless junk='';
   int key_index=event2index(lastevent);
   name_index := eventtab_index(_default_keys,_ctlfile1.p_mode_eventtab,key_index);
   command_name := name_name(name_index);

   diffMode_index := _eventtab_get_mode_keys('diff_keys');
   if ( diffMode_index ) {
      diffMode_name_index:=eventtab_index(diffMode_index,diffMode_index,key_index);
      if ( diffMode_name_index ) {
         command_name=name_name(diffMode_name_index);
      }
   }

   //This is to handle C-X combinations
   if (name_type(name_index)==EVENTTAB_TYPE) {
      int eventtab_index2=name_index;
      typeless event2=get_event('k');
      key_index=event2index(event2);
      name_index=eventtab_index(eventtab_index2,eventtab_index2,key_index);
      command_name=name_name(name_index);
   }
   //oldevent=last_event();_message_box("h1");last_event(oldevent);
   //messageNwait("_EditControlEventHandler: name="command_name);
   //DiffMessage('command_name='command_name);
   if (!_dont_use_diff_command) {
      //messageNwait("h2 _EditControlEventHandler: eventname="eventname" _select_type()="_select_type()" command_name="command_name);
      if (DiffCommands._indexin(command_name)) {
         if ( !_haveProDiff() && !DiffCommands:[command_name].supportedInStandardEdition ) {
            message(get_message(VSRC_FEATURE_REQUIRES_PRO_EDITION));
            return;
         }
         if ( DiffEditorIsReadOnly()  ) {
            CMDUI cmdui;
            cmdui.menu_handle=0;
            cmdui.menu_pos=0;
            cmdui.inMenuBar=false;
            cmdui.button_wid=1;

            _OnUpdateInit(cmdui,p_window_id);

            cmdui.button_wid=0;

            int mfflags=_OnUpdate(cmdui,p_window_id,command_name);

            if (!mfflags || (mfflags&MF_ENABLED)) {
               //Command is allowed, everything is cool.
            }else{
               //Command is not allowed, so beep at user and return
               _beep();
               if ( p_window_id==_ctlfile2 ) {
                  if ( maybeSwitchToLineDiff() ) {
                     return;
                  }else{
                     _message_box(nls("Command not allowed in Read Only mode"));
                  }
               }else{
                  _message_box(nls("Command not allowed in Read Only mode"));
               }
               return;
            }
         }
         int OldFlags=_lineflags();
         OrigLine := p_line;
         old_drag_drop := def_dragdrop;
         def_dragdrop=false;
         switch (DiffCommands:[command_name].typelessCommand._varformat()) {
         case VF_FUNPTR:
            if (pos('\-space$',command_name,1,'r')) {
               if ( !DiffEditorIsReadOnly() ) {
                  diff_mode_space();
               }
            }else if (pos('\-enter$',command_name,1,'r') ||
                      pos('\-insert-line',command_name,1,'r')
                      ) {
               if ( !DiffEditorIsReadOnly() ) {
                  _str old_keys=def_keys;
                  def_keys='windows-keys';
                  root_binding_index := 0;
                  int event_index=event2index(last_event());
                  index_used := eventtab_index(_default_keys,p_mode_eventtab,event_index,'U');
                  orig_modify := false;
                  if (index_used==p_mode_eventtab) {
                     //There is a mode binding
                     index_used=eventtab_index(_default_keys,p_mode_eventtab,event_index);
                     //Get root binding
                     root_binding_index=eventtab_index(_default_keys,_default_keys,event_index);
                     orig_modify=_eventtab_get_modify(_default_keys);
                     set_eventtab_index(_default_keys,event_index,find_index('split-insert-line',COMMAND_TYPE));

                  }
                  //set_eventtab_index(keytab_used,keyindex,command_index);
                  diff_mode_split_insert_line();
                  if (index_used==p_mode_eventtab) {
                     set_eventtab_index(_default_keys,event_index,root_binding_index);
                     _eventtab_set_modify(_default_keys,orig_modify);
                  }
                  def_keys=old_keys;
               }
            }else{
               status := (*DiffCommands:[command_name].typelessCommand)();
               if (command_name=='quit' && status!=COMMAND_CANCELLED_RC) {
                  def_dragdrop=old_drag_drop;
                  return;
               }
               if (
                   (command_name=='fast-scroll') ||
                   (command_name=='scroll-page-down') ||
                   (command_name=='scroll-page-up') ) {
                  def_dragdrop=old_drag_drop;
                  return;
               }
            }
            break;
         case VF_ARRAY:
            junk=(*DiffCommands:[command_name].typelessCommand[0])(DiffCommands:[command_name].typelessCommand[1]);
            break;
         }
         def_dragdrop=old_drag_drop;
      #if 0
      else if (DiffCloseAndRunCommands._indexin(command_name)) {
         if (diff_close_and_run_command(command_name)) {
            return;
         }
      }
      #endif
      } else{
         if (command_name=='') {
            // This could be an unbound num-pad key.  Num pad keys have different 
            // names, and are handled by _diff_docharkey
            _diff_docharkey();
            return;
         }
         if (!DiffEditorIsReadOnly() && pos('\-space$',command_name,1,'r')) {
            if (command_name=='ext-space') {
               diff_ext_space();
            }else{
               diff_mode_space();
            }
         }else if (!DiffEditorIsReadOnly() && pos('\-enter$',command_name,1,'r')) {
            diff_mode_split_insert_line();
         }else if (!DiffEditorIsReadOnly() && pos('maybe-case-backspace$',command_name,1,'r')) {
            diff_maybe_case_backspace(command_name);
         }else if (!DiffEditorIsReadOnly() && pos('\-backspace$',command_name,1,'r')) {
            diff_rubout();
         }else if (command_name=="auto-codehelp-key" ||
                   command_name=="auto-functionhelp-key") {
            _diff_docharkey();
         }else{
            // make sure that this really is a command, and not a stray event
            command_index := find_index(command_name, COMMAND_TYPE);
            eventtb_index := find_index(command_name, EVENTTAB_TYPE);
            if (!command_index && eventtb_index) {
               return;
            }
            DiffMessageBox(nls("Command '%s' is not allowed in Diff mode",command_name));
         }
      }
      //messageNwait("h3 _EditControlEventHandler: eventname="eventname" _select_type()="_select_type());
   }else{
      index := find_index(command_name,COMMAND_TYPE);
      if (index && index_callable(index)) {
         call_index(index);
      }
   }

   // 3:04:05 PM 3/1/2010 
   // It is possible that the keyboard command that was run above has actually 
   // caused the dialog to close, check to see if the window is still there.
   windowStillExists := false;
   for (i:=0;i<gDiffUpdateInfo.list._length();++i) {
      if (gDiffUpdateInfo.list[i].wid==fid) {
         windowStillExists = true;
         break;
      }
   }
   if ( !windowStillExists ) return;
   /* mou_click now supports touch scrolling. Don't exit
      the scroll for mou-click.
   */
   if (command_name!='mou-click') {
      _ctlfile1.p_scroll_left_edge=-1;
      _ctlfile2.p_scroll_left_edge=-1;
      otherwid := GetOtherWid(wid);
      int wid_sle=p_scroll_left_edge;
      p_window_id=otherwid;
      p_scroll_left_edge=wid_sle;
   } else {
      otherwid := GetOtherWid(wid);
      p_window_id=otherwid;
   }
   p_window_id=wid;//Yuck!!!!!!!!! I don't know if this really is the best
   //way to do this, but it keeps both cursors in view

   //_diffedit_UpdateForm(_ctlfile1.p_line);
   //_post_call(_diffedit_UpdateForm,_ctlfile1.p_line);
   _DiffSetNeedRefresh(true);
}

_ctlfile1.on_lost_focus()
{
   LastActiveEditWindowWID=_ctlfile1;
}

_ctlfile2.on_lost_focus()
{
   LastActiveEditWindowWID=_ctlfile2;
}

static void ScrollDown(int Noflines)
{
   int last_vscroll=_DiffVscrollGetLast();

   if (last_vscroll+Noflines>vscroll1.p_max) {
      Noflines=vscroll1.p_max-last_vscroll;
   }
   //Should scroll down
   p_window_id=_ctlfile1;
   _scroll_page('d',Noflines);
   p_window_id=_ctlfile2;
   _scroll_page('d',Noflines);

   int newval=last_vscroll+Noflines;
   _DiffVscrollSetLast(newval);
   vscroll1.p_value=newval;
}
static void ScrollUp(int Noflines)
{
   int last_vscroll=_DiffVscrollGetLast();

   if (last_vscroll-Noflines<vscroll1.p_min) {
      Noflines=last_vscroll-vscroll1.p_min;
   }
   //Should scroll down
   p_window_id=_ctlfile1;
   _scroll_page('u',Noflines);
   p_window_id=_ctlfile2;
   _scroll_page('u',Noflines);

   int newval=last_vscroll-Noflines;
   _DiffVscrollSetLast(newval);
   vscroll1.p_value=newval;
}
void _ctlfile1.on_vsb_line_down()
{
   p_window_id.ScrollDown(1);
}
void _ctlfile2.on_vsb_line_down()
{
   p_window_id.ScrollDown(1);
}
void _ctlfile1.on_vsb_line_up()
{
   p_window_id.ScrollUp(1);
}
void _ctlfile2.on_vsb_line_up()
{
   p_window_id.ScrollUp(1);
}
//Not sure about portablity

//defeventtab _diff_form.ctlfile1;
//_ctlfile1.\0-\32,\129-MBUTTON_UP,'S-LBUTTON-DOWN'-ON_SELECT()
_ctlfile1.'range-first-nonchar-key'-'all-range-last-nonchar-key',' ', 'range-first-mouse-event'-'all-range-last-mouse-event',ON_SELECT()
{
   _EditControlEventHandler();
}

//Not sure about portability
//_ctlfile2.\0-\33,\129-ON_SELECT()
//_ctlfile2.\0-\32,\129-MBUTTON_UP,'S-LBUTTON-DOWN'-ON_SELECT()
_ctlfile2.'range-first-nonchar-key'-'all-range-last-nonchar-key',' ', 'range-first-mouse-event'-'all-range-last-mouse-event',ON_SELECT()
{
   _EditControlEventHandler();
}

static void MaybeMakeLineReal()
{
   if (!(_lineflags()&NOSAVE_LF)) {
      return;
   }
   _lineflags(0,NOSAVE_LF);
   int lineflags=_lineflags();
   line := "";
   get_line(line);
   if (!DialogIsDiff()) {
      _lineflags(0,~lineflags);
      _lineflags(lineflags,lineflags);
   }
   if (line=="Imaginary Buffer Line") {
      safe_replace_line('');
   }
}

void _maybe_case_word(bool autocase,_str &gWord,int &gWordEndOffset);

static int gWordEndOffset=-1;
static _str gWord;

static void diff_maybe_case_backspace(_str cmdname)
{
   if (OnImaginaryLine()) {
      return;
   }
   if (select_active() && _within_char_selection()) {
      //DiffMessage('Mark deletes not yet available');
      diff_linewrap_delete_char('delete-selection');
      return;
   }
   wasCol1 := p_col==1;
   wid := 0;
   otherwid := p_window_id.GetOtherWid(wid);
   wid._undo('S');
   otherwid._undo('S');


   typeless orig_values;
   int embedded_status=_EmbeddedStart(orig_values);

   autoCase := LanguageSettings.getAutoCaseKeywords(p_LangId);

   _maybe_case_backspace(autoCase,gWord,gWordEndOffset);

   if (embedded_status==1) {
      _EmbeddedEnd(orig_values);
   }
   commandindex := find_index(cmdname,COMMAND_TYPE);
   prev_index(commandindex,'C');

   if (wasCol1) {
      save_pos(auto p);
      wid.DiffInsertImaginaryBufferLine();
      restore_pos(p);
      otherwid.p_line = wid.p_line;
      otherwid.p_col = wid.p_col;
   } else {
      otherwid.left();
   }
   AddUndoNothing(otherwid);

   _DiffSetNeedRefresh(true);
}

static void diff_maybe_case_word(_str cmdname)
{
   typeless orig_values;
   int embedded_status=_EmbeddedStart(orig_values);

   autoCase := LanguageSettings.getAutoCaseKeywords(p_LangId);

   _maybe_case_word(autoCase,gWord,gWordEndOffset);

   if (embedded_status==1) {
      _EmbeddedEnd(orig_values);
   }


   commandindex := find_index(cmdname,COMMAND_TYPE);
   prev_index(commandindex,'C');
}

static void diff_xml_slash()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   xml_slash();
   AddUndoNothing(otherwid);
}

static void diff_html_lt()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   html_lt();
   AddUndoNothing(otherwid);
}

static void diff_html_gt()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   html_gt();
   AddUndoNothing(otherwid);
}

static void diff_ext_space()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   ext_space();
   if (wid.p_Noflines>old_num_lines) {
      int i,origwid=p_window_id;
      p_window_id=otherwid;
      p_line=old_linenum;
      for (i=1;i<=wid.p_Noflines-old_num_lines;++i) {
         //DiffInsertColorInfo(p_buf_id,p_line);
         //InsertImaginaryLine();
         DiffInsertImaginaryBufferLine();
      }
      p_window_id=origwid;
   }
   AddUndoNothing(otherwid);
}

static void diff_html_key()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   html_key();
   if (wid.p_Noflines>old_num_lines) {
      int i,origwid=p_window_id;
      p_window_id=otherwid;
      p_line=old_linenum;
      for (i=0;i<wid.p_Noflines-old_num_lines;++i) {
         //DiffInsertColorInfo(p_buf_id,p_line);
         //InsertImaginaryLine();
         DiffInsertImaginaryBufferLine();
      }
      p_window_id=origwid;
   }
   AddUndoNothing(otherwid);
}

static void diff_lang_key(_str Language)
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   //html_key();
   index := find_index(Language'-key',COMMAND_TYPE);
   if (index && index_callable(index)) {
      call_index(index);
      if (wid.p_Noflines>old_num_lines) {
         int i,origwid=p_window_id;
         p_window_id=otherwid;
         p_line=old_linenum;
         for (i=1;i<wid.p_Noflines-old_num_lines;++i) {
            DiffInsertImaginaryBufferLine();
         }
         p_window_id=origwid;
      }
      AddUndoNothing(otherwid);
   }
}

static void _diff_docharkey()
{
   if ( !_haveProDiff() ) {
      message(get_message(VSRC_FEATURE_REQUIRES_PRO_EDITION));
      return;
   }
   _str key=last_event();
   _str eventName=event2name(key);
   _str cmdname=name_name(eventtab_index(p_mode_eventtab,p_mode_eventtab,event2index(key)));
   switch (cmdname) {
   case 'c-endbrace':
      c_endbrace();
      return;
   case 'auto-codehelp-key':
   case 'java-auto-codehelp-key':
      diff_auto_codehelp_key();
      return;
   case 'java-auto-functionhelp-key':
   case 'auto-functionhelp-key':
      diff_auto_functionhelp_key();
      return;
   case 'html-key':
      diff_html_key();
      return;
   case 'perl-key':
      diff_lang_key('perl');
      return;
   case 'ext-space':
      diff_ext_space();
      return;
   case 'xml-slash':
      diff_xml_slash();
      return;
   case 'html-lt':
      diff_html_lt();
      return;
   case 'html-gt':
      diff_html_gt();
      return;
   default:
      if (pos('maybe-case-word$',cmdname,1,'r')) {
         diff_maybe_case_word(cmdname);
         return;
      }else if ( pos('^PAD-',eventName,1,'R') ) {
         DiffPadChar(eventName,key);
      }else{
         // 6/19/2007 - rb,cm
         // Could probably use either isprint() or isnormal_char(), but less
         // is better in this case we think.
         if( isprint(key) ) {
            keyin(key);
         }
      }
      return;
   }
}

static void DiffPadChar(_str eventName,_str key)
{
   wid := p_window_id;
   otherwid := GetOtherWid(wid);
   p_window_id=wid;

   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   switch (eventName) {
   case 'PAD-STAR':
      keyin('*');
      break;
   case 'PAD-SLASH':
      keyin('/');
      break;
   case 'PAD-MINUS':
      keyin('-');
      break;
   case 'PAD-PLUS':
      keyin('+');
      break;
   default:
      keyval := key2ascii(key);
      if (keyval!="") {
         _ctlfile1._undo('S');
         _ctlfile2._undo('S');
         keyin(keyval);
         otherwid.right();
         AddUndoNothing(otherwid);
      }
   }
   otherwid.right();
   AddUndoNothing(otherwid);
}

//_ctlfile1.'a'-'z','A'-'Z','0-9',',',"'",'"','?','/','.','<','>'()
int _ctlfile1.\33-'range-last-char-key'()
{
   if ( !_haveProDiff() ) return 0;
   if ( DiffEditorIsReadOnly() ) {
      _message_box(nls("Command not allowed in Read Only mode"));
      return(1);
   }
   if (_GetDialogInfoHt("lastWasDiffCommand")==1) {
      _SetDialogInfoHt("lastWasDiffCommand",0);
      _ctlfile1._undo('S');
      _ctlfile2._undo('S');
      AddUndoNothing(_ctlfile2);
   }
   MaybeMakeLineReal();
   if ((!select_active() ||
       ( _select_type('','U')=='P' && _select_type('','S')=='E' ))
       ) {
      //!_within_char_selection keeps us from deleting selections created
      //by word completion
      _diff_docharkey();
      _ctlfile2.right();
      AddUndoNothing(_ctlfile2);
   }else{
      if (!_within_char_selection() ) {
         deselect();
         _diff_docharkey();
         _ctlfile2.right();
         AddUndoNothing(_ctlfile2);
      } else {
         diff_multi_delete();
      }
   }
   _DiffSetNeedRefresh(true);
   // 8:34:27 PM 2/19/2002
   // This code is not quite fast enough to keep, but I do
   // not want to lose it right now
   //SetHScrollFlag(p_active_form);
   return(0);
}

//_ctlfile2.'a'-'z','A'-'Z'()
int _ctlfile2.\33-'range-last-char-key'()
{
   if ( !_haveProDiff() ) return 0;
   if ( DiffEditorIsReadOnly() ) {
      if ( maybeSwitchToLineDiff() ) {
         return 0;
      }else{
         _message_box(nls("Command not allowed in Read Only mode"));
      }
      return(1);
   }
   MaybeMakeLineReal();
   int lineflags=_lineflags();
   if (!select_active() ||
       ( _select_type('','U')=='P' && _select_type('','S')=='E' )) {
      _diff_docharkey();
      _ctlfile1.right();
      AddUndoNothing(_ctlfile1);//This had _ctlfile2, but I think it was wrong
   }else{
      if (!_within_char_selection() ) {
         deselect();
         _diff_docharkey();
         _ctlfile1.right();
         AddUndoNothing(_ctlfile1);
      } else {
         diff_multi_delete();
      }
   }
   if ( !DialogIsDiff() ) {
      _lineflags(0,~lineflags);
      _lineflags(lineflags,lineflags);
      lineflags=_lineflags();
   }
   _DiffSetNeedRefresh(true);
   return(0);
}

_control _ctlnext_difference;
_control _ctlprev_difference;

_ctlfile1.C_F6()
{
   if ( _DiffGetNextDiffMissing()!=1 ) {
      call_event(_ctlnext_difference,LBUTTON_UP);
   }
}

_ctlfile2.C_F6()
{
   if ( _DiffGetNextDiffMissing()!=1 ) {
      call_event(_ctlnext_difference,LBUTTON_UP);
   }
}

_ctlfile1.'C-S-F6'()
{
   if ( _DiffGetNextDiffMissing()!=1 ) {
      call_event(_ctlprev_difference,LBUTTON_UP);
   }
}

_ctlfile2.'C-S-F6'()
{
   if ( _DiffGetNextDiffMissing()!=1 ) {
      call_event(_ctlprev_difference,LBUTTON_UP);
   }
}

_ctlfile1.'C-tab'()
{
   diff_next_window();
}

_ctlfile2.'C-tab'()
{
   diff_next_window();
}


_ctlfile1.'C-S-tab'()
{
   diff_next_window(true);
}

_ctlfile2.'C-S-tab'()
{
   diff_next_window(true);
}

static bool OnLastLine()
{
   //I wanted this to be a define, but there were problems with calling it
   //ex:  wid.OnLastLine()
   return(p_line==p_Noflines);
}


void _diff_form.on_got_focus()
{
   _ctlfile1.hex_off();
   _ctlfile2.hex_off();
   _ctlfile1._diff_show_all();
   _ctlfile2._diff_show_all();
   _diffSetLineLabelWidths();
}

static void GetVisibleControlList(_str &widlist,_str controlsToSkip = "")
{
   p_window_id=p_active_form;
   int wid=p_child;
   int first=wid;
   widlist='';
   for (;;) {
      if (wid.p_visible && !pos(' 'wid.p_name' ',' 'controlsToSkip' ')) {
         if (widlist=='') {
            widlist=wid;
         }else{
            widlist :+= ' 'wid;
         }
      }
      wid=wid.p_next;
      if (wid==first) break;
   }
}

static void SetListVisibleProperty(_str widlist,int value)
{
   cur := "";
   for (;;) {
      parse widlist with cur widlist;
      if (cur=='') break;
      cur.p_visible=value!=0;
   }
}


static int ResizeWithButtonsAtTop(int containerWID, int availablespace)
{
   int client_width=_dx2lx(SM_TWIP,containerWID.p_client_width);
   int border_width=containerWID.p_width-client_width;

   int xbuffer=_ctlfile1label.p_x;
   int ybuffer=_ctlfile1label.p_y;

   _ctlfile2.p_width=_ctlfile1.p_width=(availablespace-vscroll1.p_width) intdiv 2;
   vscroll1.p_x=(_ctlfile1.p_x_extent)-_twips_per_pixel_x();
   _ctlfile2.p_x=vscroll1.p_x_extent-_twips_per_pixel_x();
   hscroll1.p_width=(_ctlfile2.p_x_extent-_ctlfile1.p_x)/*-_twips_per_pixel_x()*/;


   int buttonHeight=(_ctlcopy_right.p_height+xbuffer)*2;

   int buttonBuffer=_ctlcopy_right_line.p_x-(_ctlcopy_right.p_x_extent);

   int client_height=_dy2ly(SM_TWIP,containerWID.p_client_height);

   _ctlfile1.p_height=client_height-(hscroll1.p_height+_ctlfile2_readonly.p_height+_ctlfile1.p_y+(3*xbuffer));
   _ctlseparater.p_width=containerWID.p_width;
   _ctlfile2.p_height=_ctlfile1.p_height;
   _ctlfile2_readonly.p_y=_ctlfile1_readonly.p_y=ctllegend.p_y=_ctlfile1.p_y_extent+hscroll1.p_height+xbuffer;

   vscroll1.p_height=_ctlfile2.p_height;
   hscroll1.p_y=(_ctlfile1.p_y_extent)-_twips_per_pixel_y();

   _ctlfile2_readonly.p_x=_ctlfile2.p_x;
   _ctlfile1line.p_y=_ctlfile1_readonly.p_y;


   PlaceBottomRowButtons(xbuffer,ybuffer,true);
   _ctlseparater.p_y=_ctlclose.p_y_extent+xbuffer;

   int secondRowY=_ctlseparater.p_y_extent+xbuffer;

   _ctlcopy_right.p_y=_ctlcopy_right_line.p_y=_ctlcopy_right_all.p_y=_ctlfile1save.p_y=\
      _ctlcopy_left.p_y=_ctlcopy_left_line.p_y=_ctlcopy_left_all.p_y=_ctlfile2save.p_y=secondRowY;
   if ( _find_control("ctlsave_all") ) {
      _nocheck _control ctlsave_all;
      ctlsave_all.p_y = _ctlfile1save.p_y;
   }

   _ctlfile2label.p_x=_ctlfile2.p_x;


   _ctlcopy_left.p_x=_ctlfile2.p_x;
   _ctlcopy_left_line.p_x=_ctlcopy_left.p_x_extent+buttonBuffer;

   _ctlcopy_left_all.p_x=_ctlcopy_left_line.p_x_extent+buttonBuffer;
   _ctlfile2save.p_x=_ctlcopy_left_all.p_x_extent+buttonBuffer;

   _ctlfile1label.p_y=_ctlfile2label.p_y=buttonHeight+xbuffer+xbuffer;
   ctlcontextCombo1.p_y = ctlcontextCombo2.p_y = _ctlfile1label.p_y_extent+ybuffer;
   ctlcontextCombo1.p_width = ctlcontextCombo2.p_width = _ctlfile1.p_width;
   ctlcontextCombo2.p_x = _ctlfile2.p_x;

   if (_haveCurrentContextToolBar() && !(def_diff_edit_flags&DIFFEDIT_HIDE_CURRENT_CONTEXT)) {
      _ctlfile1.p_y=_ctlfile2.p_y=ctlcontextCombo1.p_y_extent + xbuffer;
   } else {
      _ctlfile1.p_y=_ctlfile2.p_y=ctlcontextCombo1.p_y;
   }

   vscroll1.p_y=_ctlfile1.p_y;
   hscroll1.p_y=(_ctlfile1.p_y_extent)-_twips_per_pixel_y();
   return(0);
}

static const FILE_LABEL_Y= 180;

static void resizeMiddleDialog(int xbuffer, int ybuffer)
{
   _ctlfile2.p_height=_ctlfile1.p_height;
   vscroll1.p_height=_ctlfile2.p_height;
   hscroll1.p_y=(_ctlfile1.p_y_extent)-_twips_per_pixel_y();

   if ( _find_control("_ctlclose") ) {
      _ctlclose.p_x=_ctlfile1.p_x;
   }

   _ctlfile1_readonly.p_y = _ctlfile1.p_y_extent + hscroll1.p_height + ybuffer;
   _ctlfile2_readonly.p_y = ctllegend.p_y = _ctlfile1.p_y_extent + hscroll1.p_height + ybuffer;

   // Have to find the differnce between the size of the label check box, this
   // centers the text "Legend" next to the "Read Only" checkbox
   ctllegend.p_y += (_ctlfile2_readonly.p_height - _ctlfile2_readonly._text_height()) intdiv 2;

//   ctlInsertedImage.p_y = ctlModifiedImage.p_y = ctlImaginaryImage.p_y = ctlBalancedImage.p_y = _ctlfile1_readonly.p_y;

   _ctlfile2_readonly.p_x=_ctlfile2.p_x;
   ctllegend.p_x = _ctlfile2_readonly.p_x_extent;

   _nocheck _control ctlInsertedImage;
   _nocheck _control ctlModifiedImage;
   _nocheck _control ctlImaginaryImage;
   _nocheck _control ctlBalancedImage;

   // Here we can use the y value of the read only checkbox, because the images
   // are taller than the text
   alignControlsHorizontal(ctllegend.p_x_extent+xbuffer, ctllegend.p_y,
                           xbuffer,
                           ctlInsertedImage,
                           ctlModifiedImage,
                           ctlImaginaryImage,
                           ctlBalancedImage);

   _ctlfile1line.p_y=_ctlfile1_readonly.p_y;

   _ctlcopy_right.p_y=_ctlfile1_readonly.p_y_extent+ybuffer;

   _ctlcopy_right.p_x=_ctlfile1.p_x;_ctlcopy_left.p_x=_ctlfile2.p_x;
   _ctlcopy_right_line.p_x=_ctlcopy_right.p_x_extent+xbuffer;
   _ctlcopy_right_all.p_x=_ctlcopy_right_line.p_x_extent+xbuffer;
   _ctlcopy_right_line.p_y=_ctlcopy_right_all.p_y=_ctlfile2save.p_y=_ctlcopy_right.p_y;
   _ctlfile1save.p_x=_ctlcopy_right_all.p_x_extent+xbuffer;
   _ctlfile1save.p_y=_ctlcopy_right_all.p_y;
   if ( _find_control("ctlsave_all") ) {
      _nocheck _control ctlsave_all;
      ctlsave_all.p_y = _ctlfile1save.p_y;
      ctlsave_all.p_x = _ctlfile1save.p_x_extent + xbuffer;
   }
   _ctlcopy_left_line.p_y=_ctlcopy_left_all.p_y=_ctlfile1save.p_y;
   _ctlcopy_left_line.p_x=_ctlcopy_left.p_x_extent+xbuffer;
   _ctlcopy_left_all.p_x=_ctlcopy_left_line.p_x_extent+xbuffer;
   _ctlfile2save.p_x=_ctlcopy_left_all.p_x_extent+xbuffer;

   _ctlcopy_left.p_y=_ctlcopy_right.p_y;
}

void _DiffResizeDialog(int containerWID)
{
   typeless width='';
   typeless height='';
   _str FormSize=_GetDialogInfo(DIFFEDIT_CONST_FORM_SIZE);
   if (FormSize!=null) {
      parse FormSize with width height .;
      if (width==containerWID.p_width && height==containerWID.p_height &&
         arg(1)!='F' &&!(def_diff_edit_flags&DIFFEDIT_BUTTONS_AT_TOP)) {
         _SetDialogInfoHt("inOnResize", 0, _ctlfile1);
         return;
      }
   }

   // make sure we enforce a minimum size - all the buttons should be visible
   minWidth := ctltypetoggle.p_x_extent;
   if ( containerWID.p_width < minWidth ) {
      containerWID.p_width = minWidth;
   }

   int xbuffer=_ctlfile1label.p_x;
   int ybuffer=_ctlfile1label.p_y;

   widlist := "";
   GetVisibleControlList(widlist,"_grabbar_vert");
   SetListVisibleProperty(widlist,0);

   int availablespace=containerWID.p_width-(xbuffer*2);

   typeless status=0;
   if ( def_diff_edit_flags&DIFFEDIT_BUTTONS_AT_TOP ) {
      status=ResizeWithButtonsAtTop(containerWID, availablespace);
      SetListVisibleProperty(widlist,1);
      FormSize=containerWID.p_width' 'containerWID.p_height;
      _SetDialogInfo(DIFFEDIT_CONST_FORM_SIZE,FormSize);

      p1 := 1;
      vscroll1.p_max=_ctlfile1.p_Noflines-_ctlfile1.p_char_height;

      _diffSetLineLabelWidths();
      SetHScrollFlag(containerWID);

      _SetDialogInfoHt("inOnResize", 0, _ctlfile1);
      return;
   }
#if 0 //13:11pm 1/13/2021
   // Leave the labels at the top
   if ( containerWID == p_active_form ) {
      _ctlfile1label.p_y=_ctlfile2label.p_y=FILE_LABEL_Y;
   }
#endif
   contextComboHeight := 0;
   numYBuffers := 6;
   if (_haveCurrentContextToolBar() && !(def_diff_edit_flags&DIFFEDIT_HIDE_CURRENT_CONTEXT)) {
      ctlcontextCombo1.p_y = _ctlfile1label.p_y_extent + ybuffer;
      ctlcontextCombo2.p_y = _ctlfile2label.p_y_extent + ybuffer;
      contextComboHeight = ctlcontextCombo1.p_height;
      _ctlfile1.p_y=_ctlfile2.p_y=ctlcontextCombo1.p_y_extent + ybuffer;
      numYBuffers += 2;
   } else {
      _ctlfile1.p_y=_ctlfile2.p_y=ctlcontextCombo1.p_y;
   }
   vscroll1.p_y=_ctlfile2.p_y;


   _ctlfile2.p_width=_ctlfile1.p_width=(availablespace-vscroll1.p_width) intdiv 2;
   ctlcontextCombo1.p_width = ctlcontextCombo2.p_width = _ctlfile1.p_width;
   vscroll1.p_x=(_ctlfile1.p_x_extent)-_twips_per_pixel_x();
   _ctlfile2.p_x = ctlcontextCombo2.p_x=vscroll1.p_x_extent-_twips_per_pixel_x();
   hscroll1.p_width=(_ctlfile2.p_x_extent-_ctlfile1.p_x)/*-_twips_per_pixel_x()*/;

   // Next difference will always be there, _ctlclose might not
   client_height := _dy2ly(SM_TWIP,containerWID.p_client_height);
   bottomButtonHeight := _ctlnext_difference.p_height;

   if ( !_haveProDiff() ) {
      // Do not subtract height of read only checkboxes because the line indicators are at the same y position are taller
      _ctlfile1.p_height=(client_height-_ctlfile1.p_y)-(ybuffer*numYBuffers)-_ctlclose.p_height-hscroll1.p_height-_ctlfile1line.p_height-(_twips_per_pixel_y()*2);

      resizeMiddleDialog(xbuffer,ybuffer);

      _ctlseparater.p_y=_ctlcopy_left.p_y;
   } else {
      // Do not subtract height of read only checkboxes because the line indicators are at the same y position are taller.
      // Use _ctlnext_difference height, close button can be missing
      _ctlfile1.p_height = client_height - (_ctlfile1label.p_height+ctlcontextCombo1.p_height+hscroll1.p_height+_ctlfile1_readonly.p_height+_ctlcopy_right.p_height+_ctlseparater.p_height+_ctlnext_difference.p_height+(ybuffer*numYBuffers));

      resizeMiddleDialog(xbuffer,ybuffer);

      _ctlseparater.p_y=_ctlcopy_left.p_y_extent+ybuffer;
   }
   _ctlseparater.p_width=containerWID.p_width;

   PlaceBottomRowButtons(xbuffer,ybuffer);

   _ctlfile1label.p_auto_size=false;
   _ctlfile2label.p_auto_size=false;
   _ctlfile1label.p_width=_ctlfile1.p_width;_ctlfile2label.p_width=_ctlfile2.p_width;

   fob := "";
   FileTitles := _DiffGetDialogTitles();
   File1Title := File2Title := "";
   if ( FileTitles!=null ) {
      File1Title = strip(parse_file(FileTitles),'B','"');
      File2Title = strip(parse_file(FileTitles),'B','"');
   }
   if (_ctlfile1.p_buf_name!='') {
      _ctlfile1label.GetFileOrBuffer(fob);
      _ctlfile1label.p_caption=File1Title:+fob;
   }
   if (_ctlfile2.p_buf_name!='') {
      _ctlfile2label.GetFileOrBuffer(fob);
      _ctlfile2label.p_caption=File2Title:+fob;
   }

   _ctlfile1label.DiffShrinkFilename(File1Title, _ctlfile1label.p_width);
   _ctlfile2label.DiffShrinkFilename(File2Title, _ctlfile2label.p_width);

   SetListVisibleProperty(widlist,1);
   FormSize=containerWID.p_width' 'containerWID.p_height;
   _SetDialogInfo(DIFFEDIT_CONST_FORM_SIZE,FormSize);

   _DiffSetupScrollBars();

   _diffSetLineLabelWidths();
   SetHScrollFlag(containerWID);
   if ( _DiffDialogIsSVCUpdate() ) {
      _nocheck _control ctlbinary_file_message;
      _nocheck _control ctlpicture1;
      ctlbinary_file_message.p_x = ctlpicture1.p_x + _ctlfile1.p_x;
      ctlbinary_file_message.p_width = _ctlfile2.p_x_extent - _ctlfile1.p_x;

      _nocheck _control ctldiff_binary_files;
      ctldiff_binary_files.p_x = ctlbinary_file_message.p_x + (ctlbinary_file_message.p_width intdiv 2) - ctldiff_binary_files.p_width intdiv 2;
      ctldiff_binary_files.p_y = ctlbinary_file_message.p_y_extent + ybuffer;
   }
}

void _diff_form.on_resize()
{
   inOnResize := _GetDialogInfoHt("inOnResize", _ctlfile1);
   if ( inOnResize==1 ) {
      return;
   }
   _SetDialogInfoHt("inOnResize", 1, _ctlfile1);

   _DiffResizeDialog(p_active_form);

   _SetDialogInfoHt("inOnResize", 0, _ctlfile1);
}

void _ctlfile1.on_resize()
{
   _DiffSetupScrollBars();
}

static void MaybeHide(int wid)
{
   if ( !wid ) return;
   if (_ctlfile1line.p_y==wid.p_y &&
       _ctlfile1line.p_x < wid.p_x_extent) {
      wid.p_visible=false;
   }else{
      wid.p_visible=true;
   }
}

static void PlaceBottomRowButtons(int xbuffer,int ybuffer,bool BottomRowOnTop=false)
{
   buttonY := _ctlseparater.p_y_extent+(ybuffer);

   if (BottomRowOnTop) {
      buttonY=ybuffer;
      _ctlnext_difference.p_y=_ctlprev_difference.p_y=buttonY;
   }else{
      _ctlnext_difference.p_y=_ctlprev_difference.p_y=buttonY;
      if ( _find_control('_ctlclose') ) {
         // In some cases the _ctlclose button may not be there
         _ctlclose.p_y = buttonY;
      }
   }

   _ctlfile1label.p_x=_ctlfile1.p_x;_ctlfile2label.p_x=_ctlfile2.p_x;

   _ctlfile1label.p_width=_ctlfile1.p_width;_ctlfile2label.p_width=_ctlfile2.p_width;
   ctloptions.p_y = ctlrediff.p_y = _ctlfind.p_y=_ctlundo.p_y=buttonY;
   _ctlhelp.p_y=_ctlundo.p_y;
   if ( _ctlundo.p_visible ) {
      _ctlhelp.p_x=_ctlundo.p_x_extent+xbuffer;
   }
   ctltypetoggle.p_y = _ctlundo.p_y;
   lastWID := ctltypetoggle;

   _ctlok.p_y=_ctlhelp.p_y;
   _ctlok.p_x=_ctlhelp.p_x_extent+xbuffer;
   lastWID = _ctlok;
   if ( _ctlok.p_visible ) {
      lastWID = _ctlok;
   }else{
      lastWID = _ctlhelp;
   }
   ctltypetoggle.p_x = lastWID.p_x_extent + xbuffer;
}

static void clearBufferSettings()
{
   DiffFreeAllColorInfo(p_buf_id);
   _DiffRemoveImaginaryLines();
   _DiffRemoveImaginaryLines();
   _DiffClearLineFlags();
}

static int onUpdate_diff_toggle_intraline_color(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid) {
      return MF_GRAYED;
   }
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   if (misc.IntraLineIsOff==1) {
      return(MF_ENABLED);
   }else if (misc.IntraLineIsOff==0) {
      return(MF_ENABLED|MF_CHECKED);
   }
   return(MF_ENABLED);
}

int _OnUpdate_diff_edit_menu(CMDUI &cmdui,int target_wid,_str command)
{
   parse command with auto menu_command auto commandToRun;
   switch (commandToRun) {
   case "align":
      return MF_ENABLED;
   case "cancel-align":
      return MF_ENABLED;
   case "toggle-intraline":
      return onUpdate_diff_toggle_intraline_color(cmdui,target_wid,command);
   case "close-and-edit":
      // For backup hsitory bufName is getting set because it intiially comes
      // up with the local file open, so we have to do further checks to see if
      // close-and-edit is allowed
      isHistoryDiff := pos('History Diff - ',p_active_form.p_caption,1);
      _nocheck _control ctltype_combo;
      if ( isHistoryDiff && (p_window_id==_ctlfile2 || ctltype_combo.p_text!=LOCAL_FILE_CAPTION) ) {
         _menu_delete(cmdui.menu_handle,cmdui.menu_pos);
         return MF_GRAYED;
      }

      return MF_ENABLED;
   case "copy-selection-to-other-window":
      {
         menuCaption := "Copy selection to ";
         if (p_window_id==_ctlfile1 ) {
            if ( !_find_control("_ctlfile2_readonly") || _ctlfile2_readonly.p_value) {
               _menu_delete(cmdui.menu_handle,cmdui.menu_pos);
               return MF_DELETED;
            }
            menuCaption :+= _ctlfile2._DiffGetDocumentName();
         } else if (p_window_id==_ctlfile2) {
            if ( !_find_control("_ctlfile1_readonly") || _ctlfile1_readonly.p_value) {
               _menu_delete(cmdui.menu_handle,cmdui.menu_pos);
               return MF_DELETED;
            }
            menuCaption :+= _ctlfile1._DiffGetDocumentName();
         }
         _menu_set_state(cmdui.menu_handle,cmdui.menu_pos,MF_ENABLED,'P',menuCaption);
         return select_active()!=0?MF_ENABLED:MF_GRAYED;
      }
   }
   return MF_GRAYED;
}

_command void diff_edit_menu(_str cmdline="") name_info(','VSARG2_REQUIRES_PRO_EDITION/*|VSARG2_REQUIRES_PRO_OR_STANDARD_EDITION*/)
{
   if (cmdline=="") {
      return;
   }
   switch (lowcase(cmdline)) {
   case "align":
      diff_align_with();
      break;
   case "cancel-align":
      diff_cancel_align_with();
      break;
   case "toggle-intraline":
      diff_toggle_intraline_color();
      break;
   case "close-and-edit":
      diff_close_and_edit();
      break;
   case "copy-selection-to-other-window":
      diff_copy_selection_to_other_window();
      break;
   }
}

static void diff_cancel_align_with()
{
   if ( p_name != "_ctlfile1" && p_name != "_ctlfile2" ) {
      return;
   }
   _SetDialogInfoHt("pending1",null);
   _SetDialogInfoHt("pending2",null);
   _ctlfile1.p_mouse_pointer = _ctlfile2.p_mouse_pointer = MP_DEFAULT;
}

static void diff_align_with()
{
   nextWID := _ctlfile2;
   index := "pending1";
   if ( p_window_id == _ctlfile2 ) {
      nextWID = _ctlfile1;
      index = "pending2";

      // Use _set_focus so user does not have to click twice in other window
      _ctlfile1._set_focus();
   } else {
      // Use _set_focus so user does not have to click twice in other window
      _ctlfile2._set_focus();
   }
   _save_pos2(auto p);
   _begin_line();
   offset := _QROffset();
   _SetDialogInfoHt(index,offset);
   _restore_pos2(p);
   nextWID.p_mouse_pointer = MP_ARROW;
}

static void rediff()
{
   if (!_haveDiff()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_OR_STANDARD_EDITION_1ARG, "Diff");
      return;
   }
   _ctlfile1.save_pos(auto p);
   _ctlfile2.save_pos(auto q);
   line1 := _ctlfile1.p_line;
   line2 := _ctlfile2.p_line;
   _ctlfile1.clearBufferSettings();
   _ctlfile2.clearBufferSettings();
   // Clean up any stream markers used by Source Diff

   // Clean up any stream markers used by scroll markup
   cleanupScrollMarkers("diffScrollMarkupModifiedType");
   cleanupScrollMarkers("diffScrollMarkupInsertedType");
   cleanupScrollMarkers("diffScrollMarkupDeletedType");

   gaugeWID := 0;
   gaugeFormWID := 0;
   if ( def_diff_edit_flags&DIFFEDIT_SHOW_GAUGE ) {
      gaugeFormWID = show('-mdi _difftree_progress_form');
      _DiffSetupProgressForFile(gaugeFormWID,gaugeWID);
   }
   DIFF_INFO info;

   info.viewID1 = _ctlfile1;
   info.viewID2 = _ctlfile2;
   info.options = _GetDialogInfoHt("lastDiffOptions",_ctlfile1);
   if ( info.options==null ) {
      info.options = def_diff_flags;
   }
   info.numDiffOutputs = 0;
   info.isSourceDiff = false;
   info.loadOptions = def_load_options;
   info.gaugeWID = gaugeWID;
   info.maxFastFileSize = def_max_fast_diff_size;
   info.lineRange1 = "1";
   info.lineRange2 = "1";
   info.smartDiffLimit = def_smart_diff_limit;
   info.imaginaryText = null;
   info.tokenExclusionMappings=null;
   info.alignments = null;

   getAlignments(auto alignmentList);

   info.alignments = alignmentList;

   status := Diff(info,auto junk);
   _ctlfile1.restore_pos(p);
   _ctlfile2.restore_pos(q);

   _ctlfile1.p_line = line1;
   _ctlfile2.p_line = line2;
   //_ctlfile1._BlastUndoInfo();
   //_ctlfile2._BlastUndoInfo();
   _DiffSetupScrollBars();
   gaugeFormWID._delete_window();
}

void ctlrediff.lbutton_up()
{
    getAlignments(auto alignmentList);
    if ( alignmentList._length()>0 ) {
       status := _message_box(nls("Clear alignments?"),"",MB_YESNO);
       if ( status==IDYES ) {
          _SetDialogInfoHt("alignments",null);
       }
    }
    rediff();
    if ( LastActiveEditWindowWID ) {
       LastActiveEditWindowWID._set_focus();
    }
}

void _diffSetLineLabelWidths()
{
   if ( _DiffGetLineNumLabelsMissing()!=1 ) {
      // 1/18/2021 - This will work when there are files in the diff.
      int textwidth1=_ctlfile1line._text_width(_ctlfile1line.p_caption);
      int textwidth2=_ctlfile2line._text_width(_ctlfile2line.p_caption);

      _ctlfile1line.p_x=(_ctlfile1.p_x_extent)-textwidth1;
      _ctlfile2line.p_y=_ctlfile1line.p_y;
      _ctlfile2line.p_x=((_ctlfile2.p_x_extent)-textwidth2)-300;
   }
}

static void diff_mode_split_insert_line()
{
   //Shut off the intra-line diffing while we do this.
   //Otherwise, the callback will hit in them middle of the
   //split and diff lines that are not really side by side
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      DiffTextChangeCallback(0,_ctlfile1.p_buf_id);
      DiffTextChangeCallback(0,_ctlfile2.p_buf_id);
   }
   otherwid := GetOtherWid(auto wid);
   wid._undo('S');
   otherwid._undo('S');

   _UndoPushModify(otherwid);

   if ( wid._lineflags()&NOSAVE_LF ) {
      // If this is an imaginary buffer line, go to the end of the line before
      // the user presses enter so we do not split the line
      _end_line();
   }
   oldlinenum := p_line;
   oldline := "";
   get_line(oldline);

   mode_name := "";
   key_index := 0;
   index := 0;
   lastEventName := event2name(last_event());
   if ( lastEventName :== "ENTER" 
        || lastEventName :== "C-ENTER" 
        || lastEventName :== "S-ENTER" 
        || lastEventName :== "C-S-ENTER" 
        ) {
      key_index=event2index(last_event());
      index=eventtab_index(_default_keys,p_mode_eventtab,key_index);
   } else {
      parse lowcase(p_mode_name) with mode_name '-' .;
      index=find_index(mode_name'_enter',COMMAND_TYPE);
   }
   oldro := p_readonly_mode;
   p_readonly_mode=false;
   if (!index) {
      wid.split_insert_line();
   }else{
      //index=find_index(arg(1)'_enter',COMMAND_TYPE);
      call_index(index);
   }
   p_readonly_mode=oldro;
   wid=p_window_id;
   p_window_id=otherwid;
   if (wid.p_Noflines!=otherwid.p_Noflines) {
      p_line=oldlinenum;
      DiffInsertImaginaryBufferLine();
      otherwid.p_line=wid.p_line;
      AddUndoNothing(otherwid);
   }
   p_window_id=wid;
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      //Turn the intra-line diffing back on
      DiffTextChangeCallback(1,_ctlfile1.p_buf_id);
      DiffTextChangeCallback(1,_ctlfile2.p_buf_id);
   }
   _UndoPopModify(otherwid);

   _DiffSetupScrollBars();
}

static void FixCaption(int wid,bool modify)
{
   if (length(wid.p_caption)<2) {
      return;
   }
   str := substr(wid.p_caption,length(wid.p_caption)-1);
   cap := wid.p_caption;
   if (str==' *') {
      cap=substr(cap,1,length(wid.p_caption)-2);
   }
   if (modify) {
      cap :+= ' *';
   }
   if (cap!=wid.p_caption) {
      wid.p_caption=cap;
   }
}

static void DiffLabelCopyButtons()
{
   if ( _DiffCopyMissing()==1 ) {
      return;
   }
   diff_label_copy_buttons(_ctlcopy_right, _ctlcopy_right_line,
                           _ctlcopy_left,  _ctlcopy_left_line);
}

void diff_label_copy_buttons( int r_copy_block,   int r_copy_line,
                              int l_copy_block=0, int l_copy_line=0,
                              bool reverse_left_and_right = false )
{
   if (reverse_left_and_right) {
      diff_label_copy_buttons( l_copy_block, l_copy_line,
                               r_copy_block, r_copy_line);
      return;
   }

   line := "";
   if (!_ctlfile1.p_line) {
      if (r_copy_block) r_copy_block.p_enabled=false;
      if (r_copy_line)  r_copy_line.p_enabled=false;
      if (l_copy_block) l_copy_block.p_enabled=false;
      if (l_copy_line)  l_copy_line.p_enabled=false;
   }else{
      int file1line_modified=_ctlfile1._lineflags()&MODIFY_LF;
      int file1line_inserted=_ctlfile1._lineflags()&INSERTED_LINE_LF;
      int file2line_modified=_ctlfile2._lineflags()&MODIFY_LF;
      int file2line_inserted=_ctlfile2._lineflags()&INSERTED_LINE_LF;
      if (file1line_inserted) {
         if (r_copy_block) r_copy_block.p_enabled=true;
         if (l_copy_block) l_copy_block.p_enabled=true;
         _ctlfile1.get_line(line);
         if (_ctlfile1._lineflags()&NOSAVE_LF) {//Inserted Line
            if (l_copy_block) l_copy_block.p_caption='<<Block';
            if (r_copy_block) r_copy_block.p_caption='Del Block';
            if (r_copy_line)  r_copy_line.p_enabled=false;
            if (l_copy_line)  l_copy_line.p_enabled=true;
         }else{//Deleted Line
            if (r_copy_block) r_copy_block.p_enabled=true;
            if (l_copy_block) l_copy_block.p_enabled=true;
            if (l_copy_block) l_copy_block.p_caption='Del Block';
            if (r_copy_block) r_copy_block.p_caption='Block>>';
            if (r_copy_line)  r_copy_line.p_enabled=true;
            if (l_copy_line)  l_copy_line.p_enabled=false;
         }
      }else if (file2line_inserted) {
         if (r_copy_block) r_copy_block.p_enabled=true;
         if (l_copy_block) l_copy_block.p_enabled=true;
         _ctlfile1.get_line(line);
         if (_ctlfile1._lineflags()&NOSAVE_LF) {//Inserted Line
            if (l_copy_block) l_copy_block.p_caption='<<Block';
            if (r_copy_block) r_copy_block.p_caption='Del Block';
            if (r_copy_line)  r_copy_line.p_enabled=false;
            if (l_copy_line)  l_copy_line.p_enabled=true;
         }else{//Deleted Line
            if (r_copy_block) r_copy_block.p_enabled=true;
            if (l_copy_block) l_copy_block.p_enabled=true;
            if (l_copy_block) l_copy_block.p_caption='Del Block';
            if (r_copy_block) r_copy_block.p_caption='Block>>';
            if (r_copy_line)  r_copy_line.p_enabled=true;
            if (l_copy_line)  l_copy_line.p_enabled=false;
         }
      }else if (file1line_modified||file2line_modified) {
         if (r_copy_block) r_copy_block.p_enabled=true;
         if (l_copy_block) l_copy_block.p_enabled=true;
         if (r_copy_line)  r_copy_line.p_enabled=true;
         if (l_copy_line)  l_copy_line.p_enabled=true;
         if (l_copy_block) l_copy_block.p_caption='<<Block';
         if (r_copy_block) r_copy_block.p_caption='Block>>';
      }else{
         if (l_copy_block) l_copy_block.p_caption='<<Block';
         if (r_copy_block) r_copy_block.p_caption='Block>>';
         if (r_copy_block) r_copy_block.p_enabled=false;
         if (l_copy_block) l_copy_block.p_enabled=false;
         if (r_copy_line)  r_copy_line.p_enabled=false;
         if (l_copy_line)  l_copy_line.p_enabled=false;
      }
   }
}

static bool DialogIsDiff()
{
   //return(p_active_form.p_caption=='Diff');
   int i;
   for (i=0;i<gDiffUpdateInfo.list._length();++i) {
      if (gDiffUpdateInfo.list[i].wid==p_active_form &&
         gDiffUpdateInfo.list[i].isDiff) {
         return(true);
      }
   }
   return(false);
}

bool _DiffDialogIsSVCUpdate()
{
   int i;
   for (i=0;i<gDiffUpdateInfo.list._length();++i) {
      if (gDiffUpdateInfo.list[i].wid==p_active_form &&
         gDiffUpdateInfo.list[i].isSVCUpdate) {
         return(true);
      }
   }
   return(false);
}

static void getFirstLines(int &firstLine1,int &firstLine2)
{
   firstLines := _GetDialogInfoHt("diffFirstLines",_ctlfile1);
   if ( firstLines==null ) {
      firstLine1 = 1;
      firstLine2 = 1;
   } else {
      parse firstLines with auto firstLine1Str auto firstLine2Str;
      firstLine1 = (int)firstLine1Str;
      firstLine2 = (int)firstLine2Str;
   }
}

static void UpdateForm2()
{
   if (arg(1)!='') {
      if (_ctlfile1.p_line!=arg(1)) {
         return;
      }
   }
   if (!_find_control('_ctlfile1')) {
      return;
   }
   if ( !_DiffGetNeedRefresh() ) {
      return;
   }

   if (!_GetDialogInfo(DIFFEDIT_CONST_HAS_MODIFY)) {
      _SetDialogInfo(DIFFEDIT_CONST_FILE1_MODIFY,_ctlfile1.p_modify);
      _ctlfile1.p_modify=false;
      _SetDialogInfo(DIFFEDIT_CONST_FILE2_MODIFY,_ctlfile2.p_modify);
      _ctlfile2.p_modify=false;
      _SetDialogInfo(DIFFEDIT_CONST_HAS_MODIFY,true);
   }

   if ( _DiffGetLineNumLabelsMissing()!=1 ) {
      getFirstLines(auto firstLine1,auto firstLine2);
      _ctlfile1line.p_caption=_ctlfile1.p_RLine+getFirstLineOffset(firstLine1)'/'(_ctlfile1.p_Noflines-_ctlfile1.p_NofNoSave+getFirstLineOffset(firstLine1));
      _ctlfile2line.p_caption=_ctlfile2.p_RLine+getFirstLineOffset(firstLine2)'/'(_ctlfile2.p_Noflines-_ctlfile2.p_NofNoSave+getFirstLineOffset(firstLine2));
   }
   _diffSetLineLabelWidths();
   if (DialogIsDiff()) {
      DiffLabelCopyButtons();
   } else if (!_DiffCopyLeftMissing()) {
      diff_label_copy_buttons(0, 0, _ctlcopy_left,  _ctlcopy_left_line);
   }
   if ( _DiffGetFileLabelsMissing()!=1 ) {
      FixCaption(_ctlfile1label,_ctlfile1.p_modify||_GetDialogInfo(DIFFEDIT_CONST_FILE1_MODIFY));
      FixCaption(_ctlfile2label,_ctlfile2.p_modify||_GetDialogInfo(DIFFEDIT_CONST_FILE2_MODIFY));
   }
   int YInLines=_ctlfile1.p_cursor_y intdiv _ctlfile1.p_font_height;

   //vscroll1.p_user='';
   _DiffVscrollSetLast('');
   vscroll1.p_value=_ctlfile1.p_line-YInLines;
   //vscroll1.p_user=_ctlfile1.p_line-YInLines;
   _DiffVscrollSetLast(_ctlfile1.p_line-YInLines);

   _DiffHscrollSetLast('');
   hscroll1.p_value=_ctlfile1.p_left_edge;
   _DiffHscrollSetLast(_ctlfile1.p_left_edge);

   if (DialogIsDiff() && _DiffCopyMissing()!=1) {
      _str files_matched=_DiffGetFilesMatch();
      _ctlcopy_right_all.p_enabled=files_matched!='Files Match';
      _ctlcopy_left_all.p_enabled=files_matched!='Files Match';
   }
   _DiffSetNeedRefresh(false);
}

void _diffedit_UpdateForm()
{
   //We have to do all these cascading checks because we get called on a timer
   //and some parts may be filled in, but not other parts.
   i := 0;
   if (gDiffUpdateInfo.list._varformat()==VF_ARRAY) {
      for (i=0;i<gDiffUpdateInfo.list._length();++i) {
         if (VF_IS_STRUCT(gDiffUpdateInfo.list[i])) {
            if (VF_IS_INT(gDiffUpdateInfo.list[i].wid)) {
               if (_iswindow_valid(gDiffUpdateInfo.list[i].wid)) {
                  gDiffUpdateInfo.list[i].wid.UpdateForm2();
                  if (gDiffUpdateInfo.list[i].needToSetupHScroll) {
                     formWID := gDiffUpdateInfo.list[i].wid;
                     formWID._DiffSetupHorizontalScrollBar();
                     formWID.vscroll1.p_large_change=formWID._ctlfile1.p_char_height-1;
                  }
               }
            }
         }
      }
   }
}

static void SetHScrollFlag(int formwid,bool value=true)
{
   i := 0;
   if (gDiffUpdateInfo.list._varformat()==VF_ARRAY) {
      for (i=0;i<gDiffUpdateInfo.list._length();++i) {
         if (VF_IS_STRUCT(gDiffUpdateInfo.list[i])) {
            if (gDiffUpdateInfo.list[i].wid==formwid) {
               gDiffUpdateInfo.list[i].needToSetupHScroll=value;
               break;
            }
         }
      }
   }
}

int DiffModifiedFiles()
{
   i := 0;
   if (gDiffUpdateInfo.list._varformat()==VF_ARRAY) {
      for (i=0;i<gDiffUpdateInfo.list._length();++i) {
         if (VF_IS_STRUCT(gDiffUpdateInfo.list[i])) {
            int formwid=gDiffUpdateInfo.list[i].wid;
            wid := p_window_id;
            p_window_id=formwid;
            if (_ctlfile1.p_modify || _ctlfile2.p_modify) {
               p_window_id=wid;
               return(formwid);
            }
            p_window_id=wid;
         }
      }
   }
   return(0);
}

static void diff_maybe_deselect_command(...)
{
   diff_maybe_deselect();
   diff_command(arg(1));
   wid := 0;
   otherwid := GetOtherWid(wid);
   otherwid.p_col=wid.p_col;
   otherwid.p_line=wid.p_line;
   _DiffUpdateScrollThumbs();
}

static void diff_command_and_update() {
   diff_command(arg(1));
   wid := 0;
   otherwid := GetOtherWid(wid);
   otherwid.p_col=wid.p_col;
   otherwid.p_line=wid.p_line;
   _DiffUpdateScrollThumbs();
}

static void diff_command(...)
{
   wid := 0;
   otherwid := GetOtherWid(wid);
#if 0 //4:14pm 9/12/2019
   //This is the only way I could compare to see if it was a pointer to undo
   typeless str_uc=undo_cursor;
   typeless str_u=undo;
   if (arg(1)!=str_u && arg(1)!=str_uc) {
      if (in_cua_select) {
         if (p_window_id==_ctlfile1) {
            _ctlfile2._undo('S');
         }else{
            _ctlfile1._undo('S');
         }
      }else{
         _ctlfile1._undo('S');
         _ctlfile2._undo('S');
      }
   }
#endif
#if 0 //4:31pm 9/13/2019
   lastCommandName := _GetDialogInfoHt("lastCommandName",_ctlfile1);
   if (lastCommandName!=null) {
      say('diff_command lastCommandName='lastCommandName);
   }
   if ( lastCommandName=="select-char" || lastCommandName=="select-line" ) {
      if ( wid.select_active() ) {
         say('diff_command AddUndoNothing('otherwid.p_name')');
         AddUndoNothing(otherwid);
      } else if ( otherwid.select_active() ) {
         say('diff_command AddUndoNothing('wid.p_name')');
         AddUndoNothing(wid);
      }
   }
#endif

   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   typeless ptr=arg(1);
   p_window_id=wid;
   typeless junk=(*ptr)();
   p_window_id=otherwid;
   junk=(*ptr)();
   p_window_id=wid;
   otherwid.p_col=wid.p_col;
   _SetDialogInfoHt("lastWasDiffCommand",1);
}

_ctlcopy_left.lbutton_up()
{
   if ( _ctlfile1.DiffEditorIsReadOnly() ) {
      _message_box(nls("Command not allowed in Read Only mode"));
      return(1);
   }
   formWid := p_active_form;
   switch (_ctlcopy_left.p_caption) {
   case 'Del Block':
      _ctlfile2.diff_delete_block();
      break;
   case '<<Block':
      _ctlfile2.diff_copy_block();
      break;
   }
   if (!_iswindow_valid(formWid)) return(0);
   _DiffSetNeedRefresh(true);
   ReturnFocusToEditWindow();

   return(0);
}

_ctlcopy_left_all.lbutton_up()
{
   if ( _ctlfile1.DiffEditorIsReadOnly() ) {
      _message_box(nls("Command not allowed in Read Only mode"));
      return(1);
   }
   mou_hour_glass(true);
   p_window_id=_ctlfile2;
   _set_focus();
   _ctlfile2.top();_ctlfile2.up();
   _ctlfile1.top();_ctlfile1.up();
   int old=def_diff_edit_flags;
   def_diff_edit_flags|=DIFFEDIT_AUTO_JUMP;
   diff_next_difference('','No Messages');
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      DiffTextChangeCallback(0,_ctlfile1.p_buf_id);
      DiffTextChangeCallback(0,_ctlfile2.p_buf_id);
   }
   typeless status=0;
   for (;;) {
      status=_ctlfile2.diff_copy_block('No Messages', true,  true);
      if (status) break;
   }
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      DiffClearAllColorInfo(_ctlfile1.p_buf_id);
      DiffClearAllColorInfo(_ctlfile2.p_buf_id);
   }
   refresh();//This is important.  Otherwise, the callback gets called with most of the file
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      DiffTextChangeCallback(1,_ctlfile1.p_buf_id);
      DiffTextChangeCallback(1,_ctlfile2.p_buf_id);
   }
   def_diff_edit_flags=old;
   _DiffSetNeedRefresh(true);
   p_window_id=_ctlfile2;
   ReturnFocusToEditWindow();
   mou_hour_glass(false);
   return(0);
}

static void merge_copy_block()
{
   int lineflags=_lineflags();
   curflag := 0;
   if (lineflags&MODIFY_LF) {
      curflag=MODIFY_LF;
   }else if (lineflags&INSERTED_LINE_LF) {
      curflag=INSERTED_LINE_LF;
   }
   if (!curflag) {
      return;
   }
   while (!up()) {
      if (!(_lineflags()&(curflag|NOSAVE_LF))) {
         down();
         break;
      }
   }
   _ctlfile2.p_line=p_line;
   for (;;) {
      if (!(_lineflags()&NOSAVE_LF)) {
         line := "";
         get_line(line);
         _ctlfile2._lineflags(0,~curflag);
         _ctlfile2._lineflags(curflag,curflag);
         _ctlfile2.safe_replace_line(line);
      }
      if (down() || _ctlfile2.down()) break;
      if (!(_lineflags()&(curflag|NOSAVE_LF))) {
         break;
      }
   }
}

static void CopyFile1Block()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   p_window_id=_ctlfile1;
   old_line1 := _ctlfile1.p_line;
   old_line2 := _ctlfile2.p_line;
   while (_lineflags()&(MODIFY_LF|NOSAVE_LF)) {
      _ctlfile1.up();_ctlfile2.up();
   }
   //_ctlfile1.diff_copy_block('',false);
   _ctlfile1.merge_copy_block();
   _ctlfile1.p_line=old_line1;
   _ctlfile2.p_line=old_line2;
   AddUndoNothing(_ctlfile2);
}

void _DiffAddUndoOther(int buf_id)
{
   int i;
   for (i=0;i<gDiffUpdateInfo.list._length();++i) {
      int fid=gDiffUpdateInfo.list[i].wid;
      if (fid._ctlfile1.p_buf_id==buf_id) {
         fid._ctlfile2._undo('S');
         AddUndoNothing(fid._ctlfile2);
         return;
      }
      if (fid._ctlfile2.p_buf_id==buf_id) {
         fid._ctlfile1._undo('S');
         AddUndoNothing(fid._ctlfile1);
         return;
      }
   }
}
static void diff_quote_key()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := 0;
   otherwid := GetOtherWid(wid);
   wid.quote_key();
   AddUndoNothing(otherwid);
}

static void diff_auto_functionhelp_key()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := 0;
   otherwid := GetOtherWid(wid);
   wid.auto_functionhelp_key();
   AddUndoNothing(otherwid);
}
static void diff_auto_codehelp_key()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := 0;
   otherwid := GetOtherWid(wid);
   wid.auto_codehelp_key();
   AddUndoNothing(otherwid);
}

static void diff_codehelp_complete()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := 0;
   otherwid := GetOtherWid(wid);
   oldcol := wid.p_col;
   wid.codehelp_complete();
   if (wid.p_col!=oldcol) {
      AddUndoNothing(otherwid);
   }
}

static void diff_gui_goto_line()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := 0;
   otherwid := GetOtherWid(wid);
   origParam1 := _param1;
   wid.gui_goto_line();
   _param1 = origParam1;
   otherwid.p_line=wid.p_line;
   wid.center_line();
   otherwid.center_line();
}

static void diff_seek(long seekPos)
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   _ctlfile1.goto_point(seekPos);
   _ctlfile1.p_scroll_left_edge=-1;
   _ctlfile2.p_scroll_left_edge=-1;
   _ctlfile2.p_line = _ctlfile1.p_line;
   _ctlfile1.center_line();
   _ctlfile2.center_line();
   _DiffUpdateScrollThumbs(true);
   _DiffSetNeedRefresh(true);
}

static void diff_fast_scroll()
{
   if (last_event()==ON_SB_END_SCROLL) {
      return;
   }

   int key=event2index(last_event());
   key&=(~VSEVFLAG_ALL_SHIFT_FLAGS);

   newVertVal := -1;
   newHorzVal := -1;
   switch (index2event(key)) {
   case WHEEL_RIGHT:
      newHorzVal = hscroll1.p_value+10;
      break;
   case WHEEL_DOWN:
      newVertVal = vscroll1.p_value+1;
      break;
   case WHEEL_LEFT:
      newHorzVal = hscroll1.p_value-10;
      break;
   case WHEEL_UP:
      newVertVal = vscroll1.p_value-1;
      break;
   }

   if ( newVertVal >=0 && newVertVal <= vscroll1.p_max ) {
      vscroll1.p_value = newVertVal;
   } else if ( newHorzVal >=0 && newHorzVal <= hscroll1.p_max ) {
      hscroll1.p_value = newHorzVal;
   }
}

static void diff_scroll_page_down()
{
   vscroll1.p_value+=vscroll1.p_large_change;
}

static void diff_scroll_page_up()
{
   vscroll1.p_value-=vscroll1.p_large_change;
}

static int diff_quit()
{
   if ( !_find_control("_ctlclose") ) {
      return 1;
   }
   return(_ctlclose.call_event(_ctlclose,LBUTTON_UP));
}

static void CopyFile2Block()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   p_window_id=_ctlfile1;
   old_line1 := _ctlfile1.p_line;
   old_line2 := _ctlfile2.p_line;
   while (!(_lineflags()&MODIFY_LF)) {
      _ctlfile1.down();_ctlfile2.down();
   }
   //_ctlfile1.diff_copy_block('',false);
   _ctlfile1.merge_copy_block();
   _ctlfile1.p_line=old_line1;
   _ctlfile2.p_line=old_line2;
   AddUndoNothing(_ctlfile1);
}

void diff_copy_line(int wid1,int wid2)
{
   wid1.p_scroll_left_edge=-1;
   wid2.p_scroll_left_edge=-1;
   ReadOnlyCheckBoxWID := _find_control(wid2.p_name'_readonly');
   if (ReadOnlyCheckBoxWID) {
      if (ReadOnlyCheckBoxWID.p_value) {
         _message_box(nls("Command not allowed in Read Only mode"));
         return;
      }
   }
   line := "";
   wid1._undo('S');
   wid2._undo('S');
   wid1.get_line(line);
   wid1._lineflags(0,NOSAVE_LF);
   wid2._lineflags(0,NOSAVE_LF);
   wid2.safe_replace_line(line);
   wid1._lineflags(0,MODIFY_LF|INSERTED_LINE_LF);
   wid2._lineflags(0,MODIFY_LF|INSERTED_LINE_LF);
   removeMarginButtonsFromLine(_ctlfile1.p_line);
   wid1.down();
   wid2.down();
   wid1.refresh('w');
   wid2.refresh('w');
   ReturnFocusToEditWindow();
   _DiffSetNeedRefresh(true);
}

const PREV_FILE_CAPTION="Prev File";
const NEXT_FILE_CAPTION="Next File";
const MFUPDATE_DIALOG_NAME="_svc_mfupdate_form";

int _ctlcopy_right_line.lbutton_up()
{
   if (DialogIsDiff()) {
      if ( _ctlfile2.DiffEditorIsReadOnly() ) {

         if ( maybeSwitchToLineDiff() ) {
            return 0;
         }else{
            _message_box(nls("Command not allowed in Read Only mode"));
         }

         return(1);
      }
      diff_copy_line(_ctlfile1,_ctlfile2);
   } else if ( p_active_form.p_name==MFUPDATE_DIALOG_NAME && p_caption==NEXT_FILE_CAPTION ) {
      _nocheck _control ctltree1;
      index := ctltree1._SVCGetCheckedIndex('N');
      if ( index>=0 ) {
         curFilename := ctltree1._SVCGetFilenameFromUpdateTree(index);
         ctltree1._TreeSetCurIndex(index);
         return 0;
      }
      origWID := p_window_id;
      p_window_id = ctltree1;
      nextIndex := _TreeGetNextIndex(_TreeCurIndex());
      diffableFiles := false;
      while ( nextIndex>=0 ) {
         _TreeGetInfo(nextIndex,auto state,auto bmindex1,bmindex1,auto flags,auto lineNumber,-1,auto overlays);
         diffableFiles = _SVCHaveDiffableFile(nextIndex,overlays);
         if ( diffableFiles ) {
            _TreeSetCurIndex(nextIndex);
            break;
         }
         nextIndex = _TreeGetNextIndex(nextIndex);
      }
      if ( !diffableFiles ) {
         if ( _DiffDialogIsSVCUpdate() ) {
            DiffMessageBox(get_message(VSDIFF_NO_MORE_DIFFERENCES_RC));
         } else {
            if (DiffMessageBox(get_message(VSDIFF_NO_MORE_DIFFERENCES_CLOSE_RC),MB_YESNO,IDNO) == IDYES) {
               // We already know we're in the svcupdate dialog
              if (_find_control('ctlclose')) {
                 _nocheck _control ctlclose;
                 ctlclose.call_event(ctlclose,LBUTTON_UP);
              }
              return(-1);
           }
         }
      }
      p_window_id = origWID;
   } else {
      _ctlfile1._undo('s');
      _ctlfile2._undo('s');
      wid := p_window_id;
      p_window_id=_ctlfile1;
      save_pos(auto p);
      top();up();
      while (!diff_next_difference()) {
         _ctlcopy_right.call_event(_ctlcopy_right,LBUTTON_UP);
         AddUndoNothing(_ctlfile1);
      }
      restore_pos(p);
      _ctlfile2.p_line=p_line;
      p_window_id=wid;
   }
   return(0);
}
int _ctlcopy_left_line.lbutton_up()
{
   diff_copy_line(_ctlfile2,_ctlfile1);
   return(0);
}

/** 
 * Prompt user to switch to line diff so that they can  
 * 
 * @return bool non-zero if user clicks Line Diff button
 */
static bool promptForLineDiff(bool &turnOffSourceDiff)
{
   turnOffSourceDiff = false;
   DIFF_READONLY_TYPE readOnly2=_GetDialogInfo(DIFFEDIT_READONLY2_VALUE,_ctlfile1);
   result := 0;
   if ( readOnly2!=DIFF_READONLY_SET_BY_USER ) {

      // Only show checkbox if Source Diff is turned on
      checkboxCaption := "";
      if ( !(def_diff_flags&DIFF_NO_SOURCE_DIFF) ) {
         checkboxCaption = "-CHECKBOX Set default to Line Diff";
      }
      result = textBoxDialog("Source Diff",
                              TB_RETRIEVE,
                              0,
                              '',
                              "Line Diff,Cancel:_cancel\t-html In <B>Source Diff</B> the file on the right is always read only.  You can edit both sides by using <B>Line Diff</B>.",//Button List
                              "",
                              checkboxCaption);
      if ( result==1 ) {
         if ( _param1==1 ) {
            // Checkbox was on
            turnOffSourceDiff = true;
         }
      }
   }
   return (result>0);
}

static int maybeSwitchToLineDiff()
{
   if (! _find_control("ctltypetoggle") ) {
      return 0;
   }
   if ( ctltypetoggle.p_caption=="Line Diff" ) {
      // We are in source diff, and could change to line diff
      switchToLineDiff := promptForLineDiff(auto turnOffSourceDiff);
      if ( switchToLineDiff ) {
         if ( turnOffSourceDiff==1 ) {
            def_diff_flags |= DIFF_NO_SOURCE_DIFF;
         }
         ctltypetoggle.call_event(ctltypetoggle,LBUTTON_UP);
      }
      return 1;
   }
   return 0;
}

int _ctlcopy_right.lbutton_up()
{
   if ( _ctlfile2.DiffEditorIsReadOnly() && !_DiffDialogIsSVCUpdate() ) {
      if ( maybeSwitchToLineDiff() ) {
         return 0;
      }else{
         _message_box(nls("Command not allowed in Read Only mode"));
      }

      return(1);
   }
   formWid := p_active_form;
   if (DialogIsDiff()) {
      switch (_ctlcopy_right.p_caption) {
      case 'Del Block':
         _ctlfile1.diff_delete_block();
         break;
      case 'Block>>':
         _ctlfile1.diff_copy_block();
         break;
      }
      if (!_iswindow_valid(formWid)) return(0);
   }else if ( _DiffDialogIsSVCUpdate() && p_caption==PREV_FILE_CAPTION ) {
      index := _SVCGetCheckedIndex('P');
      if ( index>=0 ) {
         _nocheck _control ctltree1;
         curFilename := ctltree1._SVCGetFilenameFromUpdateTree(index);
         ctltree1._TreeSetCurIndex(index);
      }
      origWID := p_window_id;
      _nocheck _control ctltree1;
      p_window_id = ctltree1;
      diffableFiles := false;
      nextIndex := _TreeGetPrevIndex(_TreeCurIndex());
      while ( nextIndex>=0 ) {
         _TreeGetInfo(nextIndex,auto state,auto bmindex1,bmindex1,auto flags,auto lineNumber,-1,auto overlays);
         diffableFiles = _SVCHaveDiffableFile(nextIndex,overlays);
         if ( diffableFiles ) {
            _TreeSetCurIndex(nextIndex);
            break;
         }
         nextIndex = _TreeGetPrevIndex(nextIndex);
      }
      if ( !diffableFiles ) {
         // Use VSDIFF_NO_MORE_DIFFERENCES_RC instead of 
         // VSDIFF_NO_MORE_DIFFERENCES_CLOSE_RC here because it's unlikely 
         // somebody is going to go through backwards and close the update
         // dialog
         if ( _DiffDialogIsSVCUpdate() ) {
            DiffMessageBox(get_message(VSDIFF_NO_MORE_DIFFERENCES_RC));
            return VSDIFF_NO_MORE_DIFFERENCES_RC;
         } else {
            if (DiffMessageBox(get_message(VSDIFF_NO_MORE_DIFFERENCES_RC),MB_YESNO,IDNO) == IDYES) { 
               return(-1);
            }
         }
      }
      p_window_id = origWID;
   }else{
      CopyFile1Block();
      if ( _ctlcopy_right.p_caption!=PREV_FILE_CAPTION ) {
         _ctlcopy_right.p_enabled=false;
      }
   }
   _DiffSetNeedRefresh(true);
   p_window_id=_ctlfile1;
   _ctlfile1.refresh('w');
   _ctlfile2.refresh('w');
   ReturnFocusToEditWindow();
   return(0);
}

int _ctlcopy_right_all.lbutton_up()
{
   if ( _ctlfile2.DiffEditorIsReadOnly() ) {
      if ( maybeSwitchToLineDiff() ) {
         return 0;
      }else{
         _message_box(nls("Command not allowed in Read Only mode"));
      }
      return(1);
   }
   typeless status=0;
   mou_hour_glass(true);
   p_window_id=_ctlfile1;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   if (DialogIsDiff()) {
      _ctlfile2.top();_ctlfile2.up();
      _ctlfile1.top();_ctlfile1.up();
      int old=def_diff_edit_flags;
      def_diff_edit_flags|=DIFFEDIT_AUTO_JUMP;
      diff_next_difference('','No Messages');
      if (DialogIsDiff()) {
         DiffTextChangeCallback(0,_ctlfile1.p_buf_id);
         DiffTextChangeCallback(0,_ctlfile2.p_buf_id);
      }
      for (;;) {
         status=_ctlfile1.diff_copy_block('No Messages', true,  true);
         if (status) break;
      }
      if (DialogIsDiff()) {
         DiffTextChangeCallback(1,_ctlfile1.p_buf_id);
         DiffTextChangeCallback(1,_ctlfile2.p_buf_id);
         DiffClearAllColorInfo(_ctlfile1.p_buf_id);
         DiffClearAllColorInfo(_ctlfile2.p_buf_id);
      }
      def_diff_edit_flags=old;
      _DiffSetNeedRefresh(true);
   }else{
      CopyFile2Block();
      _ctlcopy_right_all.p_enabled=false;
   }
   p_window_id=_ctlfile1;
   ReturnFocusToEditWindow();
   mou_hour_glass(false);
   return(0);
}

static void diff_find(...)
{
   origParam1 := _param1;
   typeless findarg=arg(1);
   wid := p_window_id;
   if (wid != _ctlfile1 && wid != _ctlfile2) {
      wid = LastActiveEditWindowWID;
   }
   if (wid==0) {
      wid = _ctlfile1;
   }
   typeless status=wid.gui_find_modal(findarg);
   if (wid==_ctlfile1) {
      _ctlfile2.p_col = _ctlfile1.p_col;
      _ctlfile2.p_line=_ctlfile1.p_line;
      _ctlfile2.set_scroll_pos(_ctlfile1.p_left_edge,_ctlfile1.p_cursor_y);
   }else if (wid==_ctlfile2) {
      _ctlfile1.p_col = _ctlfile2.p_col;
      _ctlfile1.p_line=_ctlfile2.p_line;
      _ctlfile1.set_scroll_pos(_ctlfile2.p_left_edge,_ctlfile2.p_cursor_y);
   }
   if (status && status!=COMMAND_CANCELLED_RC) {
      clear_message();
      _message_box(nls("String not found"));
   } else if ( !status ) {
      if ( wid==_ctlfile1 ) {
         _ctlfile1._set_focus();
      } else if ( wid==_ctlfile2 ) {
         _ctlfile2._set_focus();
      }
   }
   _param1 = origParam1;
}

static void diff_find_backwards()
{
   diff_find('-');
}

_ctlfind.lbutton_up()
{
   diff_find();
   _DiffSetNeedRefresh(true);
}

int _ctlfile1save.lbutton_up()
{
   typeless status=0;
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      status=_ctlfile1._diff_save();
      if ( !status ) {
         _SetDialogInfo(DIFFEDIT_CONST_FILE1_MODIFY,false);
      }
      ReturnFocusToEditWindow();
      return(status);
   }else{
      _ctlfile1._undo('s');
      _ctlfile2._undo('s');
      wid := p_window_id;
      p_window_id=_ctlfile1;
      save_pos(auto p);
      top();up();
      while (!diff_next_difference()) {
         _ctlcopy_right_all.call_event(_ctlcopy_right_all,LBUTTON_UP);
         AddUndoNothing(_ctlfile1);
      }
      restore_pos(p);
      _ctlfile2.p_line=p_line;
      p_window_id=wid;
   }
   return(0);
}

int _ctlfile2save.lbutton_up()
{
   typeless status=_ctlfile2._diff_save();
   if ( !status ) {
      _SetDialogInfo(DIFFEDIT_CONST_FILE2_MODIFY,false);
   }
   ReturnFocusToEditWindow();
   return(status);
}

void diffStartNewUndoStep(_str buf_name)
{
   if ( buf_name=="" ) return;
   wid:=window_match(buf_name,1,"xn",-1,"VG,VM,VA,GMA");
   if (wid) {
      wid._undo('s');
      return;
   }
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   status := load_files('+b 'buf_name);
   if ( !status ) {
      _undo('s');
   }
   p_window_id = origWID;
}

static void ReplaceMarkedSelection(int &MarkId,int MarkedBufId,int OldMarkId,int SourceViewId,_str origFile1PosMarker = '')
{
   orig_view_id := p_window_id;
   p_window_id=SourceViewId;
   int NewMarkId=_alloc_selection();
   saveAllPositions(MarkedBufId ,auto positionList);
   diffStartNewUndoStep(SourceViewId.p_buf_name);
   if (origFile1PosMarker!='' && origFile1PosMarker!=null ) {
      _begin_select(origFile1PosMarker);
   }
   top();
   _select_line(NewMarkId);
   bottom();
   status:=_select_line(NewMarkId);

   p_window_id=VSWID_HIDDEN;
   _safe_hidden_window();
   status=load_files('+bi 'MarkedBufId);

   // save bookmark, breakpoint, and annotation information
   status=_begin_select(OldMarkId);
   startRLine := p_RLine;
   status=_end_select(OldMarkId);
   endRLine := p_RLine;
   _SaveMarkersInFile(auto markerSaves, startRLine, endRLine);

   status=_begin_select(OldMarkId);
   orig_linenum := p_line;
   origModify := p_modify;
   status=_delete_selection(OldMarkId);
   if (p_line==orig_linenum) {
      //It should be safe to use p_line and p_Noflines here because the
      //whole file should be in memory anyway.
      up();
   }
   status=_copy_to_cursor(NewMarkId);
   _free_selection(OldMarkId);

   _RestoreMarkersInFile(markerSaves);
   //_free_selection(NewMarkId);
   {
      top();up();
      while (!down()) {
         flags := _lineflags(0, MODIFY_LF | INSERTED_LINE_LF );
      }
   }
   MarkId=NewMarkId;
   p_modify = origModify;
   p_window_id=orig_view_id;
   restoreAllPositions(MarkedBufId, positionList);
}

static int SaveBuffer(int BufId,_str &filename="")
{
   orig_view_id := p_window_id;
   infoWID := _ctlfile1;
   p_window_id=VSWID_HIDDEN;
   _safe_hidden_window();
   int orig_buf_id=p_buf_id;
   typeless status=load_files('+bi 'BufId);
   if (status) {
      return(status);
   }
   _str options = build_save_options(p_buf_name)" -l";
   if (isEclipsePlugin()) {
      options = "-CFE "options;
   }

   modifiedMarkerType := _GetDialogInfoHt("modifiedMarkerType",infoWID);
   insertedMarkerType := _GetDialogInfoHt("insertedMarkerType",infoWID);
   markerIndexes := _GetDialogInfoHt("markerIndexes",infoWID);

   SEDiffSetFlagsFromMarkers(orig_view_id,p_window_id,modifiedMarkerType,insertedMarkerType);
   status = SEDiffGetChecksum(p_window_id, auto origChecksum);
   // 10/19/2020
   // Can't use low-level save here because callbacks won't be called, most 
   // notably the one for FTP upload.  All of the other callbacks have been
   // checked to be sure they're safe
   status = (int)save_file(_maybe_quote_filename(p_buf_name),options);
   filename = p_buf_name;
   status = SEDiffGetChecksum(p_window_id, auto afterChecksum);

   if (status) {
      _message_box(nls("Could not save file '%s'\n\n%s",p_buf_name,get_message(status)));
      return(status);
   }
   status=load_files('+bi 'orig_buf_id);
   p_window_id=orig_view_id;
   _DiffSetNeedRefresh(true);
   return(status);
}

static bool DiffEditorIsReadOnly()
{
   if ( _DiffGetReadOnlyCBMissing()==1 ) {
      isro := _DiffGetReadOnly()==1;
      return(isro);
   }
   int readonly_cb_wid=p_name=='_ctlfile1'?_ctlfile1_readonly:_ctlfile2_readonly;
   return(readonly_cb_wid.p_value!=0);
}

void _SVCMaybeUpdateFileBitmap(int wholeBufID, SVCFileStatus &fileStatus, int index=-1)
{
   fileStatus = 0;
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   filename := "";
   bufferIsModified := false;
   status := load_files('+bi 'wholeBufID);
   if ( !status ) {
      filename = p_buf_name;
      bufferIsModified = p_modify;
   }
   p_window_id = origWID;
   if ( filename=="" ) return;

   VCSystemName := svc_get_vc_system(filename);
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) {
      return;
   }
   status = pInterface->getFileStatus(filename, fileStatus);
   if ( status ) return;

   _nocheck _control ctltree1;
   if ( index<0 ) {
      index = ctltree1._TreeCurIndex();
      if ( index < 0 ) return;
   }

   INTARRAY overlays;

   // Get the overlay for the status
   ctltree1._TreeGetInfo(index,auto state,auto bmindex1,auto bmindex2,auto flags,auto lineNumber,-1,overlays);

   hadOverlay := false;

   foundModified := false;
   INTARRAY overlayIndexesToRemove;
   // Take out statuses that we don't need
   // 8/29/2021 - Currently only supports modified and edited -- DWH
   for (i:=0; i < overlays._length(); ++i) {
      if ( (!(fileStatus&SVC_STATUS_MODIFIED) && overlays[i]==_pic_file_mod_overlay) ||
           (!bufferIsModified && overlays[i]==_pic_file_edited_overlay) 
           ) {
         overlayIndexesToRemove :+= i;
         hadOverlay = true;
         foundModified = !foundModified && overlays[i]==_pic_file_mod_overlay;
      }
   }

   len := overlayIndexesToRemove._length();
   for (i=len-1;i>=0;--i) {
      overlays._deleteel(overlayIndexesToRemove[i]);
   }

   // Add new overlays 
   // 8/29/2021 - Currently incomplete -- DWH
   if ( (fileStatus&SVC_STATUS_MODIFIED) && !foundModified ) {
      overlays :+= _pic_file_mod_overlay;
      hadOverlay = true;
   }
   if ( hadOverlay ) {
      ctltree1._TreeSetInfo(index, state, bmindex1, bmindex2, 0, 0, -1, overlays);
   }
}

int _diff_save(int index=-1)
{
   typeless status=0;
   result := "";
   options := " -l";

   wid := 0;
   otherwid := GetOtherWid(wid);

   /**
    * _diff_save is not called from Eclipse.  This is here as a 
    * workaround in case you are editing within DIFFzilla on an 
    * open buffer.  The buffer itself will not be marked as 
    * "dirty", so when it is saved from diffedit, _eclipse_save 
    * will not do anything. 
    *  
    * To get around this we tell SlickEdit that save was called 
    * from Eclipse, so SlickEdit does the saving. 
    */ 
   if (isEclipsePlugin()) {
      options = "-CFE "options;
   }
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   if ( DiffEditorIsReadOnly() ) {
      //_message_box(get_message(COMMAND_NOT_ALLOWED_IN_READ_ONLY_MODE_RC));
      //return(COMMAND_NOT_ALLOWED_IN_READ_ONLY_MODE_RC);
      status=_DiffGetSaveAsInfo(options,result,p_name);
      if ( status ) {
         return(status);
      }
   }else{
      diffsave_callback_index := find_index("_diff_save_callback1",PROC_TYPE|COMMAND_TYPE);
      if (diffsave_callback_index && index_callable(diffsave_callback_index)) {
         _str FileTitles=_DiffGetDialogTitles();
         File1Title := strip(parse_file(FileTitles),'B','"');
         File2Title := strip(parse_file(FileTitles),'B','"');

         title := "";
         id := 0;
         if (p_window_id==_ctlfile1) {
            id=1;
            title=File1Title;
         }else{
            id=2;
            title=File2Title;
         }
         status=call_index(p_window_id,id,title,diffsave_callback_index);
         return(status);
      }

      _ctlfile1._undo('S');
      _ctlfile2._undo('S');
      onlyOverlay := _GetDialogInfoHt("onlyOverlay",_ctlfile2);
      if (p_window_id==_ctlfile1 &&
          misc!=null &&
          misc.buffer1.WholeFileBufId>=0) {
         if ( misc.buffer1.MarkId>0 ) {
            _ctlfile1._save_pos2(auto p);
            origFile1PosMarker := "";
            origFile1PosMarker = _GetDialogInfoHt("origFile1PosMarker",_ctlfile1);
            ReplaceMarkedSelection(misc.buffer1.MarkId,misc.buffer1.WholeFileBufId,misc.buffer1.MarkId,p_window_id,origFile1PosMarker);
            _ctlfile1._restore_pos2(p);
            _DiffSetDiffShowingInfo(misc,_ctlfile1);
            filename := "";
            if ( onlyOverlay!=1 ) {
               status=SaveBuffer(misc.buffer1.WholeFileBufId,filename);
            }
            if (!status) {
               p_modify=false;
            }
            // This can only happen for file 1
            if ( _DiffDialogIsSVCUpdate() ) {
               STRARRAY selectedFileList;
               INTARRAY selectedIndexList;
               selectedFileList[0]  = filename;
               _nocheck _control ctltree1;
               selectedIndexList[0] = ctltree1._TreeCurIndex();
               VCSystemName := svc_get_vc_system(filename);
               IVersionControl *pInterface = svcGetInterface(VCSystemName);
               if ( pInterface!=null ) {
                  removedAllOverlays := false;
                  _SVCUpdateRefreshAfterOperation(selectedFileList,selectedIndexList,null,pInterface,false,removedAllOverlays:removedAllOverlays);
                  if ( removedAllOverlays ) {
                     // We know it has to be the one we were working on because 
                     // we only passed one in
                     _SVCSetupDiffTextFiles();
                     _SVCLoadBlankFilesForDisabled();
                  }
               }
            }
            return(status);
         }
      } else if (p_window_id==_ctlfile2 &&
                misc!=null &&
                misc.buffer2.WholeFileBufId>=0) {
         if ( misc.buffer2.MarkId>0 ) {
            _ctlfile2._save_pos2(auto p);
            ReplaceMarkedSelection(misc.buffer2.MarkId,misc.buffer2.WholeFileBufId,misc.buffer2.MarkId,p_window_id);
            _ctlfile2._restore_pos2(p);
            _DiffSetDiffShowingInfo(misc,_ctlfile1);
            if ( onlyOverlay!=1 ) {
               status=SaveBuffer(misc.buffer2.WholeFileBufId);
            }
            if (!status) {
               p_modify=false;
            }
            return(status);
         }
      } else if (p_buf_name=="") {
         status=_DiffGetSaveAsInfo(options,result,p_name);
         if ( status ) {
            return(status);
         }
      }
   }
   _project_disable_auto_build(true);
   p_AllowSave=true;
   // Do not have to use _maybe_quote_filename() here because result comes from
   // _SetDialogInfo and it will quote the file name piece if necessary. If we
   // call _maybe_quote_filename(), there may be options before the file name which
   // will cause us to quote it un-necessarily
   int rv=save(options" "result);
   filename := result;
   _maybe_strip(filename,'"',true);
   AddUndoNothing(otherwid);
   if ( _DiffDialogIsSVCUpdate() ) {
      STRARRAY selectedFileList;
      INTARRAY selectedIndexList;
      _nocheck _control ctltree1;
      if ( index > 0 ) {
         selectedIndexList[0] = index;
      } else {
         selectedIndexList[0] = ctltree1._TreeCurIndex();
      }
      filename = selectedFileList[0] = _SVCGetFilenameFromUpdateTree(selectedIndexList[0]);
      VCSystemName := svc_get_vc_system(filename);
      IVersionControl *pInterface = svcGetInterface(VCSystemName);
      if ( pInterface!=null ) {
         removedAllOverlays := false;
         _SVCUpdateRefreshAfterOperation(selectedFileList,selectedIndexList,null,pInterface,false,removedAllOverlays:removedAllOverlays);
         if ( removedAllOverlays ) {
            _SVCSetupDiffTextFiles();
            _SVCLoadBlankFilesForDisabled() ;
         }
      }
   }
   _DiffSetNeedRefresh(true);
   _project_disable_auto_build(false);
   return(rv);
}

static int _DiffGetSaveAsInfo(_str &options,_str &result,_str windowName)
{
   result=_OpenDialog('-new -modal',
        'Save As',
        _last_wildcards,     // Initial wildcards
        //'*.c;*.h',
        def_file_types,  // file types
        OFN_SET_LAST_WILDCARDS|OFN_SAVEAS,
        def_ext,      // Default extensions
        "", // Initial filename
        '',      // Initial directory
        '',      // Reserved
        "Save As dialog box"
        );
   if (result=='') {
      return(COMMAND_CANCELLED_RC);
   }
   lang := p_LangId;
   if (_file_eq(lang,"fundamental")) {
      //name(result);
   } else {
      //name(result);
      if (p_LangId == 'fundamental' ||
          _file_eq(_get_extension(p_buf_name),'sql')
          ) {
         _DiffSetEditorLanguage(lang);
      }
      _DiffSetDocumentName("");
   }
   p_buf_flags&=~VSBUFFLAG_PROMPT_REPLACE;
   if ( p_active_form.p_name=='_diff_form' ) {
      labelwid := 0;
      if (p_window_id==_ctlfile1) {
         labelwid=_ctlfile1label;
      }else{
         labelwid=_ctlfile2label;
      }
      labelwid.p_caption=p_buf_name'(Buffer)';//File cannot be modified
   }
   return(0);
}

_ctlnext_difference.lbutton_up(bool startAtLine0=false)
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   if (startAtLine0) {
      _ctlfile1.p_line=_ctlfile2.p_line=0;
   }
   status := _ctlfile1.diff_next_difference();
   if (status!=-1) {
      _DiffSetNeedRefresh(true);
      ReturnFocusToEditWindow();
   }
}

static void ReturnFocusToEditWindow()
{
   if ( _iswindow_valid(LastActiveEditWindowWID) ) {
      LastActiveEditWindowWID._set_focus();
   }
}

void _ctlprev_difference.lbutton_up()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   if (_ctlfile1.diff_next_difference('-') < 0) return;
   //this is a nasty little trick I'm playing to get the scroll to
   //refresh properly
   p_window_id=_ctlfile1;
   _scroll_page('d',1);
   _scroll_page('u',1);
   p_window_id=_ctlfile2;
   _scroll_page('d',1);
   _scroll_page('u',1);
   _DiffSetNeedRefresh(true);
   ReturnFocusToEditWindow();
}

static void diff_mode_space()
{
   otherwid := GetOtherWid(auto wid);
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');

   mode_name := "";
   key_index := 0;
   index := 0;
   if ( wid.select_active() ) {
      if (!_within_char_selection() ) {
         deselect();
         _diff_docharkey();
         _ctlfile2.right();
         AddUndoNothing(_ctlfile2);
      } else {
         diff_multi_delete();
      }
      return;
   }
   _UndoPushModify(otherwid);
   if (last_event():==' ') {
      key_index=event2index(last_event());
      index=eventtab_index(_default_keys,p_mode_eventtab,key_index);
   } else {
      parse lowcase(p_mode_name) with mode_name '-' .;
      index=find_index(mode_name'_space',COMMAND_TYPE);
      if (index <= 0) {
         key_index=event2index(last_event());
         index=eventtab_index(_default_keys,p_mode_eventtab,key_index);
      }
   }
   if (index) {
      call_index(index);
   }else{
      maybe_complete();
   }
   if (wid.p_Noflines>old_num_lines) {
      int i,origwid=p_window_id;
      p_window_id=otherwid;
      p_line=old_linenum;
      int numLinesInserted = wid.p_Noflines-old_num_lines;
      for (i=1;i<=numLinesInserted;++i) {
         DiffInsertImaginaryBufferLine();
      }
      for (i=old_linenum;i<=old_linenum+((wid.p_Noflines-old_num_lines)*2)+1;++i) {
         // Callbacks come at inconvenient times.  Fix where lines where the 
         // wrong lines were compared.
         DiffUpdateColorInfo(_ctlfile1,i,_ctlfile2,i,0,1,false,false);
      }
      p_line=origwid.p_line;
      p_window_id=origwid;
   }
   _UndoPopModify(otherwid);
   AddUndoNothing(otherwid);
}

static void diff_move_text_tab()
{
   wid := p_window_id;
   if (NoSaveLine(p_line)) {
      _beep();
      return;
   }
   otherwid := 0;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid.move_text_tab();
   AddUndoNothing(otherwid);
}

static void diff_ctab()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid.c_tab();
   AddUndoNothing(otherwid);
   otherwid.p_col=wid.p_col;
}

static void diff_cbacktab()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid.cbacktab();
   otherwid.cbacktab();
   AddUndoNothing(otherwid);
}

static void diff_delete_or_cut_word(typeless *pfn)
{
   otherwid := 0;
   wid := p_window_id;
   if (NoSaveLine(p_line)) {
      _beep();
      return;
   }
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   oldwid := p_window_id;
   p_window_id=wid;
   origNumLines := wid.p_Noflines;

   bline := 0;
   eline := 0;
   typeless markid=_alloc_selection();
   WillJoinLine := false;
   save_pos(auto p);
   if (!pselect_word(markid)) {
      _begin_select(markid);
      bline=p_line;
      _end_select(markid);
      eline=p_line;
      p_line=bline;
      WillJoinLine=bline!=eline;
      if (WillJoinLine) {
         if (p_Noflines>p_line) {
            //We are not on the last line
            if (NoSaveLine(p_line+1)) {
               //The next line is an imaginary buffer line
               _free_selection(markid);
               _beep();
               restore_pos(p);
               return;//Blow out so we don't bring up the imaginary line
            }
         }
      }
   }
   _free_selection(markid);

   restore_pos(p);
   (*pfn)();
   ln := p_line;
   col := p_col;

   if (wid.p_Noflines!=origNumLines) {
      //InsertImaginaryLine();
      DiffInsertImaginaryBufferLine();
   }
   p_line=ln;p_col=col;
   AddUndoNothing(otherwid);
   p_window_id=oldwid;
}

static void diff_cut_word()
{
   diff_delete_or_cut_word(delete_word);
}
static void diff_delete_word()
{
   diff_delete_or_cut_word(cut_word);
}

static void diff_prev_or_next_word(typeless *pfn)
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');

   //AddUndoNothing did not want to work on this one so I gave in and did
   //it the hard way.. shouldn't cause a problem
   (*pfn)();
   oldwid := p_window_id;
   p_window_id=otherwid;
   (*pfn)();
   p_window_id=oldwid;
   //AddUndoNothing(otherwid);
   otherwid.p_line=wid.p_line;
   otherwid.p_col=wid.p_col;
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
}

static void diff_prev_word()
{
   diff_prev_or_next_word(prev_word);
}

static void diff_next_word()
{
   diff_prev_or_next_word(next_word);
}

static void diff_word_complete(_str fname)
{
   //This seems really screwy, but I gotta do some screwy stuff with undo...
   otherwid := 0;
   wid := p_window_id;
   if (NoSaveLine(p_line)) {
      _beep();
      return;
   }
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   wid._undo('S');
   otherwid._undo('S');
   typeless was_selected=select_active();
   index := find_index(fname,COMMAND_TYPE);
   typeless rv=call_index(index);
   if (rv==1 && was_selected) {
      index1 := find_index('complete-prev',COMMAND_TYPE);
      index2 := find_index('complete-next',COMMAND_TYPE);
      index3 := find_index('complete-more',COMMAND_TYPE);
      pi := prev_index();
      last_command_was_complete_command := (pi==index1||pi==index2||pi==index3);
      if (last_command_was_complete_command) {
         //say('AddUndoNothing 1');
         //AddUndoNothing(otherwid);
      }
   }
   if (rv==1) {
      AddUndoNothing(otherwid);
   }
   prev_index(index);
}

static void diff_complete_prev()
{
   diff_word_complete('complete-prev');
}

static void diff_complete_next()
{
   diff_word_complete('complete-next');
}

static void diff_complete_more()
{
   diff_word_complete('complete-more');
}

static void diff_find_matching_paren()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   typeless status=find_matching_paren();
   if (!status) {
      otherwid.p_line=wid.p_line;
      otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
      //AddUndoNothing(otherwid);
      //Do not need to add undo information for this operation
   }
}

static void diff_cut_end_line()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');

   origNumLines := wid.p_Noflines;

   p_window_id=wid;
   cut_end_line();

   ln := p_line;
   col := p_col;

   if (wid.p_Noflines!=origNumLines) {
      //InsertImaginaryLine();
      DiffInsertImaginaryBufferLine();
   }
   p_line=ln;p_col=col;
   AddUndoNothing(otherwid);
}

static void diff_expand_alias()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');

#if 0
   parse lowcase(p_mode_name) with mode_name '-' .;
   index=find_index(mode_name'_space',COMMAND_TYPE);
   if (index) {
      //wid.c_space();
      call_index(index);
   }else{
      maybe_complete();
   }
#endif
   i := 0;
   expand_alias();
   AddUndoNothing(otherwid);
   if (wid.p_Noflines>old_num_lines) {
      otherwid.p_line=old_linenum;
      for (i=1;i<=wid.p_Noflines-old_num_lines;++i) {
         //otherwid.InsertImaginaryLine();
         otherwid.DiffInsertImaginaryBufferLine();
      }
   }
}
static void diff_list_clipboards()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   old_num_lines := p_Noflines;
   old_linenum := p_line;
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');

   list_clipboards_modal();
   AddUndoNothing(otherwid);
   if (wid.p_Noflines>old_num_lines) {
      otherwid.p_line=old_linenum;
      for (i:=1;i<=wid.p_Noflines-old_num_lines;++i) {
         //otherwid.InsertImaginaryLine();
         otherwid.DiffInsertImaginaryBufferLine();
      }
   }
}

static void diff_undo()
{
   status1 := _ctlfile1.undo();
   status2 := _ctlfile2.undo();
   //say('diff_undo status1='status1' status2='status2);
   if ( status1<0 && status2>=0 ) {
      _ctlfile1.p_line = _ctlfile2.p_line;
   } else if ( status1>=0 && status2<0 ) {
      _ctlfile2.p_line = _ctlfile1.p_line;
   }
   otherwid := GetOtherWid(auto wid);
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);

   _DiffSetNeedRefresh(true);
}

static void diff_push_bookmark(int &wid,int &otherwid)
{
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   wid = otherwid = 0;
   otherwid=GetOtherWid(wid);

   otherwid._undo('S');
   wid._undo('S');

   _str Bookmarks[];
   Bookmarks=misc.Bookmarks;
   if (Bookmarks._varformat()!=VF_ARRAY) {
      Bookmarks._makeempty();
   }

   // Add bookmark bitmap. Get type, alloc if necessary
   bookmarkMarkerType := _GetDialogInfoHt("bookmarkMarkerType",wid.p_active_form);
   if ( bookmarkMarkerType==null ) {
      bookmarkMarkerType = _MarkerTypeAlloc();
      _SetDialogInfoHt("bookmarkMarkerType",bookmarkMarkerType,wid.p_active_form);
   }

   // Get pic index, find if necessary
   bookmarkPicIndex := _GetDialogInfoHt("bookmarkPicIndex",wid.p_active_form);
   if ( bookmarkPicIndex==null ) {
      bookmarkPicIndex = find_index("_ed_bookmark_pushed.svg",PICTURE_TYPE);
      _SetDialogInfoHt("bookmarkPicIndex",bookmarkPicIndex,wid.p_active_form);
   }
   // Finally, add bitmap to line
   lmIndex := _LineMarkerAdd(wid, wid.p_line, false, 0,
                             bookmarkPicIndex, bookmarkMarkerType,
                             "");

   Bookmarks[Bookmarks._length()]=wid.p_line','wid.p_col','wid.p_left_edge','wid.p_cursor_y','lmIndex;
   misc.Bookmarks=Bookmarks;

   _DiffSetDiffShowingInfo(misc,wid.p_window_id._ctlfile1);
}

static void diff_push_tag()
{
   diff_push_bookmark(auto wid, auto otherwid);
   int status=wid.goto_context_tag();
   if (status) {
      return;
   }

   otherwid.p_line=wid.p_line;
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
}

static void diff_push_tag_line(int linenum)
{
   diff_push_bookmark(auto wid,auto otherwid);

   otherwid.p_RLine = wid.p_RLine = linenum;
   wid.center_line();
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
}

static void diff_next_proc()
{
   wid := 0;
   otherwid := GetOtherWid(wid);

   otherwid._undo('S');
   wid._undo('S');

   typeless status=wid.next_proc();
   otherwid.p_line=wid.p_line;
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
}

static void diff_prev_proc()
{
   wid := 0;
   otherwid := GetOtherWid(wid);

   otherwid._undo('S');
   wid._undo('S');

   typeless status=wid.prev_proc();
   otherwid.p_line=wid.p_line;
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
}

static void diff_next_tag()
{
   wid := 0;
   otherwid := GetOtherWid(wid);

   otherwid._undo('S');
   wid._undo('S');

   typeless status=wid.next_tag();
   otherwid.p_line=wid.p_line;
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
}

static void diff_prev_tag()
{
   wid := 0;
   otherwid := GetOtherWid(wid);

   otherwid._undo('S');
   wid._undo('S');

   typeless status=wid.prev_tag();
   otherwid.p_line=wid.p_line;
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
}

static void diff_pop_bookmark()
{
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   _str Bookmarks[];
   Bookmarks=misc.Bookmarks;
   if (Bookmarks._varformat()!=VF_ARRAY) {
      Bookmarks._makeempty();
   }
   if (!Bookmarks._length()) {
      _beep();
      return;
   }
   typeless line='';
   typeless col='';
   typeless leftedge='';
   typeless cursory='';
   parse Bookmarks[Bookmarks._length()-1] with line ',' col ',' leftedge \
                                               ',' cursory ',' auto lmIndex ;
   Bookmarks._deleteel(Bookmarks._length()-1);
   misc.Bookmarks = Bookmarks;

   wid := 0;
   otherwid := GetOtherWid(wid);

   _DiffSetDiffShowingInfo(misc,_ctlfile1);

   otherwid._undo('S');
   wid._undo('S');

   wid.p_line=line;
   wid.p_col=col;
   wid.set_scroll_pos(leftedge,cursory);
   if ( isinteger(lmIndex) ) {
      wid._LineMarkerRemove((int)lmIndex);
   }

   otherwid.p_line=wid.p_line;
   otherwid.p_col=wid.p_col;
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
}

static void diff_undo_cursor()
{
   lindex := last_index('','C');
   pindex := prev_index('','C');
   _ctlfile2._undo('C');
   last_index(lindex,'C');prev_index(pindex,'C');
   _ctlfile1._undo('C');
   _DiffVscrollSetLast('');
   int YInLines=_ctlfile1.p_cursor_y intdiv _ctlfile1.p_font_height;
   vscroll1.p_value=_ctlfile1.p_line-YInLines;
   _DiffVscrollSetLast(_ctlfile1.p_line-YInLines);
   p_window_id=LastActiveEditWindowWID;
   wid := 0;
   OtherWid := GetOtherWid(wid);
   OtherWid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
   _DiffSetNeedRefresh(true);
   prev_index(0,'C');
   last_index(0,'C');
}

static void diff_select_line()
{
   otherwid := GetOtherWid(auto wid);
   otherwid._undo('S');
   wid._undo('S');
   wid.select_line();
}

static void diff_select_word()
{
   otherwid := GetOtherWid(auto wid);
   otherwid._undo('S');
   wid._undo('S');
   wid.select_word();
   otherwid.p_line = wid.p_line;
}

static void diff_select_subword()
{
   otherwid := GetOtherWid(auto wid);
   otherwid._undo('S');
   wid._undo('S');
   wid.select_subword();
   otherwid.p_line = wid.p_line;
}

static void diff_select_full_word()
{
   otherwid := GetOtherWid(auto wid);
   otherwid._undo('S');
   wid._undo('S');
   wid.select_full_word();
   otherwid.p_line = wid.p_line;
}

static void diff_select_whole_word()
{
   otherwid := GetOtherWid(auto wid);
   otherwid._undo('S');
   wid._undo('S');
   wid.select_whole_word();
   otherwid.p_line = wid.p_line;
}

static void diff_select_char()
{
   otherwid := GetOtherWid(auto wid);
   otherwid._undo('S');
   wid._undo('S');
   wid.select_char();
}

static void diff_deselect()
{
   if (!select_active()) return;
   otherwid := GetOtherWid(auto wid);
   wid._undo('S');
   otherwid._undo('S');
   wid.deselect();
}

static int GetOtherWid(int &wid)
{
   otherwid := 0;
   wid=p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   } else if ( wid==_ctlfile2 ) {
      otherwid=_ctlfile1;
   } else if ( wid==ctlcontextCombo1 ) {
      wid = _ctlfile1;
      otherwid=_ctlfile2;
   } else if ( wid==ctlcontextCombo2 ) {
      wid = _ctlfile2;
      otherwid=_ctlfile1;
   }
   return(otherwid);
}

static void diff_shift_selection_right()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   wid._undo('S');
   otherwid._undo('S');

   wid.shift_selection_right();

   AddUndoNothing(otherwid);
   _DiffSetNeedRefresh(true);
}

static void diff_shift_selection_left()
{
   wid := 0;
   otherwid := p_window_id.GetOtherWid(wid);
   wid._undo('S');
   otherwid._undo('S');

   wid.shift_selection_left();

   AddUndoNothing(otherwid);
   _DiffSetNeedRefresh(true);
}

static void diff_maybe_complete()
{
   wid := 0;
   otherwid := p_window_id.GetOtherWid(wid);
   wid._undo('S');
   otherwid._undo('S');

   wid.maybe_complete();
   otherwid.right();
   AddUndoNothing(otherwid);
   _DiffSetNeedRefresh(true);
}

static void diff_mou_select_word()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   otherwid._undo('S');
   wid._undo('S');
   wid.mou_select_word();
   AddUndoNothing(otherwid);
}

static void diff_mou_select_line()
{
   otherwid := 0;
   wid := p_window_id;
   if (wid==_ctlfile1) {
      otherwid=_ctlfile2;
   }else{
      otherwid=_ctlfile1;
   }
   otherwid._undo('S');
   wid._undo('S');
   wid.mou_select_line();
   AddUndoNothing(otherwid);
}

static void diff_rubout()
{
   if (OnImaginaryLine()) {
      return;
   }
   if (select_active() && _within_char_selection()) {
      //DiffMessage('Mark deletes not yet available');
      diff_linewrap_delete_char('delete-selection');
      return;
   }
   if (p_col==1) {
      return;
   }
   wid := 0;
   otherwid := p_window_id.GetOtherWid(wid);
   wid._undo('S');
   otherwid._undo('S');

   wid.rubout();
   otherwid.left();
   AddUndoNothing(otherwid);

   _DiffSetNeedRefresh(true);
}

static int OnImaginaryLine()
{
   return(_lineflags()&NOSAVE_LF);
}

static void diff_linewrap_rubout()
{
   if (OnImaginaryLine()) {
      return;
   }
   if (select_active() && _within_char_selection()) {
      diff_linewrap_delete_char('delete-selection');
      return;
   }
   wid := 0;
   otherwid := p_window_id.GetOtherWid(wid);
   orig_numlines := p_Noflines;
   wid._undo('S');
   otherwid._undo('S');

   orig_line := "";
   if (!wid.up()) {
      wid.get_line(orig_line);wid.down();
   }
   wid.linewrap_rubout();
   if (wid.p_Noflines<orig_numlines) {
      MaybeMakeLineReal();
      DiffInsertImaginaryBufferLine();
      up();_end_line();
      AddUndoNothing(otherwid);
      otherwid.p_line=wid.p_line;
      wid.p_col=length(orig_line)+1;
   }
   AddUndoNothing(otherwid);

   _DiffSetNeedRefresh(true);
}

static void diff_multi_delete(...)
{
   if ((arg(1)==''||p_word_wrap_style&WORD_WRAP_WWS) && OnImaginaryLine()) {
      if (p_col>=length(_expand_tabsc())) return;
   }
   if (p_col > _text_colc()) {
      if (!down()) {
         if (OnImaginaryLine()) {
            if (arg(1)=='' ||
                arg(1)=='linewrap-delete-char'||
                arg(1)=='delete-char') {
               DiffMessageBox('Cannot split Imaginary line');
               up();
               return;
            }
         }
         up();
      }
   }

   wid := 0;
   otherwid := p_window_id.GetOtherWid(wid);
   orig_numlines := p_Noflines;
   wid._undo('S');
   otherwid._undo('S');

   origline := wid.p_line;
   onlast := OnLastLine();
   int isimaginary=wid._lineflags()&NOSAVE_LF;
   if (isimaginary && !DialogIsDiff()) {
      return;
   }
   oldmodify := false;
   oldwid := 0;
   switch (arg(1)) {
   case 'cut':
      wid.cut();break;
   case 'linewrap-delete-char':
      wid.linewrap_delete_char();break;
   case 'delete-char':
      wid.linewrap_delete_char();break;
   case 'cut-line':
      oldmodify=wid.p_modify;
      wid.cut_line();
      if (isimaginary) wid.p_modify=oldmodify;
      break;
   case 'delete-line':
      oldmodify=p_modify;
      wid._delete_line();
      if (isimaginary) p_modify=oldmodify;
      break;
   case 'delete-selection':
      wid.delete_selection();break;
   default:
      wid._begin_select();
      oldwid=p_window_id;p_window_id=wid;
      _delete_selection();
      p_window_id=oldwid;
      wid.keyin(last_event());
      break;
   }

   i := 0;
   old_col := 0;
   cur_num_lines := 0;
   if (wid.p_Noflines<orig_numlines) {
      cur_num_lines=wid.p_Noflines;
      otherwid.p_line=origline;
      if (!wid.OnLastLine()) {
         otherwid.p_line=wid.p_line;
      }
      wasModified := p_modify;
      wasOtherModified := otherwid.p_modify;
      _UndoPushModify(otherwid);

      for (i=1;i<=orig_numlines-cur_num_lines;++i) {
         old_col=p_col;
         if (!otherwid.OnImaginaryLine()) {
            if (!onlast) {
               up();
            }
            //InsertImaginaryLine();
            DiffInsertImaginaryBufferLine();
            if (!onlast) {
               down();
            }
            otherwid.set_line_inserted();
            otherwid.down();
            AddUndoNothing(otherwid);
         }else{
            AddUndoNothing(wid);
            wid=p_window_id;
            p_window_id=otherwid;
            oldmodify=p_modify;
            isimaginary=_lineflags()&NOSAVE_LF;
            _delete_line();
            if (isimaginary) {
               p_modify=oldmodify;
            }
            p_window_id=wid;
         }
         p_col=old_col;
      }
      _UndoPopModify(otherwid);
      otherwid.p_line=wid.p_line;
   }
   if (_lineflags()&MODIFY_LF) {
      otherwid._lineflags(MODIFY_LF,MODIFY_LF);
   }
   AddUndoNothing(otherwid);

   otherwid.set_scroll_pos(otherwid.p_left_edge,wid.p_cursor_y);
   _DiffSetNeedRefresh(true);
   _DiffSetupScrollBars();
}

static void diff_linewrap_delete_char(...)
{
   if (select_active()) {
      diff_multi_delete('delete-selection');
      return;
   }
   diff_multi_delete('linewrap-delete-char');
}

static void diff_delete_char()
{
   if (select_active()) {
      diff_multi_delete('delete-selection');
      return;
   }
   diff_multi_delete('delete-char');
}

static void diff_cut_line()
{
   if (select_active()) {
      //DiffMessage('Mark deletes not yet available');
      diff_multi_delete('cut');
      return;
   }
   diff_multi_delete('cut-line');
}

static void diff_join_line()
{
   lf := 0;
   wid := 0;
   otherwid := GetOtherWid(wid);
   origNumLines := p_Noflines;
   typeless status=down();
   if (!status) {
      lf=_lineflags();
      up();
   }
   if (lf&NOSAVE_LF) {
      DiffMessageBox('Cannot join Imaginary line');
      return;
   }
   wid._undo('S');
   otherwid._undo('S');
   join_line();
   save_pos(auto p);
   if (origNumLines!=p_Noflines) {
      int nlines=otherwid.GetNumberOfImaginaryLines(1);
      if (!nlines) {
         //InsertImaginaryLine();
         DiffInsertImaginaryBufferLine();
      }else{
         otherwid._delete_line();
      }
   }
   restore_pos(p);
   AddUndoNothing(otherwid);
}

static void diff_delete_line()
{
   if (select_active()) {
      //DiffMessage('Mark deletes not yet available');
      diff_multi_delete('delete-selection');
      return;
   }
   diff_multi_delete('delete-line');
}

static void AddUndoNothing(int wid)
{
   // Setting lineflags to themselves will set undo information
   origWID := p_window_id;
   p_window_id = wid;

   oldmodify := p_modify;
   oldflags := _lineflags();

   // Toggle MODIFY_LF to be sure some undo
   // information is created.
   if ( oldflags&MODIFY_LF ) {
      _lineflags(0,MODIFY_LF);
      _lineflags(MODIFY_LF,MODIFY_LF);
   } else {
      _lineflags(MODIFY_LF,MODIFY_LF);
      _lineflags(0,MODIFY_LF);
   }
   p_modify = oldmodify;
   p_window_id = origWID;
}

static _str GetClipboardType(...)
{
   retval := "";
   noflines := "";
   view_id := 0;
   get_window_id(view_id);
   int status=find_view('.clipboards');
   if ( ! status ) {
      line := "";
      get_line(line);
      mark_name := "";
      parse line with ':' mark_name noflines . ;
      if( !pos(' 'mark_name' ',' LINE CHAR BLOCK ') ) {
         retval='invalid';
      } else {
         retval=mark_name' 'noflines;
      }
   } else {
      // This should never happen unless clipbd.e has
      // not been loaded.
      retval='No clipboards';
   }
   clipbd_view_id := 0;
   get_window_id(clipbd_view_id);
   activate_window(view_id);
   arg(1)=noflines;
   return(retval);
}

static void diff_next_window(bool find_backward=false)
{
   if ( _jaws_mode() ) {
      if ( find_backward ) {
         _prev_control();
      }else{
         _next_control();
      }
   }else{
      wid := 0;
      otherwid := GetOtherWid(wid);
      otherwid._set_focus();
   }
}

static void diff_append_to_clipboard()
{
   wid := 0;
   otherwid := GetOtherWid(wid);

   wid._undo('S');
   otherwid._undo('S');

   typeless was_selected=select_active();
   wid.append_to_clipboard();
   //4:27pm 4/14/1998
   //Only want this if there was a selection
   if (was_selected) {
      AddUndoNothing(otherwid);
   }
}

static void diff_copy_to_clipboard()
{
   wid := 0;
   otherwid := GetOtherWid(wid);

   wid._undo('S');
   otherwid._undo('S');

   typeless was_selected=select_active();
   wid.copy_to_clipboard();
   //4:27pm 4/14/1998
   //Only want this if there was a selection
   if (was_selected) {
      AddUndoNothing(otherwid);
   }
}

static void diff_copy_word()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   if (NoSaveLine(p_line)) {
      _beep();
      return;
   }

   bline := 0;
   eline := 0;
   typeless markid=_alloc_selection();
   WillJumpLine := false;
   save_pos(auto p);
   if (!pselect_word(markid)) {
      _begin_select(markid);
      bline=p_line;
      _end_select(markid);
      eline=p_line;
      p_line=bline;
      WillJumpLine=bline!=eline;
      if (WillJumpLine) {
         if (p_Noflines>p_line) {
            //We are not on the last line
            if (NoSaveLine(p_line+1)) {
               //The next line is an imaginary buffer line
               _free_selection(markid);
               _beep();
               restore_pos(p);
               return;//Blow out so we don't bring up the imaginary line
            }
         }
      }
   }
   restore_pos(p);
   _free_selection(markid);
   wid._undo('S');
   otherwid._undo('S');
   wid.copy_word();
   //4:27pm 4/14/1998
   //This seems to mess things up
   //AddUndoNothing(otherwid);
   otherwid.p_line=wid.p_line;
}

static int GetNumberOfImaginaryLines(int noflines)
{
   save_pos(auto p);
   i := count := 0;
   for (i=1;i<=noflines;++i) {
      if (_lineflags()&NOSAVE_LF) {
         ++count;
      }
      if (down()) {
         break;
      }
   }
   restore_pos(p);
   return(count);
}

static void diff_paste_replace_word()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   wid._undo('S');otherwid._undo('S');
   paste_replace_word();
   AddUndoNothing(otherwid);
}

static void diff_paste()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   orig_numlines := p_Noflines;
   wid._undo('S');otherwid._undo('S');

   typeless noflines_pasted='';//passed by reference to GetClipboardType
   typeless ctype=GetClipboardType(noflines_pasted);
   typeless type='';
   parse ctype with type . ;
   int noflines_imaginary=GetNumberOfImaginaryLines(noflines_pasted);
   moved := false;
   i := 0;
   lf := 0;
   if (noflines_imaginary>noflines_pasted) {
      for (i=1;i<=noflines_pasted;++i) {
         if (type=='LINE') {
            lf=_lineflags();
            if (lf&NOSAVE_LF) {
               _delete_line();
               moved=true;
            }
         }else{
            MaybeMakeLineReal();
         }
      }
   }else if (noflines_imaginary<=noflines_pasted) {
      //say('noflines_imaginary='noflines_imaginary);
      for (i=1;i<=noflines_imaginary;++i) {
         if (type=='LINE') {
            lf=_lineflags();
            if (lf&NOSAVE_LF) {
               _delete_line();
               moved=true;
            }
         }else{
            MaybeMakeLineReal();
         }
      }
   }
   typeless seltype='';
   SelSize := 0;
   if (wid.select_active()) {
      seltype=_select_type('','S');
      _begin_select();
      FirstLine := p_line;
      _end_select();
      LastLine := p_line;
      SelSize=LastLine-FirstLine;
      _select_type('','S',seltype);
      if (_select_type()=='LINE') {
         ++SelSize;
      }
   }
   if (moved && p_line!=p_Noflines) {
      up();
   }
   insert_after := ( (type=='CHAR') || (strip(upcase(def_line_insert))=='A') );
   origline := wid.p_line;
   origotherline := otherwid.p_line;
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      DiffTextChangeCallback(0,_ctlfile1.p_buf_id);
      DiffTextChangeCallback(0,_ctlfile2.p_buf_id);
   }
   wid.paste();AddUndoNothing(otherwid);
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      DiffTextChangeCallback(1,_ctlfile1.p_buf_id);
      DiffTextChangeCallback(1,_ctlfile2.p_buf_id);
   }
   cur_numlines := wid.p_Noflines;
   if (cur_numlines>orig_numlines) {
      for (i=1;i<=cur_numlines-orig_numlines/*-noflines_imaginary*/;++i) {
         //otherwid.InsertImaginaryLine();
         otherwid.DiffInsertImaginaryBufferLine();
         if (!insert_after) otherwid.up();
         AddUndoNothing(otherwid);
         if (!insert_after) otherwid.down();
      }
   }else if (cur_numlines<orig_numlines) {
      for (i=1;i<=(orig_numlines-cur_numlines)-SelSize;++i) {
         //InsertImaginaryLine();
         otherwid.DiffInsertImaginaryBufferLine();
         if (!insert_after) otherwid.up();
         otherwid.AddUndoNothing(otherwid);
         if (!insert_after) otherwid.down();
      }
      if (SelSize>0) {
         save_pos(auto p);
         for (i=0;i<SelSize;++i) {
            DiffInsertImaginaryBufferLine();
         }
         restore_pos(p);
      }
   }
   //fsay('origline='origline' wid.p_line='wid.p_line' noflines_pasted='noflines_pasted' p_Noflines='p_Noflines);
   //say('origline='origline' wid.p_line='wid.p_line' noflines_pasted='noflines_pasted' p_Noflines='p_Noflines);
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      if (noflines_pasted=='') {
         DiffUpdateColorInfo(_ctlfile1,_ctlfile1.p_line,_ctlfile2,_ctlfile2.p_line,0,1,true,false);
      }else{
         for (i=origline+1;i<wid.p_line+noflines_pasted-1;++i) {
            //fsay('diffing i='i);
            //say('diffing i='i);
            DiffUpdateColorInfo(_ctlfile1,i,_ctlfile2,i,0,1,true,false);
         }
      }
   }
   otherwid.p_line=wid.p_line;
   otherwid.set_scroll_pos(otherwid.p_left_edge,wid.p_cursor_y);
   _DiffSetupScrollBars();
}

static void diff_close_form()
{
   if ( _DiffGetCloseMissing()!=1 ) {
      _ctlclose.call_event(_ctlclose,LBUTTON_UP);
   }else{
      wid := _find_control("ctlclose");
      if ( wid ) {
         wid.call_event(wid,LBUTTON_UP);
      } else {
         p_active_form._delete_window();
      }
   }
}

static void diff_cua_select()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   in_cua_select=true;_argument=1;
   cua_select();
   _argument="";
   in_cua_select=false;
   AddUndoNothing(otherwid);
   _dont_use_diff_command=1;
   otherwid.p_line=wid.p_line;
   _dont_use_diff_command=0;
}

#pragma option(deprecateconst,off)

static void diff_maybe_deselect()
{
   if (in_cua_select) return;
   if (select_active()) {
      if ( _select_type('','U')!='P') {
         diff_deselect();
      }
   }
}
static void addCopyButtonsToCurrentLines()
{
   copyLeftType := _GetDialogInfoHt("copyLeftType",_ctlfile1);
   copyRightType := _GetDialogInfoHt("copyRightType",_ctlfile1);
   _LineMarkerAdd(_ctlfile1,_ctlfile1.p_line,false,1,_pic_merge_right,copyRightType,"Copy this block to the other file");
   _LineMarkerAdd(_ctlfile2,_ctlfile2.p_line,false,1,_pic_merge_left,copyLeftType,"Copy this block to the other file");
}

static bool didLineCopy(_str origEventName)
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   origLineNumber := p_line;
   _LineMarkerFindList(auto list1,p_window_id,p_line,VSNULLSEEK,true);
   widCopyRight := _find_control("_ctlcopy_right");
   widCopyRightLine := _find_control("_ctlcopy_right_line");
   widCopyLeft := _find_control("_ctlcopy_left");
   widCopyLeftLine := _find_control("_ctlcopy_left_line");
   diff_label_copy_buttons(widCopyRight, widCopyRightLine,
                           widCopyLeft,  widCopyLeftLine);
   INTARRAY list2;
   if (origEventName=="C-S-LBUTTON-DOWN") {
      // If we were on the bitmap, we have to get rid of it when we're done
      // because it no longer will work because the first line will not 
      // have lineflags set
      if ( list1._length()>0 && _lineflags()&(VSLF_NOSAVE|VSLF_MODIFY|VSLF_INSERTED_LINE) ) {
         _LineMarkerFindList(list2,otherwid,otherwid.p_line,VSNULLSEEK,true);
         if (list2._length()>0) {
            deselect();
         }
      }
      buttonWID := (p_window_id==_ctlfile1)?_ctlcopy_right_line:_ctlcopy_left_line;
      if (buttonWID.p_enabled) {
         buttonWID.call_event(buttonWID,LBUTTON_UP);
      }
      if (!_iswindow_valid(wid)) return true;
      if ( _lineflags()&(VSLF_NOSAVE|VSLF_MODIFY|VSLF_INSERTED_LINE) ) {
         addCopyButtonsToCurrentLines();
      }
      return true;
   } else if (list1._length()>0) {

      deselect();
      buttonWID := (p_window_id==_ctlfile1)?widCopyRight:widCopyLeft;
      flagsBeforeCopy := _lineflags();
      if (buttonWID!=0 && buttonWID.p_enabled) {
         status := buttonWID.call_event(buttonWID,LBUTTON_UP);
      }
      if (!_iswindow_valid(wid)) return true;
      if (_iswindow_valid(otherwid)) {
         otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
      }
      return true;
   }
   return false;
}

static void diff_mou_click()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   wid._undo('s');
   otherwid._undo('s');
   origEventName := event2name(last_event());
   wid.mou_click();
   AddUndoNothing(otherwid);
   otherwid.p_line=wid.p_line;
   otherwid.p_col=wid.p_col;
   otherwid.refresh('W');
   _DiffSetNeedRefresh(true);

   int mx=mou_last_x('D');
   int my=mou_last_y('D');
   wx := wy := 0;
   _map_xy(p_window_id,0,wx,wy);
   mx-=wx;my-=wy;
   marginWidth := _lx2dx(SM_TWIP,_default_option('l'));

   //if (mx<=marginWidth) {
   if (mou_last_x() < _adjusted_windent_x()) {
      if ( didLineCopy(origEventName) ) {
         return;
      }
   }

   //otherwid.set_scroll_pos(otherwid.p_left_edge,wid.p_cursor_y);
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
   //AddUndoNothing(otherwid);
   if ( wid.p_mouse_pointer == MP_ARROW) {
      DIFF_ALIGN align;
      if ( _lineflags()&NOSAVE_LF ) {
         return;
      }
      long setSeekPos = 0;
      _save_pos2(auto p);
      _begin_line();
      if ( wid.p_name=="_ctlfile1" ) {
         setSeekPos = align.pos1 = _QROffset();
         align.lineNum1 = p_RLine;
         align.pos2 = _GetDialogInfoHt("pending2");
         _SetDialogInfoHt("pending2",null);
      }else if (wid.p_name=="_ctlfile2") {
         align.pos1 = _GetDialogInfoHt("pending1");
         setSeekPos = align.pos2 = _QROffset();
         align.lineNum2 = p_RLine;
         _SetDialogInfoHt("pending1",null);
      }
      _restore_pos2(p);
      wid.p_mouse_pointer = MP_DEFAULT;
      addToGlobalAligns(align);
      rediff();

      // Get scroll positions right
      _ctlfile1.top(); 
      _ctlfile2.top(); 
      if ( wid.p_name=="_ctlfile1" ) {
         _ctlfile1._GoToROffset(setSeekPos);
         _ctlfile2.p_line = p_line;
      }else if (wid.p_name=="_ctlfile2") {
         _ctlfile2._GoToROffset(setSeekPos);
         _ctlfile1.p_line = p_line;
      }

      //_ctlfile1._BlastUndoInfo();
      //_ctlfile2._BlastUndoInfo();
      if ( LastActiveEditWindowWID ) {
         LastActiveEditWindowWID._set_focus();
      }
   }
}

/**
 * Get line the specified alignment is on 
 *  
 * @param wid Window ID that <b>markid</b> is in
 * @param markid Mark ID that represents this alignment
 * 
 * @return int 
 */
static void getAlignmentLineAndSeek(int wid, int markid, int &lineNum, long &seekPos)
{
   seekPos = 0;
   origWID := p_window_id;
   p_window_id = wid;
   _save_pos2(auto p);
   _begin_select(markid);
   seekPos = _QROffset();
   lineNum = p_line;
   _restore_pos2(p);
   p_window_id = origWID;
}

/** 
 * Get alignments from the mark ids. Even though we have stored 
 * DIFF_ALIGN structs in _GetDialogInfoHt("alignments"), we have 
 * to get these from the selections because the files may have 
 * been edited and the line positions might be out of date. 
 * 
 * @param alignmentList returns list of alignments with 
 *                      positiosn and markids set properly.
 */
static void getAlignments(DIFF_ALIGN (&alignmentList)[])
{
   DIFF_ALIGN alignments[];
   alignments = _GetDialogInfoHt("alignments");
   len := alignments._length();
   for (i:=0;i<len;++i) {
      getAlignmentLineAndSeek(_ctlfile1,alignments[i].markid1,auto lineNum1, auto seekPos1);
      getAlignmentLineAndSeek(_ctlfile2,alignments[i].markid2,auto lineNum2, auto seekPos2);
      alignmentList[i].pos1 = seekPos1;
      alignmentList[i].pos2 = seekPos2;
      alignmentList[i].markid1 = alignments[i].markid1;
      alignmentList[i].markid2 = alignments[i].markid2;
      alignmentList[i].lineNum1 = lineNum1;
      alignmentList[i].lineNum2 = lineNum2;
   }
}

/** 
 * Get the alignments, and then remove any that are colliding. 
 * This can happen when there are two marks and lines are 
 * deleted.  The marks move and can be cascaded onto the same 
 * line. 
 */
static void reduceAlignments()
{
   DIFF_ALIGN alignments[];

   // Have to call getAlignments here because if we use what's in 
   // _GetDialogInfoHt we may get outdated line positions because
   // the user may have edited the file.
   getAlignments(alignments);
   int reductionTable:[];


   // Algorithm: If the left line is not an index in the hash table, 
   // store the current index with left line number as the hash table
   // index.

   // If the left line is an index in the table, add the value stored (index)
   // to delList, then store the current entry in the hasntable. This way
   // when items collide, the most recently added one is kept.
   // 
   INTARRAY delList;
   len := alignments._length();
   for (i:=0;i<len;++i) {
      if ( reductionTable:[alignments[i].pos1]==null ) {
         reductionTable:[alignments[i].pos1] = i;
      } else {
         ARRAY_APPEND(delList,reductionTable:[alignments[i].pos1]);
         reductionTable:[alignments[i].pos1] = i;
      }
   }

   // Repeat the above algorithm, but us the right line number as the 
   // hash table index.
   reductionTable = null;
   for (i=0;i<len;++i) {
      if ( reductionTable:[alignments[i].pos2]==null ) {
         reductionTable:[alignments[i].pos2] = i;
      } else {
         ARRAY_APPEND(delList,reductionTable:[alignments[i].pos2]);
         reductionTable:[alignments[i].pos2] = i;
      }
   }
   
   // Finally, remove the collided items.  Go through delList backwards
   // (so the indexes do not shift) and free the selections and
   // delete the items from the array
   len = delList._length();
   for (i=len-1;i>=0;--i) {
      _free_selection(alignments[delList[i]].markid1);
      _free_selection(alignments[delList[i]].markid2);
      alignments._deleteel(delList[i]);
   }
   elimnateCrossovers(alignments);
   // Store the reduced table
   _SetDialogInfoHt("alignments",alignments);
}

static void elimnateCrossovers(DIFF_ALIGN (&alignments)[])
{
   // Alignments are added one at a time so we only have
   // to check the last one to see if it is criss-crossed.
   len := alignments._length();
   if ( len<2 ) return;
   lastAlignment := alignments[len-1];
   INTARRAY delList;
   for (i:=len-2;i>=0;--i) {
      if ( (alignments[i].pos1 > lastAlignment.pos1 && 
            alignments[i].pos2 < lastAlignment.pos2)
         ||(alignments[i].pos1 < lastAlignment.pos1 && 
            alignments[i].pos2 > lastAlignment.pos2)
            ) {
         ARRAY_APPEND(delList,i);
      }
   }
   len = delList._length();
   for (i=len-1;i>=0;--i) {
      alignments._deleteel(delList[i]);
   }
}

/** 
 * Set a mark on line <b>markpos</b> in window <b>wid</b> 
 * 
 * @param wid ID of window to set mark in
 * @param markid Mark ID returned from _alloc_selection
 * @param markpos line number to put mark on
 */
static void setAlignmentMark(int wid,int markid,long markpos)
{
   origWID := p_window_id;
   p_window_id = wid;
   save_pos(auto p);
   if ( isnumber(markpos) ) {
      _GoToROffset(markpos);
   } else {
      p_RLine = (int)markpos;
   }
   _select_line(markid);
   restore_pos(p);
   p_window_id = origWID;
}

/** 
 * Set an alignment in the diff form 
 * 
 * @param alignment DIFF_ALIGN structure with the pos1 and pos2
 *                  fields filled in.  This function will fill
 *                 in the markid fields.
 */
static void setAlignment(DIFF_ALIGN &alignment)
{
   alignment.markid1 = _alloc_selection('B');
   alignment.markid2 = _alloc_selection('B');
   setAlignmentMark(_ctlfile1,alignment.markid1,alignment.pos1);
   setAlignmentMark(_ctlfile2,alignment.markid2,alignment.pos2);
}

/**
 * Add <b>alignment</b> to the table of alignments stored on the 
 * dialog 
 * 
 * @param alignment DIFF_ALIGN structure with the pos1 and pos2 
 *                  fields filled in.  This function will call
 *                  <b>setAlignment</b> to fill in the markid
 *                  fields.
 */
static void addToGlobalAligns(DIFF_ALIGN &alignment)
{
   DIFF_ALIGN alignments[] = _GetDialogInfoHt("alignments");
   setAlignment(alignment);
   alignments :+= alignment;
   _SetDialogInfoHt("alignments",alignments);

   alignmentTypes2 := _GetDialogInfoHt("alignments");


   reduceAlignments();

   alignmentTypes2 = _GetDialogInfoHt("alignments");
}

static void diff_mou_extend_selection()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   wid._undo('s');
   otherwid._undo('s');
   wid.mou_extend_selection();
   AddUndoNothing(otherwid);
   otherwid.p_line=wid.p_line;
   otherwid.p_col=wid.p_col;
   otherwid.refresh('W');
   _DiffSetNeedRefresh(true);
   //otherwid.set_scroll_pos(otherwid.p_left_edge,wid.p_cursor_y);
   otherwid.set_scroll_pos(wid.p_left_edge,wid.p_cursor_y);
   //AddUndoNothing(otherwid);
}

static int MaybeSaveFile(bool InMem=false,_str controlNameSuffix="")
{
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   if (p_modify) {
      controlName := '1';
      if (p_name=='_ctlfile2save' || p_name=='_ctlfile2') {
         controlName = '2';
      }
      buf_name := "";

      // If we stored a buffer ID for this temp p_buf_name, this was an untitled
      // buffer and we want to prompt them to save it with the original buffer
      // ID
      buf_id := _GetDialogInfoHt(p_buf_name, _ctlfile1);
      if (buf_id!=null) {
         buf_name = "Untitled <"buf_id">";
         _SetDialogInfoHt("onlyOverlay",1,_ctlfile2);
      } else {
         buf_name = _DiffGetFilenameFromDialog(misc,controlName);
         if ( buf_name=="" ) {
            buf_name=_DiffGetDocumentName();
            if (buf_name=="") {
               buf_name=p_buf_name;
            }
         }
      }
      int result=prompt_for_save(nls("Do you wish to save changes to '%s'",buf_name));
      wid := 0;
      name := "";
      labelname := "";
      typeless preserve1='';
      typeless preserve2='';
      parse misc.PreserveInfo with preserve1 preserve2;
      switch (result) {
      case IDNO:
#if 0
         labelname=p_name'label';
         wid=p_active_form._find_control(labelname);
         if (wid) {
            if (InMem) {
               // 4:52:03 PM 1/19/2003
               // If the file is in memory we want to undo back to where we were.
               // The old method of checkin the dialog is no longer good enough
               // because we can't count on the name of the label
               if (p_undo_steps) {
                  while (_undo('C')!=NOTHING_TO_UNDO_RC);
                  //This is to be sure that we avoid those rare cases
                  //where modify is on and after all steps are undone
                  //if the user has specified the -preserve option(s).
                  //Also, this will bail'em out if they did not set undo
                  //high enough
                  if (p_window_id==_ctlfile1 && preserve1) {
                     p_modify=false;
                  }
                  if (p_window_id==_ctlfile2 && preserve2) {
                     p_modify=false;
                  }
               }
               clear_message();
            }
         }
#endif
         if (!DialogIsDiff()) {
            return(2);
         }else{
            return(0);
         }
      case IDCANCEL:
         return(COMMAND_CANCELLED_RC);
      case IDYES:
         preserve1=strip(preserve1);
         if (preserve1=='') {
            preserve1=0;
         }
         preserve2=strip(preserve2);
         if (preserve2=='') {
            preserve2=0;
         }
         if (p_window_id==_ctlfile1 && preserve1) {
            return(0);
         }
         if (p_window_id==_ctlfile2 && preserve2) {
            return(0);
         }
         name=substr(p_name,1,9);
         wid=p_active_form._find_control(name'save');
         if (wid) {
            typeless status=wid.call_event(wid,LBUTTON_UP);
            if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
               return(status);
            }else{
               return(1);
            }
         }
         return(1);
      }
   }
   return(0);
}

/**
 * 
 * Gets filename of buffer <B>bufid</B>
 * 
 * @param int bufid buffer id to get filename of
 * 
 * @return _str filename of buffer <B>bufid</B>
 */
_str GetFilenameFromBufId(int bufid)
{
   orig_view_id := p_window_id;
   p_window_id=VSWID_HIDDEN;
   _safe_hidden_window();
   int origbid=p_buf_id;
   int status=load_files('+bi 'bufid);
   if (status) {
      load_files('+bi 'origbid);
      p_window_id=orig_view_id;
      return('');
   }
   _str filename=p_buf_name;
   load_files('+bi 'origbid);
   p_window_id=orig_view_id;
   return(filename);
}

static int closeButton()
{
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   _str bufInfo1=_GetDialogInfo(DIFFEDIT_CONST_BUFFER_INFO1,_ctlfile1);
   _str bufInfo2=_GetDialogInfo(DIFFEDIT_CONST_BUFFER_INFO2,_ctlfile1);
   bufid1 := file1inmem := file1readonly := bufid2 := file2inmem := file2readonly := "";

   if ( bufInfo1==null ) {
      return(0);
   }
   parse bufInfo1 with bufid1 file1inmem file1readonly;
   if ( bufInfo2==null ) {
      return(0);
   }
   parse bufInfo2 with bufid2 file2inmem file2readonly;

   typeless status=0;
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      status=_ctlfile1.MaybeSaveFile((int)file1inmem!=0);
      if (status) {
         return(status);
      }
   }
   SavedFile2 := 0;
   status=_ctlfile2.MaybeSaveFile((int)file2inmem!=0);
   if (!status) {
      SavedFile2=1;
   }else{
      if (status==2) {
         SavedFile2=2;
      }else if (status==1) {
         SavedFile2=1;
      }else return(status);
   }

   if (_GetDialogInfo(DIFFEDIT_CONST_HAS_MODIFY)) {
      if (_GetDialogInfo(DIFFEDIT_CONST_FILE1_MODIFY)) {
         _ctlfile1.p_modify=true;
      }

      if (_GetDialogInfo(DIFFEDIT_CONST_FILE2_MODIFY)) {
         _ctlfile2.p_modify=true;
      }
   }

   _str filename1=_ctlfile1.p_buf_name;
   _str filename2=_ctlfile2.p_buf_name;

   if (misc.buffer1.WholeFileBufId>-1) {
      filename1=GetFilenameFromBufId(misc.buffer1.WholeFileBufId);
   }
   if (misc.buffer2.WholeFileBufId>-1) {
      filename2=GetFilenameFromBufId(misc.buffer2.WholeFileBufId);
   }

   file1datemismatch := (misc.buffer1.fileDate!=_file_date(_ctlfile1.p_buf_name,'B'));
   file2datemismatch := (misc.buffer2.fileDate!=_file_date(_ctlfile2.p_buf_name,'B'));

#if 0 //23:38pm 10/7/2021
   if (misc.RefreshTagsOnClose &&
       (file1datemismatch || file2datemismatch) ) {
      _nocheck _control tree1;
      if (_iswindow_valid(misc.DiffParentWID) &&
          misc.DiffParentWID.p_name=='_difftree_output_form') {
         state := 0;
         misc.DiffParentWID.tree1._TreeGetInfo(misc.TagParentIndex1,state);
         if (state>0) {
            if (misc.buffer1.WholeFileBufId>-1) {
               bufid1=misc.buffer1.WholeFileBufId;
            }else{
               bufid1=_ctlfile1.p_buf_id;
            }
            if (misc.buffer2.WholeFileBufId>-1) {
               bufid2=misc.buffer2.WholeFileBufId;
            }else{
               bufid2=_ctlfile2.p_buf_id;
            }
            _ctlfile1._DiffRemoveImaginaryLines();
            _ctlfile2._DiffRemoveImaginaryLines();
            misc.DiffParentWID._DiffExpandTags2(bufid1,bufid2,misc.TagParentIndex1,misc.TagParentIndex2,'+bi','+bi');
         }
      }
   }
#endif
   if (SavedFile2) {
      p_active_form._delete_window(SavedFile2);
      return(SavedFile2);
   }

   p_active_form._delete_window(COMMAND_CANCELLED_RC);
   return(COMMAND_CANCELLED_RC);
}

int _ctlclose.lbutton_up()
{
   return closeButton();
}

int _DiffShowComment()
{
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   int wid=show('_showbuf_form');
   if (!wid) {
      return(0);
   }
   _nocheck _control list1;
   wid.p_caption='Comment';
   wid.list1._delete_line();
   wid.list1._insert_text(strip(misc.Comment,'B','"'));
   _modal_wait(wid);
   return(0);
}

int _ctlok.lbutton_up()
{
   typeless pfn=0;
   typeless status=0;
   typeless result=0;
   int vf=p_user._varformat();
   if (p_user!='' && (vf==VF_FUNPTR) ||
       (vf==VF_LSTR && substr(p_user,1,1))) {
      pfn=p_user;
      status=(*pfn)();
      return(status);
   }
   if (_ctlfile2.p_modify) {
      result=prompt_for_save(nls("Do you wish to save changes to '%s'?", _ctlfile2.p_buf_name));
      if (result==IDYES) {
         _project_disable_auto_build(true);
         _ctlfile2.p_AllowSave=true;
         _ctlfile2.save("+n");
         _project_disable_auto_build(false);
      }else if (result==IDCANCEL) {
         return(0);
      }
   }
   p_active_form._delete_window(0);
   return(0);
}

void _ctlundo.lbutton_up()
{
   if ( DialogIsDiff() || _DiffDialogIsSVCUpdate() ) {
      diff_undo_cursor();
   }
}
static void GetFileOrBuffer(_str &Label)
{
   //Need to trim off (File) or (Buffer) (maybe a modified indicator) from label
   lp := lastpos('(',p_caption);
   if (!lp) {//Filename not really there yet
      Label='';
      return;
   }
   str := substr(p_caption,lp);
   p_caption=substr(p_caption,1,lp-1);
   Label=str;
}

static void DiffShrinkFilename(_str filename, int width)
{
   //Need to trim off (File) or (Buffer) (maybe a modified indicator) from label
   lp := lastpos('(',p_caption);
   if (!lp) {//Filename not really there yet
      return;
   }
   str := "";
   GetFileOrBuffer(str);
   p_caption=_ShrinkFilename(filename,width-_text_width(str)):+str;
}

_command void cmd_message_box(_str msg="") name_info(','VSARG2_REQUIRES_PRO_OR_STANDARD_EDITION)
{
   _message_box(nls("%s",msg));
}

int _OnUpdate_diff_toggle_intraline_color(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid) return MF_GRAYED;
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   if (misc.IntraLineIsOff==1) {
      return(MF_ENABLED);
   }else if (misc.IntraLineIsOff==0) {
      return(MF_ENABLED|MF_CHECKED);
   }
   return(MF_ENABLED);
}

static void diff_toggle_intraline_color()
{
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   if (misc.IntraLineIsOff==1) {
      misc.IntraLineIsOff=0;
      DiffIntraLineColoring(1,_ctlfile1.p_buf_id);
      DiffIntraLineColoring(1,_ctlfile2.p_buf_id);
   }else{
      misc.IntraLineIsOff=1;
      DiffIntraLineColoring(0,_ctlfile1.p_buf_id);
      DiffIntraLineColoring(0,_ctlfile2.p_buf_id);
   }
   _DiffSetDiffShowingInfo(misc,_ctlfile1);
   _ctlfile1.refresh('W');
   _ctlfile2.refresh('W');
}

static int GetLineStatus(int leftWID, int rightWID)
{
   int flag1=leftWID._lineflags();
   int flag2=rightWID._lineflags();
   if ( (!(flag1&MODIFY_LF) && !(flag1&INSERTED_LINE_LF)) &&
        (!(flag2&MODIFY_LF) && !(flag2&INSERTED_LINE_LF))) {
      return(MATCHING_LINE);
   }
   // Have to check del/ins first.  A line could be inserted, and then modified
   // This could cause us to delete a bigger block than the user would figure.
   if (flag1&NOSAVE_LF) {
      return(DELETED_LINE);
   }
   if (flag2&NOSAVE_LF) {
      return(INSERTED_LINE);
   }
   if ( (flag1&MODIFY_LF) || (flag2&MODIFY_LF) ) {
      return(CHANGED_LINE);
   }

   if (flag1&(NOSAVE_LF|INSERTED_LINE_LF) &&
       flag2&(NOSAVE_LF|INSERTED_LINE_LF)) {
      //12:05pm 6/11/1999
      //Funny merge case with soft collision
      return(INSERTED_LINE);
   }

   //message('flag1='flag1' flag2='flag2' _ctlfile1.p_line='_ctlfile1.p_line' _ctlfile2.p_line='_ctlfile2.p_line);
   //_message_box(nls("How did I get here"));
   return(0);
}
static int GetLineSkipFlag(int leftWID)
{
   int flag1=leftWID._lineflags();
   if (flag1&NOSAVE_LF) {
      return(NOSAVE_LF);
   }
   if (flag1&INSERTED_LINE_LF) {
      return(INSERTED_LINE_LF);
   }

   if (flag1&MODIFY_LF) {
      return(MODIFY_LF);
   }
   return(0);
}

int def_diff_next_hack=0;

static void diff_end_line()
{
   wid := 0;
   otherwid := p_window_id.GetOtherWid(wid);
   wid._undo('S');
   otherwid._undo('S');
   if (!(otherwid._lineflags()&NOSAVE_LF)) {
      wid.end_line();
      otherwid.end_line();
   }else{
      diff_maybe_deselect_command(end_line);
   }
}

static int FlagTable[]={
   INSERTED_LINE|CHANGED_LINE|DELETED_LINE,//Matching line
   CHANGED_LINE|DELETED_LINE,
   INSERTED_LINE|DELETED_LINE,
   0,//These are in hex, so there isn't a 3
   INSERTED_LINE|CHANGED_LINE
};

static int NoChangeFlagTable[]={
   INSERTED_LINE|DELETED_LINE,//Matching line
   DELETED_LINE,
   INSERTED_LINE|DELETED_LINE,
   0,//These are in hex, so there isn't a 3
   INSERTED_LINE
};

/**
 * Moves to the next (or previous) difference in two windows by looking at lineflags
 *
 * @param leftWID   Window id of left editor control
 * @param rightWID  Window id of left editor control
 * @param direction '' (default) to move forward(down)
 *                  '-' to move backward(up)
 *
 * @return
 */
int _DiffNextDifference(int leftWID, int rightWID,_str direction='',_str nomsgs='',
                        bool closeMessage=true)
{
   wid := p_window_id;
   wid=leftWID;
   rightWID.p_line=leftWID.p_line;//Just in case

   leftWID.p_col=1;rightWID.p_col=1;
   leftWID._refresh_scroll();
   rightWID._refresh_scroll();

   int line1flag=leftWID._lineflags();
   int line2flag=rightWID._lineflags();

   typeless list='';
   int skip_flag=GetLineSkipFlag(leftWID);
   int or_match_flags=0;
   if (skip_flag==MODIFY_LF) {
      or_match_flags=INSERTED_LINE_LF|NOSAVE_LF;
   } else if (skip_flag==INSERTED_LINE_LF) {
      or_match_flags=NOSAVE_LF;
   }
   found := 0;
   typeless p,p2;
   leftWID.save_pos(p);
   rightWID.save_pos(p2);

   typeless cur=0;
   typeless difftype=0;
   if (direction=='') {
      done:=false;
      if (skip_flag) {
         //say('h1 ln='p_line' col='p_col);
         line1:=leftWID.p_line;
         status:=leftWID._FindLineFlags(or_match_flags,skip_flag,1,false);
         //say('h2 ln='p_line' col='p_col' status='status);
         if (status) {
            done=true;
         } else {
            rightWID.down(leftWID.p_line-line1);
         }
         /*for (;;) {
            if (leftWID.down()||rightWID.down()) {
               done=true;
               break;
            }
            cur=leftWID._lineflags();
            if (!(cur& skip_flag) || (cur & or_match_flags)) {
               break;
            }
         } */
      } else {
         //cur=leftWID._lineflags();
      }
      if (!done) {
         change_flags:=MODIFY_LF|INSERTED_LINE_LF|NOSAVE_LF;
         //say('h3 ln='p_line' col='p_col);
         line1:=leftWID.p_line;
         status:=leftWID._FindLineFlags(change_flags,0,1,true);
         //say('h4 ln='p_line' col='p_col' status='status);
         if (!status) {
            found=1;
            rightWID.down(leftWID.p_line-line1);
         }
         /*for (;;) {
            if (cur & change_flags) {
               found=1;
               break;
            }
            if (leftWID.down()||rightWID.down()) {
               break;
            }
            cur=leftWID._lineflags();
         } */

      }
   } else {
      done:=false;
      if (skip_flag) {
         line1:=leftWID.p_line;
         status:=leftWID._FindLineFlags(or_match_flags,skip_flag,-1,false);
         if (status) {
            done=true;
         } else {
            rightWID.up(line1-leftWID.p_line);
         }
         /*for (;;) {
            leftWID.up();rightWID.up();
            if (leftWID.p_line==0) {
               leftWID.down();rightWID.down();
               done=true;
               break;
            }
            cur=leftWID._lineflags();
            if (!(cur& skip_flag) || (cur & or_match_flags)) {
               break;
            }
         } */
      } else {
         //cur=leftWID._lineflags();
      }
      if (!done) {
         change_flags:=MODIFY_LF|INSERTED_LINE_LF|NOSAVE_LF;
         //say('h3 ln='p_line' col='p_col);
         line1:=leftWID.p_line;
         status:=leftWID._FindLineFlags(change_flags,0,-1,true);
         //say('h4 ln='p_line' col='p_col' status='status);
         if (!status) {
            found=1;
            rightWID.up(line1-leftWID.p_line);
         }
#if 0
         for (;;) {
            if (cur & change_flags) {
               found=1;
               break;
            }
            leftWID.up();rightWID.up();
            if (leftWID.p_line==0) {
               leftWID.down();rightWID.down();
               done=true;
               break;
            }
            cur=leftWID._lineflags();
         }
#endif
         if (found) {
            // Now find the start of this block
            skip_flag=GetLineSkipFlag(leftWID);
            or_match_flags=0;
            if (skip_flag==MODIFY_LF) {
               or_match_flags=INSERTED_LINE_LF|NOSAVE_LF;
            } else if (skip_flag==INSERTED_LINE_LF) {
               or_match_flags=NOSAVE_LF;
            }
            line1=leftWID.p_line;
            status=leftWID._FindLineFlags(or_match_flags,skip_flag,-1,false);
            if (!status) {
               leftWID.down();
               rightWID.up(line1-leftWID.p_line);
            }
#if 0
            for (;;) {
               leftWID.up();rightWID.up();
               if (leftWID.p_line==0) {
                  leftWID.down();rightWID.down();
                  done=true;
                  break;
               }
               cur=leftWID._lineflags();
               if (!(cur& skip_flag) || (cur & or_match_flags)) {
                  leftWID.down();rightWID.down();
                  break;
               }
            }
#endif
         }
      }
   }
   if (!found) {
      leftWID.restore_pos(p);
      rightWID.restore_pos(p2);
      if (leftWID.p_parent && leftWID.p_parent.p_visible) {//Form may not be visible
         refresh();
         if (nomsgs!='No Messages') {
            if ( _DiffDialogIsSVCUpdate() && _GetDialogInfoHt("promptForNextFile",_ctlfile1)==1 ) {
               autoNextFile := def_svc_update_flags&SVC_UPDATE_AUTO_JUMP;
               if ( autoNextFile ) {
                  if (def_diff_edit_flags&DIFFEDIT_AUTO_JUMP) {
                     _nocheck _control ctlnext_mismatch;
                     if ( direction=='-' ) {
                        status := _ctlcopy_right.call_event(_ctlcopy_right, LBUTTON_UP);
                        if ( !status ) {
                           (*DiffCommands:["bottom-of-buffer"].typelessCommand[0])(DiffCommands:["bottom-of-buffer"].typelessCommand[1]);
                           lineflags := _ctlfile1._lineflags();
                           if ( !(lineflags&VSLF_MODIFY) && !(lineflags&VSLF_INSERTED_LINE) &&  !(lineflags&VSLF_NOSAVE) ) {
                              _ctlprev_difference.call_event(_ctlprev_difference, LBUTTON_UP);
                           }
                        }
                     } else {
                        _ctlcopy_right_line.call_event(_ctlcopy_right_line,LBUTTON_UP);
                     }
                  }
                  _DiffSetNeedRefresh(true);
                  return 0;
               } else {
                  DiffMessageBox(get_message(VSDIFF_NO_MORE_DIFFERENCES_RC));
               }
            } else {
               DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
               if (misc.AutoClose && direction!='-') {
                  if (_find_control('_ctlclose')) {
                     _ctlclose.call_event(_ctlclose,LBUTTON_UP);
                  }
                  return(-1);
               }else{
                  if ( closeMessage ) {
                     if ( DiffMessageBox(get_message(VSDIFF_NO_MORE_DIFFERENCES_CLOSE_RC),MB_YESNO,IDNO) == IDYES ) {
                        if (_find_control('_ctlclose')) {
                           _ctlclose.call_event(_ctlclose,LBUTTON_UP);
                        }
                        return(-1);
                     }
                  } else {
                     DiffMessageBox(get_message(VSDIFF_NO_MORE_DIFFERENCES_RC));
                  }
               }
            }
         }
      }
      return(1);
   }

   leftWID.center_line();
   rightWID.center_line();
   p_window_id=wid;

   line1 := "";
   line2 := "";
    if ( leftWID._line_length()<=def_diff_max_intraline_len*1024 &&
         rightWID._line_length()<=def_diff_max_intraline_len*1024 ) {
      if (!(leftWID._lineflags()&NOSAVE_LF) && !(rightWID._lineflags()&NOSAVE_LF)) {
         leftWID.get_line_raw(line1);
         rightWID.get_line_raw(line2);
         i := 1;
         while ( (substr(line1,i,1) == substr(line2,i,1) ) &&
                 i<=length(line1) && i<=length(line2)) ++i;
         leftWID.p_col=rightWID.p_col=text_col(line1,i,'I');
      }else{
         leftWID._begin_line();
         rightWID._begin_line();
      }
   }

   leftWID.p_scroll_left_edge=rightWID.p_scroll_left_edge=-1;
   return(0);
}

static int diff_next_difference(_str direction="",_str noMessagesMessage="")
{
   int status=_DiffNextDifference(_ctlfile1,_ctlfile2,direction,noMessagesMessage);
   return( status );
}

/**
 * Make our own version of save_pos that only uses real lines. 
 * Also, we get the information from <B>getFirstLines</B> and 
 * adjust the first line if we're being called from 
 * diff_close_and_edit.  We have to do it this way.  We cannot 
 * use _save_pos2 because the buffer is likely gone and the 
 * selection would be gone with it. Must be called as a method 
 * on one of the diff editor controls 
 * @param p blob variable with position info
 */
static void diff_save_pos(typeless &p)
{
   if (p_HasBuffer) {
      // This could be from a function or line range.
      // Have to get this information up front because it
      // is attached to the dialog, which will be closed when
      // We have to make this adjustment
      getFirstLines(auto firstLineNum1,auto firstLineNum2);
      firstLineNum := 0;
      if ( p_window_id==_ctlfile1 ) {
         firstLineNum = firstLineNum1;
      } else {
         firstLineNum = firstLineNum2;
      }
      if ( firstLineNum>0 ) --firstLineNum;
      /*
         WARNING: DO NOT APPEND ANYTHING AFTER THE POINT() FUNCTION CALL.  The point() function
         sometimes returns two values and not one.
      */
      p='r'p_RLine+firstLineNum" "p_col " "p_hex_nibble" "p_cursor_y " "_WinGetLeftEdge(0,false)' 'p_LastModified' 'point();
      return;
   }
   _lbsave_pos(p);
}

/**
 * Include for completeness.  If save_pos and restore_pos 
 * change, this will give us a place to do our work. 
 *  
 * @param p blob variable with position info
 */
static void diff_restore_pos(typeless p)
{
   restore_pos(p);
}

static void diff_close_and_edit()
{
   bufName := "";
   DIFF_SHOWING_INFO misc=_DiffGetDiffShowingInfo();
   editingFile1 := false;
   editorWID := 0;
   if ( p_window_id == _ctlfile1) {
      bufName = _DiffGetFilenameFromDialog(misc,'1');
      editingFile1 = true;
      editorWID = _ctlfile1;
   } else if ( p_window_id == _ctlfile2 ) {
      if ( _ctlfile2_readonly.p_value ) {
         return;
      }
      editorWID = _ctlfile2;
      bufName = _DiffGetFilenameFromDialog(misc,'2');
   }

   editorWID.diff_save_pos(auto p);
   diff_close_form();
   edit(_maybe_quote_filename(bufName));
   restore_pos(p);
   center_line();
}

static int diff_prev_difference()
{
   return(diff_next_difference("-"));
}

_command void diff_next_diff() name_info(','VSARG2_REQUIRES_PRO_OR_STANDARD_EDITION)
{
   // This is just a stub so that diff_next_difference will get called
}

_command void diff_prev_diff() name_info(','VSARG2_REQUIRES_PRO_OR_STANDARD_EDITION)
{
   // This is just a stub so that diff_prev_difference will get called
}

static int NoSaveLine(int LineNumber)
{
   OrigLineNum := p_line;
   p_line=LineNumber;
   line := "";
   get_line(line);
   //rv=line=='Imaginary Buffer Line';
   int rv=_lineflags()&NOSAVE_LF;
   p_line=OrigLineNum;
   return(rv);
}

void diff_delete_block(_str NoMessageStr='')
{
   diff_copy_block(NoMessageStr, true, true/*doDeleteBlock*/);
}

static void diff_right_side_of_window()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   typeless old_scroll=_scroll_style();
   _scroll_style('S 0');
   orig_left_edge := p_left_edge;
   p_cursor_x=p_client_width-1;
   while (p_left_edge!=orig_left_edge) {
      --p_col;
      set_scroll_pos(orig_left_edge,p_cursor_y);
   }
   _scroll_style(old_scroll);
   otherwid.p_col=p_col;
}

static void diff_left_side_of_window()
{
   wid := 0;
   otherwid := GetOtherWid(wid);
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   p_cursor_x=0;
   otherwid.p_col=p_col;
}

int diff_copy_block(_str NoMessageStr='',
                    bool ResetLineFlags=true,
                    bool doDeleteBlock=false)
{
   NoMessages := (NoMessageStr=='No Messages');
   if (!NoMessages) {
      _ctlfile1._undo('S');
      _ctlfile2._undo('S');
   }
   wid := 0;
   otherwid := GetOtherWid(wid);
   delete_block := (doDeleteBlock && (wid._lineflags()&NOSAVE_LF));
   typeless orig=GetLineStatus(_ctlfile1, _ctlfile2);
   while ((_lineflags()&NOSAVE_LF) && !doDeleteBlock) {
      if (!NoMessages) {
         DiffMessageBox('Cannot copy imaginary block');
      }else if (NoMessages) {
         if (diff_next_difference('',NoMessageStr)) return(1);
      }
      return(0);
   }
   if (orig==MATCHING_LINE) {
      if (!NoMessages) {
         DiffMessageBox('Block already matches');
      }
      return(1);
   }
   typeless status=0;
   while (GetLineStatus(_ctlfile1, _ctlfile2)==orig) {
      status=wid.up() || otherwid.up();
      if (status) break;
   }
   wid.down();otherwid.down();
   topln := wid.p_line;
   while (GetLineStatus(_ctlfile1, _ctlfile2)==orig) {
      status=wid.down() || otherwid.down();
      if (status) break;
   }
   if (!status) {
      wid.up();otherwid.up();
   }
   bottomln := p_line;
   wid.p_line=topln-1;otherwid.p_line=wid.p_line;
   count := 0;
   int numLines = bottomln-(topln-1);

   if (status==0) {
      removeMarginButtonsFromLine(topln);
   }

   hadImaginaryLine := false;
//   _CallbackBufSuspendAll(_ctlfile1.p_buf_id,1);
//   _CallbackBufSuspendAll(_ctlfile2.p_buf_id,1);
   wasModified := wid.p_modify;
   wasOtherModified := otherwid.p_modify;
   _UndoPushModify(wid);
   for (;;) {
      status=wid.down()||otherwid.down();
      if (status) break;
      if (delete_block) {
         if (count>bottomln-topln) break;
      }else{
         if (status||wid.p_line>bottomln) break;
      }
      if (delete_block) {
         wid.DeleteLineMaybeNoModify();wid.up();
         otherwid.DeleteLineMaybeNoModify();otherwid.up();
         ++count;
      }else{
         line := "";
         wid.get_line(line);
         hadImaginaryLine = ((wid._lineflags()&NOSAVE_LF)!=0) || ((otherwid._lineflags()&NOSAVE_LF)!=0);
         otherwid._lineflags(0,NOSAVE_LF);//Get rid of any nosave flags
         otherwid.safe_replace_line(line);
         if (ResetLineFlags) {
            wid.set_line_normal();
         }
         otherwid.set_line_normal();
      }
      if ( hadImaginaryLine ) {
         DiffUpdateColorInfo(_ctlfile1,_ctlfile1.p_line-1,_ctlfile2,_ctlfile2.p_line-1,0,1,false,false);
      } else {
         // Have to do this manually because we suspended callback so that we do 
         // not add scroll markers
         DiffUpdateColorInfo(_ctlfile1,_ctlfile1.p_line,_ctlfile2,_ctlfile2.p_line,0,1,false,false);
      }
   }
   AddUndoNothing(otherwid);
   _UndoPopModify(wid);
//   _CallbackBufSuspendAll(_ctlfile1.p_buf_id,0);
//   _CallbackBufSuspendAll(_ctlfile2.p_buf_id,0);

   if (def_diff_edit_flags&DIFFEDIT_AUTO_JUMP) {
      int flags1=wid._lineflags();
      int flags2=otherwid._lineflags();
      if ((flags1&MODIFY_LF || flags1&INSERTED_LINE_LF || flags1&NOSAVE_LF) ||
          (flags2&MODIFY_LF || flags2&INSERTED_LINE_LF || flags2&NOSAVE_LF)) {
         //We are on the next error already
         return(0);
      }
      status=diff_next_difference('',NoMessageStr);
      return(status);
   }
   return(0);
}
int diff_copy_selection_to_other_window(_str NoMessageStr='',
                                        bool ResetLineFlags=true,
                                        bool doDeleteBlock=false)
{
   NoMessages := (NoMessageStr=='No Messages');
   if (!NoMessages) {
      _ctlfile1._undo('S');
      _ctlfile2._undo('S');
   }
   wid := 0;
   otherwid := GetOtherWid(wid);
   delete_block := (doDeleteBlock && (wid._lineflags()&NOSAVE_LF));
   typeless orig=GetLineStatus(_ctlfile1, _ctlfile2);
   while ((_lineflags()&NOSAVE_LF) && !doDeleteBlock) {
      if (!NoMessages) {
         DiffMessageBox('Cannot copy imaginary block');
      }else if (NoMessages) {
         if (diff_next_difference('',NoMessageStr)) return(1);
      }
      return(0);
   }
   if (orig==MATCHING_LINE) {
      if (!NoMessages) {
         DiffMessageBox('Block already matches');
      }
      return(1);
   }
   save_pos(auto p);
   wid._begin_select();
   topln := wid.p_line;
   wid._end_select();
   typeless status=0;
   bottomln := p_line;
   count := 0;
   int numLines = bottomln-topln;

   if (status==0) {
      removeMarginButtonsFromLine(topln);
   }

   hadImaginaryLine := false;
   wasModified := wid.p_modify;
   wasOtherModified := otherwid.p_modify;
   _UndoPushModify(otherwid);
   otherwid.p_line = wid.p_line = topln-1;
   for (;;) {
      status=wid.down()||otherwid.down();
      if (status) break;
      if (delete_block) {
         if (count>bottomln-topln) break;
      }else{
         if (status||wid.p_line>bottomln) break;
      }
      if (delete_block) {
         wid.DeleteLineMaybeNoModify();wid.up();
         otherwid.DeleteLineMaybeNoModify();otherwid.up();
         ++count;
      }else{
         line := "";
         wid.get_line(line);
         hadImaginaryLine = ((wid._lineflags()&NOSAVE_LF)!=0) || ((otherwid._lineflags()&NOSAVE_LF)!=0);
         otherwid._lineflags(0,NOSAVE_LF);//Get rid of any nosave flags
         otherwid.safe_replace_line(line);
         if (ResetLineFlags) {
            wid.set_line_normal();
         }
         otherwid.set_line_normal();
      }
      if ( hadImaginaryLine ) {
         DiffUpdateColorInfo(_ctlfile1,_ctlfile1.p_line-1,_ctlfile2,_ctlfile2.p_line-1,0,1,false,false);
      } else {
         // Have to do this manually because we suspended callback so that we do 
         // not add scroll markers
         DiffUpdateColorInfo(_ctlfile1,_ctlfile1.p_line,_ctlfile2,_ctlfile2.p_line,0,1,false,false);
      }
   }
   _UndoPopModify(otherwid);

   _DiffSetNeedRefresh(true);
#if 0 //11:08am 9/6/2019
   if (def_diff_edit_flags&DIFFEDIT_AUTO_JUMP) {
      int flags1=wid._lineflags();
      int flags2=otherwid._lineflags();
      if ((flags1&MODIFY_LF || flags1&INSERTED_LINE_LF || flags1&NOSAVE_LF) ||
          (flags2&MODIFY_LF || flags2&INSERTED_LINE_LF || flags2&NOSAVE_LF)) {
         //We are on the next error already
         return(0);
      }
      status=diff_next_difference('',NoMessageStr);
      return(status);
   }
#endif
   return(0);
}

static int diff_find_next()
{
   typeless status=find_next();
   if (/*LastActiveEditWindowWID*/_get_focus()==_ctlfile1) {
      _ctlfile2.p_col = _ctlfile1.p_col;
      _ctlfile2.p_line=_ctlfile1.p_line;
      _ctlfile2.set_scroll_pos(_ctlfile1.p_left_edge,_ctlfile1.p_cursor_y);
   }else if (/*LastActiveEditWindowWID*/_get_focus()==_ctlfile2) {
      _ctlfile1.p_col = _ctlfile2.p_col;
      _ctlfile1.p_line=_ctlfile2.p_line;
      _ctlfile1.set_scroll_pos(_ctlfile2.p_left_edge,_ctlfile2.p_cursor_y);
   }
   if (status) {
      clear_message();
      _message_box(nls("String not found"));
   }
   //ReturnFocusToEditWindow();
   return(status);
}

static int diff_find_prev()
{
   typeless status=find_prev();
   if (/*LastActiveEditWindowWID*/_get_focus()==_ctlfile1) {
      _ctlfile2.p_col = _ctlfile1.p_col;
      _ctlfile2.p_line=_ctlfile1.p_line;
      _ctlfile2.set_scroll_pos(_ctlfile1.p_left_edge,_ctlfile1.p_cursor_y);
   }else if (/*LastActiveEditWindowWID*/_get_focus()==_ctlfile2) {
      _ctlfile1.p_col = _ctlfile2.p_col;
      _ctlfile1.p_line=_ctlfile2.p_line;
      _ctlfile1.set_scroll_pos(_ctlfile2.p_left_edge,_ctlfile2.p_cursor_y);
   }
   if (status) {
      clear_message();
      _message_box(nls("String not found"));
   }
   //ReturnFocusToEditWindow();
   return(status);
}

static void DeleteLineMaybeNoModify()
{
   old := p_modify;
   int imaginary=_lineflags()&NOSAVE_LF;
   _delete_line();
   if (imaginary) {
      p_modify=old;
   }
}

static void set_line_inserted()
{
   _lineflags(0,INSERTED_LINE_LF|MODIFY_LF);
   _lineflags(INSERTED_LINE_LF,INSERTED_LINE_LF);
}
static void set_line_normal()
{
   _lineflags(0,INSERTED_LINE_LF|MODIFY_LF);
}

static int matching_tileid_exists(int tileid)
{
   buf_name2 := "";
   int tile_id=p_tile_id;
   first_window_id := p_window_id;
   typeless w2_view_id='';
   wid2 := 0;
   for (;;) {
      _next_window('HF');
      if ( p_window_id==first_window_id ) break;
      if ( p_tile_id==tile_id && !(p_window_flags &HIDE_WINDOW_OVERLAP)) {
         if ( w2_view_id!='' ) {
            w2_view_id='error';
            break;
         }
         w2_view_id=p_window_id;
         wid2=p_window_id;
         buf_name2=p_buf_name;
      }
   }
   return(wid2);
}
static void safe_replace_line(_str line)
{
   int old_TruncateLength=p_TruncateLength;
   p_TruncateLength=0;
   replace_line(line);
   p_TruncateLength=old_TruncateLength;
}

static void diff_vi_restart_word()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := p_window_id;
   OtherWid := GetOtherWid(wid);
   wid.vi_restart_word();
   AddUndoNothing(OtherWid);
}

static void diff_vi_ptab()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := p_window_id;
   OtherWid := GetOtherWid(wid);
   wid.vi_ptab();
   AddUndoNothing(OtherWid);
}

static void diff_vi_pbacktab()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := p_window_id;
   OtherWid := GetOtherWid(wid);
   wid.vi_pbacktab();
   AddUndoNothing(OtherWid);
}

static void diff_vi_begin_next_line()
{
   _ctlfile1._undo('S');
   _ctlfile2._undo('S');
   wid := p_window_id;
   OtherWid := GetOtherWid(wid);
   wid.vi_begin_next_line();
   OtherWid.p_line=p_line;
   OtherWid.p_col=p_col;
}

/**
 * Indicate that the buffers associated with the current Diff window 
 * are being diffed. 
 * 
 * @param addOrRemove   'true' means these buffers are being diffed 
 *                      'false' indicates they are no longer being diffed
 * @param misc          diff miscellaneous information struct 
 */
void _DiffSetBuffersAreDiffed(bool addOrRemove, DIFF_SHOWING_INFO &misc=null)
{
   if (misc == null) {
      misc=_DiffGetDiffShowingInfo(_ctlfile1);
      if (misc == null || !VF_IS_STRUCT(misc)) {
         return;
      }
   }

   if (misc.buffer1.WholeFileBufId>-1) {
      _DiffSetBufferIsDiffed(misc.buffer1.WholeFileBufId, addOrRemove);
   }
   if (misc.buffer2.WholeFileBufId>-1) {
      _DiffSetBufferIsDiffed(misc.buffer2.WholeFileBufId, addOrRemove);
   }
}

void _DiffSetBufferIsDiffed(int buf_id, bool addOrRemove)
{
   // invalid buffer id?
   if (buf_id < 0) return;
   // already have an editor control with this buffer?
   if (_isEditorCtl(true) && buf_id == p_buf_id) {
      origCount := _GetBufferInfoHt(DIFFEDIT_CONST_BUFFER_IS_DIFFED:+p_buf_id);
      if (origCount ==  null) {
         // buffer was not being diffed before, initialize count to 1
         if (addOrRemove) {
            _SetBufferInfoHt(DIFFEDIT_CONST_BUFFER_IS_DIFFED:+p_buf_id, 1);
         }
      } else if (addOrRemove) {
         // increment count
         _SetBufferInfoHt(DIFFEDIT_CONST_BUFFER_IS_DIFFED:+p_buf_id, origCount+1);
      } else if (origCount > 1) {
         // decrement count
         _SetBufferInfoHt(DIFFEDIT_CONST_BUFFER_IS_DIFFED:+p_buf_id, origCount-1);
      } else {
         // clear counter entirely
         _SetBufferInfoHt(DIFFEDIT_CONST_BUFFER_IS_DIFFED:+p_buf_id, null);
      }
      return;
   }
   // otherwise open the buffer in a hidden window 
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   status := load_files('+bi 'buf_id);
   if (!status) {
      _DiffSetBufferIsDiffed(buf_id, addOrRemove);
   }
#if 0 //16:19pm 7/6/2021
   else{
      say('_DiffSetBufferIsDiffed status='status' could not load buf_id='buf_id);
   }
#endif
   p_window_id = origWID;
}


/**
 * Set the "Files match" item that we keep track of
 */
void _DiffSetFilesMatch(_str FilesMatchInfo)
{
   _SetDialogInfo(DIFFEDIT_CONST_FILES_MATCH,FilesMatchInfo,_ctlfile1);
}
/**
 * Get the "Files match" item that we keep track of
 */
_str _DiffGetFilesMatch()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_FILES_MATCH,_ctlfile1));
}

/**
 * Set the dialog titles item that we keep track of
 */
void _DiffSetDialogTitles(_str File1Title,_str File2Title)
{
   _SetDialogInfo(DIFFEDIT_CONST_FILE_TITLES,_maybe_quote_filename(File1Title)' '_maybe_quote_filename(File2Title),_ctlfile1);
}
/**
 * Get the dialog titles item that we keep track of
 */
_str _DiffGetDialogTitles()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_FILE_TITLES,_ctlfile1));
}

/**
 * Set the previous vertical scroll position
 */
void _DiffVscrollSetLast(typeless LastVScrollPos)
{
   _SetDialogInfo(DIFFEDIT_CONST_LAST_VSCROLL,LastVScrollPos,_ctlfile1);
}
/**
 * Get the previous vertical scroll position
 */
int _DiffVscrollGetLast()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_LAST_VSCROLL,_ctlfile1));
}

/**
 * Set the previous horizontal scroll position
 */
void _DiffHscrollSetLast(typeless LastHScrollPos)
{
   _SetDialogInfo(DIFFEDIT_CONST_LAST_HSCROLL,LastHScrollPos,_ctlfile1);
}
/**
 * Get the previous horizontal scroll position
 */
int _DiffHscrollGetLast()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_LAST_HSCROLL,_ctlfile1));
}

/**
 * Set the refresh flag
 */
void _DiffSetNeedRefresh(bool NeedRefresh)
{
   _SetDialogInfo(DIFFEDIT_CONST_NEED_REFRESH,NeedRefresh,_ctlfile1);
}
/**
 * Get the refresh flag
 */
bool _DiffGetNeedRefresh()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_NEED_REFRESH,_ctlfile1));
}

void _DiffSetDiffShowingInfo(DIFF_SHOWING_INFO &misc,int infoWID = 0)
{
   if ( infoWID==0 ) {
      infoWID = _ctlfile1;
   }
   DIFF_SHOWING_INFO allInfo:[];
   allInfo = _GetDialogInfoHt(DIFFEDIT_CONST_MISC_INFO,infoWID);
   allInfo:[infoWID.p_buf_id] = misc;
   _SetDialogInfoHt(DIFFEDIT_CONST_MISC_INFO,allInfo,infoWID);
}

DIFF_SHOWING_INFO _DiffGetDiffShowingInfo(int infoWID = 0)
{
   if ( infoWID==0 ) {
      infoWID = _ctlfile1;
   }
   DIFF_SHOWING_INFO allInfo:[];
   allInfo = _GetDialogInfoHt(DIFFEDIT_CONST_MISC_INFO,infoWID);
   return allInfo:[infoWID.p_buf_id];
}

void _DiffGetAllMiscInfo(DIFF_SHOWING_INFO (&info):[],int infoWID = 0)
{
   if ( infoWID==0 ) {
      infoWID = _ctlfile1;
   }
   info = _GetDialogInfoHt(DIFFEDIT_CONST_MISC_INFO,infoWID);
}

INTARRAY _DiffGetListOfOriginalBufIDs(int infoWID = 0)
{
   if ( infoWID==0 ) {
      infoWID = _ctlfile1;
   }
   copyBufIDToOriginalBufIDMap := _GetDialogInfoHt("copyBufIDToOriginalBufIDMap",infoWID);
   INTARRAY listOfMappedBuffers;
   foreach ( auto index => auto curBufID in copyBufIDToOriginalBufIDMap ) {
      listOfMappedBuffers :+= curBufID;
   }
   return listOfMappedBuffers;
}

void _DiffSetCopyBufIDToOriginaBufID(int copyBufID, int origBufID, int infoWID = 0)
{
   if ( infoWID==0 ) {
      infoWID = _ctlfile1;
   }
   copyBufIDToOriginalBufIDMap := _GetDialogInfoHt("copyBufIDToOriginalBufIDMap",infoWID);
   copyBufIDToOriginalBufIDMap:[copyBufID] = origBufID;
   _SetDialogInfoHt("copyBufIDToOriginalBufIDMap", copyBufIDToOriginalBufIDMap, infoWID);
}

int _DiffGetOrigBufIDMap(int copyBufID, int infoWID = 0)
{
   copyBufIDToOriginalBufIDMap := _GetDialogInfoHt("copyBufIDToOriginalBufIDMap",infoWID);
   return copyBufIDToOriginalBufIDMap:[copyBufID];
}

/**
 * Set flag to let us know that the File title labels are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
void _DiffSetFileLabelsMissing()
{
   _SetDialogInfo(DIFFEDIT_CONST_FILE_LABELS_MISSING,1,_ctlfile1);
}
/**
 * Set flag to let us know that the File title labels are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
bool _DiffGetFileLabelsMissing()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_FILE_LABELS_MISSING,_ctlfile1));
}

/**
 * Set flag to let us know that the line number labels are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
void _DiffSetLineNumLabelsMissing()
{
   _SetDialogInfo(DIFFEDIT_CONST_LINENUM_LABELS_MISSING,1,_ctlfile1);
}
/**
 * Get flag to let us know that the line number labels are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
bool _DiffGetLineNumLabelsMissing()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_LINENUM_LABELS_MISSING,_ctlfile1));
}

/**
 * Set the flag to let us know that the line number labels are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
void _DiffSetReadOnlyCBMissing()
{
   _SetDialogInfo(DIFFEDIT_CONST_READONLY_CB_MISSING,1,_ctlfile1);
}
/**
 * Get the flag to let us know that the line number labels are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
bool _DiffGetReadOnlyCBMissing()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_READONLY_CB_MISSING,_ctlfile1));
}

/**
 * Set the flag to let us know that the file 1 is readonly, even if the
 * checkboxes are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
void _DiffSetReadOnly(int value)
{
   id := 0;
   if ( p_name=='_ctlfile1' ) {
      id=DIFFEDIT_CONST_READONLY_SET1;
   }else if ( p_name=='_ctlfile2' ) {
      id=DIFFEDIT_CONST_READONLY_SET2;
   }
   _SetDialogInfo(id,value,_ctlfile1);
}
/**
 * Set the flag to let us know that the file 1 is readonly, even if the
 * checkboxes are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
bool _DiffGetReadOnly()
{
   id := 0;
   if ( p_name=='_ctlfile1' ) {
      id=DIFFEDIT_CONST_READONLY_SET1;
   }else if ( p_name=='_ctlfile2' ) {
      id=DIFFEDIT_CONST_READONLY_SET2;
   }
   return(_GetDialogInfo(id,_ctlfile1));
}

/**
 * Set the flag to let us know that the Next/Prev diff buttons are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
void _DiffSetNextDiffMissing()
{
   _SetDialogInfo(DIFFEDIT_CONST_LINE_NEXT_DIFF_MISSING,1,_ctlfile1);
}
/**
 * Get the flag to let us know that the Next/Prev diff buttons are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
bool _DiffGetNextDiffMissing()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_LINE_NEXT_DIFF_MISSING,_ctlfile1));
}

/**
 * Set the flag to let us know that the Close button is missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
void _DiffSetCloseMissing()
{
   _SetDialogInfo(DIFFEDIT_CONST_CLOSE_MISSING,1,_ctlfile1);
}
/**
 * Get the flag to let us know that the Close button is missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
bool _DiffGetCloseMissing()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_CLOSE_MISSING,_ctlfile1));
}

/**
 * Set the flag to let us know that the Copy buttons are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
void _DiffSetCopyMissing()
{
   _SetDialogInfo(DIFFEDIT_CONST_COPY_MISSING,1,_ctlfile1);
}
void _DiffSetCopyLeftMissing()
{
   _SetDialogInfo(DIFFEDIT_CONST_COPY_LEFT_MISSING,1,_ctlfile1);
}
/**
 * Get the flag to let us know that the Copy buttons are missing
 * Pieces of the dialog may be copied to other dialogs, and this may be missing
 */
bool _DiffCopyMissing()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_COPY_MISSING,_ctlfile1));
}
bool _DiffCopyLeftMissing()
{
   return(_GetDialogInfo(DIFFEDIT_CONST_COPY_LEFT_MISSING,_ctlfile1));
}

void _before_context_combo_select_diffedit(int comboBoxWID)
{
   if ( comboBoxWID.p_name=='ctlcontextCombo1' ||
        comboBoxWID.p_name=='ctlcontextCombo2' ) {
      _ctlfile1._undo('S');
      _ctlfile2._undo('S');
   }
}

void _after_context_combo_select_diffedit(int comboBoxWID)
{
   if ( comboBoxWID.p_name=='ctlcontextCombo1' ||
        comboBoxWID.p_name=='ctlcontextCombo2' ) {
      origWID := p_window_id;
      otherWID := 0;
      if ( p_window_id == ctlcontextCombo1 ) {
         p_window_id = _ctlfile2;
         otherWID = _ctlfile1;
      } else if ( p_window_id == ctlcontextCombo2 ) {
         p_window_id = _ctlfile1;
         otherWID = _ctlfile2;
      }
      p_line = otherWID.p_line;
      center_line();
      otherWID._set_focus();
      refresh();
      p_window_id = origWID;
   }
}
