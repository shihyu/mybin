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
#include "slick.sh"
#import "bind.e"
#import "files.e"
#import "main.e"
#import "options.e"
#import "stdcmds.e"
#import "setupext.e"
#import "search.e"
#endregion

  //typeless def_gui;
  //typeless def_keys;

  //typeless def_alt_menu;
  //typeless def_preplace;
  //typeless def_buflist;

  //typeless def_deselect_copy;
  //typeless def_deselect_paste;
  //typeless def_persistent_select;
  //typeless def_advanced_select;
  //typeless def_select_style;

  //typeless def_updown_col;
  //typeless def_hack_tabs;
  //typeless def_line_insert;

  //typeless def_next_word_style;
  //typeless def_top_bottom_style;
  //typeless def_linewrap;
  //typeless def_cursorwrap;
  //typeless def_jmp_on_tab;
  //typeless def_pull;

  // Operate on current word starting from cursor.
  //typeless def_from_cursor;
  //typeless def_word_delim;
  //typeless def_restore_cursor;
  //typeless def_modal_tab;
  //typeless def_one_file;
  //typeless def_leave_selected;
  //typeless def_click_past_end;
  //bool def_word_continue;

defmain()
{
   def_re_search_flags=VSSEARCHFLAG_PERLRE;
   _default_option('S',IGNORECASE_SEARCH|VSSEARCHFLAG_WRAP|PROMPT_WRAP_SEARCH);
   def_inclusive_block_sel=1;
   def_display_buffer_id=false;
  def_updown_screen_lines=true;
  def_switchbuf_cd=false;
  _SmartTabSetAll(2);
  _config_modify_flags(CFGMODIFY_DEFVAR);
  def_process_tab_output=true;
  def_click_past_end=1;
  def_gui=1;
  def_keys = 'ispf-keys';
  def_block_mode_fill_only_if_line_long_enough=false;

  def_alt_menu=1;
  def_cua_select_alt_shift_block=!_isMac();
  def_preplace=1;
  def_buflist=3;

  def_deselect_copy=true;
  def_deselect_paste=true;
  def_persistent_select='D';
  def_advanced_select='P';
  def_select_style = 'CN';
  def_scursor_style=0;

  def_updown_col=0;
  def_hack_tabs=false;
  def_line_insert = 'A';

  def_next_word_style = 'E';
  def_top_bottom_style = '1';
  def_linewrap = false;
  def_join_strips_spaces = true;
  def_cursorwrap= false;
  def_jmp_on_tab = true;
  def_pull = true;

  // Operate on current word starting from cursor.
  def_from_cursor = false;
  def_word_delim = '0';
  def_restore_cursor = true;
  def_modal_tab = 1;

  def_one_file='+w';
  _default_option(VSOPTION_TAB_TITLE,VSOPTION_TAB_TITLE_SHORT_NAME);
  _default_option(VSOPTION_SPLIT_WINDOW,VSOPTION_SPLIT_WINDOW_EVENLY);
  
  def_leave_selected=1;
  def_word_continue=false;

  _default_option(VSOPTION_LINE_NUMBERS_LEN,6);
  _default_option(VSOPTION_LCREADWRITE,6);
  _default_option(VSOPTION_LCREADONLY,1);
  _LCUpdateOptions();
  def_ispf_flags=0;

  //_default_option(VSOPTION_LCREADONLY,0);
  _default_option(VSOPTION_NEXTWINDOWSTYLE,0);

  _ModifyTabSetupAll(
     1,         // Fundamental indent with tabs setting
     0,         // Common indent with tabs setting
     '+4'       // Common tabs setting
     );
  _SoftWrapUpdateAll(false,true);
  _str updateTable:[];
  updateTable:[VSLANGPROPNAME_TABS]='';
  updateTable:[VSLANGPROPNAME_INDENT_WITH_TABS]='';
  updateTable:[VSLANGPROPNAME_SOFT_WRAP]='';
  updateTable:[VSLANGPROPNAME_SOFT_WRAP_ON_WORD]='';
  if(index_callable(find_index('_update_buffer_from_new_setting',PROC_TYPE))) _update_buffer_from_new_setting(updateTable);

   _scroll_style('H 2');
   _search_case('I');

   _default_option('n','');
   _default_option(VSOPTION_LCNOCOLON,1);
   def_brief_word=false;
   def_vcpp_word=false;
   def_subword_nav=false;
   def_vcpp_bookmark=false;
   // Completion e and edit lists binary files
   def_list_binary_files=true;
   _default_option(VSOPTION_MAC_USE_COMMAND_KEY_FOR_DIALOG_HOT_KEYS,1);
   _default_option(VSOPTION_MAC_ALT_KEY_BEHAVIOR,VSOPTION_MAC_ALT_KEY_WINDOWS_STYLE_BEHAVIOR);
   if (machine()=='MACOSX' || machine() == "MACOSX-M1") {
      _default_option(VSOPTION_USE_CLEAR_KEY_AS_NUMLOCK_KEY,1);
      _default_option(VSOPTION_INITIAL_CLEAR_KEY_NUMLOCK_STATE,1);
      _default_option(VSOPTION_CLEAR_KEY_NUMLOCK_STATE,1);
   }
   rc=0;
}
