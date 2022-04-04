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
#import "color.e"
#import "dlgeditv.e"
#import "files.e"
#import "listbox.e"
#import "picture.e"
#import "recmacro.e"
#import "setupext.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "tagfind.e"
#import "util.e"
#import "se/color/ColorScheme.e"
#import "se/color/DefaultColorsConfig.e"
#endregion

/**
 * Displays <b>Window Color dialog box</b> which allows you to change 
 * the color scheme for the current MDI edit window or all MDI edit windows.
 * 
 * @appliesTo Edit_Window, Editor_Control
 * @categories Forms, Edit_Window_Methods, Editor_Control_Methods
 */ 
_command void window_color() name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL)
{
   show('-modal -xy -wh _window_color_form', '', p_WindowColorProfile, p_window_id);
}


defeventtab _window_color_form;

/**
 * Document name for color coding sample text buffer.
 */
static const SAMPLE_COLOR_FORM_DOC_NAME= ".Sample Window Color Preview Window Buffer";

/**
 * Store the buffer ID of the color coding sample text buffer in its p_user.
 */
static int SampleColorEditWindowBufferID(...) 
{
   if (arg()) ctl_code_sample.p_user=arg(1);
   return ctl_code_sample.p_user;
}

/**
 * Store the editor window ID for the window that launched this form. 
 */
static int ParentEditorWindowID(...) 
{
   if (arg()) _okay.p_user=arg(1);
   return _okay.p_user;
}

/**
 * Displays <b>Window Color dialog box</b> which allows you to change
 * the color profile for the current MDI edit window or all MDI edit windows.
 * 
 * @param options       'C' to work as a simple color profile chooser
 * @param color_profile specifies the color profile that should be used
 *                      to initialize the dialog box.
 * @param editor_wid    editor control to modify color for
 * 
 * @example void show('_window_color_form', <i>options</i> , <i>color_profile</i> , <i>buf_id</i> ,' <i>line_no</i>)
 * 
 * @see window_color
 */ 
void _okay.on_create(_str options="",_str color_profile="",int editor_wid=0, int line_no=1, _str langId="")
{
   // load default profiles and the current symbol coloring profile
   se.color.DefaultColorsConfig dcc;
   dcc.loadFromDefaultColors();
   
   // hide the scope controls if this is just a color profile picker.
   if (upcase(_first_char(options)) == 'C') {
      _scope.p_visible = _scope.p_enabled = false;
      options = substr(options,2);
      p_active_form.p_caption = "Select Color Profile";
   }
   
   // load all the profile names into the combo box, putting
   // user defined profiles at the top of the list.
   if (color_profile == "") color_profile = def_color_scheme;
   ctl_scheme._lbaddColorProfileNames(dcc);
   ctl_scheme._cbset_text(se.color.ColorScheme.addProfilePrefix(color_profile));

   // set up the buffer name for the sample code buffer
   ctl_code_sample.docname(SAMPLE_COLOR_FORM_DOC_NAME);
   SampleColorEditWindowBufferID(ctl_code_sample.p_buf_id);

   // the small sample text needs to use the editor control font
   ctl_mode_name.p_enabled = false;
   ctl_mode_name._lbaddModeNames();
   if (_iswindow_valid(editor_wid) && editor_wid._isEditorCtl()) {
      ctl_mode_name._lbadd_item(VS_TAG_FIND_TYPE_BUFFER_ONLY);
      ctl_mode_name._cbset_text(VS_TAG_FIND_TYPE_BUFFER_ONLY);
      ParentEditorWindowID(editor_wid);
   } else {
      ParentEditorWindowID(0);
   }
   ctl_mode_name._lbsort();
   ctl_mode_name.p_enabled = true;

   // load the current window into the sample code, and copy the font settings
   if (_iswindow_valid(editor_wid) && editor_wid._isEditorCtl()) {
      ctl_code_sample.p_buf_id           = editor_wid.p_buf_id;
      ctl_code_sample.p_line             = editor_wid.p_line;
      ctl_code_sample.p_col              = editor_wid.p_col;
      ctl_code_sample.p_font_name        = editor_wid.p_font_name;       
      ctl_code_sample.p_font_size        = editor_wid.p_font_size;       
      ctl_code_sample.p_font_bold        = editor_wid.p_font_bold;       
      ctl_code_sample.p_font_italic      = editor_wid.p_font_italic;     
      ctl_code_sample.p_font_underline   = editor_wid.p_font_underline;  
      ctl_code_sample.p_font_strike_thru = editor_wid.p_font_strike_thru;
      ctl_code_sample.p_font_charset     = editor_wid.p_font_charset;
      ctl_code_sample.center_line();
      _lang_changes.p_caption = "All \"" :+ editor_wid.p_mode_name :+ "\" files";
   } else if (langId != "") {
      ctl_mode_name._cbset_text(_LangId2Modename(langId));
      _lang_changes.p_caption = "All \"" :+ _LangId2Modename(langId) :+ "\" files";
      _lang_changes.p_value = 1;
   } else {
      _lang_changes.p_caption = "";
      _lang_changes.p_enabled = false;
      _lang_changes.p_visible = false;
      _lang_changes.p_value = 0;
   }

   // do not want the minimap here
   //ctl_code_sample.p_show_minimap = false;
}

void _window_color_form.on_load()
{
   ctl_scheme._set_focus();
}

static void generate_change_all_macro(_str langId, _str profile_name, bool update_editor_colors, bool update_minimap_colors)
{
   _macro('m',_macro('s'));
   _macro_call("_change_all_window_colors", langId, profile_name, update_editor_colors, update_minimap_colors);
}

static void generate_change_current_macro(_str profile_name)
{
   _macro('m',_macro('s'));
   _macro_append("p_color_name = "_quote(profile_name)";");
}

/**
 * Changes the color scheme of all MDI edit windows.  
 *  
 * @param langId                 Limit to the given language settings
 * @param scheme_name            Color scheme name
 * @param update_editor_colors   Update editor windows
 * @param update_minimap_colors  Update minimap windows
 * 
 * @categories Window_Functions
 */
void _change_all_window_colors(_str langId,
                               _str profile_name, 
                               bool update_editor_colors, 
                               bool update_minimap_colors)
{
   if (update_editor_colors) {
      if (langId == null) {
         def_color_scheme = profile_name;
         se.color.ColorScheme colorProfile;
         real_profile_name := se.color.ColorScheme.realProfileName(profile_name);
         colorProfile.loadProfile(real_profile_name);
         colorProfile.applyColorProfile();
         colorProfile.applySymbolColorProfile();
      } else {
         se.lang.api.LanguageSettings.setColorProfile(langId, profile_name);
      }
   }

   if (update_minimap_colors) {
      if (langId == null) {
         def_minimap_color_scheme = profile_name;
         se.color.ColorScheme colorProfile;
         real_profile_name := se.color.ColorScheme.realProfileName(profile_name);
         followEditorProfile := false;
         if (real_profile_name == "") {
            real_profile_name = def_color_scheme;
            followEditorProfile = true;
         }
         colorProfile.loadProfile(real_profile_name);
         colorProfile.applyMinimapColorProfile(real_profile_name, followEditorProfile);
      } else {
         se.lang.api.LanguageSettings.setMinimapColorProfile(langId, profile_name);
      }
   }

   orig_wid := p_window_id;
   bool buffers_done:[];
   last := _last_window_id();
   for (i:=1; i<=last; ++i) {
      if (_iswindow_valid(i) && i._isEditorCtl(false) && !i.p_IsTempEditor) {
         if (langId != null && langId != i.p_LangId) {
            continue;
         }
         int thiscfg=MAXINT;
         if (update_minimap_colors && i.p_IsMinimap) {
            buffers_done:[i.p_buf_id] = true;
            i._ResetColorProfileForEditor();
         }
         if (update_editor_colors && !i.p_IsMinimap) {
            buffers_done:[i.p_buf_id] = true;
            i._ResetColorProfileForEditor();
         }
      }
   }

   // update the rest of the open buffers if using multiple-files-share window
   if (def_one_file == "") {
      activate_window(VSWID_HIDDEN);
      _safe_hidden_window();
      first_buf_id := p_buf_id;
      for (;;) {
         if (!buffers_done._indexin(p_buf_id) && (langId == null || langId == p_LangId)) {
            _ResetColorProfileForEditor(allowHiddenWindow:true);
         }
         _next_buffer("HNR");
         if ( p_buf_id==first_buf_id ) break;
      }
   }
   p_window_id = orig_wid;
}

void _okay.lbutton_up()
{
   profile_name := se.color.ColorScheme.removeProfilePrefix(ctl_scheme._lbget_text());
   if (profile_name == "") {
      return;
   }

   if (!_scope.p_visible) {
      p_active_form._delete_window(profile_name);
      return;
   }

   wid := ParentEditorWindowID();
   if (!wid || !_iswindow_valid(wid) || !wid._isEditorCtl()) {
      wid = _form_parent();
   }
   update_editor_colors  := !wid.p_IsMinimap;
   update_minimap_colors := wid.p_IsMinimap;

   if (_just_window.p_value) {
      p_active_form._delete_window(1);
      wid.p_redraw=false;
      if (wid.p_IsMinimap) {
         wid.p_MinimapColorProfile = profile_name;
      } else {
         wid.p_BufferColorProfile = profile_name;
      }
      wid.p_redraw=true;

      generate_change_current_macro(profile_name);
      // Call list for things like stream markers that need to be re-styled.
      call_list('reset_buffer_color_profile');
   } else if (_lang_changes.p_value) {

      p_active_form._delete_window(1);
      _change_all_window_colors(langId: wid.p_LangId, profile_name, update_editor_colors, update_minimap_colors);
      generate_change_all_macro(langId: wid.p_LangId, profile_name, update_editor_colors, update_minimap_colors);

   } else {
      p_active_form._delete_window(1);
      _change_all_window_colors(langId: null, profile_name, update_editor_colors, update_minimap_colors);
      generate_change_all_macro(langId: null, profile_name, update_editor_colors, update_minimap_colors);
   }
}

/** 
 * Change the mode name for the sample code. 
 */
void ctl_mode_name.on_change(int reason)
{
   // do nothing while loading modes
   if (!ctl_mode_name.p_enabled) {
      return;
   }

   // switching to the current file?
   if (p_text == VS_TAG_FIND_TYPE_BUFFER_ONLY) {
      if (!_no_child_windows()) {
         editor_wid := _mdi.p_child;
         if (ctl_code_sample.p_buf_id != editor_wid.p_buf_id) {
            ctl_code_sample._ClearSampleColorCode();
            ctl_code_sample.load_files("+q +m +bi "editor_wid.p_buf_id);
            //ctl_code_sample.p_buf_id = editor_wid.p_buf_id;
            //ctl_code_sample.p_buf_flags |= (VSBUFFLAG_HIDDEN|VSBUFFLAG_DELETE_BUFFER_ON_CLOSE);
            ctl_code_sample.p_line = editor_wid.p_line;
            ctl_code_sample.p_col = editor_wid.p_col;
            ctl_code_sample._ExitScroll();
            ctl_code_sample.center_line();
         }
         return;
      }
   }

   // if not using current file, shift back to original buffer
   switch (reason) {
   case CHANGE_CLINE_NOTVIS:
   case CHANGE_CLINE:
   case CHANGE_SELECTED:
      ctl_code_sample._ClearSampleColorCode();
      ctl_code_sample._SetEditorLanguage(_Modename2LangId(p_text));
      ctl_code_sample._GenerateSampleColorCode();
      break;
   }
}

/** 
 * Change the mode name for the sample code. 
 */
void ctl_scheme.on_change(int reason)
{
   // do nothing while loading modes
   if (!ctl_mode_name.p_enabled) {
      return;
   }

   // switching to the current file?
   profile_name := se.color.ColorScheme.removeProfilePrefix(ctl_scheme.p_text);
   if (profile_name == "") {
      return;
   }

   ctl_code_sample.p_WindowColorProfile = profile_name;
   ctl_code_sample.refresh('w');
}

void _window_color_form.on_resize()
{
   clientWidth := _dx2lx(SM_TWIP,p_client_width);
   clientHeight := _dy2ly(SM_TWIP,p_client_height);
   borderX := _scope.p_x;
   borderY := _scope.p_y;

   // enforce minimum form with and height
   minWidth  := borderX + ctl_scheme_label.p_width + 
                borderX + _just_window.p_width +
                borderX + _lang_changes.p_width +
                borderX + _global_changes.p_width + 
                borderX;
   minHeight := borderY + _scope.p_height + 
                borderY + ctl_scheme.p_height + 
                //borderY + ctl_minimap.p_height + 
                borderY + 5*ctl_mode_name.p_height + /* in place of sample height */
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

   // scheme name and combo box
   ctl_scheme_label.p_y = scope_bottom + borderY;
   ctl_scheme.p_y = ctl_scheme_label.p_y + (ctl_scheme.p_height - ctl_scheme_label.p_height) intdiv 2;
   ctl_scheme_label.p_x = borderX;
   //ctl_scheme.p_x = borderX + max(ctl_scheme_label.p_width, ctl_minimap_label.p_width) + borderX;
   ctl_scheme.p_x = borderX + ctl_scheme_label.p_width + borderX;
   ctl_scheme.p_width = clientWidth - borderX - ctl_scheme.p_x;
   scheme_bottom := max(ctl_scheme_label.p_y_extent, ctl_scheme.p_y_extent);

   /*
   // minimap scheme name and combo box
   if (ctl_minimap.p_visible) {
      ctl_minimap_label.p_y = scheme_bottom + (borderY intdiv 2);
      ctl_minimap.p_y = ctl_minimap_label.p_y + (ctl_minimap.p_height - ctl_minimap_label.p_height) intdiv 2;
      ctl_minimap_label.p_x = borderX;
      ctl_minimap.p_x = ctl_scheme.p_x;
      ctl_minimap.p_width = ctl_scheme.p_width;
      scheme_bottom = max(ctl_minimap_label.p_y_extent, ctl_minimap.p_y_extent);
   }
   */

   // sample frame
   ctl_sample_frame.p_x = borderX;
   ctl_sample_frame.p_y = scheme_bottom + borderY;
   ctl_sample_frame.p_height = clientHeight - ctl_sample_frame.p_y - _okay.p_height - 2*borderY;
   ctl_sample_frame.p_width = clientWidth - ctl_sample_frame.p_x - borderX;
   ctl_mode_name.p_width = max(_global_changes.p_width, ctl_sample_frame.p_width intdiv 4);
   ctl_mode_name.p_x = max(borderX + 3*ctl_scheme_label.p_width, (ctl_sample_frame.p_width - ctl_mode_name.p_width) intdiv 2);
   ctl_mode_name.p_y = 0;
   ctl_code_sample.p_x = borderX;
   ctl_code_sample.p_y = ctl_mode_name.p_y_extent + _dy2ly(SM_TWIP,4);
   ctl_code_sample.p_height = ctl_sample_frame.p_height - ctl_code_sample.p_y - _dy2ly(SM_TWIP,4);
   ctl_code_sample.p_width  = ctl_sample_frame.p_width - 2*borderX;
   ctl_code_sample._ExitScroll();
   ctl_code_sample.center_line();

   // buttons
   buttonY := clientHeight - _okay.p_height - borderY;
   alignControlsHorizontal(borderX, buttonY, 2*borderX,
                           _okay.p_window_id,
                           _cancel.p_window_id,
                           _help.p_window_id);
}


