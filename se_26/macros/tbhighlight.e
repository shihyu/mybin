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
#include "markers.sh"
#include "color.sh"
#import "cfg.e"
#import "diff.e"
#import "dlgman.e"
#import "files.e"
#import "listbox.e"
#import "main.e"
#import "markfilt.e"
#import "mprompt.e"
#import "picture.e"
#import "search.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "tagfind.e"
#import "treeview.e"
#import "sc/lang/ScopedTimeoutGuard.e"
#import "se/color/HighlightOptions.e"
#import "se/color/HighlightProfile.e"
#import "se/color/HighlightWordInfo.e"
#import "se/color/HighlightTextChangeListener.e"
#import "se/color/HighlightAnalyzer.e"
#import "se/color/SeekPositionRanges.e"
#import "se/color/SymbolColorAnalyzer.e"
#import "se/ui/ITextChangeListener.e"
#import "se/ui/TextChange.e"
#import "se/ui/toolwindow.e"
#endregion


/**
 * Pull in all the symbols from the se/color namespace. 
 * This is where the bulk of the highlight analyzer implementaion is. 
 */
using namespace se.color;


// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW CONSTANTS                                           ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * The name of the Highlight tool window form.
 */
static const HIGHLIGHT_FORM_NAME_STRING = "_tbhighlight_form";

/**
 * Key used to store and look up the color profile name last used to render 
 * word pattern colors in the Highlight tool window. 
 */
static const HIGHLIGHT_TW_KEY_COLOR_PROFILE_NAME = "COLOR_PROFILE_NAME";
/**
 * Key used to store and look up the previous highlight profile name
 * in the highlight tool window.  This is kept so that we can temporarily 
 * disable highlighting using the {@link highlight toggle_enabled} command, 
 * and then toggle it back to it's original settings. 
 */
static const HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME = "PREV_HIGHLIGHT_PROFILE_NAME";

/**
 * Key used to store and look up the current highlight profile, containing the 
 * array of word patterns displayed in the Highlight tool window. 
 * The tool window can have additional words that are tentatively added 
 * but not yet committed to the highlight profile. 
 */
static const HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO = "HIGHLIGHT_PROFILE_INFO";

/**
 * Key used to store and look the array of word indexes for the word patterns 
 * which were temporarily added to the list using the "Add words" text box. 
 */
static const HIGHLIGHT_TW_KEY_ADD_WORD_INDICES = "ADD_WORD_INDICES";

/**
 * Key used to store and look up whether highlight tool window controls 
 * should temporarily not respond to change events.  This is used, for example, 
 * when filling in the list of profile names or the list of word patterns 
 * in the tree control. 
 */
static const HIGHLIGHT_TW_KEY_NO_CHANGES = "NO_CHANGES";

/**
 * Tree column index for Highlight tool window word pattern "Enable" check box.
 */
static const HIGHLIGHT_TW_ENABLE_COLUMN = 0;
/**
 * Tree column index for Highlight tool window word pattern.
 */
static const HIGHLIGHT_TW_WORD_COLUMN   = 1;
/**
 * Tree column index for Highlight tool window word pattern type.
 */
static const HIGHLIGHT_TW_KIND_COLUMN   = 2;
/**
 * Tree column index for Highlight tool window word pattern case-sensitivity option.
 */
static const HIGHLIGHT_TW_CASE_COLUMN   = 3;
/**
 * Tree column index for Highlight tool window word pattern language mode restriction.
 */
static const HIGHLIGHT_TW_MODE_COLUMN   = 4;

/**
 * Tree column caption for Highlight tool window "Enabled" column.
 */
static const HIGHLIGHT_TW_ENABLE_CAPTION = "Enable";
/**
 * Tree column caption for Highlight tool window "Mode" column.
 */
static const HIGHLIGHT_TW_WORD_CAPTION   = "Word";
/**
 * Tree column caption for Highlight tool window "Kind" column.
 */
static const HIGHLIGHT_TW_KIND_CAPTION   = "Kind";
/**
 * Tree column caption for Highlight tool window "Case" column.
 */
static const HIGHLIGHT_TW_CASE_CAPTION   = "Case";
/**
 * Tree column caption for Highlight tool window "Mode" column.
 */
static const HIGHLIGHT_TW_MODE_CAPTION   = "Mode";


// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW GLOBAL VARAIBLES                                    ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * Global variable used to track the current active highlight profile. 
 * Generaly, the active profile is comes from the highlight tool window, but 
 * when there is no highlight tool window active, we use this setting. 
 *  
 * @note 
 * This setting is saved and restored with the current workspace. 
 */
static _str gHighlightCurrentProfile = HIGHLIGHT_DEFAULT_PROFILE_NAME;
/**
 * Global ariable used to track the previous active highlight profile. 
 * This is kept so that we can temporarily disable highlighting using 
 * the {@link highlight toggle_enabled} command, and then toggle it back to 
 * it's original settings. 
 *  
 * @note 
 * This should never be set to {@link HIGHLIGHT_DISABLE_PROFILE_NAME}.
 *  
 * @note 
 * This setting is saved and restored with the current workspace. 
 */
static _str gHighlightPreviousProfile = HIGHLIGHT_DEFAULT_PROFILE_NAME;

/**
 * This keeps track of all the currently open files which the highlight tool 
 * window is to color.  It's extent depends on the setting for 
 * {@link def_highlight_tw_windows}. 
 */
static VisibleTabsCache gHighlightTWVisibleTabs;

/** 
 * Table of all active Highlight tool window instances. 
 */
static int gHighlightFormList[];


// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW INITIALIZATION, SAVE, RESTORE                       ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * Module initialization code for Highlight tool window.
 */
definit()
{
   // recalculate the list of active Highlight tool window form instances
   last := _last_window_id();
   for (i:=1; i<=last; ++i) {
      if (_iswindow_valid(i) && i.p_object == OI_FORM && !i.p_edit) {
         if (i.p_name :== HIGHLIGHT_FORM_NAME_STRING) {
            gHighlightFormList :+= i;
         }
      }
   }

   // reset the list of files to color
   _ResetVisibleFileTabs(gHighlightTWVisibleTabs);

   // do not need to reset settings if just reloading, only for initialization
   if ( arg(1) != 'L' ) {
      gHighlightCurrentProfile = null;
      gHighlightPreviousProfile = null;
   }
}

/**
 * Save/restore current and previous highlight profile name.
 * 
 * @param options     save/restore options ('R' or 'N' to load settings)
 * @param info        info to restore
 * 
 * @return 
 * Returns 0 on success.
 */
int _sr_tbhighlight(_str options = "", _str info = "")
{
   if (options == 'R' || options == 'N') {
      // restore values
      parse info with auto currentProfile auto previousProfile .;
      gHighlightCurrentProfile = _maybe_unquote_filename(currentProfile);
      gHighlightPreviousProfile = _maybe_unquote_filename(previousProfile);
   } else if (gHighlightCurrentProfile != null && gHighlightCurrentProfile != "") {
      insert_line("TBHIGHLIGHT: \""gHighlightCurrentProfile"\" \""gHighlightPreviousProfile"\"");
      down();
   }
   return(0);
}


// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW UTILITY FUNCTIONS                                   ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * @return 
 * Return the active edtior control for the current highlight tool window form, 
 * which is expected to be the current window.
 */
static int GetHighlightTWActiveEditor()
{
   // try to find the active editor control for this MDI child
   editorctl_wid := p_active_form._MDIGetActiveMDIChild();
   if (editorctl_wid && editorctl_wid._isEditorCtl()) {
      return editorctl_wid;
   }
   return 0;
}

/**
 * @return 
 * Return the color profile for the active edtior control for the current 
 * highlight tool window form which is expected to be the current window.
 */
static _str GetHighlightTWActiveColorProfile()
{
   // try to find the active editor control for this MDI child
   editorctl_wid := p_active_form._MDIGetActiveMDIChild();
   if (editorctl_wid && editorctl_wid._isEditorCtl()) {
      return editorctl_wid.p_WindowColorProfile;
   }
   lastColorScheme := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_COLOR_PROFILE_NAME);
   if (lastColorScheme != null && length(lastColorScheme) > 0) {
      return lastColorScheme;
   }
   return def_color_scheme;
}

/**
 * @return 
 * Return {@code true} if the given form WID is a valid instance of 
 * an active Highlight tool window. 
 * 
 * @param form_wid    form window ID
 */
static bool HighlightTWIsValid(int form_wid)
{
   if (!_iswindow_valid(form_wid)) return false;
   if (form_wid.p_object != OI_FORM) return false;
   if (form_wid.p_name != HIGHLIGHT_FORM_NAME_STRING) return false;
   return true;
}

/**
 * @return 
 * Return the window ID of the active Highlight tool window form relative to 
 * the current window. 
 * 
 * @param twff_flags     bitset of TWFF_* flags (see {@link tw_find_form})  
 *
 * @categories Toolbar_Functions, Search_Functions
 */
int _tbGetActiveHighlightForm(int twff_flags=-1)
{
   return tw_find_form(HIGHLIGHT_FORM_NAME_STRING, 0, twff_flags);
}


// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW FORM HANDLING                                       ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * Event table for Highlight tool window.
 */
defeventtab _tbhighlight_form;

/**
 * @return 
 * Returns {@literal 'E'} for exact case (case-sensitive), 
 * {@literal 'I'} for ignore case (case-insenstivie), or 
 * {@literal 'A'} for language dependent case sensitivity.
 * 
 * @param v               case-sensitivity check box value
 * @param editorctl_wid   editor control window
 */
static _str GetHighlightCaseOption(_str v, int editorctl_wid=0)
{
   switch (v) {
   case 1:
      return 'E';
   case 2:
      if (editorctl_wid && editorctl_wid._isEditorCtl()) {
         return (editorctl_wid.p_LangCaseSensitive? 'E' : 'I');
      }
      return 'A';
   case 0:
   default:
      return 'I';
   }
}

/**
 * @return 
 * Returns the language mode ID depending on the language option.
 * 
 * @param v               language specific check box value
 * @param editorctl_wid   editor control window
 */
static _str GetHighlightModeOption(int v, int editorctl_wid=0)
{
   if (!editorctl_wid) {
      if (_isEditorCtl()) {
         editorctl_wid = p_window_id;
      } else if (p_active_form) {
         editorctl_wid = p_active_form._MDIGetActiveMDIChild();
      }
   }

   if (v > 0 && editorctl_wid && editorctl_wid._isEditorCtl()) {
      return editorctl_wid.p_LangId;
   }
   return "";
}

/**
 * Add the highlight word pattern list to the tree control on the 
 * Highlight tool window.
 * 
 * @param profileName       highlight profile name
 * @param words             list of word patterns to add
 * @param colorSchemeName   (optional) editor control color profile name
 */
static void HighlightTWAddWordsToTree(_str profileName,
                                      HighlightWordInfo (&words)[], 
                                      _str colorSchemeName="")
{
   if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      _TreeDelete(TREE_ROOT_INDEX, 'C');
      return;
   }

   // make sure we have the color scheme information
   if (colorSchemeName == "") {
      colorSchemeName = GetHighlightTWActiveColorProfile();
   }

   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_COLOR_PROFILE_NAME, colorSchemeName);
   _TreeBeginUpdate(TREE_ROOT_INDEX);

   // add the words to the tree for the current profile
   fg_color := bg_color := 0;
   font_flags := 0;
   foreach (auto i => auto wordInfo in words) {
      if (wordInfo._isempty()) continue;
      word := wordInfo.getEscapedWordPattern();
      kind_caption := wordInfo.getWordKindCaption();
      case_caption := wordInfo.getWordCaseCaption();
      mode_caption := wordInfo.getLanguageModeCaption();
      wordInfo.getHighlightWordColor(colorSchemeName, fg_color, bg_color, font_flags);
      node := _TreeAddItem(TREE_ROOT_INDEX, "\t"word"\t"kind_caption"\t"case_caption"\t"mode_caption, TREE_ADD_AS_CHILD, 0, 0, TREE_NODE_LEAF, 0, i);
      _TreeSetCheckable(node, 1, 0, (wordInfo.m_enabled? TCB_CHECKED : TCB_UNCHECKED), HIGHLIGHT_TW_ENABLE_COLUMN);
      _TreeSetColor(node, HIGHLIGHT_TW_WORD_COLUMN, fg_color, bg_color, font_flags);
   }

   _TreeEndUpdate(TREE_ROOT_INDEX);
   _TreeRefresh();
}

/**
 * Highlight tool window form creation.
 */
void ctl_highlight_words.on_create()
{
   // save the form wid
   gHighlightFormList :+= p_active_form;

   // configure settings for colors to use
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
   ctl_draw_box.p_value             = (def_highlight_tw_options & HIGHLIGHT_TW_DRAW_BOX_TEXT      )? 1:0;
   ctl_scroll_markers.p_value       = (def_highlight_tw_options & HIGHLIGHT_TW_DRAW_SCROLL_MARKERS)? 1:0;
   ctl_match_language.p_value       = (def_highlight_tw_options & HIGHLIGHT_TW_RESTRICT_LANGUAGE  )? 1:0;
   ctl_match_case.p_value           = (def_highlight_tw_options & HIGHLIGHT_TW_CASE_SENSITIVE     )? 1:0;
   if (def_highlight_tw_options & HIGHLIGHT_TW_CASE_LANGUAGE) {
      ctl_match_case.p_value = 2;
   }
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);

   // resize the buttons to add/remove a profile
   sizeBrowseButtonToTextBox(ctl_profile.p_window_id, 
                             ctl_add_profile.p_window_id, 
                             ctl_del_profile.p_window_id, 
                             ctl_profile_label.p_x);

   // resize the help button for the words to add
   sizeBrowseButtonToTextBox(ctl_add_label.p_window_id, 
                             ctl_add_help.p_window_id);

   // resize the options expand/collapse button
   ctl_style_options_button.resizeToolButtonToLabel(ctl_style_options_label.p_window_id);
   ctl_new_options_button.resizeToolButtonToLabel(ctl_new_options_label.p_window_id);

   // load the profile names from the configuration settings, 
   // always have a "Default" profile name first
   HighlightProfile.addProfilesToList(ctl_profile);
   ctl_profile._cbset_text(HIGHLIGHT_DEFAULT_PROFILE_NAME);

   // restore previous profile name
   ctl_profile._retrieve_value();
   if (ctl_profile.p_text != "") {
      gHighlightCurrentProfile = ctl_profile.p_text;
      if (ctl_profile.p_text != HIGHLIGHT_DISABLE_PROFILE_NAME) {
         gHighlightPreviousProfile = ctl_profile.p_text;
      }
   } else {
      ctl_profile._cbset_text(HIGHLIGHT_DEFAULT_PROFILE_NAME);
   }

   // get the current profile name
   profileName := gHighlightCurrentProfile;
   if (profileName == "") {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }
   ctl_profile._cbset_text(profileName);
   HighlightProfile profileInfo;
   profileInfo.loadProfile(profileName);
   if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME, HIGHLIGHT_DEFAULT_PROFILE_NAME);
   } else {
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME, profileName);
   }

   // add the different highlight styles to the combo box
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
   HighlightOptions.textStyleCaptionList(auto highlightStyleCaptions);
   foreach (auto caption in highlightStyleCaptions) {
      ctl_style_type._lbadd_item(caption);
   }
   ctl_style_type._cbset_text(HIGHLIGHT_STYLE_COLOR_TEXT);
   caption = HighlightOptions.textStyleCaption((HighlightToolWindowOptions)(def_highlight_tw_options & HIGHLIGHT_TW_USE_STYLE_MASK));
   if (caption != "" && !pos(',', caption)) {
      ctl_style_type._cbset_text(caption);
   }
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);

   // set up the column captions for the tree control.
   HighlightWordInfo.wordKindCaptionList(auto highlightWordCaptions);
   HighlightWordInfo.wordCaseCaptionList(auto highlightCaseCaptions);
   HighlightWordInfo.languageModeCaptionList(auto highlightModeCaptions);

   // calculate longest "Enable", "Kind", "Case", and "Mode" captions
   enable_width := ctl_highlight_words._text_width(HIGHLIGHT_TW_ENABLE_CAPTION) + 2*ctl_highlight_words.p_x;
   kind_width := HighlightWordInfo.wordKindCaptionWidth(ctl_highlight_words.p_window_id, HIGHLIGHT_TW_KIND_CAPTION);
   case_width := HighlightWordInfo.wordCaseCaptionWidth(ctl_highlight_words.p_window_id, HIGHLIGHT_TW_CASE_CAPTION);
   mode_width := HighlightWordInfo.languageModeCaptionWidth(ctl_highlight_words.p_window_id, HIGHLIGHT_TW_MODE_CAPTION);
   kind_width += 2*ctl_highlight_words.p_x;
   case_width += 2*ctl_highlight_words.p_x;
   mode_width += 2*ctl_highlight_words.p_x;

   // now set up the column information for tree
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_ENABLE_COLUMN, enable_width, TREE_BUTTON_FIXED_WIDTH, -1, HIGHLIGHT_TW_ENABLE_CAPTION);
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_WORD_COLUMN, 2100, 0, -1, HIGHLIGHT_TW_WORD_CAPTION);
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_KIND_COLUMN, kind_width, TREE_BUTTON_FIXED_WIDTH, -1, HIGHLIGHT_TW_KIND_CAPTION);
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_CASE_COLUMN, case_width, TREE_BUTTON_FIXED_WIDTH, -1, HIGHLIGHT_TW_CASE_CAPTION);
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_MODE_COLUMN, mode_width, TREE_BUTTON_FIXED_WIDTH, -1, HIGHLIGHT_TW_MODE_CAPTION);
   ctl_highlight_words._TreeSetColEditStyle(HIGHLIGHT_TW_WORD_COLUMN, TREE_EDIT_TEXTBOX);
   ctl_highlight_words._TreeSetColEditStyle(HIGHLIGHT_TW_KIND_COLUMN, TREE_EDIT_COMBOBOX);
   ctl_highlight_words._TreeSetColEditStyle(HIGHLIGHT_TW_CASE_COLUMN, TREE_EDIT_COMBOBOX);
   ctl_highlight_words._TreeSetColEditStyle(HIGHLIGHT_TW_MODE_COLUMN, TREE_EDIT_COMBOBOX);
   ctl_highlight_words._TreeSetComboDataCol(HIGHLIGHT_TW_KIND_COLUMN, highlightWordCaptions);
   ctl_highlight_words._TreeSetComboDataCol(HIGHLIGHT_TW_CASE_COLUMN, highlightCaseCaptions);
   ctl_highlight_words._TreeSetComboDataCol(HIGHLIGHT_TW_MODE_COLUMN, highlightModeCaptions);

   // add the words to the tree for the current profile
   HighlightTWAddWordsToTree(profileName, profileInfo.m_words);

   // adjust alignment for auto-sized button
   ctl_style_options_button._retrieve_value();
   ctl_style_options_label.p_x = ctl_style_options_button.p_x_extent + _dx2lx(SM_TWIP,5);
   ctl_style_options_button.p_user = ctl_style_options_button.p_value;

   // adjust alignment for auto-sized button
   ctl_new_options_button._retrieve_value();
   ctl_new_options_label.p_x = ctl_new_options_button.p_x_extent + _dx2lx(SM_TWIP,5);
   ctl_new_options_button.p_user = ctl_new_options_button.p_value;

   // restore regular expression types and last regex used
   ctl_regex_type._lbadd_item(RE_TYPE_SLICKEDIT_STRING);
   ctl_regex_type._lbadd_item(RE_TYPE_PERL_STRING);
   ctl_regex_type._lbadd_item(RE_TYPE_VIM_STRING);
   //ctl_regex_type._lbadd_item(RE_TYPE_WILDCARD_STRING);
   ctl_regex_type._retrieve_value();
   if (ctl_regex_type.p_text == "") {
      if (def_re_search_flags & VSSEARCHFLAG_RE) {
         ctl_regex_type.p_text = RE_TYPE_SLICKEDIT_STRING;
      //} else if (def_re_search_flags & VSSEARCHFLAG_WILDCARDRE) {
      //   ctl_regex_type.p_text = RE_TYPE_WILDCARD_STRING;
      } else if (def_re_search_flags & VSSEARCHFLAG_VIMRE) {
         ctl_regex_type.p_text = RE_TYPE_VIM_STRING;
      } else {
         ctl_regex_type.p_text = RE_TYPE_PERL_STRING;
      }
   }

   // retrieve the words left behind in the text box
   ctl_add_words._retrieve_value();
}

/**
 * Save settings before destroying Highlight tool window form.
 */
void _tbhighlight_form.on_destroy()
{
   ctl_profile._append_retrieve(ctl_profile, ctl_profile.p_text);
   ctl_regex_type._append_retrieve(ctl_regex_type, ctl_regex_type.p_text);
   ctl_add_words._append_retrieve(ctl_add_words, ctl_add_words.p_text);
   ctl_style_options_button._append_retrieve(ctl_style_options_button, ctl_style_options_button.p_value);
   ctl_new_options_button._append_retrieve(ctl_new_options_button, ctl_new_options_button.p_value);

   // Call user-level2 ON_DESTROY so that tool window docking info is saved
   call_event(p_window_id,ON_DESTROY,'2');
}

/**
 * Highlight tool window resize code.
 */
void _tbhighlight_form.on_resize()
{
   // if the minimum width has not been set, it will return 0
   if (!tw_is_docked_window(p_active_form) && !_minimum_width()) {
      min_width := 3*max(ctl_profile_label.p_width,
                         ctl_add_label.p_width,
                         ctl_style_label.p_width,
                         ctl_regex_label.p_width);
      min_width = max(min_width,
                      ctl_draw_box.p_width,
                      ctl_scroll_markers.p_width,
                      ctl_match_language.p_width,
                      ctl_match_case.p_width);
      min_width += 2*ctl_draw_box.p_x;
      min_width += 2*ctl_new_options_frame.p_x;
      min_height := ctl_highlight_words.p_y + 8*ctl_profile.p_height;
      _set_minimum_size(min_width, min_height);
   }

   // available space and border usage
   xpadding := ctl_add_words.p_x;
   ypadding := ctl_profile.p_y;
   avail_width  := _dx2lx(SM_TWIP,p_client_width)  - 2*xpadding;
   avail_height := _dy2ly(SM_TWIP,p_client_height) - 2*ypadding;

   // lay out style options frame
   expand_style_options := (ctl_style_options_button.p_value == 1);
   if (ctl_style_options_button.p_user == null || ctl_style_options_button.p_user != expand_style_options) {
      ctl_style_label.p_enabled = expand_style_options;
      ctl_style_type.p_enabled = expand_style_options;
      ctl_draw_box.p_enabled = expand_style_options;
      ctl_scroll_markers.p_enabled = expand_style_options;
      if (expand_style_options) {
         ctl_style_label.p_y = max(ctl_style_options_button.p_y_extent, ctl_style_options_label.p_y_extent) + ypadding;
         ctl_style_type.p_y  = ctl_style_label.p_y;
         ctl_draw_box.p_y = ctl_style_type.p_y_extent + ypadding;
         ctl_scroll_markers.p_y = ctl_draw_box.p_y_extent + ypadding;
         ctl_style_options_frame.p_height = ctl_scroll_markers.p_y_extent + ypadding;
      } else {
         ctl_style_options_frame.p_height = ctl_style_options_label.p_y_extent + ypadding;
      }
   }

   // lay out new word options frame
   expand_new_options := (ctl_new_options_button.p_value == 1);
   if (ctl_new_options_button.p_user == null || ctl_new_options_button.p_user != expand_new_options) {
      ctl_match_case.p_enabled = expand_new_options;
      ctl_match_language.p_enabled = expand_new_options;
      ctl_regex_label.p_enabled = expand_new_options;
      ctl_regex_type.p_enabled = expand_new_options;
      if (expand_new_options) {
         ctl_regex_label.p_y = max(ctl_new_options_button.p_y_extent, ctl_new_options_label.p_y_extent) + ypadding;
         ctl_regex_type.p_y  = ctl_regex_label.p_y;
         ctl_match_case.p_y = ctl_regex_type.p_y_extent + ypadding;
         ctl_match_language.p_y = ctl_match_case.p_y_extent + ypadding;
         ctl_new_options_frame.p_height = ctl_match_language.p_y_extent + ypadding;
      } else {
         ctl_new_options_frame.p_height = ctl_new_options_label.p_y_extent + ypadding;
      }
   }

   // resize widths
   ctl_profile.p_x             = ctl_profile_label.p_x_extent + xpadding;
   ctl_del_profile.p_x         = avail_width - ctl_del_profile.p_width;
   ctl_add_profile.p_x         = ctl_del_profile.p_x - xpadding - ctl_add_profile.p_width;
   ctl_profile.p_width         = ctl_add_profile.p_x - xpadding - ctl_profile.p_x;
   ctl_add_words.p_width       = avail_width;
   ctl_highlight_words.p_width = avail_width;
   ctl_style_options_frame.p_width = avail_width;
   ctl_new_options_frame.p_width   = avail_width;
   ctl_style_type.p_x          = max(ctl_style_label.p_x_extent, ctl_regex_label.p_x_extent) + 2*xpadding;
   ctl_style_type.p_width      = avail_width - ctl_style_type.p_x - 2*xpadding;
   ctl_regex_type.p_x          = ctl_style_type.p_x;
   ctl_regex_type.p_width      = ctl_style_type.p_width;

   // calculate longest "Enable", "Kind", "Case", and "Mode" captions
   enable_width := ctl_highlight_words._text_width(HIGHLIGHT_TW_ENABLE_CAPTION) + 2*xpadding;
   kind_width := HighlightWordInfo.wordKindCaptionWidth(ctl_highlight_words.p_window_id, HIGHLIGHT_TW_KIND_CAPTION);
   case_width := HighlightWordInfo.wordCaseCaptionWidth(ctl_highlight_words.p_window_id, HIGHLIGHT_TW_CASE_CAPTION);
   mode_width := HighlightWordInfo.languageModeCaptionWidth(ctl_highlight_words.p_window_id, HIGHLIGHT_TW_MODE_CAPTION);
   kind_width += 2*ctl_highlight_words.p_x;
   case_width += 2*ctl_highlight_words.p_x;
   mode_width += 2*ctl_highlight_words.p_x;
   if (5*mode_width > ctl_highlight_words.p_width) {
      mode_width = ctl_highlight_words._text_width(HIGHLIGHT_TW_MODE_CAPTION) + 4*xpadding;
   }

   // set column widths for tree control
   scrollbar_width := _dx2lx(SM_TWIP, ctl_highlight_words._TreeGetVScrollBarWidth());
   border_width := ctl_highlight_words._TreeGetBorderWidth();
   margin_width := max(ctl_highlight_words._TreeGetIconWidth(), ctl_highlight_words.p_LevelIndent);
   column_width := (avail_width - margin_width - enable_width - kind_width - case_width - mode_width - scrollbar_width - 2*border_width - 4*xpadding);
   column_width_available := (avail_width - margin_width - enable_width - scrollbar_width - 2*border_width - 4*xpadding);
   if (column_width < enable_width + max(kind_width, case_width, mode_width)) {
      column_width = enable_width + max(kind_width, case_width, mode_width);
      if (column_width > column_width_available) column_width = enable_width;
   }
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_ENABLE_COLUMN, enable_width, TREE_BUTTON_FIXED_WIDTH, -1, HIGHLIGHT_TW_ENABLE_CAPTION);
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_WORD_COLUMN, column_width, 0, -1, HIGHLIGHT_TW_WORD_CAPTION);
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_KIND_COLUMN, kind_width, TREE_BUTTON_FIXED_WIDTH, -1, HIGHLIGHT_TW_KIND_CAPTION);
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_CASE_COLUMN, case_width, TREE_BUTTON_FIXED_WIDTH, -1, HIGHLIGHT_TW_CASE_CAPTION);
   ctl_highlight_words._TreeSetColButtonInfo(HIGHLIGHT_TW_MODE_COLUMN, mode_width, TREE_BUTTON_FIXED_WIDTH, -1, HIGHLIGHT_TW_MODE_CAPTION);

   // resize heights
   ctl_add_label.p_y = ctl_profile.p_y_extent + ypadding;
   ctl_add_help.p_y  = ctl_add_label.p_y;
   ctl_add_words.p_y = ctl_add_label.p_y_extent + ypadding;
   ctl_highlight_words.p_y = ctl_add_words.p_y_extent + ypadding;
   ctl_highlight_words.p_height = max(2*ctl_add_words.p_height,  avail_height - ctl_style_options_frame.p_height - ctl_new_options_frame.p_height - ctl_highlight_words.p_y - ypadding);
   ctl_style_options_frame.p_y = ctl_highlight_words.p_y_extent + ypadding;
   ctl_new_options_frame.p_y = ctl_style_options_frame.p_y_extent + ypadding;

   if ( !(p_window_flags & VSWFLAG_ON_RESIZE_ALREADY_CALLED) ) {
      // First time
      ctl_highlight_words._TreeRetrieveColButtonInfo();
   }
}

/**
 * Update the "Style" options label for the Highlight tool window.
 * 
 * @param flags    (output) bitset of HIGHLIGHT_TW_* flags
 */
static void HighlightTWUpdateStyleOptionsLabel(HighlightToolWindowOptions &flags)
{
   caption := "Style: " :+ ctl_style_type.p_text;
   flags = HighlightOptions.textStyleOption(ctl_style_type.p_text);

   if (ctl_draw_box.p_value) {
      _maybe_append(caption, ", ");
      caption :+= "Draw box";
      flags |= HIGHLIGHT_TW_DRAW_BOX_TEXT;
   }
   if (ctl_scroll_markers.p_value) {
      _maybe_append(caption, ", ");
      caption :+= "Scrollbar markup";
      flags |= HIGHLIGHT_TW_DRAW_SCROLL_MARKERS;
   }

   ctl_style_options_label.p_caption = caption;
}

/**
 * Update the "New word" options label for the Highlight tool window.
 * 
 * @param flags    (output) bitset of HIGHLIGHT_TW_* flags
 */
static void HighlightTWUpdateNewWordOptionsLabel(HighlightToolWindowOptions &flags)
{
   caption := "New words use: ";

   switch (ctl_regex_type.p_text) {
   case RE_TYPE_SLICKEDIT_STRING:
      caption :+= HighlightWordInfo.captionFromWordKind('R');
      break;
   case RE_TYPE_PERL_STRING:
      caption :+= HighlightWordInfo.captionFromWordKind('L');
      break;
   case RE_TYPE_VIM_STRING:
      caption :+= HighlightWordInfo.captionFromWordKind('V');
      break;
   case RE_TYPE_WILDCARD_STRING:
      caption :+= HighlightWordInfo.captionFromWordKind('&');
      break;
   }

   caption :+= ", ";
   switch (ctl_match_case.p_value) {
   case 0: 
      caption :+= HighlightWordInfo.captionFromCaseOption('I');
      break;
   case 1: 
      caption :+= HighlightWordInfo.captionFromCaseOption('E');
      flags |= HIGHLIGHT_TW_CASE_SENSITIVE;   
      break;
   case 2: 
      caption :+= HighlightWordInfo.captionFromCaseOption('A');
      flags |= HIGHLIGHT_TW_CASE_LANGUAGE;   
      break;
   default:
      caption :+= HighlightWordInfo.captionFromCaseOption('I');
      break;
   }

   caption :+= ", ";
   if (ctl_match_language.p_value) {
      caption :+= "Current languages";
   } else {
      caption :+= "All languages";
   }

   ctl_new_options_label.p_caption = caption;
}

/**
 * Toggle expand/collapse of Highlight tool window "Style" options.
 */
void ctl_style_options_button.lbutton_up()
{
   HighlightTWUpdateStyleOptionsLabel(auto flags);
   p_active_form.call_event(p_active_form, ON_RESIZE);
   ctl_style_options_button.p_user = ctl_style_options_button.p_value;
   p_active_form.call_event(p_active_form, ON_RESIZE);
}

/**
 * Toggle expand/collapse of Highlight tool window "New word" options.
 */
void ctl_new_options_button.lbutton_up()
{
   HighlightTWUpdateNewWordOptionsLabel(auto flags);
   p_active_form.call_event(p_active_form, ON_RESIZE);
   ctl_new_options_button.p_user = ctl_new_options_button.p_value;
}

/**
 * Toggle whether to draw a box around the highlighted items.
 */
void ctl_draw_box.lbutton_up()
{
   flags := HIGHLIGHT_TW_NULL;
   HighlightTWUpdateStyleOptionsLabel(flags);
   HighlightTWUpdateNewWordOptionsLabel(flags);
   if (flags != def_highlight_tw_options) {
       def_highlight_tw_options = flags;
       _config_modify_flags(CFGMODIFY_DEFVAR);

       profileName := ctl_profile.p_text;
       if (profileName == null || profileName=="") {
          profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
       }
       ctl_add_words.call_event(ctl_add_words.p_window_id, ON_CHANGE);

       HighlightProfile *pProfileInfo = p_active_form._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
       if (pProfileInfo != null && *pProfileInfo instanceof se.color.HighlightProfile) {
          ctl_highlight_words.HighlightTWAddWordsToTree(profileName, pProfileInfo->m_words);
          HighlightAnalyzer.clearHighlightMarkers();
          HighlightProfile.incrementSavedGeneration(profileName);
          _ResetWordHighlightingForAllFiles();
       }
   }
}

/**
 * Select the default regular expression type use when adding new word patterns.
 */
void ctl_regex_type.on_change()
{
   ignoringChanges := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES);
   if (ignoringChanges != null && ignoringChanges == true) {
      return;
   }

   flags := HIGHLIGHT_TW_NULL;
   HighlightTWUpdateStyleOptionsLabel(flags);
   HighlightTWUpdateNewWordOptionsLabel(flags);
}

/**
 * Select the style of highlighting colors to use.
 */
void ctl_style_type.on_change()
{
   ignoringChanges := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES);
   if (ignoringChanges != null && ignoringChanges == true) {
      return;
   }

   ctl_draw_box.call_event(ctl_draw_box.p_window_id, LBUTTON_UP);
}

/**
 * Select whether to to use case-sensitive word pattern matching or not.
 */
void ctl_match_case.lbutton_up()
{
   ignoringChanges := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES);
   if (ignoringChanges != null && ignoringChanges == true) {
      return;
   }

   ctl_draw_box.call_event(ctl_draw_box.p_window_id, LBUTTON_UP);
}

/**
 * Select whether to add new words as language specific words or not.
 */
void ctl_match_language.lbutton_up()
{
   ignoringChanges := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES);
   if (ignoringChanges != null && ignoringChanges == true) {
      return;
   }

   ctl_draw_box.call_event(ctl_draw_box.p_window_id, LBUTTON_UP);
}

/**
 * Callback to check if the highlight tool window profile name a user gave 
 * is valid. 
 * 
 * @param name     profile name to check.
 * 
 * @return 
 * Returns {@literal 0} if the profile name is valid, {@literal &lt;0} otherwise.
 */
int _check_highlight_tw_profile_name(_str name)
{
   if (pos("[~\\p{L}\\p{N}a-zA-Z0-9 -]", name, 1, 'ir')) {
      _message_box('Invalid profile name.');
      return INVALID_ARGUMENT_RC;
   }
   if (name == "" || name == HIGHLIGHT_DEFAULT_PROFILE_NAME || name == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      _message_box('Invalid profile name.');
      return INVALID_ARGUMENT_RC;
   }
   HighlightProfile.listProfiles(auto profileNames);
   foreach (auto usedName in profileNames) {
      if (usedName == name) {
         _message_box('Profile name already exists.');
         return INVALID_ARGUMENT_RC;
      }
   }
   return 0;
}

/**
 * Add a new highlight profile.
 */
void ctl_add_profile.lbutton_up()
{
   status := textBoxDialog("Enter New Profile Name", 0, 0, "New Highlight Profile dialog", "", "", 
                          "-e _check_highlight_tw_profile_name: Profile name:");
   if (status < 0 || _param1 == "") return;
   profileName := _param1;
   ctl_profile._cbset_text(profileName);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME, profileName);
   HighlightWordInfo emptyArray[];
   gHighlightCurrentProfile = profileName;
   gHighlightPreviousProfile = profileName;
   HighlightProfile.incrementSavedGeneration(profileName);
   HighlightAnalyzer.clearHighlightMarkers();
   ctl_add_words._set_focus();
}

/**
 * Delete or reset the current highlight profile in the Highlight tool window.
 */
void ctl_del_profile.lbutton_up()
{
   // get the current profile name from the combo box
   profileName := ctl_profile.p_text;
   if (profileName == null || profileName=="") {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }

   // and delete it
   highlight_delete_profile(profileName);

   // update the window closest to this form
   child_wid := _MDIGetActiveMDIChild();
   if (child_wid) {
      _UpdateHighlightsToolWindow(p_active_form, child_wid, AlwaysUpdate:true);
      child_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}

/**
 * Delete or reset the current highlight profile in the Highlight tool window.
 */
void ctl_profile.DEL()
{
   ctl_del_profile.call_event(ctl_del_profile.p_window_id, LBUTTON_UP);
}

/**
 * Callback for handling switching highlight profiles in the Highlight tool window.
 * 
 * @param reason     change reason
 * @param index      current item
 */
void ctl_profile.on_change(int reason, int index=0)
{
   ignoringChanges := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES);
   if (ignoringChanges != null && ignoringChanges == true) {
      return;
   }

   profileName := ctl_profile.p_text;
   if (profileName == null || profileName=="") {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }

   if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      if (ctl_add_words.p_enabled) {
         ctl_add_label.p_enabled = false;
         ctl_add_help.p_enabled  = false;
         ctl_add_words.p_enabled = false;
         ctl_del_profile.p_enabled = false;
         ctl_highlight_words.p_enabled = false;
         ctl_style_options_frame.p_enabled = false;
         ctl_new_options_frame.p_enabled = false;
      }
   } else if (!ctl_add_words.p_enabled) {
      ctl_add_label.p_enabled = true;
      ctl_add_help.p_enabled  = true;
      ctl_add_words.p_enabled = true;
      ctl_del_profile.p_enabled = true;
      ctl_highlight_words.p_enabled = true;
      ctl_style_options_frame.p_enabled = true;
      ctl_new_options_frame.p_enabled = true;
   }

   if (p_text == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      gHighlightPreviousProfile = gHighlightCurrentProfile;
   } else {
      gHighlightPreviousProfile = p_text;
   }

   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
   HighlightProfile.incrementSavedGeneration(profileName);
   gHighlightCurrentProfile = p_text;
   HighlightProfile profileInfo;
   profileInfo.loadProfile(profileName);
   ctl_highlight_words.HighlightTWAddWordsToTree(profileName, profileInfo.m_words);
   ctl_add_words.p_text = "";
   HighlightAnalyzer.clearHighlightMarkers();

   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME, profileName);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, profileInfo);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, null);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);
}

/**
 * Callback for handling changes to highlight word patterns.
 * 
 * 
 * @param reason         change reason
 * @param index          index of item selected in tree
 * @param col            column index
 * @param text           (in/out) item text
 * @param combobox_wid   (optional) window ID of combo box control selected
 * 
 * @return 
 * Returns {@literal 0} on success. 
 * Returns {@literal -1} if you try to edit a column which is not editable. 
 */
int ctl_highlight_words.on_change(int reason, int index, int col=0, _str &text="", int combobox_wid=0)
{
   // check if we are in th middle of something important
   ignoringChanges := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES);
   if (ignoringChanges != null && ignoringChanges == true) {
      return 0;
   }

   // invalid tree index?
   if (index <= 0) {
      return 0;
   }

   // get the currently selected profile name
   profileName := ctl_profile.p_text;
   if (profileName == null || profileName=="") {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }

   // disabled means do not do anything
   if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return 0;
   }

   // get the highlight profile information object (including list of words)
   HighlightProfile *pProfileInfo = p_active_form._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
   if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
      return 0;
   }

   // get the word index for the selected item, make sure it is valid
   user_info := _TreeGetUserInfo(index);
   if (user_info == null || !isinteger(user_info)) {
      return 0;
   }
   wordIndex := user_info;
   if (!pProfileInfo->isValidWordIndex(wordIndex)) {
      return 0;
   }

   // now get the word info for this item
   wordInfo := pProfileInfo->getWordPattern(wordIndex);
   origWordInfo := wordInfo;

   // check what happened
   switch (reason) {
   case CHANGE_SELECTED:
      break;

   // toggling enabled
   case CHANGE_CHECK_TOGGLED:
      wordInfo.m_enabled = (_TreeGetCheckState(index, 0) != 0);
      if (!wordInfo.m_enabled) {
         child_wid := p_active_form._MDIGetActiveMDIChild();
         if (child_wid) {
            HighlightAnalyzer.clearHighlightMarkersWithIndex(child_wid, wordIndex);
         }
      }
      break;

   // editing word text
   case CHANGE_LEAF_ENTER:
      if (col == 0 || col == HIGHLIGHT_TW_WORD_COLUMN) {
         _TreeEditNode(index, HIGHLIGHT_TW_WORD_COLUMN);
      }
      return 0;

   // want to edit column info
   case CHANGE_EDIT_PROPERTY:
      switch (col) {
      case HIGHLIGHT_TW_WORD_COLUMN:
         return -1;
      case HIGHLIGHT_TW_KIND_COLUMN:
      case HIGHLIGHT_TW_CASE_COLUMN:
      case HIGHLIGHT_TW_MODE_COLUMN:
         return TREE_EDIT_COLUMN_BIT|col;
      default:
         return -1;
      }

   // done editing a column
   case CHANGE_EDIT_CLOSE:
      switch (col) {
      case HIGHLIGHT_TW_WORD_COLUMN:
         wordInfo.setEscapedWordPattern(text);
         break;
      case HIGHLIGHT_TW_KIND_COLUMN:
         wordInfo.m_wordKind = HighlightWordInfo.wordKindFromCaption(text);
         break;
      case HIGHLIGHT_TW_CASE_COLUMN:
         wordInfo.m_caseOption = HighlightWordInfo.wordCaseFromCaption(text);
         break;
      case HIGHLIGHT_TW_MODE_COLUMN:
         wordInfo.m_langId = HighlightWordInfo.langIdFromCaption(text);
         break;
      default:
         return -1;
      }

   // anything else do nothing
   default:
      break;
   }

   // update and save the profile if the word has been changed
   if (wordInfo != origWordInfo) {

      // if they manually edit a temporarily added word, commit it to the list
      int addWordIndexes[] = p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES);
      if (addWordIndexes != null) {
         foreach (auto i => auto tempWordIndex in addWordIndexes) {
            if (tempWordIndex == wordIndex) {
               addWordIndexes._deleteel(i);
               p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, addWordIndexes);
               break;
            }
         }

         // maybe remove the word from the "Add words" text box
         if (wordInfo.m_wordPattern != origWordInfo.m_wordPattern ||
             wordInfo.m_wordKind    != origWordInfo.m_wordKind) {
            addWordsText := ctl_add_words.p_text;
            defaultCaseOption := GetHighlightCaseOption(ctl_match_case.p_value);
            defaultRegexType := HighlightWordInfo.wordKindFromCaption(ctl_regex_type.p_text);
            defaultLangMode := GetHighlightModeOption(ctl_match_language.p_value);
            RemoveNewHighlightWordFromText(addWordsText, origWordInfo, 
                                           defaultRegexType, defaultCaseOption, defaultLangMode);
            ctl_add_words.p_text = strip(addWordsText);
         }
      }

      // replace the word information in the profile information and save
      pProfileInfo->replaceWordPattern(wordIndex, wordInfo);
      pProfileInfo->saveProfile(profileName);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, *pProfileInfo);
      HighlightProfile.incrementSavedGeneration(profileName);

      // update the window closest to this form
      child_wid := _MDIGetActiveMDIChild();
      if (child_wid) {
         _UpdateHighlightsToolWindow(p_active_form, child_wid, AlwaysUpdate:true);
         child_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
      }
   }

   // that's all folks
   return 0;
}

/**
 * Delete the currently selected word pattern (or multiple word patternss) 
 * in the Highlight tool window.
 */
void ctl_highlight_words.DEL()
{
   int selected_items[];
   num_selected := _TreeGetNumSelectedItems();
   if (num_selected > 0) {
      _TreeGetSelectionIndices(selected_items);
   } else {
      selected_items[0] = _TreeCurIndex();
      if (selected_items[0] <= TREE_ROOT_INDEX) {
         return;
      }
   }

   lastColorScheme := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_COLOR_PROFILE_NAME);
   if (lastColorScheme == null) {
      lastColorScheme = "";
   }

   // get the highlight profile information object (including list of words)
   HighlightProfile *pProfileInfo = p_active_form._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
   if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
      return;
   }

   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
   for (i := num_selected-1; i>=0; --i) {
      user_info := _TreeGetUserInfo(selected_items[i]);
      if (user_info == null || !isinteger(user_info)) continue;
      wordIndex := user_info;

      origWordInfo := pProfileInfo->getWordPattern(wordIndex);
      pProfileInfo->deleteWordPattern(wordIndex);
      _TreeDelete(selected_items[i]);

      // maybe remove the word from the "Add words" text box
      int addWordIndexes[] = p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES);
      if (origWordInfo != null && ctl_add_words.p_text != "") {
         addWordsText := ctl_add_words.p_text;
         defaultCaseOption := GetHighlightCaseOption(ctl_match_case.p_value);
         defaultRegexType := HighlightWordInfo.wordKindFromCaption(ctl_regex_type.p_text);
         defaultLangMode := GetHighlightModeOption(ctl_match_language.p_value);
         RemoveNewHighlightWordFromText(addWordsText, origWordInfo,
                                        defaultRegexType, defaultCaseOption, defaultLangMode);
         ctl_add_words.p_text = strip(addWordsText);
      }

      // if they manually delete a temporarily added word, remove it from the list
      if (addWordIndexes != null) {
         foreach (auto j => auto tempWordIndex in addWordIndexes) {
            if (tempWordIndex == wordIndex) {
               addWordIndexes._deleteel(j);
               p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, addWordIndexes);
               break;
            }
         }
      }
   }

   profileName := ctl_profile.p_text;
   ctl_highlight_words.HighlightTWAddWordsToTree(profileName, pProfileInfo->m_words, lastColorScheme);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, *pProfileInfo);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);

   pProfileInfo->saveProfile();
   HighlightProfile.incrementSavedGeneration(profileName);

   // update the window closest to this form
   child_wid := _MDIGetActiveMDIChild();
   if (child_wid) {
      _UpdateHighlightsToolWindow(p_active_form, child_wid, AlwaysUpdate:true);
      child_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}

/**
 * Parse word patterns from words entered into the "Add words" checkbox 
 * on the Highlight tool window. 
 */
/**
 * Add word patterns to the list of word patterns in the Highlight tool window.
 * 
 * @param text                list of word patterns to add
 * @param wordArray           list of word patterns to append new items to
 * @param defaultRegexType    default regular exprssion type
 * @param defaultCaseOption   default case-sensitivity option
 * @param defaultLangMode     default langauge mode ID ("" for all languages)
 */
static void ParseHighlightWordsFromText(_str text, 
                                        HighlightWordInfo (&wordArray)[],
                                        int (&startPositions)[],
                                        int (&endPositions)[],
                                        _str defaultRegexType,
                                        _str defaultCaseOption,
                                        _str defaultLangMode)
{
   // go through list of words given and add them to the list
   orig_text_length := length(text);
   while (text != "") {
      text = strip(text, 'L');
      start_pos := orig_text_length - length(text); 
      HighlightWordInfo wordInfo;
      wordInfo.m_enabled = true;
      wordInfo.m_colorIndex = 0;
      wordInfo.m_caseOption = defaultCaseOption;
      wordInfo.m_langId = defaultLangMode;

      firstch := _first_char(text);
      if (firstch == '"' || firstch == "'") {
         // string search (no word boundaries)
         wordInfo.m_wordKind = 'S';
         lastch := "";
         string_pos := 0;
         if (firstch == '"') {
            string_pos = pos('"(?:[^"\\]++|\\.)*+("[eiw]?|)', text, 1, 'LI');
         } else {
            string_pos = pos("'(?:[^']++|'')*+('[eiw]?|)", text, 1, 'LI');
         }
         if (string_pos == 1) {
            len := pos('');
            wordInfo.m_wordPattern = substr(text,2,len-1);
            if (_last_char(wordInfo.m_wordPattern) == firstch) {
               wordInfo.m_wordPattern = substr(wordInfo.m_wordPattern, 1, length(wordInfo.m_wordPattern)-1);
            } else if (len > 1 && substr(text, len-1, 1) == firstch) {
               wordInfo.m_wordPattern = substr(wordInfo.m_wordPattern, 1, length(wordInfo.m_wordPattern)-2);
               lastch = substr(text,len,1);
            } else {
               wordInfo.m_wordPattern = substr(wordInfo.m_wordPattern, 1);
            }
            if (firstch == '"') {
               wordInfo.setEscapedWordPattern(wordInfo.m_wordPattern);
            } else {
               wordInfo.m_wordPattern = stranslate(wordInfo.m_wordPattern, "'", "''");
            }
            text = strip(substr(text, len+1));
         } else {
            // should never get here
            wordInfo.m_wordPattern = parse_file(text, returnQuotes:false);
         }
         switch (upcase(lastch)) {
         case 'E':
            wordInfo.m_caseOption = 'E';
            break;
         case 'I':
            wordInfo.m_caseOption = 'I';
            break;
         case 'W':
            wordInfo.m_wordKind = upcase(lastch);
            break;
         }

      } else if (firstch == '/' || firstch == '`') {
         // regular expression search
         wordInfo.m_wordKind = lowcase(defaultRegexType);
         lastch := "";
         re_pos := 0;
         if (firstch == '/') {
            re_pos = pos('/(?:[^/\\]++|\\.|/(?![ierlubv\~]{0,2}([ \t]|$)))*+(/[ierlubv\~]{0,2}|)', text, 1, 'LI');
         } else {
            re_pos = pos('`(?:[^\\`]++|\\.|`(?![ierlubv\~]{0,2}([ \t]|$)))*+(`[ierlubv\~]{0,2}|)', text, 1, 'LI');
         }
         if (re_pos == 1) {
            len := pos('');
            wordInfo.m_wordPattern = substr(text,2,len-1);
            if (_last_char(wordInfo.m_wordPattern) == firstch) {
               wordInfo.m_wordPattern = substr(wordInfo.m_wordPattern, 1, length(wordInfo.m_wordPattern)-1);
            } else if (len > 1 && substr(text, len-1, 1) == firstch) {
               wordInfo.m_wordPattern = substr(wordInfo.m_wordPattern, 1, length(wordInfo.m_wordPattern)-2);
               lastch = substr(text,len,1);
            } else if (len > 2 && substr(text, len-2, 1) == firstch) {
               wordInfo.m_wordPattern = substr(wordInfo.m_wordPattern, 1, length(wordInfo.m_wordPattern)-3);
               lastch = substr(text,len-1,2);
            } else {
               wordInfo.m_wordPattern = substr(wordInfo.m_wordPattern, 1);
            }
            wordInfo.setEscapedRegexPattern(wordInfo.m_wordPattern);
            text = strip(substr(text, len+1));
         } else if (firstch == '/') {
            parse text with '/' wordInfo.m_wordPattern '/' text;
         } else {
            parse text with '`' wordInfo.m_wordPattern '`' text;
         }
         while (lastch != "") {
            switch (_first_char(lastch)) {
            case 'e':
            case 'E':
               wordInfo.m_caseOption = 'E';
               break;
            case 'i':
            case 'I':
               wordInfo.m_caseOption = 'I';
               break;
            case 'R':
            case 'r':
               wordInfo.m_wordKind = lastch;
               break;
            case 'L':
            case 'U':
            case 'B':
               wordInfo.m_wordKind = 'L';
               break;
            case 'l':
            case 'u':
            case 'b':
               wordInfo.m_wordKind = 'l';
               break;
            case 'V':
               wordInfo.m_wordKind = 'V';
               break;
            case 'v':
            case '~':
               wordInfo.m_wordKind = 'v';
               break;
            }
            lastch = substr(lastch,2);
         }

      } else {
         // just a word
         parse text with wordInfo.m_wordPattern text;

         // double check that it works with default word boundaries,
         // if not treat it like a string
         wordInfo.m_wordKind = 'W';
         word_re := '\o<':+_escape_re_chars(wordInfo.m_wordPattern, 'L')'\o>';
         word_haystack := " BEFORE "wordInfo.m_wordPattern" AFTER ";
         if (pos(word_re, word_haystack, 1, 'L') <= 0) {
            wordInfo.m_wordKind = 'S';
         }

      }

      // just say no to empty words
      if (wordInfo.m_wordPattern == null || wordInfo.m_wordPattern == "") {
         continue;
      }

      // add the word to the list, and track where it came from
      wordArray :+= wordInfo;
      startPositions :+= start_pos;
      endPositions   :+= (orig_text_length - length(text));
   }
}

/**
 * Add word patterns to the list of word patterns in the Highlight tool window.
 * 
 * @param text                list of word patterns to add
 * @param wordArray           list of word patterns to append new items to
 * @param defaultRegexType    default regular exprssion type
 * @param defaultCaseOption   default case-sensitivity option
 * @param defaultLangMode     default langauge mode ID ("" for all languages)
 */
static void AddNewHighlightWords(_str text, 
                                 HighlightWordInfo (&wordArray)[],
                                 int (&addWordIndexes)[],
                                 _str defaultRegexType,
                                 _str defaultCaseOption,
                                 _str defaultLangMode)
{
   // find the highest color index used in the word array
   // and build a hash table of existing word patterns
   lastIndexUsed := -HIGHLIGHT_TW_LARGE_COLOR_INCREMENT;
   bool wordHash:[];
   foreach (auto wordInfo in wordArray) {
      if (wordInfo._isempty()) continue;
      wordHash:[wordInfo.m_wordKind:+wordInfo.m_wordPattern] = true;
      if (wordInfo.m_colorIndex > lastIndexUsed) {
         lastIndexUsed = wordInfo.m_colorIndex;
      }
   }

   // array of new words parsed out
   HighlightWordInfo newWordArray[];
   int startPositions[];
   int endPositions[];
   ParseHighlightWordsFromText(text, 
                               newWordArray, startPositions, endPositions, 
                               defaultRegexType, defaultCaseOption, defaultLangMode);

   // go through list of words found and add them
   foreach (wordInfo in newWordArray) {
      lastIndexUsed += HIGHLIGHT_TW_LARGE_COLOR_INCREMENT;
      wordInfo.m_colorIndex = lastIndexUsed;

      // just say no to empty words
      if (wordInfo.m_wordPattern == null || wordInfo.m_wordPattern == "") {
         continue;
      }

      // or words we already have
      if (!wordHash._indexin(wordInfo.m_wordKind:+wordInfo.m_wordPattern)) {
         addWordIndexes :+= wordArray._length();
         wordArray :+= wordInfo;
         wordHash:[wordInfo.m_wordKind:+wordInfo.m_wordPattern] = true;
      }
   }
}

/**
 * Remove characters from the string containing temporarily added words from 
 * the "Add words" text box which match the given word information. 
 * 
 * @param text           (reference) text from "Add words" text box
 * @param removeWordInfo word information for word being deleted
 */
static void RemoveNewHighlightWordFromText(_str &text, 
                                           HighlightWordInfo &removeWordInfo,
                                           _str defaultRegexType,
                                           _str defaultCaseOption,
                                           _str defaultLangMode)
{
   // array of new words parsed out
   HighlightWordInfo newWordArray[];
   int startPositions[];
   int endPositions[];
   ParseHighlightWordsFromText(text, 
                               newWordArray, startPositions, endPositions, 
                               defaultRegexType, defaultCaseOption, defaultLangMode);

   // go through list of words found and remove the text 
   // for the one that did not match
   for (i:= newWordArray._length()-1; i >= 0; --i) {
      wordInfo := newWordArray[i];
      // or words we already have
      if (wordInfo.m_wordPattern == removeWordInfo.m_wordPattern &&
          wordInfo.m_wordKind    == removeWordInfo.m_wordKind) {
         //say("RemoveNewHighlightWordFromText H"__LINE__": FOUND IT");
         start_pos := startPositions[i];
         end_pos   := endPositions[i];
         orig_text := text;
         text = "";
         if (start_pos > 1) {
            text = substr(orig_text, 1, start_pos-1);
         }
         if (end_pos < length(orig_text)) {
            text :+= substr(orig_text, end_pos);
         }
      }
   }
}

/**
 * Callback for any change to the text box for adding words. 
 * We dynamically add words as they are typed and so users can see immediately 
 * what they are adding.  The words here are just tentatively added, they are 
 * not commited to the highlight profile until the user hits {@literal ENTER}. 
 */
void ctl_add_words.on_change()
{
   // check if we are in th middle of something important
   ignoringChanges := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES);
   if (ignoringChanges != null && ignoringChanges == true) {
      return;
   }

   // get the profile name, make sure we are not disabled
   profileName := ctl_profile.p_text;
   if (profileName == null || profileName=="") {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }
   if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return;
   }

   // get the highlight profile information object (including list of words)
   HighlightProfile *pProfileInfo = p_active_form._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
   if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
      return;
   }

   // delete the word patterns that were added temporarily.
   int addWordIndexes[] = p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES);
   if (addWordIndexes != null) {
      foreach (auto wordIndex in addWordIndexes) {
         pProfileInfo->deleteWordPattern(wordIndex);
      }
      addWordIndexes._makeempty();
   }

   // disable callbacks
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);

   // now update the list of temporary words
   defaultCaseOption := GetHighlightCaseOption(ctl_match_case.p_value);
   defaultRegexType := HighlightWordInfo.wordKindFromCaption(ctl_regex_type.p_text);
   defaultLangMode := GetHighlightModeOption(ctl_match_language.p_value);
   AddNewHighlightWords(ctl_add_words.p_text, 
                        pProfileInfo->m_words,
                        addWordIndexes, 
                        defaultRegexType, 
                        defaultCaseOption, 
                        defaultLangMode);
   HighlightProfile.incrementSavedGeneration(profileName);
   ctl_highlight_words.HighlightTWAddWordsToTree(profileName, pProfileInfo->m_words);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, *pProfileInfo);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, addWordIndexes);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);
   HighlightAnalyzer.clearHighlightMarkers();

   // update the window closest to this form
   child_wid := p_active_form._MDIGetActiveMDIChild();
   if (child_wid) {
      _UpdateHighlightsToolWindow(p_active_form, child_wid, AlwaysUpdate:true);
   }
}

/**
 * Callback for user hitting {@literal ENTER} in the text box for adding words. 
 * This will add all the words in the text box to the list of word patterns, 
 * and commit them to the highlight profile. 
 */
void ctl_add_words.enter()
{
   // get the profile name, make sure we are not disabled
   profileName := ctl_profile.p_text;
   if (profileName == null || profileName=="") {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }
   if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return;
   }

   // get the highlight profile information object (including list of words)
   HighlightProfile *pProfileInfo = p_active_form._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
   if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
      return;
   }

   // delete the word patterns that were added temporarily.
   int addWordIndexes[] = p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES);
   if (addWordIndexes != null) {
      foreach (auto wordIndex in addWordIndexes) {
         pProfileInfo->deleteWordPattern(wordIndex);
      }
      addWordIndexes._makeempty();
   }

   // disable callbacks
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);

   // now update the list of temporary words
   defaultCaseOption := GetHighlightCaseOption(ctl_match_case.p_value);
   defaultRegexType := HighlightWordInfo.wordKindFromCaption(ctl_regex_type.p_text);
   defaultLangMode := GetHighlightModeOption(ctl_match_language.p_value);
   AddNewHighlightWords(ctl_add_words.p_text, 
                        pProfileInfo->m_words,
                        addWordIndexes,
                        defaultRegexType, 
                        defaultCaseOption, 
                        defaultLangMode);
   ctl_highlight_words.HighlightTWAddWordsToTree(profileName, pProfileInfo->m_words);
   ctl_add_words.p_text = "";
   HighlightAnalyzer.clearHighlightMarkers();

   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, *pProfileInfo);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, null);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);
   pProfileInfo->saveProfile(profileName);
   HighlightProfile.incrementSavedGeneration(profileName);

   // update the window closest to this form
   child_wid := _MDIGetActiveMDIChild();
   if (child_wid) {
      _UpdateHighlightsToolWindow(p_active_form, child_wid, AlwaysUpdate:true);
      child_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}

// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW FORM UTILITY FUNCTIONS                              ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * Delete the given profile name from the Highlight tool window GUI.
 * 
 * @param deleteProfileName   name of highlight profile to delete
 * @param newProfileInfo      name of new highlight profile to select
 */
static void HighlightTWDeleteProfile(_str deleteProfileName, HighlightProfile &newProfileInfo)
{
   if (ctl_profile.p_text == deleteProfileName) {

      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);

      // out with the old profile, except for Default or Disabled profiles
      if (deleteProfileName != HIGHLIGHT_DEFAULT_PROFILE_NAME && deleteProfileName != HIGHLIGHT_DISABLE_PROFILE_NAME) {
         ctl_profile._lbdelete_item();
      }

      // in with the new profile
      newProfileName := newProfileInfo.getProfileName();
      ctl_profile._cbset_text(newProfileName);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME, newProfileName);
      ctl_add_words.p_text = "";
      ctl_highlight_words.HighlightTWAddWordsToTree(newProfileName, newProfileInfo.m_words);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, newProfileInfo);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, null);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);

      // update the active editor control for this form
      editorctl_wid := GetHighlightTWActiveEditor();
      if (editorctl_wid) {
         _UpdateHighlightsToolWindow(p_active_form, editorctl_wid, AlwaysUpdate:true);
         editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
      }

   } else {

      // out with the old profile, except for Default or Disabled profiles
      if (deleteProfileName != HIGHLIGHT_DEFAULT_PROFILE_NAME && deleteProfileName != HIGHLIGHT_DISABLE_PROFILE_NAME) {
         p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
         origProfileName := ctl_profile.p_text;
         ctl_profile._lbfind_and_delete_item(deleteProfileName);
         ctl_profile._cbset_text(origProfileName);
         p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);
      }
   }
}

/**
 * Toggle highlighting enabled or disabled in the Highlight tool window.  
 * This is done by shifting to the "Disabled" profile when disabled, 
 * and re-activating the previous active highlight profile when enabled.
 * 
 * @param turn_on_highlighting   Turn highlighting on ({@code true}) or off ({@code false})
 * @param profileName            highlight profile name to switch to
 */
static void HighlightTWToggleEnabled(bool turn_on_highlighting, _str profileName)
{
   // determine which profile this form is switching to
   newProfileName := HIGHLIGHT_DISABLE_PROFILE_NAME;
   if (turn_on_highlighting) {
      newProfileName = p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME);
      if (newProfileName == null || newProfileName == "" || newProfileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
         newProfileName = profileName;
      }
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME, newProfileName);
   }

   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
   ctl_profile._cbset_text(newProfileName);
   HighlightProfile profileInfo;
   profileInfo.loadProfile(newProfileName);
   ctl_highlight_words.HighlightTWAddWordsToTree(newProfileName, profileInfo.m_words);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, profileInfo);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, null);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);
   if (turn_on_highlighting && ctl_add_words.p_text != "") {
      ctl_add_words.call_event(ctl_add_words.p_window_id, ON_CHANGE);
   }

   editorctl_wid := GetHighlightTWActiveEditor();
   if (editorctl_wid) {
      _UpdateHighlightsToolWindow(p_active_form, editorctl_wid, AlwaysUpdate:true);
      editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}

/**
 * Replace the entire word list for the given profile name.
 * 
 * @param profileName     highlight profilename
 * @param words           new list of words
 */
static void HighlightTWReplaceWordList(_str profileName, HighlightWordInfo (&words)[])
{
   //say("HighlightTWReplaceWordList: profileName="profileName" ctl_profile.p_text="ctl_profile.p_text);
   if (ctl_profile.p_text == profileName) {
      //say("HighlightTWReplaceWordList: profile matches");

      // get the highlight profile information object (including list of words)
      HighlightProfile *pProfileInfo = p_active_form._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
      if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
         return;
      }

      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
      ctl_highlight_words.HighlightTWAddWordsToTree(profileName, words);
      pProfileInfo->m_words = words;
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, *pProfileInfo);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, null);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);

      if (ctl_add_words.p_text != "") {
         ctl_add_words.call_event(ctl_add_words.p_window_id, ENTER);
      }
   }
}

/**
 * Update the word pattern information for the given item in the current profile.
 * 
 * @param profileName     highlight profilename
 * @param wordIndex       word index
 * @param wordInfo        new word pattern information
 */
static void HighlightTWUpdateWordInfo(_str profileName, int wordIndex, HighlightWordInfo wordInfo)
{
   //say("HighlightTWUpdateWordInfo: profileName="profileName" ctl_profile.p_text="ctl_profile.p_text);
   if (ctl_profile.p_text == profileName) {
      //say("HighlightTWUpdateWordInfo: profile matches");

      // get the highlight profile information object (including list of words)
      HighlightProfile *pProfileInfo = p_active_form._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
      if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
         return;
      }

      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
      pProfileInfo->replaceWordPattern(wordIndex, wordInfo);
      ctl_highlight_words.HighlightTWAddWordsToTree(profileName, pProfileInfo->m_words);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, *pProfileInfo);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, null);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);

      if (ctl_add_words.p_text != "") {
         ctl_add_words.call_event(ctl_add_words.p_window_id, ENTER);
      }
   }
}

/**
 * Delete the word pattern information for the given item in the current profile. 
 * This does not delete the item from the array, it only nulls out the entry. 
 * It works this way in order to preserve word indexes. 
 * 
 * @param profileName highlight profilename
 * @param wordIndex   word index
 * @param wordInfo    word pattern information
 */
static void HighlightTWDeleteWordInfo(_str profileName, int wordIndex, HighlightWordInfo wordInfo)
{
   if (ctl_profile.p_text == profileName) {
      if (ctl_add_words.p_text != "") {
         ctl_add_words.call_event(ctl_add_words.p_window_id, ENTER);
      }

      // get the highlight profile information object (including list of words)
      HighlightProfile *pProfileInfo = p_active_form._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
      if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
         return;
      }

      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
      pProfileInfo->deleteWordPattern(wordIndex);
      ctl_highlight_words.HighlightTWAddWordsToTree(profileName, pProfileInfo->m_words);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, *pProfileInfo);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, null);
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);
   }
}

/**
 * @return 
 * Return the current profile name. 
 * This is either the currently selected Highlight profile in the Highlight 
 * tool window, or the global {@code gHighlightCurrentProfile}, or the 
 * Default profile if nothing else is set. 
 */
static _str HighlightTWGetProfileName()
{
   profileName := "";
   form_wid := _tbGetActiveHighlightForm(~(TWFF_ACTIVE_FORM|TWFF_FOCUS_FORM));
   if (form_wid != 0) {
      profileName = form_wid.ctl_profile.p_text;
   }
   if (profileName == "") {
      profileName = gHighlightCurrentProfile;
   }
   if (profileName == null || profileName=="") {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }
   return profileName;
}

/**
 * @return 
 * Return the Highlight profile analyzer object for the current buffer. 
 * Will create and initialize one for the given profile if not yet configured, 
 * unless {@code profileName} is {@literal (None)}.  
 * 
 * @param profileName     highlight profile name to use
 */
static HighlightAnalyzer *HighlightTWGetAnalyzer(_str profileName="")
{
   // expecting an editor control
   if (!_isEditorCtl()) {
      return null;
   }

   // get the active profile name
   if (profileName == "") {
      profileName = HighlightTWGetProfileName();
   }

   // check if we already have an highlighter object for this buffer?
   HighlightAnalyzer *pHighlighter = _GetBufferInfoHtPtr(HIGHLIGHT_BUFFER_INFO_KEY);
   if (pHighlighter == null || !(*pHighlighter instanceof se.color.HighlightAnalyzer)) {
      if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
         return null;
      }
      HighlightAnalyzer highlighter(p_window_id);
      highlighter.initAnalyzer(profileName);
      _SetBufferInfoHt(HIGHLIGHT_BUFFER_INFO_KEY, highlighter);
      pHighlighter = _GetBufferInfoHtPtr(HIGHLIGHT_BUFFER_INFO_KEY);
      if (pHighlighter == null) {
         return null;
      }
   }

   // that's all folks
   return pHighlighter;
}

/**
 * Find the word pattern under the cursor and cycle it to the next color entry. 
 * Color index wrap back to 0 or 1023 if they exceed the boundaries.
 * 
 * @param direction    positive or negative number to go to next/previous colorProfileName
 * @param maybeAddWord if {@code true} add a word pattern for the word or selection 
 *                     under the cursor if the word under the cursor is not already
 *                     highlighted. 
 */
static void HighlightCycleColor(int direction, bool maybeAddWord=false)
{
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }

   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = _MDICurrentChild(0);
      if (!editorctl_wid) return;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = editorctl_wid.HighlightTWGetAnalyzer();
   if (pHighlighter == null) return;

   wordIndex := editorctl_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords: maybeAddWord);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return;
   }
   if (wordIndex < 0 || wordInfo == null) {
      if (maybeAddWord) {
         highlight_toggle_word();
      }
      return;
   }

   wordInfo.m_colorIndex += direction;
   if (wordInfo.m_colorIndex < 0) {
      wordInfo.m_colorIndex = 1023;
   }

   if (pHighlighter->m_profileInfo == null) {
      pHighlighter->m_profileInfo.loadProfile(profileName);
   }
   pHighlighter->m_profileInfo.replaceWordPattern(wordIndex, wordInfo);
   pHighlighter->m_profileInfo.saveProfile();
   HighlightProfile.incrementSavedGeneration(profileName);
   pHighlighter->m_profileInfo.loadProfile(profileName);

   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReplaceWordList(profileName, pHighlighter->m_profileInfo.m_words);
   }

   // find stream markers for the given color and apply the new color
   marker_flags := 0;
   cfg_color := wordInfo.getHighlightMarkerColor(editorctl_wid.p_WindowColorProfile, marker_flags);
   _StreamMarkerFindListWithType(auto list, editorctl_wid, gHighlightStreamMarkerType, BMIndex:0, wordIndex+1);
   foreach (auto markerId in list) {
      if (_StreamMarkerGetUserDataInt64(markerId) == wordIndex+1) {
         _StreamMarkerSetTextColor(markerId, cfg_color);
      }
   }

   // update the current editor window for this item
   editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
}

/**
 * @return 
 * Return the word index of the highlighted word under the cursor. 
 * Return an error code &lt;0 if there is no word highlighted under the cursor. 
 * 
 * @param profileName          highlight color profile
 * @param wordInfo             (output) set to word pattern information found
 * @param lookForDisabledWords if {@code true} look for word patterns that are disabled
 */
static int GetHighlightMarkerUnderCursor(_str &profileName, HighlightWordInfo &wordInfo, bool lookForDisabledWords=false)
{
   // check if we already have an highlighter object for this buffer?
   HighlightAnalyzer *pHighlighter = HighlightTWGetAnalyzer();
   if (pHighlighter == null || pHighlighter->m_profileInfo == null) {
      return STRING_NOT_FOUND_RC;
   }
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }
   profileName = pHighlighter->m_profileInfo.getProfileName();
   return pHighlighter->m_profileInfo.getWordUnderCursor(p_window_id, gHighlightStreamMarkerType, wordInfo, lookForDisabledWords);
}


// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW COMMANDS                                            ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * Activates the Highlight tool window.
 *
 * @categories Toolbar_Functions, Search_Functions
 */
_command activate_highlight()  name_info(','VSARG2_EDITORCTL|VSARG2_READ_ONLY)
{
  return activate_tool_window(HIGHLIGHT_FORM_NAME_STRING, true, "ctl_add_words", true);
}

/**
 * Toggles the display of the Highlight tool window.
 *
 * @categories Toolbar_Functions, Search_Functions
 */
_command void toggle_highlight()  name_info(','VSARG2_EDITORCTL|VSARG2_READ_ONLY)
{
   tw_toggle_tabgroup(HIGHLIGHT_FORM_NAME_STRING, 'ctl_add_words');
}
/**
 * Toggles the display of the Highlight tool window between pinned and unpinned states.
 *
 * @categories Toolbar_Functions, Search_Functions
 */
_command void toggle_highlight_pinned()  name_info(','VSARG2_EDITORCTL|VSARG2_READ_ONLY)
{
   tw_toggle_tabgroup(HIGHLIGHT_FORM_NAME_STRING, 'ctl_add_words', toggle_pinned:true);
}

/**
 * Delete the given highlight profile name.
 * 
 * @param profileName    highlight profile to delete 
 *  
 * @note 
 * You can not delete the "Disabled" profile, and the built-in "Default" profile 
 * can only be reset, not actually deleted.
 *
 * @categories Search_Functions
 */
_command void highlight_delete_profile(_str profileName="") name_info(','VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL)
{
   if (profileName == null || profileName=="") {
      return;
   }
   if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return;
   }

   // confirmation prompt so we do not delete profiles all willy-nilly
   HighlightProfile profileInfo(profileName);
   newProfileName := HIGHLIGHT_DEFAULT_PROFILE_NAME;
   if (HighlightProfile.hasBuiltinProfile(profileName)) {
      newProfileName = gHighlightCurrentProfile;
      yesno := _message_box("Reset all highlights for \"":+profileName:+"\" to defaults?", "Reset Highlight Profile", MB_YESNO|MB_ICONQUESTION);
      if (yesno != IDYES) return;
   } else {
      profileInfo.loadProfile(profileName);
      if (profileInfo.isEmpty()) {
         yesno := _message_box("Delete all highlights for \"":+profileName:+"\"?", "Delete Highlight Profile", MB_YESNO|MB_ICONQUESTION);
         if (yesno != IDYES) return;
      }
   }

   HighlightProfile.deleteProfile(profileName);
   HighlightProfile.incrementSavedGeneration(profileName);
   gHighlightCurrentProfile = newProfileName;
   gHighlightPreviousProfile = newProfileName;
   HighlightAnalyzer.clearHighlightMarkers();
   profileInfo.loadProfile(newProfileName);
   
   // Update the highlight tool window for each active form.
   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWDeleteProfile(profileName, profileInfo);
   }
}

/**
 * Toggle word pattern highlighting entirely on or off.  This works by 
 * selected the "Disabled" profile when toggling off, and then pivoting back 
 * to the previously active profile when toggling back on. 
 * 
 * @param onOff  (optional) {@literal 0} or {@literal off} to force highlighting off
 *
 * @categories Search_Functions
 */
_command void highlight_toggle_enabled(_str onOff="") name_info(','VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL)
{
   turn_on_highlighting := (gHighlightCurrentProfile == HIGHLIGHT_DISABLE_PROFILE_NAME);
   if (onOff != "") {
      turn_on_highlighting = (onOff != 0 && onOff != "off");
   }

   if (turn_on_highlighting) {
      gHighlightCurrentProfile = gHighlightPreviousProfile;
   } else {
      HighlightAnalyzer.clearHighlightMarkers();
      if (gHighlightCurrentProfile != HIGHLIGHT_DISABLE_PROFILE_NAME) {
         gHighlightPreviousProfile = gHighlightCurrentProfile;
      }
      gHighlightCurrentProfile = HIGHLIGHT_DISABLE_PROFILE_NAME;
   }

   profileName := gHighlightCurrentProfile;
   if (profileName == null || profileName == "") {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }

   // Update the highlight tool window for each active form.
   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWToggleEnabled(turn_on_highlighting, profileName);
   }
}

/**
 * Turn word pattern highlight entirely off.
 *  
 * @see highlight_toggle_enabled 
 * @categories Search_Functions
 */
_command void highlight_clear_all() name_info(','VSARG2_READ_ONLY|VSARG2_NOEXIT_SCROLL)
{
   highlight_toggle_enabled("off");
}

/**
 * Cycle the color for the word pattern under the cursor to the next color. 
 * If there is no word pattern highlighted under the cursor, create a new 
 * word pattern for the word or selection under the cursor and add it to the 
 * current highlighting profile. 
 *  
 * @see highlight_cycle_next_color 
 * @see highlight_cycle_prev_color 
 * @categories Search_Functions
 */
_command void highlight_cycle_add_color() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL) 
{
   HighlightCycleColor(HIGHLIGHT_TW_SMALL_COLOR_INCREMENT, maybeAddWord:true);
}
int _OnUpdate_highlight_cycle_add_color(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   return MF_ENABLED;
}

/**
 * Cycle the color for the word pattern under the cursor to the next color. 
 * If there is no word pattern highlighted under the cursor, do nothing.
 *  
 * @see highlight_cycle_add_color 
 * @see highlight_cycle_prev_color 
 * @categories Search_Functions
 */
_command void highlight_cycle_next_color() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL) 
{
   HighlightCycleColor(HIGHLIGHT_TW_SMALL_COLOR_INCREMENT);
}
int _OnUpdate_highlight_cycle_next_color(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords:true);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return MF_GRAYED;
   }
   return MF_ENABLED;
}

/**
 * Cycle the color for the word pattern under the cursor to the previous color. 
 * If there is no word pattern highlighted under the cursor, do nothing.
 *  
 * @see highlight_cycle_add_color 
 * @see highlight_cycle_next_color 
 * @categories Search_Functions
 */
_command void highlight_cycle_prev_color() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL) 
{
   HighlightCycleColor(HIGHLIGHT_TW_SMALL_COLOR_DECREMENT);
}
int _OnUpdate_highlight_cycle_prev_color(CMDUI &cmdui,int target_wid,_str command)
{
   return _OnUpdate_highlight_cycle_next_color(cmdui, target_wid, command);
}

/**
 * Toggle the word pattern under the cursor between the enabled and disaabled states.
 * If there is no matching word pattern highlighted under the cursor, do nothing.
 * 
 * @categories Search_Functions
 */
_command void highlight_toggle_word_enabled() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL) 
{
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }

   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = _MDICurrentChild(0);
      if (!editorctl_wid) return;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = editorctl_wid.HighlightTWGetAnalyzer();
   if (pHighlighter == null) return;

   // check if we already have an highlighter object for this buffer?
   wordIndex := editorctl_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords:true);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return;
   }

   //_dump_var(wordInfo, "highlight_toggle_word_enabled H"__LINE__": wordInfo");
   wordInfo.m_enabled = !wordInfo.m_enabled;

   // update the list of words for the highlighter object
   if (pHighlighter->m_profileInfo == null) {
      pHighlighter->m_profileInfo.loadProfile(profileName);
   }
   pHighlighter->m_profileInfo.replaceWordPattern(wordIndex, wordInfo);
   pHighlighter->m_profileInfo.saveProfile();
   HighlightProfile.incrementSavedGeneration(profileName);
   pHighlighter->m_profileInfo.loadProfile(profileName);

   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReplaceWordList(profileName, pHighlighter->m_profileInfo.m_words);
   }

   if (!wordInfo.m_enabled) {
      // clear all stream markers for this item
      HighlightAnalyzer.clearHighlightMarkersWithIndex(editorctl_wid, wordIndex);
   }

   if (wordInfo.m_enabled) {
      editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}
int _OnUpdate_highlight_toggle_word_enabled(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   //if (wordIndex < 0 || wordInfo == null) {
   //   return MF_GRAYED;
   //}
   return MF_ENABLED;
}

/**
 * Toggle the case-sensitivity options for the word pattern under the cursor.
 * If there is no matching word pattern highlighted under the cursor, do nothing.
 * 
 * @categories Search_Functions
 */
_command void highlight_toggle_word_case() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL) 
{
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }

   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = _MDICurrentChild(0);
      if (!editorctl_wid) return;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = editorctl_wid.HighlightTWGetAnalyzer();
   if (pHighlighter == null) return;

   // check if we already have an highlighter object for this buffer?
   wordIndex := editorctl_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords:true);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return;
   }

   switch (upcase(wordInfo.m_caseOption)) {
   case 'E':  wordInfo.m_caseOption = 'I'; break;
   case 'I':  wordInfo.m_caseOption = 'A'; break;
   case 'A':  wordInfo.m_caseOption = 'E'; break;
   }

   // update the list of words for the highlighter object
   if (pHighlighter->m_profileInfo == null) {
      pHighlighter->m_profileInfo.loadProfile(profileName);
   }
   pHighlighter->m_profileInfo.replaceWordPattern(wordIndex, wordInfo);
   pHighlighter->m_profileInfo.saveProfile();
   HighlightProfile.incrementSavedGeneration(profileName);
   pHighlighter->m_profileInfo.loadProfile(profileName);
   
   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReplaceWordList(profileName, pHighlighter->m_profileInfo.m_words);
   }

   // refresh the current window
   if (wordInfo.m_enabled) {
      editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}
int _OnUpdate_highlight_toggle_word_case(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return MF_GRAYED;
   }
   return MF_ENABLED;
}

/**
 * Toggle the search options between doing a word match and doing a substring match 
 * for the word pattern under the cursor. 
 * If there is no matching word pattern highlighted under the cursor, do nothing.
 * 
 * @categories Search_Functions
 */
_command void highlight_toggle_word_or_string() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL) 
{
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }

   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = _MDICurrentChild(0);
      if (!editorctl_wid) return;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = editorctl_wid.HighlightTWGetAnalyzer();
   if (pHighlighter == null) return;

   // check if we already have an highlighter object for this buffer?
   wordIndex := editorctl_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords:true);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return;
   }

   //_dump_var(wordInfo, "highlight_toggle_word_enabled H"__LINE__": wordInfo");
   switch (upcase(wordInfo.m_wordKind)) {
   case 'W':  wordInfo.m_caseOption = 'S'; break;
   case 'S':  wordInfo.m_caseOption = 'W'; break;
   default: 
      _message_box("Can not change regular expression highlight.");
      return;
   }

   // update the list of words for the highlighter object
   if (pHighlighter->m_profileInfo == null) {
      pHighlighter->m_profileInfo.loadProfile(profileName);
   }
   pHighlighter->m_profileInfo.replaceWordPattern(wordIndex, wordInfo);
   pHighlighter->m_profileInfo.saveProfile();
   HighlightProfile.incrementSavedGeneration(profileName);
   pHighlighter->m_profileInfo.loadProfile(profileName);
   
   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReplaceWordList(profileName, pHighlighter->m_profileInfo.m_words);
   }

   // refresh the current window
   if (wordInfo.m_enabled) {
      editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}
int _OnUpdate_highlight_toggle_word_or_string(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return MF_GRAYED;
   }
   return MF_ENABLED;
}

/**
 * Toggle the language-specific attribute for the word pattern under the cursor 
 * between the current language mode and all languages. 
 * If there is no matching word pattern highlighted under the cursor, do nothing.
 * 
 * @categories Search_Functions
 */
_command void highlight_toggle_word_language() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL) 
{
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }

   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = _MDICurrentChild(0);
      if (!editorctl_wid) return;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = editorctl_wid.HighlightTWGetAnalyzer();
   if (pHighlighter == null) return;

   // check if we already have an highlighter object for this buffer?
   wordIndex := editorctl_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords:true);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return;
   }

   //_dump_var(wordInfo, "highlight_toggle_word_enabled H"__LINE__": wordInfo");
   if (wordInfo.m_langId == null || wordInfo.m_langId == "") {
      wordInfo.m_langId = editorctl_wid.p_LangId;
   } else {
      wordInfo.m_langId = "";
   }

   // update the list of words for the highlighter object
   if (pHighlighter->m_profileInfo == null) {
      pHighlighter->m_profileInfo.loadProfile(profileName);
   }
   pHighlighter->m_profileInfo.replaceWordPattern(wordIndex, wordInfo);
   pHighlighter->m_profileInfo.saveProfile();
   pHighlighter->resetAnalyzer(editorctl_wid);
   HighlightProfile.incrementSavedGeneration(profileName);
   pHighlighter->m_profileInfo.loadProfile(profileName);
   
   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReplaceWordList(profileName, pHighlighter->m_profileInfo.m_words);
   }

   // refresh the current window
   if (wordInfo.m_enabled) {
      editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}
int _OnUpdate_highlight_toggle_word_language(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return MF_GRAYED;
   }
   return MF_ENABLED;
}

/**
 * Toggle whether the word pattern under the cursor is part of the current 
 * highlight profile or not.  If there is no matching word pattern highlighted 
 * under the cursor, add a new word pattern to the profile. 
 *  
 * @see highlight_toggle_word_enabled 
 * @see highlight_add_word 
 * @see highlight_delete_word 
 *  
 * @categories Search_Functions
 */
_command void highlight_toggle_word() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL|VSARG2_MARK) 
{
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }

   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = _MDICurrentChild(0);
      if (!editorctl_wid) return;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = editorctl_wid.HighlightTWGetAnalyzer();
   if (pHighlighter == null) return;

   // check if we already have an highlighter object for this buffer?
   wordIndex := editorctl_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords:true);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      _message_box("Highlighting disabled.");
      return;
   }
   deleteExistingWord := true;
   if (wordIndex < 0 || wordInfo == null) {
      deleteExistingWord = false;
      wordIndex = pHighlighter->m_profileInfo.getNewPatternUnderCursor(editorctl_wid, wordInfo);
      if (wordIndex < 0) return;
   }

   // update the list of words for the highlighter object
   if (pHighlighter->m_profileInfo == null) {
      pHighlighter->m_profileInfo.loadProfile(profileName);
   }

   //say("highlight_toggle_word H"__LINE__": wordIndex="wordIndex" delete="deleteExistingWord);
   //_dump_var(pHighlighter->m_profileInfo.m_words, "highlight_toggle_word H"__LINE__": BEFORE pHighlighter->m_profileInfo.m_words");

   if (deleteExistingWord) {
      wordInfo.m_enabled = false;
      pHighlighter->m_profileInfo.deleteWordPattern(wordIndex);
      //say("highlight_toggle_word: DELETE WORD");
   } else {
      wordInfo.m_enabled = true;
      pHighlighter->m_profileInfo.replaceWordPattern(wordIndex, wordInfo);
      //say("highlight_toggle_word: REPLACE WORD");
   }
   pHighlighter->m_profileInfo.saveProfile(profileName);
   pHighlighter->resetAnalyzer(editorctl_wid);
   HighlightProfile.incrementSavedGeneration(profileName);
   pHighlighter->m_profileInfo.loadProfile(profileName);

   //_dump_var(pHighlighter->m_profileInfo.m_words, "highlight_toggle_word H"__LINE__": AFTER pHighlighter->m_profileInfo.m_words");

   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReplaceWordList(profileName, pHighlighter->m_profileInfo.m_words);
   }

   if (deleteExistingWord) {
      // clear all stream markers for this item
      HighlightAnalyzer.clearHighlightMarkersWithIndex(editorctl_wid, wordIndex);
   } else {
      // update the current editor window for this item
      editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}
int _OnUpdate_highlight_toggle_word(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   if (wordIndex < 0 || wordInfo == null) {
      get_line(auto line);
      if (line == "") {
         return MF_GRAYED;
      }
   }
   return MF_ENABLED;
}

/**
 * Add the word under the cursor to the current highlighting profile.
 * 
 * @param word_list    (currently ignored) list of words to add 
 *  
 * @see highlight_toggle_word 
 * @see highlight_delete_word 
 *  
 * @categories Search_Functions
 */
_command void highlight_add_word(_str word_list="") name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL|VSARG2_MARK) 
{
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }

   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = _MDICurrentChild(0);
      if (!editorctl_wid) return;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = editorctl_wid.HighlightTWGetAnalyzer();
   if (pHighlighter == null) return;

   // check if we already have an highlighter object for this buffer?
   wordIndex := editorctl_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords:true);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      _message_box("Highlighting disabled.");
      return;
   }
   if (wordIndex < 0 || wordInfo == null) {
      wordIndex = pHighlighter->m_profileInfo.getNewPatternUnderCursor(editorctl_wid, wordInfo);
      if (wordIndex < 0) return;
   } else {
      _message_box("Word '":+wordInfo.m_wordPattern:+'" is already highlighted.');
   }

   // update the list of words for the highlighter object
   if (pHighlighter->m_profileInfo == null) {
      pHighlighter->m_profileInfo.loadProfile(profileName);
   }

   wordInfo.m_enabled = true;
   pHighlighter->m_profileInfo.replaceWordPattern(wordIndex, wordInfo);
   pHighlighter->m_profileInfo.saveProfile(profileName);
   pHighlighter->resetAnalyzer(editorctl_wid);
   HighlightProfile.incrementSavedGeneration(profileName);
   pHighlighter->m_profileInfo.loadProfile(profileName);

   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReplaceWordList(profileName, pHighlighter->m_profileInfo.m_words);
   }

   editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
}
int _OnUpdate_highlight_add_word(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   return MF_ENABLED;
}

/**
 * Remove the word pattern under the cursor form the current highlight profile. 
 * If there is no matching word pattern highlighted under the cursor, do nothing.
 *  
 * @see highlight_toggle_word
 * @see highlight_add_word 
 *  
 * @categories Search_Functions
 */
_command void highlight_delete_word() name_info(','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_NOEXIT_SCROLL) 
{
   if (gHighlightStreamMarkerType <= 0) {
      HighlightAnalyzer.initHighlightMarkerType(def_highlight_tw_options);
   }

   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = _MDICurrentChild(0);
      if (!editorctl_wid) return;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = editorctl_wid.HighlightTWGetAnalyzer();
   if (pHighlighter == null) return;

   // check if we already have an highlighter object for this buffer?
   wordIndex := editorctl_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo, lookForDisabledWords:true);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      _message_box("Highlighting disabled");
      return;
   }
   if (wordIndex < 0 || wordInfo == null) {
      _message_box("No highlight under cursor.");
      return;
   }

   // update the list of words for the highlighter object
   wordInfo.m_enabled = false;
   if (pHighlighter->m_profileInfo == null) {
      pHighlighter->m_profileInfo.loadProfile(profileName);
   }
   pHighlighter->m_profileInfo.deleteWordPattern(wordIndex);
   pHighlighter->m_profileInfo.saveProfile();
   HighlightProfile.incrementSavedGeneration(profileName);
   pHighlighter->m_profileInfo.loadProfile(profileName);

   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReplaceWordList(profileName, pHighlighter->m_profileInfo.m_words);
   }

   // clear all stream markers for this item
   HighlightAnalyzer.clearHighlightMarkersWithIndex(editorctl_wid, wordIndex);
}
int _OnUpdate_highlight_delete_word(CMDUI &cmdui,int target_wid,_str command)
{
   if (!target_wid || !target_wid._isEditorCtl()) {
      return MF_GRAYED;
   }
   wordIndex := target_wid.GetHighlightMarkerUnderCursor(auto profileName, auto wordInfo);
   if (profileName == null || profileName == "" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      return MF_GRAYED;
   }
   if (wordIndex < 0 || wordInfo == null) {
      return MF_GRAYED;
   }
   return MF_ENABLED;
}


// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW BUFFER LIST HANDLING                                ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * Changing current buffer.
 * 
 * @param oldbuffname old buffer name
 * @param flag        switch buffer flag
 */
void _switchbuf_WordHighlighting(_str oldbuffname, _str flag)
{
   _ResetVisibleFileTabs(gHighlightTWVisibleTabs);
   _UpdateHighlightsToolWindowForCurrentEditorWindow(AlwaysUpdate:true);
}
/**
 * Closing a buffer.
 * 
 * @param buffid  buffer ID
 * @param name    name of file being closed
 * @param docname document name for file being closed
 * @param flags   bitset of flags
 */
void _cbquit_WordHighlighting(int buffid, _str name, _str docname= "", int flags = 0)
{
   _ResetVisibleFileTabs(gHighlightTWVisibleTabs);
   _UpdateHighlightsToolWindowForCurrentEditorWindow(AlwaysUpdate:true);
}
/**
 * Opening a new buffer
 * 
 * @param newBuffID new buffer ID
 * @param name      new buffer name
 * @param flags     bitset of flags
 */
void _buffer_add_WordHighlighting(int newBuffID, _str name, int flags = 0)
{
   _ResetVisibleFileTabs(gHighlightTWVisibleTabs);
   _UpdateHighlightsToolWindowForCurrentEditorWindow(AlwaysUpdate:true);
}

/**
 * Options callback for selecting how many files the highlighting tool window 
 * should try to color.  Can be just the current file, just visible files, or 
 * all open files. 
 * 
 * @param value     new option setting
 * @return returns the option setting 
 *  
 * @see def_highlight_tw_windows
 */
int highlight_coloring_windows(int value = null)
{
   if (value != null) {
      // set the new value, reset our list
      def_highlight_tw_windows = value;
      _config_modify_flags(CFGMODIFY_DEFVAR);
      _ResetVisibleFileTabs(gHighlightTWVisibleTabs);
   }

   return def_highlight_tw_windows;
}

/** 
 * Update colors in tool window if the color profile changes for the current buffer. 
 * 
 * @param colorProfileName 
 */
void _color_profile_modified_highlight(_str colorProfileName="")
{
   _UpdateHighlightsToolWindowForCurrentEditorWindow(AlwaysUpdate:true);
}

/**
 * Update the highlight tool window after the configuration was reloaded. 
 * The tool window is expected to be the current object. 
 */
static void HighlightTWReloadProfile()
{
   // reload the default profiles and options
   profileName := ctl_profile.p_text;

   // load the profile names from the configuration settings, 
   // always have a "Default" profile name first
   HighlightProfile.addProfilesToList(ctl_profile);
   if (profileName == "" || !HighlightProfile.hasProfile(profileName)) {
      profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
   }
   ctl_profile._cbset_text(profileName);
   HighlightProfile profileInfo;
   profileInfo.loadProfile(profileName);
   if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME, HIGHLIGHT_DEFAULT_PROFILE_NAME);
   } else {
      p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_PREV_HIGHLIGHT_PROFILE_NAME, profileName);
   }

   // add the different highlight styles to the combo box
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, true);
   ctl_add_words.p_text = "";
   profileName = ctl_profile.p_text;
   ctl_highlight_words.HighlightTWAddWordsToTree(profileName, profileInfo.m_words);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO, profileInfo);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_ADD_WORD_INDICES, null);
   p_active_form._SetDialogInfoHt(HIGHLIGHT_TW_KEY_NO_CHANGES, false);

   editorctl_wid := GetHighlightTWActiveEditor();
   if (editorctl_wid) {
      _UpdateHighlightsToolWindow(p_active_form, editorctl_wid, AlwaysUpdate:true);
      editorctl_wid._UpdateWordHighlightingForEditorWindow(force:true, doMinimalWork:true, okToRefresh:true);
   }
}

/**
 * Callback to reload highlighting profiles when the configuration is reloaded.
 */
void _config_reload_highlight_tw() 
{
   foreach (auto form_wid in gHighlightFormList) {
      if (!HighlightTWIsValid(form_wid)) continue;
      form_wid.HighlightTWReloadProfile();
   }
}

/**
 * Reset the word highlighting for all buffers.  Use this when global 
 * properties change, such as toggling on/off draw box around line. 
 */
void _ResetWordHighlightingForAllFiles()
{
   orig_wid := p_window_id;
   activate_window(VSWID_HIDDEN);
   _safe_hidden_window();
   first_buf_id := p_buf_id;
   for (;;) {
      // get the highlight tool window data for this buffer and reset
      HighlightAnalyzer *pHighlighter = HighlightTWGetAnalyzer();
      if (pHighlighter != null) {
         pHighlighter->resetAnalyzer();
      }
      // next please
      _next_buffer("HNR");
      if ( p_buf_id==first_buf_id ) break;
   }
   p_window_id = orig_wid;
}


// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃ HIGHLIGHT TOOL WINDOW BACKGROUND WORK (TIMER CALLBACKS)                   ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

/**
 * Update the word pattern highlighting for all active buffers that 
 * need to be updated. 
 * 
 * @param force    force highlighting to be done immediately. 
 *  
 * @see _UpdateWordHighlightingForEditorWindow
 * @categories Search_Functions
 */
void _UpdateWordHighlighting(bool force=false)
{
   // update highlighting only when the editor has been idle for a while
   idle := _idle_time_elapsed();
   if (!force && idle < def_highlight_tw_delay) {
      return;
   }

   _UpdateWordHighlightingForAllEditorWindows(force, 
                                              (def_highlight_tw_windows == VT_CURRENT_WINDOW),
                                              (def_highlight_tw_windows != VT_ALL_WINDOWS));
}

/**
 * Update the colors for the current highlight profile for the Highlight tool 
 * windown associated with the current editor control.  This is used to update 
 * the highlight tool window after the color profile changes in an editor 
 * control, or after switching files.
 * 
 * @param AlwaysUpdate  force update to be done immediately
 */
static void _UpdateHighlightsToolWindowForCurrentEditorWindow(bool AlwaysUpdate=false)
{
   form_wid := _tbGetActiveHighlightForm(~(TWFF_ACTIVE_FORM|TWFF_FOCUS_FORM));
   if (!form_wid) {
      return;
   }
   editorctl_wid := 0;
   if (_isEditorCtl()) {
      editorctl_wid = p_window_id;
   } else {
      editorctl_wid = form_wid._MDIGetActiveMDIChild();
   }
   if (!editorctl_wid) {
      return;
   }
   _UpdateHighlightsToolWindow(form_wid, editorctl_wid, AlwaysUpdate);
}

/**
 * Update the given Highlight tool window using the color profile for the 
 * given editor control. 
 *    
 * @param form_wid         highlight tool window to update
 * @param editorctl_wid    editor control window to grab color profile from
 * @param AlwaysUpdate     force update to be done immediately
 */
static void _UpdateHighlightsToolWindow(int form_wid, int editorctl_wid, bool AlwaysUpdate) 
{
   if( !tw_is_wid_active(form_wid) ) {
      return;
   }
   if (!editorctl_wid || !_iswindow_valid(editorctl_wid) || !editorctl_wid._isEditorCtl()) {
      return;
   }

   lastColorScheme := p_active_form._GetDialogInfoHt(HIGHLIGHT_TW_KEY_COLOR_PROFILE_NAME);
   if (lastColorScheme == null) {
      lastColorScheme = "";
   }

   newColorScheme := editorctl_wid.p_WindowColorProfile;
   if (newColorScheme == null || newColorScheme == "") {
      newColorScheme = def_color_scheme;
   }

   if (lastColorScheme != newColorScheme) {
      profileName := form_wid.ctl_profile.p_text;
      if (profileName == null || profileName=="") {
         profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
      }
      if (!form_wid.ctl_highlight_words._TreeGetEditorState()) {
         HighlightProfile *pProfileInfo = form_wid._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
         if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
            return;
         }
         form_wid.ctl_highlight_words.HighlightTWAddWordsToTree(profileName, pProfileInfo->m_words, newColorScheme);
      }
   }
}

/**
 * Update word pattern highlighting for all the active editor window which 
 * highlighting is configured to operate on.  This could be just the current 
 * file, or just visible editor windows, or all editor windows. 
 *  
 * When doing multiple files, update the current buffer first, then update 
 * visible editor window, then update other editor windows.
 * 
 * @param force               force update to be done immediately
 * @param doCurrentWindowOnly do highlighting for the current window only
 * @param doVisibleOnly       do highlighting for all visible editor windows
 */
static void _UpdateWordHighlightingForAllEditorWindows(bool force=false, 
                                                       bool doCurrentWindowOnly=false,
                                                       bool doVisibleOnly=false)
{

   // update highlighting only when the editor has been idle for a while
   idle := _idle_time_elapsed();
   if (!force && idle < def_highlight_tw_delay) {
      return;
   }

   _DoCallbackForAllVisibleTabs(gHighlightTWVisibleTabs, 
                                _UpdateWordHighlightingForEditorWindow, 
                                force, doCurrentWindowOnly, doVisibleOnly,
                                def_highlight_tw_delay, 
                                def_highlight_tw_timeout);
}

/**
 * Update the word highlighting for the current file in the current editor window.
 *  
 * @param force         force the highlighting to update now
 * @param doMinimalWork do minimal work, just color the visible lines
 * @param okToRefresh   if {@code true}, refresh the editor window when done, if needed
 * @param tab_index     document tab index of editor window being updated
 * 
 * @return 
 * Return {@literal 0} if the window has been completed. 
 * Return {@literal 1} 1 if we timed out or otherwise did not finish.
 *  
 * @see _UpdateWordHighlighting 
 * @categories Search_Functions
 */
int _UpdateWordHighlightingForEditorWindow(bool force=false, bool doMinimalWork=false, bool okToRefresh=false, int tab_index=0)
{
   //say("_UpdateWordHighlightingForWindow H"__LINE__": HERE");

   // update highlighting only when the editor has been idle for a while
   idle := _idle_time_elapsed();
   if (!force && idle < def_highlight_tw_delay) {
      //say("_UpdateWordHighlightingForWindow H"__LINE__": delay");
      return 1;
   }

   profileName := HighlightTWGetProfileName();
   if (profileName == null) {
      return 1;
   }
   //say("_UpdateWordHighlightingForEditorWindow H"__LINE__": profileName="profileName);
   //say("_UpdateWordHighlightingForEditorWindow H"__LINE__": p_buf_name="p_buf_name);

   // no highlighting allowed in DiffZilla
   if ( _isdiffed(p_buf_id) ) {
      _RemoveVisibleFileTab(gHighlightTWVisibleTabs, p_window_id, tab_index);
      return 0;
   }

   // get the highlight tool window data for this editor control
   HighlightAnalyzer *pHighlighter = HighlightTWGetAnalyzer();
   if (pHighlighter == null) {
      //say("_UpdateWordHighlightingForEditorWindow H"__LINE__": NO ANALYZER");
      return 1;
   }

   // get the list of words to highlight from Highlight tool window form
   HighlightProfile *pProfileInfo = &pHighlighter->m_profileInfo;
   form_wid := _tbGetActiveHighlightForm(~(TWFF_ACTIVE_FORM|TWFF_FOCUS_FORM));
   if (form_wid != 0) {
      //say("_UpdateWordHighlightingForEditorWindow H"__LINE__": HAVE FORM");
      pProfileInfo = form_wid._GetDialogInfoHtPtr(HIGHLIGHT_TW_KEY_HIGHLIGHT_PROFILE_INFO);
      if (pProfileInfo == null || !(*pProfileInfo instanceof se.color.HighlightProfile)) {
         pProfileInfo = &pHighlighter->m_profileInfo;
      }
   }

   // delegate the rest of the work to the highlight analyzer engine
   //say("_UpdateWordHighlightingForEditorWindow H"__LINE__": UPDATE");
   return pHighlighter->updateWordHighlighting(p_window_id,
                                               *pProfileInfo, 
                                               def_highlight_tw_options,
                                               doMinimalWork, okToRefresh);
}

