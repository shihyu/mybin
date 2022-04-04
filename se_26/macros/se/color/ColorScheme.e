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
#require "sc/lang/IEquals.e"
#require "se/color/ColorInfo.e"
#require "se/color/IColorCollection.e"
#import "se/color/SymbolColorConfig.e"
#import "se/color/SymbolColorAnalyzer.e"
#import "se/ui/NavMarker.e"
#import "cfg.e"
#import "dlgman.e"
#import "files.e"
#import "ini.e"
#import "main.e"
#import "math.e"
#import "recmacro.e"
#import "rte.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "wcolor.e"
#endregion

// These are for converting old color schemes
// to profiles. 
// DONT USE THE FOR NEW CODE.
// Every profile already has a version attribute
// which replaces custom versioning like this stuff.
// Write a profile updater in C code to take care
// of versioning in the future.
//        
enum ColorSchemeVersion {
   // default, virgin SlickEdit configuration
   COLOR_SCHEME_VERSION_DEFAULT = 0,

   // any migrated color scheme from user's vusrdefs.e (probably incomplete) 
   COLOR_SCHEME_VERSION_PREHISTORIC,

   // Epoch colors added from previous releases 
   COLOR_SCHEME_VERSION_SPECIAL_CHARS = 10,     // colors added in 10.0
   COLOR_SCHEME_VERSION_BLOCK_MATCHING = 11,    // colors added in 12.0
   COLOR_SCHEME_VERSION_FILE_TABS = 13,         // added in 13.0.2
   COLOR_SCHEME_VERSION_EMBEDDED_CHANGES = 14,  // added in 14.0.0
   COLOR_SCHEME_VERSION_COMMENT_COLORS,
   COLOR_SCHEME_VERSION_INACTIVE_COLORS,
   COLOR_SCHEME_VERSION_INHERIT_COLORS,
   COLOR_SCHEME_VERSION_INACTIVE_COMMENT,
   COLOR_SCHEME_VERSION_MODIFIED_ITEM,
   COLOR_SCHEME_VERSION_NAVHINT,
   COLOR_SCHEME_VERSION_XML_CHARACTER_REF,
   COLOR_SCHEME_VERSION_MARKDOWN,
   COLOR_SCHEME_VERSION_SELECTIVE_DISPLAY,
   COLOR_SCHEME_VERSION_SYMBOL_COLORING_PALETTE,

   // keep up with the latest color scheme version number
   COLOR_SCHEME_VERSION_LAST_PLUS_ONE,
   COLOR_SCHEME_VERSION_CURRENT = (COLOR_SCHEME_VERSION_LAST_PLUS_ONE-1),
};

void _convert_uscheme_ini(_str ini_filename='') {
   if (ini_filename=='') {
      ini_filename=usercfg_path_search('uscheme.ini');
   }
   if (!file_exists(ini_filename)) {
      return;
   }
   // Convert to the new .cfg.xml languages settings
   module := "convert_uscheme_ini.ex";
   filename := _macro_path_search(_strip_filename(substr(module,1,length(module)-1), "P"));
   //_message_box('filename='filename);
   if (filename=='') {
      module='convert_uscheme_ini.e';
      filename = _macro_path_search(_strip_filename(substr(module,1,length(module)), "P"));
      //_message_box('h2 filename='filename);
      if (filename=='') {
         filename='convert_uscheme_ini';
      }
   }
   shell(_maybe_quote_filename(filename)' '_maybe_quote_filename(ini_filename));
   recycle_file(_ConfigPath():+'uscheme.ini');
}

/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information
 * within SlickEdit.
 */
namespace se.color;

using namespace se.ui.AutoBracketMarker;
/**
 * The ColorScheme class is used to describe one SlickEdit color profile, 
 * including embedded colors.
 */
class ColorScheme : IColorCollection, sc.lang.IEquals {

   /**
    * This is a name for this scheme, for display in the GUI.
    */
   _str m_name;

   /**
    * This is the entire set of colors, indexed by the CFG_* 
    * color constants. 
    */
   private ColorInfo m_colors[];

   /**
    * This is the set of colors for embedded code, also indexed by 
    * the CFG_* color constants.  Note that although we store 
    * complete color information for each embedded color, as of 
    * SlickEdit 2009, we only use the embedded background color. 
    */
   private ColorInfo m_embedded[];

   /**
    * This is the recommended symbol coloring profile to use with
    * this color scheme.
    */
   _str m_symbolColoringProfile;

   /**
    * This is the name of the color scheme which this scheme inherits from.
    */
   _str m_inheritsProfile;

   /**
    * Keep track of what colors are defined in this scheme
    */
   bool m_definedColors[];

   /**
    * Construct a symbol color rule base.
    */
   ColorScheme(_str name = "") {
      m_name = name;
      m_colors = null;
      m_embedded = null;
      m_symbolColoringProfile = null;
      m_inheritsProfile = null;
      m_definedColors = null;
   }
   void initAllMembers(_str name,ColorInfo (&colors)[],ColorInfo (&embedded)[],_str symbolColoringProfile,_str inheritsProfile="") {
      m_name = name;
      m_colors = colors;
      m_embedded = embedded;
      m_symbolColoringProfile = symbolColoringProfile;
      m_inheritsProfile = inheritsProfile;
      for (i:=0; i<m_colors._length(); i++) {
         m_definedColors[i] = (m_colors[i] != null || m_embedded != null);
      }
   }
   /**
    * Modify a color in this color scheme.
    *
    * @param cfg        color index (CFG_*)
    *                   use negative numbers for embedded
    * @param color      color information
    *
    * @return 0 on success, <0 on error.
    */
   void setColor(int cfg, ColorInfo &color) {
      if (cfg < 0) {
         m_embedded[-cfg] = color;
      } else {
         m_definedColors[cfg] = true;
         m_colors[cfg] = color;
      }
   }

   /**
    * Modify a color in the embedded portion of this color scheme.
    *
    * @param cfg        color index (CFG_*)
    *                   use negative numbers for embedded
    * @param color      color information
    *
    * @return 0 on success, <0 on error.
    */
   void setEmbeddedColor(int cfg, ColorInfo &color) {
      m_definedColors[cfg] = true;
      m_embedded[cfg] = color;
   }

   /**
    * @return Return the total number of colors in this scheme.
    */
   int getNumColors() {
      return m_colors._length() + m_embedded._length();
   }

   /**
    * Return a pointer to the color information for the given item.
    *
    * @param cfg        color index (CFG_*)
    *                   use negative numbers for embedded
    *
    * @return ColorInfo* on success, null if no such color
    */
   ColorInfo *getColor(int cfg) {
      if (cfg < 0 && -cfg < m_embedded._length()) {
         return &m_embedded[-cfg];
      }
      if (cfg > 0 && cfg < m_colors._length()) {
         return &m_colors[cfg];
      }
      return null;
   }

   /**
    * Return a pointer to the color information for the given item 
    * in the embedded portion of the color scheme. 
    *
    * @param cfg        color index (CFG_*)
    *                   use negative numbers for embedded
    *
    * @return ColorInfo* on success, null if no such color
    */
   ColorInfo *getEmbeddedColor(int cfg) {
      if (cfg < m_embedded._length()) {
         return &m_embedded[cfg];
      }
      return null;
   }

   /** 
    * @return 
    * Return 'true' if the given color is defined in this profile, 'false' 
    * if the color scheme profile allows this color to default to empty. 
    * 
    * @param cfg        color index (CFG_*)
    */
   bool isColorDefinedInProfile(int cfg) {
      return (m_definedColors._indexin(cfg) && m_definedColors[cfg] == true &&  
              m_colors._indexin(cfg)        && m_colors[cfg] != null);
   }

   /**
    * Is the given color ID a significant embedded color?
    */
   static bool isEmbeddedColor(int cfg) {
      switch (cfg) {
      case CFG_CLINE:
      case CFG_CURSOR:
      case CFG_SELECTION:
      case CFG_SELECTED_CLINE:
      case CFG_WINDOW_TEXT:
      case CFG_ERROR:
      case CFG_MODIFIED_LINE:
      case CFG_INSERTED_LINE:
      case CFG_KEYWORD:
      case CFG_LINENUM:
      case CFG_NUMBER:
      case CFG_STRING:
      case CFG_COMMENT:
      case CFG_PPKEYWORD:
      case CFG_PUNCTUATION:
      case CFG_LIBRARY_SYMBOL:
      case CFG_OPERATOR:
      case CFG_USER_DEFINED:
      case CFG_NOSAVE_LINE:
      case CFG_FUNCTION:
      case CFG_FILENAME:
      case CFG_HILIGHT:
      case CFG_ATTRIBUTE:
      case CFG_UNKNOWN_ATTRIBUTE:
      case CFG_TAG:
      case CFG_UNKNOWN_TAG:
      case CFG_XHTMLELEMENTINXSL:
      case CFG_SPECIALCHARS:
      case CFG_BLOCK_MATCHING:
      case CFG_INC_SEARCH_CURRENT:
      case CFG_INC_SEARCH_MATCH:
      case CFG_HEX_MODE_COLOR:
      case CFG_SYMBOL_HIGHLIGHT:
      case CFG_LINE_COMMENT:
      case CFG_DOCUMENTATION:
      case CFG_DOC_KEYWORD:
      case CFG_DOC_PUNCTUATION:
      case CFG_DOC_ATTRIBUTE:
      case CFG_DOC_ATTR_VALUE:
      case CFG_IDENTIFIER:
      case CFG_IDENTIFIER2:
      case CFG_FLOATING_NUMBER:
      case CFG_HEX_NUMBER:
      case CFG_SINGLEQUOTED_STRING:
      case CFG_BACKQUOTED_STRING:
      case CFG_UNTERMINATED_STRING:
      case CFG_INACTIVE_CODE:
      case CFG_INACTIVE_KEYWORD:
      case CFG_INACTIVE_COMMENT:
      case CFG_IMAGINARY_SPACE:
      case CFG_XML_CHARACTER_REF:
      case CFG_MARKDOWN_HEADER:
      case CFG_MARKDOWN_CODE:
      case CFG_MARKDOWN_BLOCKQUOTE:
      case CFG_MARKDOWN_LINK:
      case CFG_MARKDOWN_LINK2:
      case CFG_MARKDOWN_BULLET:
      case CFG_MARKDOWN_EMPHASIS:
      case CFG_MARKDOWN_EMPHASIS2:
      case CFG_MARKDOWN_EMPHASIS3:
      case CFG_MARKDOWN_EMPHASIS4:
      case CFG_CSS_ELEMENT:
      case CFG_CSS_CLASS:
      case CFG_CSS_PROPERTY:
      case CFG_CSS_SELECTOR:
      case CFG_REF_HIGHLIGHT_0:
      case CFG_REF_HIGHLIGHT_1:
      case CFG_REF_HIGHLIGHT_2:
      case CFG_REF_HIGHLIGHT_3:
      case CFG_REF_HIGHLIGHT_4:
      case CFG_REF_HIGHLIGHT_5:
      case CFG_REF_HIGHLIGHT_6:
      case CFG_REF_HIGHLIGHT_7:
      case CFG_YAML_TEXT_COLON:
      case CFG_YAML_TEXT:
      case CFG_YAML_TAG:
      case CFG_YAML_DIRECTIVE:
      case CFG_YAML_ANCHOR_DEF:
      case CFG_YAML_ANCHOR_REF:
      case CFG_YAML_PUNCTUATION:
      case CFG_YAML_OPERATOR:
         return true;
      default:
         if (cfg >= CFG_FIRST_SYMBOL_COLOR && cfg <= CFG_LAST_SYMBOL_COLOR) {
            return true;
         }
         return false;
      }
   }

   /**
    * @return
    * Return the message code for the given color's name.
    * 
    * @param cfg  color ID 
    */
   static int getColorNameRC(int cfg)
   {
      switch (cfg) {
      case CFG_SELECTION:                  return VSRC_CFG_SELECTION;
      case CFG_WINDOW_TEXT:                return VSRC_CFG_WINDOW_TEXT;
      case CFG_CLINE:                      return VSRC_CFG_CURRENT_LINE;
      case CFG_SELECTED_CLINE:             return VSRC_CFG_SELECTED_CURRENT_LINE;
      case CFG_MESSAGE:                    return VSRC_CFG_MESSAGE;
      case CFG_STATUS:                     return VSRC_CFG_STATUS;
      case CFG_CURSOR:                     return VSRC_CFG_CURSOR;
      case CFG_ERROR:                      return VSRC_CFG_ERROR;
      case CFG_MODIFIED_LINE:              return VSRC_CFG_MODIFIED_LINE;
      case CFG_INSERTED_LINE:              return VSRC_CFG_INSERTED_LINE;
      case CFG_KEYWORD:                    return VSRC_CFG_KEYWORD;
      case CFG_LINENUM:                    return VSRC_CFG_LINE_NUMBER;
      case CFG_NUMBER:                     return VSRC_CFG_NUMBER;
      case CFG_STRING:                     return VSRC_CFG_STRING;
      case CFG_COMMENT:                    return VSRC_CFG_COMMENT;
      case CFG_PPKEYWORD:                  return VSRC_CFG_PREPROCESSOR;
      case CFG_PUNCTUATION:                return VSRC_CFG_PUNCTUATION;
      case CFG_LIBRARY_SYMBOL:             return VSRC_CFG_LIBRARY_SYMBOL;
      case CFG_OPERATOR:                   return VSRC_CFG_OPERATOR;
      case CFG_USER_DEFINED:               return VSRC_CFG_USER_DEFINED_SYMBOL;
      case CFG_NOSAVE_LINE:                return VSRC_CFG_NOSAVE_LINE;
      case CFG_FUNCTION:                   return VSRC_CFG_FUNCTION;
      case CFG_LINEPREFIXAREA:             return VSRC_CFG_LINE_PREFIX_AREA;
      case CFG_FILENAME:                   return VSRC_CFG_FILENAME;
      case CFG_HILIGHT:                    return VSRC_CFG_HIGHLIGHT;
      case CFG_ATTRIBUTE:                  return VSRC_CFG_ATTRIBUTE;
      case CFG_UNKNOWN_ATTRIBUTE:          return VSRC_CFG_UNKNOWN_ATTRIBUTE;
      case CFG_TAG:                        return VSRC_CFG_TAG;
      case CFG_UNKNOWN_TAG:                return VSRC_CFG_UNKNOWN_TAG;
      case CFG_XHTMLELEMENTINXSL:          return VSRC_CFG_XHTML_ELEMENT_IN_XSL;
      //case CFG_ACTIVECAPTION:              return VSRC_CFG_ACTIVE_TOOL_WINDOW_CAPTION;
      //case CFG_INACTIVECAPTION:            return VSRC_CFG_INACTIVE_TOOL_WINDOW_CAPTION;
      case CFG_SPECIALCHARS:               return VSRC_CFG_SPECIALCHARS;
      case CFG_CURRENT_LINE_BOX:           return VSRC_CFG_CURRENT_LINE_BOX;
      case CFG_VERTICAL_COL_LINE:          return VSRC_CFG_VERTICAL_COL_LINE;
      case CFG_MARGINS_COL_LINE:           return VSRC_CFG_MARGINS_COL_LINE;
      case CFG_TRUNCATION_COL_LINE:        return VSRC_CFG_TRUNCATION_COL_LINE;
      case CFG_PREFIX_AREA_LINE:           return VSRC_CFG_PREFIX_AREA_LINE;
      case CFG_BLOCK_MATCHING:             return VSRC_CFG_BLOCK_MATCHING;
      case CFG_INC_SEARCH_CURRENT:         return VSRC_CFG_INC_SEARCH_CURRENT;
      case CFG_INC_SEARCH_MATCH:           return VSRC_CFG_INC_SEARCH_MATCH;
      case CFG_HEX_MODE_COLOR:             return VSRC_CFG_HEX_MODE_COLOR;
      case CFG_SYMBOL_HIGHLIGHT:           return VSRC_CFG_SYMBOL_HIGHLIGHT;
      //case CFG_MODIFIED_FILE_TAB:          return VSRC_CFG_MODIFIED_FILE_TAB;
      case CFG_LINE_COMMENT:               return VSRC_CFG_LINE_COMMENT;
      case CFG_DOCUMENTATION:              return VSRC_CFG_DOCUMENTATION_COMMENT;
      case CFG_DOC_KEYWORD:                return VSRC_CFG_DOCUMENTATION_KEYWORD;
      case CFG_DOC_PUNCTUATION:            return VSRC_CFG_DOCUMENTATION_PUNCTUATION;
      case CFG_DOC_ATTRIBUTE:              return VSRC_CFG_DOCUMENTATION_ATTRIBUTE;
      case CFG_DOC_ATTR_VALUE:             return VSRC_CFG_DOCUMENTATION_ATTR_VALUE;
      case CFG_IDENTIFIER:                 return VSRC_CFG_IDENTIFIER;
      case CFG_IDENTIFIER2:                return VSRC_CFG_IDENTIFIER2;
      case CFG_FLOATING_NUMBER:            return VSRC_CFG_FLOATING_NUMBER;
      case CFG_HEX_NUMBER:                 return VSRC_CFG_HEX_NUMBER;
      case CFG_SINGLEQUOTED_STRING:        return VSRC_CFG_SINGLE_QUOTED_STRING;
      case CFG_BACKQUOTED_STRING:          return VSRC_CFG_BACKQUOTED_STRING;
      case CFG_UNTERMINATED_STRING:        return VSRC_CFG_UNTERMINATED_STRING;
      case CFG_INACTIVE_CODE:              return VSRC_CFG_INACTIVE_CODE;
      case CFG_INACTIVE_KEYWORD:           return VSRC_CFG_INACTIVE_KEYWORD;
      case CFG_INACTIVE_COMMENT:           return VSRC_CFG_INACTIVE_COMMENT;
      case CFG_IMAGINARY_SPACE:            return VSRC_CFG_IMAGINARY_SPACE;
      case CFG_MODIFIED_ITEM:              return VSRC_CFG_MODIFIED_ITEM;
      case CFG_NAVHINT:                    return VSRC_CFG_NAVHINT;
      case CFG_XML_CHARACTER_REF:          return VSRC_CFG_XML_CHARACTER_REF;
      case CFG_SEARCH_RESULT_TRUNCATED:    return VSRC_CFG_SEARCH_RESULT_TRUNCATED;
      case CFG_MARKDOWN_HEADER:            return VSRC_CFG_MARKDOWN_HEADER;
      case CFG_MARKDOWN_CODE:              return VSRC_CFG_MARKDOWN_CODE;
      case CFG_MARKDOWN_BLOCKQUOTE:        return VSRC_CFG_MARKDOWN_BLOCKQUOTE;
      case CFG_MARKDOWN_LINK:              return VSRC_CFG_MARKDOWN_LINK;
      case CFG_MARKDOWN_LINK2:             return VSRC_CFG_MARKDOWN_LINK2;
      case CFG_MARKDOWN_BULLET:            return VSRC_CFG_MARKDOWN_BULLET;
      case CFG_MARKDOWN_EMPHASIS:          return VSRC_CFG_MARKDOWN_EMPHASIS;
      case CFG_MARKDOWN_EMPHASIS2:         return VSRC_CFG_MARKDOWN_EMPHASIS2;
      case CFG_MARKDOWN_EMPHASIS3:         return VSRC_CFG_MARKDOWN_EMPHASIS3;
      case CFG_MARKDOWN_EMPHASIS4:         return VSRC_CFG_MARKDOWN_EMPHASIS4;
      case CFG_CSS_ELEMENT:                return VSRC_CFG_CSS_ELEMENT;
      case CFG_CSS_CLASS:                  return VSRC_CFG_CSS_CLASS;
      case CFG_CSS_PROPERTY:               return VSRC_CFG_CSS_PROPERTY;
      case CFG_CSS_SELECTOR:               return VSRC_CFG_CSS_SELECTOR;
      case CFG_DOCUMENT_TAB_ACTIVE:        return VSRC_CFG_DOCUMENT_TAB_ACTIVE;
      case CFG_DOCUMENT_TAB_MODIFIED:      return VSRC_CFG_DOCUMENT_TAB_MODIFIED;
      case CFG_DOCUMENT_TAB_SELECTED:      return VSRC_CFG_DOCUMENT_TAB_SELECTED;
      case CFG_DOCUMENT_TAB_UNSELECTED:    return VSRC_CFG_DOCUMENT_TAB_UNSELECTED;
      case CFG_SELECTIVE_DISPLAY_LINE:     return VSRC_CFG_SELECTIVE_DISPLAY_LINE;
      case CFG_REF_HIGHLIGHT_0:            return VSRC_CFG_REF_HIGHLIGHT_0;
      case CFG_REF_HIGHLIGHT_1:            return VSRC_CFG_REF_HIGHLIGHT_1;
      case CFG_REF_HIGHLIGHT_2:            return VSRC_CFG_REF_HIGHLIGHT_2;
      case CFG_REF_HIGHLIGHT_3:            return VSRC_CFG_REF_HIGHLIGHT_3;
      case CFG_REF_HIGHLIGHT_4:            return VSRC_CFG_REF_HIGHLIGHT_4;
      case CFG_REF_HIGHLIGHT_5:            return VSRC_CFG_REF_HIGHLIGHT_5;
      case CFG_REF_HIGHLIGHT_6:            return VSRC_CFG_REF_HIGHLIGHT_6;
      case CFG_REF_HIGHLIGHT_7:            return VSRC_CFG_REF_HIGHLIGHT_7;
      case CFG_MINIMAP_DIVIDER:            return VSRC_CFG_MINIMAP_DIVIDER;
      case CFG_YAML_TEXT_COLON:            return VSRC_CFG_YAML_TEXT_COLON;
      case CFG_YAML_TEXT:                  return VSRC_CFG_YAML_TEXT;
      case CFG_YAML_TAG:                   return VSRC_CFG_YAML_TAG;
      case CFG_YAML_DIRECTIVE:             return VSRC_CFG_YAML_DIRECTIVE;
      case CFG_YAML_ANCHOR_DEF:            return VSRC_CFG_YAML_ANCHOR_DEF;
      case CFG_YAML_ANCHOR_REF:            return VSRC_CFG_YAML_ANCHOR_REF;
      case CFG_YAML_PUNCTUATION:           return VSRC_CFG_YAML_PUNCTUATION;
      case CFG_YAML_OPERATOR:              return VSRC_CFG_YAML_OPERATOR;
      case CFG_LIVE_ERRORS_ERROR:          return VSRC_CFG_LIVE_ERRORS_ERROR;
      case CFG_LIVE_ERRORS_WARNING:        return VSRC_CFG_LIVE_ERRORS_WARNING;

      // "named" symbol coloring colors
      case CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND:                 return VSRC_CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND;
      case CFG_SYMBOL_COLOR_LOCAL_VARIABLE:                   return VSRC_CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
      case CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE:            return VSRC_CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE;
      case CFG_SYMBOL_COLOR_PARAMETER:                        return VSRC_CFG_SYMBOL_COLOR_PARAMETER;
      case CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER:               return VSRC_CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER;
      case CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE:           return VSRC_CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE;
      case CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE:          return VSRC_CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE;
      case CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE:        return VSRC_CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE;
      case CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE:          return VSRC_CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE;
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE:    return VSRC_CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE;
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE:   return VSRC_CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE;
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE: return VSRC_CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE;
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE:   return VSRC_CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE;
      case CFG_SYMBOL_COLOR_GLOBAL_VARIABLE:                  return VSRC_CFG_SYMBOL_COLOR_GLOBAL_VARIABLE;
      case CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE:           return VSRC_CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE;
      case CFG_SYMBOL_COLOR_GLOBAL_FUNCTION:                  return VSRC_CFG_SYMBOL_COLOR_GLOBAL_FUNCTION;
      case CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION:           return VSRC_CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION;
      case CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR:                return VSRC_CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR;
      case CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR:                 return VSRC_CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR;
      case CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION:           return VSRC_CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION;
      case CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION:          return VSRC_CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION;
      case CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION:        return VSRC_CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION;
      case CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION:          return VSRC_CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION;
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION:    return VSRC_CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION;
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION:   return VSRC_CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION;
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION: return VSRC_CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION;
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION:   return VSRC_CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION;
      case CFG_SYMBOL_COLOR_NESTED_FUNCTION:                  return VSRC_CFG_SYMBOL_COLOR_NESTED_FUNCTION;
      case CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY:            return VSRC_CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY;
      case CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY:           return VSRC_CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY;
      case CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY:         return VSRC_CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY;
      case CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY:           return VSRC_CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY;
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_CLASS_PROPERTY:     return VSRC_CFG_SYMBOL_COLOR_PUBLIC_STATIC_CLASS_PROPERTY;
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_CLASS_PROPERTY:    return VSRC_CFG_SYMBOL_COLOR_PACKAGE_STATIC_CLASS_PROPERTY;
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_CLASS_PROPERTY:  return VSRC_CFG_SYMBOL_COLOR_PROTECTED_STATIC_CLASS_PROPERTY;
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_CLASS_PROPERTY:    return VSRC_CFG_SYMBOL_COLOR_PRIVATE_STATIC_CLASS_PROPERTY;
      case CFG_SYMBOL_COLOR_CLASS:                            return VSRC_CFG_SYMBOL_COLOR_CLASS;
      case CFG_SYMBOL_COLOR_TEMPLATE_CLASS:                   return VSRC_CFG_SYMBOL_COLOR_TEMPLATE_CLASS;
      case CFG_SYMBOL_COLOR_ABSTRACT_CLASS:                   return VSRC_CFG_SYMBOL_COLOR_ABSTRACT_CLASS;
      case CFG_SYMBOL_COLOR_INTERFACE_CLASS:                  return VSRC_CFG_SYMBOL_COLOR_INTERFACE_CLASS;
      case CFG_SYMBOL_COLOR_STRUCT:                           return VSRC_CFG_SYMBOL_COLOR_STRUCT;
      case CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE:            return VSRC_CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE;
      case CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS:         return VSRC_CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS;
      case CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO:               return VSRC_CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO;
      case CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE:             return VSRC_CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE;
      case CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT:                return VSRC_CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT;
      case CFG_SYMBOL_COLOR_ENUMERATED_TYPE:                  return VSRC_CFG_SYMBOL_COLOR_ENUMERATED_TYPE;
      case CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT:               return VSRC_CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT;
      case CFG_SYMBOL_COLOR_STATEMENT_LABEL:                  return VSRC_CFG_SYMBOL_COLOR_STATEMENT_LABEL;
      case CFG_SYMBOL_COLOR_DATABASE_TABLE:                   return VSRC_CFG_SYMBOL_COLOR_DATABASE_TABLE;
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_COLUMN:            return VSRC_CFG_SYMBOL_COLOR_DATABASE_TABLE_COLUMN;
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_INDEX:             return VSRC_CFG_SYMBOL_COLOR_DATABASE_TABLE_INDEX;
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_VIEW:              return VSRC_CFG_SYMBOL_COLOR_DATABASE_TABLE_VIEW;
      case CFG_SYMBOL_COLOR_MODULE:                           return VSRC_CFG_SYMBOL_COLOR_MODULE;
      case CFG_SYMBOL_COLOR_CONCEPT:                          return VSRC_CFG_SYMBOL_COLOR_CONCEPT;
      case CFG_SYMBOL_COLOR_RULE:                             return VSRC_CFG_SYMBOL_COLOR_RULE;
      case CFG_SYMBOL_COLOR_ANNOTATION_TYPE:                  return VSRC_CFG_SYMBOL_COLOR_ANNOTATION_TYPE;
      case CFG_SYMBOL_COLOR_ANNOTATION:                       return VSRC_CFG_SYMBOL_COLOR_ANNOTATION;
      case CFG_SYMBOL_COLOR_CONTROL:                          return VSRC_CFG_SYMBOL_COLOR_CONTROL;
      case CFG_SYMBOL_COLOR_MENU:                             return VSRC_CFG_SYMBOL_COLOR_MENU;
      case CFG_SYMBOL_COLOR_FORM:                             return VSRC_CFG_SYMBOL_COLOR_FORM;
      case CFG_SYMBOL_COLOR_EVENT_TABLE:                      return VSRC_CFG_SYMBOL_COLOR_EVENT_TABLE;
      case CFG_SYMBOL_COLOR_PROTECTED_SCOPE:                  return VSRC_CFG_SYMBOL_COLOR_PROTECTED_SCOPE;
      case CFG_SYMBOL_COLOR_PRIVATE_SCOPE:                    return VSRC_CFG_SYMBOL_COLOR_PRIVATE_SCOPE;
      case CFG_SYMBOL_COLOR_PALETTE_00:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_00;
      case CFG_SYMBOL_COLOR_PALETTE_01:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_01;
      case CFG_SYMBOL_COLOR_PALETTE_02:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_02;
      case CFG_SYMBOL_COLOR_PALETTE_03:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_03;
      case CFG_SYMBOL_COLOR_PALETTE_04:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_04;
      case CFG_SYMBOL_COLOR_PALETTE_05:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_05;
      case CFG_SYMBOL_COLOR_PALETTE_06:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_06;
      case CFG_SYMBOL_COLOR_PALETTE_07:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_07;
      case CFG_SYMBOL_COLOR_PALETTE_08:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_08;
      case CFG_SYMBOL_COLOR_PALETTE_09:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_09;
      case CFG_SYMBOL_COLOR_PALETTE_10:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_10;
      case CFG_SYMBOL_COLOR_PALETTE_11:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_11;
      case CFG_SYMBOL_COLOR_PALETTE_12:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_12;
      case CFG_SYMBOL_COLOR_PALETTE_13:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_13;
      case CFG_SYMBOL_COLOR_PALETTE_14:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_14;
      case CFG_SYMBOL_COLOR_PALETTE_15:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_15;
      case CFG_SYMBOL_COLOR_PALETTE_16:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_16;
      case CFG_SYMBOL_COLOR_PALETTE_17:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_17;
      case CFG_SYMBOL_COLOR_PALETTE_18:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_18;
      case CFG_SYMBOL_COLOR_PALETTE_19:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_19;
      case CFG_SYMBOL_COLOR_PALETTE_20:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_20;
      case CFG_SYMBOL_COLOR_PALETTE_21:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_21;
      case CFG_SYMBOL_COLOR_PALETTE_22:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_22;
      case CFG_SYMBOL_COLOR_PALETTE_23:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_23;
      case CFG_SYMBOL_COLOR_PALETTE_24:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_24;
      case CFG_SYMBOL_COLOR_PALETTE_25:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_25;
      case CFG_SYMBOL_COLOR_PALETTE_26:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_26;
      case CFG_SYMBOL_COLOR_PALETTE_27:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_27;
      case CFG_SYMBOL_COLOR_PALETTE_28:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_28;
      case CFG_SYMBOL_COLOR_PALETTE_29:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_29;
      case CFG_SYMBOL_COLOR_PALETTE_30:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_30;
      case CFG_SYMBOL_COLOR_PALETTE_31:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_31;
      case CFG_SYMBOL_COLOR_PALETTE_32:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_32;
      case CFG_SYMBOL_COLOR_PALETTE_33:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_33;
      case CFG_SYMBOL_COLOR_PALETTE_34:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_34;
      case CFG_SYMBOL_COLOR_PALETTE_35:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_35;
      case CFG_SYMBOL_COLOR_PALETTE_36:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_36;
      case CFG_SYMBOL_COLOR_PALETTE_37:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_37;
      case CFG_SYMBOL_COLOR_PALETTE_38:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_38;
      case CFG_SYMBOL_COLOR_PALETTE_39:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_39;
      case CFG_SYMBOL_COLOR_PALETTE_40:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_40;
      case CFG_SYMBOL_COLOR_PALETTE_41:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_41;
      case CFG_SYMBOL_COLOR_PALETTE_42:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_42;
      case CFG_SYMBOL_COLOR_PALETTE_43:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_43;
      case CFG_SYMBOL_COLOR_PALETTE_44:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_44;
      case CFG_SYMBOL_COLOR_PALETTE_45:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_45;
      case CFG_SYMBOL_COLOR_PALETTE_46:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_46;
      case CFG_SYMBOL_COLOR_PALETTE_47:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_47;
      case CFG_SYMBOL_COLOR_PALETTE_48:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_48;
      case CFG_SYMBOL_COLOR_PALETTE_49:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_49;
      case CFG_SYMBOL_COLOR_PALETTE_50:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_50;
      case CFG_SYMBOL_COLOR_PALETTE_51:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_51;
      case CFG_SYMBOL_COLOR_PALETTE_52:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_52;
      case CFG_SYMBOL_COLOR_PALETTE_53:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_53;
      case CFG_SYMBOL_COLOR_PALETTE_54:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_54;
      case CFG_SYMBOL_COLOR_PALETTE_55:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_55;
      case CFG_SYMBOL_COLOR_PALETTE_56:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_56;
      case CFG_SYMBOL_COLOR_PALETTE_57:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_57;
      case CFG_SYMBOL_COLOR_PALETTE_58:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_58;
      case CFG_SYMBOL_COLOR_PALETTE_59:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_59;
      case CFG_SYMBOL_COLOR_PALETTE_60:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_60;
      case CFG_SYMBOL_COLOR_PALETTE_61:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_61;
      case CFG_SYMBOL_COLOR_PALETTE_62:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_62;
      case CFG_SYMBOL_COLOR_PALETTE_63:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_63;
      default:
         return 0;
      }
   }

   /**
    * @return
    * Return the message code for the given color's name.
    * 
    * @param cfg  color ID 
    */
   int getColorDescriptionRC(int cfg)
   {
      switch (cfg) {
      case CFG_SELECTION:                    return VSRC_CFG_SELECTION_DESCRIPTION;
      case CFG_WINDOW_TEXT:                  return VSRC_CFG_WINDOW_TEXT_DESCRIPTION;
      case CFG_CLINE:                        return VSRC_CFG_CURRENT_LINE_DESCRIPTION;
      case CFG_SELECTED_CLINE:               return VSRC_CFG_SELECTED_CURRENT_LINE_DESCRIPTION;
      case CFG_MESSAGE:                      return VSRC_CFG_MESSAGE_DESCRIPTION;
      case CFG_STATUS:                       return VSRC_CFG_STATUS_DESCRIPTION;
      case CFG_CURSOR:                       return VSRC_CFG_CURSOR_DESCRIPTION;
      case CFG_ERROR:                        return VSRC_CFG_ERROR_DESCRIPTION;
      case CFG_MODIFIED_LINE:                return VSRC_CFG_MODIFIED_LINE_DESCRIPTION;
      case CFG_INSERTED_LINE:                return VSRC_CFG_INSERTED_LINE_DESCRIPTION;
      case CFG_KEYWORD:                      return VSRC_CFG_KEYWORD_DESCRIPTION;
      case CFG_LINENUM:                      return VSRC_CFG_LINE_NUMBER_DESCRIPTION;
      case CFG_NUMBER:                       return VSRC_CFG_NUMBER_DESCRIPTION;
      case CFG_STRING:                       return VSRC_CFG_STRING_DESCRIPTION;
      case CFG_COMMENT:                      return VSRC_CFG_COMMENT_DESCRIPTION;
      case CFG_PPKEYWORD:                    return VSRC_CFG_PREPROCESSOR_DESCRIPTION;
      case CFG_PUNCTUATION:                  return VSRC_CFG_PUNCTUATION_DESCRIPTION;
      case CFG_LIBRARY_SYMBOL:               return VSRC_CFG_LIBRARY_SYMBOL_DESCRIPTION;
      case CFG_OPERATOR:                     return VSRC_CFG_OPERATOR_DESCRIPTION;
      case CFG_USER_DEFINED:                 return VSRC_CFG_USER_DEFINED_SYMBOL_DESCRIPTION;
      case CFG_NOSAVE_LINE:                  return VSRC_CFG_NOSAVE_LINE_DESCRIPTION;
      case CFG_FUNCTION:                     return VSRC_CFG_FUNCTION_DESCRIPTION;
      case CFG_LINEPREFIXAREA:               return VSRC_CFG_LINE_PREFIX_AREA_DESCRIPTION;
      case CFG_FILENAME:                     return VSRC_CFG_FILENAME_DESCRIPTION;
      case CFG_HILIGHT:                      return VSRC_CFG_HIGHLIGHT_DESCRIPTION;
      case CFG_ATTRIBUTE:                    return VSRC_CFG_ATTRIBUTE_DESCRIPTION;
      case CFG_UNKNOWN_ATTRIBUTE:            return VSRC_CFG_UNKNOWN_ATTRIBUTE_DESCRIPTION;
      case CFG_TAG:                          return VSRC_CFG_TAG_DESCRIPTION;
      case CFG_UNKNOWN_TAG:                  return VSRC_CFG_UNKNOWN_TAG_DESCRIPTION;
      case CFG_XHTMLELEMENTINXSL:            return VSRC_CFG_XHTML_ELEMENT_IN_XSL_DESCRIPTION;
      //case CFG_ACTIVECAPTION:                return VSRC_CFG_ACTIVE_TOOL_WINDOW_CAPTION_DESCRIPTION;
      //case CFG_INACTIVECAPTION:              return VSRC_CFG_INACTIVE_TOOL_WINDOW_CAPTION_DESCRIPTION;
      case CFG_SPECIALCHARS:                 return VSRC_CFG_SPECIALCHARS_DESCRIPTION;
      case CFG_CURRENT_LINE_BOX:             return VSRC_CFG_CURRENT_LINE_BOX_DESCRIPTION;
      case CFG_VERTICAL_COL_LINE:            return VSRC_CFG_VERTICAL_COL_LINE_DESCRIPTION;
      case CFG_MARGINS_COL_LINE:             return VSRC_CFG_MARGINS_COL_LINE_DESCRIPTION;
      case CFG_TRUNCATION_COL_LINE:          return VSRC_CFG_TRUNCATION_COL_LINE_DESCRIPTION;
      case CFG_PREFIX_AREA_LINE:             return VSRC_CFG_PREFIX_AREA_LINE_DESCRIPTION;
      case CFG_BLOCK_MATCHING:               return VSRC_CFG_BLOCK_MATCHING_DESCRIPTION;
      case CFG_INC_SEARCH_CURRENT:           return VSRC_CFG_INC_SEARCH_CURRENT_DESCRIPTION;
      case CFG_INC_SEARCH_MATCH:             return VSRC_CFG_INC_SEARCH_MATCH_DESCRIPTION;
      case CFG_HEX_MODE_COLOR:               return VSRC_CFG_HEX_MODE_COLOR_DESCRIPTION;
      case CFG_SYMBOL_HIGHLIGHT:             return VSRC_CFG_SYMBOL_HIGHLIGHT_DESCRIPTION;
      //case CFG_MODIFIED_FILE_TAB:            return VSRC_CFG_MODIFIED_FILE_TAB_DESCRIPTION;
      case CFG_LINE_COMMENT:                 return VSRC_CFG_LINE_COMMENT_DESCRIPTION;
      case CFG_DOCUMENTATION:                return VSRC_CFG_DOC_COMMENT_DESCRIPTION;
      case CFG_DOC_KEYWORD:                  return VSRC_CFG_DOCUMENTATION_KEYWORD_DESCRIPTION;
      case CFG_DOC_PUNCTUATION:              return VSRC_CFG_DOCUMENTATION_PUNCTUATION_DESCRIPTION;
      case CFG_DOC_ATTRIBUTE:                return VSRC_CFG_DOCUMENTATION_ATTRIBUTE_DESCRIPTION;
      case CFG_DOC_ATTR_VALUE:               return VSRC_CFG_DOCUMENTATION_ATTR_VALUE_DESCRIPTION;
      case CFG_IDENTIFIER:                   return VSRC_CFG_IDENTIFIER_DESCRIPTION;
      case CFG_IDENTIFIER2:                  return VSRC_CFG_IDENTIFIER2_DESCRIPTION;
      case CFG_FLOATING_NUMBER:              return VSRC_CFG_FLOATING_NUMBER_DESCRIPTION;
      case CFG_HEX_NUMBER:                   return VSRC_CFG_HEX_NUMBER_DESCRIPTION;
      case CFG_SINGLEQUOTED_STRING:          return VSRC_CFG_SINGLE_QUOTED_STRING_DESCRIPTION;
      case CFG_BACKQUOTED_STRING:            return VSRC_CFG_BACKQUOTED_STRING_DESCRIPTION;
      case CFG_UNTERMINATED_STRING:          return VSRC_CFG_UNTERMINATED_STRING_DESCRIPTION;
      case CFG_INACTIVE_CODE:                return VSRC_CFG_INACTIVE_CODE_DESCRIPTION;
      case CFG_INACTIVE_KEYWORD:             return VSRC_CFG_INACTIVE_KEYWORD_DESCRIPTION;
      case CFG_INACTIVE_COMMENT:             return VSRC_CFG_INACTIVE_COMMENT_DESCRIPTION;
      case CFG_IMAGINARY_SPACE:              return VSRC_CFG_IMAGINARY_SPACE_DESCRIPTION;
      case CFG_MODIFIED_ITEM:                return VSRC_CFG_MODIFIED_ITEM_DESCRIPTION;
      case CFG_NAVHINT:                      return VSRC_CFG_NAVHINT_DESCRIPTION;
      case CFG_LIVE_ERRORS_ERROR:            return VSRC_CFG_LIVE_ERRORS_ERROR_DESCRIPTION;
      case CFG_LIVE_ERRORS_WARNING:          return VSRC_CFG_LIVE_ERRORS_WARNING_DESCRIPTION;
      case CFG_XML_CHARACTER_REF:            return VSRC_CFG_XML_CHARACTER_REF_DESCRIPTION;
      case CFG_SEARCH_RESULT_TRUNCATED:      return VSRC_CFG_SEARCH_RESULT_TRUNCATED_DESCRIPTION;
      case CFG_MARKDOWN_HEADER:              return VSRC_CFG_MARKDOWN_HEADER_DESCRIPTION;
      case CFG_MARKDOWN_CODE:                return VSRC_CFG_MARKDOWN_CODE_DESCRIPTION;
      case CFG_MARKDOWN_BLOCKQUOTE:          return VSRC_CFG_MARKDOWN_BLOCKQUOTE_DESCRIPTION;
      case CFG_MARKDOWN_LINK:                return VSRC_CFG_MARKDOWN_LINK_DESCRIPTION;
      case CFG_MARKDOWN_LINK2:               return VSRC_CFG_MARKDOWN_LINK2_DESCRIPTION;
      case CFG_MARKDOWN_BULLET:              return VSRC_CFG_MARKDOWN_BULLET_DESCRIPTION;
      case CFG_MARKDOWN_EMPHASIS:            return VSRC_CFG_MARKDOWN_EMPHASIS_DESCRIPTION;
      case CFG_MARKDOWN_EMPHASIS2:           return VSRC_CFG_MARKDOWN_EMPHASIS2_DESCRIPTION;
      case CFG_MARKDOWN_EMPHASIS3:           return VSRC_CFG_MARKDOWN_EMPHASIS3_DESCRIPTION;
      case CFG_MARKDOWN_EMPHASIS4:           return VSRC_CFG_MARKDOWN_EMPHASIS4_DESCRIPTION;
      case CFG_CSS_ELEMENT:                  return VSRC_CFG_CSS_ELEMENT_DESCRIPTION;
      case CFG_CSS_CLASS:                    return VSRC_CFG_CSS_CLASS_DESCRIPTION;
      case CFG_CSS_PROPERTY:                 return VSRC_CFG_CSS_PROPERTY_DESCRIPTION;
      case CFG_CSS_SELECTOR:                 return VSRC_CFG_CSS_SELECTOR_DESCRIPTION;
      case CFG_DOCUMENT_TAB_ACTIVE:          return VSRC_CFG_DOCUMENT_TAB_ACTIVE_DESCRIPTION;
      case CFG_DOCUMENT_TAB_MODIFIED:        return VSRC_CFG_DOCUMENT_TAB_MODIFIED_DESCRIPTION;
      case CFG_DOCUMENT_TAB_SELECTED:        return VSRC_CFG_DOCUMENT_TAB_SELECTED_DESCRIPTION;
      case CFG_DOCUMENT_TAB_UNSELECTED:      return VSRC_CFG_DOCUMENT_TAB_UNSELECTED_DESCRIPTION;
      case CFG_SELECTIVE_DISPLAY_LINE:       return VSRC_CFG_SELECTIVE_DISPLAY_LINE_DESCRIPTION;
      case CFG_REF_HIGHLIGHT_0:              return VSRC_CFG_REF_HIGHLIGHT_DESCRIPTION;
      case CFG_REF_HIGHLIGHT_1:              return VSRC_CFG_REF_HIGHLIGHT_DESCRIPTION;
      case CFG_REF_HIGHLIGHT_2:              return VSRC_CFG_REF_HIGHLIGHT_DESCRIPTION;
      case CFG_REF_HIGHLIGHT_3:              return VSRC_CFG_REF_HIGHLIGHT_DESCRIPTION;
      case CFG_REF_HIGHLIGHT_4:              return VSRC_CFG_REF_HIGHLIGHT_DESCRIPTION;
      case CFG_REF_HIGHLIGHT_5:              return VSRC_CFG_REF_HIGHLIGHT_DESCRIPTION;
      case CFG_REF_HIGHLIGHT_6:              return VSRC_CFG_REF_HIGHLIGHT_DESCRIPTION;
      case CFG_REF_HIGHLIGHT_7:              return VSRC_CFG_REF_HIGHLIGHT_DESCRIPTION;
      case CFG_MINIMAP_DIVIDER:              return VSRC_CFG_MINIMAP_DIVIDER_DESCRIPTION;
      case CFG_YAML_TEXT_COLON:            return VSRC_CFG_YAML_TEXT_COLON_DESCRIPTION;
      case CFG_YAML_TEXT:                  return VSRC_CFG_YAML_TEXT_DESCRIPTION;
      case CFG_YAML_TAG:                   return VSRC_CFG_YAML_TAG_DESCRIPTION;
      case CFG_YAML_DIRECTIVE:             return VSRC_CFG_YAML_DIRECTIVE_DESCRIPTION;
      case CFG_YAML_ANCHOR_DEF:            return VSRC_CFG_YAML_ANCHOR_DEF_DESCRIPTION;
      case CFG_YAML_ANCHOR_REF:            return VSRC_CFG_YAML_ANCHOR_REF_DESCRIPTION;
      case CFG_YAML_PUNCTUATION:           return VSRC_CFG_YAML_PUNCTUATION_DESCRIPTION;
      case CFG_YAML_OPERATOR:              return VSRC_CFG_YAML_OPERATOR_DESCRIPTION;

      // "named" symbol coloring colors
      case CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND:                 return VSRC_CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND_DESCRIPTION;
      case CFG_SYMBOL_COLOR_LOCAL_VARIABLE:                   return VSRC_CFG_SYMBOL_COLOR_LOCAL_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE:            return VSRC_CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PARAMETER:                        return VSRC_CFG_SYMBOL_COLOR_PARAMETER_DESCRIPTION;
      case CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER:               return VSRC_CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE:           return VSRC_CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE:          return VSRC_CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE:        return VSRC_CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE:          return VSRC_CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE:    return VSRC_CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE:   return VSRC_CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE: return VSRC_CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE:   return VSRC_CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_GLOBAL_VARIABLE:                  return VSRC_CFG_SYMBOL_COLOR_GLOBAL_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE:           return VSRC_CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_GLOBAL_FUNCTION:                  return VSRC_CFG_SYMBOL_COLOR_GLOBAL_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION:           return VSRC_CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR:                return VSRC_CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR_DESCRIPTION;
      case CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR:                 return VSRC_CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION:           return VSRC_CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION:          return VSRC_CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION:        return VSRC_CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION:          return VSRC_CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION:    return VSRC_CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION:   return VSRC_CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION: return VSRC_CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION:   return VSRC_CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_NESTED_FUNCTION:                  return VSRC_CFG_SYMBOL_COLOR_NESTED_FUNCTION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY:            return VSRC_CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY:           return VSRC_CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY:         return VSRC_CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY:           return VSRC_CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_CLASS_PROPERTY:     return VSRC_CFG_SYMBOL_COLOR_PUBLIC_STATIC_CLASS_PROPERTY_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_CLASS_PROPERTY:    return VSRC_CFG_SYMBOL_COLOR_PACKAGE_STATIC_CLASS_PROPERTY_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_CLASS_PROPERTY:  return VSRC_CFG_SYMBOL_COLOR_PROTECTED_STATIC_CLASS_PROPERTY_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_CLASS_PROPERTY:    return VSRC_CFG_SYMBOL_COLOR_PRIVATE_STATIC_CLASS_PROPERTY_DESCRIPTION;
      case CFG_SYMBOL_COLOR_CLASS:                            return VSRC_CFG_SYMBOL_COLOR_CLASS_DESCRIPTION;
      case CFG_SYMBOL_COLOR_TEMPLATE_CLASS:                   return VSRC_CFG_SYMBOL_COLOR_TEMPLATE_CLASS_DESCRIPTION;
      case CFG_SYMBOL_COLOR_ABSTRACT_CLASS:                   return VSRC_CFG_SYMBOL_COLOR_ABSTRACT_CLASS_DESCRIPTION;
      case CFG_SYMBOL_COLOR_INTERFACE_CLASS:                  return VSRC_CFG_SYMBOL_COLOR_INTERFACE_CLASS_DESCRIPTION;
      case CFG_SYMBOL_COLOR_STRUCT:                           return VSRC_CFG_SYMBOL_COLOR_STRUCT_DESCRIPTION;
      case CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE:            return VSRC_CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS:         return VSRC_CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO:               return VSRC_CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE:             return VSRC_CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT:                return VSRC_CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT_DESCRIPTION;
      case CFG_SYMBOL_COLOR_ENUMERATED_TYPE:                  return VSRC_CFG_SYMBOL_COLOR_ENUMERATED_TYPE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT:               return VSRC_CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT_DESCRIPTION;
      case CFG_SYMBOL_COLOR_STATEMENT_LABEL:                  return VSRC_CFG_SYMBOL_COLOR_STATEMENT_LABEL_DESCRIPTION;
      case CFG_SYMBOL_COLOR_DATABASE_TABLE:                   return VSRC_CFG_SYMBOL_COLOR_DATABASE_TABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_COLUMN:            return VSRC_CFG_SYMBOL_COLOR_DATABASE_TABLE_COLUMN_DESCRIPTION;
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_INDEX:             return VSRC_CFG_SYMBOL_COLOR_DATABASE_TABLE_INDEX_DESCRIPTION;
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_VIEW:              return VSRC_CFG_SYMBOL_COLOR_DATABASE_TABLE_VIEW_DESCRIPTION;
      case CFG_SYMBOL_COLOR_MODULE:                           return VSRC_CFG_SYMBOL_COLOR_MODULE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_CONCEPT:                          return VSRC_CFG_SYMBOL_COLOR_CONCEPT_DESCRIPTION;
      case CFG_SYMBOL_COLOR_RULE:                             return VSRC_CFG_SYMBOL_COLOR_RULE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_ANNOTATION_TYPE:                  return VSRC_CFG_SYMBOL_COLOR_ANNOTATION_TYPE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_ANNOTATION:                       return VSRC_CFG_SYMBOL_COLOR_ANNOTATION_DESCRIPTION;
      case CFG_SYMBOL_COLOR_CONTROL:                          return VSRC_CFG_SYMBOL_COLOR_CONTROL_DESCRIPTION;
      case CFG_SYMBOL_COLOR_MENU:                             return VSRC_CFG_SYMBOL_COLOR_MENU_DESCRIPTION;
      case CFG_SYMBOL_COLOR_FORM:                             return VSRC_CFG_SYMBOL_COLOR_FORM_DESCRIPTION;
      case CFG_SYMBOL_COLOR_EVENT_TABLE:                      return VSRC_CFG_SYMBOL_COLOR_EVENT_TABLE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PROTECTED_SCOPE:                  return VSRC_CFG_SYMBOL_COLOR_PROTECTED_SCOPE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PRIVATE_SCOPE:                    return VSRC_CFG_SYMBOL_COLOR_PRIVATE_SCOPE_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_00:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_00_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_01:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_01_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_02:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_02_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_03:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_03_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_04:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_04_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_05:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_05_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_06:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_06_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_07:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_07_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_08:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_08_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_09:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_09_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_10:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_10_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_11:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_11_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_12:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_12_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_13:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_13_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_14:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_14_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_15:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_15_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_16:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_16_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_17:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_17_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_18:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_18_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_19:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_19_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_20:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_20_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_21:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_21_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_22:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_22_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_23:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_23_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_24:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_24_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_25:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_25_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_26:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_26_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_27:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_27_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_28:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_28_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_29:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_29_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_30:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_30_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_31:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_31_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_32:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_32_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_33:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_33_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_34:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_34_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_35:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_35_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_36:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_36_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_37:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_37_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_38:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_38_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_39:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_39_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_40:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_40_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_41:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_41_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_42:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_42_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_43:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_43_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_44:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_44_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_45:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_45_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_46:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_46_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_47:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_47_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_48:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_48_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_49:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_49_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_50:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_50_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_51:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_51_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_52:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_52_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_53:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_53_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_54:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_54_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_55:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_55_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_56:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_56_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_57:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_57_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_58:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_58_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_59:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_59_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_60:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_60_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_61:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_61_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_62:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_62_DESCRIPTION;
      case CFG_SYMBOL_COLOR_PALETTE_63:                       return VSRC_CFG_SYMBOL_COLOR_PALETTE_63_DESCRIPTION;
      default:
         return 0;
      }
   }

   /**
    * Get the color index for the given display color name.
    */
   static int getColorIndexByName(_str colorName) {
      int colorNameRC[];
      for (cfg:=1; cfg<=CFG_LAST_DEFAULT_COLOR; cfg++) {
         colorNameRC[cfg] = getColorNameRC(cfg);
      }
      foreach (cfg => auto colorRC in colorNameRC) {
         if (colorRC!=0 && get_message(colorRC) == colorName) {
            return cfg;
         }
      }
      return STRING_NOT_FOUND_RC;
   }

   /**
    * @return Return the display name for the given color index. 
    *         Return null if we do not have a display name for
    *         this color.
    */
   static _str getColorName(int cfg) {
      if (cfg < 0) {
         cfg = -cfg;
      }

      if (cfg < 0 || cfg > CFG_LAST_DEFAULT_COLOR) {
         return null;
      }
      colorNameRC := getColorNameRC(cfg);
      if (colorNameRC == 0) return null;
      return get_message(colorNameRC);
   }

   /**
    * @return Return the description of the given color.
    *         Return null if we do not have a
    *         description for this color.
    */
   _str getColorDescription(int cfg) {
      if (cfg < 0) {
         cfg = -cfg;
      }

      if (cfg < 0 || cfg > CFG_LAST_DEFAULT_COLOR) {
         return null;
      }
      colorDescRC := getColorDescriptionRC(cfg);
      if (colorDescRC == 0) return null;
      return get_message(colorDescRC);
   }

   /**
    * @return Return the color category for the given color item.
    */
   _str getColorCategoryName(int colorId, int &priority) {

      if (colorId < 0) colorId = -colorId;
       categoryRC := 0;
       switch (colorId) {
       case CFG_WINDOW_TEXT:
          categoryRC = VSRC_COLOR_CATEGORY_CANVAS_COLOR;
          priority = -1000;
          break;
       case CFG_KEYWORD:
       case CFG_PPKEYWORD:
       case CFG_SYMBOL1:
       case CFG_SYMBOL2:
       case CFG_SYMBOL3:
       case CFG_SYMBOL4:
       case CFG_FUNCTION:
       case CFG_SPECIALCHARS:
       case CFG_IDENTIFIER:
       case CFG_IDENTIFIER2:
           categoryRC = VSRC_COLOR_CATEGORY_EDITOR_TEXT;
           priority = -999;
           break;
       case CFG_SELECTION:
       case CFG_CLINE:
       case CFG_SELECTED_CLINE:
       case CFG_CURSOR:
           categoryRC = VSRC_COLOR_CATEGORY_EDITOR_CURSOR;
           priority = -990;
           break;
       case CFG_COMMENT:
       case CFG_LINE_COMMENT:
       case CFG_DOCUMENTATION:
       case CFG_DOC_KEYWORD:
       case CFG_DOC_PUNCTUATION:
       case CFG_DOC_ATTRIBUTE:
       case CFG_DOC_ATTR_VALUE:
       case CFG_INACTIVE_CODE:
       case CFG_INACTIVE_KEYWORD:
       case CFG_INACTIVE_COMMENT:
           categoryRC = VSRC_COLOR_CATEGORY_COMMENTS;
           priority = -980;
           break;
       case CFG_STRING:
       case CFG_SINGLEQUOTED_STRING:
       case CFG_BACKQUOTED_STRING:
       case CFG_UNTERMINATED_STRING:
           categoryRC = VSRC_COLOR_CATEGORY_STRINGS;
           priority = -970;
           break;
       case CFG_LINENUM:
       case CFG_NUMBER:
       case CFG_FLOATING_NUMBER:
       case CFG_HEX_NUMBER:
          categoryRC = VSRC_COLOR_CATEGORY_NUMBERS;
          priority = -960;
          break;
       case CFG_ATTRIBUTE:
       case CFG_UNKNOWN_ATTRIBUTE:
       case CFG_TAG:
       case CFG_UNKNOWN_TAG:
       case CFG_XHTMLELEMENTINXSL:
       case CFG_XML_CHARACTER_REF:
           categoryRC = VSRC_COLOR_CATEGORY_XML;
           priority = -950;
           break;
       case CFG_CSS_ELEMENT:
       case CFG_CSS_CLASS:
       case CFG_CSS_PROPERTY:
       case CFG_CSS_SELECTOR:
          categoryRC = VSRC_COLOR_CATEGORY_CSS;
          priority = -940;
          break;
       case CFG_MARKDOWN_HEADER:    
       case CFG_MARKDOWN_CODE:      
       case CFG_MARKDOWN_BLOCKQUOTE:
       case CFG_MARKDOWN_LINK:      
       case CFG_MARKDOWN_LINK2:
       case CFG_MARKDOWN_BULLET:
       case CFG_MARKDOWN_EMPHASIS:
       case CFG_MARKDOWN_EMPHASIS2:
       case CFG_MARKDOWN_EMPHASIS3:
       case CFG_MARKDOWN_EMPHASIS4:
           categoryRC = VSRC_COLOR_CATEGORY_MARKDOWN;
           priority = -930;
           break;
       case CFG_YAML_TEXT_COLON:
       case CFG_YAML_TEXT:
       case CFG_YAML_TAG:
       case CFG_YAML_DIRECTIVE:
       case CFG_YAML_ANCHOR_DEF:
       case CFG_YAML_ANCHOR_REF:
       case CFG_YAML_PUNCTUATION:
       case CFG_YAML_OPERATOR:
          categoryRC = VSRC_COLOR_CATEGORY_YAML;
          priority = -925;
          break;
       case CFG_MODIFIED_LINE:
       case CFG_INSERTED_LINE:
       case CFG_IMAGINARY_LINE:
       case CFG_IMAGINARY_SPACE:
           categoryRC = VSRC_COLOR_CATEGORY_DIFF;
           priority = -920;
           break;
       case CFG_FILENAME:
       case CFG_HILIGHT:
       case CFG_INC_SEARCH_CURRENT:
       case CFG_INC_SEARCH_MATCH:
       case CFG_HEX_MODE_COLOR:
       case CFG_SYMBOL_HIGHLIGHT:
       case CFG_BLOCK_MATCHING:
       case CFG_ERROR:
       case CFG_SEARCH_RESULT_TRUNCATED:
           categoryRC = VSRC_COLOR_CATEGORY_HIGHLIGHTS;
           priority = -910;
           break;
       case CFG_LINEPREFIXAREA:
       case CFG_CURRENT_LINE_BOX:
       case CFG_VERTICAL_COL_LINE:
       case CFG_MARGINS_COL_LINE:
       case CFG_TRUNCATION_COL_LINE:
       case CFG_PREFIX_AREA_LINE:
       case CFG_SELECTIVE_DISPLAY_LINE:
       case CFG_MINIMAP_DIVIDER:
           categoryRC = VSRC_COLOR_CATEGORY_EDITOR_COLUMNS;
           priority = -900;
           break;

       //case CFG_MODIFIED_FILE_TAB:
       case CFG_DOCUMENT_TAB_ACTIVE:
       case CFG_DOCUMENT_TAB_MODIFIED:
       case CFG_DOCUMENT_TAB_SELECTED:
       case CFG_DOCUMENT_TAB_UNSELECTED:
           categoryRC = VSRC_COLOR_CATEGORY_DOCUMENT_TABS;
           priority = -890;
           break;

       case CFG_MESSAGE:
       case CFG_STATUS:
       case CFG_CMDLINE:
       case CFG_MODIFIED_ITEM:
       case CFG_FUNCTION_HELP:
       case CFG_FUNCTION_HELP_FIXED:
       case CFG_NAVHINT:
           categoryRC = VSRC_COLOR_CATEGORY_MISC;
           priority = -880;
           break;

       case CFG_REF_HIGHLIGHT_0:
       case CFG_REF_HIGHLIGHT_1:
       case CFG_REF_HIGHLIGHT_2:
       case CFG_REF_HIGHLIGHT_3:
       case CFG_REF_HIGHLIGHT_4:
       case CFG_REF_HIGHLIGHT_5:
       case CFG_REF_HIGHLIGHT_6:
       case CFG_REF_HIGHLIGHT_7:
          categoryRC = VSRC_COLOR_CATEGORY_REFERENCES;
          priority = -850;
          break;

       // "named" symbol coloring colors
       case CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND:
       case CFG_SYMBOL_COLOR_LOCAL_VARIABLE:
       case CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE:
       case CFG_SYMBOL_COLOR_PARAMETER:
       case CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER:
       case CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE:
       case CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE:
       case CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE:
       case CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE:
       case CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE:
       case CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE:
       case CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE:
       case CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE:
       case CFG_SYMBOL_COLOR_GLOBAL_VARIABLE:
       case CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE:
       case CFG_SYMBOL_COLOR_GLOBAL_FUNCTION:
       case CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION:
       case CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR:
       case CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR:
       case CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION:
       case CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION:
       case CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION:
       case CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION:
       case CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION:
       case CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION:
       case CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION:
       case CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION:
       case CFG_SYMBOL_COLOR_NESTED_FUNCTION:
       case CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY:
       case CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY:
       case CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY:
       case CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY:
       case CFG_SYMBOL_COLOR_PUBLIC_STATIC_CLASS_PROPERTY:
       case CFG_SYMBOL_COLOR_PACKAGE_STATIC_CLASS_PROPERTY:
       case CFG_SYMBOL_COLOR_PROTECTED_STATIC_CLASS_PROPERTY:
       case CFG_SYMBOL_COLOR_PRIVATE_STATIC_CLASS_PROPERTY:
       case CFG_SYMBOL_COLOR_CLASS:
       case CFG_SYMBOL_COLOR_TEMPLATE_CLASS:
       case CFG_SYMBOL_COLOR_ABSTRACT_CLASS:
       case CFG_SYMBOL_COLOR_INTERFACE_CLASS:
       case CFG_SYMBOL_COLOR_STRUCT:
       case CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE:
       case CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS:
       case CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO:
       case CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE:
       case CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT:
       case CFG_SYMBOL_COLOR_ENUMERATED_TYPE:
       case CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT:
       case CFG_SYMBOL_COLOR_STATEMENT_LABEL:
       case CFG_SYMBOL_COLOR_DATABASE_TABLE:
       case CFG_SYMBOL_COLOR_DATABASE_TABLE_COLUMN:
       case CFG_SYMBOL_COLOR_DATABASE_TABLE_INDEX:
       case CFG_SYMBOL_COLOR_DATABASE_TABLE_VIEW:
       case CFG_SYMBOL_COLOR_MODULE:
       case CFG_SYMBOL_COLOR_CONCEPT:
       case CFG_SYMBOL_COLOR_RULE:
       case CFG_SYMBOL_COLOR_ANNOTATION_TYPE:
       case CFG_SYMBOL_COLOR_ANNOTATION:
       case CFG_SYMBOL_COLOR_CONTROL:
       case CFG_SYMBOL_COLOR_MENU:
       case CFG_SYMBOL_COLOR_FORM:
       case CFG_SYMBOL_COLOR_EVENT_TABLE:
       case CFG_SYMBOL_COLOR_PROTECTED_SCOPE:
       case CFG_SYMBOL_COLOR_PRIVATE_SCOPE:
          categoryRC = VSRC_COLOR_CATEGORY_SYMBOL_COLORING;
          priority = -810;
          break;
       case CFG_SYMBOL_COLOR_PALETTE_00:
       case CFG_SYMBOL_COLOR_PALETTE_01:
       case CFG_SYMBOL_COLOR_PALETTE_02:
       case CFG_SYMBOL_COLOR_PALETTE_03:
       case CFG_SYMBOL_COLOR_PALETTE_04:
       case CFG_SYMBOL_COLOR_PALETTE_05:
       case CFG_SYMBOL_COLOR_PALETTE_06:
       case CFG_SYMBOL_COLOR_PALETTE_07:
       case CFG_SYMBOL_COLOR_PALETTE_08:
       case CFG_SYMBOL_COLOR_PALETTE_09:
       case CFG_SYMBOL_COLOR_PALETTE_10:
       case CFG_SYMBOL_COLOR_PALETTE_11:
       case CFG_SYMBOL_COLOR_PALETTE_12:
       case CFG_SYMBOL_COLOR_PALETTE_13:
       case CFG_SYMBOL_COLOR_PALETTE_14:
       case CFG_SYMBOL_COLOR_PALETTE_15:
       case CFG_SYMBOL_COLOR_PALETTE_16:
       case CFG_SYMBOL_COLOR_PALETTE_17:
       case CFG_SYMBOL_COLOR_PALETTE_18:
       case CFG_SYMBOL_COLOR_PALETTE_19:
       case CFG_SYMBOL_COLOR_PALETTE_20:
       case CFG_SYMBOL_COLOR_PALETTE_21:
       case CFG_SYMBOL_COLOR_PALETTE_22:
       case CFG_SYMBOL_COLOR_PALETTE_23:
       case CFG_SYMBOL_COLOR_PALETTE_24:
       case CFG_SYMBOL_COLOR_PALETTE_25:
       case CFG_SYMBOL_COLOR_PALETTE_26:
       case CFG_SYMBOL_COLOR_PALETTE_27:
       case CFG_SYMBOL_COLOR_PALETTE_28:
       case CFG_SYMBOL_COLOR_PALETTE_29:
       case CFG_SYMBOL_COLOR_PALETTE_30:
       case CFG_SYMBOL_COLOR_PALETTE_31:
       case CFG_SYMBOL_COLOR_PALETTE_32:
       case CFG_SYMBOL_COLOR_PALETTE_33:
       case CFG_SYMBOL_COLOR_PALETTE_34:
       case CFG_SYMBOL_COLOR_PALETTE_35:
       case CFG_SYMBOL_COLOR_PALETTE_36:
       case CFG_SYMBOL_COLOR_PALETTE_37:
       case CFG_SYMBOL_COLOR_PALETTE_38:
       case CFG_SYMBOL_COLOR_PALETTE_39:
       case CFG_SYMBOL_COLOR_PALETTE_40:
       case CFG_SYMBOL_COLOR_PALETTE_41:
       case CFG_SYMBOL_COLOR_PALETTE_42:
       case CFG_SYMBOL_COLOR_PALETTE_43:
       case CFG_SYMBOL_COLOR_PALETTE_44:
       case CFG_SYMBOL_COLOR_PALETTE_45:
       case CFG_SYMBOL_COLOR_PALETTE_46:
       case CFG_SYMBOL_COLOR_PALETTE_47:
       case CFG_SYMBOL_COLOR_PALETTE_48:
       case CFG_SYMBOL_COLOR_PALETTE_49:
       case CFG_SYMBOL_COLOR_PALETTE_50:
       case CFG_SYMBOL_COLOR_PALETTE_51:
       case CFG_SYMBOL_COLOR_PALETTE_52:
       case CFG_SYMBOL_COLOR_PALETTE_53:
       case CFG_SYMBOL_COLOR_PALETTE_54:
       case CFG_SYMBOL_COLOR_PALETTE_55:
       case CFG_SYMBOL_COLOR_PALETTE_56:
       case CFG_SYMBOL_COLOR_PALETTE_57:
       case CFG_SYMBOL_COLOR_PALETTE_58:
       case CFG_SYMBOL_COLOR_PALETTE_59:
       case CFG_SYMBOL_COLOR_PALETTE_60:
       case CFG_SYMBOL_COLOR_PALETTE_61:
       case CFG_SYMBOL_COLOR_PALETTE_62:
       case CFG_SYMBOL_COLOR_PALETTE_63:
           categoryRC = VSRC_COLOR_CATEGORY_SYMBOL_COLORING_PALETTE;
           priority = -800;
           break;
       case CFG_LIVE_ERRORS_ERROR:
       case CFG_LIVE_ERRORS_WARNING:
          categoryRC = VSRC_COLOR_CATEGORY_LIVE_ERRORS;
          priority  = -700;
          break;
       default:
           categoryRC = VSRC_COLOR_CATEGORY_MISC;
           priority = 999;
           break;
       }

       return get_message(categoryRC);
   }

   /**
    * Load a default color profile.
    */
   void loadDefaultColorProfile() {
      m_name = "Default";
      m_colors = null;
      m_embedded = null;

      // editor window syntax element colors
      ColorInfo textColor(0x0, 0xFFFFFF, 0);
      m_colors[CFG_WINDOW_TEXT] = textColor;
      m_colors[CFG_UNKNOWN_ATTRIBUTE] = textColor;
      m_colors[CFG_YAML_ANCHOR_DEF] = textColor;
      m_colors[CFG_YAML_ANCHOR_REF] = textColor;
      m_colors[CFG_YAML_TEXT] = textColor;
      textColor.m_background = 0xD0D0D0;
      m_embedded[CFG_WINDOW_TEXT] = textColor;
      m_embedded[CFG_UNKNOWN_ATTRIBUTE] = textColor;
      m_embedded[CFG_YAML_ANCHOR_DEF] = textColor;
      m_embedded[CFG_YAML_ANCHOR_REF] = textColor;
      m_embedded[CFG_YAML_TEXT] = textColor;

      ColorInfo identifierColor(0x0, 0xFFFFFF, F_INHERIT_BG_COLOR, true);
      m_colors[CFG_IDENTIFIER] = identifierColor; 
      m_colors[CFG_IDENTIFIER2] = identifierColor; 
      m_colors[CFG_CSS_CLASS] = identifierColor; 
      m_colors[CFG_CSS_SELECTOR] = identifierColor; 
      textColor.m_background = 0xD0D0D0;
      m_embedded[CFG_IDENTIFIER] = identifierColor;
      m_embedded[CFG_IDENTIFIER2] = identifierColor;
      m_embedded[CFG_CSS_CLASS] = identifierColor;
      m_embedded[CFG_CSS_SELECTOR] = identifierColor;

      ColorInfo commentColor(0x8000, 0xFFFFFF, F_ITALIC|F_INHERIT_BG_COLOR);
      m_colors[CFG_COMMENT] = commentColor;
      commentColor.m_background = 0xD0D0D0;
      m_embedded[CFG_COMMENT] = commentColor;

      ColorInfo lineCommentColor(0x608000, 0xFFFFFF, F_ITALIC|F_INHERIT_BG_COLOR);
      m_colors[CFG_LINE_COMMENT] = lineCommentColor;
      lineCommentColor.m_background = 0xD0D0D0;
      m_embedded[CFG_LINE_COMMENT] = lineCommentColor;

      ColorInfo docCommentColor(0x008060, 0xFFFFFF, F_ITALIC|F_INHERIT_BG_COLOR);
      m_colors[CFG_DOCUMENTATION] = docCommentColor;
      docCommentColor.m_background = 0xD0D0D0;
      m_embedded[CFG_DOCUMENTATION] = docCommentColor;

      ColorInfo docKeywordColor(0x800080, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_DOC_KEYWORD] = docKeywordColor;
      docKeywordColor.m_background = 0xD0D0D0;
      m_embedded[CFG_DOC_KEYWORD] = docKeywordColor;

      ColorInfo docPunctuationColor(0x0, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_DOC_PUNCTUATION] = docPunctuationColor;
      docPunctuationColor.m_background = 0xD0D0D0;
      m_embedded[CFG_DOC_PUNCTUATION] = docPunctuationColor;

      ColorInfo docAttributeColor(0x800080, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_DOC_ATTRIBUTE] = docAttributeColor;
      docAttributeColor.m_background = 0xD0D0D0;
      m_embedded[CFG_DOC_ATTRIBUTE] = docAttributeColor;

      ColorInfo docStringColor(0x808000, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_DOC_ATTR_VALUE] = docStringColor;
      docStringColor.m_background = 0xD0D0D0;
      m_embedded[CFG_DOC_ATTR_VALUE] = docStringColor;

      ColorInfo inactiveCodeColor(0x808080, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_INACTIVE_CODE] = inactiveCodeColor;
      inactiveCodeColor.m_foreground = 0xD0D0D0;
      m_embedded[CFG_INACTIVE_CODE] = inactiveCodeColor;

      ColorInfo inactiveKeywordColor(0x808080, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_INACTIVE_KEYWORD] = inactiveKeywordColor;
      inactiveKeywordColor.m_foreground = 0xD0D0D0;
      m_embedded[CFG_INACTIVE_KEYWORD] = inactiveKeywordColor;

      ColorInfo inactiveCommentColor(0x808080, 0xFFFFFF, F_ITALIC|F_INHERIT_BG_COLOR);
      m_colors[CFG_INACTIVE_COMMENT] = inactiveCommentColor;
      inactiveCommentColor.m_foreground = 0xD0D0D0;
      m_embedded[CFG_INACTIVE_COMMENT] = inactiveCommentColor;

      ColorInfo keywordColor(0x800080, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_KEYWORD] = keywordColor;
      m_colors[CFG_TAG] = keywordColor;
      m_colors[CFG_CSS_PROPERTY] = keywordColor;
      m_colors[CFG_YAML_TEXT_COLON] = keywordColor;
      keywordColor.m_background = 0xD0D0D0;
      m_embedded[CFG_KEYWORD] = keywordColor;
      m_embedded[CFG_TAG] = keywordColor;
      m_embedded[CFG_CSS_PROPERTY] = keywordColor;
      m_embedded[CFG_YAML_TEXT_COLON] = keywordColor;

      ColorInfo linenumColor(0x0, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_LINENUM] = linenumColor;
      linenumColor.m_background = 0xD0D0D0;
      m_embedded[CFG_LINENUM] = linenumColor;

      ColorInfo numberColor(0x808000, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_NUMBER] = numberColor;
      m_colors[CFG_HEX_NUMBER] = numberColor;
      m_colors[CFG_FLOATING_NUMBER] = numberColor;
      numberColor.m_background = 0xD0D0D0;
      m_embedded[CFG_NUMBER] = numberColor;
      m_embedded[CFG_HEX_NUMBER] = numberColor;
      m_embedded[CFG_FLOATING_NUMBER] = numberColor;

      ColorInfo ppColor(0x8080, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_PPKEYWORD] = ppColor;
      m_colors[CFG_YAML_DIRECTIVE] = ppColor;
      ppColor.m_background = 0xD0D0D0;
      m_embedded[CFG_PPKEYWORD] = ppColor;
      m_embedded[CFG_YAML_DIRECTIVE] = ppColor;

      ColorInfo stringColor(0x808000, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_STRING] = stringColor;
      m_colors[CFG_SINGLEQUOTED_STRING] = stringColor;
      m_colors[CFG_BACKQUOTED_STRING] = stringColor;
      m_colors[CFG_UNTERMINATED_STRING] = stringColor;
      stringColor.m_background = 0xD0D0D0;
      m_embedded[CFG_STRING] = stringColor;
      m_embedded[CFG_SINGLEQUOTED_STRING] = stringColor;
      m_embedded[CFG_BACKQUOTED_STRING] = stringColor;
      m_embedded[CFG_UNTERMINATED_STRING] = stringColor;

      ColorInfo punctuationColor(0x0, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_PUNCTUATION] = punctuationColor;
      m_colors[CFG_YAML_PUNCTUATION] = punctuationColor;
      punctuationColor.m_background = 0xD0D0D0;
      m_embedded[CFG_PUNCTUATION] = punctuationColor;
      m_embedded[CFG_YAML_PUNCTUATION] = punctuationColor;

      m_colors[CFG_MARKDOWN_BULLET] = punctuationColor;
      punctuationColor.m_background = 0xD0D0D0;
      m_embedded[CFG_MARKDOWN_BULLET] = punctuationColor;

      ColorInfo libraryColor(0x0, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_LIBRARY_SYMBOL] = libraryColor;
      m_colors[CFG_MARKDOWN_EMPHASIS] = libraryColor;
      m_colors[CFG_MARKDOWN_EMPHASIS2] = libraryColor;
      m_colors[CFG_MARKDOWN_EMPHASIS3] = libraryColor;
      m_colors[CFG_MARKDOWN_EMPHASIS4] = libraryColor;
      m_colors[CFG_YAML_TAG] = libraryColor;
      libraryColor.m_background = 0xD0D0D0;
      m_embedded[CFG_LIBRARY_SYMBOL] = libraryColor;
      m_embedded[CFG_MARKDOWN_EMPHASIS] = libraryColor;
      m_embedded[CFG_MARKDOWN_EMPHASIS2] = libraryColor;
      m_embedded[CFG_MARKDOWN_EMPHASIS3] = libraryColor;
      m_embedded[CFG_MARKDOWN_EMPHASIS4] = libraryColor;
      m_embedded[CFG_YAML_TAG] = libraryColor;

      ColorInfo operatorColor(0x0, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_OPERATOR] = operatorColor;
      m_colors[CFG_YAML_OPERATOR] = operatorColor;
      operatorColor.m_background = 0xD0D0D0;
      m_embedded[CFG_OPERATOR] = operatorColor;
      m_embedded[CFG_YAML_OPERATOR] = operatorColor;

      ColorInfo userDefinedColor(0x0, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_USER_DEFINED] = userDefinedColor;
      userDefinedColor.m_background = 0xD0D0D0;
      m_embedded[CFG_USER_DEFINED] = userDefinedColor;

      ColorInfo functionColor(0x0, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_FUNCTION] = functionColor;
      m_colors[CFG_CSS_ELEMENT] = functionColor;
      functionColor.m_background = 0xD0D0D0;
      m_embedded[CFG_FUNCTION] = functionColor;

      // special characters
      ColorInfo specialCharsColor(0xC0C0C0, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_SPECIALCHARS] = specialCharsColor;
      specialCharsColor.m_background = 0xD0D0D0;
      m_embedded[CFG_SPECIALCHARS] = specialCharsColor;

      ColorInfo hexColor(0x80, 0xF0F0F0, F_BOLD);
      m_colors[CFG_HEX_MODE_COLOR] = hexColor;
      m_embedded[CFG_HEX_MODE_COLOR] = hexColor;

      // XML and HTML tags and attributes
      ColorInfo attributeColor(0x800080, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_ATTRIBUTE] = attributeColor;
      attributeColor.m_background = 0xD0D0D0;
      m_embedded[CFG_ATTRIBUTE] = attributeColor;

      ColorInfo unknownXMLElementColor(0x0080FF, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_UNKNOWN_TAG] = unknownXMLElementColor;
      unknownXMLElementColor.m_background = 0xD0D0D0;
      m_embedded[CFG_UNKNOWN_TAG] = unknownXMLElementColor;

      ColorInfo XHTMLElementInXSLColor(0x8080, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_XHTMLELEMENTINXSL] = XHTMLElementInXSLColor;
      XHTMLElementInXSLColor.m_background = 0xD0D0D0;
      m_embedded[CFG_XHTMLELEMENTINXSL] = XHTMLElementInXSLColor;

      // current line and selection colors
      ColorInfo cursorColor(0xC0C0C0, 0x0, 0);
      m_colors[CFG_CURSOR] = cursorColor;
      m_embedded[CFG_CURSOR] = cursorColor;

      ColorInfo currentLineColor(0xFF0000, 0xFFFFFF, 0);
      m_colors[CFG_CLINE] = currentLineColor;
      currentLineColor.m_background = 0xD0D0D0;
      m_embedded[CFG_CLINE] = currentLineColor;

      ColorInfo insertedLineColor(0xFFFFFF, 0x80, 0);
      m_colors[CFG_INSERTED_LINE] = insertedLineColor;
      m_embedded[CFG_INSERTED_LINE] = insertedLineColor;

      ColorInfo errorColor(0xFFFFFF, 0xFF, 0);
      m_colors[CFG_ERROR] = errorColor;
      m_embedded[CFG_ERROR] = errorColor;

      ColorInfo modifiedLineColor(0xFFFFFF, 0xFF, 0);
      m_colors[CFG_MODIFIED_LINE] = modifiedLineColor;
      m_embedded[CFG_MODIFIED_LINE] = modifiedLineColor;

      ColorInfo noSaveLineColor(0xFFFFFF, 0x80, 0);
      m_colors[CFG_NOSAVE_LINE] = noSaveLineColor;
      m_embedded[CFG_NOSAVE_LINE] = noSaveLineColor;

      ColorInfo imaginarySpaceColor(0xFFFFFF, 0x8000, 0);
      m_colors[CFG_IMAGINARY_SPACE] = imaginarySpaceColor;
      m_embedded[CFG_IMAGINARY_SPACE] = imaginarySpaceColor;

      ColorInfo selectedCurrentLineColor(0xFF0000, 0xC0C0C0, 0);
      m_colors[CFG_SELECTED_CLINE] = selectedCurrentLineColor;
      selectedCurrentLineColor.m_background = 0xFFD0D0;
      m_embedded[CFG_SELECTED_CLINE] = selectedCurrentLineColor;

      ColorInfo selectionColor(0xFF0000, 0xFFFFFF, 0);
      m_colors[CFG_SELECTION] = selectionColor;
      selectionColor.m_background = 0xFFD0D0;
      m_embedded[CFG_SELECTION] = selectionColor;

      // filenames on MDI icons
      ColorInfo filenameColor(0x8000000, 0xC0C0C0, 0);
      m_colors[CFG_FILENAME] = filenameColor;
      m_embedded[CFG_FILENAME] = filenameColor;

      ColorInfo highlightColor(0xFFFFFF, 0xFF0000, 0);
      m_colors[CFG_HILIGHT] = highlightColor;
      m_embedded[CFG_HILIGHT] = highlightColor;

      ColorInfo blockMatchingColor(0xFFFFFF, 0xFF0000, 0);
      m_colors[CFG_BLOCK_MATCHING] = blockMatchingColor;
      m_embedded[CFG_BLOCK_MATCHING] = blockMatchingColor;

      ColorInfo incrementalSearchCurrentColor(0x0, 0x0ffff80, F_INHERIT_STYLE);
      m_colors[CFG_INC_SEARCH_CURRENT] = incrementalSearchCurrentColor;
      m_embedded[CFG_INC_SEARCH_CURRENT] = incrementalSearchCurrentColor;

      ColorInfo incrementalSearchMatchColor(0x0, 0x080ffff, F_INHERIT_STYLE);
      m_colors[CFG_INC_SEARCH_MATCH] = incrementalSearchMatchColor;
      m_embedded[CFG_INC_SEARCH_MATCH] = incrementalSearchMatchColor;

      ColorInfo symbolHighlightColor(0x0, 0x080ffff, 0);
      m_colors[CFG_SYMBOL_HIGHLIGHT] = symbolHighlightColor;
      m_embedded[CFG_SYMBOL_HIGHLIGHT] = symbolHighlightColor;

      // message bar and status bar
      ColorInfo messageColor((int)VSDEFAULT_FOREGROUND_COLOR,
                             (int)VSDEFAULT_BACKGROUND_COLOR, 0);
      m_colors[CFG_MESSAGE] = messageColor;
      m_embedded[CFG_MESSAGE] = messageColor;

      ColorInfo statusColor((int)VSDEFAULT_FOREGROUND_COLOR,
                            (int)VSDEFAULT_BACKGROUND_COLOR, 0);
      m_colors[CFG_STATUS] = messageColor;
      m_embedded[CFG_STATUS] = messageColor;

      // current line box, vertical lines, prefix area
      ColorInfo currentLineBoxColor(0xFF8080, 0xFF8080, 0);
      m_colors[CFG_CURRENT_LINE_BOX] = currentLineBoxColor;
      m_embedded[CFG_CURRENT_LINE_BOX] = currentLineBoxColor;

      ColorInfo gutterColor(0x800080, 0xFFF0F0, 0);
      m_colors[CFG_LINEPREFIXAREA] = gutterColor;
      m_embedded[CFG_LINEPREFIXAREA] = gutterColor;

      ColorInfo gutterLineColor(0x808080, 0x808080, 0);
      m_colors[CFG_PREFIX_AREA_LINE] = gutterLineColor;
      m_embedded[CFG_PREFIX_AREA_LINE] = gutterLineColor;

      ColorInfo verticalColumnLineColor(0x8080FF, 0x8080FF, 0);
      m_colors[CFG_VERTICAL_COL_LINE] = verticalColumnLineColor;
      m_embedded[CFG_VERTICAL_COL_LINE] = verticalColumnLineColor;

      ColorInfo marginColumnsLineColor(0x808080, 0x808080, 0);
      m_colors[CFG_MARGINS_COL_LINE] = marginColumnsLineColor;
      m_embedded[CFG_MARGINS_COL_LINE] = marginColumnsLineColor;

      ColorInfo truncationColumnLineColor(0x0000FF, 0x0000FF, 0);
      m_colors[CFG_TRUNCATION_COL_LINE] = truncationColumnLineColor;
      m_embedded[CFG_TRUNCATION_COL_LINE] = truncationColumnLineColor;

       // modified item in a debugger window
      ColorInfo modifiedItemColor(0xFF, 0xFFFFFF, 0);
      m_colors[CFG_MODIFIED_ITEM] = modifiedItemColor;
      m_embedded[CFG_MODIFIED_ITEM] = modifiedItemColor;

      ColorInfo navHintColor(0x0, 0xFF8000, F_INHERIT_BG_COLOR);
      m_colors[CFG_NAVHINT] = navHintColor;
      m_embedded[CFG_NAVHINT] = navHintColor;

      ColorInfo leErrorColor(0xff, 0);
      m_colors[CFG_LIVE_ERRORS_ERROR] = leErrorColor;
      m_embedded[CFG_LIVE_ERRORS_ERROR] = leErrorColor;

      ColorInfo leWarningColor(0xe1e100, 0);
      m_colors[CFG_LIVE_ERRORS_WARNING] = leWarningColor;
      m_embedded[CFG_LIVE_ERRORS_WARNING] = leWarningColor;

      ColorInfo xmlCharColor(0x808000, 0xFFFFFF, F_INHERIT_BG_COLOR);
      m_colors[CFG_XML_CHARACTER_REF] = numberColor;
      numberColor.m_background = 0xD0D0D0;
      m_embedded[CFG_XML_CHARACTER_REF] = numberColor;

      ColorInfo searchTruncColor(0xC0C0C0, 0xFFFFFF, 0);
      m_colors[CFG_SEARCH_RESULT_TRUNCATED] = searchTruncColor;
      searchTruncColor.m_background = 0xD0D0D0;
      m_embedded[CFG_SEARCH_RESULT_TRUNCATED] = searchTruncColor;

      ColorInfo markdownHeader(0x800080, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_MARKDOWN_HEADER] = markdownHeader;
      markdownHeader.m_background = 0xD0D0D0;
      m_embedded[CFG_MARKDOWN_HEADER] = markdownHeader;

      ColorInfo markdownCode(0x808000, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_MARKDOWN_CODE] = markdownCode;
      markdownCode.m_background = 0xD0D0D0;
      m_embedded[CFG_MARKDOWN_CODE] = markdownCode;

      ColorInfo markdownBlockQuote(0x40C0, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_MARKDOWN_BLOCKQUOTE] = markdownBlockQuote;
      markdownBlockQuote.m_background = 0xD0D0D0;
      m_embedded[CFG_MARKDOWN_BLOCKQUOTE] = markdownBlockQuote;

      ColorInfo markdownLink(0x800000, 0xFFFFFF, F_BOLD|F_INHERIT_BG_COLOR);
      m_colors[CFG_MARKDOWN_LINK] = markdownLink;
      m_colors[CFG_MARKDOWN_LINK2] = markdownLink;
      markdownLink.m_background = 0xD0D0D0;
      m_embedded[CFG_MARKDOWN_LINK] = markdownLink;
      m_embedded[CFG_MARKDOWN_LINK2] = markdownLink;

      // message bar, status bar, document tabs
      ColorInfo documentTabActiveColor((int)VSDEFAULT_FOREGROUND_COLOR,
                                       (int)VSDEFAULT_BACKGROUND_COLOR, 0);
      m_colors[CFG_DOCUMENT_TAB_ACTIVE] = documentTabActiveColor;
      m_embedded[CFG_DOCUMENT_TAB_ACTIVE] = documentTabActiveColor;

      ColorInfo documentTabModifiedColor(0xff, 0xffffff, 0);
      m_colors[CFG_DOCUMENT_TAB_MODIFIED] = documentTabModifiedColor;
      m_embedded[CFG_DOCUMENT_TAB_MODIFIED] = documentTabModifiedColor;

      ColorInfo documentTabSelectedColor((int)VSDEFAULT_FOREGROUND_COLOR,
                                         (int)VSDEFAULT_BACKGROUND_COLOR, 0);
      m_colors[CFG_DOCUMENT_TAB_SELECTED] = documentTabSelectedColor;
      m_embedded[CFG_DOCUMENT_TAB_SELECTED] = documentTabSelectedColor;

      ColorInfo documentTabUnselectedColor((int)VSDEFAULT_FOREGROUND_COLOR,
                                           (int)VSDEFAULT_BACKGROUND_COLOR, 0);
      m_colors[CFG_DOCUMENT_TAB_UNSELECTED] = documentTabUnselectedColor;
      m_embedded[CFG_DOCUMENT_TAB_UNSELECTED] = documentTabUnselectedColor;

      ColorInfo seldispColumnsLineColor(0xB0C0B0, 0xB0C0B0, 0);
      m_colors[CFG_SELECTIVE_DISPLAY_LINE] = seldispColumnsLineColor;
      m_embedded[CFG_SELECTIVE_DISPLAY_LINE] = seldispColumnsLineColor;

      ColorInfo refHighlightColor0(0xFFFFFF, 0xFF0000, F_INHERIT_BG_COLOR, CFG_HILIGHT);
      m_colors[CFG_REF_HIGHLIGHT_0] = refHighlightColor0;
      m_embedded[CFG_REF_HIGHLIGHT_0] = refHighlightColor0;
      ColorInfo refHighlightColor1(0xFFFFC0, 0xFF0000, F_INHERIT_BG_COLOR, CFG_HILIGHT);
      m_colors[CFG_REF_HIGHLIGHT_1] = refHighlightColor1;
      m_embedded[CFG_REF_HIGHLIGHT_1] = refHighlightColor1;
      ColorInfo refHighlightColor2(0xFFC0FF, 0xFF0000, F_INHERIT_BG_COLOR, CFG_HILIGHT);
      m_colors[CFG_REF_HIGHLIGHT_2] = refHighlightColor2;
      m_embedded[CFG_REF_HIGHLIGHT_2] = refHighlightColor2;
      ColorInfo refHighlightColor3(0xFFC0C0, 0xFF0000, F_INHERIT_BG_COLOR, CFG_HILIGHT);
      m_colors[CFG_REF_HIGHLIGHT_3] = refHighlightColor3;
      m_embedded[CFG_REF_HIGHLIGHT_3] = refHighlightColor3;
      ColorInfo refHighlightColor4(0xC0FFFF, 0xFF0000, F_INHERIT_BG_COLOR, CFG_HILIGHT);
      m_colors[CFG_REF_HIGHLIGHT_4] = refHighlightColor4;
      m_embedded[CFG_REF_HIGHLIGHT_4] = refHighlightColor4;
      ColorInfo refHighlightColor5(0xC0FFC0, 0xFF0000, F_INHERIT_BG_COLOR, CFG_HILIGHT);
      m_colors[CFG_REF_HIGHLIGHT_5] = refHighlightColor5;
      m_embedded[CFG_REF_HIGHLIGHT_5] = refHighlightColor5;
      ColorInfo refHighlightColor6(0xC0C0FF, 0xFF0000, F_INHERIT_BG_COLOR, CFG_HILIGHT);
      m_colors[CFG_REF_HIGHLIGHT_6] = refHighlightColor6;
      m_embedded[CFG_REF_HIGHLIGHT_6] = refHighlightColor6;
      ColorInfo refHighlightColor7(0xC0C0C0, 0xFF0000, F_INHERIT_BG_COLOR, CFG_HILIGHT);
      m_colors[CFG_REF_HIGHLIGHT_7] = refHighlightColor7;
      m_embedded[CFG_REF_HIGHLIGHT_7] = refHighlightColor7;

      for (i:=0; i<m_colors._length(); i++) {
         m_definedColors[i] = (m_colors[i] != null || m_embedded != null);
      }
   }
   static _str realProfileName(_str profileName) {
      if (strieq(profileName, CONFIG_AUTOMATIC)) {
         return _GetColorProfileForOS();
      }
      return profileName;
   }
   static _str realProfileNameWithPrefix(_str profileName) {
      realProfileName := removeProfilePrefix(profileName);
      realProfileName = realProfileName(realProfileName);
      realProfileName = addProfilePrefix(realProfileName);
      return realProfileName;
   }

   /**
    * Load the user's current color profile.
    */
   void loadCurrentColorProfile() {
      m_name = def_color_scheme;
      m_colors = null;
      m_embedded = null;
      m_symbolColoringProfile = "";
      m_inheritsProfile = "";
      for (cfg:=1; cfg<=CFG_LAST_DEFAULT_COLOR; cfg++) {
         // make sure this is a valid / interesting color
         if (getColorNameRC(cfg) == 0) {
            m_colors[cfg] = null;
            m_embedded[cfg] = null;
            continue;
         }
         // get standard colors
         ColorInfo c;
         c.getColor(cfg);
         m_colors[cfg] = c;
         // also get embedded colors
         if (!isEmbeddedColor(cfg)) {
            m_embedded[cfg] = null;
            continue;
         }
         ColorInfo e;
         e.getColor(-cfg);
         e.m_fontFlags = c.m_fontFlags;
         m_embedded[cfg] = e;
      }

      associated_symbol_profile := _plugin_get_property(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(m_name),'associated_symbol_profile');
      if (associated_symbol_profile != "") {
         m_symbolColoringProfile = associated_symbol_profile;
      }
      inherits_profile := _plugin_get_property(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(m_name),'inherit');
      if (inherits_profile != "") {
         m_inheritsProfile = inherits_profile;
      } else if (!_plugin_has_builtin_profile(VSCFGPACKAGE_COLOR_PROFILES, m_name)) {
         if (isDarkColorProfile(m_name)) {
            dark_profile := _plugin_get_property(VSCFGPACKAGE_MISC, 'color_profile_for_theme', 'Dark');
            if (dark_profile == "") dark_profile = "Slate";
            m_inheritsProfile = dark_profile;
         } else {
            m_inheritsProfile = "Default";
         }
      }
   }

   void saveProfile() {
      handle:=_xmlcfg_create_profile(auto profile_node,VSCFGPACKAGE_COLOR_PROFILES,realProfileName(m_name),VSCFGPROFILE_COLOR_VERSION);
      if (m_symbolColoringProfile != null && m_symbolColoringProfile != "" && m_symbolColoringProfile != CONFIG_AUTOMATIC) {
         property_node:=_xmlcfg_add_property(handle,profile_node,'associated_symbol_profile',m_symbolColoringProfile);
      }

      // load inherited color scheme
      ColorScheme origProfileName;
      ColorScheme parentProfileName;
      if (m_inheritsProfile != null && m_inheritsProfile != "") {
         // Need to load 
         window_text := m_colors[CFG_WINDOW_TEXT];
         origProfileName.loadProfile(m_name, /*ignore user customizations*/1, recursiveDepth:MAXINT);
         parentProfileName.loadProfile(m_inheritsProfile, 
                                       /*ignore user customizations*/1, null,
                                       window_text.getForegroundColor(&this),
                                       window_text.getBackgroundColor(&this),
                                       window_text.getFontFlags(&this),
                                       getEmbeddedBackgroundColor(CFG_WINDOW_TEXT));
         if (_plugin_has_builtin_profile(VSCFGPACKAGE_COLOR_PROFILES,m_inheritsProfile)) {
            _xmlcfg_add_property(handle,profile_node,'inherit',m_inheritsProfile);
         }
      }

      for (i:=1; i <= CFG_LAST_DEFAULT_COLOR; i++) {
         if (i >= m_colors._length()) break;
         if (m_colors[i] == null) continue;
         cname := getColorConstantName(i);
         if (cname==null) continue;
         name := lowcase(substr(cname,5));

         // skip generating properties for inherited colors that have not changed
         // but always generate colors for items defined in the original color scheme
         if (m_inheritsProfile != null && m_inheritsProfile != "" && !origProfileName.isColorDefinedInProfile(i)) {
            if (parentProfileName.isColorDefinedInProfile(i) && m_colors[i] == parentProfileName.m_colors[i]) {
               continue;
            }
         }

         property_node:=_xmlcfg_add_property(handle,profile_node,name);
         attrs_node:=property_node;
         ColorInfo c=m_colors[i];
         if (isinteger(c.m_foreground)) {
            _xmlcfg_set_attribute(handle,attrs_node,"fg",ColorInfo.formatHTMLHexColor(0x0000000FFFFFFFF & c.getForegroundColor(&this)));
            if (!(c.getFontFlags(&this) & F_INHERIT_BG_COLOR) || name == "window_text") {
               _xmlcfg_set_attribute(handle,attrs_node,"bg",ColorInfo.formatHTMLHexColor(0x0000000FFFFFFFF & c.getBackgroundColor(&this)));
            }
            _xmlcfg_set_attribute(handle,attrs_node,"flags","0x":+_dec2hex(c.getFontFlags(&this)));
            if (!(c.getFontFlags(&this) & F_INHERIT_BG_COLOR) || name == "window_text") {
               if (i <m_embedded._length() && m_embedded[i]!=null && isEmbeddedColor(i) /*&& m_embedded[i]!=defaultEmbedded*/) {
                  _xmlcfg_set_attribute(handle,attrs_node,"embg", ColorInfo.formatHTMLHexColor(0x0000000FFFFFFFF & getEmbeddedBackgroundColor(i)));
               }
            }
         }
      }
      _plugin_set_profile(handle);
      _xmlcfg_close(handle);
   }

   /**
    * Apply this color scheme as the current color scheme.
    */
   void applyColorProfile(_str defaultColorSchemeName="") {

      // if this is the same as the default color scheme, save it to both places
      setDefaultColors := (m_name == ColorScheme.realProfileName(def_color_scheme));

      // save all the colors
      for (i:=1; i <= CFG_LAST_DEFAULT_COLOR; i++) {
         if (i >= m_colors._length()) break;
         if (m_colors[i] == null) continue;
         if (getColorConstantName(i) == null) continue;
         if (m_name != "") {
            m_colors[i].setColor(i, &this, m_name);
         }
         if (setDefaultColors) {
            m_colors[i].setColor(i, &this);
         }
         if (i == CFG_NAVHINT) {
            navcolor := m_colors[i].getForegroundColor();
            NavMarker.updateMarkerColor(navcolor);
         } else if (i == CFG_LIVE_ERRORS_ERROR) {
            rte_update_error_colors(m_colors[i].getForegroundColor());
         } else if (i == CFG_LIVE_ERRORS_WARNING) {
            rte_update_warning_colors(m_colors[i].getForegroundColor());
         }
      }
      for (i=1; i <= CFG_LAST_DEFAULT_COLOR; i++) {
         if (i >= m_embedded._length()) break;
         if (m_embedded[i] == null) continue;
         if (!isEmbeddedColor(i)) continue;
         embeddedColor := m_embedded[i];
         embeddedColor.m_foreground = m_colors[i].getForegroundColor();
         embeddedColor.m_background = getEmbeddedBackgroundColor(i);
         embeddedColor.m_fontFlags &= ~F_INHERIT_BG_COLOR;
         if (m_name != "") {
            embeddedColor.setColor(-i, &this, m_name);
         }
         if (setDefaultColors) {
            embeddedColor.setColor(-i, &this);
         }
      }
      if (defaultColorSchemeName != "" && def_color_scheme!=defaultColorSchemeName) {
         def_color_scheme = defaultColorSchemeName;
         _config_modify_flags(CFGMODIFY_DEFVAR);
         // if they change this, then reset all-languages
         _LangSetProperty(VSCFGPROFILE_ALL_LANGUAGES,VSLANGPROPNAME_COLOR_PROFILE,"");
         _LangSetProperty(VSCFGPROFILE_ALL_LANGUAGES,VSLANGPROPNAME_ALT_COLOR_PROFILE,"");
         // no update the buffer color profiles for all windows using the global default
         _change_all_window_colors(langId:null, defaultColorSchemeName, update_editor_colors:true, update_minimap_colors:false);
      }
   }

   /**
    * Apply this color scheme as the current minimap color scheme.
    * "colorProfileName" is the name of the actual profile name to 
    * be applied, and must be a valid profile name, not a sentinel 
    * like "".  If "followEditorProfile" is true, then "" will be 
    * stored in def_minimap_color_scheme as the sentinel for 
    * following the editor profile.  Otherwise, colorProfileName 
    * will be used. 
    */
   void applyMinimapColorProfile(_str colorProfileName, bool followEditorProfile) {
      /*
      if (colorProfileName != "") {
         for (i:=1; i <= CFG_LAST_DEFAULT_COLOR; i++) {
            if (i >= m_colors._length()) break;
            if (m_colors[i] == null) continue;
            if (getColorConstantName(i) == null) continue;
            m_colors[i].setColor(i, &this, colorProfileName);
         }
         for (i=1; i <= CFG_LAST_DEFAULT_COLOR; i++) {
            if (i >= m_embedded._length()) break;
            if (m_embedded[i] == null) continue;
            if (!isEmbeddedColor(i)) continue;
            embeddedColor := m_embedded[i];
            embeddedColor.m_foreground = m_colors[i].getForegroundColor();
            embeddedColor.m_background = getEmbeddedBackgroundColor(i);
            embeddedColor.m_fontFlags &= ~F_INHERIT_BG_COLOR;
            embeddedColor.setColor(-i, &this, colorProfileName);
         }
      }
      */
      defName := colorProfileName;
      if (followEditorProfile) {
         defName = '';
      }
      if (def_minimap_color_scheme != defName) {
         // if they change this, then reset all-languages
         _LangSetProperty(VSCFGPROFILE_ALL_LANGUAGES,VSLANGPROPNAME_MINIMAP_COLOR_PROFILE,"");
         _LangSetProperty(VSCFGPROFILE_ALL_LANGUAGES,VSLANGPROPNAME_ALT_MINIMAP_COLOR_PROFILE,"");
         // then update all window colors and the def-var
         _change_all_window_colors(langId:null, colorProfileName, update_editor_colors:false, update_minimap_colors:true);
         if (followEditorProfile) {
            def_minimap_color_scheme = '';
         } else {
            def_minimap_color_scheme = colorProfileName;
         }
        _config_modify_flags(CFGMODIFY_DEFVAR);
      }
   }

   /**
    * Apply this color scheme using the given color scheme name.
    */
   void applyColorProfileAs(_str colorProfileName) {
      for (i:=1; i <= CFG_LAST_DEFAULT_COLOR; i++) {
         if (i >= m_colors._length()) break;
         if (m_colors[i] == null) continue;
         if (getColorConstantName(i) == null) continue;
         m_colors[i].setColor(i, &this, colorProfileName);
      }
      for (i=1; i <= CFG_LAST_DEFAULT_COLOR; i++) {
         if (i >= m_embedded._length()) break;
         if (m_embedded[i] == null) continue;
         if (!isEmbeddedColor(i)) continue;
         embeddedColor := m_embedded[i];
         embeddedColor.m_foreground = m_colors[i].getForegroundColor();
         embeddedColor.m_background = getEmbeddedBackgroundColor(i);
         embeddedColor.m_fontFlags &= ~F_INHERIT_BG_COLOR;
         embeddedColor.setColor(-i, &this, colorProfileName);
      }
   }
   static bool isDarkWindowTextColor(int windowTextBgColor)
   {
      value := _dec2hex(windowTextBgColor,16,6);
      typeless bg_r=strip(substr(value,1,2));
      typeless bg_g=strip(substr(value,3,2));
      typeless bg_b=strip(substr(value,5,2));
      bg_r=_hex2dec(bg_r,16);
      bg_g=_hex2dec(bg_g,16);
      bg_b=_hex2dec(bg_b,16);
      if (!isinteger(bg_r)) bg_r=0;
      if (!isinteger(bg_g)) bg_g=0;
      if (!isinteger(bg_b)) bg_b=0;
      return (bg_r<90 && bg_g<90 && bg_b<90);
   }

   static bool isDarkColorProfile(_str name, int depth=0) {
      handle:=_plugin_get_property_xml(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(name),'window_text');
      if (handle<0 && depth<32) {
         handle = _plugin_get_property_xml(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(name),'inherit');
         if (handle < 0) {
            return false;
         }
         parentProfileName := _xmlcfg_get_attribute(handle,_xmlcfg_get_document_element(handle),'v');
         if (parentProfileName == "") {
            return false;
         }
         return isDarkColorProfile(parentProfileName, depth+1);
      }
      if (handle<0) {
         return false;
      }
      value:=_xmlcfg_get_attribute(handle,_xmlcfg_get_document_element(handle),'bg');
      // IF the background color was specified in decimal (odd but possible)
      value = ColorInfo.parseColorValue(value);
      result := isDarkWindowTextColor(value);
      _xmlcfg_close(handle);
      return result;
   }

   // Looks at the currently loaded color values, which may differ from the saved 
   // profile if this scheme is being edited, and determines whether it is a dark profile.
   bool isDarkColorProfileLoaded()
   {
      color := getColor(CFG_WINDOW_TEXT);
      if (color) {
         return isDarkWindowTextColor(color->getBackgroundColor());
      } else {
         return false;
      }
   }

   static bool hasSymbolColoringRulesDefined(_str name) {
      handle:=_plugin_get_property_xml(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(name),'symbol_color_parameter');
      if (handle<0) {
         return false;
      }
      handle=_plugin_get_property_xml(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(name),'symbol_color_database_table');
      if (handle<0) {
         return false;
      }
      handle=_plugin_get_property_xml(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(name),'symbol_color_palatte_00');
      if (handle<0) {
         return false;
      }
      handle=_plugin_get_property_xml(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(name),'symbol_color_palatte_63');
      if (handle<0) {
         return false;
      }
      return true;
   }

   /**
    * Apply the associated symbol coloring scheme for this color scheme.
    */
   void applySymbolColorProfile() {
      if (def_symbol_color_profile != "" && 
          def_symbol_color_profile != CONFIG_AUTOMATIC && 
          def_symbol_color_profile != m_symbolColoringProfile) {
         def_symbol_color_profile = m_symbolColoringProfile;
         _config_modify_flags(CFGMODIFY_DEFVAR);
      }
      SymbolColorAnalyzer.initAllSymbolAnalyzers();
   }

   /**
    * Insert the Slick-C code required for recording their color changes.
    */
   void insertMacroCode(bool macroRecording) {
      // make sure we are recording
      if (macroRecording) {
         _macro('m',_macro('s'));
      }

      // first add the macro code for normal colors
      for (i:=1; i<= CFG_LAST_DEFAULT_COLOR; i++) {
         if (i >= m_colors._length()) break;
         if (m_colors[i] == null) continue;
         cfgName := getColorConstantName(i);
         if (cfgName == null) continue;
         m_colors[i].insertMacroCode(cfgName, macroRecording);
      }

      // now add the code for select embedded colors
      for (i=1; i<= CFG_LAST_DEFAULT_COLOR; i++) {
         if (i >= m_embedded._length()) break;
         if (m_embedded[i] == null) continue;
         if (!isEmbeddedColor(i)) continue;
         cfgName := getColorConstantName(i);
         if (cfgName == null) continue;
         embeddedColor := m_embedded[i];
         embeddedColor.m_background = getEmbeddedBackgroundColor(i);
         embeddedColor.insertMacroCode("-":+cfgName, macroRecording);
      }

      if (m_name != "") {
         if (macroRecording) {
            _macro_append("def_color_scheme = "_dquote(m_name)";");
         } else {
            insert_line("  def_color_scheme = "_dquote(m_name)";");
         }
      }
   }
   static _str getDefaultProfile() {
      parse def_color_scheme with auto currentScheme '(modified)';
      if (currentScheme == '') currentScheme = def_color_scheme;
      currentScheme = strip(currentScheme);
      if (_plugin_has_profile(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(currentScheme))) {
         return currentScheme;
      }
      return 'Default';
   }
   static _str getMinimapProfile(bool allowEmpty=false) {
      parse def_minimap_color_scheme with auto currentScheme '(modified)';
      if (currentScheme == '') currentScheme = def_minimap_color_scheme;
      currentScheme = strip(currentScheme);
      if (currentScheme == "") {
         if (allowEmpty) return "";
         return getDefaultProfile();
      }
      if (_plugin_has_profile(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(currentScheme))) {
         return currentScheme;
      }
      return 'Default';
   }
   /**
    * Insert the Slick-C code required for recording their color 
    * changes.  followEditorProfile should be set to true for the 
    * case where the user has chosen to have the minimap color 
    * follow the editor color profile setting. 
    */
   void insertMinimapMacroCode(bool macroRecording, bool followEditorProfile) {
      // make sure we are recording
      if (macroRecording) {
         _macro('m',_macro('s'));
      }
      profName := m_name;
      if (followEditorProfile) {
         profName = '';
      }
      if (m_name != "") {
         if (macroRecording) {
            _macro_append("def_minimap_color_scheme = "_dquote(profName)";");
         } else {
            insert_line("  def_minimap_color_scheme = "_dquote(profName)";");
         }
      }
   }

   /**
    * Load the given color scheme from the INI file.
    * 
    * @param profileName         Name of color scheme to find and load
    * @param optionLevel         optionLevel=0 specifies the user level 
    *                            settings. There may be project and
    *                            workspace levels in the future.
    * @param defined_minimap_divider  (optional), only used internally
    * @param window_text_fg      (optional), only used internally when loading inherited color scheme
    * @param window_text_bg      (optional), only used internally when loading inherited color scheme
    * @param window_text_flags   (optional), only used internally when loading inherited color scheme
    * @param window_text_embg    (optional), only used internally when loading inherited color scheme
    * @param recursiveDepth      (optional), only used internally
    * 
    * @return 0 on success, &lt;0 on error.
    */
   int loadProfile(_str profileName,int optionLevel=0,
                   bool *pdefined_minimap_divider=null,
                   int window_text_fg=0,int window_text_bg=0,
                   int window_text_flags=0,int window_text_embg=0,
                   int recursiveDepth=0) 
   {
      handle:=_plugin_get_profile(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(profileName),optionLevel);
      if (handle<0) {
         return handle;
      }

      // need window text color for inheriting colors
      profile_node:=_xmlcfg_set_path(handle,"/profile");
      if (!window_text_fg && !window_text_bg) {
         window_text_node := _xmlcfg_find_property(handle, profile_node, "window_text");
         if (window_text_node > 0) {
            value := _xmlcfg_get_attribute(handle,window_text_node,'bg');
            if (value!='') window_text_bg = ColorInfo.parseColorValue(value);
            value = _xmlcfg_get_attribute(handle,window_text_node,'fg');
            if (value!='') window_text_fg = ColorInfo.parseColorValue(value);
            value = _xmlcfg_get_attribute(handle,window_text_node,'flags');
            if (value!='') window_text_flags = _hex2dec(value);
            value=_xmlcfg_get_attribute(handle,window_text_node,'embg');
            if (value!='') window_text_embg = ColorInfo.parseColorValue(value);
         }
      }

      // initialize the entire color list
      bool defined_minimap_divider=false;
      if (pdefined_minimap_divider == null) {
         pdefined_minimap_divider = &defined_minimap_divider;
      }
      m_colors = null;
      m_embedded = null;
      m_symbolColoringProfile = "";
      m_inheritsProfile = "";

      // check for color scheme inheritance
      inherits_node := _xmlcfg_find_property(handle, profile_node, "inherit");
      if (recursiveDepth < 8) {
         parentProfileName := "";
         if (inherits_node >= 0) {
            parentProfileName = _xmlcfg_get_attribute(handle,inherits_node,'v');
         }
         if (!_plugin_has_builtin_profile(VSCFGPACKAGE_COLOR_PROFILES, profileName)) {
            if (isDarkColorProfile(profileName, recursiveDepth+1)) {
               dark_profile := _plugin_get_property(VSCFGPACKAGE_MISC, 'color_profile_for_theme', 'Dark');
               if (dark_profile == "") dark_profile = "Slate";
               parentProfileName = dark_profile;
            } else {
               parentProfileName = "Default";
            }
         }
         if (parentProfileName != "") {
            // load the parent color scheme first
            _xmlcfg_close(handle);
            handle = _plugin_get_profile(VSCFGPACKAGE_COLOR_PROFILES,parentProfileName,optionLevel);
            if (handle >= 0) {
               loadProfile(parentProfileName, optionLevel,
                           pdefined_minimap_divider, 
                           window_text_fg, window_text_bg, 
                           window_text_flags, window_text_embg, 
                           recursiveDepth+1);
            }
            handle=_plugin_get_profile(VSCFGPACKAGE_COLOR_PROFILES,realProfileName(profileName),optionLevel);
            profile_node=_xmlcfg_set_path(handle,"/profile");
         }
      }

      // watch for the scheme version
      if (recursiveDepth == 0) {
         m_name = profileName;
      }

      // parse out the colors for this scheme
      property_node:=_xmlcfg_get_first_child(handle,profile_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
      while (property_node>=0) {
         if (_xmlcfg_get_name(handle,property_node)!=VSXMLCFG_PROPERTY) {
            property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
            continue;
         }
         key:=_xmlcfg_get_attribute(handle,property_node,VSXMLCFG_PROPERTY_NAME);

         // handle special cases for inherits profile and associated color scheme
         if (key == "inherit") {
            m_inheritsProfile = _xmlcfg_get_attribute(handle,property_node,VSXMLCFG_PROPERTY_VALUE);
            property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
            continue;
         } else if (key == "associated_symbol_profile") {
            m_symbolColoringProfile = _xmlcfg_get_attribute(handle,property_node,VSXMLCFG_PROPERTY_VALUE);
            property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
            continue;
         }

         // extract the color id and the fg/bg/flag
         constantName := 'CFG_':+upcase(key);
         colorId := _const_value(constantName);
         if (colorId==CFG_MINIMAP_DIVIDER) {
            *pdefined_minimap_divider=true;
         }
         if (!isinteger(colorId) || colorId <= 0 || colorId > CFG_LAST_DEFAULT_COLOR) {
            property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
            continue;
         }

         m_definedColors[colorId] = true;
         ColorInfo *c = &m_colors[colorId];
         attrs_node := property_node;
         value := _xmlcfg_get_attribute(handle,attrs_node,'bg');
         if (value!='') c->m_background = ColorInfo.parseColorValue(value);
         value=_xmlcfg_get_attribute(handle,attrs_node,'fg');
         if (value!='') c->m_foreground = ColorInfo.parseColorValue(value);
         value=_xmlcfg_get_attribute(handle,attrs_node,'flags');
         if (value!='') c->m_fontFlags = _hex2dec(value);
         if (c->m_fontFlags & F_INHERIT_BG_COLOR) {
            c->m_background = window_text_bg;
         }
         value=_xmlcfg_get_attribute(handle,attrs_node,'embg');
         if (value!='') {
            ColorInfo *ec = &m_embedded[colorId];
            ec->m_foreground = c->m_foreground;
            ec->m_fontFlags = c->m_fontFlags;
            ec->m_background = ColorInfo.parseColorValue(value);
         } else if (isEmbeddedColor(colorId) && (c->m_fontFlags & F_INHERIT_BG_COLOR)) {
            ColorInfo *ec = &m_embedded[colorId];
            ec->m_foreground = c->m_foreground;
            ec->m_fontFlags = c->m_fontFlags;
            ec->m_background = window_text_embg;
         }
         property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
      }

      defaultText := m_colors[CFG_WINDOW_TEXT];
      defaultEmbedded := m_embedded[CFG_WINDOW_TEXT];
      // null out colors that are not part of this scheme
      for (i := 1; i<=CFG_LAST_DEFAULT_COLOR; i++) {
         if (getColorNameRC(i) == 0) {
            m_colors[i] = null;
            m_embedded[i] = null;
            continue;
         }
         if (!isEmbeddedColor(i)) {
            m_embedded[i] = null;
         }
         if (m_colors[i] == null) {
            m_colors[i] = defaultText;
            if (i==CFG_MINIMAP_DIVIDER && !*pdefined_minimap_divider) {
               m_colors[i].m_background=m_colors[i].m_foreground= isDarkColorProfile(profileName)?0x484849:0xa0a0a0;
               m_colors[i].m_fontFlags=0;
               m_colors[i].m_parentName=null;
            }
            // reminder for devs
            //say('WARNING: loadScheme['schemeName']: m_colors['i':'getColorName(i)']=null (NOT defined in default scheme: 'fileName')');
         }
         if (m_embedded[i] == null) {
            m_embedded[i] = defaultEmbedded;
         }
         // make sure there are no colors with foreground or font inheritance
         if (m_colors[i] != null)   m_colors[i].m_fontFlags   &= ~(F_INHERIT_FG_COLOR|F_INHERIT_STYLE);
         if (m_embedded[i] != null) m_embedded[i].m_fontFlags &= ~(F_INHERIT_FG_COLOR|F_INHERIT_STYLE);
      }
      _xmlcfg_close(handle);

      // that's all folks
      return 0;
   }
   public _str getProfileName()
   {
      return m_name;
   }
   public static _str removeProfilePrefix(_str profileName) {
      parse profileName with auto prefix ':' auto rest;
      if (prefix:=='Dark' || prefix:=='Light') {
         return strip(rest);
      }
      return profileName;
   }
   public static _str addProfilePrefix(_str profileName) {
      if (profileName == "" || strieq(profileName,CONFIG_AUTOMATIC)) {
         return profileName;
      }
      if (isDarkColorProfile(profileName)) {
         profileName='Dark: 'profileName;
      } else {
         profileName='Light: 'profileName;
      }
      return profileName;
   }
   public static void listProfiles(_str (&profileNames)[],bool addPrefix=false) { 
      profileNames._makeempty();
      _plugin_list_profiles(VSCFGPACKAGE_COLOR_PROFILES,auto allProfileNames);
      foreach (auto name in allProfileNames) {
         //if (_plugin_has_builtin_profile(VSCFGPACKAGE_COLOR_PROFILES,name)) continue;
         if (addPrefix) {
            profileNames :+= addProfilePrefix(name);;
         } else {
            profileNames :+= name;
         }
      }

      // The color dialog combo box needs this sorted or
      // the user may not be able to select items that have a prefix match.
      profileNames._sort('i');
   }

   /** 
    * @return 
    * Return the color constant name for the given color 
    * Return null if this is not a color that we work 
    * with in the Color settings dialog. 
    * 
    * @param cfg     color id 
    */
   static _str getColorConstantName(int cfg) {
      // build a table maping CFG_* indexes to their names from the names table.
      static _str cfg_to_name[];
      if (cfg_to_name._isempty()) {
         index := name_match("CFG_",1,ENUM_TYPE|CONST_TYPE);
         while (index > 0) {
            cfg_name := name_name(index);
            cfg_val := name_info(index);
            if (isinteger(cfg_val) && cfg_val >= 0 && cfg_val <= CFG_LAST_DEFAULT_COLOR) {
               cfg_to_name[(int)cfg_val] = upcase(stranslate(cfg_name,'_','-'));
            }
            index = name_match("CFG_",0,ENUM_TYPE|CONST_TYPE);
         }

         // special cases for items that have repeated values
         cfg_to_name[CFG_WINDOW_TEXT]                   = "CFG_WINDOW_TEXT";
         cfg_to_name[CFG_PUNCTUATION]                   = "CFG_PUNCTUATION";
         cfg_to_name[CFG_LIBRARY_SYMBOL]                = "CFG_LIBRARY_SYMBOL";
         cfg_to_name[CFG_OPERATOR]                      = "CFG_OPERATOR";
         cfg_to_name[CFG_USER_DEFINED]                  = "CFG_USER_DEFINED";
         cfg_to_name[CFG_IMAGINARY_LINE]                = "CFG_IMAGINARY_LINE";
         cfg_to_name[CFG_UNKNOWN_TAG]                   = "CFG_UNKNOWN_TAG";
         cfg_to_name[CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND] = "CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND";
         cfg_to_name[CFG_SYMBOL_COLOR_PRIVATE_SCOPE]    = "CFG_SYMBOL_COLOR_PRIVATE_SCOPE";
         cfg_to_name[CFG_SYMBOL_COLOR_PALETTE_00]       = "CFG_SYMBOL_COLOR_PALETTE_00";
         cfg_to_name[CFG_SYMBOL_COLOR_PALETTE_63]       = "CFG_SYMBOL_COLOR_PALETTE_63";
         cfg_to_name[CFG_DOCUMENT_TAB_MODIFIED]         = "CFG_DOCUMENT_TAB_MODIFIED";
      }
      // now look up this item in the table
      if (cfg_to_name._indexin(cfg) && cfg >= 0 && cfg <= CFG_LAST_DEFAULT_COLOR) {
         return cfg_to_name[cfg];
      }
      return null;

      /*
      switch (cfg) {
      case CFG_SELECTION:                 return "CFG_SELECTION";          
      case CFG_WINDOW_TEXT:               return "CFG_WINDOW_TEXT";        
      case CFG_CLINE:                     return "CFG_CLINE";              
      case CFG_SELECTED_CLINE:            return "CFG_SELECTED_CLINE";     
      case CFG_MESSAGE:                   return "CFG_MESSAGE";            
      case CFG_STATUS:                    return "CFG_STATUS";             
      case CFG_CMDLINE:                   return "CFG_CMDLINE";            
      case CFG_CURSOR:                    return "CFG_CURSOR";             
      case CFG_ERROR:                     return "CFG_ERROR";      
      case CFG_MODIFIED_LINE:             return "CFG_MODIFIED_LINE";      
      case CFG_INSERTED_LINE:             return "CFG_INSERTED_LINE";      
      //case CFG_FUNCTION_HELP:             return "CFG_FUNCTION_HELP";      
      //case CFG_FUNCTION_HELP_FIXED      : return "CFG_FUNCTION_HELP_FIXED";
      case CFG_KEYWORD:                   return "CFG_KEYWORD";            
      case CFG_LINENUM:                   return "CFG_LINENUM";            
      case CFG_NUMBER:                    return "CFG_NUMBER";             
      case CFG_STRING:                    return "CFG_STRING";             
      case CFG_COMMENT:                   return "CFG_COMMENT";            
      case CFG_PPKEYWORD:                 return "CFG_PPKEYWORD";          
      case CFG_PUNCTUATION:               return "CFG_PUNCTUATION";        
      case CFG_LIBRARY_SYMBOL:            return "CFG_LIBRARY_SYMBOL";     
      case CFG_OPERATOR:                  return "CFG_OPERATOR";           
      case CFG_USER_DEFINED:              return "CFG_USER_DEFINED";       
      case CFG_IMAGINARY_LINE:            return "CFG_IMAGINARY_LINE";     
      case CFG_NOSAVE_LINE:               return "CFG_NOSAVE_LINE";        
      case CFG_FUNCTION:                  return "CFG_FUNCTION";           
      case CFG_LINEPREFIXAREA:            return "CFG_LINEPREFIXAREA";     
      case CFG_FILENAME:                  return "CFG_FILENAME";           
      case CFG_HILIGHT:                   return "CFG_HILIGHT";            
      case CFG_ATTRIBUTE:                 return "CFG_ATTRIBUTE";          
      case CFG_UNKNOWN_ATTRIBUTE:         return "CFG_UNKNOWN_ATTRIBUTE";          
      case CFG_TAG:                       return "CFG_TAG";
      case CFG_UNKNOWN_TAG:               return "CFG_UNKNOWN_TAG";
      case CFG_XHTMLELEMENTINXSL:         return "CFG_XHTMLELEMENTINXSL";  
      //case CFG_ACTIVECAPTION:             return "CFG_ACTIVECAPTION";      
      //case CFG_INACTIVECAPTION:           return "CFG_INACTIVECAPTION";    
      case CFG_SPECIALCHARS:              return "CFG_SPECIALCHARS";       
      case CFG_CURRENT_LINE_BOX:          return "CFG_CURRENT_LINE_BOX";   
      case CFG_VERTICAL_COL_LINE:         return "CFG_VERTICAL_COL_LINE";  
      case CFG_MARGINS_COL_LINE:          return "CFG_MARGINS_COL_LINE";   
      case CFG_TRUNCATION_COL_LINE:       return "CFG_TRUNCATION_COL_LINE";
      case CFG_PREFIX_AREA_LINE:          return "CFG_PREFIX_AREA_LINE";   
      case CFG_BLOCK_MATCHING:            return "CFG_BLOCK_MATCHING";     
      case CFG_INC_SEARCH_CURRENT:        return "CFG_INC_SEARCH_CURRENT"; 
      case CFG_INC_SEARCH_MATCH:          return "CFG_INC_SEARCH_MATCH";   
      case CFG_HEX_MODE_COLOR:            return "CFG_HEX_MODE_COLOR";     
      case CFG_SYMBOL_HIGHLIGHT:          return "CFG_SYMBOL_HIGHLIGHT";   
      //case CFG_MODIFIED_FILE_TAB:         return "CFG_MODIFIED_FILE_TAB";
      case CFG_LINE_COMMENT:              return "CFG_LINE_COMMENT";
      case CFG_DOCUMENTATION:             return "CFG_DOCUMENTATION";
      case CFG_DOC_KEYWORD:               return "CFG_DOC_KEYWORD";
      case CFG_DOC_PUNCTUATION:           return "CFG_DOC_PUNCTUATION";
      case CFG_DOC_ATTRIBUTE:             return "CFG_DOC_ATTRIBUTE";
      case CFG_DOC_ATTR_VALUE:            return "CFG_DOC_ATTR_VALUE";
      case CFG_IDENTIFIER:                return "CFG_IDENTIFIER";
      case CFG_IDENTIFIER2:               return "CFG_IDENTIFIER2";
      case CFG_FLOATING_NUMBER:           return "CFG_FLOATING_NUMBER";
      case CFG_HEX_NUMBER:                return "CFG_HEX_NUMBER";
      case CFG_SINGLEQUOTED_STRING:       return "CFG_SINGLEQUOTED_STRING";
      case CFG_BACKQUOTED_STRING:         return "CFG_BACKQUOTED_STRING";
      case CFG_UNTERMINATED_STRING:       return "CFG_UNTERMINATED_STRING";
      case CFG_INACTIVE_CODE:             return "CFG_INACTIVE_CODE";
      case CFG_INACTIVE_KEYWORD:          return "CFG_INACTIVE_KEYWORD";
      case CFG_INACTIVE_COMMENT:          return "CFG_INACTIVE_COMMENT";
      case CFG_IMAGINARY_SPACE:           return "CFG_IMAGINARY_SPACE";     
      case CFG_MODIFIED_ITEM:             return "CFG_MODIFIED_ITEM";
      case CFG_NAVHINT:                   return "CFG_NAVHINT";
      case CFG_XML_CHARACTER_REF:         return "CFG_XML_CHARACTER_REF";
      case CFG_SEARCH_RESULT_TRUNCATED:   return "CFG_SEARCH_RESULT_TRUNCATED";
      case CFG_MARKDOWN_HEADER:           return "CFG_MARKDOWN_HEADER";
      case CFG_MARKDOWN_CODE:             return "CFG_MARKDOWN_CODE";
      case CFG_MARKDOWN_BLOCKQUOTE:       return "CFG_MARKDOWN_BLOCKQUOTE";
      case CFG_MARKDOWN_LINK:             return "CFG_MARKDOWN_LINK";
      case CFG_MARKDOWN_LINK2:            return "CFG_MARKDOWN_LINK2";
      case CFG_MARKDOWN_BULLET:           return "CFG_MARKDOWN_BULLET";
      case CFG_MARKDOWN_EMPHASIS:         return "CFG_MARKDOWN_EMPHASIS";
      case CFG_MARKDOWN_EMPHASIS2:        return "CFG_MARKDOWN_EMPHASIS2";
      case CFG_MARKDOWN_EMPHASIS3:        return "CFG_MARKDOWN_EMPHASIS3";
      case CFG_MARKDOWN_EMPHASIS4:        return "CFG_MARKDOWN_EMPHASIS4";
      case CFG_CSS_ELEMENT:               return "CFG_CSS_ELEMENT";
      case CFG_CSS_CLASS:                 return "CFG_CSS_CLASS";
      case CFG_CSS_PROPERTY:              return "CFG_CSS_PROPERTY";
      case CFG_CSS_SELECTOR:              return "CFG_CSS_SELECTOR";
      case CFG_DOCUMENT_TAB_ACTIVE:       return "CFG_DOCUMENT_TAB_ACTIVE";
      case CFG_DOCUMENT_TAB_MODIFIED:     return "CFG_DOCUMENT_TAB_MODIFIED";
      case CFG_DOCUMENT_TAB_SELECTED:     return "CFG_DOCUMENT_TAB_SELECTED";
      case CFG_DOCUMENT_TAB_UNSELECTED:   return "CFG_DOCUMENT_TAB_UNSELECTED";
      case CFG_SELECTIVE_DISPLAY_LINE:    return "CFG_SELECTIVE_DISPLAY_LINE";        
      case CFG_REF_HIGHLIGHT_0:           return "CFG_REF_HIGHLIGHT_0";            
      case CFG_REF_HIGHLIGHT_1:           return "CFG_REF_HIGHLIGHT_1";            
      case CFG_REF_HIGHLIGHT_2:           return "CFG_REF_HIGHLIGHT_2";            
      case CFG_REF_HIGHLIGHT_3:           return "CFG_REF_HIGHLIGHT_3";            
      case CFG_REF_HIGHLIGHT_4:           return "CFG_REF_HIGHLIGHT_4";            
      case CFG_REF_HIGHLIGHT_5:           return "CFG_REF_HIGHLIGHT_5";            
      case CFG_REF_HIGHLIGHT_6:           return "CFG_REF_HIGHLIGHT_6";            
      case CFG_REF_HIGHLIGHT_7:           return "CFG_REF_HIGHLIGHT_7";            
      case CFG_MINIMAP_DIVIDER:           return "CFG_MINIMAP_DIVIDER";            
      case CFG_YAML_TEXT_COLON:           return "CFG_YAML_TEXT_COLON";
      case CFG_YAML_TEXT:                 return "CFG_YAML_TEXT";
      case CFG_YAML_TAG:                  return "CFG_YAML_TAG";
      case CFG_YAML_DIRECTIVE:            return "CFG_YAML_DIRECTIVE";
      case CFG_YAML_ANCHOR_DEF:           return "CFG_YAML_ANCHOR_DEF";
      case CFG_YAML_ANCHOR_REF:           return "CFG_YAML_ANCHOR_REF";
      case CFG_YAML_PUNCTUATION:          return "CFG_YAML_PUNCTUATION";
      case CFG_YAML_OPERATOR:             return "CFG_YAML_OPERATOR";

      // "named" symbol coloring colors
      case CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND:                 return "CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND";
      case CFG_SYMBOL_COLOR_LOCAL_VARIABLE:                   return "CFG_SYMBOL_COLOR_LOCAL_VARIABLE";
      case CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE:            return "CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE";
      case CFG_SYMBOL_COLOR_PARAMETER:                        return "CFG_SYMBOL_COLOR_PARAMETER";
      case CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER:               return "CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER";
      case CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE:           return "CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE";
      case CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE:          return "CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE";
      case CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE:        return "CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE";
      case CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE:          return "CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE";
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE:    return "CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE";
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE:   return "CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE";
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE: return "CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE";
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE:   return "CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE";
      case CFG_SYMBOL_COLOR_GLOBAL_VARIABLE:                  return "CFG_SYMBOL_COLOR_GLOBAL_VARIABLE";
      case CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE:           return "CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE";
      case CFG_SYMBOL_COLOR_GLOBAL_FUNCTION:                  return "CFG_SYMBOL_COLOR_GLOBAL_FUNCTION";
      case CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION:           return "CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION";
      case CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR:                return "CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR";
      case CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR:                 return "CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR";
      case CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION:           return "CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION";
      case CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION:          return "CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION";
      case CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION:        return "CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION";
      case CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION:          return "CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION";
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION:    return "CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION";
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION:   return "CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION";
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION: return "CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION";
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION:   return "CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION";
      case CFG_SYMBOL_COLOR_NESTED_FUNCTION:                  return "CFG_SYMBOL_COLOR_NESTED_FUNCTION";
      case CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY:            return "CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY";
      case CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY:           return "CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY";
      case CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY:         return "CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY";
      case CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY:           return "CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY";
      case CFG_SYMBOL_COLOR_PUBLIC_STATIC_CLASS_PROPERTY:     return "CFG_SYMBOL_COLOR_PUBLIC_STATIC_CLASS_PROPERTY";
      case CFG_SYMBOL_COLOR_PACKAGE_STATIC_CLASS_PROPERTY:    return "CFG_SYMBOL_COLOR_PACKAGE_STATIC_CLASS_PROPERTY";
      case CFG_SYMBOL_COLOR_PROTECTED_STATIC_CLASS_PROPERTY:  return "CFG_SYMBOL_COLOR_PROTECTED_STATIC_CLASS_PROPERTY";
      case CFG_SYMBOL_COLOR_PRIVATE_STATIC_CLASS_PROPERTY:    return "CFG_SYMBOL_COLOR_PRIVATE_STATIC_CLASS_PROPERTY";
      case CFG_SYMBOL_COLOR_CLASS:                            return "CFG_SYMBOL_COLOR_CLASS";
      case CFG_SYMBOL_COLOR_TEMPLATE_CLASS:                   return "CFG_SYMBOL_COLOR_TEMPLATE_CLASS";
      case CFG_SYMBOL_COLOR_ABSTRACT_CLASS:                   return "CFG_SYMBOL_COLOR_ABSTRACT_CLASS";
      case CFG_SYMBOL_COLOR_INTERFACE_CLASS:                  return "CFG_SYMBOL_COLOR_INTERFACE_CLASS";
      case CFG_SYMBOL_COLOR_STRUCT:                           return "CFG_SYMBOL_COLOR_STRUCT";
      case CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE:            return "CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE";
      case CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS:         return "CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS";
      case CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO:               return "CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO";
      case CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE:             return "CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE";
      case CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT:                return "CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT";
      case CFG_SYMBOL_COLOR_ENUMERATED_TYPE:                  return "CFG_SYMBOL_COLOR_ENUMERATED_TYPE";
      case CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT:               return "CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT";
      case CFG_SYMBOL_COLOR_STATEMENT_LABEL:                  return "CFG_SYMBOL_COLOR_STATEMENT_LABEL";
      case CFG_SYMBOL_COLOR_DATABASE_TABLE:                   return "CFG_SYMBOL_COLOR_DATABASE_TABLE";
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_COLUMN:            return "CFG_SYMBOL_COLOR_DATABASE_TABLE_COLUMN";
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_INDEX:             return "CFG_SYMBOL_COLOR_DATABASE_TABLE_INDEX";
      case CFG_SYMBOL_COLOR_DATABASE_TABLE_VIEW:              return "CFG_SYMBOL_COLOR_DATABASE_TABLE_VIEW";
      case CFG_SYMBOL_COLOR_MODULE:                           return "CFG_SYMBOL_COLOR_MODULE";
      case CFG_SYMBOL_COLOR_CONCEPT:                          return "CFG_SYMBOL_COLOR_CONCEPT";
      case CFG_SYMBOL_COLOR_RULE:                             return "CFG_SYMBOL_COLOR_RULE";
      case CFG_SYMBOL_COLOR_ANNOTATION_TYPE:                  return "CFG_SYMBOL_COLOR_ANNOTATION_TYPE";
      case CFG_SYMBOL_COLOR_ANNOTATION:                       return "CFG_SYMBOL_COLOR_ANNOTATION";
      case CFG_SYMBOL_COLOR_CONTROL:                          return "CFG_SYMBOL_COLOR_CONTROL";
      case CFG_SYMBOL_COLOR_MENU:                             return "CFG_SYMBOL_COLOR_MENU";
      case CFG_SYMBOL_COLOR_FORM:                             return "CFG_SYMBOL_COLOR_FORM";
      case CFG_SYMBOL_COLOR_EVENT_TABLE:                      return "CFG_SYMBOL_COLOR_EVENT_TABLE";
      case CFG_SYMBOL_COLOR_PROTECTED_SCOPE:                  return "CFG_SYMBOL_COLOR_PROTECTED_SCOPE";
      case CFG_SYMBOL_COLOR_PRIVATE_SCOPE:                    return "CFG_SYMBOL_COLOR_PRIVATE_SCOPE";
      case CFG_SYMBOL_COLOR_PALETTE_00:                       return "CFG_SYMBOL_COLOR_PALETTE_00";
      case CFG_SYMBOL_COLOR_PALETTE_01:                       return "CFG_SYMBOL_COLOR_PALETTE_01";
      case CFG_SYMBOL_COLOR_PALETTE_02:                       return "CFG_SYMBOL_COLOR_PALETTE_02";
      case CFG_SYMBOL_COLOR_PALETTE_03:                       return "CFG_SYMBOL_COLOR_PALETTE_03";
      case CFG_SYMBOL_COLOR_PALETTE_04:                       return "CFG_SYMBOL_COLOR_PALETTE_04";
      case CFG_SYMBOL_COLOR_PALETTE_05:                       return "CFG_SYMBOL_COLOR_PALETTE_05";
      case CFG_SYMBOL_COLOR_PALETTE_06:                       return "CFG_SYMBOL_COLOR_PALETTE_06";
      case CFG_SYMBOL_COLOR_PALETTE_07:                       return "CFG_SYMBOL_COLOR_PALETTE_07";
      case CFG_SYMBOL_COLOR_PALETTE_08:                       return "CFG_SYMBOL_COLOR_PALETTE_08";
      case CFG_SYMBOL_COLOR_PALETTE_09:                       return "CFG_SYMBOL_COLOR_PALETTE_09";
      case CFG_SYMBOL_COLOR_PALETTE_10:                       return "CFG_SYMBOL_COLOR_PALETTE_10";
      case CFG_SYMBOL_COLOR_PALETTE_11:                       return "CFG_SYMBOL_COLOR_PALETTE_11";
      case CFG_SYMBOL_COLOR_PALETTE_12:                       return "CFG_SYMBOL_COLOR_PALETTE_12";
      case CFG_SYMBOL_COLOR_PALETTE_13:                       return "CFG_SYMBOL_COLOR_PALETTE_13";
      case CFG_SYMBOL_COLOR_PALETTE_14:                       return "CFG_SYMBOL_COLOR_PALETTE_14";
      case CFG_SYMBOL_COLOR_PALETTE_15:                       return "CFG_SYMBOL_COLOR_PALETTE_15";
      case CFG_SYMBOL_COLOR_PALETTE_16:                       return "CFG_SYMBOL_COLOR_PALETTE_16";
      case CFG_SYMBOL_COLOR_PALETTE_17:                       return "CFG_SYMBOL_COLOR_PALETTE_17";
      case CFG_SYMBOL_COLOR_PALETTE_18:                       return "CFG_SYMBOL_COLOR_PALETTE_18";
      case CFG_SYMBOL_COLOR_PALETTE_19:                       return "CFG_SYMBOL_COLOR_PALETTE_19";
      case CFG_SYMBOL_COLOR_PALETTE_20:                       return "CFG_SYMBOL_COLOR_PALETTE_20";
      case CFG_SYMBOL_COLOR_PALETTE_21:                       return "CFG_SYMBOL_COLOR_PALETTE_21";
      case CFG_SYMBOL_COLOR_PALETTE_22:                       return "CFG_SYMBOL_COLOR_PALETTE_22";
      case CFG_SYMBOL_COLOR_PALETTE_23:                       return "CFG_SYMBOL_COLOR_PALETTE_23";
      case CFG_SYMBOL_COLOR_PALETTE_24:                       return "CFG_SYMBOL_COLOR_PALETTE_24";
      case CFG_SYMBOL_COLOR_PALETTE_25:                       return "CFG_SYMBOL_COLOR_PALETTE_25";
      case CFG_SYMBOL_COLOR_PALETTE_26:                       return "CFG_SYMBOL_COLOR_PALETTE_26";
      case CFG_SYMBOL_COLOR_PALETTE_27:                       return "CFG_SYMBOL_COLOR_PALETTE_27";
      case CFG_SYMBOL_COLOR_PALETTE_28:                       return "CFG_SYMBOL_COLOR_PALETTE_28";
      case CFG_SYMBOL_COLOR_PALETTE_29:                       return "CFG_SYMBOL_COLOR_PALETTE_29";
      case CFG_SYMBOL_COLOR_PALETTE_30:                       return "CFG_SYMBOL_COLOR_PALETTE_30";
      case CFG_SYMBOL_COLOR_PALETTE_31:                       return "CFG_SYMBOL_COLOR_PALETTE_31";
      case CFG_SYMBOL_COLOR_PALETTE_32:                       return "CFG_SYMBOL_COLOR_PALETTE_32";
      case CFG_SYMBOL_COLOR_PALETTE_33:                       return "CFG_SYMBOL_COLOR_PALETTE_33";
      case CFG_SYMBOL_COLOR_PALETTE_34:                       return "CFG_SYMBOL_COLOR_PALETTE_34";
      case CFG_SYMBOL_COLOR_PALETTE_35:                       return "CFG_SYMBOL_COLOR_PALETTE_35";
      case CFG_SYMBOL_COLOR_PALETTE_36:                       return "CFG_SYMBOL_COLOR_PALETTE_36";
      case CFG_SYMBOL_COLOR_PALETTE_37:                       return "CFG_SYMBOL_COLOR_PALETTE_37";
      case CFG_SYMBOL_COLOR_PALETTE_38:                       return "CFG_SYMBOL_COLOR_PALETTE_38";
      case CFG_SYMBOL_COLOR_PALETTE_39:                       return "CFG_SYMBOL_COLOR_PALETTE_39";
      case CFG_SYMBOL_COLOR_PALETTE_40:                       return "CFG_SYMBOL_COLOR_PALETTE_40";
      case CFG_SYMBOL_COLOR_PALETTE_41:                       return "CFG_SYMBOL_COLOR_PALETTE_41";
      case CFG_SYMBOL_COLOR_PALETTE_42:                       return "CFG_SYMBOL_COLOR_PALETTE_42";
      case CFG_SYMBOL_COLOR_PALETTE_43:                       return "CFG_SYMBOL_COLOR_PALETTE_43";
      case CFG_SYMBOL_COLOR_PALETTE_44:                       return "CFG_SYMBOL_COLOR_PALETTE_44";
      case CFG_SYMBOL_COLOR_PALETTE_45:                       return "CFG_SYMBOL_COLOR_PALETTE_45";
      case CFG_SYMBOL_COLOR_PALETTE_46:                       return "CFG_SYMBOL_COLOR_PALETTE_46";
      case CFG_SYMBOL_COLOR_PALETTE_47:                       return "CFG_SYMBOL_COLOR_PALETTE_47";
      case CFG_SYMBOL_COLOR_PALETTE_48:                       return "CFG_SYMBOL_COLOR_PALETTE_48";
      case CFG_SYMBOL_COLOR_PALETTE_49:                       return "CFG_SYMBOL_COLOR_PALETTE_49";
      case CFG_SYMBOL_COLOR_PALETTE_50:                       return "CFG_SYMBOL_COLOR_PALETTE_50";
      case CFG_SYMBOL_COLOR_PALETTE_51:                       return "CFG_SYMBOL_COLOR_PALETTE_51";
      case CFG_SYMBOL_COLOR_PALETTE_52:                       return "CFG_SYMBOL_COLOR_PALETTE_52";
      case CFG_SYMBOL_COLOR_PALETTE_53:                       return "CFG_SYMBOL_COLOR_PALETTE_53";
      case CFG_SYMBOL_COLOR_PALETTE_54:                       return "CFG_SYMBOL_COLOR_PALETTE_54";
      case CFG_SYMBOL_COLOR_PALETTE_55:                       return "CFG_SYMBOL_COLOR_PALETTE_55";
      case CFG_SYMBOL_COLOR_PALETTE_56:                       return "CFG_SYMBOL_COLOR_PALETTE_56";
      case CFG_SYMBOL_COLOR_PALETTE_57:                       return "CFG_SYMBOL_COLOR_PALETTE_57";
      case CFG_SYMBOL_COLOR_PALETTE_58:                       return "CFG_SYMBOL_COLOR_PALETTE_58";
      case CFG_SYMBOL_COLOR_PALETTE_59:                       return "CFG_SYMBOL_COLOR_PALETTE_59";
      case CFG_SYMBOL_COLOR_PALETTE_60:                       return "CFG_SYMBOL_COLOR_PALETTE_60";
      case CFG_SYMBOL_COLOR_PALETTE_61:                       return "CFG_SYMBOL_COLOR_PALETTE_61";
      case CFG_SYMBOL_COLOR_PALETTE_62:                       return "CFG_SYMBOL_COLOR_PALETTE_62";
      case CFG_SYMBOL_COLOR_PALETTE_63:                       return "CFG_SYMBOL_COLOR_PALETTE_63";

      default: 
         return null;  
      }
      */
   }

   /** 
    * @return 
    * Return the color constant with the given CFG_name 
    * Returns 'null' if not found.
    * 
    * @param cfg_name     color id 
    */
   static _str getCFGConstantByName(_str cfg_name) {
      cfg_index := find_index(cfg_name, ENUM_TYPE|CONST_TYPE);
      if (cfg_index > 0) {
         return (int)name_info(cfg_index);
      }
      static CFGColorConstants name_to_cfg:[];
      if (name_to_cfg._isempty()) {
         for (i := CFG_WINDOW_TEXT; i<=CFG_LAST_DEFAULT_COLOR; i++) {
            name_i := getColorConstantName(i);
            if (name_i == null || name_i == "") continue;
            name_to_cfg:[name_i] = i;
         }
      }
      if (name_to_cfg._indexin(upcase(cfg_name))) {
         return name_to_cfg:[cfg_name];
      }
      return null;
   }

   /** 
    * @return 
    * Return the embedded background color for this color item. 
    * If the color is inherited, return the color for embedded 
    * window text. 
    * 
    * @param cfg  Color id 
    */
   int getEmbeddedBackgroundColor(int cfg) {
      color := getColor(cfg);
      if (color->m_fontFlags & F_INHERIT_BG_COLOR) {
         color = getEmbeddedColor(CFG_WINDOW_TEXT);
         if (color == null) return 0x0;
      } else {
         color = getEmbeddedColor(cfg);
         if (color == null) return 0x0;
      }
      return color->m_background;
   }

   ////////////////////////////////////////////////////////////////////////
   // interface IColorCollection
   ////////////////////////////////////////////////////////////////////////

   /**
    * @return
    * Return a pointer to the color information object associated with
    * the given color name.  Color names do not have to be universally
    * unique, only unique within this collection.
    * <p>
    * Return null if there is no such color or if this collection does
    * not index colors by name.
    *
    * @param name    color name
    */
   ColorInfo *getColorByName(_str colorName) {
      if (colorName == null || colorName=="") {
         return &m_colors[CFG_WINDOW_TEXT];
      }
      isEmbedded := false;
      if (_first_char(colorName)=='-') {
         isEmbedded = true;
         colorName = substr(colorName, 2);
      }
      cfg := getColorIndexByName(colorName);
      if (isEmbedded) {
         if (cfg < 0 || cfg >= m_embedded._length()) {
            return null;
         }
         return &m_embedded[cfg];
      } else {
         if (cfg < 0 || cfg >= m_colors._length()) {
            return null;
         }
         return &m_colors[cfg];
      }
   }


   ////////////////////////////////////////////////////////////////////////
   // interface IEquals
   ////////////////////////////////////////////////////////////////////////

   /**
    * Compare this object with another (presumably) instance of
    * a symbol color rule base.
    *
    * @param rhs  object on the right hand side of comparison
    *
    * @return 'true' if this equals 'rhs', false otherwise
    */
   bool equals(sc.lang.IEquals &rhs) {
      if (rhs == null) {
//       say("equals:  rhs null");
         return (this == null);
      }
      if (!(rhs instanceof se.color.ColorScheme)) {
//       say("equals:  rhs not a ColorScheme");
         return false;
      }
      ColorScheme *pRHS = &((ColorScheme)rhs);
      if (pRHS->m_name != m_name) {
//       say("equals:  names are different");
         return false;
      }
      for (i:=1; i<=CFG_LAST_DEFAULT_COLOR; i++) {
         if (!getColorName(i)) continue;
         c1 := getColor(i);
         c2 := pRHS->getColor(i);
         if (c1==null && c2==null) {
         } else if (c1 == null || c2==null) {
//          say("equals: MISSING COLOR, i="i" color="getColorName(i));
            return false;
         } else if (*c1 == null && *c2 == null) {
         } else if (*c1 != null && *c2 != null) {
            if (*c1 != *c2) {
//             say("equals: HERE1, i="i" color="getColorName(i));
               return false;
            }
         }
         if (isEmbeddedColor(i)) {
            c1 = getEmbeddedColor(i);
            c2 = pRHS->getEmbeddedColor(i);
            if (c1==null && c2==null) {
            } else if (c1 == null || c2==null) {
//             say("equals: MISSING EMBEDDED COLOR, i="i" color="getColorName(i));
            } else if (*c1 == null && *c2 == null) {
            } else if (*c1 != null && *c2 != null) {
               if (*c1 != *c2) {
//                say("equals: EMBEDDED HERE1, i="i" color="getColorName(i));
//                _dump_var(*c1);
//                _dump_var(*c2);
                  return false;
               }
            }
         }
      }
      if (pRHS->m_symbolColoringProfile != m_symbolColoringProfile) {
//       say("equals:  different coloring scheme names");
         return false;
      }
      if (pRHS->m_inheritsProfile != m_inheritsProfile) {
//       say("equals:  different parent scheme names");
         return false;
      }
//    say("equals:  EQUAL AFTER ALL!");
      return true;
   }

};

