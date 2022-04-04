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
#include "eclipse.sh"
#include "hthelp.sh"
#include "pip.sh"
#include "xml.sh"
#import "about.e"
#import "codehelp.e"
#import "compile.e"
#import "context.e"
#import "dlgman.e"
#import "doscmds.e"
#import "html.e"
#import "listbox.e"
#import "main.e"
#import "optionsxml.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "tags.e"
#import "treeview.e"
#import "util.e"
#import "math.e"
#import "xmldoc.e"
#import "cfg.e"
#import "picture.e"
#import "search.e"
#import "mprompt.e"
#require "se/lang/api/LanguageSettings.e"
#endregion

const HELP_ACTION_TYPE_URL="URL";
//const HELP_ACTION_TYPE_FILE="File";
const HELP_ACTION_TYPE_PROFILE="Profile";
const HELP_ACTION_TYPE_SLICKC="Slick-C";
//const HELP_ACTION_TYPE_EXTERNAL="External";
const HELP_ACTION_TYPE_INTERNET_SEARCH="Internet search";
const HELP_ACTION_TYPE_STOP="Stop";

const HELP_DEFAULT_PROFILE='Default';

_str def_search_engine="Google";
_str def_apihelp_default_profile='Default';

struct HelpURLInfo { 
   bool m_enabled;
   _str m_match_word;
   _str m_match_class;
   _str m_flags;
   /* Warning, when m_action_type==HELP_ACTION_TYPE_FILE
      the filename is stored in the
      property name attribute ("n") and not the "action"
      attribute.
   */
   _str m_action_type;
   _str m_action;
   int m_position;
};
static init_helpurlinfo(HelpURLInfo &info) {
   info.m_enabled=true;
   info.m_match_class='^?@$';
   info.m_match_word='^?@$';
   info.m_flags='regex class_regex';
   info.m_action_type=HELP_ACTION_TYPE_URL;
   info.m_action='';
}

using se.lang.api.LanguageSettings;
static _str help_class_number;
static _str help_class_type;

_str def_bottom_border;
_str _retrieve;

#if 1 /* __PCDOS__ */
// No longer used, kept for backwards compatibility
_str def_msdn_coll;
#endif 

/**
 * Displays <i>message_text</i> in message box with an information 
 * icon displayed to the left of the message.  This function is typically 
 * used to display help information messages.
 * 
 * @param string     message to display
 * 
 * @see popup_message
 * @see _message_box
 * @see help
 * @see message
 * @see messageNwait
 * @see sticky_message
 * @see clear_message
 * 
 * @categories Miscellaneous_Functions
 * 
 */ 
_command void popup_imessage(_str string="")
{
   popup_message(string,MB_OK|MB_ICONINFORMATION);
}
/**
 * Displays <i>message_text</i> in message box with an exclamation 
 * point displayed to the left of the message.  Use the new and more 
 * powerful <b>_message_box</b> function instead of this function.  
 * This function is typically used with the <b>_post_call</b> function to 
 * display an error message box during <b>on_got_focus</b> or 
 * <b>on_lost_focus</b> events.
 * 
 * @param string     message to display
 * @param flags      message box flags (MB_*)
 * @param title      message box title
 * 
 * @see popup_imessage
 * @see _message_box
 * @see help
 * @see message
 * @see messageNwait
 * @see sticky_message
 * @see clear_message
 * 
 * @categories Miscellaneous_Functions
 * 
 */ 
_command void popup_message(_str string="", typeless flags="", _str title="")
{
   if (flags==''){
      flags=MB_OK|MB_ICONEXCLAMATION;
   }
   if (title=='') {
      title=editor_name('a');  // Application name
   }
   // Parse off switches
   for (;;) {
      string=strip(string,'L');
      if (substr(string,1,1)!='-'){
         break;
      }
      option := "";
      parse string with option string;
      switch(lowcase(option)){
      case '-title':
         title=strip(parse_file(string),'B','"');
         break;
      }
   }
   _message_box(string,title,flags);
}

/**
 * Displays the message corresponding to error number error_code.
 * Displays the message 
 * get_message 
 */
void popup_nls_message(int error_code, ...)
{
   msg := "";
   switch (arg()) {
   case 1:
      msg = get_message(error_code);
      break;
   case 2:
      msg = get_message(error_code, arg(2));
      break;
   case 3:
      msg = get_message(error_code, arg(2), arg(3));
      break;
   case 4:
      msg = get_message(error_code, arg(2), arg(3), arg(4));
      break;
   case 5:
      msg = get_message(error_code, arg(2), arg(3), arg(4), arg(5));
      break;
   default:
      msg = "Modify popup_get_message() to support more arguments.";
      say(msg);
      break;
   }
   popup_message(msg);
}

/**
 * Launches the help index page.
 * 
 * @param help_file URL of the help index page.  DO make sure that this path
 * is a valid URL in UNIX build e.g. file:///opt/slickedit/.....
 */
static void _help_contents(_str help_file)
{
   typeless status=_syshtmlhelp(help_file);
   _help_error(status,help_file,'');
}

static _str escapeURISpecialChars(_str str,bool doublePercents=false) {
    int i;
    _str result=str;
    for (i=1;i<=length(result);++i) {
       ch := substr(result,i,1);
       if (isalpha(ch) || isdigit(ch) || ch=='_' || ch=='.' || ch=='_' || ch=='~') {
          continue;
       }
       temp := _dec2hex(_asc(ch),16);
       if (length(temp)<1) {
          temp='0'temp;
       }
       if (doublePercents) {
          temp='%%'temp;
       } else {
          temp='%'temp;
       }
       //say('b4 i='i' result='result);
       result=substr(result,1,i-1):+temp:+substr(result,i+1);
       //say('af i='i' result='result);
       i+=length(temp)-1;
    }
    return result;
}

static bool _match_help_word(_str word, _str match_word,_str flags, _str prefix='') {
   re_option:='';
   if (pos(' 'prefix:+'regex ',' 'flags' ')) {
      re_option='r';
   } else if (pos(' 'prefix:+'perlre ',' 'flags' ')) {
      re_option='l';
   }
   ignore_case:='';
   if (pos(' 'prefix:+'ignore_case  ',' 'flags' ')) {
      ignore_case='i';
   }
   if (re_option!='') {
      //say('word='word' mw='match_word' 'match_word_flags' re_option='re_option);
      //say('p='pos(match_word,word,1,re_option:+ignore_case));
      return pos(match_word,word,1,re_option:+ignore_case)>=1;
   }
   if (ignore_case) {
      return strieq(word,match_word);
   }
   return word:==match_word;
}
static void _read_help_info(int handle,int node,HelpURLInfo &info,_str &prev_action,_str &prev_action_type) {

   init_helpurlinfo(info);

   /*info.m_action_type=_xmlcfg_get_attribute(handle,node,'action_type');
   if (info.m_action_type=='') {
      info.m_action_type=HELP_ACTION_TYPE_URL;
   } */

   list:=_xmlcfg_get_attribute(handle,node,VSXMLCFG_PROPERTY_NAME);
   /*list:=_xmlcfg_get_attribute(handle,node,VSXMLCFG_PROPERTY_NAME);
   if (strieq(info.m_action_type,HELP_ACTION_TYPE_PROFILE)) {
      info.m_action=list;
      info.m_match_word='';
      info.m_match_class='';
   }  else {*/
      j := 1;

      _str position=_pos_parse_wordsep(j,list,VSXMLCFG_PROPERTY_SEPARATOR,VSSTRWF_NONE,VSXMLCFG_PROPERTY_ESCAPECHAR);
      if (!isinteger(position)) {
         info.m_position=0;
      } else {
         info.m_position=(int)position;
      }

      info.m_match_word=_pos_parse_wordsep(j,list,VSXMLCFG_PROPERTY_SEPARATOR,VSSTRWF_NONE,VSXMLCFG_PROPERTY_ESCAPECHAR);
      if (info.m_match_word==null) info.m_match_word='';
      info.m_match_class=_pos_parse_wordsep(j,list,VSXMLCFG_PROPERTY_SEPARATOR,VSSTRWF_NONE,VSXMLCFG_PROPERTY_ESCAPECHAR);
      if (info.m_match_class==null) info.m_match_class='';


      info.m_action=_pos_parse_wordsep(j,list,VSXMLCFG_PROPERTY_SEPARATOR,VSSTRWF_NONE,VSXMLCFG_PROPERTY_ESCAPECHAR);
      if (info.m_action==null) info.m_action='';

      info.m_action_type=_pos_parse_wordsep(j,list,VSXMLCFG_PROPERTY_SEPARATOR,VSSTRWF_NONE,VSXMLCFG_PROPERTY_ESCAPECHAR);
      if (info.m_action_type==null) info.m_action_type='';
      if (info.m_action_type=='') {
         info.m_action_type=HELP_ACTION_TYPE_URL;
      }

      if (strieq(info.m_action_type,HELP_ACTION_TYPE_PROFILE) ||
          strieq(info.m_action_type,HELP_ACTION_TYPE_STOP)
          ) {
         info.m_match_word='';
         info.m_match_class='';
      }

      //info.m_action=_xmlcfg_get_attribute(handle,node,'action');

   //}

   info.m_enabled=_xmlcfg_get_attribute(handle,node,'enabled','1')!=0;
   info.m_flags=_xmlcfg_get_attribute(handle,node,'flags');

   if (!strieq(info.m_action_type,HELP_ACTION_TYPE_STOP)) {
      if (info.m_action=='') {
         info.m_action=prev_action;
         info.m_action_type=prev_action_type;
      } else {
         prev_action=info.m_action;
         prev_action_type=info.m_action_type;
      }
   }
}
static int do_help_action(_str action_type,_str action,_str class_name,_str word,bool use_class_as_curword) {
   if (use_class_as_curword && class_name!='') {
      word=class_name;
   }
   set_env('mode-name',escapeURISpecialChars(p_mode_name,true));
   set_env('class-name',escapeURISpecialChars(class_name,true));
   if (strieq(action_type,HELP_ACTION_TYPE_URL) || strieq(action_type,HELP_ACTION_TYPE_INTERNET_SEARCH)) {
      word=escapeURISpecialChars(word,true);
   }
   _str url=_parse_project_command(action,'','',word);
   set_env('mode-name',null);
   set_env('class-name',null);
   int status;
   if (strieq(action_type,HELP_ACTION_TYPE_URL)) {
      status=goto_url(url);
   } else if (strieq(action_type,HELP_ACTION_TYPE_SLICKC)) {
      status=execute(url);
   /*} else if (strieq(action_type,HELP_ACTION_TYPE_EXTERNAL)) {
      status=shell(url,'a');*/
   } else if (strieq(action_type,HELP_ACTION_TYPE_INTERNET_SEARCH)) {
      _str search_term=url;
      url=_plugin_get_property(VSCFGPACKAGE_MISC,VSCFGPROFILE_SEARCH_ENGINES,def_search_engine);
      if (url=='') {
         url=_plugin_get_property(VSCFGPACKAGE_MISC,VSCFGPROFILE_SEARCH_ENGINES,"Google");
      }
      url=stranslate(url,"\1","%%");
      url=stranslate(url,"%c","%s");
      url=stranslate(url,"%%","\1");
      url=_parse_project_command(url,'','',search_term);
      status=goto_url(url);
   } else if (strieq(action_type,HELP_ACTION_TYPE_STOP)) {
      return 0;
   } else {
      status=1;
   }
   return status;
}
static int _run_help_action_xml(int handle,_str class_name,_str word,_str &action_type, _str langId, bool (&already_processed_profile):[]) {
   if (handle<0) {
      return 1;
   }
   profile_node:=_xmlcfg_get_document_element(handle);
   if (profile_node<0) {
      return 1;
   }

   _xmlcfg_sort_on_attribute(handle,profile_node,VSXMLCFG_PROPERTY_NAME,'n');
   node:=_xmlcfg_get_first_child(handle,profile_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
   _str action='';
   action_type='';
   _str prev_action='';
   _str prev_action_type='';
   while (node>=0) {
      HelpURLInfo info;

      _read_help_info(handle,node,info,prev_action,prev_action_type);

      if (info.m_enabled) {
         if (strieq(info.m_action_type,HELP_ACTION_TYPE_PROFILE)) {
            //handle2:=_xmlcfg_open(info.m_action,auto status);
            
            profile_path:=_plugin_append_profile_name(vsCfgPackage_for_LangAPIHelpProfiles(langId),lowcase(info.m_action));
            if (already_processed_profile._indexin(profile_path)) {
               _message_box(nls("Already processed API Help profile '%s'", info.m_action));
               return 0;
            }
            already_processed_profile:[profile_path]=true;
            handle2:=_plugin_get_profile(vsCfgPackage_for_LangAPIHelpProfiles(langId),info.m_action);
            //handle2:=_plugin_get_profile(info.m_action,auto status);
            if (handle2>=0) {
               action=_run_help_action_xml(handle2,class_name,word,action_type,langId,already_processed_profile);
               _xmlcfg_close(handle2);
               if (!action) {
                  return 0;
               }
            }
         } else if (strieq(info.m_action_type,HELP_ACTION_TYPE_STOP)) {
            return 0;
         } else {
            if (info.m_match_word=='') {
               if(_match_help_word(class_name,info.m_match_class,info.m_flags,'class_')) {
                  action_type=info.m_action_type;
                  action=info.m_action;
                  use_class_as_curword:=true;
                  status:=do_help_action(action_type,action,class_name,word,use_class_as_curword);
                  if (!status) return 0;
               } else if(_match_help_word(word,info.m_match_class,info.m_flags,'class_')) {
                  action_type=info.m_action_type;
                  action=info.m_action;
                  use_class_as_curword:=false;
                  status:=do_help_action(action_type,action,class_name,word,use_class_as_curword);
                  if (!status) return 0;
               }
            } else if(_match_help_word(class_name,info.m_match_class,info.m_flags,'class_') && 
               _match_help_word(word,info.m_match_word,info.m_flags)) {
                  action_type=info.m_action_type;
                  action=info.m_action;
                  use_class_as_curword:=false;
                  status:=do_help_action(action_type,action,class_name,word,use_class_as_curword);
                  if (!status) return 0;
            }
         }
      }
      node=_xmlcfg_get_next_sibling(handle,node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
   }
   return 1;
}
int _run_help_action(_str class_name, _str word,_str langId,_str &action_type) {
   _str defaultProfile;
   if (langId=='') {
      defaultProfile=def_apihelp_default_profile;
   } else {
      defaultProfile=_LangGetProperty(langId,VSLANGPROPNAME_APIHELP_DEFAULT_PROFILE);
   }
   if (defaultProfile=='') defaultProfile=HELP_DEFAULT_PROFILE;
   handle:=_plugin_get_profile(vsCfgPackage_for_LangAPIHelpProfiles(langId),defaultProfile);
   if (handle<0) {
      return 1;
   }
   profile_path:=_plugin_append_profile_name(vsCfgPackage_for_LangAPIHelpProfiles(langId),lowcase(defaultProfile));
   bool already_processed_profile:[];
   already_processed_profile:[profile_path]=true;
   result:=_run_help_action_xml(handle,class_name,word,action_type,langId,already_processed_profile);
   _xmlcfg_close(handle);
   return result;
}
int _word_help(_str help_file,_str word,bool ImmediateHelp=false,bool maybeWordHelp=false)
{
   if(isEclipsePlugin()) {
      _eclipse_help(word);
      return 0;
   }
   if(isVisualStudioPlugin()) {
      return 0;
   }

   // currently if maybe_word_help!=0 then help_file must be vslick.hlp
   if (maybeWordHelp && !_isEditorCtl()) {
      _help_contents(help_file);
      return(0);
   }
   if (_isEditorCtl() && word=='' && (
       _file_eq('.'_get_extension(p_buf_name),_macro_ext) ||
       _file_eq('.'_get_extension(p_buf_name),'.sh'))) {
      help_file=_help_filename('');
   }
   allHelpWorkDone := false;
   start_col := 0;
   _str ext=_get_extension(help_file);
   _str class_name='';
   if (word=='') {
      if( _isEditorCtl()) {
         int FunctionHelp_FunctionNameOffset;
         word=_CodeHelpCurWord(allHelpWorkDone,FunctionHelp_FunctionNameOffset);
         if (word!='') {
            // When we are in code help, pressing F1 is like press Ctrl+F1 (word help)
            maybeWordHelp=false;
         }
         if (allHelpWorkDone) {
            return(0);
         }
         typeless p;
         if (word!='') {
            save_pos(p);
            //_GoToROffset
            goto_point(FunctionHelp_FunctionNameOffset);
         } else {
            FunctionHelp_FunctionNameOffset=-1;
         }
         {
            VS_TAG_BROWSE_INFO cm;

            // initialize the symbol to blank
            tag_browse_info_init(cm);

            _UpdateContext(true,true);
            // first try to identify the symbol under the cursor
            status := tag_get_browse_info("", cm, 
                                          quiet:true, 
                                          filterDuplicates:true, 
                                          filterPrototypes:true, 
                                          filterDefinitions:true, 
                                          filterFunctionSignatures:true);
            if (status >= 0 && cm.member_name != "") {

               word=cm.member_name;
               class_name=cm.class_name;
               //say('h1 word='word' class='class_name);

               // evaluate type of local variables and parameters, because
               // looking up a local variable name won't be of much use.
               if (cm.class_name == "" && (cm.type_name == "param" || cm.type_name == "lvar")) {
                  tag_files := tags_filenamea();
                  VS_TAG_RETURN_TYPE visited:[] = null;
                  class_name = _Embeddedget_inferred_return_type_string(auto errorArgs, tag_files, cm, visited);
                  if (class_name == "") class_name = cm.return_type;
                  //say('h2 word='word' class='class_name);
               }

            } else {
#if 0
               // if not found, try for a symbol definition or declaration 
               // under the cursor
               context_id := tag_get_current_context(cm.member_name, 
                                                     cm.flags, 
                                                     cm.type_name, 
                                                     auto dummy_type_id,
                                                     cm.class_name,
                                                     auto cur_class,
                                                     auto cur_package);
               if (context_id > 0) {
                  tag_get_context_info(context_id, cm);
                  word=cm.member_name;
                  class_name=cm.class_name;
                  say('h3 word='word' class='class_name);
               } else {
                  word=cur_word(start_col);
                  say('h4 word='word' class='class_name);
               }
#endif
               word=cur_word(start_col);
               //say('h5 word='word' class='class_name);
            }

            if (class_name!='') {
               tag_browse_info_init(cm);
               cm.member_name=word;
               cm.class_name=class_name:+"\1";
               symbol:=extension_get_decl(p_LangId,cm,VSCODEHELPDCLFLAG_SHOW_CLASS);
               parse symbol with class_name "\1";
            }
         }
         if (FunctionHelp_FunctionNameOffset>=0) {
            restore_pos(p);
         }
      }
      if (word=='') {
         if (_isUnix() || !_file_eq(ext,'idx') ) {
            if (maybeWordHelp) {
               _help_contents(help_file);
               return(0);
            } else {
               message(nls('No word at cursor'));
               return(0);
            }
         }
      }
   }

   typeless status=0;
   if( _isEditorCtl()) {
      if (def_use_word_help_url && word!='') {
         action_type:='';
         if (_run_help_action(class_name,word,p_LangId,action_type) ) {
            _run_help_action(class_name,word,'',action_type);
         }
         return 0;
      }
   }
#if 0
   if( _isEditorCtl() && word!='') {
      _str extension=_get_extension(p_buf_name);
      if ( _file_eq('.'extension,_macro_ext) || _file_eq(extension,'cmd') ||
         (_file_eq(extension,'sh')) ) {
         _str new_keyword=h_match_exact(word);
         if (new_keyword=='') {
            if (maybeWordHelp) {
               _help_contents(help_file);
               return(0);
            }
            _message_box(nls("Help item '%s' not found",word));
            return(STRING_NOT_FOUND_RC);
         }
         word=new_keyword;
         html_keyword_help(_help_filename(''),word);
         return(0);
      }
   }

   if (_isUnix()) {
      if( _isEditorCtl()) {
         status=man(word);
         if (status && maybeWordHelp) {
            _help_contents(help_file);
            return(0);
         }
         return(status);
      } else {
         mou_hour_glass(true);
         int wid=_find_formobj("_unixman_form","n");
         if (wid) {
            _nocheck _control ctlfind;
            _nocheck _control ctleditorctl;
            wid._set_foreground_window();
            wid.ctleditorctl._set_focus();
            wid.ctlfind.call_event(word,1,wid.ctlfind,on_create,"");
            mou_hour_glass(false);
            return(0);
         }
         status=show("-xy -app _unixman_form",word,0);
         mou_hour_glass(false);
         return(status);
      }
   } else {
      if (maybeWordHelp) {
         help_file=_help_filename('');
      }
      if (word=='') {
         _help_contents(help_file);
         return(0);
      }
      status=html_keyword_help(help_file,word,true);
      return(0);
   }
#endif
   return 1;
}

/**
 * SDK word help.
 * 
 * @appliesTo Edit_Window, Editor_Control
 * 
 * @categories Miscellaneous_Functions
 * 
 * @deprecated Use {@link help()} 
 */ 
_command wh(_str word="") name_info(','VSARG2_EDITORCTL|VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
{
   return(_word_help('',word));
}
/**
 * SDK word help.
 * 
 * @appliesTo Edit_Window, Editor_Control
 * 
 * @categories Miscellaneous_Functions
 * 
 * @deprecated Use {@link help()} 
 */ 
_command wh2(_str word="") name_info(','VSARG2_EDITORCTL|VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
{
   return(_word_help('',word));
}

/**
 * SDK word help.
 * 
 * @appliesTo Edit_Window, Editor_Control
 * 
 * @categories Miscellaneous_Functions
 * 
 * @deprecated Use {@link help()} 
 */ 
_command wh3(_str word="") name_info(','VSARG2_EDITORCTL|VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
{
   return(_word_help('',word));
}
_command qh(_str word="") name_info(','VSARG2_ICON|VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL)
{
   if (word=='') {
      junk := 0;
      word=cur_word(junk);
   }
   dos('qh 'word);
}

_str _help_filename(_str file_spec="")
{
   if (file_spec=='') {
      file_spec=_help_file_spec;
   }
   if(file_spec=='') {
      file_spec=_getSlickEditInstallPath():+'help':+FILESEP:+SLICK_HELP_FILE;
      if (!file_exists(file_spec)) {
         // Not sure if this if is needed but keep it for now.
         if (_isUnix()) {
            _message_box(nls("Can't find help file '%s'",SLICK_HELP_FILE));
            //_message_box(nls("Can't find help file '%s",SLICK_HELP_FILE))
         } else {
            _message_box(nls("Can't find help file '%s'",file_spec));
            //_message_box(nls("Can't find help file '%s",SLICK_HELP_FILE))
         }
      }
      if (file_spec!='') {
         _help_file_spec=absolute(file_spec);
         file_spec=_help_file_spec;
      }
      return(file_spec);
   }
   if (pos('+',file_spec)) {
      return(file_spec);
   }
   _str temp=slick_path_search(file_spec,"S");
   if (temp=='') {
      _message_box(nls("Can't find help file '%s'",file_spec));
      return('');
   }
   if (file_spec=='' && temp!='') {
      _help_file_spec=absolute(temp);
   }
   temp=_parse_project_command(temp, '', '', '');
   return(temp);
}
static _str hmpu_sellist_callback(int sl_event,_str &result,_str info)
{
   if (sl_event==SL_ONDEFAULT) {
      // check that the item in the combo box is a valid Slick-C identifier
      result=_sellist._lbget_text();
      _param1=_sellist.p_line-1;
      return(1);
   }
   return('');
}
_str h_match_pick_url(_str name,bool &CrossReferenceMultiplyDefined=false,_str helpindex_filename=SLICK_HELPINDEX_FILE,bool quiet=false,bool justVerifyHaveKeyword=false,int xmlcfg_helpindex_handle= -1)
{
   CrossReferenceMultiplyDefined=false;
   int IndexTopicNodes[];
   filename := "";
   int handle=xmlcfg_helpindex_handle;
   if (handle<0) {
      filename=_getSlickEditInstallPath():+'help':+FILESEP:+helpindex_filename;
      //filename=_maybe_quote_filename(_config_path():+SLICK_HELPLIST_FILE);
      int status;
      handle=_xmlcfg_open(filename,status);
      if (handle<0) {
         if ( handle==FILE_NOT_FOUND_RC ) {
            _message_box(nls("File '%s' not found",filename));
         } else {
            _message_box(nls("Error loading help file '%s'",filename));
         }
         return('');
      }
   }
   
   int key;
   if (pos("'",name)) {
      key=_xmlcfg_find_simple(handle,'/indexdata/key[strieq(@name,"'name'")]');
   } else {
      key=_xmlcfg_find_simple(handle,"/indexdata/key[strieq(@name,'"name"')]");
   }

   if (key<0) {
      if (xmlcfg_helpindex_handle<0) _xmlcfg_close(handle);
      if (!quiet) {
         _message_box(nls("%s1 not found in the help index",name));
      }
      return('');
   }
   return _xmlcfg_get_attribute(handle,key,"url");
#if 0
   _str array[];
   _str array_url[];
   _xmlcfg_find_simple_array(handle,"topic/@name",array,key,VSXMLCFG_FIND_VALUES);
   _xmlcfg_find_simple_array(handle,"topic/@url",array_url,key,VSXMLCFG_FIND_VALUES);
   if (xmlcfg_helpindex_handle<0) _xmlcfg_close(handle);
   if (!array._length()) {
      if (!quiet) {
         _message_box(nls("Error in help file.  No URL's for help index item '%s1'",name));
      }
      return('');
   }
   if (array._length()==1 || justVerifyHaveKeyword ) {
      return(array_url[0]);
   }
   CrossReferenceMultiplyDefined=1;
   
   typeless result=show('-modal _sellist_form',
                        'Choose a Help Topic',
                        SL_DEFAULTCALLBACK|SL_SELECTCLINE, // flags
                        array,   // input_data
                        "OK", // buttons
                        '',   // help item
                        '',   // font
                        hmpu_sellist_callback   // Call back function
                       );
   if (result=='') {
      return('');
   }
   return(array_url[_param1]);
#endif
}

_str h_match_exact(_str name)
{
   view_id := 0;
   get_window_id(view_id);
   activate_window(VSWID_HIDDEN);
   //tname=lowcase(translate(name,'_','-'));
   typeless result=h_match(name,1);
   for (;;) {
      if (result=='') {
          h_match(name,2);
          activate_window(view_id);
          return('');
      }
      if (strieq(name,result) /*lowcase(translate(result,'_','-'))*/) {
          h_match(name,2);
          activate_window(view_id);
          return(result);
      }
      result=h_match(name,0);
   }
}
int gxmlcfg_help_index_handle;
static _str ghm_array[];
static int ghm_i;
_str h_match(_str &name,int find_first)
{
   filename := "";
   tname := lowcase(translate(name,'_','-'));
   if ( find_first ) {
      if ( find_first:==2 ) {
         ghm_array._makeempty();
         return('');
      }
      ghm_array._makeempty();ghm_i=0;
      if (!gxmlcfg_help_index_handle) {
         filename=_getSlickEditInstallPath():+'help':+FILESEP:+SLICK_HELPINDEX_FILE;
         //filename=_maybe_quote_filename(_config_path():+SLICK_HELPLIST_FILE);
         int status;
         int handle=_xmlcfg_open(filename,status);
         if (handle<0) {
            if ( handle==FILE_NOT_FOUND_RC ) {
               _message_box(nls("File '%s' not found",filename));
            } else {
               _message_box(nls("Error loading help file '%s'",filename));
            }
            return('');
         }
         gxmlcfg_help_index_handle=handle;
      }
      _xmlcfg_find_simple_array(gxmlcfg_help_index_handle,"/indexdata/key/@name",ghm_array,TREE_ROOT_INDEX,VSXMLCFG_FIND_VALUES);
      //name=_escape_re_chars(translate(name,"\n\n","-_"));
      //name=stranslate(name,'[\-_]',"\n");
      //status=search('^ ('name'|:ghm_i, 'name')','ri@');
   }
   for (;;) {
      if (ghm_i>=ghm_array._length()) {
         return('');
      }
      if (length(ghm_array[ghm_i])>=length(name) && 
          strieq(tname,substr(translate(ghm_array[ghm_i],'_','-'),1,length(name)))
          ) {
         break;
      }
      ++ghm_i;
   }
   ++ghm_i;
   return(ghm_array[ghm_i-1]);
}
static _help_error(int status,_str in_filenames,_str word)
{
   if (status==STRING_NOT_FOUND_RC) {
      _message_box(nls('No help on %s',word));
      return('');
   }
   if (status==FILE_NOT_FOUND_RC) {
      filename := "";
      _str filenames=in_filenames;
      for (;;) {
         parse filenames with filename '+' filenames ;
         filename=strip(filename,'B');
         if (filename=='') {
            _message_box(nls("File '%s' not found.",in_filenames));
            return('');
         }
         _str ext=_get_extension(filename);
         typeless result=slick_path_search(filename);
         if (result=='') {
            _message_box(nls("File '%s' not found.",filename));
            return('');
         }
      }
   }
}
static _str EmulateHelpItem()
{
   if (def_keys == "vcpp-keys") {
      return "Visual C++ Emulation Keys";
   }
   return longEmulationName(def_keys) :+ " Emulation Keys";
}
static int html_keyword_help(_str filename,_str keyword,bool show_contents_if_keyword_not_found=false)
{
   junk := false;
   name:=_strip_filename(filename,'PE');
   if (name=='slickedit5') {
      name='slickedit';
   }
   index_filename := name:+"index.xml";
   _str url=h_match_pick_url(keyword,junk,index_filename,show_contents_if_keyword_not_found,_isUnix());
   if (url=='') {
      _help_contents(filename);
      return(1);
   }
   return(_syshtmlhelp(filename,HH_DISPLAY_TOPIC,url));
}
/**
 * <p>The help command allows you to use the command line to get help on a 
 * specific help item or get context sensitive help. 
 *  
 * <p>By default, F1 displays context sensitive help for the word at the cursor. 
 * When you are not in any context, help on table of contents is displayed.</p>
 * 
 * <p>When no parameters and there is a word at the cursor, 
 * context sensitive help for the current word is provided. The
 * language specific API Help profile is searched and then the
 * global API Help profile is searched for a match action.
 * 
 * <p>The <i>keyword</i> parameter may specify a help index item stored
 * in "slickeditindex.xml". It's the same list display in the help
 * index. You don't have to memorize every help item. Use the
 * space bar and '?' keys (completion) to help you enter the
 * name. If you are looking at some macro source code and want
 * help on a function, invoke the
 * <b>help</b> command and specify the name of the function (or just press F1).
 * Browse some of the features on the Help menu. You may find
 * them useful as well. If you specify "-search" for
 * <i>name</i>, the help search tab is displayed. If you specify
 * "-contents" for <i>name</i>, the help contents tab is
 * displayed.  If you specify "-index" for <i>name</i>, the help
 * index tab is displayed.</p>
 * 
 * <p>Press the ESC key to toggle the cursor to the command line.</p>
 *
 * @example
 * <pre>
 *    help windows keys
 *    help slickedit keys
 *    help emacs keys
 *    help brief keys
 *    help regular expressions
 *    help operators
 *    help substr
 *    help _control
 *    help -index
 * </pre>
 * 
 *
 * @categories Miscellaneous_Functions
 * 
 */
_command help(_str keyword="", _str filename="") name_info(HELP_ARG','VSARG2_CMDLINE)
{
   if(isEclipsePlugin()) {
      _str url = h_match_pick_url(keyword);
      if (url != '') {
         _eclipse_help(url);
      }
      return 0;
   }
   if(isVisualStudioPlugin()) {
      return 0;
   }

   i := 0;
   first_ch := "";
   command := "";
   typeless status=0;
   url := "";
   quiet:=false;
   parse keyword with auto option auto rest;
   if (option=='-q') {
      quiet=true;
      keyword=rest;
   }

   if ( p_window_id==_cmdline && keyword=='' && filename=='') {
      /* Check if a command is on the command line */
      _cmdline.get_command(command);
      parse command with command .;
      first_ch=substr(command,1,1);
      i=pos('[~A-Za-z0-9_\-]',command,1,'r');
      if ( i ) {
         command=substr(command,1,i-1);
      }
      if ( isdigit(first_ch) ) {
         command='0';
      } else if ( ! isalpha(first_ch) ) {
         command=first_ch;
      }
      if ( command!='' ) {
         if (def_keys=='ispf-keys' && h_match_exact('ispf-'lowcase(command))!='') {
            return(help('ispf-'lowcase(command)));
         }
         if (h_match_exact(command)!='') {
            return(help(command));
         }
         ucommand := stranslate(command, '_', '-');
         if (h_match_exact(ucommand)!='') {
            return(help(ucommand));
         }
         // Show table of contents item
         keyword='';
      }
   }
   orig_filename := filename;
   filename=_help_filename(filename);
   if (filename=='') {
      return(1);
   }
   if ( keyword=='') {
      _word_help(filename,'',false,true);
      // Show table of contents

      //status=_syshelp(filename,'',HELP_CONTENTS);
      //_help_error(status,filename,'');
      return(1);
   }
   if (lowcase(keyword)=='-contents') {
      _help_contents(filename);
      return(1);
   }
   if (lowcase(keyword)=='-index') {
      status=_syshtmlhelp(filename,HH_DISPLAY_INDEX);
      _help_error(status,filename,'');
      return(1);
   }
   if (lowcase(keyword)=='-using') {
      _message_box('-using option no longer supported');
      return(1);
   }
   if (lowcase(keyword)=='-search') {
      status=_syshtmlhelp(filename,HH_DISPLAY_SEARCH);
      _help_error(status,filename,'');
      return(1);
   }
   if (lowcase(keyword)=='summary of keys') {
      keyword=EmulateHelpItem();
   }
   if (orig_filename==''){
      if (def_error_check_help_items) {
         new_keyword := "";
         if (def_keys=='ispf-keys') {
            new_keyword=h_match_exact('ispf-'lowcase(keyword));
         }
         if (new_keyword=='') {
            new_keyword=h_match_exact(keyword);
         }
         if (new_keyword=='') {
            new_keyword=h_match_exact(stranslate(keyword, '_', '-'));
         }
         if (new_keyword=='') {
            if (!quiet) {
               _message_box(nls("Help item '%s' not found",keyword));
            }
            return(STRING_NOT_FOUND_RC);
         }
         keyword=new_keyword;
      }
   }
   if (def_error_check_help_items) {
      _str ext=_get_extension(filename);
      if ( _file_eq(ext,'chm') || _file_eq(ext,'htm') || _file_eq(ext,'qhc')) {
         status=html_keyword_help(filename,keyword);
      }else if ( _file_eq(ext,'hlp') ) {
         _syshelp(filename,keyword);
      }
   } else {
      status=_syshtmlhelp(filename,HH_KEYWORD_LOOKUP,keyword);
      _help_error(status,filename,keyword);
   }

   // log this event in the Product Improvement Program
   if (_pip_on) {
      name := p_name;
      if (p_object == OI_EDITOR) {
         name = p_mode_name' file';
      }
      _pip_log_help_event(keyword, p_object, name);
   }

   return(0);
}

// static _str get_system_browser_command()
// {
//    // Predefined list of browsers to search for and their command
//    // to open a URL (%f).
//    _str browser_list[][];
//    browser_list._makeempty();
//    int i = 0;
//    browser_list[i][0] = "firefox";
//    browser_list[i++][1] = "'%f'";
//    browser_list[i][0] = "mozilla";
//    browser_list[i++][1] = "-remote 'openURL('%f')'";
//    browser_list[i][0] = "netscape";
//    browser_list[i++][1] = "-remote 'openURL('%f')'";
//
//    int size = browser_list._length();
//    for (i = 0; i < size; ++i) {
//       _str browser_path = path_search(browser_list[i][0]);
//       if (!browser_path._isempty()) {
//          // System browser found.
//          _str cmd = browser_path' 'browser_list[i][1];
//          return cmd;
//       }
//    }
//    return '';
// }
//
// /**
//  * Open a specified URL using user's web browser of choice.
//  *
//  * @param url URL to open.  Must be well-formatted (e.g.
//  *            file:///path/to/file).
//  */
// void launch_web_browser(_str url='')
// {
//    if (_isMac() || !__UNIX__) {
//       // Use the old way for Mac for now.  But we need to revisit
//       // this after beta and fix it the right way.
//       goto_url(url, true);
//       return;
//    }
//    _str browser_cmd = get_system_browser_command();
//    if (!browser_cmd._isempty()) {
//       browser_cmd = stranslate(browser_cmd, url, '%f');
//       shell(browser_cmd, 'A');
//    }
// }

defeventtab _comboisearch_form;
void list1.lbutton_double_click()
{
   _ok.call_event(_ok,lbutton_up);
}
_ok.on_create()
{
   list1.p_completion=HELP_ARG;
   list1.p_ListCompletions=false;
   _str filename=_getSlickEditInstallPath():+'help':+FILESEP:+SLICK_HELPINDEX_FILE;
   //filename=_maybe_quote_filename(_config_path():+SLICK_HELPLIST_FILE);
   int status;
   int handle=_xmlcfg_open(filename,status);
   if (handle<0) {
      if ( handle==FILE_NOT_FOUND_RC ) {
         _message_box(nls("File '%s' not found",filename));
      } else {
         _message_box(nls("Error loading help file '%s'",filename));
      }
      return('');
   }
   _str array[];
   _xmlcfg_find_simple_array(handle,"/indexdata/key/@name",array,TREE_ROOT_INDEX,VSXMLCFG_FIND_VALUES);
   _xmlcfg_close(handle);
   int wid=list1.p_window_id;
   int i;
   for (i=0;i<array._length();++i) {
      wid._lbadd_item(array[i]);
   }

   //list1.p_cb_list_box.search('^ :i,','@r','');
   list1._lbtop();
   list1._lbselect_line();
   return('');
}

void list1.on_change(int reason)
{
   switch (reason) {
   case CHANGE_OTHER:
      list1._lbselect_line();
      list1.line_to_top();
   }
}

void _ok.lbutton_up()
{
   p_active_form._delete_window(list1._lbget_text());
}


static const HELPAPI_OPTS="HELPAPI_OPTS";
defeventtab _help_urls_form;
void ctlfind.lbutton_up()
{
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   int result = show('-modal -reinit _gui_find_form', arg(1), ctltree1.p_window_id);
   if (result == '') {
      return;
   }
   _str options='SC';
   if (pos('i',_param2,1,'i')) {
      strappend(options,'I');
   }
   int found_index=ctltree1._TreeSearch(curindex,_param1,options);
   orig_wid:=_create_temp_view(auto temp_wid);
   find(_param1,_param2);  // Do a search so search parameters are recorded for next search
   _delete_temp_view(temp_wid);
   p_window_id=orig_wid;
   if (found_index>=0) {
      ctltree1._TreeSetCurIndex(found_index);
   }
}

static bool HELP_URLS_MODIFIED(...) {
   if (arg()) {
      ctladd.p_user=arg(1);
      if (_plugin_has_builtin_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),HELP_PROFILE_NAME())) {
         ctldeleteprofile.p_caption="Reset";
         ctldeleteprofile.p_enabled=arg(1)!=0 || _plugin_has_user_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),HELP_PROFILE_NAME());
      } else {
         ctldeleteprofile.p_caption="Delete";
         ctldeleteprofile.p_enabled=true;
      }
   }
   return ctladd.p_user;
}
static bool HELP_IGNORE_CHANGE(...) {
   if (arg()) ctldelete.p_user=arg(1);
   return ctldelete.p_user;
}
static _str HELP_LANG_ID(...) {
   if (arg()) ctlmoveup.p_user=arg(1);
   return ctlmoveup.p_user;
}
static _str HELP_PROFILE_NAME(...) {
   if (arg()) ctlprofile.p_user=arg(1);
   return ctlprofile.p_user;
}
static _str HELP_DEFAULT_PROFILE_NAME(...) {
   if (arg()) ctlnewprofile.p_user=arg(1);
   return ctlnewprofile.p_user;
}

static _str _make_apihelp_key(HelpURLInfo &info) {
   action_type:=info.m_action_type;
   if (strieq(action_type,HELP_ACTION_TYPE_URL)) {
      action_type='';
   }
   // no class to match. Reuse previous URL action
   if (info.m_match_class=='' && info.m_action=='' && action_type=='') {
      return _plugin_escape_property(info.m_match_word);
   }
   // Reuse previous URL action
   if (info.m_action=='' && action_type=='') {
      return _plugin_escape_property(info.m_match_word):+VSXMLCFG_PROPERTY_SEPARATOR:+_plugin_escape_property(info.m_match_class);
   }
   return _plugin_escape_property(info.m_match_word):+VSXMLCFG_PROPERTY_SEPARATOR:+_plugin_escape_property(info.m_match_class):+
         VSXMLCFG_PROPERTY_SEPARATOR:+_plugin_escape_property(info.m_action):+
        ((action_type=='')?'':VSXMLCFG_PROPERTY_SEPARATOR:+_plugin_escape_property(action_type));
}
static void help_position_info(int (&hash_position):[],int &largest=0) {
   largest=0;
   hash_position._makeempty();

   child_index:=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   while (child_index>=0) {
      HelpURLInfo info=ctltree1._TreeGetUserInfo(child_index);
      if (isinteger(info.m_position))  {
         if (info.m_position>largest) {
            largest=info.m_position;
         }
         if (info.m_position>0) {
            hash_position:[_make_apihelp_key(info)]=info.m_position;
         }
      }
      child_index=ctltree1._TreeGetNextSiblingIndex(child_index);
   }
}
void _help_urls_form_save_settings()
{
   HELP_URLS_MODIFIED(false);
   int apihelp_info:[/* profileName*/]=null;
   _SetDialogInfoHt(HELPAPI_OPTS,apihelp_info);
}

bool _help_urls_form_is_modified()
{
   return HELP_URLS_MODIFIED() || _GetDialogInfoHtPtr(HELPAPI_OPTS)->_length() || !strieq(HELP_DEFAULT_PROFILE_NAME(),ctlprofile.p_text);
}
static int apihelp_save_profile() {

   handle:=_xmlcfg_create_profile(auto profile_node,vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),HELP_PROFILE_NAME(),VSCFGPROFILE_HELP_VERSION);
   child_index:=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   int hash_position:[];
   last_position := 0;
   help_position_info(hash_position,auto largest);
   bool doCompression=false;
   if (child_index>0) {
      NofChildren:=ctltree1._TreeGetNumChildren(TREE_ROOT_INDEX);
      if (NofChildren>=1000) {
         doCompression=true;
      }
   }
   doCompression=false;
   _str prev_action='';
   _str prev_action_type='';

   while (child_index>=0) {
      HelpURLInfo info=ctltree1._TreeGetUserInfo(child_index);
      n:=_make_apihelp_key(info);
      _plugin_next_position(n,last_position,hash_position);
      if (doCompression && prev_action:!='' && info.m_action:==prev_action && info.m_action_type:==prev_action_type) {
         info.m_action='';
         info.m_action_type='';
         n=_make_apihelp_key(info);
      }
      //_xmlcfg_set_attribute(handle,item_node,'p',last_position);

      /*if (strieq(info.m_action_type,HELP_ACTION_TYPE_PROFILE)) {
         n=_plugin_escape_property(info.m_action);
         info.m_action='';
      } */

      item_node:=_xmlcfg_add_property(handle,profile_node,last_position:+',':+n);
      if (!info.m_enabled) {
         _xmlcfg_set_attribute(handle,item_node,'enabled',info.m_enabled);
      }
      if (info.m_flags!='') {
         _xmlcfg_set_attribute(handle,item_node,'flags',info.m_flags);
      }
      if (prev_action=='' || info.m_action!='') {
         prev_action=info.m_action;
         prev_action_type=info.m_action_type;
      }
#if 0
      // Only need action_type if it's not "url"
      if (!strieq(info.m_action_type,HELP_ACTION_TYPE_URL)) {
         _xmlcfg_set_attribute(handle,item_node,'action_type',info.m_action_type);
      }
      // Action must be stored in the external file specified.
      if (info.m_action!='') {
         _xmlcfg_set_attribute(handle,item_node,'action',info.m_action);
      } 
#endif

      child_index=ctltree1._TreeGetNextSiblingIndex(child_index);
   }
   return handle;
}
bool _help_urls_form_apply()
{
   if (HELP_URLS_MODIFIED()) {
       handle:=apihelp_save_profile();
      _plugin_set_profile(handle);
      _xmlcfg_close(handle);
   }
   if(!strieq(HELP_DEFAULT_PROFILE_NAME(),ctlprofile.p_text)) {
      if (HELP_LANG_ID()=='') {
         def_apihelp_default_profile=ctlprofile.p_text;
         _config_modify_flags(CFGMODIFY_DEFVAR);
      } else {
         _LangSetProperty(HELP_LANG_ID(),VSLANGPROPNAME_APIHELP_DEFAULT_PROFILE,ctlprofile.p_text);
      }
   }
   foreach (auto profileName=>auto handle in _GetDialogInfoHt(HELPAPI_OPTS)) {
      _plugin_set_profile(handle);
      _xmlcfg_close(handle);
   }
   //gapihelp_info._makeempty();
   return true;
}

static void apihelp_show_profile(_str profileName,int handle=-1) {
   HELP_PROFILE_NAME(profileName);
   _TreeDelete(TREE_ROOT_INDEX,'C');
   int profile_node;
   int old_handle=handle;
   if (handle<0) {
      handle=_plugin_get_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileName);
      if (handle<0) {
         handle=_xmlcfg_create_profile(profile_node,vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileName,VSCFGPROFILE_HELP_VERSION);
         node2:=_xmlcfg_get_first_child(handle,profile_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
      } else {
         profile_node=_xmlcfg_get_document_element(handle);
      }
      _xmlcfg_sort_on_attribute(handle,profile_node,VSXMLCFG_PROPERTY_NAME,'n');
   } else {
      profile_node=_xmlcfg_get_document_element(handle);
   }

   HELP_IGNORE_CHANGE(true);
   node:=_xmlcfg_get_first_child(handle,profile_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
   _str prev_action='';
   _str prev_action_type='';
   while (node>=0) {
       HelpURLInfo info;

       _read_help_info(handle,node,info,prev_action,prev_action_type);

       childIndex := _TreeAddItem(TREE_ROOT_INDEX,_help_caption(info),TREE_ADD_AS_CHILD,0,0,-1,0,info);
       _TreeSetCheckable( childIndex, 1, 0, true);
       _TreeSetCheckState(childIndex,info.m_enabled?1:0);

       node=_xmlcfg_get_next_sibling(handle,node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
   }
   //_xmlcfg_get_first_child(handle,_xmlcfg_get_document_element());
   if (old_handle<0) {
      _xmlcfg_close(handle);
   }
   HELP_IGNORE_CHANGE(false);
   HELP_URLS_MODIFIED(old_handle>=0);
   ctlsearchtype_class.cc_fill_search_combo();
   ctlsearchtype_word.cc_fill_search_combo();
   ctlactiontype.init_action_type();
   ctltree1.call_event(CHANGE_SELECTED,ctltree1,ON_CHANGE,'W');
   ctlaction._fill_in_action_combo_box();
   HELP_IGNORE_CHANGE(true);
   ctlprofile.p_text=profileName;
   HELP_IGNORE_CHANGE(false);
}

void _help_urls_form_init_for_options(_str langID='')
{
   int apihelp_info:[/* profileName*/]=null;
   _SetDialogInfoHt(HELPAPI_OPTS,apihelp_info);
   HELP_IGNORE_CHANGE(false);
   HELP_LANG_ID(langID);

   sizeBrowseButtonToTextBox(ctlaction.p_window_id, ctlactionmenu.p_window_id, 0, 0);
   ctltree1._TreeSetColButtonInfo(0,500,TREE_BUTTON_SORT_NONE,0,"");
   ctltree1._TreeSetColButtonInfo(1,2000,TREE_BUTTON_SORT_NONE,0,"Match");
   ctltree1._TreeSetColButtonInfo(2,2000,TREE_BUTTON_SORT_NONE,-1,"Action");

   _str profileNames[];
   _plugin_list_profiles(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileNames);

   bool found_delete_profile=false;
   foreach (auto profileName in profileNames) {
      ctlprofile._lbadd_item(profileName);
      if (profileName:==HELP_DEFAULT_PROFILE) {
         found_delete_profile=true;
      }
   }
   if (!found_delete_profile) {
      ctlprofile._lbadd_item(HELP_DEFAULT_PROFILE);
   }

   _str defaultProfile;
   if (langID=='') {
      defaultProfile=def_apihelp_default_profile;
   } else {
      defaultProfile=_LangGetProperty(langID,VSLANGPROPNAME_APIHELP_DEFAULT_PROFILE);
   }
   if (defaultProfile=='') defaultProfile=HELP_DEFAULT_PROFILE;
   HELP_DEFAULT_PROFILE_NAME(defaultProfile);

   ctltree1.apihelp_show_profile(defaultProfile);
}

void ctlprofile.on_change(int reason) {
   if (HELP_IGNORE_CHANGE()) {
      return;
   }
   //if (reason == CHANGE_CLINE || reason == CHANGE_CLINE_NOTVIS) {
   if (p_text:==HELP_PROFILE_NAME()) {
      return;
   }
   if (HELP_URLS_MODIFIED()) {
      handle:=apihelp_save_profile();
      _GetDialogInfoHtPtr(HELPAPI_OPTS)->:[HELP_PROFILE_NAME()]=handle;
   }
   profileName:=p_text;
   if (_GetDialogInfoHtPtr(HELPAPI_OPTS)->_indexin(p_text)) {
      handle:=_GetDialogInfoHtPtr(HELPAPI_OPTS)->:[profileName];
      ctltree1.apihelp_show_profile(profileName,handle);
      _GetDialogInfoHtPtr(HELPAPI_OPTS)->_deleteel(profileName);
      _xmlcfg_close(handle);
   } else {
      ctltree1.apihelp_show_profile(profileName);
   }
}
void ctlnewprofile.lbutton_up() {
   profileName:=HELP_PROFILE_NAME();
   status:=_plugin_prompt_add_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileName);
   if (status) {
      return;
   }
   if (HELP_URLS_MODIFIED() && !strieq(profileName,HELP_PROFILE_NAME())) {
      handle:=apihelp_save_profile();
      _GetDialogInfoHtPtr(HELPAPI_OPTS)->:[HELP_PROFILE_NAME()]=handle;
   }

   if (!_plugin_has_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileName)) {
      ctlprofile._lbadd_item(profileName);
   }
   ctltree1.apihelp_show_profile(profileName);
   HELP_URLS_MODIFIED(true);
}
void ctldeleteprofile.lbutton_up() {
   profileName:=ctlprofile.p_text;
   if (_plugin_has_builtin_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileName)) {
      result:=_message_box(nls("Are you sure that you wish to reset the Profile '%s'",profileName),'',MB_YESNOCANCEL|MB_ICONQUESTION);
      if (result!=IDYES) {
         return;
      }
      // Delete user definitions
      _plugin_delete_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileName);
      ctltree1.apihelp_show_profile(profileName);
      HELP_URLS_MODIFIED(true);
      return;
   }
   if (ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX)>0) {
      result:=_message_box(nls("Are you sure that you wish to delete the Profile '%s'",profileName),'',MB_YESNOCANCEL|MB_ICONQUESTION);
      if (result!=IDYES) {
         return;
      }
   }
   _plugin_delete_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileName);

   HELP_IGNORE_CHANGE(true);
   ctlprofile._lbdelete_item();
   if (ctlprofile.p_Noflines<1) {
      ctltree1._TreeDelete(TREE_ROOT_INDEX,'C');
      ctlprofile._lbadd_item(HELP_DEFAULT_PROFILE);
      ctlprofile.p_text=HELP_DEFAULT_PROFILE;
   } else {
      ctlprofile.p_text=ctlprofile._lbget_text();
   }
   handle:=_GetDialogInfoHtPtr(HELPAPI_OPTS)->:[profileName];
   _GetDialogInfoHtPtr(HELPAPI_OPTS)->_deleteel(profileName);
   if (isinteger(handle)) _xmlcfg_close(handle);
   HELP_IGNORE_CHANGE(false);

   // Show profile
   profileName=ctlprofile.p_text;
   if (_GetDialogInfoHtPtr(HELPAPI_OPTS)->_indexin(profileName)) {
      handle=_GetDialogInfoHtPtr(HELPAPI_OPTS)->:[profileName];
      ctltree1.apihelp_show_profile(profileName,handle);
      _GetDialogInfoHtPtr(HELPAPI_OPTS)->_deleteel(profileName);
      _xmlcfg_close(handle);
   } else {
      ctltree1.apihelp_show_profile(profileName);
   }
}
void ctlcopyprofile.lbutton_up() {
   copyFrom:=HELP_PROFILE_NAME();
   status:=_plugin_prompt_add_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),auto profileName,copyFrom);
   handle:=_GetDialogInfoHtPtr(HELPAPI_OPTS)->:[profileName];
   _GetDialogInfoHtPtr(HELPAPI_OPTS)->_deleteel(profileName);
   if (isinteger(handle)) _xmlcfg_close(handle);
   if (!_plugin_has_profile(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),profileName)) {
      ctlprofile._lbadd_item(profileName);
   }
   handle=apihelp_save_profile();
   if (HELP_URLS_MODIFIED()) {
      _GetDialogInfoHtPtr(HELPAPI_OPTS)->:[copyFrom]=handle;
      ctltree1.apihelp_show_profile(profileName,handle);
   } else {
      ctltree1.apihelp_show_profile(profileName,handle);
      _xmlcfg_close(handle);
   }
}


_str _help_urls_form_export_settings(_str &file, _str &args, _str langID='')
{
   error := '';
   // just set the args to be the profile name for this langauge
   if (langID=='') {
      args=def_apihelp_default_profile;
   } else {
      args=_LangGetProperty(langID, VSLANGPROPNAME_APIHELP_DEFAULT_PROFILE);
   }
   if (args == null || args=='') {
      args=HELP_DEFAULT_PROFILE;
   }

   //_plugin_export_profile(file,vsCfgPackage_for_LangBeautifierProfiles(langID),args,langID);
   error=_plugin_export_profiles(file,vsCfgPackage_for_LangAPIHelpProfiles(langID),null,false);

   return error;
}

_str _help_urls_form_import_settings(_str &file, _str &args, _str langID='')
{
   error := '';

   if (args == '') {
      // we can't do anything here
      return error;
   }

   if (file != '') {
      error=_plugin_import_profiles(file,vsCfgPackage_for_LangAPIHelpProfiles(langID),2);
      //error = importUserProfile(file, args, langID);
   }
   if (_plugin_has_profile(vsCfgPackage_for_LangAPIHelpProfiles(langID),args)) {
      // it does, so set it as this profile for this language
      if (langID=='') {
         def_apihelp_default_profile=args;
         _config_modify_flags(CFGMODIFY_DEFVAR);
      } else {
         _LangSetProperty(langID, VSLANGPROPNAME_APIHELP_DEFAULT_PROFILE, args);
      }
      //LanguageSettings.setBeautifierProfileName(langID, args);
   }

   return error;
}

static void enableDisableButtons()
{
   int selected[];
   ctltree1._TreeGetSelectionIndices(selected);
   numSelected := selected._length();

   if (numSelected == 0) {
      ctlpicture1.p_enabled = ctldelete.p_enabled = 
         ctlmoveup.p_enabled = ctlmovedown.p_enabled = false;
   } else if (numSelected == 1) {
      selIndex := selected[0];
      ctlpicture1.p_enabled = ctldelete.p_enabled = true;

      prev := ctltree1._TreeGetPrevSiblingIndex(selIndex);
      next := ctltree1._TreeGetNextSiblingIndex(selIndex);
   
      ctlmoveup.p_enabled = (prev >= 0);
      ctlmovedown.p_enabled = (next >= 0);
      ctlsearch_class.p_enabled=ctlsearch_class.p_next.p_enabled=ctlsearch_class.p_next.p_next.p_enabled=!strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_PROFILE) && !strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_STOP);
      ctllabel1.p_enabled=ctlsearch_word.p_enabled=ctlsearch_word.p_next.p_enabled=ctlsearch_word.p_next.p_next.p_enabled=!strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_PROFILE)&& !strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_STOP);
      ctlactiontype.p_enabled=ctlaction.p_enabled=!strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_STOP);
      ctlactionmenu.p_enabled=strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_URL) || strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_INTERNET_SEARCH);
   } else {
      ctlpicture1.p_enabled = ctlmoveup.p_enabled = ctlmovedown.p_enabled = false;
      ctldelete.p_enabled = true;
   }
}
static _str _help_caption(HelpURLInfo &info) {
   if (strieq(info.m_action_type,HELP_ACTION_TYPE_STOP)) {
      return "\t\tstop";
   }
   if (info.m_match_word=='' && info.m_match_class=='') {
      return "\t\t"info.m_action;
   }
   return "\t"info.m_match_word','info.m_match_class"\t"info.m_action;
}
void ctladd.lbutton_up() {
   HelpURLInfo info;

   curindex:=ctltree1._TreeCurIndex();
   if (curindex>0) {
      info=ctltree1._TreeGetUserInfo(curindex);
   } else {
      init_helpurlinfo(info);
      info.m_action_type=HELP_ACTION_TYPE_INTERNET_SEARCH;
   }
   info.m_position=0;

   int childIndex;
   if (curindex>0) {
      childIndex=ctltree1._TreeAddItem(curindex,_help_caption(info),TREE_ADD_AFTER,0,0,-1,0,info);
   } else {
      childIndex=ctltree1._TreeAddItem(TREE_ROOT_INDEX,_help_caption(info),TREE_ADD_AS_CHILD,0,0,-1,0,info);
   }
   ctltree1._TreeSetCheckable(childIndex, 1, 0, true);

   enableDisableButtons();
   HELP_URLS_MODIFIED(true);
   ctltree1._TreeSetCurIndex(childIndex);
   //_help_update_item(childIndex,info);
}
void ctldelete.lbutton_up() {

   // figure out which tree we want
   treeWid := _control ctltree1;

   // get a whole list of selected stuff
   int selected[];
   treeWid._TreeGetSelectionIndices(selected);

   if (selected._length() == 0) return;

   // figure out what to select after we get rid of stuff
   newSelection := -1;
   if (selected._length() == 1) {
      newSelection = treeWid._TreeGetNextSiblingIndex(selected[0]);
      if (newSelection < 0) {
         newSelection = treeWid._TreeGetPrevSiblingIndex(selected[0]);
      }
   }

   for (i := 0; i < selected._length(); i++) {
      // get the index and rip it out
      treeWid._TreeDelete(selected[i]);
   }

   // if we haven't set up something to select, just pick the top thing
   if (newSelection < 0) {
      newSelection = treeWid._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   }

   if (newSelection > 0) {
      treeWid._TreeSelectLine(newSelection);
   } 

   HELP_URLS_MODIFIED(true);
   ctltree1.call_event(CHANGE_SELECTED,ctltree1,ON_CHANGE,'W');
}
static void cc_fill_search_combo() {
   _lbclear();
   _lbadd_item('Plain text search');
   _lbadd_item('Perl regex');
   _lbadd_item('SlickEdit regex');
}
static void init_action_type() {
   _lbclear();
   _lbadd_item(HELP_ACTION_TYPE_URL);
   _lbadd_item(HELP_ACTION_TYPE_INTERNET_SEARCH);
   _lbadd_item(HELP_ACTION_TYPE_PROFILE);
   _lbadd_item(HELP_ACTION_TYPE_SLICKC);
   //_lbadd_item(HELP_ACTION_TYPE_EXTERNAL);
   _lbadd_item(HELP_ACTION_TYPE_STOP);
}
static void _set_searchtype(_str &styles,_str prefix='') {
   styles=stranslate(' 'styles' ','',' 'prefix:+'regex|'prefix:+'perlre','r');
   styles=strip(styles);
   if (strieq(p_text,"SlickEdit regex")) {
      strappend(styles,' ':+prefix:+'regex');
   } else if (strieq(p_text,"Perl regex")) {
      strappend(styles,' ':+prefix:+'perlre');
   }
   styles=strip(styles);
}
static void _set_matchcase(_str &styles,_str prefix='') {
   value:=p_value;
   styles=stranslate(' 'styles' ','',' 'prefix:+'ignore_case');
   styles=strip(styles);
   if (!value) {
      strappend(styles,' 'prefix:+'ignore_case');
   }
   styles=strip(styles);
}
static void _help_update_item(int curindex, HelpURLInfo &info) {
   ctltree1._TreeSetCheckState(curindex,info.m_enabled?1:0);
   ctltree1._TreeSetCaption(curindex,_help_caption(info));
}

static void resizeTreeColumns()
{
   //return;
   /*treeWidth := _ctl_patterns_tree.p_width;

   colSlice := _ctl_patterns_tree.p_width intdiv 4;

   _ctl_patterns_tree._TreeSetColButtonInfo(0, colSlice * 3);
   _ctl_patterns_tree._TreeSetColButtonInfo(1, colSlice);*/
}
void _help_urls_form.on_resize()
{
   width := _dx2lx(p_active_form.p_xyscale_mode, p_active_form.p_client_width);
   height := _dy2ly(p_active_form.p_xyscale_mode, p_active_form.p_client_height);

   // determine padding
   padding := ctltree1.p_x;

   widthDiff := width - (ctladd.p_x_extent + padding);
   heightDiff := height - (ctltree1.p_y_extent + padding+ ctlpicture1.p_height);

   if (widthDiff) {
      // move the pattern tree buttons over
      //ctledit.p_x += widthDiff;
      ctladd.p_x += widthDiff;
      ctldelete.p_x += widthDiff;
      ctlmoveup.p_x += widthDiff;
      ctlmovedown.p_x += widthDiff;
      ctlfind.p_x += widthDiff;

      // widen the trees
      ctltree1.p_width += widthDiff;

      resizeTreeColumns();
   }
   ctltree1.p_height += heightDiff;

   ctlpicture1.p_y=100+ctltree1.p_y_extent;
   ctlpicture1.p_width=width-2*ctlpicture1.p_x;
   ctlaction.p_width+=ctlpicture1.p_width-(ctlaction.p_x+ctlaction.p_width+ctlactionmenu.p_width+40);
   ctlactionmenu.p_x=ctlaction.p_x_extent+30;
}
void ctlmoveup.lbutton_up()
{
   treeWid := _control ctltree1;

   int selected[];
   treeWid._TreeGetSelectionIndices(selected);
   index := selected[0];
   treeWid._TreeMoveUp(index);

   HELP_URLS_MODIFIED(true);
   enableDisableButtons();
}

void ctlmovedown.lbutton_up()
{
   treeWid := _control ctltree1;

   // we want to check out the currently selected node - we only allow motion in single select mode
   int selected[];
   treeWid._TreeGetSelectionIndices(selected);
   index := selected[0];
   treeWid._TreeMoveDown(index);

   HELP_URLS_MODIFIED(true);
   enableDisableButtons();
}
static void showHelpItemSettings(_str match, _str match_flags,_str prefix='') {
   p_text=match;

   if (pos(' ':+prefix:+'regex ',' 'match_flags' ')) {
      p_next.p_text="SlickEdit regex";
   } else if (pos(' ':+prefix:+'perlre ',' 'match_flags' ')) {
      p_next.p_text="Perl regex";
   } else {
      p_next.p_text="Plain text search";
   }
   if (pos(' ':+prefix:+'ignore_case ',' 'match_flags' ')) {
      p_next.p_next.p_value=0;
   } else {
      p_next.p_next.p_value=1;
   }
}
void ctltree1.on_change(int reason,int index=-1)
{
   if (HELP_IGNORE_CHANGE()) return;
   if (reason == CHANGE_SELECTED) {
      curindex:=ctltree1._TreeCurIndex();
      if (curindex<=0) {
         return;
      }
      HELP_IGNORE_CHANGE(true);
      HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);
      ctlsearch_class.p_text=info.m_match_class;
      ctlsearch_class.showHelpItemSettings(info.m_match_class,info.m_flags,'class_');
      ctlsearch_word.p_text=info.m_match_word;
      ctlsearch_word.showHelpItemSettings(info.m_match_word,info.m_flags);
      ctlactiontype.p_text=info.m_action_type;
      ctlaction.p_text=info.m_action;
      HELP_IGNORE_CHANGE(false);
      ctlaction._fill_in_action_combo_box();
      enableDisableButtons();
   } else if (reason==CHANGE_CHECK_TOGGLED) {
      value:=ctltree1._TreeGetCheckState(index);
      HelpURLInfo info=ctltree1._TreeGetUserInfo(index);
      info.m_enabled=value!=0;
      ctltree1._TreeSetUserInfo(index, info);
      HELP_URLS_MODIFIED(true);
   }
}
void ctlsearch_class.on_change() {
   if (HELP_IGNORE_CHANGE()) return;
   
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);
   info.m_match_class=p_text;
   ctltree1._TreeSetUserInfo(curindex, info);
   _help_update_item(curindex,info);
   HELP_URLS_MODIFIED(true);
}
void ctlsearch_word.on_change() {
   if (HELP_IGNORE_CHANGE()) return;
   
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);
   info.m_match_word=p_text;
   ctltree1._TreeSetUserInfo(curindex, info);
   _help_update_item(curindex,info);
   HELP_URLS_MODIFIED(true);
}
static void _fill_in_action_combo_box() {
   _lbclear();
   if (strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_PROFILE)) {
      _plugin_list_profiles(vsCfgPackage_for_LangAPIHelpProfiles(HELP_LANG_ID()),auto profileNames);
      for (i:=0;i<profileNames._length();++i) {
         _lbadd_item(profileNames[i]);
      }
   } else if (strieq(ctlactiontype.p_text,HELP_ACTION_TYPE_SLICKC)) {
      _insert_name_list(COMMAND_TYPE);
   }
}
void ctlactiontype.on_change() {
   if (HELP_IGNORE_CHANGE()) return;
   
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);

   ctlaction._fill_in_action_combo_box();
   if (strieq(p_text,HELP_ACTION_TYPE_PROFILE) || strieq(p_text,HELP_ACTION_TYPE_STOP)) {
      info.m_action='';
      info.m_match_class='';
      info.m_match_word='';
      info.m_flags='';
   } else {
      //orig_action:=info.m_action;
      init_helpurlinfo(info);
      info.m_action='';
   }
   info.m_action_type=p_text;
   HELP_IGNORE_CHANGE(true);
   ctlsearch_class.p_text=info.m_match_class;
   //call_event(ctlsearch_class,ON_CHANGE,'W');
   ctlsearch_word.p_text=info.m_match_word;
   ctlaction.p_text=info.m_action;
   //call_event(ctlsearch_word,ON_CHANGE,'W');
   HELP_IGNORE_CHANGE(false);
   ctltree1._TreeSetUserInfo(curindex, info);
   _help_update_item(curindex,info);
   HELP_URLS_MODIFIED(true);
   enableDisableButtons();
}
void ctlsearchtype_class.on_change() {
   if (HELP_IGNORE_CHANGE()) return;
   
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);
   _set_searchtype(info.m_flags,'class_');

   ctltree1._TreeSetUserInfo(curindex, info);
   _help_update_item(curindex,info);
   HELP_URLS_MODIFIED(true);
}
void ctlsearchtype_word.on_change() {
   if (HELP_IGNORE_CHANGE()) return;
   
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);
   _set_searchtype(info.m_flags);

   ctltree1._TreeSetUserInfo(curindex, info);
   _help_update_item(curindex,info);
   HELP_URLS_MODIFIED(true);
}

void ctlmatchcase_class.lbutton_up() {
   if (HELP_IGNORE_CHANGE()) return;
   
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);
   _set_matchcase(info.m_flags,'class_');

   ctltree1._TreeSetUserInfo(curindex, info);
   _help_update_item(curindex,info);
   HELP_URLS_MODIFIED(true);
}

void ctlmatchcase_word.lbutton_up() {
   if (HELP_IGNORE_CHANGE()) return;
   
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);
   _set_matchcase(info.m_flags);

   ctltree1._TreeSetUserInfo(curindex, info);
   _help_update_item(curindex,info);
   HELP_URLS_MODIFIED(true);
}
void ctlaction.on_change() {
   if (HELP_IGNORE_CHANGE()) return;
   
   curindex:=ctltree1._TreeCurIndex();
   if (curindex<=0) {
      return;
   }
   HelpURLInfo info=ctltree1._TreeGetUserInfo(curindex);
   info.m_action=p_text;

   ctltree1._TreeSetUserInfo(curindex, info);
   _help_update_item(curindex,info);
   HELP_URLS_MODIFIED(true);
}



defeventtab _search_engines_form;
static bool SEARCH_ENGINES_URLS_MODIFIED(...) {
   if (arg()) ctladd.p_user=arg(1);
   return ctladd.p_user;
}
static bool SEARCH_ENGINES_IGNORE_CHANGE(...) {
   if (arg()) ctldelete.p_user=arg(1);
   return ctldelete.p_user;
}
static _str _findDefaultProfile() {
   default_profile := "";
   index:=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   while (index>0) {
      ctltree1._TreeGetInfo(index,auto showChildren,auto nonCurrentBMIndex,auto currentBMIndex,auto nodeFlags,auto lineNumber);
      if (nodeFlags & TREENODE_BOLD) {
         parse ctltree1._TreeGetCaption(index) with default_profile "\t";
         break;
      }
      index=ctltree1._TreeGetNextSiblingIndex(index);
   }
   return default_profile;
}
void _search_engines_form_save_settings()
{
   SEARCH_ENGINES_URLS_MODIFIED(false);
}
bool _search_engines_form_is_modified()
{
   return SEARCH_ENGINES_URLS_MODIFIED();
}

static int search_engines_save_profile() {

   handle:=_xmlcfg_create_profile(auto profile_node,VSCFGPACKAGE_MISC,VSCFGPROFILE_SEARCH_ENGINES,VSCFGPROFILE_SEARCH_ENGINES_VERSION);
   child_index:=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   while (child_index>=0) {
      parse ctltree1._TreeGetCaption(child_index) with auto name auto url;
      _xmlcfg_add_property(handle,profile_node,name,url);

      child_index=ctltree1._TreeGetNextSiblingIndex(child_index);
   }
   return handle;
}
bool _search_engines_form_apply()
{
   default_profile:=_findDefaultProfile();
   if (default_profile!='') {
      def_search_engine=default_profile;
      _config_modify_flags(CFGMODIFY_DEFVAR);
   }

   handle:=search_engines_save_profile();
   _plugin_set_profile(handle);
   _xmlcfg_close(handle);
   return true;
}

static void search_engine_show_profile() {
   handle:=_plugin_get_profile(VSCFGPACKAGE_MISC,VSCFGPROFILE_SEARCH_ENGINES);
   profile_node:=_xmlcfg_get_document_element(handle);

   HELP_IGNORE_CHANGE(true);
   node:=_xmlcfg_get_first_child(handle,profile_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
   while (node>=0) {
      name:=_xmlcfg_get_attribute(handle,node,VSXMLCFG_PROPERTY_NAME);
      url:=_xmlcfg_get_attribute(handle,node,VSXMLCFG_PROPERTY_VALUE);
      childIndex := _TreeAddItem(TREE_ROOT_INDEX,name:+"\t":+url,TREE_ADD_AS_CHILD);
      node=_xmlcfg_get_next_sibling(handle,node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
   }
   //_xmlcfg_get_first_child(handle,_xmlcfg_get_document_element());
   _xmlcfg_close(handle);
   SEARCH_ENGINES_IGNORE_CHANGE(false);
   SEARCH_ENGINES_URLS_MODIFIED(false);
   ctltree1.call_event(CHANGE_SELECTED,ctltree1,ON_CHANGE,'W');
}
void _search_engines_form_init_for_options()
{
   SEARCH_ENGINES_IGNORE_CHANGE(false);

   //sizeBrowseButtonToTextBox(ctlaction.p_window_id, ctlactionmenu.p_window_id, 0, 0);
   ctltree1._TreeSetColButtonInfo(0,1500,TREE_BUTTON_SORT_NONE,0,"Search engine");
   ctltree1._TreeSetColButtonInfo(1,2500,TREE_BUTTON_SORT_NONE,-1,"URL");

   ctltree1.search_engine_show_profile();
   search_engine_update_default_profile(def_search_engine);
   search_engines_enableDisableButtons();
   ctltree1._TreeSizeColumnToContents(0);
}
static void search_engines_enableDisableButtons() {
   index:=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   if (index<0) {
      ctledit.p_enabled=false;
      ctldelete.p_enabled=false;
      ctlsetdefault.p_enabled=false;
      return;
   }
   index=ctltree1._TreeCurIndex();
   ctledit.p_enabled=true;
   ctlsetdefault.p_enabled=true;
   parse ctltree1._TreeGetCaption(index) with auto name "\t" auto url;
   if (_plugin_has_builtin_property(VSCFGPACKAGE_MISC,VSCFGPROFILE_SEARCH_ENGINES,name)) {
      ctldelete.p_enabled=false;
   } else {
      ctldelete.p_enabled=true;
   }
}
void ctltree1.on_change(int reason,int index=-1)
{
   if (SEARCH_ENGINES_IGNORE_CHANGE()) return;
   if (reason == CHANGE_SELECTED) {
      search_engines_enableDisableButtons();

      curindex:=ctltree1._TreeCurIndex();
      if (curindex<=0) {
         return;
      }
      SEARCH_ENGINES_IGNORE_CHANGE(true);
      /*parse ctltree1._TreeGetCaption(curindex) with auto name "\t" auto url;
      ctlname.p_text=name;
      ctlurl.p_text=url;*/
      SEARCH_ENGINES_IGNORE_CHANGE(false);
      search_engines_enableDisableButtons();
   }
}
static void search_engine_update_default_profile(_str default_search_engine,int index=-1) {

   child_index:=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   bool found_default=false;
   int google_index=-1;
   while (child_index>=0) {
      parse ctltree1._TreeGetCaption(child_index) with auto name auto url;
      if (name=="Google") {
         google_index=child_index;
      }
      if ((index<=0 && name==default_search_engine) || (index>=0 && child_index==index)) {
         ctltree1._TreeSetInfo(child_index,TREE_NODE_LEAF,-1,-1,TREENODE_BOLD);
         found_default=true;
      } else {
         ctltree1._TreeSetInfo(child_index,TREE_NODE_LEAF,-1,-1,0);
      }

      child_index=ctltree1._TreeGetNextSiblingIndex(child_index);
   }
   if (!found_default) {
      if (google_index>=0) {
         ctltree1._TreeSetInfo(google_index,TREE_NODE_LEAF,-1,-1,TREENODE_BOLD);
      } else {
         child_index=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
         if (child_index>=0) {
            ctltree1._TreeSetInfo(child_index,TREE_NODE_LEAF,-1,-1,TREENODE_BOLD);
         }
      }
   }

   search_engines_enableDisableButtons();
}
void ctlsetdefault.lbutton_up() {
   index:=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   if (index<0) {
      return;
   }
   search_engine_update_default_profile('',ctltree1._TreeCurIndex());
   SEARCH_ENGINES_URLS_MODIFIED(true);
}
static int gsearch_engine_tree_wid;
static _str gsearch_engine_orig_name;
int _check_search_engine_name(_str name) {
   if (gsearch_engine_orig_name!=null) {
      if (gsearch_engine_orig_name==name) {
         return 0;
      }
   }
   if (!_iswindow_valid(gsearch_engine_tree_wid)) {
      _message_box('not valid handle');
      return INVALID_ARGUMENT_RC;
   }
   if (gsearch_engine_tree_wid.p_object!=OI_TREE_VIEW) {
      _message_box('!=OI_TREE_VIEW');
      return INVALID_ARGUMENT_RC;
   }
   index:=gsearch_engine_tree_wid._TreeSearch(TREE_ROOT_INDEX,name"\t","p");
   if (index>=0) {
      _message_box('This search engine name already exists');
      return(INVALID_ARGUMENT_RC);
   }
   return 0;
}
void ctladd.lbutton_up() {
   gsearch_engine_tree_wid=ctltree1;
   gsearch_engine_orig_name=null;
   int status = p_active_form.textBoxDialog("Add Search Engine",
                                   0,
                                   0,
                                   "",
                                   "OK,Cancel:_cancel\tSpecify the search engine name and URL. Specify %s in URL for search query text",  // Button List
                                   "",
                                   "-e _check_search_engine_name Name:",
                                   "URL:");
   if (status<0) {
      return;
   }
   childIndex:=ctltree1._TreeAddItem(TREE_ROOT_INDEX,_param1"\t"_param2,TREE_ADD_AS_CHILD,0,0,-1);

   search_engines_enableDisableButtons();
   SEARCH_ENGINES_URLS_MODIFIED(true);
   ctltree1._TreeSetCurIndex(childIndex);
}
void ctledit.lbutton_up() {
   index:=ctltree1._TreeCurIndex();
   if (index<=0) {
      return;
   }
   gsearch_engine_tree_wid=ctltree1;
   parse ctltree1._TreeGetCaption(index) with auto name "\t" auto url;
   gsearch_engine_orig_name=name;

   int status = p_active_form.textBoxDialog("Search Engine Properties",
                                   0,
                                   0,
                                   "",
                                   "OK,Cancel:_cancel\tSpecify the search engine name and URL. Specify %s in URL for search query text",  // Button List
                                   "",
                                   "-e _check_search_engine_name Name:"name,
                                   "URL:"url);
   if (status<0) {
      return;
   }
   ctltree1._TreeSetCaption(index,_param1"\t"_param2);

   search_engines_enableDisableButtons();
   SEARCH_ENGINES_URLS_MODIFIED(true);
}
void ctldelete.lbutton_up() {
   index:=ctltree1._TreeCurIndex();
   if (index<=0) {
      return;
   }
   ctltree1._TreeGetInfo(index,auto showChildren,auto nonCurrentBMIndex,auto currentBMIndex,auto nodeFlags,auto lineNumber);
   parse ctltree1._TreeGetCaption(index) with auto name "\t";
   status := _message_box("Are you sure you want to delete search engine '"name"'?", "Confirm Delete", MB_YESNO | MB_ICONEXCLAMATION);
   if (status == IDYES) {
      ctltree1._TreeDelete(index);
      //IF the node we deleted was bold
      if (nodeFlags & TREENODE_BOLD) {
         index=ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
         if (index>0) {
            index=ctltree1._TreeCurIndex();
            ctltree1._TreeSetInfo(index,TREE_NODE_LEAF,-1,-1,TREENODE_BOLD);
         }
      }
      SEARCH_ENGINES_URLS_MODIFIED(true);
      search_engines_enableDisableButtons();
   }
}
void _search_engines_form.on_resize()
{
   width := _dx2lx(p_active_form.p_xyscale_mode, p_active_form.p_client_width);
   height := _dy2ly(p_active_form.p_xyscale_mode, p_active_form.p_client_height);

   // determine padding
   padding := ctltree1.p_x;

   widthDiff := width - (ctladd.p_x_extent + padding);
   heightDiff := height - (ctltree1.p_y_extent + padding);

   if (widthDiff) {
      // move the pattern tree buttons over
      //ctledit.p_x += widthDiff;
      ctladd.p_x += widthDiff;
      ctldelete.p_x += widthDiff;
      ctledit.p_x += widthDiff;
      ctlsetdefault.p_x += widthDiff;

      // widen the trees
      ctltree1.p_width += widthDiff;

      //resizeTreeColumns();
   }
   ctltree1.p_height += heightDiff;

   /*ctlpicture1.p_y=100+ctltree1.p_y_extent;
   ctlpicture1.p_width=width-2*ctlpicture1.p_x;
   ctlname.p_width+=ctlpicture1.p_width-(ctlname.p_x_extent);
   ctlurl.p_width+=ctlpicture1.p_width-(ctlurl.p_x_extent);*/
}

_str _search_engines_form_export_settings(_str &file, _str &args)
{
   error := '';

   // just set the args to be the profile name for this langauge
   args=def_search_engine;
   if (args == null || args=='') {
      args="Google";
   }

   //_plugin_export_profile(file,vsCfgPackage_for_LangBeautifierProfiles(langID),args,langID);
   error=_plugin_export_profile(file,VSCFGPACKAGE_MISC,VSCFGPROFILE_SEARCH_ENGINES);

   return error;
}

_str _search_engines_form_import_settings(_str &file, _str &args)
{
   error := '';

   if (args == '') {
      // we can't do anything here
      return error;
   }

   if (file != '') {
      error=_plugin_import_profile(file,VSCFGPACKAGE_MISC,VSCFGPROFILE_SEARCH_ENGINES);
   }
   if (_plugin_has_property(VSCFGPACKAGE_MISC,VSCFGPROFILE_SEARCH_ENGINES,args)) {
      def_search_engine=args;
      _config_modify_flags(CFGMODIFY_DEFVAR);
   }

   return error;
}
