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
#include "tagsdb.sh"
#include "color.sh"
#include "diff.sh"
#include "minihtml.sh"
#include "treeview.sh"
#import "box.e"
#import "c.e"
#import "cbrowser.e"
#import "cfg.e"
#import "clipbd.e"
#import "codehelp.e"
#import "codehelputil.e"
#import "commentformat.e"
#import "context.e"
#import "cutil.e"
#import "diff.e"
#import "dlgman.e"
#import "help.e"
#import "htmltool.e"
#import "listbox.e"
#import "listproc.e"
#import "main.e"
#import "markfilt.e"
#import "menu.e"
#import "mprompt.e"
#import "picture.e"
#import "pushtag.e"
#import "recmacro.e"
#import "reflow.e"
#import "sellist.e"
#import "setupext.e"
#import "slickc.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "tags.e"
#import "util.e"
#import "xmldoc.e"
#import "se/tags/TaggingGuard.e"
#endregion

//#define REMOVECODE 0
//#pragma option(autodeclvars,off)

/**
 * Returns the string representation of a specific subarray of the
 * {@code char} array argument.
 * <p>
 * The {@code offset} argument is the index of the first
 * character of the subarray. The {@code count} argument
 * specifies the length of the subarray. The contents of the subarray
 * are copied; subsequent modification of the character array does not
 * affect the newly created string.
 *
 * @param   data
 * @param   offset   the initial offset into the value of the
 * {@code String}.
 * @param   count    the length of the value of the {@code String}.
 * more text
 * @return  a newly allocated string representing the sequence of
 * characters contained in the subarray of the character array
 * argument.
 * @exception NullPointerException if {@code data} is
 *          {@code null}.
 * @exception IndexOutOfBoundsException if {@code offset} is
 * negative, or {@code count} is negative, or
 * <code>offset+count</code> is larger than
 * <code>data.length</code>.
 * @see     java.lang.StringBuffer#append(long)
 * @see     java.lang.StringBuffer#append(java.lang.Object)
 * @see     java.lang.StringBuffer#append(java.lang.String)
 * @since   JDK1.0
 * @author  Lee Boynton
 * @author  Arthur van Hoff
 * @version 1.112, 09/23/98
 */

static const JAVADOC_TAGS_FROM_SIG= "param,return,exception,throws";


static int _testdoc1(int data[], int offset, int count)
{
   return 0;
}

static bool in_cua_select;

static void jdcmd_maybe_deselect_command(typeless pfn);
static void jdcmd_rubout();
static void jdcmd_linewrap_rubout();
static void jdcmd_delete_char();
static void jdcmd_linewrap_delete_char();
static void jdcmd_cua_select();

static void jdcmd_cut_line();
static void jdcmd_join_line();
static void jdcmd_delete_line();
static void jdcmd_cut_end_line();
static void jdcmd_erase_end_line();

static typeless JavadocCommands:[]={
   "rubout"                    =>jdcmd_rubout,
   "linewrap-rubout"           =>jdcmd_linewrap_rubout,
   "delete-char"               =>jdcmd_delete_char,
   "vi-forward-delete-char"    =>jdcmd_delete_char,
   "linewrap-delete-char"      =>jdcmd_linewrap_delete_char,
   "brief-delete"              =>jdcmd_linewrap_delete_char,

   "cut-line"                  =>jdcmd_cut_line,
   "join-line"                 =>jdcmd_join_line,
   "cut"                       =>jdcmd_cut_line,
   "delete-line"               =>jdcmd_delete_line,
   "cut-end-line"              =>jdcmd_cut_end_line,
   "erase-end-line"            =>jdcmd_erase_end_line,

   "codehelp-complete"         =>codehelp_complete,
   "list-symbols"              =>list_symbols,
   "function-argument-help"    =>function_argument_help,
   "split-insert-line"         =>split_insert_line,
   "maybe-split-insert-line"   =>split_insert_line,
   "nosplit-insert-line"       =>split_insert_line,
   "nosplit-insert-line-above" =>split_insert_line,
   "paste"                     =>paste,
   "brief-paste"               =>paste,

   "undo"                      =>undo,
   "undo-cursor"               =>undo_cursor,
   "cua-select"                =>jdcmd_cua_select,
   "deselect"                  =>deselect,
   "copy-to-clipboard"         =>copy_to_clipboard,

   "bottom-of-buffer"          =>{jdcmd_maybe_deselect_command,bottom_of_buffer},

   "top-of-buffer"             =>{jdcmd_maybe_deselect_command,top_of_buffer},

   "page-up"                   =>{jdcmd_maybe_deselect_command,page_up},

   "vi-page-up"                =>{jdcmd_maybe_deselect_command,page_up},

   "page-down"                 =>{jdcmd_maybe_deselect_command,page_down},

   "vi-page-down"              =>{jdcmd_maybe_deselect_command,page_down},


   "cursor-left"               =>{jdcmd_maybe_deselect_command,cursor_left},
   "vi-cursor-left"            =>{jdcmd_maybe_deselect_command,cursor_left},

   "cursor-right"              =>{jdcmd_maybe_deselect_command,cursor_right},
   "vi-cursor-right"           =>{jdcmd_maybe_deselect_command,cursor_right},

   "cursor-up"                 =>{jdcmd_maybe_deselect_command,cursor_up},
   "vi-prev-line"              =>{jdcmd_maybe_deselect_command,cursor_up},

   "cursor-down"               =>{jdcmd_maybe_deselect_command,cursor_down},
   "vi-next-line"              =>{jdcmd_maybe_deselect_command,cursor_down},

   "begin-line"                =>{jdcmd_maybe_deselect_command,begin_line},

   "begin-line-text-toggle"    =>{jdcmd_maybe_deselect_command,begin_line_text_toggle},

   "brief-home"                =>{jdcmd_maybe_deselect_command,begin_line},

   "vi-begin-line"             =>{jdcmd_maybe_deselect_command,begin_line},

   "vi-begin-line-insert-mode" =>{jdcmd_maybe_deselect_command,begin_line},

   "brief-end"                 =>{jdcmd_maybe_deselect_command,end_line},
   "end-line"                  =>end_line,
   "end-line-text-toggle"      =>{jdcmd_maybe_deselect_command,end_line_text_toggle},
   "end-line-ignore-trailing-blanks"=>{jdcmd_maybe_deselect_command,end_line_ignore_trailing_blanks},
   "vi-end-line"               =>{jdcmd_maybe_deselect_command,end_line},
   "vi-end-line-append-mode"   =>{jdcmd_maybe_deselect_command,end_line},
   "mou-click"                 =>mou_click,
   "mou-extend-selection"      =>mou_extend_selection,
   "mou-select-line"           =>mou_select_line,

   "select-line"               =>select_line,
   "brief-select-line"         =>select_line,
   "select-char"               =>select_char,
   "brief-select-char"         =>select_char,
};

/**
 * Controls whether or not the JavaDoc editor will preserve
 * comments for obsolete or misnamed parameters.
 *
 * @categories Configuration_Variables
 */
bool def_javadoc_keep_obsolete=false;

static const JDMIN_EDITORCTL_HEIGHT=  600;
/**
 * Amount in twips to indent in the Y direction after a label control
 */
static const JDY_AFTER_LABEL=   28;
/**
 * Amount in twips to indent in the Y direction after controls that do not have
 * a specific indent
 */
static const JDY_AFTER_OTHER=   100;
static const JDX_BETWEEN_TEXT_BOX=  200;

static const JAVATYPE_CLASS=    1;
static const JAVATYPE_DATA=     2;
static const JAVATYPE_METHOD=   3;
static const JAVATYPE_LAST=     3;

_control ctlcancel;

static int CURJAVATYPE(...) {
   if (arg()) ctlok.p_user=arg(1);
   return ctlok.p_user;
}
static int MODIFIED(...) {
   if (arg()) ctltree1.p_user=arg(1);
   return ctltree1.p_user;
}
static typeless TIMER_ID(...) {
   if (arg()) ctltagcaption.p_user=arg(1);
   return ctltagcaption.p_user;
}
static _str HASHTAB(...):[][] {
   if (arg()) ctlcancel.p_user=arg(1);
   return ctlcancel.p_user;
}
static int CURTREEINDEX(...) {
   if (arg()) p_active_form.p_user=arg(1);
   return p_active_form.p_user;
}
static int USE_EXCEPTION_TAG(...) {
   if (arg()) ctlpreview.p_user=arg(1);
   return ctlpreview.p_user;
}
   _control ctltree1;

defeventtab _javadoc_form;
void ctloptions.lbutton_up()
{
   show("-modal _javadoc_format_form");
}
struct JDSEEUSERDATA {
   int NofHiddenLinesBefore;
   int NofHiddenLinesAfter;
   int NofHiddenBytes;
};
static void jdSetupSeeContextTagging()
{
   if (p_user!="") {
      return;
   }
   p_user=1;
   //say("initializing data");
   orig_modify := p_modify;
   orig_linenum := p_line;
   orig_col := p_col;
   top();
   text := get_text(p_buf_size);
   /*if (length(text)<length(p_newline) ||
       substr() {
   } */

   typeless markid=_alloc_selection();
   int editorctl_wid=_form_parent();
   typeless p;
   editorctl_wid.save_pos(p);
   editorctl_wid.top();
   editorctl_wid._select_line(markid);
   editorctl_wid.bottom();
   editorctl_wid._select_line(markid);
   int undo_steps=p_undo_steps;p_undo_steps=0;
   _lbclear();
   _copy_to_cursor(markid);
   editorctl_wid.restore_pos(p);

   _free_selection(markid);
   top();up();
   _lineflags(HIDDEN_LF,PLUSBITMAP_LF|MINUSBITMAP_LF|HIDDEN_LF|LEVEL_LF);
   for (;;) {
      if ( down()) break;
      _lineflags(HIDDEN_LF,PLUSBITMAP_LF|MINUSBITMAP_LF|HIDDEN_LF|LEVEL_LF);
   }

   orig_wid := p_window_id;
   int orig_view_id;
   get_window_id(orig_view_id);
   p_window_id=editorctl_wid;
   _UpdateContext(true);
   _str proc_name,path;
   start_line_no := -1;
   int javatype;
   tag_init_tag_browse_info(auto cm);
   orig_wid.ctltree1._ProcTreeTagInfo2(editorctl_wid,cm,proc_name,path,start_line_no,orig_wid.CURTREEINDEX());
   activate_window(orig_view_id);

   p_RLine=start_line_no;
   p_col=1;
   up();
   restore_linenum := 0;
   i := 0;
   for (i=1;;++i) {
      if (text:=="") break;
      line := "";
      parse text with line '\r\n|\r|\n','r' text;
      insert_line(line);
      _lineflags(0,HIDDEN_LF);
      if (i==orig_linenum) {
         restore_linenum=i;
      }
   }
   p_col=orig_col;
   if (restore_linenum) {
      p_line=restore_linenum;
   }
   p_undo_steps=undo_steps;
   p_modify=orig_modify;

}
void ctlsee1.on_got_focus()
{
   jdSetupSeeContextTagging();
}


static void jdEditControlEventHandler()
{
   _str lastevent=last_event();
   _str eventname=event2name(lastevent);
   //messageNwait("_EditControlEventHandler: eventname="eventname" _select_type()="_select_type());
   if (eventname=="F1" || eventname=="A-F4" || eventname=="ESC" || eventname=="TAB" || eventname=="S-TAB") {
      call_event(defeventtab _ainh_dlg_manager,last_event(),'e');
      return;
      //help("Diff Dialog box");
   }
   if (eventname=="MOUSE-MOVE") {
      return;
   }
   /*if (eventname=="RBUTTON-DOWN ") {
      edit_window_rbutton_up();
      return;
   } */
   typeless junk="";
   typeless status=0;
   if (substr(eventname,1,2)=="A-" && isalpha(substr(eventname,3,1))) {
      letter := "";
      parse event2name(last_event()) with "A-" letter;
      status=_dmDoLetter(letter);
      if (!status) return;
   }
   int key_index=event2index(lastevent);
   name_index := eventtab_index(_default_keys,p_mode_eventtab,key_index);
   command_name := name_name(name_index);

   //This is to handle C-X combinations
   if (name_type(name_index)==EVENTTAB_TYPE) {
      int eventtab_index2=name_index;
      _str event2=get_event("k");
      key_index=event2index(event2);
      name_index=eventtab_index(_default_keys,eventtab_index2,key_index);
      command_name=name_name(name_index);
   }
   if (JavadocCommands._indexin(command_name)) {
      old_dragdrop := def_dragdrop;
      def_dragdrop=false;
      switch (JavadocCommands:[command_name]._varformat()) {
      case VF_FUNPTR:
         (*JavadocCommands:[command_name])();
         break;
      case VF_ARRAY:
         junk=(*JavadocCommands:[command_name][0])(JavadocCommands:[command_name][1]);
         break;
      }
      def_dragdrop=old_dragdrop;
   } else {
      if (command_name!="") {
         if (pos('\-space$',command_name,1,'r')) {
            keyin(' ');
         }else if (pos('\-enter$',command_name,1,'r')) {
            split_insert_line();
         }else if (pos('\maybe-case-backspace$',command_name,1,'r')) {
            jdcmd_linewrap_rubout();
         }else if (pos('\-backspace$',command_name,1,'r')) {
            jdcmd_linewrap_rubout();
         }
      }
   }

   p_scroll_left_edge=-1;

}
//void ctlsee1.\0-\33,\129-MBUTTON_UP,'S-LBUTTON-DOWN'-ON_SELECT()
void ctlsee1."range-first-nonchar-key"-"all-range-last-nonchar-key"," ", "range-first-mouse-event"-"all-range-last-mouse-event",ON_SELECT()
{
   jdEditControlEventHandler();
}
static void jdDoCharKey()
{
   _str key=last_event();
   int index=eventtab_index(p_mode_eventtab,p_mode_eventtab,event2index(key));
   cmdname := name_name(index);
   if (pos("auto-codehelp-key",cmdname) || 
       pos("auto-functionhelp-key",cmdname)
       ) {
      call_index(find_index(cmdname,name_type(index)));
      return;
   }
   keyin(key);
}
#if 0
static void jd_multi_delete(_str cmdline="")
{
   line := "";
   if ((cmdline==""||p_word_wrap_style&WORD_WRAP_WWS) && OnImaginaryLine()) {
      get_line(line);
      //if (p_col==length(line)) return;
      if (p_col>=length(expand_tabs(line))) return;
   }
   if (p_col > _line_length()) {
      if (!down()) {
         if (OnImaginaryLine()) {
            if (cmdline=="" ||
                cmdline=="linewrap-delete-char"||
                cmdline=="delete-char") {
               DiffMessageBox("Cannot split Imaginary line");
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

   oldwid := 0;
   oldmodify := false;
   origline := wid.p_line;
   wid.get_line(line);
   onlast := OnLastLine();
   int isimaginary=wid._lineflags()&NOSAVE_LF;
   if (isimaginary && !DialogIsDiff()) {
      return;
   }
   switch (cmdline) {
   case "cut":
      wid.cut();break;
   case "linewrap-delete-char":
      wid.linewrap_delete_char();break;
   case "delete-char":
      wid.linewrap_delete_char();break;
   case "cut-line":
      oldmodify=wid.p_modify;
      wid.cut_line();
      if (isimaginary) wid.p_modify=oldmodify;
      break;
   case "delete-line":
      oldmodify=p_modify;
      wid.delete_line();
      if (isimaginary) p_modify=oldmodify;
      break;
   case "delete-selection":
      wid.delete_selection();break;
   default:
      wid._begin_select();
      oldwid=p_window_id;p_window_id=wid;
      _delete_selection();
      p_window_id=oldwid;
      wid.keyin(last_event());
      break;
   }
   if (wid.p_Noflines<orig_numlines) {
      cur_num_lines := wid.p_Noflines;
      otherwid.p_line=origline;
      if (!wid.OnLastLine()) {
         otherwid.p_line=wid.p_line;
      }
      int i;
      for (i=1;i<=orig_numlines-cur_num_lines;++i) {
         old_col := p_col;
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
      otherwid.p_line=wid.p_line;
   }
   if (_lineflags()&MODIFY_LF) {
      otherwid._lineflags(MODIFY_LF,MODIFY_LF);
   }
   AddUndoNothing(otherwid);

   otherwid.set_scroll_pos(otherwid.p_left_edge,wid.p_cursor_y);
   p_active_form.p_user=1;
}
#endif

static int jdmaybe_delete_selection()
{
   if (!command_state() && select_active()) {
      if ( _select_type("",'U')=="P" && _select_type("",'S')=="E" ) {
         return(0);
      }
      if ( def_persistent_select=="D"  && !_QReadOnly() ) {
         _begin_select();
         if (_select_type()=="LINE") {
            p_col=1;_delete_selection();
            if (_lineflags() & HIDDEN_LF) {
               up();
               insert_line("");
               _lineflags(0,HIDDEN_LF);
            }
         } else if (_select_type()=="CHAR") {
            _end_select();
            _end_line();
            down();
            if (_lineflags()& HIDDEN_LF) {
               first_col := 0;
               last_col := 0;
               typeless junk="";
               _get_selinfo(first_col,last_col,junk);
               if(p_col<last_col+_select_type("","i")) {
                  up();insert_line("");
               }
            }
            _begin_select();
            _delete_selection();
         } else {
            _delete_selection();
         }
         return(1);
      }
   }
   return(0);
}
void ctlsee1.\33-"range-last-char-key"()
{
   jdmaybe_delete_selection();
   jdDoCharKey();
}
void ctlsee1."<"()
{
}
void ctlsee1."<"()
{
   jdmaybe_delete_selection();
   line := "";
   get_line(line);
   if (line!="") {
      keyin("<");
      return;
   }
   _SetEditorLanguage("html");
   _insert_text("<"case_html_tag("a")" "case_html_tag("href",true)'=""></'case_html_tag("a")">");
   _SetEditorLanguage(_form_parent().p_LangId);
   p_col-=6;
}
void ctlsee1."#"()
{
   jdmaybe_delete_selection();
   line := "";
   get_line(line);
   int cfg=_clex_find(0,'g');
   if (cfg==CFG_COMMENT || cfg==CFG_STRING) {
      keyin("#");
      return;
   }
   auto_codehelp_key();
}
void ctlparam3."TAB"()
{
   int wid=_find_control("ctlparamcombo"CURJAVATYPE());
   if (wid.p_line<wid.p_Noflines) {
      wid._lbdown();
      wid.p_text=wid._lbget_text();
   } else {
      call_event(defeventtab _ainh_dlg_manager,TAB,'E');
   }
}
void ctlparam3."S-TAB"()
{
   int wid=_find_control("ctlparamcombo"CURJAVATYPE());
   if (wid.p_line>1) {
      wid._lbup();
      wid.p_text=wid._lbget_text();
   } else {
      call_event(defeventtab _ainh_dlg_manager,S_TAB,'E');
   }
}
//void _javadoc_form.A_A-A_Z()
void _javadoc_form.A_K,A_X,A_O,A_T,A_N,A_P,A_A,A_X,A_M,A_U,A_I()
{
   _str lastevent=last_event();
   _str eventname=event2name(lastevent);
   if (substr(eventname,1,2)=="A-" && isalpha(substr(eventname,3,1))) {
      letter := "";
      parse event2name(last_event()) with "A-" letter;
      int status=_dmDoLetter(letter);
      if (!status) return;
   }
}
void ctlok.lbutton_up()
{
   jdMaybeSave(true);
   p_active_form._delete_window();
}

static _str jdSSTab[][]={
   {"0"},
   {"ctldescriptionlabel1"},
   {"ctldescriptionlabel2"},
   {"ctldescriptionlabel3","ctlsincelabel3","ctlexamplelabel3","ctlexamplenotelabel3"},
};
static int jdPercentageHashtab:[]={
   "ctldescription1"=> 50,
   "ctldeprecated1"=>22,
   "ctlsee1"=>28,

   "ctldescription2"=> 50,
   "ctldeprecated2"=>22,
   "ctlsee2"=>28,

   "ctldescription3"=> 50,
   "ctlparam3"=> 25,
   "ctlreturn3"=> 25,

   "ctldeprecated3"=>30,
   "ctlsee3"=>35,
   "ctlexception3"=> 35,

   "ctlexample3"=>100
};
static void jdHideAll()
{
   int i,wid;
   for (i=1;i<=JAVATYPE_LAST;++i) {
      wid=_find_control("ctlpicture"i);
      wid.p_visible=false;
   }
   ctlpreview.p_enabled=false;
}
static int jdPictureFirstChild()
{
   int wid=_find_control("ctlpicture"CURJAVATYPE());
   if (wid.p_object==OI_SSTAB) {
      return(_find_control(jdSSTab[CURJAVATYPE()][wid.p_ActiveTab]));
   }
   return(wid.p_child);
}
static void jdCheckForModifiedEditorCtl()
{
   int child,firstchild;
   firstchild=child=jdPictureFirstChild();
   for (;;) {
      if (child.p_object==OI_EDITOR) {
         if (child.p_modify) {
            MODIFIED(1);
            return;
         }
      }
      child=child.p_next;
      if (child==firstchild) break;
   }
}
/*
  The data is modified if any editor control is modified or
  a text box, or check box is modified.
*/
static bool jdModified()
{
   if (CURJAVATYPE()=="") return(false);
   if (MODIFIED()) {
      return(true);
   }
   jdCheckForModifiedEditorCtl();
   if (MODIFIED()) {
      return(true);
   }
   return(false);
}
static void jdCopyEditorCtlData(int form_wid,_str prefix,_str ctlname,int flag,bool &addBlankBeforeNext,_str atTagSpace="",bool atTagSpaceFirstLineOnly=true)
{
   int wid=form_wid._find_control(ctlname:+form_wid.CURJAVATYPE());
   if (wid && wid.p_visible) {
      if (!wid.p_Noflines) {
         return;
      }
      line := "";
      wid.get_line(line);
      if (ctlname=="ctlexample" && wid.p_Noflines==1 && line=="") {
         return;
      }
      status := 0;
      typeless p;
      wid.save_pos(p);
      wid.top();
      isdescription := (ctlname=="ctldescription");
      if (isdescription) {
         status=wid.search('^[ \t]*\@','@rh');
      }
      wid.bottom();
      while (wid.p_Noflines>1) {
         wid.get_line(line);
         if (line!="") break;
         wid._delete_line();
      }
      doBeautify := false;
      indent := "";

      if ((def_javadoc_format_flags & VSJAVADOCFLAG_BEAUTIFY) &&
          (
          (ctlname=="ctlreturn" &&

             (def_javadoc_format_flags & VSJAVADOCFLAG_ALIGN_RETURN)) ||
          (ctlname=="ctldeprecated" &&

             (def_javadoc_format_flags & VSJAVADOCFLAG_ALIGN_DEPRECATED))
          )

         ) {
         wid.top();
         status=wid.search( "<pre|<xmp" ,'rh@i');
         if (status) {
            doBeautify=true;
            indent=substr("",1,length(atTagSpace));
         }
      }
      wid.top();wid.up();
      for (;;) {
         if (wid.down()) break;
         if (wid._lineflags() & HIDDEN_LF) {
            continue;
         }
         wid.get_line(line);
         if (ctlname!="ctlsee" || line!="") {
            if (addBlankBeforeNext) {
               insert_line(prefix);
               addBlankBeforeNext=false;
            }
            if (doBeautify && length(atTagSpace)==0) {
               insert_line(prefix:+atTagSpace:+indent:+strip(line));
            } else {
               insert_line(prefix:+atTagSpace:+line);
            }
         }
         if (atTagSpaceFirstLineOnly) {
            atTagSpace="";
         }
      }
      wid.restore_pos(p);
      if ((def_javadoc_format_flags & VSJAVADOCFLAG_BEAUTIFY) &&
          (def_javadoc_format_flags & flag)
          ) {
         for (;;) {
            get_line(line);
            line=substr(line,length(prefix));
            if (line!="") {
               break;
            }
            if(!_delete_line()) {
               if (up()) break;
            }
         }
         if (status) {
            addBlankBeforeNext=true;
         }
      }
   }
}
static void jdCopyComboCtlData(int form_wid,_str prefix,_str ctlname,int flag,bool &addBlankBeforeNext,_str tag,_str tagPrefix="@")
{

   _str hashindex_tag=tag;
   if (tag=="exception" && !form_wid.USE_EXCEPTION_TAG()) {
      tag="throws";
   }
   
   list := "";
   line := "";
   argName := "";
   rest := "";

   int wid=form_wid._find_control(ctlname:+form_wid.CURJAVATYPE());
   if (wid) {
      _str hashtab:[][]=form_wid.HASHTAB();
      // If there are parameters
      int count=hashtab:[hashindex_tag]._length();
      if (!def_javadoc_keep_obsolete && 
          hashindex_tag=="param" && hashtab._indexin("@paramcount")) {
         count=(int)hashtab:["@paramcount"][0];
      }
      i := 0;
      LongestLen := -1;
      int minLen,maxLen;
      int flag2;
      if (hashindex_tag=="param") {
         flag2=VSJAVADOCFLAG_ALIGN_PARAMETERS;
         minLen=def_javadoc_parammin;
         maxLen=def_javadoc_parammax;
      } else {
         flag2=VSJAVADOCFLAG_ALIGN_EXCEPTIONS;
         minLen=def_javadoc_exceptionmin;
         maxLen=def_javadoc_exceptionmax;
      }
      if ((def_javadoc_format_flags & VSJAVADOCFLAG_BEAUTIFY) &&
          (def_javadoc_format_flags & flag2)
          ) {
         LongestLen=minLen;
         // Determine the longest parameter name.
         for (i=0;i<count;++i) {
            list=hashtab:[hashindex_tag][i];
            parse list with line "\n" list;
            parse line with argName rest;
            if (hashindex_tag!="param" || !def_javadoc_keep_obsolete ||
                i<hashtab:["@paramcount"][0] ||
                rest!="" || list!="") {
               if (length(argName)>LongestLen) {
                  if (length(argName)<=maxLen) {
                     LongestLen=length(argName);
                  }
               }
            }
         }
         if (LongestLen<minLen) {
            LongestLen=minLen;
         }
      }

      for (i=0;i<count;++i) {
         list=hashtab:[hashindex_tag][i];
         parse list with line "\n" list;
         parse line with argName rest;
         if (hashindex_tag!="param" || !def_javadoc_keep_obsolete ||
             i<hashtab:["@paramcount"][0] ||
             rest!="" || list!="") {
            indent := "";
            doBeautify := false;
            if (addBlankBeforeNext) {
               insert_line(prefix);
               addBlankBeforeNext=false;
            }
            if (LongestLen>=0 && !pos("<pre",rest:+list,1,'i') &&
                !pos("<xmp",rest:+list,1,'i')
                ) {
               if (length(argName)<=LongestLen) {
                  argName=substr(argName,1,LongestLen);
               }
               if (length(argName)>maxLen) {
                  insert_line(prefix:+tagPrefix:+tag:+strip(" "argName,'T'));
                  indent=substr("",1,length(tagPrefix:+tag)+LongestLen+2);
                  if (rest!="") {
                     insert_line(prefix:+indent:+strip(rest));
                  }
               } else {
                  indent=substr("",1,1+length(tagPrefix:+tag" ")+length(argName));
                  insert_line(prefix:+tagPrefix:+tag:+strip(" "argName:+" "strip(rest),'T'));
               }
               doBeautify=true;
            } else {
               doBeautify=false;
               insert_line(prefix:+tagPrefix:+tag" "argName:+" "rest);
            }
            for (;;) {
               if (list:=="") {
                  break;
               }
               parse list with line "\n" list;
               if (addBlankBeforeNext) {
                  insert_line(prefix);
                  addBlankBeforeNext=false;
               }
               if (doBeautify) {
                  insert_line(prefix:+indent:+strip(line));
               } else {
                  insert_line(prefix:+indent:+line);
               }
            }
         }
         if ((def_javadoc_format_flags & VSJAVADOCFLAG_BEAUTIFY) &&
             ((def_javadoc_format_flags & flag) ||
              (i+1==count && hashindex_tag=="param" &&
               (def_javadoc_format_flags & VSJAVADOCFLAG_BLANK_LINE_AFTER_LAST_PARAM)))
             ) {
            for (;;) {
               get_line(line);
               line=substr(line,length(prefix));
               if (line!="") {
                  break;
               }
               status := _delete_line();
               if (!status) up();
            }
            addBlankBeforeNext=true;
         }
      }
   }
}
/**
 * Insert comment lines into current editor control object.
 * 
 * @param form_wid      Window id of javadoc form
 * @param start_col     Lines are indent up to start_col specified
 * @param comment_flags bitset of VSCODEHELP_COMMENTFLAG_*
 * @param doxygen_comment_start  start characters for Doxygen comments.
 */
static void jdInsertCommentLines(int form_wid,
                                 int start_col,
                                 int comment_flags=0,
                                 _str doxygen_comment_start="",
                                 _str tagPrefix="@")
{

   // save parameter changes
   int wid=form_wid._find_control("ctlparamcombo"form_wid.CURJAVATYPE());
   if (wid) {
      wid.jdShowParam();
   }

   // save parameter changes
   wid=form_wid._find_control("ctlexceptioncombo"form_wid.CURJAVATYPE());
   if (wid) {
      wid.jdShowParam("exception");
   }

   _str slcomment_start;
   _str mlcomment_start;
   _str mlcomment_end;
   get_comment_delims(slcomment_start,mlcomment_start,mlcomment_end);

   if (comment_flags & VSCODEHELP_COMMENTFLAG_DOXYGEN) {
      if (doxygen_comment_start == "//!") {
         mlcomment_start = "";
         mlcomment_end   = "";
         slcomment_start = doxygen_comment_start;
      } else if (doxygen_comment_start == "/*!") {
         mlcomment_start = doxygen_comment_start;
         slcomment_start=" *";
      }
   } else {
      mlcomment_start = "/**";
   }

   if (mlcomment_start!="") {
      insert_line(indent_string(start_col-1):+mlcomment_start);
      slcomment_start="";
      if (pos("*",mlcomment_start)) {
         slcomment_start=" *";
      }
   }

   _str prefix=indent_string(start_col-1):+slcomment_start:+" ";
   addBlankBeforeNext := false;
   jdCopyEditorCtlData(form_wid,prefix,"ctldescription",
                       VSJAVADOCFLAG_BLANK_LINE_AFTER_DESCRIPTION,addBlankBeforeNext,
                       "",true
                       );

   wid=form_wid._find_control("ctlauthor"form_wid.CURJAVATYPE());
   if (wid && wid.p_text!="") {
      author_list := wid.p_text;
      for (;;) {
         author := "";
         parse author_list with author "," author_list;
         if (author=="") break;
         if (addBlankBeforeNext) {
            insert_line(prefix);
            addBlankBeforeNext=false;
         }
         insert_line(prefix:+tagPrefix"author "strip(author));
      }
   }
   wid=form_wid._find_control("ctlversion"form_wid.CURJAVATYPE());
   if (wid && wid.p_text!="") {
      insert_line(prefix:+tagPrefix"version "strip(wid.p_text));
   }
   jdCopyComboCtlData(form_wid,prefix,"ctlparamcombo",VSJAVADOCFLAG_BLANK_LINE_AFTER_PARAMETERS,addBlankBeforeNext,"param",tagPrefix);
   jdCopyEditorCtlData(form_wid,prefix,"ctlreturn",VSJAVADOCFLAG_BLANK_LINE_AFTER_RETURN,addBlankBeforeNext,tagPrefix:+"return ");
   jdCopyEditorCtlData(form_wid,prefix,"ctlexample",VSJAVADOCFLAG_BLANK_LINE_AFTER_EXAMPLE,addBlankBeforeNext,tagPrefix:+"example ");

   jdCopyComboCtlData(form_wid,prefix,"ctlexceptioncombo",0,addBlankBeforeNext,"exception");

   jdCopyEditorCtlData(form_wid,prefix,"ctlsee",0,addBlankBeforeNext,tagPrefix:+"see ",false);

   wid=form_wid._find_control("ctlsince"form_wid.CURJAVATYPE());
   if (wid && wid.p_text!="") {
      insert_line(prefix:+tagPrefix:+"since "strip(wid.p_text));
   }
   wid=form_wid._find_control("ctldeprecated"form_wid.CURJAVATYPE());
   if (wid) {
      // IF Deprecated check box is on
      if (wid.p_prev.p_value) {
         jdCopyEditorCtlData(form_wid,prefix,"ctldeprecated",0,addBlankBeforeNext,tagPrefix:+"deprecated ");
      }
   }
   line := "";
   get_line(line);
   if (line=="*") {
      _delete_line();up();
   }
   if (mlcomment_end != "") {
      insert_line(indent_string(start_col):+mlcomment_end);
   }
}

static void jdMaybeSave(bool forceSave=false)
{
   if (jdModified() || forceSave) {
      static int recursion;
      if (recursion) return;
      ++recursion;
      //say('a0 CURT='CURTREEINDEX()' cap='ctltree1._TreeGetCaption(CURTREEINDEX()));

      form_wid := p_active_form;
      editorctl_wid := _form_parent();
      orig_wid := p_window_id;

      int orig_view_id;
      get_window_id(orig_view_id);
      p_window_id=editorctl_wid;

      // make sure that the context doesn't get modified by a background thread.
      se.tags.TaggingGuard sentry;
      sentry.lockContext(false);
      _UpdateContext(true);

      _str proc_name,path;
      start_line_no := -1;
      tag_init_tag_browse_info(auto cm);
      orig_wid.ctltree1._ProcTreeTagInfo2(editorctl_wid,cm,proc_name,path,start_line_no,orig_wid.CURTREEINDEX());

      _save_pos2(auto p);
      p_RLine=start_line_no;

      _GoToROffset(cm.seekpos);
      start_col := p_col;

      VSCodeHelpCommentFlags comment_flags=0;
      orig_comment := "";
      return_type := "";
      line_prefix := "";
      doxygen_comment_start := "";
      int blanks:[][];
      tagPrefix := "@";
      status := _GetCurrentCommentInfo(comment_flags,orig_comment,return_type,line_prefix,blanks,doxygen_comment_start);
      if (status != 0) {
         comment_flags=0;
      } else if (comment_flags & VSCODEHELP_COMMENTFLAG_DOXYGEN) {
         if (pos("\\param " ,orig_comment)) tagPrefix="\\";
         if (pos("\\return ",orig_comment)) tagPrefix="\\";
      }

      first_line := start_line_no;
      last_line  := start_line_no;
      if (_do_default_get_tag_header_comments(first_line, last_line, start_line_no)) {
         first_line = start_line_no;
         last_line  = first_line-1;
      }

      // delete the original comment lines
      num_lines := last_line-first_line+1;
      if (num_lines > 0) {
         p_line=first_line;
         for (i:=0; i<num_lines; i++) {
            _delete_line();
         }
      } else {
         first_line=start_line_no;
      }
      p_line=first_line-1;

      jdInsertCommentLines(form_wid,start_col,comment_flags,doxygen_comment_start,tagPrefix);

      _restore_pos2(p);
      activate_window(orig_view_id);

      buf_name := editorctl_wid.p_buf_name;
      if (buf_name!="") {
         caption := "";
         parse p_active_form.p_caption with caption ":";
         p_active_form.p_caption=caption": "buf_name;
      }

      _javadoc_refresh_proctree(false);
      CURTREEINDEX(ctltree1._TreeCurIndex());
      //say('a1 CURT='CURTREEINDEX()' cap='ctltree1._TreeGetCaption(CURTREEINDEX()));
      --recursion;
   }
}
void _javadoc_refresh_proctree(bool curItemMayChange=true)
{
   tag_lock_context(true);
   form_wid := p_active_form;
   int editorctl_wid=_form_parent();
   editorctl_wid._UpdateContext(true);
   cb_prepare_expand(p_active_form,ctltree1,TREE_ROOT_INDEX);
   ctltree1._TreeBeginUpdate(TREE_ROOT_INDEX,"",'T');
   tag_tree_insert_context(ctltree1,TREE_ROOT_INDEX,
                           def_javadoc_filter_flags,
                           1,1,0,0);
   ctltree1._TreeEndUpdate(TREE_ROOT_INDEX);
   tag_unlock_context();
   ctltree1._TreeSizeColumnToContents(0);
   if (curItemMayChange) {
      nearIndex := ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
      if (nearIndex<0) {
         jdHideAll();
         ctltagcaption.p_caption="No symbol selected, check filtering options.";
         //p_active_form._delete_window();
         return;
      }
      ctltree1.call_event(CHANGE_SELECTED,nearIndex,ctltree1,ON_CHANGE,'W');
   }
}
static void jdClearControls(int activeTab=0)
{
   int firstchild,child;
   int wid=_find_control("ctlpicture"CURJAVATYPE());
   if (wid.p_object==OI_SSTAB) {
      firstchild=child=_find_control(jdSSTab[CURJAVATYPE()][activeTab]);
   } else {
      firstchild=child=jdPictureFirstChild();
   }
   for (;;) {
      undo_steps := 0;
      switch (child.p_object) {
      case OI_EDITOR:
         undo_steps=child.p_undo_steps;child.p_undo_steps=0;
         child._lbclear();
         child.p_user="";
         child.p_undo_steps=undo_steps;
         child.insert_line("");
         child.p_modify=false;
         child.p_MouseActivate=MA_ACTIVATE;
         break;
      case OI_CHECK_BOX:
         child.p_value=0;
         break;
      case OI_COMBO_BOX:
         child._lbclear();
         child.p_text="";
         break;
      case OI_TEXT_BOX:
         child.p_text="";
         break;
      }
      if (child.p_child) {
         int firstchild2,child2;
         firstchild2=child2=child.p_child;
         for (;;) {
            switch (child2.p_object) {
            case OI_EDITOR:
               undo_steps=child2.p_undo_steps;child2.p_undo_steps=0;
               child2._lbclear();
               child2.p_user="";
               child2.p_undo_steps=undo_steps;
               child2.insert_line("");
               child2.p_modify=false;
               child2.p_MouseActivate=MA_ACTIVATE;
               break;
            case OI_CHECK_BOX:
               child2.p_value=0;
               break;
            case OI_COMBO_BOX:
               child2._lbclear();
               child2.p_text="";
               break;
            case OI_TEXT_BOX:
               child2.p_text="";
               break;
            }
            child2=child2.p_next;
            if (child2==firstchild2) break;
         }
      }
      child=child.p_next;
      if (child==firstchild) break;
   }
}
static void jdShowType(int javatype)
{
   ctlparamcombo3.p_user="";
   ctlexceptioncombo3.p_user="";
   if (CURJAVATYPE()!=javatype) {
      jdHideAll();
      CURJAVATYPE(javatype);
   }
   int wid=_find_control("ctlpicture"CURJAVATYPE());
   if (wid.p_object==OI_SSTAB) {
      jdClearControls(0);
      jdClearControls(1);
   } else {
      jdClearControls(0);
   }
   ctlpreview.p_enabled=true;
}
static void jdResizeChildren(int activeTab=0)
{
   int paddingX=_dx2lx(SM_TWIP,_lx2dx(SM_TWIP,100));
   int paddingY=ctltree1.p_y;
   y := 0;
   int wid=_find_control("ctlpicture"CURJAVATYPE());
   // Determine the minimum hieght required
   NofSizeableControls := 0;
   UseMorePercent := 0;
   nextPaddingY := 0;
   int firstchild,child;
   if (wid.p_object==OI_SSTAB) {
      firstchild=child=_find_control(jdSSTab[CURJAVATYPE()][activeTab]);
   } else {
      firstchild=child=jdPictureFirstChild();
   }
   for (y=paddingY;;) {
      y+=nextPaddingY;
      if (child.p_visible==0) {
         y-=nextPaddingY;
         if (jdPercentageHashtab._indexin(child.p_name)) {
            UseMorePercent+=jdPercentageHashtab:[child.p_name];
         }
      } else {
         switch (child.p_object) {
         case OI_CHECK_BOX:
            if (!child.p_value) {
               y+=child.p_height;
               nextPaddingY=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDY_AFTER_OTHER));
               break;
            }
         case OI_LABEL:
            y+=child.p_height;
            nextPaddingY=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDY_AFTER_LABEL));
            break;
         case OI_EDITOR:
            if (jdPercentageHashtab._indexin(child.p_name)) {
               NofSizeableControls+=1;
               y+=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDMIN_EDITORCTL_HEIGHT));
               nextPaddingY=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDY_AFTER_OTHER));
               break;
            }
         default:
            y+=child.p_height;
            nextPaddingY=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDY_AFTER_OTHER));
         }
      }
      child=child.p_next;
      if (child==firstchild) break;
   }
   if (wid.p_object==OI_SSTAB) {
      y+=paddingY;
   }
   int extra_height=ctlok.p_y-y;
   int pic_width= _dx2lx(SM_TWIP,p_active_form.p_client_width)-ctlimage1.p_x-ctlimage1.p_width;
   if (!activeTab) {
      wid.p_x=ctlimage1.p_x_extent;
      wid.p_y=0;
      wid.p_width=pic_width;
      wid.p_y_extent = ctltree1.p_y_extent;
   }
   if (wid.p_object==OI_SSTAB) {
      firstchild=child=_find_control(jdSSTab[CURJAVATYPE()][activeTab]);

      pic_width-=(wid.p_width-wid.p_child.p_width);
      extra_height-=(wid.p_height-wid.p_child.p_height);
   } else {
      firstchild=child=jdPictureFirstChild();
   }
   if (extra_height<0) extra_height=0;
   int extra_height_remaining=extra_height;
   //say("*******************************************************");
   //say("extra_height="extra_height);
   nextPaddingY=0;
   last_sizeable_wid := 0;
   for (y=paddingY;;) {
      y+=nextPaddingY;
      if (child.p_visible==0) {
         y-=nextPaddingY;
      } else {
         int height;
         if (jdPercentageHashtab._indexin(child.p_name)) {
            percent := 0;
            if (UseMorePercent && NofSizeableControls) {
               percent=UseMorePercent/NofSizeableControls;
            }
            int extra=((percent+jdPercentageHashtab:[child.p_name])*extra_height) intdiv 100;
            height=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDMIN_EDITORCTL_HEIGHT))+extra;
            extra_height_remaining-=extra;
            last_sizeable_wid=wid;
         } else {
            height=child.p_height;
         }
         child._move_window(paddingX,y,pic_width-paddingX*2,height);
         //say("y="y" t="ctltree1.p_y);
         if (child.p_object==OI_PICTURE_BOX){
            sizename := substr(child.p_name,1,10);
            if (sizename=="ctlsizepic") {
               // version and serial
               int child2=child.p_child.p_next;
               int text_box_width=((child.p_width-JDX_BETWEEN_TEXT_BOX) intdiv 2);

               // move version text box
               child2._move_window(child2.p_x,child2.p_y,text_box_width,child2.p_height);
               child2=child2.p_next;
               // move serial label
               child2._move_window(text_box_width+JDX_BETWEEN_TEXT_BOX,child2.p_y,child2.p_width,child2.p_height);
               child2=child2.p_next;
               // move serial text box
               child2._move_window(text_box_width+JDX_BETWEEN_TEXT_BOX,child2.p_y,text_box_width,child2.p_height);
            } else if (sizename=="ctlsizeexc" || sizename=="ctlsizepar") {
               int label_wid=child.p_child;
               int combo_wid=label_wid.p_next;
               combo_wid.p_x=label_wid.p_x_extent+100;
               int width=child.p_width-combo_wid.p_x-label_wid.p_x;
               if (width<0) width=1000;
               combo_wid.p_width=width;
            }
         }
         switch (child.p_object) {
         case OI_CHECK_BOX:
            if (!child.p_value) {
               y+=child.p_height;
               nextPaddingY=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDY_AFTER_OTHER));
               break;
            }
         case OI_LABEL:
            y+=child.p_height;
            nextPaddingY=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDY_AFTER_LABEL));
            break;
         case OI_EDITOR:
            if (jdPercentageHashtab._indexin(child.p_name)) {
               y+=child.p_height;
               nextPaddingY=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDY_AFTER_OTHER));
               break;
            }
         default:
            y+=child.p_height;
            nextPaddingY=_dy2ly(SM_TWIP,_ly2dy(SM_TWIP,JDY_AFTER_OTHER));
         }
      }
      child=child.p_next;
      if (child==firstchild) break;
   }
}
static void jdResizeControls()
{
   ctltagcaption.p_visible=ctlok.p_visible=ctlcancel.p_visible=false;

   ctlok.p_y= _dy2ly(SM_TWIP,p_client_height)-ctlok.p_height-100;
   ctlcancel.p_y=ctlpreview.p_y=ctloptions.p_y=ctlok.p_y;
   ctltagcaption.p_y=ctlok.p_y+(ctlok.p_height-ctltagcaption.p_height) intdiv 2;
   ctltagcaption.p_x = ctloptions.p_x_extent + ctltree1.p_y; // options button is auto-sized, plus ctltree1.p_y for padding

   ctltree1.p_y_extent = ctlok.p_y-100;
   ctltree1.p_x_extent = ctlimage1.p_x;

   ctlimage1.p_y=0;
   ctlimage1.p_height=ctltree1.p_y_extent;

   ctlok.p_visible=ctlcancel.p_visible=true;
   ctltagcaption.p_visible=true;

   int wid=_find_control("ctlpicture"CURJAVATYPE());
   if (wid) {
      wid.p_visible=false;

      if (wid.p_object==OI_SSTAB) {
         jdResizeChildren(0);
         jdResizeChildren(1);
         jdResizeChildren(2);
      } else {
         jdResizeChildren();
      }

      wid.p_visible=true;
   }
}


// Get the information about the tag currently selected
// in the proc tree.
//
static int _ProcTreeTagInfo2(int editorctl_wid,
                             struct VS_TAG_BROWSE_INFO &cm,
                             _str &proc_name, _str &path, int &LineNumber,
                             int tree_index=-1)
{
   // find the tag name, file and line number
   if (tree_index<0) {
      tree_index= _TreeCurIndex();
   }
   LineNumber=_TreeGetUserInfo(tree_index);

   path=editorctl_wid.p_buf_name;
   cm.language=editorctl_wid.p_LangId;
   cm.file_name=editorctl_wid.p_buf_name;

   caption := _TreeGetCaption(tree_index);
   tag_tree_decompose_caption(caption,proc_name);

   // get the remainder of the information
   status := (int)_GetContextTagInfo(cm, "", proc_name, path, LineNumber);
   cm.language=editorctl_wid.p_LangId;
   cm.file_name=editorctl_wid.p_buf_name;
   return (status);
}

void jdParseParam(_str &string,_str &argName,_str &text,bool doBeautify=false,_str tag="")
{
   parse string with argName text;
   parse argName with argName '[ \n]','r';
   if (doBeautify &&
       def_javadoc_format_flags & VSJAVADOCFLAG_BEAUTIFY) {
      int flag2;
      if (tag=="param") {
         flag2=VSJAVADOCFLAG_ALIGN_PARAMETERS;
      } else {
         flag2=VSJAVADOCFLAG_ALIGN_EXCEPTIONS;
      }
      if ( (def_javadoc_format_flags & flag2) &&
           !pos("<pre",text,1,'i') &&
           !pos("<xmp",text,1,'i')
         ) {
         typeless result="";
         for (;;) {
            if (text:=="") {
               break;
            }
            line := "";
            parse text with line "\n" text;
            if (result=="") {
               result=strip(line);
            } else {
               result :+= "\n":+strip(line);
            }
         }
         text=result;

      }
   }
}
static int jdFindParam(_str tag,_str param_name,_str (&hashtab):[][],bool case_sensitive)
{
   int count=hashtab:[tag]._length();
   int i;
   _str argName,text;
   for (i=0;i<count;++i) {
      jdParseParam(hashtab:[tag][i],argName,text);
      if (case_sensitive) {
         if (argName==param_name) {
            return(i);
         }
      } else {
         if (strieq(argName,param_name)) {
            return(i);
         }
      }
   }
   return(-1);
}
static void jdShowParam(_str tag="param")
{
   if (p_text=="") return;
   int editorctl_wid=_form_parent();
   int widcombo=_find_control("ctl"tag"combo"CURJAVATYPE());
   int wid=_find_control("ctl"tag:+CURJAVATYPE());
   modify := wid.p_modify;
   _str hashtab:[][];
   hashtab=HASHTAB();
   _str param_name,text;
   if (modify && isinteger(widcombo.p_user) && widcombo.p_user>=0) {
      int j=widcombo.p_user;
      jdParseParam(hashtab:[tag][j],param_name,text);
      text=wid.get_text(wid.p_buf_size,0);
      if (wid.p_newline=="\r\n") {
         text=stranslate(text,"","\r");
      } else if (wid.p_newline=="\r") {
         text=stranslate(text,"\n","\r");
      }
      if (text:==wid.p_newline || text=="\n") {
         text="";
      }
      linetemp := "";
      parse text with linetemp "\n";
      hashtab:[tag][j]=param_name" "text;
      if (length(text)) {
         widcombo=_find_control("ctl"tag"combo"CURJAVATYPE());
         typeless p;
         widcombo.save_pos(p);
         widcombo._lbtop();
         if (!widcombo._lbfind_and_select_item(param_name" (empty)")) {
            widcombo._lbset_item(param_name);
         }
         widcombo.restore_pos(p);
      }
      HASHTAB(hashtab);
   }
   parse p_text with param_name" (";
   int undo_steps=wid.p_undo_steps;wid.p_undo_steps=0;
   wid._lbclear();
   wid.p_undo_steps=undo_steps;
   int j=jdFindParam(tag,param_name,hashtab,editorctl_wid.p_EmbeddedCaseSensitive);
   if (j>=0) {
      jdParseParam(hashtab:[tag][j],param_name,text,true,tag);
      wid._insert_text(text);
      wid.p_modify=modify;wid.top();
   }
   widcombo.p_user=j;
}
void ctlcancel.lbutton_up()
{
   if (jdModified()) {
      int result=prompt_for_save("Save changes?");
      if (result==IDCANCEL) {
         return;
      }
      if (result==IDYES) {
         jdMaybeSave();
      }
   }
   p_active_form._delete_window();
}
void ctlexceptioncombo3.on_change(int reason)
{
   jdShowParam("exception");
}
void ctlauthor1.on_change()
{
   MODIFIED(1);
}
void ctlparamcombo3.on_change(int reason)
{
   jdShowParam();
}
static void jdShowModified()
{
   if (MODIFIED()) {
      if (TIMER_ID()!="") {
         _kill_timer(TIMER_ID());
         TIMER_ID("");
      }
      p_active_form.p_caption=p_active_form.p_caption:+" *";
   }
}
static void TimerCallback(int form_wid)
{
   if (form_wid.jdModified()) {
      form_wid.MODIFIED(1);
      form_wid.jdShowModified();
   }
}
void ctlpreview.lbutton_up()
{
   form_wid := p_active_form;
   temp_view_id := 0;
   int orig_view_id=_create_temp_view(temp_view_id);
   p_UTF8=form_wid._form_parent().p_UTF8;
   _SetEditorLanguage(form_wid._form_parent().p_LangId);
   jdInsertCommentLines(form_wid,1);
   VSCodeHelpCommentFlags comment_flags=0;
   orig_comment := "";
   int first_line, last_line;
   line_prefix := "";
   int blanks:[][];
   doxygen_comment_start := "";
   if (!_do_default_get_tag_header_comments(first_line, last_line)) {
      _parse_multiline_comments(1,first_line,last_line,comment_flags,"",orig_comment,2000,line_prefix,blanks,doxygen_comment_start);
   }
   _make_html_comments(orig_comment, comment_flags, "", "", false, p_LangId);

   show("-xy -modal _javadoc_preview_form",orig_comment);

   activate_window(orig_view_id);
   return;
}
void ctltree1.on_change(int reason,int index)
{
   if (reason==CHANGE_SELECTED) {
      jdMaybeSave();
      if (TIMER_ID()=="") {
         TIMER_ID(_set_timer(40,TimerCallback,p_active_form));
      }

      if (index==TREE_ROOT_INDEX) return;
      CURTREEINDEX(index);
      //say("a3 CURTREEINDEX()="CURTREEINDEX());
      caption := _TreeGetCaption(CURTREEINDEX());
      parse caption with auto before "\t" auto after;
      if (after!="") {
         ctltagcaption.p_caption=stranslate(after,"&&","&");
      } else {
         ctltagcaption.p_caption=stranslate(caption,"&&","&");
      }
      // Line number and type(class,proc|func, other)
      tag_init_tag_browse_info(auto cm);
      editorctl_wid := _form_parent();
      buf_name := editorctl_wid.p_buf_name;
      if (buf_name!="") {
         parse p_active_form.p_caption with caption ":";
         p_active_form.p_caption=caption": "buf_name;
      }
      orig_wid := p_window_id;

      get_window_id(auto orig_view_id);
      p_window_id=editorctl_wid;

      // make sure that the context doesn't get modified by a background thread.
      se.tags.TaggingGuard sentry;
      sentry.lockContext(false);
      _UpdateContext(true);

      embedded_status := _EmbeddedStart(auto orig_values);

      start_line_no := 1;
      javatype := 0;
      orig_wid._ProcTreeTagInfo2(editorctl_wid,cm,auto proc_name,auto path,start_line_no,index);
      if (tag_tree_type_is_func(cm.type_name)) {
         javatype=JAVATYPE_METHOD;
      } else if (tag_tree_type_is_class(cm.type_name)) {
         javatype=JAVATYPE_CLASS;
         //} else if (tag_tree_type_is_package(cm.type_name)) {
      } else {
         javatype=JAVATYPE_DATA;
      }
      orig_wid.jdShowType(javatype);
      init_modified := 0;

      save_pos(auto p);
      p_RLine=start_line_no;
      _GoToROffset(cm.seekpos);
      //p_col=1;_clex_skip_blanks();

      // try to locate the current context, maybe skip over
      // comments to start of next tag
      int context_id = tag_current_context();
      if (context_id <= 0) {
         if (embedded_status==1) {
            _EmbeddedEnd(orig_values);
         }
         restore_pos(p);
         _message_box("no current tag");
         return;
      }

      // get the information about the current function
      tag_get_context_browse_info(context_id, auto context_cm);

      _GoToROffset(context_cm.seekpos);
      if (tag_tree_type_is_func(cm.type_name) || tag_tree_type_is_class(cm.type_name)) {
         _UpdateLocals(true);
      }

      VSCodeHelpCommentFlags comment_flags=0;
      count := 0;
      // hash table of original comments for incremental updates
      orig_comment := "";
      int first_line, last_line;
      if (!_do_default_get_tag_header_comments(first_line, last_line)) {
         p_RLine=context_cm.line_no;
         _GoToROffset(context_cm.seekpos);
         // We temporarily change the buffer name just in case the Javadoc Editor
         // is the one getting the comments.
         _str old_buf_name=p_buf_name;
         p_buf_name="";
         line_prefix := "";
         int blanks:[][];
         doxygen_comment_start := "";
         _do_default_get_tag_comments(comment_flags, context_cm.type_name, orig_comment, 1000, false, line_prefix, blanks, 
            doxygen_comment_start);
         p_buf_name=old_buf_name;
      } else {
         init_modified=1;
         first_line = context_cm.line_no;
         last_line  = first_line-1;
      }
      if (embedded_status==1) {
         _EmbeddedEnd(orig_values);
      }

      // double-check that context and locals are up-to-date
      editorctl_wid._GoToROffset(context_cm.seekpos);
      editorctl_wid._UpdateContext(true);
      editorctl_wid._UpdateLocals(true);

      restore_pos(p);
      activate_window(orig_view_id);

      _str hashtab:[][];
      _str tagList[];
      description := "";
      if (comment_flags & VSCODEHELP_COMMENTFLAG_JAVADOC) {
         //_parseJavadocComment(orig_comment, description,hashtab,tagList,false);
         tag_tree_parse_javadoc_comment(orig_comment, description, auto tagStyle, hashtab, tagList, false);
      } else {
         init_modified=1;
         description=orig_comment;
      }
      typeless i,j;
      hashtab._nextel(i);
      /*
        ORDER


         deprecated,param,return,throws,since

         others

         Author

         see
      */
      param_name := "";
      argName := "";
      text := "";
      list := "";

      typeless status=0;
      tag := "";
      line := "";
      int wid=_find_control("ctldescription"CURJAVATYPE());
      if (wid) {
         tag="description";
         if (description!="") {
            wid.p_undo_steps=0;
            wid._delete_line();
            wid._insert_text(description);
            while (wid.p_Noflines>1) {
               wid.get_line(line);
               if (line!="") break;
               wid._delete_line();
            }
            wid.p_modify=false;wid.top();
            wid.p_undo_steps=32000;
         }
      }
      wid=_find_control("ctldeprecated"CURJAVATYPE());
      if (wid) {
         tag="deprecated";
         if (hashtab._indexin(tag)) {
            wid.p_undo_steps=0;
            wid._delete_line();
            wid._insert_text(hashtab:[tag][0]);
            while (wid.p_Noflines>1) {
               wid.get_line(line);
               if (line!="") break;
               wid._delete_line();
            }

            if ((def_javadoc_format_flags & VSJAVADOCFLAG_BEAUTIFY)
                 && (def_javadoc_format_flags & VSJAVADOCFLAG_ALIGN_DEPRECATED)
                ) {
               wid.top();
               status=wid.search( "<pre|<xmp" ,'rh@i');
               if (status) {
                  wid.up();
                  for(;;) {
                     if (wid.down()) break;
                     wid.get_line(line);
                     wid.replace_line(strip(line));
                  }
               }

            }

            wid.p_modify=false;wid.top();
            wid.p_undo_steps=32000;
            wid.p_prev.p_value=1;
            wid.p_visible=true;

            hashtab._deleteel(tag);
         } else {
            wid.p_prev.p_value=0;
            wid.p_visible=false;
         }
      }
      wid=_find_control("ctlreturn"CURJAVATYPE());
      if (wid) {
         tag="return";
         // If there is a return value
         if (cm.return_type!=""  && cm.return_type!="void" && cm.return_type!="void VSAPI") {
            if (hashtab._indexin(tag)) {
               wid.p_undo_steps=0;
               wid._delete_line();
               wid._insert_text(hashtab:[tag][0]);
               while (wid.p_Noflines>1) {
                  wid.get_line(line);
                  if (line!="") break;
                  wid._delete_line();
               }

               if ((def_javadoc_format_flags & VSJAVADOCFLAG_BEAUTIFY)
                    && (def_javadoc_format_flags & VSJAVADOCFLAG_ALIGN_RETURN)
                   ) {
                  wid.top();
                  status=wid.search( "<pre|<xmp" ,'rh@i');
                  if (status) {
                     wid.up();
                     for(;;) {
                        if (wid.down()) break;
                        wid.get_line(line);
                        wid.replace_line(strip(line));
                     }
                  }

               }

               wid.p_modify=false;wid.top();
               wid.p_undo_steps=32000;
               hashtab._deleteel(tag);

            } else {
               // Add @return tag
               init_modified=1;
            }
            wid.p_visible=true;
            wid.p_prev.p_visible=true;
         } else {
            if (hashtab._indexin(tag)) {
               // Remove obsolete @return tag
               init_modified=1;
               hashtab._deleteel(tag);
            }
            wid.p_visible=false;
            wid.p_prev.p_visible=false;
         }
      }

      wid=_find_control("ctlparamcombo"CURJAVATYPE());
      if (wid) {
         tag="param";
         // If there are parameters
         bool hitList[];
         _str new_list[];
         count=0;
         if (hashtab._indexin(tag)) {
            count=hashtab:[tag]._length();
         }
         for (i=0;i<count;++i) hitList[i]=false;
         empty_msg := " (empty)";

         for (i=1; i<=tag_get_num_of_locals(); i++) {
            // only process params that belong to this function, not outer functions
            local_seekpos := 0;
            param_type := "";
            param_flags := SE_TAG_FLAG_NULL;
            tag_get_detail2(VS_TAGDETAIL_local_start_seekpos,i,local_seekpos);
            tag_get_detail2(VS_TAGDETAIL_local_type,i,param_type);
            if (param_type=='param' && local_seekpos>=cm.seekpos && local_seekpos<cm.scope_seekpos) {
               tag_get_detail2(VS_TAGDETAIL_local_name,i,param_name);
               tag_get_detail2(VS_TAGDETAIL_local_flags,i,param_flags);
               j=jdFindParam("param",param_name,hashtab,editorctl_wid.p_EmbeddedCaseSensitive);
               if (j < 0) {
                  j=jdFindParam("param","<"param_name">",hashtab,editorctl_wid.p_EmbeddedCaseSensitive);
               }
               if (param_flags & SE_TAG_FLAG_TEMPLATE) {
                  param_name = "<" :+ param_name :+ ">";
               }
               if (j>=0) {
                  jdParseParam(hashtab:[tag][j],argName,text);
                  if (new_list._length()!=j) {
                     init_modified=1;
                  }
                  new_list[new_list._length()]=hashtab:[tag][j];
                  hitList[j]=true;
                  if (text=="") {
                     wid._lbadd_item(param_name:+empty_msg);
                  } else {
                     wid._lbadd_item(param_name);
                  }
               } else {
                  init_modified=1;
                  wid._lbadd_item(param_name:+empty_msg);
                  new_list[new_list._length()]=param_name;
               }
            }
         }
         hashtab:["@paramcount"][0]=new_list._length();
         for (i=0;i<count;++i) {
            if (!hitList[i]) {
               jdParseParam(hashtab:[tag][i],argName,text);
               new_list[new_list._length()]=hashtab:[tag][i];
               wid._lbadd_item(argName" (obsolete)");
               if (!def_javadoc_keep_obsolete) {
                  init_modified=1;
               } else if(text=="") {
                  init_modified=1;
               }
            }
         }
         hashtab:[tag]=new_list;

         int widparam=_find_control("ctlparam"CURJAVATYPE());
         if (wid.p_Noflines) {
            HASHTAB(hashtab);
            wid._lbtop();
            wid.p_text=wid._lbget_text();
            //wid.jdShowParam();
            widparam.p_visible=true;
            widparam.p_prev.p_visible=true;
         } else {
            widparam.p_visible=false;
            widparam.p_prev.p_visible=false;
         }
      }

      USE_EXCEPTION_TAG(1);
      wid=_find_control("ctlexceptioncombo"CURJAVATYPE());
      if (wid) {
         USE_EXCEPTION_TAG(1);
         tag="exception";
         bool hitList[];
         count=0;
         if (hashtab._indexin(tag)) {
            count=hashtab:[tag]._length();
         } else if (hashtab._indexin("throws")) {
            hashtab:[tag]=hashtab:["throws"];
            hashtab._deleteel("throws");
            count=hashtab:[tag]._length();
            USE_EXCEPTION_TAG(0);
         }
         for (i=0;i<count;++i) hitList[i]=false;
         empty_msg := " (empty)";

         if (cm.exceptions!="") {
            list=cm.exceptions;
            exception := "";
            for (;;) {
               parse list with exception "," list;
               if (exception=="") break;
               j=jdFindParam("exception",exception,hashtab,editorctl_wid.p_EmbeddedCaseSensitive);
               if (j>=0) {
                  jdParseParam(hashtab:[tag][j],argName,text);
                  hitList[j]=true;
                  if (text=="") {
                     // comment not given for this exception
                     wid._lbadd_item(exception:+empty_msg);
                  } else {
                     wid._lbadd_item(exception);
                  }
               } else {
                  // exception in throws clause but not in the javadoc comment.
                  // add it to hashtab
                  wid._lbadd_item(exception:+empty_msg);
                  hashtab:[tag][hashtab:[tag]._length()]=exception;
               }
            }
         }
         for (i=0; i < count; ++i) {
            if (!hitList[i]) {
               jdParseParam(hashtab:[tag][i],argName,text);
               // We don't append an ' (obsolete)' text to the unchecked exceptions 
               // like we used to.  See #1-3DGMS.
               wid._lbadd_item(argName);
            }
         }

         int widparam=_find_control("ctlexception"CURJAVATYPE());
         if (wid.p_Noflines) {
            HASHTAB(hashtab);
            wid._lbtop();
            wid.p_text=wid._lbget_text();
            //wid.jdShowParam();
            widparam.p_visible=true;
            widparam.p_prev.p_visible=true;
         } else {
            widparam.p_visible=false;
            widparam.p_prev.p_visible=false;
         }
      }

      _str extra_description='';
      _str rest;
      wid=_find_control("ctlsince"CURJAVATYPE());
      if (wid) {
         tag="since";
         if (hashtab._indexin(tag)) {
            parse hashtab:[tag][0] with line "\n" rest;
            if (rest!='') {
               if (extra_description:!='') {
                  strappend(extra_description,"\n");
               }
               strappend(extra_description,rest);
            }
            wid.p_text=line;
            hashtab._deleteel(tag);
         }
      }
      wid=_find_control("ctlversion"CURJAVATYPE());
      if (wid) {
         tag="version";
         if (hashtab._indexin(tag)) {
            parse hashtab:[tag][0] with line "\n" rest;
            if (rest!='') {
               if (extra_description:!='') {
                  strappend(extra_description,"\n");
               }
               strappend(extra_description,rest);
            }
            wid.p_text=line;
            hashtab._deleteel(tag);
         }
      }
      wid=_find_control("ctlauthor"CURJAVATYPE());
      if (wid) {
         tag="author";
         if (hashtab._indexin(tag)) {
            count=hashtab:[tag]._length();
            authors := "";
            for (i=0;i<count;++i) {
               parse hashtab:[tag][i] with line "\n" rest;
               if (rest!='') {
                  if (extra_description:!='') {
                     strappend(extra_description,"\n");
                  }
                  strappend(extra_description,rest);
               }
               if (i==0) {
                  authors=strip(line);
               } else {
                  authors :+= ", ":+strip(line);
               }
            }
            wid.p_text=authors;
            hashtab._deleteel(tag);
         }
      }
      wid=_find_control("ctlsee"CURJAVATYPE());
      if (wid) {
         tag="see";
         see_msg := "";
         if (hashtab._indexin(tag)) {
            count=hashtab:[tag]._length();
            if (count) {
               wid._lbclear();
            }
            for (i=0;i<count;++i) {
               parse hashtab:[tag][i] with line "\n" rest;
               if (rest!='') {
                  if (extra_description:!='') {
                     strappend(extra_description,"\n");
                  }
                  strappend(extra_description,rest);
               }
               wid.insert_line(line);
            }
            wid.p_modify=false;wid.top();
            hashtab._deleteel(tag);
         }
      }
      wid=_find_control("ctlexample"CURJAVATYPE());
      if (wid) {
         tag="example";
         wid.delete_all();
         wid.insert_line("");
         wid.p_modify=false;
         // If there is example code
         if (hashtab._indexin(tag)) {
            wid.p_undo_steps=0;
            wid._delete_line();
            wid._insert_text(hashtab:[tag][0]);
            while (wid.p_Noflines>1) {
               wid.get_line(line);
               if (line!="") break;
               wid._delete_line();
            }
            wid.p_modify=false;wid.top();
            wid.p_undo_steps=32000;
            hashtab._deleteel(tag);
         }
         wid.p_visible=true;
         wid.p_prev.p_visible=true;
      }
      wid=_find_control("ctldescription"CURJAVATYPE());
      if (wid) {
         wid.bottom();
         if (extra_description!='') {
            wid.insert_line('');
            wid._insert_text(extra_description);
         }
         // add user defined tags
         first_time := true;

         for (j=0;j<tagList._length();++j) {
            tag=tagList[j];
            if (hashtab._indexin(tag) && 
                !(tag=="param" && _find_control("ctlparamcombo"CURJAVATYPE())) &&
                !(tag=="exception" && _find_control("ctlexceptioncombo"CURJAVATYPE())) &&
                substr(tag,1,1)!="@") {
               count=hashtab:[tag]._length();
               if (first_time && (def_javadoc_format_flags & VSJAVADOCFLAG_BLANK_LINE_AFTER_DESCRIPTION)) {
                  wid.insert_line("");
               }
               //if (count) wid.insert_line("");
               for (i=0;i<count;++i) {
                  wid._insert_text("\n@"tag" "hashtab:[tag][i]);
                  while (wid.p_Noflines>1) {
                     wid.get_line(line);
                     if (line!="") break;
                     wid._delete_line();
                     wid._end_line();
                  }
               }
               first_time=false;
               hashtab._deleteel(tag);
            }
         }

         /*for (tag._makeempty();;) {
            hashtab._nextel(tag);
            if (tag._isempty()) break;
            if (hashtab._indexin(tag) && tag!='param' && tag!="exception" && substr(tag,1,1)!="@") {
               count=hashtab:[tag]._length();
               if (first_time && (def_javadoc_format_flags & VSJAVADOCFLAG_BLANK_LINE_AFTER_DESCRIPTION)) {
                  wid.insert_line("");
               }
               //if (count) wid.insert_line("");
               for (i=0;i<count;++i) {
                  wid._insert_text("\n@"tag" "hashtab:[tag][i]);
                  while (wid.p_Noflines>1) {
                     wid.get_line(line);
                     if (line!="") break;
                     wid._delete_line();
                     wid._end_line();
                  }
               }
            }
            first_time=false;
         } */
         wid.p_modify=false;wid.top();
      }

#if 0
      tag="serial";
      member_msg := "";
      ddstyle := "";
      if (hashtab._indexin(tag)) {
         member_msg :+= "<DT><B>Serial:</B>";
         count=hashtab:[tag]._length();
         for (i=0;i<count;++i) {
            member_msg :+= "<dd>":+hashtab:[tag][i];
         }
         hashtab._deleteel(tag);
      }
      tag="serialfield";
      if (hashtab._indexin(tag)) {
         member_msg :+= "<DT><B>SerialField:</B>";
         count=hashtab:[tag]._length();
         for (i=0;i<count;++i) {
            fieldName := "";
            fieldType := "";
            parse hashtab:[tag][i] with fieldName fieldType text;
            member_msg :+= "<dd"ddstyle">":+fieldName" "fieldType:+" - ":+text;
         }
         hashtab._deleteel(tag);
      }
      tag="serialdata";
      if (hashtab._indexin(tag)) {
         member_msg :+= "<DT><B>SerialData:</B>";
         count=hashtab:[tag]._length();
         for (i=0;i<count;++i) {
            member_msg :+= "<dd"ddstyle">":+hashtab:[tag][i];
         }
         hashtab._deleteel(tag);
      }
#endif
      HASHTAB(hashtab);

      pic_wid := 0;
      MaybeShowDeprecated();
      wid=_find_control("ctlexceptioncombo"CURJAVATYPE());
      if (wid) {
         pic_wid=_find_control("ctlsizeexc"CURJAVATYPE());
         if (wid.p_Noflines) {
            pic_wid.p_visible=true;
            _find_control("ctlexception"CURJAVATYPE()).p_visible=true;
         } else {
            pic_wid.p_visible=false;
            _find_control("ctlexception"CURJAVATYPE()).p_visible=false;
            //ctlexceptionlabel3
         }
      }
      //MODIFIED(init_modified);
      MODIFIED(0);
      jdShowModified();

      p_active_form.jdResizeControls();
      pic_wid=_find_control("ctlpicture"CURJAVATYPE());
      pic_wid.p_visible=true;

   }
}
void ctlimage1.lbutton_down()
{
   _ul2_image_sizebar_handler(ctlok.p_width, ctlpicture3.p_x_extent-ctloptions.p_x);
}
void ctltree1.rbutton_up,context()
{
   // Get handle to menu:
   index := find_index("_tagbookmark_menu",oi2type(OI_MENU));
   menu_handle := p_active_form._menu_load(index,'P');

   flags := def_javadoc_filter_flags;
   pushTgConfigureMenu(menu_handle, flags);

   // Show menu:
   mou_get_xy(auto x,auto y);
   _KillToolButtonTimer();
   status := _menu_show(menu_handle,VPM_RIGHTBUTTON,x-1,y-1);
   _menu_destroy(menu_handle);
}

static void MaybeShowDeprecated()
{
   int wid=_find_control("ctldeprecatedcheck"CURJAVATYPE());
   //wid.p_value=1;
   if (wid) {
      if (wid.p_value) {
         //_find_control("ctldeprecatedframe"CURJAVATYPE).p_visible=0;
         _find_control("ctldeprecated"CURJAVATYPE()).p_visible=true;
      } else {
         _find_control("ctldeprecated"CURJAVATYPE()).p_visible=false;
         //_find_control("ctldeprecatedframe"CURJAVATYPE).p_visible=1;
      }
   }
}
void ctldeprecatedcheck1.lbutton_up()
{
   MODIFIED(1);
   MaybeShowDeprecated();
   p_active_form.jdResizeControls();
   if (p_value) {
      p_next._set_focus();
   }
}
void _javadoc_form.on_resize(bool doMove=false)
{
   if (doMove) return;
   jdResizeControls();
}

static int _setEditorControlMode(int wid)
{
   if (wid.p_object!=OI_EDITOR) {
      return(0);
   }
   wid._SetEditorLanguage("html");
   int editorctl_wid=wid._form_parent();
   wid.p_SoftWrap=editorctl_wid.p_SoftWrap;
   wid.p_SoftWrapOnWord=editorctl_wid.p_SoftWrapOnWord;
   wid.p_encoding=editorctl_wid.p_encoding;
   return(0);
}
static int _checkEditorControlModify(int wid)
{
   if (wid.p_object!=OI_EDITOR) {
      return(0);
   }
   if (wid.p_modify) {
      return(1);
   }
   return((int)wid.p_modify);
}
void ctlok.on_create()
{
   int editorctl_wid=_form_parent();
   /*
   Determine the Java type to start with


   */
   _for_each_control(p_active_form,_setEditorControlMode,'H');
   ctlsee1._SetEditorLanguage(_form_parent().p_LangId);
   ctlsee2._SetEditorLanguage(_form_parent().p_LangId);
   ctlsee3._SetEditorLanguage(_form_parent().p_LangId);
   ctlsee1.p_window_flags |=VSWFLAG_NOLCREADWRITE;
   ctlsee2.p_window_flags |=VSWFLAG_NOLCREADWRITE;
   ctlsee3.p_window_flags |=VSWFLAG_NOLCREADWRITE;
   ctlexception3._SetEditorLanguage("html");
   ctlexample3._SetEditorLanguage("html");

   _str buf_name=editorctl_wid.p_buf_name;
   if (buf_name!="") {
      p_active_form.p_caption=p_active_form.p_caption": "buf_name;
   }

   // make sure that the context doesn't get modified by a background thread.
   se.tags.TaggingGuard sentry;
   sentry.lockContext(false);
   editorctl_wid._UpdateContext(true);

   cb_prepare_expand(p_active_form,ctltree1,TREE_ROOT_INDEX);
   ctltree1._TreeBeginUpdate(TREE_ROOT_INDEX,"",'T');
   tag_tree_insert_context(ctltree1,TREE_ROOT_INDEX,
                           def_javadoc_filter_flags,
                           1,1,0,0);
   ctltree1._TreeEndUpdate(TREE_ROOT_INDEX);
   ctltree1._TreeSizeColumnToContents(0);

   typeless p;
   editorctl_wid.save_pos(p);
   editorctl_wid.p_col=1;
   editorctl_wid._clex_skip_blanks();
   EditorLN := editorctl_wid.p_RLine;
   current_id := editorctl_wid.tag_current_context();
   nearest_id := editorctl_wid.tag_nearest_context(EditorLN, def_javadoc_filter_flags, true);
   if (nearest_id > 0 && current_id != nearest_id && editorctl_wid._in_comment()) {
      current_id = nearest_id;
   }

   nearIndex := -1;
   line_num := 0;
   editorctl_wid.restore_pos(p);
   if (current_id>0) {
      tag_get_detail2(VS_TAGDETAIL_context_line, current_id, line_num);
      nearIndex=ctltree1._TreeSearch(TREE_ROOT_INDEX,"",'T',line_num);
   }
   if (nearIndex <= 0) {
      _config_modify_flags(CFGMODIFY_DEFVAR);
      def_javadoc_filter_flags= SE_TAG_FILTER_ANYTHING;
      _javadoc_refresh_proctree();
      if (ctltree1._TreeCurIndex()<=0 || CURJAVATYPE()=="") {
         nearIndex= ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
         if (nearIndex<0) {
            //p_active_form._delete_window();
            jdHideAll();
            ctltagcaption.p_caption="No symbol selected, check filtering options.";
            return;
         }
         ctltree1.call_event(CHANGE_SELECTED,nearIndex,ctltree1,ON_CHANGE,'W');
      }
      return;
   }
   if (ctltree1._TreeCurIndex()!=nearIndex) {
      ctltree1._TreeSetCurIndex(nearIndex);
   } else {
      ctltree1.call_event(CHANGE_SELECTED,nearIndex,ctltree1,ON_CHANGE,'W');
   }

}
void _javadoc_form.on_load()
{
   int wid=_find_control("ctldescription"CURJAVATYPE());
   if (wid) {
      wid._set_focus();
   }
}
void ctlok.on_destroy()
{
   if (TIMER_ID()!="") {
      _kill_timer(TIMER_ID());
   }
}

int _OnUpdate_edit_doc_comment(CMDUI &cmdui,int target_wid,_str command)
{
   if (!_haveContextTagging()) {
      if (cmdui.menu_handle) {
         _menu_delete(cmdui.menu_handle,cmdui.menu_pos);
         _menuRemoveExtraSeparators(cmdui.menu_handle,cmdui.menu_pos);
         return MF_DELETED|MF_REQUIRES_PRO;
      }
      return MF_GRAYED|MF_REQUIRES_PRO;
   }

   if (!target_wid || !target_wid._isEditorCtl() || target_wid.p_readonly_mode) {
      return(MF_GRAYED);
   }

   int enabled=_OnUpdate_javadoc_comment(cmdui,target_wid,command);
   key_name := "";
   caption := "";
   mf_flags := 0;
   if (cmdui.menu_handle) {
      _menu_get_state(cmdui.menu_handle,cmdui.menu_pos,mf_flags,'p',caption);
      parse caption with \t key_name;
      if (target_wid._LanguageInheritsFrom("xmldoc") || commentwrap_inXMLDoc()) {
         _menu_set_state(cmdui.menu_handle,cmdui.menu_pos,mf_flags,'p',"Edit XML Comment\t"key_name);
      } else if (target_wid._inJavadoc(true)) {
         _menu_set_state(cmdui.menu_handle,cmdui.menu_pos,mf_flags,'p',"Edit Javadoc Comment\t"key_name);
      } else {
         _menu_set_state(cmdui.menu_handle,cmdui.menu_pos,mf_flags,'p',"Edit Documentation Comment\t"key_name);
      }
   }
   return(enabled);
}

// Detects comment editor from comments
_command void edit_doc_comment() name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveContextTagging()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Documentation comment editor");
      return;
   }
   VSCodeHelpCommentFlags comment_flags=0;
   orig_comment := "";
   return_type := "";
   line_prefix := "";
   doxygen_comment_start := "";
   int blanks:[][];
   int status=_GetCurrentCommentInfo(comment_flags,orig_comment,return_type,line_prefix,blanks,doxygen_comment_start);
   if (comment_flags==0) {
      if (line_prefix=="" && doxygen_comment_start=="" && _is_xmldoc_preferred()) {
         comment_flags|=VSCODEHELP_COMMENTFLAG_XMLDOC;
      }
   } else if (line_prefix == "///" && _is_xmldoc_supported()) {
      comment_flags|=VSCODEHELP_COMMENTFLAG_XMLDOC;
   }
   if (comment_flags & VSCODEHELP_COMMENTFLAG_XMLDOC) {
      xmldoc_editor();
      return;
   }
   javadoc_editor();
}

int _OnUpdate_javadoc_editor(CMDUI &cmdui,int target_wid,_str command)
{
   if (!_haveContextTagging()) {
      if (cmdui.menu_handle) {
         _menu_delete(cmdui.menu_handle,cmdui.menu_pos);
         return MF_DELETED|MF_REQUIRES_PRO;
      }
      return MF_GRAYED|MF_REQUIRES_PRO;
   }

   return _OnUpdate_javadoc_comment(cmdui,target_wid,command);
}

_command void javadoc_editor(_str deprecate="") name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveContextTagging()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Javadoc Editor");
      return;
   }
   if (p_active_form.p_name == "_javadoc_form" || p_active_form.p_name=="_xmldoc_form") {
      return;
   }
   // get the multi-line comment start string
   _str slcomment_start;
   _str mlcomment_start;
   _str mlcomment_end;
   javadocSupported := false;
   if (get_comment_delims(slcomment_start,mlcomment_start,mlcomment_end,javadocSupported) || !javadocSupported) {
      _message_box("JavaDoc comment not supported for this file type");
      return;
   }
   show("-xy -modal _javadoc_form");
}

static void jdcmd_maybe_deselect_command(typeless pfn)
{
   if (!in_cua_select) {
      if (select_active()) {
         if ( _select_type("","U")!="P") {
            _deselect();
         }
      }
   }
   (*pfn)();
}
static void jdcmd_rubout()
{
   if(jdmaybe_delete_selection()) return;
   _rubout();
}
static void jdcmd_linewrap_rubout()
{
   if(jdmaybe_delete_selection()) return;
   if (p_col!=1) {
      _rubout();
      return;
   }
   save_pos(auto p);
   up();
   if (_lineflags()& HIDDEN_LF) {
      restore_pos(p);
      return;
   }
   down();
   linewrap_rubout();
}
static void jdcmd_delete_char()
{
   if(jdmaybe_delete_selection()) return;
   _delete_char();
}
static void jdcmd_linewrap_delete_char()
{
   if(jdmaybe_delete_selection()) return;
   if (p_col<=_text_colc()) {
      _delete_char();
      return;
   }
   save_pos(auto p);
   down();
   if (_lineflags()& HIDDEN_LF) {
      restore_pos(p);
      return;
   }
   up();
   linewrap_delete_char();
}
static void jdcmd_cua_select()
{
   in_cua_select=true;
   cua_select();
   in_cua_select=false;
}

static void jdcmd_cut_line()
{
   jdmaybe_delete_selection();
   cut_line();
   if (_lineflags()& HIDDEN_LF) {
      up();insert_line("");
      _lineflags(0,HIDDEN_LF);
   }
}
static void jdcmd_delete_line()
{
   jdmaybe_delete_selection();
   _delete_line();
   if (_lineflags()& HIDDEN_LF) {
      up();insert_line("");
      _lineflags(0,HIDDEN_LF);
   }
}
static void jdcmd_join_line()
{
   save_pos(auto p);
   down();
   if (_lineflags()& HIDDEN_LF) {
      restore_pos(p);
      return;
   }
   join_line();
}
static void jdcmd_cut_end_line()
{
   if(jdmaybe_delete_selection()) return;
   if (p_col<=_text_colc()) {
      cut_end_line();
      return;
   }
   save_pos(auto p);
   down();
   if (_lineflags()& HIDDEN_LF) {
      restore_pos(p);
      return;
   }
   up();
   cut_end_line();
}
static void jdcmd_erase_end_line()
{
   if(jdmaybe_delete_selection()) return;
   if (p_col<=_text_colc()) {
      erase_end_line();
      return;
   }
   save_pos(auto p);
   down();
   if (_lineflags()& HIDDEN_LF) {
      restore_pos(p);
      return;
   }
   up();
   erase_end_line();
}
defeventtab _javadoc_preview_form;
void _javadoc_preview_form.on_create(_str htmltext,bool isxmldoc=false)
{
   if (isxmldoc) {
      p_active_form.p_caption="XMLDOC Preview";
   }
   ctlminihtml1.p_text=htmltext;

   ctlminihtml1._codehelp_set_minihtml_fonts(
      _default_font(CFG_FUNCTION_HELP),
      _default_font(CFG_FUNCTION_HELP_FIXED));
}
void _javadoc_preview_form.on_resize(bool doMove)
{
   if (doMove) return;
   ctlminihtml1._move_window(0,0,_dx2lx(SM_TWIP,p_client_width),_dy2ly(SM_TWIP,p_client_height));
}
void _javadoc_preview_form.esc()
{
   p_active_form.call_event(defeventtab _ainh_dlg_manager,A_F4,'e');
}

defeventtab _javadoc_format_form;
void ctlok.on_create()
{
   ctlbeautify.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_BEAUTIFY;
   ctlparammin.p_text=def_javadoc_parammin;
   ctlparammax.p_text=def_javadoc_parammax;
   ctlexceptionmin.p_text=def_javadoc_exceptionmin;
   ctlexceptionmax.p_text=def_javadoc_exceptionmax;
   ctlparamalign.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_ALIGN_PARAMETERS;
   ctlexceptionalign.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_ALIGN_EXCEPTIONS;
   ctlreturnalign.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_ALIGN_RETURN;
   ctldeprecatedalign.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_ALIGN_DEPRECATED;
   ctlparamblank.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_BLANK_LINE_AFTER_PARAMETERS;
   ctlparamgroupblank.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_BLANK_LINE_AFTER_LAST_PARAM;
   ctlreturnblank.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_BLANK_LINE_AFTER_RETURN;
   ctlexampleblank.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_BLANK_LINE_AFTER_EXAMPLE;
   ctldescriptionblank.p_value=def_javadoc_format_flags&VSJAVADOCFLAG_BLANK_LINE_AFTER_DESCRIPTION;

   ctlbeautify.call_event(ctlbeautify,LBUTTON_UP,'W');
   ctlparamalign.call_event(ctlparamalign,LBUTTON_UP,'W');
   ctlexceptionalign.call_event(ctlexceptionalign,LBUTTON_UP,'W');
}
static int _disableAll(int wid)
{
   wid.p_enabled=ctlbeautify.p_value!=0;
   return(0);
}
void ctlparamalign.lbutton_up()
{
   p_next.p_enabled=p_next.p_next.p_enabled=p_value!=0;
   int wid=p_next.p_next.p_next;
   wid.p_next.p_enabled=wid.p_next.p_next.p_enabled=p_value!=0;
}

void ctlok.lbutton_up()
{
   int old_def_javadoc_parammin=def_javadoc_parammin;
   int old_def_javadoc_parammax=def_javadoc_parammax;
   int old_def_javadoc_exceptionmin=def_javadoc_exceptionmin;
   int old_def_javadoc_exceptionmax=def_javadoc_exceptionmax;
   int old_def_javadoc_format_flags=def_javadoc_format_flags;

   _macro('m',_macro('s'));
   if(!isinteger(ctlparammin.p_text)) {
      ctlparammin._text_box_error("Invalid integer");
      return;
   }
   if(!isinteger(ctlparammax.p_text)) {
      ctlparammax._text_box_error("Invalid integer");
      return;
   }
   if (ctlparammin.p_text>ctlparammax.p_text) {
      ctlparammin._text_box_error("Minimum must be less or equal to maximum");
      return;
   }
   if(!isinteger(ctlexceptionmin.p_text)) {
      ctlexceptionmin._text_box_error("Invalid integer");
      return;
   }
   if(!isinteger(ctlexceptionmax.p_text)) {
      ctlexceptionmax._text_box_error("Invalid integer");
      return;
   }
   if (ctlexceptionmin.p_text>ctlexceptionmax.p_text) {
      ctlexceptionmin._text_box_error("Minimum must be less or equal to maximum");
      return;
   }
   if(ctlbeautify.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_BEAUTIFY;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_BEAUTIFY;
   }
   def_javadoc_parammin=(int)ctlparammin.p_text;
   def_javadoc_parammax=(int)ctlparammax.p_text;
   def_javadoc_exceptionmin=(int)ctlexceptionmin.p_text;
   def_javadoc_exceptionmax=(int)ctlexceptionmax.p_text;

   if(ctlparamalign.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_ALIGN_PARAMETERS;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_ALIGN_PARAMETERS;
   }
   if(ctlexceptionalign.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_ALIGN_EXCEPTIONS;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_ALIGN_EXCEPTIONS;
   }
   if(ctlreturnalign.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_ALIGN_RETURN;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_ALIGN_RETURN;
   }
   if(ctldeprecatedalign.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_ALIGN_DEPRECATED;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_ALIGN_DEPRECATED;
   }
   if(ctlparamblank.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_BLANK_LINE_AFTER_PARAMETERS;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_BLANK_LINE_AFTER_PARAMETERS;
   }
   if(ctlparamgroupblank.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_BLANK_LINE_AFTER_LAST_PARAM;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_BLANK_LINE_AFTER_LAST_PARAM;
   }
   if(ctlreturnblank.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_BLANK_LINE_AFTER_RETURN;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_BLANK_LINE_AFTER_RETURN;
   }
   if(ctlexampleblank.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_BLANK_LINE_AFTER_EXAMPLE;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_BLANK_LINE_AFTER_EXAMPLE;
   }
   if(ctldescriptionblank.p_value) {
      def_javadoc_format_flags|=VSJAVADOCFLAG_BLANK_LINE_AFTER_DESCRIPTION;
   } else {
      def_javadoc_format_flags&= ~VSJAVADOCFLAG_BLANK_LINE_AFTER_DESCRIPTION;
   }

   if(old_def_javadoc_parammin!=def_javadoc_parammin) {
      _macro_append("def_javadoc_parammin="def_javadoc_parammin";");
   }
   if(old_def_javadoc_parammax!=def_javadoc_parammax) {
      _macro_append("def_javadoc_parammax="def_javadoc_parammax";");
   }
   if(old_def_javadoc_exceptionmin!=def_javadoc_exceptionmin) {
      _macro_append("def_javadoc_exceptionmin="def_javadoc_exceptionmin";");
   }
   if(old_def_javadoc_exceptionmax!=def_javadoc_exceptionmax) {
      _macro_append("def_javadoc_exceptionmax="def_javadoc_exceptionmax";");
   }
   if(old_def_javadoc_format_flags!=def_javadoc_format_flags) {
      _macro_append("def_javadoc_format_flags="def_javadoc_format_flags";");
   }

   _config_modify_flags(CFGMODIFY_DEFVAR);
   p_active_form._delete_window();
}

/**
 * Reflows the current Javadoc style comment using reflow
 * paragraph.
 */
_command void javadoc_reflow() name_info(','VSARG2_REQUIRES_EDITORCTL)
{
   // make sure this is a javaDoc comment
   int start_col = _inJavadoc();
   if (!start_col) {
      message("Not in a Javadoc comment.");
      return;
   }

   // find the beginning and end of the comment
   int first_line,last_line,orig_line=p_line;

   orig_line_data := "";
   get_line(orig_line_data);
   started_at_top_of_comment := orig_line_data=="/**";
   started_at_bottom_of_comment := orig_line_data=="*/";

   _clex_find_start(); first_line = p_line;
   _clex_find_end();   last_line  = p_line;

   // now tune the first line, looking for a paragraph break
   //p_line = first_line;
   p_line = orig_line;
   while (p_line >= first_line) {
      get_line(auto temp_first_line);
      parse temp_first_line with "*" temp_first_line;
      temp_first_line = lowcase(strip(temp_first_line));
      if (temp_first_line=="" || temp_first_line=="*") {
         first_line=p_line+1;
         break;
      }
      if (pos('^<(p|/p|/pre|/ul|/ol|/dl|li|dt|dd|/blockquote)[ >]',temp_first_line,1,'r') || substr(temp_first_line,1,1)=="@") {
         first_line=p_line;
         break;
      }
      up();
   }

   // now tune the last line, looking for a paragraph break
   //p_line = first_line;
   line := "";
   p_line = orig_line;
   while (p_line <= last_line) {
      get_line(line);
      parse line with "*" line;
      line = lowcase(strip(line));
      if (line=="" || line=="/" || line=="*/") {
         last_line=p_line-1;
         break;
      }
      if (pos('^<(p|/p|pre|ul|ol|dl|li|dt|dd|blockquote)[ >]',line,1,'r') || substr(line,1,1)=="@") {
         last_line=p_line;
         break;
      }
      down();
   }

   // Delete the leading '*'
   p_line=first_line;
   while (p_line <= last_line) {
      p_col = start_col;
      if (get_text()=="*") {
         delete_char();
      }
      down();
   }

   // insert fake blank lines to keep format paragraph in check
   p_line = last_line;
   insert_line("");
   p_line = first_line-1;
   insert_line("");
   p_line = orig_line+1;

   // Want to be sure that we are touching the text when we call reflow_fundamental
   // In border cases, setting p_line to orig_line will not work, so we need these
   // tweaks
   if ( started_at_top_of_comment ) {
      down();
   }else if (started_at_bottom_of_comment) {
      up();
   }

   // adjust the margins for the start column
   _str orig_margins=p_margins;
   typeless leftmargin="";
   typeless rightmargin="";
   rest := "";
   parse p_margins with leftmargin rightmargin rest;
   p_margins=leftmargin" "(rightmargin-start_col-1)" "rest;

   // now reflow the paragraph and find out how many lines
   // were added or removed.
   orig_num_lines := p_Noflines;
   reflow_fundamental();
   int delta_lines=p_Noflines - orig_num_lines;
   last_line += delta_lines;
   p_margins=orig_margins;

   // delete the first blank line
   p_line = first_line;
   get_line(line);
   if (line=="") {
      _delete_line();
   }

   // now put the *'s back in
   while (p_line <= last_line) {
      get_line(line);
      replace_line(indent_string(start_col-1)"* ":+strip(line));
      down();
   }

   // finally, delete the last blank line
   get_line(line);
   if (line=="") {
      _delete_line();
   }
   p_line=orig_line;
}

defeventtab default;


/**
 * Test if the current language supports the given type of doc comment.
 *
 * @param option DocCommentTrigger
 */
static bool have_doc_comment_style(_str option)
{
   return _plugin_has_property(vsCfgPackage_for_Lang(p_LangId),VSCFGPROFILE_DOC_ALIASES,option);
   //lang_doc_comments := LanguageSettings.getDocCommentFlags(p_LangId);
   //return (pos(DocCommentFlagDelimiter:+option:+DocCommentFlagDelimiter, lang_doc_comments) > 0);
}

/**
 * Prompt for user's preferred comment style.
 *
 * @param orig_comment           original comment text
 * @param comment_flags          bitset of VSCODEHELP_COMMETNFLAG_
 * @param slcomment_start        single line comment start delimiter
 * @param mlcomment_start        multiple line comment start delimiter
 * @param doxygen_comment_start  Doxygen style comment start delimiter
 *
 * @return Return 'false' if user cancelled.
 */
static bool prompt_for_doc_comment_style(_str orig_comment, VSCodeHelpCommentFlags &comment_flags, _str &slcomment_start, _str &mlcomment_start, _str &doxygen_comment_start)
{
   if (comment_flags==0) {

      keepStylePrompt := get_message(VSRC_DOC_COMMENT_STYLE_KEEP);
      javadocPrompt   := get_message(VSRC_DOC_COMMENT_STYLE_JAVADOC);
      doxygenPrompt   := get_message(VSRC_DOC_COMMENT_STYLE_DOXYGEN);
      doxygen1Prompt  := get_message(VSRC_DOC_COMMENT_STYLE_DOXYGEN1);
      doxygen2Prompt  := get_message(VSRC_DOC_COMMENT_STYLE_DOXYGEN2);
      xmldocPrompt    := get_message(VSRC_DOC_COMMENT_STYLE_XMLDOC);

      _str commentStyles[];
      int commentOptions[];
      if (orig_comment != "" || slcomment_start != "") {
         commentStyles[commentStyles._length()] = keepStylePrompt;
         commentOptions[commentOptions._length()] = VS_COMMENT_EDITING_FLAG_CREATE_DEFAULT;
      }

      if (is_javadoc_supported()) {
         if (have_doc_comment_style(DocCommentTrigger1)) {
            commentStyles[commentStyles._length()] = javadocPrompt;
            commentOptions[commentOptions._length()] = VS_COMMENT_EDITING_FLAG_CREATE_JAVADOC;
         }
         if (have_doc_comment_style(DocCommentTrigger2)) {
            commentStyles[commentStyles._length()] = doxygenPrompt;
            commentOptions[commentOptions._length()] = VS_COMMENT_EDITING_FLAG_CREATE_JAVADOC|VS_COMMENT_EDITING_FLAG_CREATE_DOXYGEN;
         }
         if (have_doc_comment_style(DocCommentTrigger4)) {
            commentStyles[commentStyles._length()] = doxygen1Prompt;
            commentOptions[commentOptions._length()] = VS_COMMENT_EDITING_FLAG_CREATE_DOXYGEN;
         }
      }
      if (have_doc_comment_style(DocCommentTrigger3)) {
         if (_is_xmldoc_supported()) {
            commentStyles[commentStyles._length()] = xmldocPrompt;
            commentOptions[commentOptions._length()] = VS_COMMENT_EDITING_FLAG_CREATE_XMLDOC;
         } else if (is_javadoc_supported()) {
            commentStyles[commentStyles._length()] = doxygen2Prompt;
            commentOptions[commentOptions._length()] = VS_COMMENT_EDITING_FLAG_CREATE_XMLDOC|VS_COMMENT_EDITING_FLAG_CREATE_DOXYGEN;
         }
      }

      msg := _language_comments_form_get_value("ctl_doc_comment_style", p_LangId);
      choice := 0;
      for (i:=0; i<commentStyles._length(); i++) {
         if (commentStyles[i] == msg) {
            choice = i+1;
            break;
         }
      }

      // if the user does not have a preferred documentation comment format, prompt
      if (choice == 0 && commentStyles._length() > 1) {
         choice = RadioButtons("Select doc comment style",
                                commentStyles, 1, "update_doc_comment.styleconversion",
                               "Do not show these options again.");
         if (choice <= 0) {
            return false;
         }
         // save comment format if they said not to prompt any more
         doNotPrompt := _param1;
         if (doNotPrompt) {
            commentFlags := _GetCommentEditingFlags(0, p_LangId);
            commentFlags &= ~VS_COMMENT_EDITING_FLAG_CREATE_JAVADOC;
            commentFlags &= ~VS_COMMENT_EDITING_FLAG_CREATE_XMLDOC;
            commentFlags &= ~VS_COMMENT_EDITING_FLAG_CREATE_DOXYGEN;
            commentFlags &= ~VS_COMMENT_EDITING_FLAG_CREATE_DEFAULT;
            commentFlags |= commentOptions[choice-1];
            _LangSetProperty(p_LangId, VSLANGPROPNAME_COMMENT_EDITING_FLAGS, commentFlags);
         }
      }

      // keep current formatting?
      if (choice <= 0) {
         return true;
      }
      msg = commentStyles[choice-1];
      if (msg == javadocPrompt) {
         mlcomment_start = CODEHELP_JAVADOC_PREFIX;
         if (_GetCommentEditingFlags(VS_COMMENT_EDITING_FLAG_AUTO_JAVADOC_ASTERISK)) {
            slcomment_start = "*";
         } else {
            slcomment_start = " ";
         }
         comment_flags   = VSCODEHELP_COMMENTFLAG_JAVADOC;
         doxygen_comment_start = mlcomment_start;
      } else if (msg == doxygenPrompt) {
         mlcomment_start = CODEHELP_DOXYGEN_PREFIX;
         if (_GetCommentEditingFlags(VS_COMMENT_EDITING_FLAG_AUTO_JAVADOC_ASTERISK)) {
            slcomment_start = "*";
         } else {
            slcomment_start = " ";
         }
         comment_flags = VSCODEHELP_COMMENTFLAG_DOXYGEN;
         doxygen_comment_start = mlcomment_start;
      } else if (msg == doxygen1Prompt) {
         doxygen_comment_start = CODEHELP_DOXYGEN_PREFIX1;
         comment_flags = VSCODEHELP_COMMENTFLAG_DOXYGEN;
         slcomment_start = "";
      } else if (msg == doxygen2Prompt) {
         doxygen_comment_start = CODEHELP_DOXYGEN_PREFIX2;
         comment_flags = VSCODEHELP_COMMENTFLAG_DOXYGEN;
         slcomment_start = "";
      } else if (msg == xmldocPrompt) {
         doxygen_comment_start = CODEHELP_DOXYGEN_PREFIX2;
         comment_flags = VSCODEHELP_COMMENTFLAG_XMLDOC;
         slcomment_start = CODEHELP_DOXYGEN_PREFIX2;
      } else if (msg == keepStylePrompt) {
         // do nothing
      } else {
         return false;
      }
   }
   return true;
}

/*
int _OnUpdate_update_doc_comment(CMDUI& cmdui, int target_wid, _str command)
{
   if (!target_wid || !target_wid._isEditorCtl() || target_wid.p_readonly_mode) {
      return(MF_GRAYED);
   }

   status := get_comment_delims(auto mlstart, auto mlend, auto supportJD);
   if (status == 0 && supportJD) {
      return MF_ENABLED;
   } else {
      return MF_GRAYED;
   }
}
*/

static _str _orig_item_text:[];
static _str _orig_help_text:[];

int _OnUpdate_update_doc_comment(CMDUI &cmdui,int target_wid,_str command)
{
   word := "";
   enabled := MF_ENABLED;

   if (!target_wid || !target_wid._isEditorCtl() ||!target_wid._istagging_supported() || target_wid.p_readonly_mode) {
      enabled=MF_GRAYED;
   }

   if (target_wid) {
      ldce := find_index('_lang_doc_comments_enabled', PROC_TYPE);
      if (ldce > 0) {
         if (!call_index(target_wid.p_LangId, ldce)) {
            enabled = MF_GRAYED;
         }
      }
   }
   // If there are no doc comment expansions, then this should not be enabled for that language.

   if (p_mdi_child && p_window_state:=='I') {
      enabled=MF_GRAYED;
   }

   command=translate(command,"-","_");
   menu_handle := cmdui.menu_handle;
   button_wid := cmdui.button_wid;
   if (button_wid) {
      return enabled;
   }
   if (target_wid && target_wid.p_object==OI_TREE_VIEW) {
      return enabled;
   }
   if (!target_wid && enabled==MF_GRAYED) {
      return enabled;
   }

   // make sure that the context doesn't get modified by a background thread.
   se.tags.TaggingGuard sentry;
   sentry.lockContext(false);
   _UpdateContext(true);
   save_pos(auto p);
   if (_in_comment()) {
      _clex_skip_blanks();
   }

   context_id := tag_current_context();
   restore_pos(p);
   func_name := "";
   if (context_id > 0) {
      tag_get_detail2(VS_TAGDETAIL_context_type, context_id, auto type_name);
      // are we on a function?
      if (tag_tree_type_is_func(type_name) || tag_tree_type_is_class(type_name) || tag_tree_type_is_data(type_name)) {
         tag_get_detail2(VS_TAGDETAIL_context_name, context_id, func_name);
      }
   }
   if (func_name == "") {
      return MF_GRAYED;
   }
   msg := "";
   if (command=="update-doc-comment") {
      msg=nls("Update Doc Comment for %s ", func_name);
   }
   if (cmdui.menu_handle) {
      if (!_orig_item_text._indexin(command)) {
         _orig_item_text:[command]="";
      }
      keys := text := "";
      parse _orig_item_text:[command] with keys "," text;
      if ( keys!=def_keys || text=="") {
         flags := 0;
         _str new_text;
         typeless junk;
         _menu_get_state(menu_handle,command,flags,'m',new_text,junk,junk,junk,_orig_help_text:[command]);
         if (keys!=def_keys || text=="") {
            text=new_text;
         }
         _orig_item_text:[command]=def_keys","text;
         //message '_orig_item_text='_orig_item_text;delay(300);
      }
      key_name := "";
      parse _orig_item_text:[command] with \t key_name;
      int status=_menu_set_state(menu_handle,
                                 cmdui.menu_pos,enabled,'p',
                                 msg"\t":+key_name,
                                 command,"","",
                                 _orig_help_text:[command]);
   }
   return(enabled);
}

static _str tag_style_for_doxygen(_str commentstart)
{
   // Indirection, since we can't import alias.e
   rv := '\';
   gaf := find_index('get_unexpanded_alias_body', PROC_TYPE);
   gdapn := find_index('getDocAliasProfileName', PROC_TYPE);
   if (gaf > 0 && gdapn > 0) {
      mli := '';
      int origview, tmpview;
      rc := call_index(commentstart, origview, tmpview, mli, call_index(p_LangId, gdapn), gaf);
      if (rc == 0) {
         top();
         save_search(auto s1, auto s2, auto s3, auto s4, auto s5);
         if (search('@param', 'L@') == 0) {
            rv = '@';
         }
         restore_search(s1, s2, s3, s4, s5);
         p_window_id = origview;
         _delete_temp_view(tmpview);
      }
   }

   return rv;
}

/**
 * Update the javadoc or doxygen comment for the current
 * function or method, based on the signature.  If no comment
 * exists for the function, then one is generated.
 *
 * @categories Miscellaneous_Functions
 */
_command void update_doc_comment() name_info(','VSARG2_REQUIRES_MDI_EDITORCTL)
{
   // get the function signature information
   // this call does not work for when you are on the javadoc of a function...would be nice
   // should validate first and last line
   status := _parseCurrentFuncSignature(auto javaDocElements, auto xmlDocElements, auto first_line, auto last_line, auto func_line);
   if (status) {
      return;
   }

   // find the start column of the comment
   start_col := find_comment_start_col(first_line);
   _save_pos2(auto p);
   mlcomment_start := "";
   slcomment_start := "";
   doxygen_comment_start := "";
   int blanks:[][];
   // extract the comment information from the existing comment for this function
   status =_GetCurrentCommentInfo(auto comment_flags,
                                  auto orig_comment,
                                  auto return_type,
                                  slcomment_start, blanks,
                                  doxygen_comment_start);
// say("update_doc_comment: comment_flags="comment_flags);
// say("update_doc_comment: slcommetn_start="slcomment_start);
// say("update_doc_comment: doxygen_comment="doxygen_comment_start);
   if (status) {
      _restore_pos2(p);
      return;
   }

   // should we convert original comment to documentation comment?
   orig_comment_flags   := comment_flags;
   orig_slcomment_start := slcomment_start;
   orig_mlcomment_start := mlcomment_start;
   orig_doxygen_start   := doxygen_comment_start;
   if (!prompt_for_doc_comment_style(orig_comment, comment_flags, slcomment_start, mlcomment_start, doxygen_comment_start)) {
      return;
   }

   // no comment at all, then create one
   if (is_javadoc_supported() && orig_comment == "" && orig_slcomment_start == "" && orig_comment_flags == 0 && orig_doxygen_start=="") {
      goto_line(func_line);
      if (doxygen_comment_start == "") {
         if (_is_xmldoc_preferred()) {
            doxygen_comment_start = DocCommentTrigger3;  // XML Doc
         } else {
            doxygen_comment_start = DocCommentTrigger1;  // Javadoc
         }
      }
      _EmbeddedCall(_document_comment,doxygen_comment_start,comment_flags);
      return;
   }

   // check the flags for the start of the comment
   isDoxygen := false;
   if ((comment_flags & VSCODEHELP_COMMENTFLAG_DOXYGEN) != 0) {
      mlcomment_start = doxygen_comment_start;
      isDoxygen = true;
   } else if (comment_flags & VSCODEHELP_COMMENTFLAG_JAVADOC) {
      mlcomment_start = CODEHELP_JAVADOC_PREFIX;
   } else if (comment_flags & VSCODEHELP_COMMENTFLAG_XMLDOC) {
      //mlcomment_start = CODEHELP_DOXYGEN_PREFIX2;
      mlcomment_start = "";
   }

   // the following code doesn't support XMLDOC comments, so bring up the
   // XMLDOC editor instead.
   if (slcomment_start == "///" && (comment_flags & VSCODEHELP_COMMENTFLAG_XMLDOC)) {
      _xmldoc_update_doc_comment(orig_comment, xmlDocElements, start_col, first_line, last_line);
      _restore_pos2(p);
      return;
   }

   // loop through blanks until we find a blank line, so we know if blanks are used in the comment
   typeless element;
   haveBlanks := false;
   for (element._makeempty();!haveBlanks;) {
      blanks._nextel(element);
      if(element._isempty()) break;
      i := 0;
      for (i = 0; i < blanks:[element]._length(); i++) {
         if (blanks:[element][i] > 0 && element != "") {
            haveBlanks = true;
            break;
         }
      }
   }
   _str commentElements:[][];
   _str tagList[];
   description := "";
   // parse information from the existing javadoc comment into hashtables
   //_parseJavadocComment(orig_comment, description, commentElements, tagList, false, isDoxygen, auto tagStyle, false);
   tagStyle := '';
   if (isDoxygen) {
      // Doxygen has the choice of two tag styles.  tag_tree_parse_javadoc_comment() will return whatever
      // style it encounters in the comment.  The special case is when there are no tags in the comment.  When
      // this happens, tag_tree_parse_javadoc_comment() will return whatever was passed in as the 'tagStyle'
      // (or a default of \\ if tagStyle is an empty string).  For this special case, we want to use the tag style
      // used in the doc comment expansion as the default tag style.
      tagStyle = tag_style_for_doxygen((mlcomment_start == '') ? slcomment_start : mlcomment_start);
   }
   tag_tree_parse_javadoc_comment(orig_comment, description, tagStyle, commentElements, tagList, false, isDoxygen, false);
   // nuke the original comment lines (if there were any)
   num_lines := last_line-first_line+1;
   if (num_lines > 0 && !(orig_comment == "" && orig_slcomment_start == "" && orig_comment_flags == 0 && orig_doxygen_start=="")) {
      p_line=first_line;
      int i;
      for (i=0; i<num_lines; i++) {
         // check if javadoc comment has leading asterisks
         if (slcomment_start=="" && (mlcomment_start == "/**" || mlcomment_start == "/*!")) {
            _first_non_blank();
            if (get_text(2) == "* ") slcomment_start = "*";
         }
         _delete_line();
      }
   }
   // put us where we need to be
   p_line=first_line-1;
   mlcomment_end := "";
   // get the ending of the comment (this should probably be parsed instead of using get_comment_delims)
   get_comment_delims(auto sl_delim,auto ml_delim, mlcomment_end);
   if (mlcomment_start == "") mlcomment_start = ml_delim;
   if (slcomment_start == ml_delim && slcomment_start != sl_delim) slcomment_start = "";
   if (mlcomment_start == "" && slcomment_start == "") slcomment_start = sl_delim;
   if (isDoxygen) {
      if (mlcomment_start == "//!") {
         mlcomment_end = "//!";
      } else if (mlcomment_start == "///") {
         mlcomment_end = "///";
      }
   }
   // add the start of the comment
   if (mlcomment_start!="") {
      if (!isDoxygen || (mlcomment_start != "///" && mlcomment_start != "//!")) {
         insert_line(indent_string(start_col-1):+mlcomment_start);
      }
      if (slcomment_start != "") {
         slcomment_start=" "slcomment_start;
      }
   }
   i := 0;

   // To be consistent with how multiline comments without borders are beautified,
   // the body of the comment is indented as if there was a single space as the left
   // border.  That way, the tags in a borderless doc comment don't look sunken into
   // the edge of the comment start and end.
   lborder := (slcomment_start == '' && mlcomment_start != '') ? '  ' : slcomment_start;
   prefix := indent_string(start_col-1):+lborder:+" ";
   // possibly adjust prefix
   leadingBlank := 1;
   if (isDoxygen && (mlcomment_start == "//!" || mlcomment_start == "///")) {
      // safety check for start_col - 2 to not be neg?
      prefix=indent_string(start_col-1):+mlcomment_start:+" ";
      leadingBlank = 0;
   }
   // maybe add leading blank lines before description
   if (isinteger(blanks:["leading"][0])) {
      for (i = 0; i < blanks:["leading"][0] - leadingBlank; i++) {
         insert_line(prefix);
      }
   }
   haveBrief := false;
   for (i = 0; i < tagList._length() && !haveBrief; i++) {
      if (tagList[i] == "brief") {
         haveBrief = true;
      }
   }
// say("prefix="prefix);
   // maybe add the description
   if (!haveBrief) {
      if (description != "") {
         description = stranslate(description, "\n", "\r\n", 'r');
         split(description, "\n", auto descArray);
         for (i = 0;i < descArray._length();i++) {
            if (strip(descArray[i]) != "") {
               insert_line(prefix:+descArray[i]);
            }
         }
         // add any blanks after the description
         if (isinteger(blanks:[""]._length()) && isinteger(blanks:[""][0])) {
            for (i = 0; i < blanks:[""][0]; i++) {
               insert_line(prefix);
            }
         }
      } else if (blanks._isempty()) {
         // leave room for the yet-to-be-written description
         insert_line(prefix);
      }
   }
   // insert javadoc tags in the order they were originally
   insert_javadoc_elements(prefix, commentElements, blanks, isDoxygen, tagList, javaDocElements, haveBlanks, tagStyle);
   // add the end of the comment
   if (mlcomment_start!="") {
      if (!isDoxygen || (mlcomment_start != "//!" && mlcomment_start != "///")) {
         if (slcomment_start == '') {
            // Another special case for borderless comments. We don't want to indent
            // the closing as if we were lining up the * with a border that isn't there.
            insert_line(mlcomment_end);
         } else {
            insert_line(indent_string(start_col):+mlcomment_end);
         }
      }
   }
   _restore_pos2(p);
}

/**
 * Find the first column of the beginning of a commment.
 *
 * @param first_line
 *
 * @return Starting column of current comment, or -1 if unsuccessful.
 */
int find_comment_start_col(int first_line){
   if (!_isEditorCtl()){
      return -1;
   }
   save_pos(auto p);
   goto_line(first_line);
   _first_non_blank();
   status := _clex_find_start();
   if (!status) {
      start_col := p_col;
      restore_pos(p);
      return start_col;
   }
   restore_pos(p);
   return -1;
}

/**
 * Insert all javadoc elements of a certain tag into a comment.
 *
 * @param prefix
 * @param sigElements
 * @param tag
 * @param comElements
 * @param blanks
 * @param haveBlanks
 */
static void insert_javadoc_element_from_signature(_str prefix, _str sigElements:[][], _str tag,
   _str comElements:[][], int blanks:[][], bool haveBlanks, bool isDoxygen, _str tagStyle)
{
   i := k := j := 0;
   _str params:[];
   params._makeempty();
   _str unmatchingDescs[];
   if (tag == "param") {
      // for each param element extracted from the existing comment...
      for (k = 0; k < comElements:[tag]._length(); k++) {
         split(strip(comElements:[tag][k])," ", auto commmentTokens);
         // stripping possible EOL char off of what we grabbed from the comment...could do this beforehand?
         if (commmentTokens._length() > 1) {
            commmentTokens[0] = stranslate(commmentTokens[0],'','\n','R');
            usingComment := false;
            for (i = 0; i < sigElements:[tag]._length(); i++) {
               newComment := strip(sigElements:[tag][i]);
               if (commmentTokens[0] == newComment) {
                  usingComment = true;
                  break;
               }
            }
            // unneeded nullcheck here?
            if (!usingComment && commmentTokens != null) {
               description := "";
               for (j = 1; j < commmentTokens._length(); j++) {
                  description :+= " "commmentTokens[j];
               }
               // couldn't find a match for this description? save it
               unmatchingDescs[k] = description;
            } else {
               unmatchingDescs[k] = "";
            }
         }
      }
   }

   // calculate parameter name alignment
   param_width := 0;
   if (tag == "param") {
      param_width = def_javadoc_parammin;
      foreach (auto el in comElements:[tag]) {
         parse el with auto name .;
         if (length(name) > param_width) {
            param_width = min(length(name), def_javadoc_parammax);
         }
      }
   } else if (tag == "exception") {
      param_width = def_javadoc_exceptionmin;
      foreach (auto el in comElements:[tag]) {
         parse el with auto name .;
         if (length(name) > param_width) {
            param_width = min(length(name), def_javadoc_exceptionmax);
         }
      }
   }

   blanksAfterLast := -1;
   // for each comment element of type 'tag' extracted from the function signature..
   for (i = 0; i < sigElements:[tag]._length(); i++) {
      newComment := strip(sigElements:[tag][i]);
      if (tag == "return") {
         if(newComment == "void") {
            // no return value...don't insert anything
            return;
         }
         newComment = "";
      }
      foundExisting := false;
      constructedDescription := false;
      // for each element of type "tag" extracted from the existing comment...
      for (k = 0; k < comElements:[tag]._length(); k++) {
         split(comElements:[tag][k]," ", auto commentTokens);
         if (commentTokens != null && commentTokens._length() > 0){
            // stripping possible EOL char off of what we grabbed from the comment...could do this beforehand?
            // we've already done this for params...
            commentTokens[0] = stranslate(commentTokens[0],'','\n','R');
            // is the first token the same as the new comment that would be generated
            // from the function signature?
            if (tag == "param" && params:[newComment] != null && params:[newComment] != "") {
               newComment :+= params:[newComment];
               foundExisting = true;
               constructedDescription = true;
               break;
            } else if (commentTokens[0] == newComment) {
               // if so, keep the already existing comment element, instead of replacing it
               newComment = comElements:[tag][k];
               foundExisting = true;
               constructedDescription = true;
               break;
            } else if (tag == "return" && commentTokens[0] != "") {
               // this is good unless the return type has changed...
               newComment = comElements:[tag][k];
               break;
            }
         }
      }
      // if we checked this signature element against each element in the comments, and didn't find
      // an appropriate description, see if we saved one from before that is in the same position
      if (!constructedDescription && tag == "param" && i < unmatchingDescs._length() && unmatchingDescs[i] != "") {
         newComment :+= unmatchingDescs[i];
         foundExisting = true;
      }
      numBlanks := 0;
      if (!foundExisting) {
         numBlanks = blanksForNewElement(blanks,tag,haveBlanks);
         // are we on the last element? check our value for "blanks after last occurrence"
         if (i == sigElements:[tag]._length() - 1) {
            if (blanksAfterLast >= 0) {
               numBlanks = blanksAfterLast;
            } else if (isinteger(blanks:[tag][i])) {
               // if blanksAfterLast isn't set here, that means the last item has been changed so we haven't
               // gotten to what was the previous last item...so check that one
               numBlanks = (int)blanks:[tag][i];
            }
         }
      } else if (isinteger(blanks:[tag][i])) {
         numBlanks = (int)blanks:[tag][i];
         // if there is a blank after this line BUT it is the last occurrence of this tag
         // that we found in the existing comment AND there are more occurences of this tag
         // to add from the function signature
         if (numBlanks > 0 && i == blanks:[tag]._length()-1 && i < sigElements:[tag]._length()-1) {
            // save this number of blanks for later
            blanksAfterLast = numBlanks;
            foundBlank := false;
            // check to see if there are blanks after at least one of the other occurrences of this tag
            m := 0;
            for (m = 0; m < i; m++) {
               if (isinteger(blanks:[tag][m]) && (int)blanks:[tag][m] > 0) {
                  foundBlank = true;
                  break;
               }
            }
            // no other blanks used between occurrences of this tag...don't insert a blank
            if (!foundBlank) {
               numBlanks = 0;
            }
         } else if (numBlanks == 0 && i == sigElements:[tag]._length()-1) {
            if (isinteger(blanks:[tag][blanks:[tag]._length()-1])) {
               numBlanks = (int)blanks:[tag][blanks:[tag]._length()-1];
            }
         }
      }
      // insert each line of the comment element...followed by the appropriate number of blank lines
      write_javadoc_element(newComment, prefix, tag, isDoxygen, tagStyle, param_width);
      for (j = 0; j < numBlanks; j++) {
         insert_line(prefix);
      }
   }
}

/**
 * Find the number of blanks that should be added after we add the javadoc tag
 * to a function comment.
 *
 * @param blanks
 * @param tag
 * @param haveBlanks
 *
 * @return number of blanks to be inserted after the javadoc element
 */
static int blanksForNewElement(int blanks:[][], _str tag, bool haveBlanks)
{
   i := 0;
   totalBlanks := 0;
   if (blanks:[tag]._length() == 0) {
      // no tags of this type in the comment...if they are using blanks just add one in
      // this could be improved
      return haveBlanks ? 1 : 0;
   } else {
      // see how many blanks are added after each tag of this type...if it's not consistent
      // then just take an average
      for (i = 0; i < blanks:[tag]._length(); i++) {
         totalBlanks += blanks:[tag][i];
      }
      return totalBlanks == 0 ? 0 : floor(totalBlanks/blanks:[tag]._length());
   }
}

/**
 * Insert all non-standard javadoc tags into the function comment.
 *
 * @param prefix
 * @param commentElements
 * @param blanks
 * @param isDoxygen
 * @param tagList
 * @param sigElements
 * @param haveBlanks
 */
static void insert_javadoc_elements(_str prefix, _str commentElements:[][], int blanks:[][],
   bool isDoxygen, _str tagList[], _str sigElements:[][], bool haveBlanks, _str tagStyle)
{
   k := 0;
   bool doneElementFromSig:[];
   doneElementFromSig._makeempty();
   curTag := "";
   for (k = 0; k < tagList._length(); k++) {
      curTag = tagList[k];
      // if this tag is not one that we extract from the function signature
      if (!pos(curTag,JAVADOC_TAGS_FROM_SIG) && commentElements:[curTag] != null) {

         // calculate parameter name alignment
         param_width := 0;
         if (curTag == "param") {
            param_width = def_javadoc_parammin;
            foreach (auto el in commentElements:[curTag]) {
               parse el with auto name .;
               if (length(name) > param_width) {
                  param_width = min(length(name), def_javadoc_parammax);
               }
            }
         } else if (curTag == "exception") {
            param_width = def_javadoc_exceptionmin;
            foreach (auto el in commentElements:[curTag]) {
               parse el with auto name .;
               if (length(name) > param_width) {
                  param_width = min(length(name), def_javadoc_exceptionmax);
               }
            }
         }

         for (i := 0; i < commentElements:[curTag]._length(); i++) {
            // insert each line of the comment element, along with any blank lines
            write_javadoc_element(strip(commentElements:[curTag][i]), prefix, curTag, isDoxygen, tagStyle, param_width);
            if (isinteger(blanks:[curTag][i])) {
               for (j := 0; j < blanks:[curTag][i]; j++) {
                  insert_line(prefix);
               }
            }
         }
      } else if (pos(curTag,JAVADOC_TAGS_FROM_SIG) && !doneElementFromSig:[curTag]) {
         insert_javadoc_element_from_signature(prefix, sigElements, curTag, commentElements, blanks, haveBlanks,
            isDoxygen, tagStyle);
         doneElementFromSig:[curTag] = true;
      }
   }
   parse JAVADOC_TAGS_FROM_SIG with curTag "," auto rest;
   // the loop on tagList will only cover the elements which existed in the original doc comment,
   // so we want to now loop over any elements which we extracted from the function signature and
   // didn't exist in the original comment
   while (curTag != "") {
      if (!doneElementFromSig:[curTag]) {
         insert_javadoc_element_from_signature(prefix, sigElements, curTag, commentElements, blanks, haveBlanks,
            isDoxygen, tagStyle);
      }
      parse rest with curTag "," rest;
   }
}

/**
 * Print a javadoc element into the current editor control.
 * 
 * @param element
 * @param pre    
 * @param tag    
 * @param isDoxygen     
 * @param tagStyle      
 * @param param_width   
 */
static void write_javadoc_element(_str element, _str pre, _str tag, bool isDoxygen, _str tagStyle, int param_width=0)
{
   tagprefix := tagStyle;
   if (tag == "return" && element == "") {
      insert_line(pre:+tagprefix:+tag);
      return;
   }

   if (element == '' && tag != '') {
      // An empty tag element shouldn't be removed as if it were a blank line.
      insert_line(pre:+tagprefix:+tag);
   } else {
      element = stranslate(element, "\n", "\r\n", 'r');
      split(element, "\n", auto elementLines);

      foreach (auto j => auto el in elementLines) {
         // we should not be inserting blank lines here
         // that is the job of the blanks hashtable.
         line := el;
         if (param_width > 0) {
            parse el with auto name auto rest;
            if (length(name) < param_width) {
               line = name :+ substr("", 1, param_width+1-length(name)) :+ rest;
            }
         }
         if (el != "" || j == 0 || (el == "" && tag != "")) {
            if (j == 0) {
               insert_line(pre:+tagprefix:+tag" ":+line);
            } else {
               insert_line(pre:+line);
            }
         }
      }
   }
}

