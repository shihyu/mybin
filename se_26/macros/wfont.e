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
#import "clipbd.e"
#import "diff.e"
#import "font.e"
#import "fontcfg.e"
#import "main.e"
#import "picture.e"
#import "recmacro.e"
#import "sellist.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "se/lang/api/LanguageSettings.e"
#endregion

_control _okay
_control _just_window
_control _sample_text
_control _font_name_list

defeventtab _wfont_form;

/**
 * Displays <b>Font dialog box</b> which allows you to change the font 
 * for the current MDI edit window or all MDI edit windows.
 * 
 * @param options is a string of zero or more of the following option 
 * letters:
 * 
 * <dl>
 * <dt>C</dt><dd>Work as a font chooser form, returns selected font info</dd>
 * <dt>F</dt><dd>Display fixed pitch fonts only.</dd>
 * <dt>S</dt><dd>(Default) Display screen fonts.</dd>
 * <dt>P</dt><dd>Display printer fonts.</dd>
 * </dl>
 * 
 * <p>Printer and screen fonts can not be displayed at the same time.</p>
 *    
 * @param font specifies the font that should be used to initialize the 
 * dialog box.  It is a string in the format:<br>  
 * 
 * <i>font_name,font_size, font_flags</i>
 * 
 * @param font_size is the point size of the font.  <i>font_flags</i> is 
 * zero or constants ORed together.  The font flag constants are defined 
 * in "slick.sh" and have the prefix "F_" (ex. F_BOLD).
 * 
 * @example void show('_wfont_form', <i>options</i> , <i>font</i>)
 * 
 * @see _choose_font
 * @see wfont
 * @see window_font
 */ 
void _okay.on_create(_str show_font_options="",_str _font_string="")
{
   // hide the scope controls if this is just a font picker.
   if (upcase(_first_char(show_font_options)) == 'C') {
      _scope.p_visible = _scope.p_enabled = false;
      show_font_options = substr(show_font_options,2);
      p_active_form.p_caption = "Select Font";
   }
      
   // set up the language mode
   wid := _form_parent(); //_mdi.p_child;
   if (wid && wid._isEditorCtl(false)) {
      _lang_changes.p_caption = "All \"" :+ wid.p_mode_name :+ "\" files";
   } else {
      _lang_changes.p_caption = "";
      _lang_changes.p_enabled = false;
      _lang_changes.p_visible = false;
      _lang_changes.p_value = 0;
   }

   createFontForm(show_font_options, _font_string);
}

static void generate_change_all_macro(_str font_name, _str font_size,
                                      int font_flags, int charset=VSCHARSET_DEFAULT,
                                      int cfg=CFG_SBCS_DBCS_SOURCE_WINDOW, _str langId="")
{
   _macro('m',_macro('s'));
   _macro_call("_change_all_wfonts",font_name,font_size,font_flags,charset,cfg,langId);
}

static void generate_change_current_macro(_str font_name, _str font_size, int font_flags,int charset=VSCHARSET_DEFAULT)
{
   fs := font_flags & F_STRIKE_THRU;
   fu := font_flags & F_UNDERLINE;
   fi := font_flags & F_ITALIC;
   fb := font_flags & F_BOLD;
   font_info := font_name ',' font_size ',' font_flags ','charset;

   _macro('m',_macro('s'));
   _macro_append("p_font_name       ="_quote(font_name)";");
   _macro_append("p_font_size       ="font_size";");
   _macro_append("p_font_bold       ="fb";");
   _macro_append("p_font_italic     ="fi";");
   _macro_append("p_font_underline  ="fu";");
   _macro_append("p_font_strike_thru="fs";");
   _macro_append("p_font_charset="charset";");
   _macro_append("p_BufferFontInfo="_quote(font_info)";");
}

/**
 * Changes the font of all MDI edit windows.  <i>font_size</i> is a point size.
 * <i>font_flags</i> is a combination of the following flag constants defined in "slick.sh":
 * <pre>
 * F_BOLD
 * F_ITALIC
 * F_STRIKE_THRU
 * F_UNDERLINE
 * </pre>
 * 
 * @param font_name
 * @param font_size
 * @param font_flags
 * @param charset
 * @param cfg 
 * @param langId
 * 
 * @categories Window_Functions
 */
void _change_all_wfonts(_str font_name, _str font_size, int font_flags,int charset=VSCHARSET_DEFAULT,int cfg=CFG_SBCS_DBCS_SOURCE_WINDOW, _str langId="")
{
   if (!isinteger(charset)) {
      charset=VSCHARSET_DEFAULT;
   }
   update_minimap_font := cfg==CFG_SBCS_DBCS_MINIMAP_WINDOW || cfg==CFG_UNICODE_MINIMAP_WINDOW;
   update_editor_font  := !update_minimap_font;
   minimap_font_name   := "";
   minimap_font_size   := null;
   minimap_cfg         := MAXINT;
   if (cfg==CFG_SBCS_DBCS_SOURCE_WINDOW) {
      minimap_cfg=CFG_SBCS_DBCS_MINIMAP_WINDOW;
      update_minimap_font=true;
      parse _default_font(CFG_SBCS_DBCS_MINIMAP_WINDOW) with minimap_font_name','minimap_font_size',';//font_flags','charset',';
   } else if (cfg==CFG_UNICODE_SOURCE_WINDOW) {
      minimap_cfg=CFG_UNICODE_MINIMAP_WINDOW;
      update_minimap_font=true;
      parse _default_font(CFG_UNICODE_MINIMAP_WINDOW) with minimap_font_name','minimap_font_size',';//font_flags','charset',';
   }

   orig_wid := p_window_id;
   bool buffers_done:[];
   last:=_last_window_id();
   for (i:=1;i<=last;++i) {
      if (_iswindow_valid(i) && i._isEditorCtl(false)) {
         if (langId != "" && i.p_LangId != langId && langId != ALL_LANGUAGES_ID) {
            continue;
         }
         int thiscfg=MAXINT;
         if (update_minimap_font && i.p_IsMinimap) {
            if (i._isEditorCtl(false)) {
               if (langId != "") {
                  thiscfg=CFG_UNICODE_MINIMAP_WINDOW;
               } else if (i.p_UTF8) {
                  thiscfg=CFG_UNICODE_MINIMAP_WINDOW;
               } else {
                  thiscfg=CFG_SBCS_DBCS_MINIMAP_WINDOW;
               }
            }
         }
         if (update_editor_font && !i.p_IsMinimap) {
            thiscfg=CFG_SBCS_DBCS_SOURCE_WINDOW;
            if (i._isEditorCtl(false)) {
               if (i.p_hex_mode) {
                  thiscfg=CFG_HEX_SOURCE_WINDOW;
               } else if (i.p_LangId=='fileman') {
                  thiscfg=CFG_FILE_MANAGER_WINDOW;
               } else if (langId != "") {
                  thiscfg=CFG_UNICODE_SOURCE_WINDOW;
               } else if (i.p_UTF8) {
                  thiscfg=CFG_UNICODE_SOURCE_WINDOW;
               }
            }
         }
         if (thiscfg==cfg) {
            buffers_done:[i.p_buf_id] = true;
            i.p_redraw=false;
            i.p_font_name      = font_name;
            i.p_font_size      = font_size;
            i.p_font_bold      = (font_flags & F_BOLD)!=0;
            i.p_font_italic    = (font_flags & F_ITALIC)!=0;
            i.p_font_underline = (font_flags & F_UNDERLINE)!=0;
            i.p_font_strike_thru = (font_flags & F_STRIKE_THRU)!=0;
            i.p_font_charset=charset;
            if (update_editor_font && !i.p_IsMinimap) {
               font_info := font_name','font_size','font_flags','charset;
               i.p_BufferFontInfo = font_info;
            }
            i.p_redraw=true;
         }
         if (thiscfg==minimap_cfg && minimap_cfg!=MAXINT) {
            buffers_done:[i.p_buf_id] = true;
            i.p_redraw=false;
            i.p_font_name      = minimap_font_name;
            i.p_font_size      = minimap_font_size;
            /*i.p_font_bold      = (font_flags & F_BOLD)!=0;
            i.p_font_italic    = (font_flags & F_ITALIC)!=0;
            i.p_font_underline = (font_flags & F_UNDERLINE)!=0;
            i.p_font_strike_thru = (font_flags & F_STRIKE_THRU)!=0;
            i.p_font_charset=charset;*/
            if (update_minimap_font && i.p_IsMinimap) {
               font_info := minimap_font_name','minimap_font_size;
               i.p_MinimapFontInfo = font_info;
            }
            i.p_redraw=true;
         }
      }
   }

   // update the rest of the open buffers if using multiple-files-share window
   if (def_one_file == "") {
      activate_window(VSWID_HIDDEN);
      _safe_hidden_window();
      first_buf_id := p_buf_id;
      for (;;) {
         if (!buffers_done._indexin(p_buf_id) && (langId == null || langId == p_LangId || langId == ALL_LANGUAGES_ID)) {
            int thiscfg=MAXINT;
            if (update_minimap_font) {
               if (langId != "") {
                  thiscfg=CFG_UNICODE_MINIMAP_WINDOW;
               } else if (p_UTF8) {
                  thiscfg=CFG_UNICODE_MINIMAP_WINDOW;
               } else {
                  thiscfg=CFG_SBCS_DBCS_MINIMAP_WINDOW;
               }
            }
            if (update_editor_font) {
               thiscfg=CFG_SBCS_DBCS_SOURCE_WINDOW;
               if (p_hex_mode) {
                  thiscfg=CFG_HEX_SOURCE_WINDOW;
               } else if (p_LangId=='fileman') {
                  thiscfg=CFG_FILE_MANAGER_WINDOW;
               } else if (langId != "") {
                  thiscfg=CFG_UNICODE_SOURCE_WINDOW;
               } else if (p_UTF8) {
                  thiscfg=CFG_UNICODE_SOURCE_WINDOW;
               }
            }
            if (update_editor_font && thiscfg==cfg) {
               font_info := font_name','font_size','font_flags','charset;
               p_BufferFontInfo = font_info;
            }
            if (update_minimap_font && thiscfg==minimap_cfg && minimap_cfg!=MAXINT) {
               font_info := minimap_font_name','minimap_font_size;
               p_MinimapFontInfo = font_info;
            }
         }
         _next_buffer("HNR");
         if ( p_buf_id==first_buf_id ) break;
      }
   }
   p_window_id = orig_wid;

   if (langId == "") {
      new_default :=  font_name','font_size','font_flags','charset;
      _default_font(cfg, new_default);
      _set_font_profile_property(cfg,font_name,font_size,font_flags,charset);
   } else {
      default_font_info := _default_font(cfg);
      parse default_font_info with auto default_font_name ',' auto default_font_size ',' auto default_font_flags ',' auto default_font_charset ',' .;
      if (font_name == default_font_name) font_name = "";
      if (font_size == default_font_size) font_size = 0;
      if (font_flags == default_font_flags) font_flags = 0;
      if (charset == default_font_charset) charset = VSCHARSET_DEFAULT;
      se.lang.api.LanguageSettings.setFontInfo(langId,cfg,font_name,font_size,font_flags,charset);
   }
}


void _okay.lbutton_up()
{
   update_sample_text();
   font_info := _font_get_result();
   if (font_info == "") {
      return;
   }
   if (!_scope.p_visible) {
      p_active_form._delete_window(font_info);
      return;
   }

   langId := "";
   font_name := "";
   typeless font_size=0;
   typeless font_flags=0;
   typeless charset='';
   parse font_info with font_name ',' font_size ',' font_flags ','charset ',' ;
   if (!isinteger(charset)) {
      charset=VSCHARSET_DEFAULT;
   }

   wid := _form_parent(); //_mdi.p_child;
   if (wid && wid._isEditorCtl(false)) {
      langId = wid.p_LangId;
   }

   if (_just_window.p_value) {
      p_active_form._delete_window(1);
      wid.p_redraw=false;
      wid.p_font_name        = font_name;
      wid.p_font_size        = font_size;
      wid.p_font_bold        = font_flags & F_BOLD;
      wid.p_font_italic      = font_flags & F_ITALIC;
      wid.p_font_underline   = font_flags & F_UNDERLINE;
      wid.p_font_strike_thru = font_flags & F_STRIKE_THRU;
      wid.p_font_charset=charset;
      if (wid.p_IsMinimap) {
         wid.p_MinimapFontInfo = font_info;
      } else {
         wid.p_BufferFontInfo = font_info;
      }
      wid.p_redraw=true;
      generate_change_current_macro(font_name, font_size, font_flags,charset);

   } else if (_lang_changes.p_enabled && _lang_changes.p_value) {

      p_active_form._delete_window(1);
      typeless cfg=CFG_SBCS_DBCS_SOURCE_WINDOW;
      if (wid && wid._isEditorCtl(false)) {
         if (wid.p_hex_mode) {
            cfg=CFG_HEX_SOURCE_WINDOW;
         } else if (wid.p_LangId=='fileman') {
            cfg=CFG_FILE_MANAGER_WINDOW;
         } else if (wid.p_UTF8) {
            cfg=CFG_UNICODE_SOURCE_WINDOW;
         }
      }
      _change_all_wfonts(font_name, font_size, font_flags, charset, cfg, langId);
      generate_change_all_macro(font_name, font_size, font_flags, charset, cfg, langId);

   } else {
      p_active_form._delete_window(1);
      typeless cfg=CFG_SBCS_DBCS_SOURCE_WINDOW;
      if (wid && wid._isEditorCtl(false)) {
         if (wid.p_hex_mode) {
            cfg=CFG_HEX_SOURCE_WINDOW;
         } else if (wid.p_LangId=='fileman') {
            cfg=CFG_FILE_MANAGER_WINDOW;
         } else if (wid.p_UTF8) {
            cfg=CFG_UNICODE_SOURCE_WINDOW;
         }
      }
      _change_all_wfonts(font_name, font_size, font_flags,charset,cfg);
      generate_change_all_macro(font_name, font_size, font_flags,charset,cfg);
   }
}

void _reset.lbutton_up()
{
   langId := "";
   wid := _form_parent(); //_mdi.p_child;
   if (wid && wid._isEditorCtl(false)) {
      langId = wid.p_LangId;
   }

   default_font_info := "";
   lang_font_info := "";
   if (wid) {
      cfg_font := wid._get_default_font_setting_constant(true);
      lang_font_info = se.lang.api.LanguageSettings.getFontInfo(langId, cfg_font);
      cfg_font = wid._get_default_font_setting_constant(false);
      default_font_info = _default_font(cfg_font);
   } else {
      default_font_info = _default_font(CFG_UNICODE_SOURCE_WINDOW);
   }

   parse default_font_info with auto font_name ',' auto font_size ',' auto font_flags ',' auto font_charset ',' .;
   if (!_global_changes.p_value ) {
      parse lang_font_info with auto lang_font_name ',' auto lang_font_size ',' auto lang_font_flags ',' auto lang_font_charset ',' .;
      if (lang_font_name != "") font_name = lang_font_name;
      if (lang_font_size != "") font_size = lang_font_size;
      if (lang_font_flags != "") font_flags = lang_font_flags;
      if (lang_font_charset != "") font_charset = lang_font_charset;
   }

   font_info := font_name ',' font_size ',' font_flags ',' font_charset;
   createFontForm("", font_info);
}

/**
 * Displays <b>Window Font dialog box</b> which allows you to 
 * change the font for the current MDI edit window or all MDI edit 
 * windows.
 * 
 * @appliesTo Edit_Window, Editor_Control
 * @categories Forms, Edit_Window_Methods, Editor_Control_Methods
 */ 
_command void wfont,window_font() name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL)
{
   typeless param2 = _font_props2flags();
   show('-modal -xy -wh _wfont_form',
        'f',
        _font_param(p_font_name,p_font_size,param2,p_font_charset)
       );

}

static int _OnUpdate_wfont_zoom_in_or_out(CMDUI cmdui,int target_wid,_str command,int plusminus_one)
{
   if ( !target_wid || !target_wid._isEditorCtl() ) {
      return(MF_GRAYED);
   }
   int font_size=(int)target_wid.p_font_size;
   if (plusminus_one>0) {
      font_size+=1;
   } else {
      font_size-=1;
   }
   if ( font_size<=0 || font_size>128 )  {
      return(MF_GRAYED);
   }

   return(MF_ENABLED);
}
int _OnUpdate_wfont_zoom_in(CMDUI cmdui,int target_wid,_str command) {
   return _OnUpdate_wfont_zoom_in_or_out(cmdui,target_wid,command,1);
}
int _OnUpdate_wfont_zoom_out(CMDUI cmdui,int target_wid,_str command) {
   return _OnUpdate_wfont_zoom_in_or_out(cmdui,target_wid,command,-1);
}
/**
 * Modify the font size for the current editor window.
 * 
 * @param size  font size change amount<ul>
 *    <li><b> +n </b> -- increase font size by 'n' pixels
 *    <li><b> -n </b> -- decrease font size by 'n' pixels
 *    <li><b> n </b> -- set font size to 'n'
 *    </ul>
 * 
 * @appliesTo Edit_Window, Editor_Control
 * @categories Edit_Window_Methods, Editor_Control_Methods 
 *  
 * @see wfont_zoom_in 
 * @see wfont_zoom_out 
 * @see wfont_unzoom
 */
_command void wfont_zoom(_str size="+1") name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL)
{
   static bool last_attempt_failed;
   if (!isnumber(size)) {
      if (!last_attempt_failed) {
         _message_box("Font size must be an integer");
      }
      last_attempt_failed=true;
      return;
   }
   
   font_name := p_font_name;
   font_size := (int)p_font_size*10;
   _xlat_font(font_name,font_size);
   //if (font_name!=p_font_name) {
   font_size=font_size intdiv 10;
   //}
   int new_size = font_size;
   if (substr(size,1,1)=='-' || substr(size,1,1)=='+') {
      new_size = font_size + (int)size;
   } else {
      new_size = (int) size;
   }
   if (new_size <= 0 || new_size > 128) {
      /*
      A user complained about this message.
      if (!last_attempt_failed) {
         _message_box("Font size is out of range");
      } */
      last_attempt_failed=true;
      return;
   }
   last_attempt_failed=false;
   if (font_size != new_size) {
      p_font_name = font_name;
      p_font_size = new_size;
      if (def_one_file == "") {
         if (p_IsMinimap) {
            p_MinimapFontInfo = font_name','new_size;
         } else {
            p_BufferFontInfo = font_name','new_size;
         }
      }
   }
}
/**
 * Increase the font size for the current editor window.
 * 
 * @param size   (default=1) amount to increment font size
 * 
 * @appliesTo Edit_Window, Editor_Control
 * @categories Edit_Window_Methods, Editor_Control_Methods
 * @see wfont_zoom
 * @see wfont_unzoom
 * @see wfont_zoom_out
 */
_command void wfont_zoom_in(_str size="1") name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL|VSARG2_MARK)
{
   wfont_zoom("+":+size);
}
/**
 * Decrease the font size for the current editor window.
 * 
 * @param size   (default=1) amount to decrement font size
 * 
 * @appliesTo Edit_Window, Editor_Control
 * @categories Edit_Window_Methods, Editor_Control_Methods
 * @see wfont_zoom
 * @see wfont_unzoom
 * @see wfont_zoom_in
 */
_command void wfont_zoom_out(_str size="1") name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL|VSARG2_MARK)
{
   wfont_zoom("-":+size);
}

int _get_default_font_setting_constant(bool for_lang_specific_setting=false)
{
   use_unicode := (p_UTF8 || for_lang_specific_setting);
   if (_isdiff_editor_window(p_window_id)) {
      return (use_unicode? CFG_UNICODE_DIFF_EDITOR_WINDOW : CFG_DIFF_EDITOR_WINDOW);
   }
   if (p_IsMinimap) {
      return (use_unicode? CFG_UNICODE_MINIMAP_WINDOW : CFG_SBCS_DBCS_MINIMAP_WINDOW);
   }
   if (!for_lang_specific_setting && p_hex_mode != HM_HEX_OFF) {
      return CFG_HEX_SOURCE_WINDOW;
   }
   if (!for_lang_specific_setting && p_LangId == "fileman") {
      return CFG_FILE_MANAGER_WINDOW;
   }
   return (use_unicode? CFG_UNICODE_SOURCE_WINDOW : CFG_SBCS_DBCS_SOURCE_WINDOW);
}

_str _get_default_editor_font_info()
{
  font_info := se.lang.api.LanguageSettings.getEditorFontInfo(p_LangId);
  parse font_info with auto font_name ',' auto font_size ',' auto font_flags ',' auto font_charset ',' .;

  if (p_UTF8) {
     font_info = _default_font(CFG_UNICODE_SOURCE_WINDOW);
  } else {
     font_info = _default_font(CFG_SBCS_DBCS_SOURCE_WINDOW);
  }
  parse font_info with auto def_font_name ',' auto def_font_size ',' auto def_font_flags ',' auto def_font_charset ',' .;
   
  if (font_name == "") font_name = def_font_name;
  if (font_size == "" || font_size == 0) font_size = def_font_size;
  if (font_flags == "") font_flags = def_font_flags;
  if (font_charset == "") font_charset = def_font_charset;

  return font_name ',' font_size ',' font_flags ',' font_charset;
}

_str _get_default_minimap_font_info()
{
  font_info := se.lang.api.LanguageSettings.getMinimapFontInfo(p_LangId);
  parse font_info with auto font_name ',' auto font_size ',' auto font_flags ',' auto font_charset ',' .;

  if (p_UTF8) {
     font_info = _default_font(CFG_UNICODE_MINIMAP_WINDOW);
  } else {
     font_info = _default_font(CFG_SBCS_DBCS_MINIMAP_WINDOW);
  }
  parse font_info with auto def_font_name ',' auto def_font_size ',' auto def_font_flags ',' auto def_font_charset ',' .;
   
  if (font_name == "") font_name = def_font_name;
  if (font_size == "" || font_size == 0) font_size = def_font_size;
  if (font_flags == "") font_flags = def_font_flags;
  if (font_charset == "") font_charset = def_font_charset;

  return font_name ',' font_size ',' font_flags ',' font_charset;
}

static int _get_unzoom_font_size() 
{
   font_info := p_IsMinimap? p_MinimapFontInfo : p_BufferFontInfo;
   parse font_info with . ',' auto font_size ',' .;

   if(def_one_file=='') {
      font_size=0;
   }

   if (font_size == "" || font_size == 0 || !isinteger(font_size)) {
      cfg_font := _get_default_font_setting_constant(true);
      font_info = se.lang.api.LanguageSettings.getFontInfo(p_LangId, cfg_font);
      parse font_info with . ',' font_size ',' .;
   }

   if (font_size == "" || font_size == 0 || !isinteger(font_size)) {
      cfg_font := _get_default_font_setting_constant(false);
      font_info = _default_font(cfg_font);
      parse font_info with . ',' font_size ',' .;
   }

   if (isinteger(font_size)) {
      return (int)font_size;
   }
   return 10;
}

int _OnUpdate_wfont_unzoom(CMDUI cmdui,int target_wid,_str command) {
   if ( !target_wid || !target_wid._isEditorCtl() ) {
      return(MF_GRAYED);
   }
   int font_size=(int)target_wid.p_font_size;
   unzoom_font_size:=target_wid._get_unzoom_font_size();
   if (font_size==unzoom_font_size) {
      return(MF_GRAYED);
   }
   return(MF_ENABLED);
}
/**
 * Reset the font size to the default font size for this editor window.
 * 
 * @appliesTo Edit_Window, Editor_Control
 * @categories Edit_Window_Methods, Editor_Control_Methods
 * @see wfont_zoom
 * @see wfont_zoom_in
 * @see wfont_zoom_out
 */
_command void wfont_unzoom() name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL)
{
   font_size:=_get_unzoom_font_size();
   wfont_zoom(font_size);
}


#if 0
_command reset_wfonts()
{
   last=_last_window_id();
   for (i=1;i<=last;++i) {
      if ((_iswindow_valid(i)) && (i.p_mdi_child) && (i.p_HasBuffer < 0)){
         i.p_font_name        = 'Courier'
         i.p_font_size        = 10;
         i.p_font_bold        = 0;
         i.p_font_italic      = 0;
         i.p_font_underline   = 0;
         i.p_font_strike_thru = 0;
      }
   }
}
#endif

void _wfont_form.on_resize()
{
   clientWidth := _dx2lx(SM_TWIP,p_client_width);
   clientHeight := _dy2ly(SM_TWIP,p_client_height);
   borderX := _scope.p_x;
   borderY := _scope.p_y;

   // enforce minimum form with and height
   minWidth  := borderX + 2*label1.p_width + borderX + ctlfixedfonts.p_width + /* in place of font name list */
                borderX + _font_size_list.p_width + 
                borderX + frame1.p_width +
                borderX;
   altWidth := borderX + 
               3*_just_window.p_x + 
               _just_window.p_width + 
               _lang_changes.p_width + 
               _global_changes.p_width + 
               borderX;
   if (altWidth > minWidth) minWidth = altWidth;

   minHeight := borderY + _scope.p_height + 
                borderY + frame1.p_height + 
                borderY + (frame1.p_height intdiv 2) + /* in place of sample height */
                borderY + _okay.p_height +
                borderY;
   p_active_form._set_minimum_size(minWidth, minHeight);

   // scope frame
   scope_bottom := borderY;
   if (_scope.p_visible) {
      alignControlsHorizontal(borderX*2, borderY*2, 
                              borderX*2,
                              _just_window.p_window_id, 
                              _lang_changes.p_window_id,
                              _global_changes.p_window_id);

      _scope.p_width = clientWidth - 2*borderX;
      _scope.p_height = _just_window.p_y_extent + borderY;
      scope_bottom = _scope.p_y_extent;
   }

   // style frame
   alignControlsVertical(borderX*2, borderY*2, 
                         PADDING_BETWEEN_CONTROL_BUTTONS, 
                         _bold.p_window_id, 
                         _italic.p_window_id, 
                         _strikethrough.p_window_id, 
                         _underline.p_window_id);


   frame1.p_width = 3*borderX + max(_bold.p_width, _italic.p_width, _strikethrough.p_width, _underline.p_width);
   frame1.p_x = clientWidth - borderX - frame1.p_width;
   frame1.p_height = _underline.p_y_extent + borderY;
   frame1.p_y = scope_bottom + borderY;
   
   // size information
   label3.p_y = scope_bottom + borderY;
   label3.p_x = frame1.p_x - borderX - _font_size_list.p_width;
   _font_size_list.p_x = label3.p_x;
   _font_size_list.p_y = label3.p_y_extent + (borderY intdiv 2);
   _font_size_list.p_width = 2*borderX + _font_size_list._text_width("12345678");
   _font_size_list.p_height = frame1.p_y_extent - _font_name_list.p_y;

   // font name information
   label1.p_x = borderX;
   label1.p_y = scope_bottom + borderY;
   _font_name_list.p_x = borderX;
   _font_name_list.p_y = _font_size_list.p_y;
   _font_name_list.p_width = _font_size_list.p_x - _font_name_list.p_x - borderX;

   // fixed fonts only check box
   ctlfixedfonts.p_x = label1.p_x_extent + 2*borderX;
   ctlfixedfonts.p_y = label1.p_y - max(0, (ctlfixedfonts.p_height - label1.p_height) intdiv 2);

   // height distribution
   buttonY := clientHeight - borderY - _okay.p_height;
   avail_height := buttonY - 2*borderY - _font_name_list.p_y;
   font_name_height := avail_height intdiv 2;
   if (_font_name_list.p_y+font_name_height < frame1.p_y_extent) {
      font_name_height = frame1.p_y_extent - _font_name_list.p_y;
   }
   sample_height := avail_height - font_name_height;
   max_sample_height := 3*frame1.p_height intdiv 2; 
   if (sample_height > max_sample_height) {
      font_name_height += (sample_height - max_sample_height);
      sample_height = max_sample_height;
   }
   _font_name_list.p_height = font_name_height;
   _font_size_list.p_height = font_name_height;

   // sample code
   _sample_frame.p_x = borderX;
   _sample_frame.p_y = _font_name_list.p_y_extent + borderY;
   _sample_frame.p_width = clientWidth - 2*borderX;
   _sample_frame.p_height = sample_height;
   picture1.p_x = borderX;
   picture1.p_width = _sample_frame.p_width - 2*borderX;
   picture1.p_height = _dy2ly(SM_TWIP, _sample_frame.p_client_height);
   _sample_text.p_x = 0;
   _sample_text.p_y = 0;
   _sample_text.p_width = picture1.p_width;
   _sample_text.p_height = picture1.p_height;

   // buttons
   alignControlsHorizontal(borderX, buttonY, 2*borderX,
                           _okay.p_window_id,
                           _cancel.p_window_id,
                           _help.p_window_id,
                           _reset.p_window_id);
}

