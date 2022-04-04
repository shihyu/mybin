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
#require "se/color/ColorInfo.e"
#require "se/color/ColorScheme.e"
#import "se/color/SymbolColorAnalyzer.e"
#import "se/color/SymbolColorConfig.e"
#import "se/options/OptionsConfigTree.e"
#import "box.e"
#import "c.e"
#import "cfg.e"
#import "clipbd.e"
#import "color.e"
#import "files.e"
#import "guiopen.e"
#import "ini.e"
#import "listbox.e"
#import "main.e"
#import "markfilt.e"
#import "math.e"
#import "mprompt.e"
#import "optionsxml.e"
#import "picture.e"
#import "saveload.e"
#import "setupext.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "tagfind.e"
#import "util.e"
#endregion

/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;

/**
 * The DefaultColorsConfig class is used to manage the data necessary 
 * for customizing the basic color scheme configuration.  It works closely 
 * with the Colors options dialog. 
 */
class DefaultColorsConfig {

   /**
    * This is the symbol color profile (rule base) which is 
    * currently being edited in the Symbol Coloring options dialog.
    */
   private ColorScheme m_currentProfile;
   /**
    * This is the symbol color profile (rule base) which is 
    * currently being edited in the Symbol Coloring options dialog.
    */
   private ColorScheme m_origProfile;

   /**
    * Has the current symbol coloring profile stored in 
    * m_currentProfile changed or has the currently selected 
    * profile changed. Call profileChanged() to check if just the
    * profile settings changed. 
    */
   private bool m_modified = false;

   /**
    * Temporarily ignore what might appear to be symbol coloring modifications. 
    */
   private bool m_ignoreModifications = false;

   /**
    * This table is used to assign color ID's to each of the the colors 
    * currently being edited in the color form.
    */
   private int m_colorIds[];

   DefaultColorsConfig() {
      m_modified=false;
      m_ignoreModifications=false;
      m_colorIds._makeempty();
   }

   ColorScheme* loadProfile(_str profileName,int optionLevel=0) {
      m_currentProfile.loadProfile(profileName,optionLevel);
      m_origProfile=m_currentProfile;
      m_colorIds._makeempty();
      return &m_currentProfile;
   }
   void resetToOriginal() {
      m_currentProfile=m_origProfile;
      m_colorIds._makeempty();
   }
   void resetColorToOriginal(int cfg) {
      color := m_origProfile.getColor(cfg);
      if (color == null) return;
      m_currentProfile.setColor(cfg, *color);
   }
   /** 
    * @return 
    * Return a pointer to the current color scheme being edited. 
    * This function can not return 'null'. 
    */
   ColorScheme *getCurrentProfile() {
      return &m_currentProfile;
   }

   static bool hasBuiltinProfile(_str profileName) {
      return _plugin_has_builtin_profile(VSCFGPACKAGE_COLOR_PROFILES,profileName);
   }

   /**
    * @return 
    * Return 'true' if the scheme with the given name was added as a system scheme, 
    * but has been modified from its original form by the user. 
    *  
    * @param name    symbol color scheme name 
    */
   bool isModifiedBuiltinProfile() {
      if (!_plugin_has_builtin_profile(VSCFGPACKAGE_COLOR_PROFILES,m_currentProfile.m_name)) {
         return false;
      }
      
      ColorScheme builtin_profile;
      builtin_profile.loadProfile(m_currentProfile.m_name,1);
      return m_currentProfile!=builtin_profile;
   }

   /**
    * @return 
    * Has the current color scheme changed since we started editing it? 
    */
   bool isModified() {
      return m_modified;
   }
   bool profileChanged() {
      return m_currentProfile != m_origProfile;
   }
   /**
    * Mark the current color scheme as modified or not modified.  This 
    * function will also relay the modification information to the main 
    * options dialog so that it knows that the Colors options panel has
    * unsaved modifications to save. 
    *  
    * @param onoff   'true' for a modification, 'false' if we are resetting modify 
    */
   void setModified(bool onoff=true) {
      if (onoff && m_ignoreModifications) return;
      m_modified = onoff;
   }

   /**
    * Temporarily ignore any modfications being made to the color scheme. 
    * This should be used when loading color schemes, to prevent callbacks 
    * that are populating the form from triggering modify callbacks when 
    * on_change() events are generated. 
    *  
    * @param onoff   'true' to ignore modifications, false otherwise. 
    *  
    * @return Returns the original state of ignoring modifications (true/false). 
    */
   void setIgnoreChanges(bool onoff) {
      m_ignoreModifications = onoff;
   }
   /**
    * @return 
    * Return 'true' if we are ignoring modifications temporilary. 
    */
   bool ignoreChanges() {
      return m_ignoreModifications;
   }

   /**
    * Set the color settings displayed in the Colors options dialog to the 
    * options currently in use. 
    */
   ColorScheme *loadFromDefaultColors() {
      m_currentProfile.loadCurrentColorProfile();
      m_origProfile=m_currentProfile;
      return &m_currentProfile;
   }
   /** 
    * @return 
    * Return a color ID, possibly allocated for the given color in 
    * the current scheme.  If a color is allocated, it will be free'd 
    * by this same class. 
    * 
    * @param cfg     CFG_* color constant 
    */
   int getColorIdForCurrentProfile(int cfg) {
      // no scheme, revert to plain text color
      if (m_currentProfile == null) {
         return CFG_WINDOW_TEXT;
      }
      // no such color, revert to plain text color
      ColorInfo *colorInfo = m_currentProfile.getColor(cfg);
      if (colorInfo == null) {
         return CFG_WINDOW_TEXT;
      }
      // no difference from default color, then use default
      if (colorInfo->matchesColor(cfg, &m_currentProfile)) {
         return cfg;
      }
      // allocate a color ID if we need one
      if (m_colorIds._length() <= cfg || m_colorIds[cfg]==null || m_colorIds[cfg] == 0) {
         m_colorIds[cfg] = colorInfo->allocateColorId(&m_currentProfile);
         return m_colorIds[cfg]; 
      }
      // color hasn't changed since allocated?
      if (!colorInfo->matchesColor(m_colorIds[cfg], &m_currentProfile)) {
         colorInfo->setColor(m_colorIds[cfg], &m_currentProfile);
      }
      // return the allocated color ID
      return m_colorIds[cfg];
   }

};


///////////////////////////////////////////////////////////////////////////
// Switch to the global namespace
//
namespace default;

using se.color.SymbolColorAnalyzer;
using se.color.ColorScheme;
using se.color.DefaultColorsConfig;

/** 
 *  
 */
definit() 
{
}

///////////////////////////////////////////////////////////////////////////
// The following code is used to implement the Colors options dialog.
///////////////////////////////////////////////////////////////////////////

defeventtab _color_form;

/**
 * Document name for color coding sample text buffer.
 */
static const SAMPLE_COLOR_FORM_DOC_NAME= ".Sample Color Preview Window Buffer";
static const SAMPLE_COLOR_MODIFIED_SCHEME= "--SAMPLE-COLOR-MODIFIED-SCHEME--";

/**
 * Store the buffer ID of the color coding sample text buffer in its p_user.
 */
static int SampleColorEditWindowBufferID(...) 
{
   if (arg()) ctl_code_sample.p_user=arg(1);
   return ctl_code_sample.p_user;
}

/**
 * Get the DefaultColorsConfig class instance, which is stored in 
 * the p_user of the schemes control. 
 * 
 * @return se.color.DefaultColorsConfig* 
 */
static se.color.DefaultColorsConfig *getDefaultColorsConfig()
{
   if (ctl_scheme.p_user instanceof se.color.DefaultColorsConfig) {
      return &ctl_scheme.p_user;
   }
   return null;
}

/**
 * Gets the scheme name that was in place when the user opened the dialog OR the 
 * most recently applied on. 
 * 
 * @return scheme name
 */
static _str getOriginalColorProfileName()
{
   return ctl_editor_label.p_user;
}

/**
 * Gets the minimap scheme name that was in place when the user opened the dialog OR the 
 * most recently applied on. 
 * 
 * @return scheme name
 */
static _str getOriginalMinimapProfileName()
{
   return ctl_minimap_label.p_user;
}

/**
 * Get the ColorScheme class instance being edited. 
 * It is obtained though the master DefaultColorsConfig object. 
 * 
 * @return se.color.ColorScheme* 
 */
static se.color.ColorScheme *getColorScheme()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return null;
   return dcc->getCurrentProfile();
}

/**
 * Get the current ColorInfo being edited.  It is obtained by looking 
 * at the color name currently selected in the Colors options dialog.
 * 
 * @return se.color.ColorInfo* 
 */
static se.color.ColorInfo *getColorInfo()
{
   scm := getColorScheme();
   if (scm == null) return null;

   index := ctl_rules._TreeCurIndex();
   if (index <= TREE_ROOT_INDEX) return null;

   colorId := getColorId();
   if (colorId != null && colorId != "") {
      return scm->getColor(colorId);
   }
   return null;
}

/**
 * Get the current ColorInfo being edited.  It is obtained by looking 
 * at the color name currently selected in the Colors options dialog.
 * 
 * @return se.color.ColorInfo* 
 */
static se.color.ColorInfo *getEmbeddedColorInfo()
{
   scm := getColorScheme();
   if (scm == null) return null;

   colorId := getColorId();
   if (colorId > 0) {
      return scm->getEmbeddedColor(colorId);
   }
   return null;
}

/** 
 * @return 
 * Return the color ID for the current color being edited.  It is obtained by 
 * looking at the color name currently selected in the Colors options dialog. 
 */
static int getColorId()
{
   index := ctl_rules._TreeCurIndex();
   if (index <= TREE_ROOT_INDEX) return 0;
   if (ctl_rules._TreeGetDepth(index) <= 1) return 0;
   return ctl_rules._TreeGetUserInfo(index);
}

/**
 * Update this color in the tree control.  The current window ID is expected 
 * to the be tree control containing all the color names (ctl_rules). 
 * 
 * @param treeIndex       index in tree control to modify
 * @param scm             color scheme object
 * @param cfg              color constant for item to modify.
 */
static void loadTreeNodeColor(int treeIndex, se.color.ColorScheme *scm, int cfg)
{
   color := scm->getColor(cfg);
   if (color == null) return;
   fg_color := color->getForegroundColor(scm);
   bg_color := color->getBackgroundColor(scm);
   em_color := scm->getEmbeddedBackgroundColor(cfg);

   fontFlags := 0;
   switch (cfg) {
   case CFG_CURRENT_LINE_BOX:
   case CFG_VERTICAL_COL_LINE:
   case CFG_MARGINS_COL_LINE:
   case CFG_TRUNCATION_COL_LINE:
   case CFG_PREFIX_AREA_LINE:
   case CFG_SELECTIVE_DISPLAY_LINE:
   case CFG_MINIMAP_DIVIDER:
      bg_color = scm->getColor(CFG_WINDOW_TEXT)->getBackgroundColor();
      em_color = bg_color;
      ctl_rules._TreeSetRowColor(treeIndex, fg_color, bg_color, fontFlags);
      break;
   case CFG_LINEPREFIXAREA:
      em_color = bg_color;
      ctl_rules._TreeSetRowColor(treeIndex, fg_color, bg_color, fontFlags);
      break;
   case CFG_STATUS:
   case CFG_CMDLINE:
   case CFG_MESSAGE:
   case CFG_MODIFIED_ITEM:
   case CFG_NAVHINT:
      bg_color = VSDEFAULT_BACKGROUND_COLOR;
      em_color = VSDEFAULT_BACKGROUND_COLOR;
      fontFlags = F_INHERIT_BG_COLOR;
      ctl_rules._TreeSetRowColor(treeIndex, fg_color, bg_color, fontFlags);
      break;
   case CFG_LIVE_ERRORS_ERROR:
   case CFG_LIVE_ERRORS_WARNING:
      bg_color = scm->getColor(CFG_WINDOW_TEXT)->getBackgroundColor();
      ctl_rules._TreeSetRowColor(treeIndex, fg_color, bg_color, fontFlags);
      break;
   case CFG_DOCUMENT_TAB_ACTIVE:
   case CFG_DOCUMENT_TAB_SELECTED:
   case CFG_DOCUMENT_TAB_UNSELECTED:
   case CFG_DOCUMENT_TAB_MODIFIED:
      is_system_default := (fg_color < 0 || fg_color == VSDEFAULT_FOREGROUND_COLOR) && 
                           (bg_color < 0 || bg_color == VSDEFAULT_BACKGROUND_COLOR);
      if (is_system_default || cfg == CFG_DOCUMENT_TAB_MODIFIED) {
         bg_color = VSDEFAULT_BACKGROUND_COLOR;
         fontFlags = F_INHERIT_BG_COLOR;
      }
      em_color = bg_color;
      ctl_rules._TreeSetRowColor(treeIndex, fg_color, bg_color, fontFlags);
      break;
   default:
      ctl_rules._TreeSetColor(treeIndex, 0, fg_color, bg_color, fontFlags);
      ctl_rules._TreeSetColor(treeIndex, 1, fg_color, em_color, fontFlags);
      break;
   }
}

/**
 * Load all the colors into the tree control pushing them into categories
 */
static void loadAllColorsInTree(se.color.ColorScheme *scm)
{
   // load all the individual colors
   if (scm == null) return;
   ctl_rules._TreeBeginUpdate(TREE_ROOT_INDEX);
   ctl_rules._TreeDelete(TREE_ROOT_INDEX,'c');
   for ( cfg:=1; cfg<=CFG_LAST_DEFAULT_COLOR; cfg++) {
      // for v17, we removed this option
      if (cfg == CFG_STATUS) continue;

      // remove items that don't apply to Standard edition
      if (!_haveBuild() && cfg==CFG_ERROR) continue;
      if (!_haveContextTagging() && cfg==CFG_SYMBOL_HIGHLIGHT) continue;
      if (!_haveContextTagging() && cfg>=CFG_REF_HIGHLIGHT_0 && cfg <= CFG_REF_HIGHLIGHT_7) continue;
      if (!_haveContextTagging() && cfg>=CFG_FIRST_SYMBOL_COLOR && cfg <= CFG_LAST_SYMBOL_COLOR) continue;
      if (!_haveDebugging() && cfg==CFG_MODIFIED_ITEM) continue;
      if (!_haveRealTimeErrors() && 
          (cfg == CFG_LIVE_ERRORS_ERROR || cfg == CFG_LIVE_ERRORS_WARNING)) 
         continue;

      if (scm->getColor(cfg) == null) continue;
      colorName := scm->getColorName(cfg);
      categoryPriority := 0;
      categoryName := scm->getColorCategoryName(cfg,categoryPriority);
      if (colorName == null || categoryName == null) continue;
      categoryNode := ctl_rules._TreeSearch(TREE_ROOT_INDEX, categoryName);
      if (categoryNode <= 0) {
         categoryNode = ctl_rules._TreeAddItem(TREE_ROOT_INDEX, categoryName,
                                               TREE_ADD_AS_CHILD, 0, 0, TREE_NODE_EXPANDED, 
                                               TREENODE_BOLD, categoryPriority);
      }
      if (colorName=="") continue;

      embeddedText := "";
      switch (cfg) {
      case CFG_CURRENT_LINE_BOX:
      case CFG_VERTICAL_COL_LINE:
      case CFG_MARGINS_COL_LINE:
      case CFG_TRUNCATION_COL_LINE:
      case CFG_PREFIX_AREA_LINE:
      case CFG_SELECTIVE_DISPLAY_LINE:
      case CFG_MINIMAP_DIVIDER:
      case CFG_LINEPREFIXAREA:
      case CFG_STATUS:
      case CFG_CMDLINE:
      case CFG_MESSAGE:
      case CFG_DOCUMENT_TAB_ACTIVE:
      case CFG_DOCUMENT_TAB_SELECTED:
      case CFG_DOCUMENT_TAB_UNSELECTED:
      case CFG_DOCUMENT_TAB_MODIFIED:
      case CFG_MODIFIED_ITEM:
      case CFG_NAVHINT:
      case CFG_LIVE_ERRORS_ERROR:
      case CFG_LIVE_ERRORS_WARNING:
         break;
      default:
         embeddedText = "\t" :+ "Embedded";
         break;
      }

      treeIndex := ctl_rules._TreeAddItem(categoryNode, colorName :+ embeddedText,
                                          TREE_ADD_AS_CHILD, 0, 0, TREE_NODE_LEAF, 0, cfg);

      // show color preview in the tree control
      ctl_rules.loadTreeNodeColor(treeIndex, scm, cfg);
   }
   ctl_rules._TreeEndUpdate(TREE_ROOT_INDEX);
   ctl_rules._TreeSizeColumnToContents(0);

   // sort items under each category
   ctl_rules._TreeSortUserInfo(TREE_ROOT_INDEX,'N');
   treeIndex := ctl_rules._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   while (treeIndex > 0) {
      ctl_rules._TreeSortCaption(treeIndex);
      treeIndex = ctl_rules._TreeGetNextSiblingIndex(treeIndex);
   }
   
}

static void loadScheme() 
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := dcc->getCurrentProfile();

   origIgnore := dcc->ignoreChanges();
   dcc->setIgnoreChanges(true);

   // set up the list of compatible color schemes
   ctl_symbol_scheme._lbaddSymbolColoringSchemeNames();
   if (scm != null &&
       scm->m_symbolColoringProfile != null && 
       scm->m_symbolColoringProfile != "") {
      ctl_symbol_scheme._lbfind_and_select_item(scm->m_symbolColoringProfile);
   } else {
      ctl_symbol_scheme.p_text = "(None)";
   }

   // load all the individual colors
   loadAllColorsInTree(scm);

   dcc->setIgnoreChanges(origIgnore);
   dcc->setModified(false);
}

/**
 * Refresh all the information about the currently selected color
 * in the list of color names and descriptions.
 */
static void updateCurrentColor()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   if (dcc->ignoreChanges()) return;

   color := getColorInfo();
   index := ctl_rules._TreeCurIndex();
   ctl_rules.p_redraw=true;

   scm := dcc->getCurrentProfile();
   if (scm == null) return;
   dcc->setModified(true);
   //profileName := strip(ctl_scheme.p_text);

   ctl_code_sample.updateSampleCode();

   // show color preview in the tree control
   ctl_rules.loadTreeNodeColor(index, scm, getColorId());
}

/**
 * Update the color coding for the language specific sample code. 
 */
static void updateSampleCode()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   if (dcc->ignoreChanges()) return;
   scm := dcc->getCurrentProfile();
   if (scm == null) return;

   // set up the color scheme for the sample code
   scm->applyColorProfileAs(SAMPLE_COLOR_MODIFIED_SCHEME);
   p_WindowColorProfile = SAMPLE_COLOR_MODIFIED_SCHEME;

   // get the selected color scheme names
   colorProfileName   := ColorScheme.removeProfilePrefix(strip(ctl_scheme.p_text));
   minimapProfileName := ColorScheme.removeProfilePrefix(strip(ctl_minimap_scheme.p_text));
   if (minimapProfileName == "" || minimapProfileName == colorProfileName) {
      minimapProfileName = SAMPLE_COLOR_MODIFIED_SCHEME;
   }

   // get the minimap wid and update it's minimap scheme
   minimap_wid := ctl_code_sample.p_minimap_wid;
   if (minimap_wid && _iswindow_valid(minimap_wid)) {
      minimap_wid.p_WindowColorProfile = minimapProfileName;
   }

   return;
}

/**
 * Change the text in the color selection box depending on whether
 * it is currently enabled or not.  Display slashes when it is
 * disabled, and a message saying to click here when it is enabled.
 */
static void enableColorControl()
{
   inherit := false;
   inherit_checkbox := p_prev;
   while (inherit_checkbox != p_window_id) {
      if (inherit_checkbox.p_object == OI_CHECK_BOX) {
         inherit = (inherit_checkbox.p_visible && inherit_checkbox.p_enabled && inherit_checkbox.p_value != 0);
         break;
      }
      inherit_checkbox = inherit_checkbox.p_prev;
   }

   orig_width := p_width;
   p_forecolor = 0x606060;
   if (inherit) {
      p_caption = "/////////////////////////////";
   } else {
      p_caption = "Click to change color...";
   }
   p_width = orig_width; 
}

/**
 * Load the given color into the Colors dialog. 
 *  
 * @param cfg      color ID 
 * @param color    color specification
 */
static void loadColor(int cfg)
{
   // get the symbol color configuration manager object
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   if (cfg == 0) {
      enableColorSettings(0);
      return;
   }

   // if they gave us a null color, disable everything, otherwise enable form
   ctl_color_note.p_enabled = true;
   enableColorSettings(cfg);

   // set up the color description
   scm := getColorScheme();
   if (scm == null) return;
   ctl_color_note.p_caption = scm->getColorDescription(cfg);

   // disable all on_change callbacks
   origIgnore := dcc->ignoreChanges();
   dcc->setIgnoreChanges(true);

   // fill in the color information
   color := scm->getColor(cfg);
   if (ctl_system_default.p_enabled) {
      ctl_system_default.p_value = ((color->m_foreground < 0 || color->m_foreground == VSDEFAULT_FOREGROUND_COLOR) && 
                                    (color->m_background < 0 || color->m_background == VSDEFAULT_BACKGROUND_COLOR))? 1:0;
   }

   if (ctl_system_default.p_enabled && ctl_system_default.p_value) {
      _system_default_color_state(true);
   } else {
      ctl_foreground_color.p_backcolor = color->getForegroundColor(scm);
      ctl_background_color.p_backcolor = color->getBackgroundColor(scm);
      ctl_embedded_color.p_backcolor = scm->getEmbeddedBackgroundColor(cfg);
   }

   ctl_background_inherit.p_value = (color->getFontFlags(scm) & F_INHERIT_BG_COLOR)? 1:0;
   ctl_foreground_color.enableColorControl();
   ctl_background_color.enableColorControl();
   ctl_embedded_color.enableColorControl();

   // fill in the font information
   ctl_italic.p_value = (color->getFontFlags(scm) & F_ITALIC)? 1:0;  
   ctl_bold.p_value = (color->getFontFlags(scm) & F_BOLD)? 1:0;  
   ctl_underline.p_value = (color->getFontFlags(scm) & F_UNDERLINE)? 1:0;  
   ctl_strikeout.p_value = (color->getFontFlags(scm) & F_STRIKE_THRU)? 1:0;  
   //ctl_normal.p_value = (color->getFontFlags(scm) & (F_ITALIC|F_BOLD|F_UNDERLINE))? 0:1;
   
   // fill in the sample color display
   ctl_sample.p_forecolor = ctl_foreground_color.p_backcolor;  
   ctl_sample.p_backcolor = ctl_background_color.p_backcolor;
   ctl_embedded_sample.p_forecolor = ctl_foreground_color.p_backcolor;  
   ctl_embedded_sample.p_backcolor = ctl_embedded_color.p_backcolor;
   ctl_sample.p_font_bold      = (color->getFontFlags(scm) & F_BOLD) != 0;
   ctl_sample.p_font_italic    = (color->getFontFlags(scm) & F_ITALIC) != 0;
   ctl_sample.p_font_underline = (color->getFontFlags(scm) & F_UNDERLINE) != 0;
   ctl_sample.p_font_strike_thru = (color->getFontFlags(scm) & F_STRIKE_THRU) != 0;
   ctl_embedded_sample.p_font_bold      = ctl_sample.p_font_bold;            
   ctl_embedded_sample.p_font_italic    = ctl_sample.p_font_italic;    
   ctl_embedded_sample.p_font_underline = ctl_sample.p_font_underline;
   ctl_embedded_sample.p_font_strike_thru = ctl_sample.p_font_strike_thru;

   // make sure color current line is turned on if that is the selected item
   if (cfg == CFG_CLINE || cfg == CFG_SELECTED_CLINE) {
      if (!(ctl_code_sample.p_color_flags & CLINE_COLOR_FLAG) || 
          !(ctl_code_sample.p_window_flags & VSWFLAG_CURLINE_COLOR)) {
         ctl_code_sample.p_window_flags |= VSWFLAG_CURLINE_COLOR;
         ctl_code_sample.p_color_flags |= CLINE_COLOR_FLAG;
         ctl_code_sample.refresh();
      }
   } else {
      if ((ctl_code_sample.p_color_flags & CLINE_COLOR_FLAG) || 
          (ctl_code_sample.p_window_flags & VSWFLAG_CURLINE_COLOR)) {
         ctl_code_sample.p_window_flags &= ~VSWFLAG_CURLINE_COLOR;
         ctl_code_sample.p_color_flags &= ~CLINE_COLOR_FLAG;
         ctl_code_sample.refresh();
      }
   }

   // done, back to business as usual 
   dcc->setIgnoreChanges(origIgnore);
}

/**
 * Load the color scheme names into a combo box 
 *  
 * @param dcc              Color configuration manager object 
 * @param includeAutomatic   include "Automatic" as a color profile name
 * @param includeOnlyBuiltin only include built-in symbol color profiles 
 */
void _lbaddColorProfileNames(se.color.DefaultColorsConfig &dcc, bool includeAutomatic=true, bool includeOnlyBuiltin=false)
{
   p_picture = _pic_lbvs;
   p_pic_space_y = 60;
   p_pic_point_scale = 8;
   _str profileNames[];
   ColorScheme.listProfiles(profileNames,true);
   name := "";
   _lbclear();
   if (includeAutomatic) {
      _lbadd_item(CONFIG_AUTOMATIC,60,_pic_lbvs);
   }

   foreach (name in profileNames) {
      if (DefaultColorsConfig.hasBuiltinProfile(ColorScheme.removeProfilePrefix(name))) {
         _lbadd_item(name,60,_pic_lbvs);
      } else if (!includeOnlyBuiltin) {
         _lbadd_item(name,60,_pic_lbuser);
      }
   }
}

/** 
 * @return 
 * Return the color index (CFG_*) for the color currently under the cursor.
 * 
 * @param editorctl_wid   editor control window to check
 */
int _ColorFormGetColorIndexUnderCursor(int editorctl_wid)
{
   // select the color under the cursor if we have an MDI editor window
   int cfg = CFG_WINDOW_TEXT;
   if (!_no_child_windows() && editorctl_wid && _iswindow_valid(editorctl_wid)) {
      // syntax coloring item
      cfg = editorctl_wid._clex_find(0, 'D');

      // check if there is a rule we should pre-select, corresponding to the
      // current symbol under the cursor.
      se.color.SymbolColorAnalyzer *analyzer = _mdi.p_child._GetBufferInfoHtPtr("SymbolColorAnalyzer");
      if (analyzer != null) {
         orig_wid := p_window_id;
         p_window_id = editorctl_wid;
         currentRule := analyzer->getSymbolColorUnderCursor();
         p_window_id = orig_wid;
         if (currentRule != null) {
            colorInfo := currentRule->m_colorInfo;
            if (colorInfo != null && colorInfo.inheritsEverything()) {
               parentId := colorInfo.getParentColorIndex();
               if (parentId > 0 && parentId < CFG_LAST_COLOR_PLUS_ONE) {
                  cfg = parentId;
               }
            }
         }
      }
   }
   return cfg;
}

/**
 * Initialize the Colors options dialog.
 */
void ctl_code_sample.on_create()
{
   // The symbol color configuration dialog manager object goes
   // in the p_user of 'ctl_scheme'
   ctl_scheme.p_user = null;

   // load default schemes and the current symbol coloring scheme
   se.color.DefaultColorsConfig dcc;
   dcc.loadFromDefaultColors();
   
   // show the minimap in the sample code area
   if (ctl_minimap_scheme.p_visible) {
      ctl_code_sample.p_window_flags |= VSWFLAG_SHOW_MINIMAP;
      ctl_code_sample.p_minimap_width_is_fixed = true;
      ctl_code_sample.p_minimap_width = (ctl_code_sample.p_width intdiv 4);
   }

   // load all the scheme names into the combo box, putting
   // user defined schemes at the top of the list.
   ctl_scheme._lbaddColorProfileNames(dcc, false);

   // load the options for the default editor schemes
   ctl_editor_scheme._lbaddColorProfileNames(dcc);
   ctl_editor_scheme._lbsort('i');

   // load the options for the minimap schemes, including "" for the default to
   // use the same scheme name as the main editor control
   ctl_minimap_scheme._lbaddColorProfileNames(dcc);
   ctl_minimap_scheme._lbadd_item("");
   ctl_minimap_scheme._lbsort('i');

   // determine the current scheme, mark it as modified if necessary
   editorProfileName  := ColorScheme.getDefaultProfile();
   minimapProfileName := ColorScheme.getMinimapProfile(allowEmpty:true);

   // if there is an editor control we are launching form, use it's active color profile
   currentProfileName := editorProfileName;
   if (!_no_child_windows()) {
      currentProfileName = _mdi.p_child.p_WindowColorProfile;
      if (currentProfileName == null || currentProfileName == "") {
         currentProfileName = editorProfileName;
      }
   }

   ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(editorProfileName));
   ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(minimapProfileName));
   ctl_scheme._cbset_text(ColorScheme.realProfileNameWithPrefix(currentProfileName));
   scm := dcc.loadFromDefaultColors();
   associated_symbol_profile := _plugin_get_property(VSCFGPACKAGE_COLOR_PROFILES,ColorScheme.realProfileName(currentProfileName),'associated_symbol_profile');

   // make the minimap show the default scheme name when empty
   if (ctl_minimap_scheme.p_text == "") ctl_minimap_scheme.p_style = PSCBO_EDIT;
   ctl_minimap_scheme.p_user = ctl_editor_scheme._lbget_text();
   ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, ctl_editor_scheme._lbget_text());

   // make sure button sizes are consistent.
   resizeControlsIdentically(ctl_symbol_coloring.p_window_id,
                             ctl_reset_colors.p_window_id);
   resizeControlsIdentically(ctl_save_scheme_as.p_window_id,
                             ctl_delete_scheme.p_window_id,
                             ctl_rename_scheme.p_window_id,
                             ctl_reset_scheme.p_window_id,
                             ctl_import_scheme.p_window_id);

   // make sure the font check boxes fit
   alignControlsHorizontal(ctl_bold.p_x, ctl_bold.p_y, 
                           ctl_bold.p_x intdiv 4, 
                           ctl_bold.p_window_id,
                           ctl_italic.p_window_id,
                           ctl_underline.p_window_id,
                           ctl_strikeout.p_window_id);
   font_width := ctl_strikeout.p_x_extent + ctl_bold.p_x;
   ctl_font_frame.p_width = font_width;
   ctl_sample.p_width = font_width - 30;
   ctl_embedded_sample.p_width = font_width - 30;
   ctl_sample.p_height = max(ctl_sample.p_height,  ctl_embedded_sample.p_height);
   ctl_embedded_sample.p_height = ctl_sample.p_height;
   ctl_embedded_sample.p_y = ctl_sample.p_y_extent;
   ctl_embedded_sample.p_x = ctl_sample.p_x;

   // symbol coloring relies on context tagging, so if it's gone, no symbol coloring
   if (_haveContextTagging()) {
      // set up the list of compatible color profiles
      ctl_symbol_scheme._lbaddSymbolColoringSchemeNames(ColorScheme.realProfileName(currentProfileName));
      if (associated_symbol_profile != "") {
         ln := ctl_symbol_scheme._lbfind_item(associated_symbol_profile);
         if (ln < 0) {
            associated_symbol_profile = _plugin_get_property(VSCFGPACKAGE_COLOR_PROFILES,
                                                             ColorScheme.realProfileName(currentProfileName),
                                                             'associated_symbol_profile',
                                                             defaultValue: "All Symbols", 
                                                             optionLevel: 1);
            ln = ctl_symbol_scheme._lbfind_item(associated_symbol_profile);
            if (ln < 0) associated_symbol_profile = "";
         }
      }
      if (associated_symbol_profile != "") {
         ctl_symbol_scheme._cbset_text(associated_symbol_profile);
      } else {
         ctl_symbol_scheme._cbset_text("(None)");
      }
   } else {
      // just hide everything
      ctl_assoc_label.p_visible = false;
      ctl_symbol_scheme.p_visible = false;
      ctl_symbol_coloring.p_visible = false;
   }
   
   // load all the individual color names
   loadAllColorsInTree(scm);

   // set up the buffer name for the sample code buffer
   ctl_code_sample.docname(SAMPLE_COLOR_FORM_DOC_NAME);
   SampleColorEditWindowBufferID(ctl_code_sample.p_buf_id);

   // the small sample text needs to use the editor control font
   ctl_mode_name._lbaddModeNames();
   ctl_mode_name._lbadd_item(VS_TAG_FIND_TYPE_BUFFER_ONLY);
   ctl_mode_name._lbsort();
   ctl_sample._use_edit_font();
   ctl_embedded_sample._use_edit_font();

   mode_name:= _retrieve_value("_color_form.ctl_mode_name");
   if (mode_name!='') {
      if (ctl_mode_name._lbfind_and_select_item(mode_name)) {
         mode_name='';
      }
   }
   if (mode_name=='') mode_name=_LangGetModeName("c");
   ctl_mode_name._lbfind_and_select_item(mode_name);

   ctl_code_sample.p_window_flags|=OVERRIDE_CURLINE_COLOR_WFLAG;  // Disable curline color

   // finally, load the current symbol coloring scheme into the form 
   ctl_scheme.p_user = dcc;
   loadScheme();

   ctl_mode_name.call_event(CHANGE_SELECTED,ctl_mode_name,ON_CHANGE,"");
   ctl_code_sample.updateSampleCode();
   ctl_rules.p_AlwaysColorCurrent = true;
   ctl_rules._TreeRefresh();

   // force the selected color schemes to be updated
   ctl_scheme.call_event(CHANGE_CLINE,ctl_scheme,ON_CHANGE,"");
   ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");

   // select the color under the cursor if we have an MDI editor window
   int cfg = CFG_WINDOW_TEXT;
   if (!_no_child_windows()) {
      cfg = _ColorFormGetColorIndexUnderCursor(_mdi.p_child);
   }
   _ColorFormSelectColor(cfg);

   // update button enable/disable status
   updateButtons();
}

/**
 * If the sample code editor window is displaying the current file, then 
 * close it and jump back to its original buffer. 
 */
void _ClearSampleColorCode() 
{
   if ( SampleColorEditWindowBufferID() != p_buf_id ) {
      ctl_code_sample.load_files("+q +m +bi "SampleColorEditWindowBufferID());
   }
}

/**
 * Cleanup
 */
void _color_form.on_destroy()
{
   ctl_code_sample._ClearSampleColorCode();
   _append_retrieve(0, ctl_mode_name.p_text,
                    "_color_form.ctl_mode_name");
   // destroy the config object
   p_user = null;
}

/**
 * Handle form resizing.  Stretches out the color list
 * vertically.  Stretches out kinds and attributes horizontally. 
 * Other items remain in the same relative positions. 
 */
void _color_form.on_resize()
{
   // total size
   width  := _dx2lx(p_xyscale_mode,p_active_form.p_client_width);
   height := _dy2ly(p_xyscale_mode,p_active_form.p_client_height);
   padding := ctl_rules.p_x;

   // calculate a minimum width for the foreground color frame.
   min_color_width := ( ctl_foreground_frame._text_width(ctl_foreground_frame.p_caption) + 
                        ctl_reset_selected_color.p_width + 3*padding );

   // if the minimum width has not been set, it will return 0
   if (!_minimum_width()) {
      min_width := ( ctl_assoc_label.p_width +
                     min_color_width +
                     ctl_font_frame.p_width +
                     4*padding );
      min_height := ( ctl_sample_frame.p_y + ctl_foreground_color.p_height);
      _set_minimum_size(min_width, min_height);
   }

   // adjust the size of both frames
   frame_x := ctl_default_profiles_frame.p_x;
   ctl_default_profiles_frame.p_width = (width - frame_x);
   ctl_edit_profile_frame.p_width = (width - frame_x);
   ctl_edit_profile_frame.p_height = height - ctl_edit_profile_frame.p_y;
   ctl_edit_profile_frame.p_x = frame_x;
   width -= 2*frame_x;

   // Adjust the position and width of the combo boxes
   combo_width := (width - ctl_reset_colors.p_width - 3*padding) intdiv 2;
   column2_x   := padding + combo_width + padding;
   column3_x   := column2_x + combo_width + padding;
   ctl_editor_scheme.p_width = combo_width;
   ctl_minimap_scheme.p_width = combo_width;
   ctl_scheme.p_width = combo_width;
   ctl_symbol_scheme.p_width = combo_width;
   ctl_minimap_label.p_x = column2_x;
   ctl_minimap_scheme.p_x = column2_x;
   ctl_assoc_label.p_x = column2_x;
   ctl_symbol_scheme.p_x = column2_x;
   ctl_reset_colors.p_x = column3_x;
   ctl_symbol_coloring.p_x = column3_x;

   // adjust the size of the list of rules
   list_height := ctl_edit_profile_frame.p_height - ctl_rules.p_y - 2*padding;
   list_width := width - min_color_width - ctl_font_frame.p_width - 4*padding;
   extra_width := 0;
   if (list_width > ctl_font_frame.p_width) {
      extra_width = (list_width - ctl_font_frame.p_width) intdiv 4; 
      list_width -= extra_width;
   }
   ctl_rules.p_width = list_width;
   ctl_rules.p_height = list_height;

   // adjust the x-positions of the color editing controls.
   color_x := ctl_rules.p_x_extent + 2*padding;
   ctl_color_note.p_x = color_x;
   ctl_foreground_frame.p_x = color_x;
   ctl_background_frame.p_x = color_x;
   ctl_sample_frame.p_x = color_x;

   // adjust the width of the color description
   ctl_color_note.p_width = (width - ctl_color_note.p_x);
   
   // adjust the width of the foreground and background color frames
   color_width := min_color_width + extra_width;
   ctl_foreground_frame.p_width = color_width;
   ctl_foreground_color.p_width = color_width - 2*ctl_foreground_color.p_x;
   ctl_reset_selected_color.p_x = color_width - ctl_reset_selected_color.p_width - padding;
   ctl_background_frame.p_width = color_width;
   ctl_background_color.p_width = color_width - 2*ctl_background_color.p_x;
   ctl_embedded_color.p_width = color_width - 2*ctl_background_color.p_x;
   ctl_background_inherit.p_x = color_width - ctl_background_inherit.p_width - padding;

   // adjust the x-positions of the font editing controls
   font_x := ctl_foreground_frame.p_x_extent + padding;
   ctl_system_default.p_x = font_x + padding;
   ctl_font_frame.p_x = font_x;
   ctl_sample.p_x = font_x;
   ctl_embedded_sample.p_x = font_x;

   // adjust the size of the sample code frame.
   sample_height := (ctl_edit_profile_frame.p_height - ctl_background_frame.p_y_extent - 4*padding);
   adjust_sample_height := (sample_height - ctl_sample_frame.p_height);
   ctl_sample_frame.p_width = (width - ctl_sample_frame.p_x - padding);
   ctl_sample_frame.p_height = sample_height;
   ctl_code_sample.p_height = ctl_sample_frame.p_height - ctl_code_sample.p_y - padding;
   ctl_code_sample.p_width = ctl_sample_frame.p_width - 2*ctl_code_sample.p_x;
   ctl_mode_name.p_width = color_width - ctl_mode_name.p_x;
}

/**
 * Callback for handling the [OK] or [Apply] buttons on the
 * master configuration dialog when the symbol coloring
 * properties are modified and need to be recalculated.
 */
void _color_form_apply()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := dcc->getCurrentProfile();
   if (scm == null) return;

   // save the color profile they were editing
   scm->saveProfile();
   scm->applyColorProfile();
   _config_modify_flags(CFGMODIFY_DEFVAR);

   // get the default editor scheme name
   editorSchemeChanged := false;
   editorProfileName := ColorScheme.removeProfilePrefix(ctl_editor_scheme._lbget_text());
   if (editorProfileName != def_color_scheme) {
      ColorScheme editor_scm;
      editor_scm.loadProfile(editorProfileName);
      editor_scm.applyColorProfile(editorProfileName);
      editor_scm.applySymbolColorProfile();
      editor_scm.insertMacroCode(macroRecording:true);
      editorSchemeChanged = true;
   }

   // update the default minimap scheme also
   minimapProfileName := ColorScheme.removeProfilePrefix(ctl_minimap_scheme._lbget_text());
   followEditorProfile := false;
   if ((editorSchemeChanged && def_minimap_color_scheme == "") || minimapProfileName != def_minimap_color_scheme) {
      if (minimapProfileName == "") {
         minimapProfileName = ColorScheme.removeProfilePrefix(ctl_editor_scheme._lbget_text());
         followEditorProfile = true;
      }
      ColorScheme minimap_scm;
      minimap_scm.loadProfile(minimapProfileName);
      minimap_scm.applyMinimapColorProfile(minimapProfileName, followEditorProfile);
      minimap_scm.insertMinimapMacroCode(macroRecording:true, followEditorProfile);
   }

   dcc->setModified(false);
   call_list("_color_profile_modified_", scm->m_name);
}

/**
 * Callback for handling the [Cancel] button on the master configuration dialog 
 * when the symbol coloring properties are modified and need to be recalculated. 
 * Since we cache the scheme being edited in the symbol coloring configuration 
 * object, there is nothing to do here unless the user changed which scheme was 
 * being used. 
 */
void _color_form_cancel()
{
   // nothing makes any permenant changes anymore, so just return
   return;
   /*

   dcc := getDefaultColorsConfig();
   if (dcc == null) return;

   // Reset the currently edited profile settings
   dcc->resetToOriginal();
   scm:=dcc->getCurrentProfile();
   scm->applyColorProfile();
   scm->applySymbolColorProfile();

   // Restore the color profile to the original if it changed since the last apply.
   origProfile := getOriginalColorProfileName();
   if (origProfile != ColorScheme.removeProfilePrefix(ctl_scheme.p_text) && 
       _plugin_has_profile(VSCFGPACKAGE_COLOR_PROFILES,origProfile)
       ) {
      dcc->loadProfile(origProfile);
      scm=dcc->getCurrentProfile();
      scm->applyColorProfile();
      scm->applySymbolColorProfile();
   }

   // Restore the minimap color profile to original
   origProfile = getOriginalMinimapProfileName();
   if (origProfile != "" && 
       origProfile != ColorScheme.removeProfilePrefix(ctl_minimap_scheme.p_text) && 
       _plugin_has_profile(VSCFGPACKAGE_COLOR_PROFILES,origProfile)) {
      dcc->loadProfile(origProfile);
      scm=dcc->getCurrentProfile();
      scm->applyMinimapColorProfile(origProfile);
   }
   */
}

/**
 * Initialize the symbol coloring configuration dialog for the 
 * master configuration dialog.  There is nothing to do here 
 * becuase it is all handled in the on_create(). 
 *  
 * @param scheme_name   symbol coloring scheme name 
 */
void _color_form_init_for_options(_str scheme_name_or_color = "")
{
   if (scheme_name_or_color != '') {
      if (isinteger(scheme_name_or_color)) {
         _ColorFormSelectColor((int)scheme_name_or_color);
      } 
   }
}

/**
 * Initialize the settings of the form so that we can figure out when it's been 
 * modified. 
 */
void _color_form_save_settings()
{
   // save the current scheme name
   ctl_editor_label.p_user = ColorScheme.removeProfilePrefix(ctl_editor_scheme.p_text);
   ctl_minimap_label.p_user = ColorScheme.removeProfilePrefix(ctl_minimap_scheme.p_text);
}

/**
 * Callback to check if the color settings have been modified since it was first
 * loaded into the dialog. 
 *  
 * @return 'true' if the coloring had been modified.
 */
bool _color_form_is_modified()
{
   // see if we are using the same scheme
   dcc := getDefaultColorsConfig();
   if (dcc == null) return false;
   scm:=dcc->getCurrentProfile();

   // see if the default editor profile has changed
   origEditorProfile := getOriginalColorProfileName();
   if (origEditorProfile != ColorScheme.removeProfilePrefix(ctl_editor_scheme.p_text)) {
      return true;
   }

   // see if the minimap profile has changed
   origMinimapProfile := getOriginalMinimapProfileName();
   if (origMinimapProfile != ColorScheme.removeProfilePrefix(ctl_minimap_scheme.p_text)) {
      return true;
   }

   // see if the current scheme is modified
   if (dcc->isModified()) {
       return true;
   }
   if (dcc->isModifiedBuiltinProfile() && !_plugin_has_user_profile(VSCFGPACKAGE_COLOR_PROFILES,scm->m_name)) {
       return true;
   }

   // nothing has changed
   return false;
}

/**
 * Callback to check if the default color profile settings have been 
 * modified since it was first loaded into the dialog. 
 *  
 * @return 'true' if the coloring had been modified.
 */
bool _default_color_profile_names_modified()
{
   // see if we are using the same scheme
   dcc := getDefaultColorsConfig();
   if (dcc == null) return false;
   scm:=dcc->getCurrentProfile();

   // see if the default editor profile has changed
   origEditorProfile := getOriginalColorProfileName();
   if (origEditorProfile != ColorScheme.removeProfilePrefix(ctl_editor_scheme.p_text)) {
      return true;
   }

   // see if the minimap profile has changed
   origMinimapProfile := getOriginalMinimapProfileName();
   if (origMinimapProfile != ColorScheme.removeProfilePrefix(ctl_minimap_scheme.p_text)) {
      return true;
   }

   // scheme names have not changed
   return false;
}

#if 0
/**
 * Callback to restore the symbol coloring options back to their 
 * original state for the given scheme name. 
 *  
 * @param scheme_name_or_color   symbol coloring scheme name to reset, or the 
 *                               color id corresponding to the color we wish to
 *                               select
 */
void _color_form_restore_state(_str scheme_name_or_color)
{
   if (isinteger(scheme_name_or_color)) {
      selectColor((int)scheme_name_or_color);
   } else {
   
      dcc := getDefaultColorsConfig();
      if (dcc == null) return;
   
      scm := dcc->getScheme(scheme_name_or_color);
      if (scm == null) return;
   
      dcc->setCurrentScheme(*scm);
      dcc->setModified(false);
      ctl_scheme.p_text = scm->m_name;
   }
}
#endif

/**
 * Enable or disable the symbol coloring form controls for editing 
 * the current color. 
 *  
 * @param onoff   'true' to enable, 'false' to disable 
 */
static void enableColorSettings(int cfg)
{
   switch (cfg) {
   case 0:
      ctl_color_note.p_enabled = false;
      ctl_system_default.p_enabled = false;
      ctl_system_default.p_visible = false;
      ctl_foreground_frame.p_visible = true;
      ctl_foreground_frame.p_enabled = false;
      ctl_foreground_color.p_enabled = false;
      ctl_foreground_color.p_backcolor = 0x808080;
      ctl_background_frame.p_visible = true;
      ctl_background_frame.p_enabled = false;
      ctl_background_inherit.p_visible = true;
      ctl_background_inherit.p_enabled = false;
      ctl_background_inherit.p_value = 0;
      ctl_background_color.p_enabled = false;
      ctl_background_color.p_backcolor = 0x808080;
      ctl_embedded_label.p_enabled = false;
      ctl_embedded_color.p_enabled = false;
      ctl_embedded_label.p_visible = true;
      ctl_embedded_color.p_visible = true;
      ctl_embedded_color.p_backcolor = 0x808080;
      ctl_font_frame.p_visible = true;
      ctl_font_frame.p_enabled = false;
      //ctl_normal.p_enabled = false;
      ctl_bold.p_enabled = false;
      ctl_underline.p_enabled = false;
      ctl_strikeout.p_enabled = false;
      ctl_italic.p_enabled = false;
      ctl_sample.p_visible = true;
      ctl_sample.p_enabled = false;
      ctl_sample.p_forecolor = 0x0;
      ctl_sample.p_backcolor = 0x808080;
      ctl_embedded_sample.p_visible = true;
      ctl_embedded_sample.p_enabled = false;
      ctl_embedded_sample.p_forecolor = 0x0;
      ctl_embedded_sample.p_backcolor = 0x808080;
      break;

   case CFG_CURRENT_LINE_BOX:
   case CFG_VERTICAL_COL_LINE:
   case CFG_MARGINS_COL_LINE:
   case CFG_TRUNCATION_COL_LINE:
   case CFG_PREFIX_AREA_LINE:
   case CFG_SELECTIVE_DISPLAY_LINE:
   case CFG_MODIFIED_ITEM:
   case CFG_NAVHINT:
   case CFG_DOCUMENT_TAB_MODIFIED:
   case CFG_MINIMAP_DIVIDER:
   case CFG_LIVE_ERRORS_ERROR:
   case CFG_LIVE_ERRORS_WARNING:
      ctl_color_note.p_enabled = true;
      ctl_system_default.p_enabled = false;
      ctl_system_default.p_visible = false;
      ctl_foreground_frame.p_visible = true;
      ctl_foreground_frame.p_enabled = true;
      ctl_foreground_color.p_enabled = true;
      ctl_background_frame.p_visible = false;
      ctl_background_frame.p_enabled = false;
      ctl_font_frame.p_enabled = false;
      ctl_font_frame.p_visible = false;
      ctl_sample.p_visible = false;
      ctl_embedded_sample.p_visible = false;
      break;

   case CFG_STATUS:
   case CFG_CMDLINE:
   case CFG_MESSAGE:
   case CFG_DOCUMENT_TAB_ACTIVE:
   case CFG_DOCUMENT_TAB_SELECTED:
   case CFG_DOCUMENT_TAB_UNSELECTED:
      ctl_color_note.p_enabled = true;
      ctl_system_default.p_enabled = true;
      ctl_system_default.p_visible = true;
      ctl_foreground_frame.p_visible = true;
      ctl_foreground_frame.p_enabled = true;
      ctl_foreground_color.p_enabled = true;
      ctl_background_frame.p_visible = true;
      ctl_background_frame.p_enabled = true;
      ctl_background_inherit.p_enabled = false;
      ctl_background_inherit.p_visible = false;
      ctl_background_color.p_enabled = true;
      ctl_embedded_label.p_enabled = false;
      ctl_embedded_color.p_enabled = false;
      ctl_embedded_label.p_visible = false;
      ctl_embedded_color.p_visible = false;
      ctl_font_frame.p_enabled = false;
      ctl_font_frame.p_visible = false;
      //ctl_normal.p_enabled = true;
      ctl_bold.p_enabled = true;
      ctl_underline.p_enabled = true;
      ctl_strikeout.p_enabled = true;
      ctl_italic.p_enabled = true;
      ctl_sample.p_visible = true;
      ctl_sample.p_enabled = true;
      ctl_embedded_sample.p_visible = false;
      ctl_embedded_sample.p_enabled = false;
      break;

   case CFG_SELECTED_CLINE:
   case CFG_SELECTION:
   case CFG_CLINE:
   case CFG_CURSOR:
      ctl_color_note.p_enabled = true;
      ctl_system_default.p_enabled = false;
      ctl_system_default.p_visible = false;
      ctl_foreground_frame.p_visible = true;
      ctl_foreground_frame.p_enabled = true;
      ctl_foreground_color.p_enabled = true;
      ctl_background_frame.p_visible = true;
      ctl_background_frame.p_enabled = true;
      ctl_background_inherit.p_visible = true;
      ctl_background_inherit.p_enabled = true;
      ctl_background_color.p_enabled = true;
      ctl_embedded_label.p_enabled = true;
      ctl_embedded_color.p_enabled = true;
      ctl_embedded_label.p_visible = true;
      ctl_embedded_color.p_visible = true;
      ctl_font_frame.p_enabled = false;
      ctl_font_frame.p_visible = true;
      //ctl_normal.p_enabled = false;
      ctl_bold.p_enabled = false;
      ctl_underline.p_enabled = false;
      ctl_strikeout.p_enabled = false;
      ctl_italic.p_enabled = false;
      ctl_bold.p_value = ctl_italic.p_value=ctl_underline.p_value=ctl_strikeout.p_value=0;
      ctl_sample.p_visible = true;
      ctl_sample.p_enabled = true;
      ctl_embedded_sample.p_visible = !(cfg == CFG_LINEPREFIXAREA);
      ctl_embedded_sample.p_enabled = !(cfg == CFG_LINEPREFIXAREA);
      break;

   default:
      ctl_color_note.p_enabled = true;
      ctl_system_default.p_enabled = false;
      ctl_system_default.p_visible = false;
      ctl_foreground_frame.p_visible = true;
      ctl_foreground_frame.p_enabled = true;
      ctl_foreground_color.p_enabled = true;
      ctl_background_frame.p_visible = true;
      ctl_background_frame.p_enabled = true;
      ctl_background_inherit.p_visible = true;
      ctl_background_inherit.p_enabled = (cfg != CFG_WINDOW_TEXT);
      ctl_background_color.p_enabled = true;
      ctl_embedded_label.p_enabled = !(cfg == CFG_LINEPREFIXAREA);
      ctl_embedded_color.p_enabled = !(cfg == CFG_LINEPREFIXAREA);
      ctl_embedded_label.p_visible = !(cfg == CFG_LINEPREFIXAREA);
      ctl_embedded_color.p_visible = !(cfg == CFG_LINEPREFIXAREA);
      ctl_font_frame.p_enabled = true;
      ctl_font_frame.p_visible = true;
      //ctl_normal.p_enabled = true;
      ctl_bold.p_enabled = true;
      ctl_underline.p_enabled = true;
      ctl_strikeout.p_enabled = true;
      ctl_italic.p_enabled = true;
      ctl_sample.p_visible = true;
      ctl_sample.p_enabled = true;
      ctl_embedded_sample.p_visible = !(cfg == CFG_LINEPREFIXAREA);
      ctl_embedded_sample.p_enabled = !(cfg == CFG_LINEPREFIXAREA);
      break;
   }
}

/**
 * Handle actions that occur in the color list, such as when the 
 * user selects a different node. 
 *  
 * @param reason     type of event 
 * @param index      current tree index
 */
void ctl_rules.on_change(int reason,int index)
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   if (dcc->ignoreChanges()) {
      return;
   }

   switch (reason) {
   case CHANGE_CLINE:
   case CHANGE_CLINE_NOTVIS:
   case CHANGE_SELECTED:
      loadColor(getColorId());
      break;
   }

}

/** 
 * Change the mode name for the sample code. 
 */
void ctl_mode_name.on_change(int reason)
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   if (dcc->ignoreChanges()) {
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
 * Prompt the user for a color scheme name, this is done both for saving the
 * current scheme and renaming the scheme. 
 *  
 * @param dcc              color configuration manager object
 * @param origProfileName   original scheme name (being renamed or saved) 
 * @param allowSameName    allow them to use the same name (to save a user scheme) 
 * 
 * @return '' if they cancelled, otherwise returns the new scheme name 
 */
static _str getColorProfileName(_str origProfileName)
{
   // prompt the user for a new scheme name
   loop {
      status := textBoxDialog("Enter Profile Name", 0, 0, 
                              "New Color Profile dialog", 
                              "", "", " Profile name:":+origProfileName);
      if (status < 0) {
         break;
      }
      newProfileName := _param1;
      if (newProfileName == "") {
         break;
      }

      // verify that the new name does not duplicate an existing name
      if (!_plugin_has_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,newProfileName)) {
         return newProfileName;
      }


      _message_box("There is already a profile named \""newProfileName".\"");
      continue;
   }

   // command cancelled due to error
   return "";
}

/**
 * Handle switching default color schemes.  If the current scheme is modified from it's 
 * saved settings, prompt the user before switching schemes. 
 *  
 * @param reason  event type
 */
void ctl_editor_scheme.on_change(int reason)
{
   if (reason == CHANGE_CLINE || reason == CHANGE_CLINE_NOTVIS) {
      dcc := getDefaultColorsConfig();
      if (!dcc || dcc->ignoreChanges) return;
      // update minimap default text
      editorProfileName := ctl_editor_scheme.p_text;
      realProfileName := ColorScheme.realProfileNameWithPrefix(editorProfileName);
      ctl_minimap_scheme.p_user = realProfileName;
      ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, realProfileName);
      if (ctl_minimap_scheme.p_text == "") {
         ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");
      }

      // if they change the default editor scheme, change which scheme is
      // being edited also.  This might trigger a prompt to save changes.
      ctl_scheme._cbset_text(realProfileName);
   }
}

/**
 * Handle switching schemes.  If the current scheme is modified from it's 
 * saved settings, prompt the user before switching schemes. 
 *  
 * @param reason  event type
 */
void ctl_scheme.on_change(int reason)
{
   if (reason == CHANGE_CLINE || reason == CHANGE_CLINE_NOTVIS) {

      dcc := getDefaultColorsConfig();
      if (dcc == null) return;
      if (dcc->ignoreChanges()) return;
      scm := getColorScheme();
      if (scm==null) return;
     
      // prompt about saving the former scheme
      if (dcc->profileChanged()) {
         buttons := "&Save Changes,&Discard Changes,Cancel:_cancel\t-html The current profile has been modified.  Would you like to save your changes?";
   
         status := textBoxDialog('SlickEdit Options',
                                 0,
                                 0,
                                 'Modified Color Profile',
                                 buttons);
         if (status == 1) {            // Save - the first button
            scm->saveProfile();
            dcc->setModified(false);
         } else if (status == 2) {     // Discard Changes - the second button
            //loadScheme(scm->m_name);
         } else {                      // Cancel our cancellation
            ctl_scheme._cbset_text(ColorScheme.addProfilePrefix(scm->m_name));
            return;
         }
      }

      // warn them if the selected scheme is not compatible with the
      // current color scheme
      profileName := ColorScheme.removeProfilePrefix(strip(ctl_scheme.p_text));
      cfg := getColorId();
      dcc->loadProfile(profileName);
      loadScheme();
      ctl_code_sample.updateSampleCode();
      _ColorFormSelectColor(cfg);
      //dcc->setModified();
      ctl_rules._TreeRefresh();

      updateButtons();
   }
}

void ctl_minimap_scheme.on_got_focus() 
{
   p_style = PSCBO_NOEDIT;
}
void ctl_minimap_scheme.on_lost_focus() 
{
   if (p_text == "") {
      p_style = PSCBO_EDIT;
   }
   if (p_user != null && p_user != "") {
      _ComboBoxSetPlaceHolderText(p_window_id, p_user);
   }
}
void ctl_minimap_scheme.DEL()
{
   _cbset_text("");
   p_style = PSCBO_EDIT;
}

void ctl_minimap_scheme.on_drop_down(int reason) 
{
   // this fix is only needed on Linux, crashes on macOS (Qt4)
   if (!_isLinux()) {
      return;
   }
   switch ( reason ) {
   case DROP_INIT:
      if (p_style != PSCBO_EDIT) {
         p_style = PSCBO_EDIT;
      }
      break;
   case DROP_UP:
      if (p_style != PSCBO_NOEDIT) {
         p_style = PSCBO_NOEDIT;
      }
      break;
   case DROP_DOWN:
      break;
   case DROP_UP_SELECTED:
      break;
   }
}

/**
 * Handle switching minimap schemes.  If the minimap is set to "Automatic", 
 * then use the same scheme used by the editor control. 
 *  
 * @param reason  event type
 */
void ctl_minimap_scheme.on_change(int reason)
{
   if (reason == CHANGE_CLINE || reason == CHANGE_CLINE_NOTVIS) {
      dcc := getDefaultColorsConfig();
      if (dcc != null && dcc->ignoreChanges()) return;

      // get the selected color scheme name
      colorProfileName   := ColorScheme.removeProfilePrefix(strip(ctl_scheme.p_text));
      editorProfileName  := ColorScheme.removeProfilePrefix(strip(ctl_editor_scheme.p_text));
      minimapProfileName := ColorScheme.removeProfilePrefix(strip(ctl_minimap_scheme.p_text));
      if (minimapProfileName == colorProfileName || 
          ColorScheme.realProfileName(minimapProfileName) == colorProfileName ||
          (minimapProfileName == "" && ColorScheme.realProfileName(editorProfileName) == colorProfileName)) {
         minimapProfileName = SAMPLE_COLOR_MODIFIED_SCHEME;
      }

      // get the minimap wid
      minimap_wid := ctl_code_sample.p_minimap_wid;
      if (minimap_wid && _iswindow_valid(minimap_wid)) {
         minimap_wid.p_redraw = false;
         minimap_wid.p_WindowColorProfile = minimapProfileName;
         minimap_wid.p_redraw = true;
      }
   }
}

/**
 * Select the given color.
 */
void _ColorFormSelectColor(int colorId)
{
   if (colorId == 0) return;
   index := ctl_rules._TreeSearch(TREE_ROOT_INDEX, "", "T", colorId);
   if (index > 0) {
      ctl_rules._TreeTop();
      ctl_rules._TreeSetCurIndex(index);
      ctl_rules._TreeScroll(ctl_rules._TreeCurLineNumber());
      ctl_rules._TreeRefresh();
   }
}

/**
 * Remotely modify a color in the color scheme.
 */
void _ColorFormSetForegroundColor(int colorId, int fgColor)
{
   if (colorId == 0) return;
   index := ctl_rules._TreeSearch(TREE_ROOT_INDEX, "", "T", colorId);
   if (index > 0) {
      ctl_rules._TreeTop();
      ctl_rules._TreeSetCurIndex(index);

      dcc := getDefaultColorsConfig();
      if (dcc==null) return;
      scm := getColorScheme();
      if (scm==null) return;
      colorInfo := getColorInfo();
      if (colorInfo == null) return;

      colorInfo->m_foreground = fgColor;
      ctl_foreground_color.p_backcolor = colorInfo->getForegroundColor(scm);
      ctl_background_color.p_backcolor = colorInfo->getBackgroundColor(scm);
      ctl_embedded_color.p_backcolor = scm->getEmbeddedBackgroundColor(colorId);
      ctl_sample.p_forecolor = ctl_foreground_color.p_backcolor;
      ctl_sample.p_backcolor = ctl_background_color.p_backcolor;
      ctl_embedded_sample.p_forecolor = ctl_foreground_color.p_backcolor;
      ctl_embedded_sample.p_backcolor = ctl_embedded_color.p_backcolor;

      // update the current color
      updateCurrentColor();

      // set modified again, to note that the current selection has changed
      dcc->setModified(true);
      updateButtons();

      // make the given color current
      ctl_rules._TreeScroll(ctl_rules._TreeCurLineNumber());
      ctl_rules._TreeRefresh();
   }
}

/**
 * Remotely modify a color in the color scheme.
 */
void _ColorFormSetBackgroundColor(int colorId, int bgColor)
{
   if (colorId == 0) return;
   index := ctl_rules._TreeSearch(TREE_ROOT_INDEX, "", "T", colorId);
   if (index > 0) {
      ctl_rules._TreeTop();
      ctl_rules._TreeSetCurIndex(index);

      dcc := getDefaultColorsConfig();
      if (dcc==null) return;
      scm := getColorScheme();
      if (scm==null) return;
      colorInfo := getColorInfo();
      if (colorInfo == null) return;

      colorInfo->m_background = bgColor;
      colorInfo->m_fontFlags &= ~F_INHERIT_BG_COLOR;
      ctl_foreground_color.p_backcolor = colorInfo->getForegroundColor(scm);
      ctl_background_color.p_backcolor = colorInfo->getBackgroundColor(scm);
      ctl_embedded_color.p_backcolor = scm->getEmbeddedBackgroundColor(colorId);
      ctl_background_inherit.p_value = 0;
      ctl_sample.p_forecolor = ctl_foreground_color.p_backcolor;
      ctl_sample.p_backcolor = ctl_background_color.p_backcolor;
      ctl_embedded_sample.p_forecolor = ctl_foreground_color.p_backcolor;
      ctl_embedded_sample.p_backcolor = ctl_embedded_color.p_backcolor;

      // update the current color
      updateCurrentColor();

      // set modified again, to note that the current selection has changed
      dcc->setModified(true);
      updateButtons();

      // make the given color current
      ctl_rules._TreeScroll(ctl_rules._TreeCurLineNumber());
      ctl_rules._TreeRefresh();
   }
}

/**
 * Reset the current scheme to the default.  Only has any effect on system 
 * schemes that have been modified. 
 */
void ctl_reset_scheme.lbutton_up()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := getColorScheme();
   if (scm == null) return;

   // make sure they know what they are doing.
   mbrc := _message_box(nls("Reset all changes to '%s?'", scm->m_name), "Confirm resetting changes", MB_YESNO);
   if (mbrc != IDYES) {
      return;
   }

   // make sure this scheme can be reset - it must be a system scheme that has 
   // been modified
   name := scm->m_name;
   if (dcc->isModifiedBuiltinProfile()) {
      dcc->loadProfile(scm->m_name,1/* Load the built-in profile */);
      cfg := getColorId();
      loadScheme();
      ctl_code_sample.updateSampleCode();
      _ColorFormSelectColor(cfg);
      ctl_rules._TreeRefresh();
      ctl_reset_scheme.p_enabled = false;
      dcc->setModified();
   }  
}
static void updateButtons()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := dcc->getCurrentProfile();

   is_builtin_profile := DefaultColorsConfig.hasBuiltinProfile(scm->m_name);
   ctl_delete_scheme.p_enabled = !is_builtin_profile;
   ctl_rename_scheme.p_enabled = !is_builtin_profile;
   ctl_reset_selected_color.p_enabled = dcc->isModified() || dcc->isModifiedBuiltinProfile();
   ctl_reset_scheme.p_enabled = dcc->isModifiedBuiltinProfile();
   ctl_reset_colors.p_enabled = _default_color_profile_names_modified();
}

/**
 * Delete the current scheme.  Do not allow them to delete system schemes.
 */
void ctl_delete_scheme.lbutton_up()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := getColorScheme();
   if (scm==null) return;

   if (DefaultColorsConfig.hasBuiltinProfile(scm->m_name)) {
      //_message_box(get_message(VSRC_CFG_CANNOT_REMOVE_SYSTEM_SCHEMES));
      return;
   }
   mbrc := _message_box("Are you sure you want to delete the profile '"scm->m_name"'?  This action can not be undone.", "Confirm Profile Delete", MB_YESNO | MB_ICONEXCLAMATION);
   if (mbrc!=IDYES) {
      return;
   }
   _plugin_delete_profile(VSCFGPACKAGE_COLOR_PROFILES,scm->m_name);

   // disable all on_change callbacks
   origIgnore := dcc->ignoreChanges();
   dcc->setIgnoreChanges(true);
   dcc->setModified(true);

   deletedProfileName := ColorScheme.removeProfilePrefix(ctl_scheme._lbget_text());
   ctl_scheme._lbdelete_item();
   ctl_scheme._lbdown();
   currentProfileName:=ColorScheme.removeProfilePrefix(ctl_scheme._lbget_text());
   ctl_scheme.p_text = ColorScheme.addProfilePrefix(currentProfileName);
   cfg := getColorId();

   // update the list of items for the default editor color profile
   editorProfileName := ColorScheme.removeProfilePrefix(ctl_editor_scheme._lbget_text());
   ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(deletedProfileName));
   ctl_editor_scheme._cbset_text(deletedProfileName);
   ctl_editor_scheme._lbdelete_item();
   if (editorProfileName == deletedProfileName) {
      ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(currentProfileName));
   } else {
      ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(editorProfileName));
   }

   // update the list of items for the minimap also
   minimapProfileName := ColorScheme.removeProfilePrefix(ctl_minimap_scheme._lbget_text());
   ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(deletedProfileName));
   ctl_minimap_scheme._cbset_text(deletedProfileName);
   ctl_minimap_scheme._lbdelete_item();
   if (minimapProfileName != "") {
      if (minimapProfileName == deletedProfileName) {
         ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(currentProfileName));
      } else {
         ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(minimapProfileName));
      }
   }

   dcc->setIgnoreChanges(origIgnore);

   dcc->loadProfile(currentProfileName);
   loadScheme();
   ctl_code_sample.updateSampleCode();
   _ColorFormSelectColor(cfg);
   ctl_rules._TreeRefresh();

   // update minimap default text
   realProfileName := ColorScheme.realProfileNameWithPrefix(editorProfileName);
   ctl_minimap_scheme.p_user = realProfileName;
   ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, realProfileName);
   if (ctl_minimap_scheme.p_text == "") {
      ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");
   }


   ctl_minimap_scheme.p_user = ctl_editor_scheme.p_text;
   ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, ctl_editor_scheme.p_text);
   if (ctl_minimap_scheme.p_text == "") {
      ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");
   }

   updateButtons();
   // set modified again, to note that the current selection has changed
   dcc->setModified(true);

}

/**
 * Save the current scheme under a new name as a user-defined scheme.
 */
void ctl_save_scheme_as.lbutton_up()
{
   if (save_changes_first()) {
      return;
   }
   copyCurrentProfile();
   updateButtons();
}

static void copyCurrentProfile()
{
   // get the configuration object
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := getColorScheme();
   if (scm == null) return;

   // prompt the user for a new scheme name
   origProfileName := scm->m_name;
   newProfileName := getColorProfileName(origProfileName);
   if (newProfileName == "") return;

   if (DefaultColorsConfig.hasBuiltinProfile(origProfileName)) {
      scm->m_inheritsProfile = origProfileName;
   }

   scm->m_name = newProfileName;
   scm->saveProfile();
   if (newProfileName != origProfileName) {
      ctl_scheme._lbbottom();
      ctl_scheme._lbadd_item(ColorScheme.addProfilePrefix(newProfileName),60,_pic_lbuser);
      ctl_scheme._lbsort('i');
      dcc->setIgnoreChanges(true);
      ctl_scheme.p_text = ColorScheme.addProfilePrefix(newProfileName);
      dcc->setIgnoreChanges(false);
      loadScheme();

      // update the list of items for the default editor color profile
      editorProfileName := ColorScheme.removeProfilePrefix(ctl_editor_scheme._lbget_text());
      ctl_editor_scheme._lbbottom();
      ctl_editor_scheme._lbadd_item(ColorScheme.addProfilePrefix(newProfileName),60,_pic_lbuser);
      ctl_editor_scheme._lbsort('i');
      if (editorProfileName == origProfileName) {
         ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(newProfileName));
      } else {
         ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(editorProfileName));
      }

      // update the list of items for the minimap also
      minimapProfileName := ColorScheme.removeProfilePrefix(ctl_minimap_scheme._lbget_text());
      ctl_minimap_scheme._lbbottom();
      ctl_minimap_scheme._lbadd_item(ColorScheme.addProfilePrefix(newProfileName),60,_pic_lbuser);
      ctl_minimap_scheme._lbsort('i');
      if (minimapProfileName != "") {
         if (minimapProfileName == origProfileName) {
            ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(newProfileName));
         } else {
            ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(minimapProfileName));
         }
      }

      // update minimap default text
      ctl_minimap_scheme.p_user = ctl_editor_scheme.p_text;
      ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, ctl_editor_scheme.p_text);
      if (ctl_minimap_scheme.p_text == "") {
         ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");
      }
   }

   dcc->setModified(false);
}

static bool save_changes_first() {
   dcc := getDefaultColorsConfig();
   if (dcc == null) return false;
   
   if (dcc->profileChanged()) {
      buttons := "&Save Changes,&Discard Changes,Cancel:_cancel\t-html The current profile has been modified.  Would you like to save your changes?";

      status := textBoxDialog('SlickEdit Options',
                              0,
                              0,
                              'Modified Color Profile',
                              buttons);
      if (status == 1) {            // Save - the first button
         scm := dcc->getCurrentProfile();
         scm->saveProfile();
         dcc->setModified(false);
      } else if (status == 2) {     // Discard Changes - the second button
         //loadScheme(rb->m_name);
      } else {                      // Cancel our cancellation
         return true;
      }
   }
   return false;
}

/**
 * Rename the current scheme.  Do not allow them to rename system 
 * default schemes. 
 */
void ctl_rename_scheme.lbutton_up()
{
   // get the configuration object
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := dcc->getCurrentProfile();

   // only allow them to rename user schemes
   origProfileName := scm->m_name;
   if (DefaultColorsConfig.hasBuiltinProfile(scm->m_name)) {
      // This button is supposed to be disabled.
      //_message_box(get_message(VSRC_CFG_CANNOT_FIND_USER_SCHEME, origProfileName));
      return;
   }
   if (save_changes_first()) {
      return;
   }

   // prompt the user for a new scheme name
   newProfileName  := getColorProfileName(origProfileName);
   if (newProfileName == "") return;

   scm->m_name = newProfileName; 
   scm->saveProfile();
   _plugin_delete_profile(VSCFGPACKAGE_COLOR_PROFILES,origProfileName);
   ctl_scheme._lbset_item(ColorScheme.addProfilePrefix(newProfileName));
   ctl_scheme._lbsort('i');
   origIgnore := dcc->ignoreChanges();
   dcc->setIgnoreChanges(true);
   ctl_scheme.p_text = ColorScheme.addProfilePrefix(newProfileName);

   // update the list of items for the default editor color profile
   editorProfileName := ColorScheme.removeProfilePrefix(ctl_editor_scheme._lbget_text());
   ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(origProfileName));
   ctl_editor_scheme._lbset_item(ColorScheme.addProfilePrefix(newProfileName));
   ctl_editor_scheme._lbsort('i');
   if (editorProfileName == origProfileName) {
      ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(newProfileName));
   } else {
      ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(editorProfileName));
   }

   // update the list of items for the minimap also
   minimapProfileName := ColorScheme.removeProfilePrefix(ctl_minimap_scheme._lbget_text());
   ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(origProfileName));
   ctl_minimap_scheme._lbset_item(ColorScheme.addProfilePrefix(newProfileName));
   ctl_minimap_scheme._lbsort('i');
   if (minimapProfileName != "") {
      if (minimapProfileName == origProfileName) {
         ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(newProfileName));
      } else {
         ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(minimapProfileName));
      }
   }

   // update minimap default text
   ctl_minimap_scheme.p_user = ctl_editor_scheme.p_text;
   ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, ctl_editor_scheme.p_text);
   if (ctl_minimap_scheme.p_text == "") {
      ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");
   }
   
   dcc->setIgnoreChanges(origIgnore);

   // set modified again, to note that the current selection has changed
   dcc->setModified(true);
   updateButtons();
}

/**
 * Reset the color scheme back to what it was before we started.
 */
void ctl_reset_colors.lbutton_up()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := getColorScheme();
   if (scm == null) return;

   // determine the default color profiles
   defaultEditorColorProfile := _GetColorProfileForOS();
   default_pair := CONFIG_AUTOMATIC'='defaultEditorColorProfile;
   defaultEditorColorProfile = CONFIG_AUTOMATIC;

   // get the original color profile names
   editorProfileName  := getOriginalColorProfileName();
   minimapProfileName := getOriginalMinimapProfileName();
   pair := editorProfileName;
   if (minimapProfileName != "") {
      pair :+= ", " :+ minimapProfileName;
   }
   result := checkBoxDialog('Reset default color profiles',
                            nls("Reset default color profile back to original values (%s)?", pair),
                            nls("Reset to SlickEdit default (%s)", default_pair), MB_YESNO, 0);
   if (result != IDYES) {
      return;
   }

   // did the want to reset back to the SlickEdit default color schemes
   resetToDefaults := _param1;
   if (resetToDefaults) {
      editorProfileName = defaultEditorColorProfile;
      minimapProfileName = "";
   }

   // reset profile to original
   dcc->resetToOriginal();
   dcc->setModified(false);

   // update editor scheme name
   if (ctl_editor_scheme.p_text != editorProfileName) {
      realProfileName := ColorScheme.realProfileName(editorProfileName);
      dcc->loadProfile(realProfileName, dcc->isModifiedBuiltinProfile()? 1:0);
      ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(editorProfileName));
      if (ctl_scheme.p_text != ctl_editor_scheme.p_text) {
         ctl_scheme._cbset_text(ColorScheme.addProfilePrefix(realProfileName));
      }
   }

   // update minimap default profile
   if (ctl_minimap_scheme.p_text != minimapProfileName) {
      ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(minimapProfileName));
   }
   ctl_minimap_scheme.p_user = ctl_editor_scheme.p_text;
   ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, ctl_editor_scheme.p_text);
   if (ctl_minimap_scheme.p_text == "") {
      ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");
   }

   // reset the color scheme
   cfg := getColorId();
   loadScheme();
   loadColor(getColorId());
   _ColorFormSelectColor(cfg);
   dcc->setModified(false);
}

/**
 * Reset the color scheme back to what it was before we started.
 */
void ctl_reset_selected_color.lbutton_up()
{
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := getColorScheme();
   if (scm == null) return;

   // extract this single color and update controls
   cfg := getColorId();
   pColorInfo := scm->getColor(cfg);
   if ( pColorInfo == null ) return;
   origColorInfo := *pColorInfo;
   dcc->resetColorToOriginal(cfg);

   // maybe the reset did not really reset anything?
   if (dcc->isModifiedBuiltinProfile()) {
      resetColorInfo := scm->getColor(cfg);
      if (resetColorInfo != null && origColorInfo == *resetColorInfo) {
         ColorScheme orig_scm;
         orig_scm.loadProfile(scm->m_name, 1/* Load the built-in profile */);
         resetColorInfo = orig_scm.getColor(cfg);
         if (resetColorInfo != null && origColorInfo != *resetColorInfo) {
            mbrc := _message_box(nls("Reset color back to SlickEdit defaults for '%s?'", ColorScheme.getColorName(cfg)), "Confirm resetting color", MB_YESNO);
            if (mbrc != IDYES) {
               return;
            }
            scm->setColor(cfg, *resetColorInfo);
         }
      }
   }  
   
   loadColor(cfg);
   updateCurrentColor();
   dcc->setModified(true);

   // set modified again, to note that the current selection has changed
   updateButtons();
}

/**
 * Display the Symbol Coloring dialog.
 */
void ctl_symbol_coloring.lbutton_up()
{
   config("Symbol Coloring");
}

/**
 * Turn on/off use of the system default coloring.
 */
static void _system_default_color_state(bool useSystemDefault)
{
   ctl_foreground_frame.p_enabled = !useSystemDefault;
   ctl_foreground_color.p_enabled = !useSystemDefault;
   ctl_background_frame.p_enabled = !useSystemDefault;
   ctl_background_inherit.p_enabled = !useSystemDefault;
   ctl_background_color.p_enabled = !useSystemDefault;
   ctl_embedded_label.p_enabled = !useSystemDefault;
   ctl_embedded_color.p_enabled = !useSystemDefault;
   
   color := getColorInfo();
   if (color == null) return;
   if (useSystemDefault) {
      color->m_foreground = VSDEFAULT_FOREGROUND_COLOR;
      color->m_background = VSDEFAULT_BACKGROUND_COLOR;
      color->m_fontFlags = 0;
   } else {
      color->m_foreground = 0x0;
      color->m_background = 0xFFFFFF;
      color->m_fontFlags = 0;
   }

   ctl_foreground_color.p_backcolor = color->getForegroundColor();
   ctl_background_color.p_backcolor = color->getBackgroundColor();
   ctl_embedded_color.p_backcolor = color->getBackgroundColor();
   ctl_sample.p_forecolor = ctl_foreground_color.p_backcolor;
   ctl_sample.p_backcolor = ctl_background_color.p_backcolor;
   ctl_embedded_sample.p_forecolor = ctl_foreground_color.p_backcolor;
   ctl_embedded_sample.p_backcolor = ctl_embedded_color.p_backcolor;
   updateCurrentColor();
}

void ctl_system_default.lbutton_up()
{
   if (!p_enabled) return;
   _system_default_color_state((p_value != 0));
}

/**
 * Handle changes in font settings.  This event handler is also used by
 * by the Inherit Font, Bold, Italic, and Underline radio buttons
 */
void ctl_bold.lbutton_up()
{
   // get our current scheme and color info
   scm := getColorScheme();
   color := getColorInfo();
   if (color == null) return;

   // figure out which font attribute changed
   font_flag := 0;
#if 0
   // Don't support bold with italic with underline for now
   if (ctl_bold.p_value && ctl_italic.p_value && ctl_underline.p_value) {
      switch (p_name) {
      case "ctl_bold":  
         ctl_bold.p_value=0;
         break;
      case "ctl_italic": 
         ctl_underline.p_value=0;
         break;
      case "ctl_underline":
         ctl_italic.p_value=0;
         break;
      case "ctl_strikeout":
         ctl_strikeout.p_value=0;
         break;
      }
   }
#endif

   // first, cut out all the flags
   color->m_fontFlags &= ~(F_BOLD|F_ITALIC|F_UNDERLINE|F_STRIKE_THRU);

   // now add back in the one we selected
   if (ctl_bold.p_value) {
      color->m_fontFlags |= F_BOLD;
   } 
   if (ctl_italic.p_value) {
      color->m_fontFlags |= F_ITALIC;
   }
   if (ctl_underline.p_value) {
      color->m_fontFlags |= F_UNDERLINE;
   }
   if (ctl_strikeout.p_value) {
      color->m_fontFlags |= F_STRIKE_THRU;
   }

   embeddedColor := getEmbeddedColorInfo();
   if (embeddedColor != null) {
      embeddedColor->m_fontFlags = color->m_fontFlags;
   }

   ctl_sample.p_font_strike_thru = (ctl_strikeout.p_value != 0);
   ctl_sample.p_font_underline = (ctl_underline.p_value != 0);
   ctl_sample.p_font_italic = (ctl_italic.p_value != 0);
   ctl_sample.p_font_bold = (ctl_bold.p_value != 0);
   ctl_embedded_sample.p_font_bold      = ctl_sample.p_font_bold;            
   ctl_embedded_sample.p_font_italic    = ctl_sample.p_font_italic;    
   ctl_embedded_sample.p_font_underline = ctl_sample.p_font_underline;
   ctl_embedded_sample.p_font_strike_thru = ctl_sample.p_font_strike_thru;
   updateCurrentColor();
   dcc := getDefaultColorsConfig();
   if (dcc==null) return;
   // set modified again, to note that the current selection has changed
   dcc->setModified(true);
   updateButtons();
}

/**
 * Handle changes in foreground or background color inheritance.
 */
void ctl_background_inherit.lbutton_up()
{
   ctl_foreground_color.enableColorControl();
   ctl_background_color.enableColorControl();
   ctl_embedded_color.enableColorControl();

   color := getColorInfo();
   if (color == null) return;

   if (p_name == "ctl_background_inherit") {
      if (p_value) {
         color->m_fontFlags |= F_INHERIT_BG_COLOR;
      } else {
         color->m_fontFlags &= ~F_INHERIT_BG_COLOR;
      }
      embeddedColor := getEmbeddedColorInfo();
      if (embeddedColor != null) {
         if (p_value) {
            embeddedColor->m_fontFlags |= F_INHERIT_BG_COLOR;
         } else {
            embeddedColor->m_fontFlags &= ~F_INHERIT_BG_COLOR;
         }
      }
   } else {
      if (p_value) {
         color->m_fontFlags |= F_INHERIT_FG_COLOR;
      } else {
         color->m_fontFlags &= ~F_INHERIT_FG_COLOR;
      }
   }

   scm := getColorScheme();
   cfg := getColorId();
   ctl_foreground_color.p_backcolor = color->getForegroundColor(scm);
   ctl_background_color.p_backcolor = color->getBackgroundColor(scm);
   ctl_embedded_color.p_backcolor = scm->getEmbeddedBackgroundColor(cfg);
   ctl_sample.p_forecolor = ctl_foreground_color.p_backcolor;
   ctl_sample.p_backcolor = ctl_background_color.p_backcolor;
   ctl_embedded_sample.p_forecolor = ctl_foreground_color.p_backcolor;
   ctl_embedded_sample.p_backcolor = ctl_embedded_color.p_backcolor;

   updateCurrentColor();
   dcc := getDefaultColorsConfig();
   if (dcc==null) return;
   // set modified again, to note that the current selection has changed
   dcc->setModified(true);
   updateButtons();
}

// Called to update the contents of a color profile combo box
// when a profile has changed between light and dark, to update
// the name.
static void update_profile_cb_prefix(_str profileName, int cbctl, bool wasDark)
{
   if (profileName == '') return;
   basename := ColorScheme.removeProfilePrefix(profileName);
   srch := basename;
   new_nm := '';
   if (wasDark) {
      srch ='Dark: 'basename;
      new_nm ='Light: 'basename;
   } else {
      srch ='Light: 'basename;
      new_nm ='Dark: 'basename;
   }

   selected := cbctl.p_text;
   selected_base := ColorScheme.removeProfilePrefix(selected);
   lbi := cbctl._lbfind_item(srch);
   if (lbi >= 0) {
      // I can't seem to get the pic_index from a combo box with lbget_item, 
      // so figure it out explicitly here.
      pic := _pic_lbuser;
      if (DefaultColorsConfig.hasBuiltinProfile(basename)) {
         pic = _pic_lbvs;
      }
      cbctl.p_line = lbi+1;
      cbctl._lbdelete_item();
      cbctl._cbset_text(new_nm, pic);

      // If the combo box had a different item selected when we went in, restore
      // it.
      if (selected_base != basename) {
         cbctl._cbset_text(selected);
      }
   }
}

/**
 * Handle changes in the foreground or background color setting. 
 */
void ctl_foreground_color.lbutton_up()
{
   inherit_checkbox := p_prev;
   while (inherit_checkbox != p_window_id) {
      if (inherit_checkbox.p_object == OI_CHECK_BOX) {
         if (inherit_checkbox.p_value != 0) return;
      }
      inherit_checkbox = inherit_checkbox.p_prev;
   }

   scm := getColorScheme();
   wasDark := scm->isDarkColorProfileLoaded();
   // make sure this is a proper color
   origColor := p_backcolor;
   if ((int)origColor < 0 || (origColor & 0x80000000) ||
       (int)origColor == VSDEFAULT_FOREGROUND_COLOR || 
       (int)origColor == VSDEFAULT_BACKGROUND_COLOR) {
      origColor = 0x0;
   }
   color := show_color_picker(origColor);
   if (color == COMMAND_CANCELLED_RC) return;
   if (color == origColor) return;

   p_backcolor = color;

   colorInfo := getColorInfo();
   if (colorInfo == null) return;

   if (p_window_id == ctl_foreground_color) {
      colorInfo->m_foreground = color;
      if (!ctl_background_frame.p_visible) {
         colorInfo->m_background = color;
      }
   } else if (p_window_id == ctl_background_color) {
      colorInfo->m_background = color;
   } else if (p_window_id == ctl_embedded_color) {
      embeddedInfo := getEmbeddedColorInfo();
      if (embeddedInfo != null) {
         embeddedInfo->m_background = color;
      }
   }

   cfg := getColorId();
   ctl_foreground_color.p_backcolor = colorInfo->getForegroundColor(scm);
   ctl_background_color.p_backcolor = colorInfo->getBackgroundColor(scm);
   ctl_embedded_color.p_backcolor = scm->getEmbeddedBackgroundColor(cfg);
   ctl_sample.p_forecolor = ctl_foreground_color.p_backcolor;
   ctl_sample.p_backcolor = ctl_background_color.p_backcolor;
   ctl_embedded_sample.p_forecolor = ctl_foreground_color.p_backcolor;
   ctl_embedded_sample.p_backcolor = ctl_embedded_color.p_backcolor;

   // if they change the background or embedded color, we need to refresh entire tree
   if (p_window_id == ctl_background_color || p_window_id == ctl_embedded_color) {
      index := ctl_rules._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
      while (index > 0) {
         color_index := ctl_rules._TreeGetFirstChildIndex(index);
         while (color_index > 0) {
            colorId := ctl_rules._TreeGetUserInfo(color_index);
            ctl_rules.loadTreeNodeColor(color_index, scm, colorId);
            color_index = ctl_rules._TreeGetNextSiblingIndex(color_index);
         }
         index = ctl_rules._TreeGetNextSiblingIndex(index);
      }
   }

   // update the current color
   updateCurrentColor();
   dcc := getDefaultColorsConfig();
   if (dcc==null) return;
   // set modified again, to note that the current selection has changed
   dcc->setModified(true);
   updateButtons();

   if (wasDark != scm->isDarkColorProfileLoaded()) {
      // The user changed the color enough to change the profile Light/Dark
      // prefix.  Update the display so the prefix is correctly displayed.
      // We ignore changes while doing this, the the on_change code won't 
      // interpret this as a user switching to another profile, which can prompt
      // to save, etc...
      minimapFollowsEditor := ctl_minimap_scheme.p_text == "";
      orig_ignore := dcc->ignoreChanges();
      dcc->setIgnoreChanges(true);
      update_profile_cb_prefix(scm->getProfileName(), ctl_editor_scheme, wasDark);
      update_profile_cb_prefix(scm->getProfileName(), ctl_minimap_scheme, wasDark);
      update_profile_cb_prefix(scm->getProfileName(), ctl_scheme, wasDark);
      dcc->setIgnoreChanges(orig_ignore);

      // We disturbed the minimap setting by deleting and adding the new name, 
      // so fix it.
      if (minimapFollowsEditor) {
         ctl_minimap_scheme._cbset_text("");
         ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, ctl_editor_scheme.p_text);
      }
   }
}

void ctl_symbol_scheme.on_change(int reason)
{
   if (reason != CHANGE_OTHER) {
      scm := getColorScheme();
      if (scm==null) return;
      if (scm->m_symbolColoringProfile != p_text) {
         dcc := getDefaultColorsConfig();
         if (dcc==null) return;
         if (dcc->ignoreChanges()) return;
         dcc->setModified(true);
         scm->m_symbolColoringProfile = p_text;
      }
   }
}

/**
 * Look up the language specific code sample from the code sample database. 
 * 
 * @param configFile    name of code samples XML config file 
 * @param modeName      language mode name to find sample for
 * 
 * @return contents of code sample (PCDATA) 
 */
static _str getSampleCode( _str modeName)
{
   langid:=_Modename2LangId(modeName);
   if (langid=='') {
      return null;
   }
   int handle=_plugin_get_property_xml(VSCFGPACKAGE_MISC,VSCFGPROFILE_COLOR_CODING_SAMPLES,langid);
   if (handle<0) {
      return null;
   }
   text:=_xmlcfg_get_text(handle,_xmlcfg_get_document_element(handle));
   _xmlcfg_close(handle);
   if (text=='') {
      return null;
   }
   return text;
}

/**
 * Generate sample code for the selected mode name 
 * and insert it into the sample code editor control. 
 */
void _GenerateSampleColorCode() 
{
   _lbclear();
   top(); 
   _begin_line();

   text := getSampleCode(p_mode_name);
   if (text != null) {
      text = strip(text, "L", " \t");
      while (_first_char(text) == "\n" || _first_char(text) == "\r") {
         text = substr(text, 2);
      }
      _insert_text(text);
   } else {
      // disable dynamic surround temporarily
      orig_ds := _lang_dynamic_surround_on(p_LangId);
      _lang_dynamic_surround_on(p_LangId, 0);

      insert_line("This code is generated.");
      _lineflags(NOSAVE_LF);
      if ( !getCommentSettings(p_LangId,auto commentSettings,"B") ) {
         insert_line(" This is a block comment.");
         select_line();
         box();
         _deselect();
         bottom();
         _end_line();
      }
      insert_line("if");
      call_event(p_window_id, " ");
      keyin(" cond == true ");
      _end_line();
      nosplit_insert_line();
      keyin("y = 123456789;");
      indent_line();

      bottom();
      if ( !getCommentSettings(p_LangId,commentSettings,"L") ) {
         insert_line(" This is a line comment.");
         comment();
      }
      insert_line("if");
      call_event(p_window_id, " ");
      keyin(" cond == false ");
      _end_line();
      nosplit_insert_line();
      keyin("x = \"This is a string\";");
      indent_line();

      // restore dynamic surround
      _lang_dynamic_surround_on(p_LangId, orig_ds);
   }
   top(); up(); _begin_line();
   // reset line flags
   while (!down()) {
      _lineflags(0,MODIFY_LF|INSERTED_LINE_LF);
   }
   top(); up(); _begin_line();
   // add Inserted Line, Modified Line to sample
   if (!down()) {
      if (!down()) _lineflags(INSERTED_LINE_LF,INSERTED_LINE_LF);
      if (!down()) _lineflags(MODIFY_LF,MODIFY_LF);
   }
   top(); _begin_line();
}

_str _color_form_export_settings(_str &path, _str &currentScheme)
{
   error := '';
   _plugin_export_profiles(path,VSCFGPACKAGE_COLOR_PROFILES);
   // save our current scheme
   currentScheme = def_color_scheme;
   return error;
}

_str _color_form_import_settings(_str file, _str currentScheme)
{
   error := '';

   if (file!='') {
      if (endsWith(file,VSCFGFILEEXT_CFGXML,false,_fpos_case)) {
         error=_plugin_import_profiles(file,VSCFGPACKAGE_COLOR_PROFILES,2);
      } else {
         _convert_uscheme_ini(file);
      }
   }
   if (_plugin_has_profile(VSCFGPACKAGE_COLOR_PROFILES,currentScheme)) {
      se.color.ColorScheme rb;
      
      def_color_scheme = currentScheme;
      _config_modify_flags(CFGMODIFY_DEFVAR);
      rb.loadProfile(def_color_scheme);
      rb.applyColorProfile(currentScheme);
   }
   return error;

}

/**
 * Import an Xcode or Visual Studio color theme. 
 */
void ctl_import_scheme.lbutton_up()
{
   if (save_changes_first()) {
      return;
   }

   // get the configuration object
   dcc := getDefaultColorsConfig();
   if (dcc == null) return;
   scm := getColorScheme();
   if (scm == null) return;
   origProfileName := scm->m_name;

   // show the import form and let it import and save the new color profile
   orig_wid := p_window_id;
   newProfileName := show("-modal _import_color_profile_form");
   if ( newProfileName == "" ) {
      return;
   }
   p_window_id = orig_wid;

   // update the color scheme we are currently editing to the new profile
   ctl_scheme._lbbottom();
   ctl_scheme._lbadd_item(ColorScheme.addProfilePrefix(newProfileName),60,_pic_lbuser);
   ctl_scheme._lbsort('i');
   dcc->setIgnoreChanges(true);
   ctl_scheme.p_text = ColorScheme.addProfilePrefix(newProfileName);
   dcc->setIgnoreChanges(false);

   // load the new profile as the active color profile
   dcc->loadProfile(newProfileName);
   loadScheme();

   // update the list of items for the default editor color profile
   editorProfileName := ColorScheme.removeProfilePrefix(ctl_editor_scheme._lbget_text());
   ctl_editor_scheme._lbbottom();
   ctl_editor_scheme._lbadd_item(ColorScheme.addProfilePrefix(newProfileName),60,_pic_lbuser);
   ctl_editor_scheme._lbsort('i');
   if (editorProfileName != "") {
      ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(editorProfileName));
   }

   // update the list of items for the minimap also
   minimapProfileName := ColorScheme.removeProfilePrefix(ctl_minimap_scheme._lbget_text());
   ctl_minimap_scheme._lbbottom();
   ctl_minimap_scheme._lbadd_item(ColorScheme.addProfilePrefix(newProfileName),60,_pic_lbuser);
   ctl_minimap_scheme._lbsort('i');
   if (minimapProfileName != "") {
      ctl_minimap_scheme._cbset_text(ColorScheme.addProfilePrefix(minimapProfileName));
   }

   // update minimap default text
   ctl_minimap_scheme.p_user = ctl_editor_scheme.p_text;
   ctl_minimap_scheme._ComboBoxSetPlaceHolderText(ctl_minimap_scheme.p_window_id, ctl_editor_scheme.p_text);
   if (ctl_minimap_scheme.p_text == "") {
      ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");
   }

   // force the selected color schemes to be updated
   ctl_scheme.call_event(CHANGE_CLINE,ctl_scheme,ON_CHANGE,"");
   ctl_minimap_scheme.call_event(CHANGE_CLINE,ctl_minimap_scheme,ON_CHANGE,"");

   dcc->setModified(false);
   updateButtons();

   // ask if they want to make this their new default profile.
   if (newProfileName != editorProfileName) {
      mbrc :=  _message_box(nls("Do you want to make '%s' your default editor color profile?", newProfileName), "SlickEdit", MB_YESNO|MB_ICONQUESTION);
      if (mbrc == IDYES) {
         ctl_editor_scheme._cbset_text(ColorScheme.addProfilePrefix(newProfileName));
      }
   }
}

