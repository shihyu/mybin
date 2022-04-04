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
#require "se/color/IColorCollection.e"
#import "se/color/ColorScheme.e"
#import "recmacro.e"
#import "stdprocs.e"
#endregion

/**
 * These constants are used for message and status colors to indicate 
 * that we should use the default system color. 
 */
const VSDEFAULT_FOREGROUND_COLOR=0x80000008;
const VSDEFAULT_BACKGROUND_COLOR=0x80000005;


/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;

/**
 * This class is used to keep track of color information and 
 * implement color inheritance. 
 */
class ColorInfo {

   /**
    * Name of color to inherit from.  This is a color allocated and 
    * managed using the ColorManager class. 
    */
   _str m_parentName;

   /**
    * Foreground color.  Specify -1 to inherit color from the parent color.
    */
   int m_foreground;
   /**
    * Background color.  Specify -1 to inherit color from the parent color.
    */
   int m_background;
    /**
    * Font flags to add to this color specification. 
    * <ul> 
    * <li>F_BOLD -- bold font
    * <li>F_ITALIC -- italic font
    * <li>F_STRIKE_THRU -- strike through font
    * <li>F_UNDERLINE -- underline text
    * <li>F_INHERIT_FG_COLOR -- inherit foreground color from parent color 
    * <li>F_INHERIT_BG_COLOR -- inherit background color from parent color 
    * <li>F_INHERIT_STYLE -- inherit font style from parent color 
    * </ul>
    */
   int m_fontFlags;

   /**
    * Construct a color information object. 
    *  
    * @param fg            Foreground color ( -1 to inherit fg color )
    * @param bg            Background color ( -1 to inherit fg color )
    * @param fontFlags     Additional font flags
    * @param parentName    Name of parent color
    */
   ColorInfo(int fg=-1, int bg=-1, int fontFlags=0, _str parent=null) {
      m_parentName = parent;
      m_foreground = fg;
      m_background = bg;
      m_fontFlags  = fontFlags;
   }

   /**
    * @return Return the color index of the parent color. 
    *         Returns 0 if there is no parent color.
    */
   int getParentColorIndex() {
      if (m_parentName == null || m_parentName == "") {
         return 0;
      }
      if (m_parentName != null && isinteger(m_parentName)) {
         return (int)m_parentName;
      }
      return ColorScheme.getColorIndexByName(m_parentName);
   }

   /**
    * @return Return the parent color for this item. 
    *         Returns CFG_WINDOW_TEXT if there is no parent color.
    *  
    * @param colorProfileName   (optional) name of color scheme to fetch color for 
    */
   ColorInfo getParentColor(_str colorProfileName=null) {
      ColorInfo parentColor = null;
      if (m_parentName == null || m_parentName == "") {
         parentColor.getColor(CFG_WINDOW_TEXT, colorProfileName);
         return parentColor;
      }
      if (m_parentName != null && isinteger(m_parentName)) {
         parentColor.getColor((int)m_parentName, colorProfileName);
         return parentColor;
      }
      parentIndex := ColorScheme.getColorIndexByName(m_parentName);
      if (parentIndex > 0) {
         parentColor.getColor(parentIndex, colorProfileName);
      }
      return parentColor;
   }

   /**
    * @return Return the actual (calculated) foreground color for this
    *         color specification.
    *  
    * @param cc                 (optional) color collection object 
    * @param colorProfileName   (optional) name of color scheme to fetch color for 
    * @param depth              (optional) recursive call depth 
    *  
    * This will be the foreground color set in this object, provided 
    * it is not -1, which indicates that we should inherit the color 
    * from the parent object.  Otherwise, it is the parent color. 
    * If the parent color is not set, or is invalid, this will return 
    * the foreground color for CFG_WINDOW_TEXT. 
    */
   int getForegroundColor(IColorCollection *cc=null, _str colorProfileName=null, int depth=0) {
      // first check if foreground color is inherited
      if ((m_fontFlags & F_INHERIT_FG_COLOR) && cc != null && depth<32) {
         if (m_parentName != null && isinteger(m_parentName)) {
            ColorInfo parentColor;
            parentColor.getColor((int)m_parentName, colorProfileName);
            if (parentColor != null) {
               return parentColor.m_foreground;
            }
         }
         color := cc->getColorByName(m_parentName);
         if (color != null) {
            return color->getForegroundColor(cc, colorProfileName, depth+1);
         }
      }
      // return actual foreground color
      return m_foreground;
   }

   /**
    * @return Return the actual (calculated) background color for this
    *         color specification.
    *  
    * @param cc                 (optional) color collection object 
    * @param colorProfileName   (optional) name of color scheme to fetch color for 
    * @param depth              (optional) recursive call depth 
    *  
    * This will be the background color set in this object, provided 
    * it is not -1, which indicates that we should inherit the color 
    * from the parent object.  Otherwise, it is the parent color.  If 
    * the parent color is not set, or is invalid, this will return the 
    * background color for CFG_WINDOW_TEXT. 
    */
   int getBackgroundColor(IColorCollection *cc=null, _str colorProfileName=null, int depth=0) {
      // first check if background color is inherited
      if ((m_fontFlags & F_INHERIT_BG_COLOR) && cc != null && depth<32) {
         if (m_parentName != null && isinteger(m_parentName)) {
            ColorInfo parentColor;
            parentColor.getColor((int)m_parentName, colorProfileName);
            if (parentColor != null) {
               return parentColor.m_background;
            }
         }
         color := cc->getColorByName(m_parentName);
         if (color != null) {
            return color->getBackgroundColor(cc, colorProfileName, depth+1);
         }
      }
      // return actual background color
      return m_background;
   }

   /**
    * @return Return the actual (calculated) font flags for this color
    *         specification.
    *  
    * @param cc                 (optional) color collection object 
    * @param colorProfileName   (optional) name of color scheme to fetch color for 
    * @param depth              (optional) recursive call depth 
    *  
    * If this color inherits from a parent color, the font flags will 
    * be the font flags set in the parent color.
    */
   int getFontFlags(IColorCollection *cc=null, _str colorProfileName=null, int depth=0) {
      if (!(m_fontFlags & F_INHERIT_STYLE)) {
         return m_fontFlags;
      }
      font_flags := (m_fontFlags & (F_INHERIT_BG_COLOR|F_INHERIT_FG_COLOR|F_INHERIT_STYLE));
      if (cc != null && m_parentName!=null && depth<32) {
         if (isinteger(m_parentName)) {
            parse _default_color((int)m_parentName, -1, -1, -1, 0, colorProfileName) with . . auto ff;
            parent_font_flags := (int) ff;
            parent_font_flags &= (F_BOLD|F_ITALIC|F_UNDERLINE|F_STRIKE_THRU);
            return parent_font_flags | font_flags;
         }
         color := cc->getColorByName(m_parentName);
         if (color != null) {
            parent_font_flags := color->getFontFlags(cc, colorProfileName, depth+1);
            parent_font_flags &= (F_BOLD|F_ITALIC|F_UNDERLINE|F_STRIKE_THRU);
            return parent_font_flags | font_flags;
         }
      }
      return m_fontFlags;
   }

   /**
    * @return Allocate a system color ID for this color specification. 
    *  
    * @param cc                 (optional) color collection object 
    * @param colorProfileName   (optional) name of color scheme to fetch color for 
    * @param depth              (optional) recursive call depth 
    *  
    * @see _AllocColor 
    * @see _FreeColor 
    */
   int allocateColorId(IColorCollection *cc=null, _str colorProfileName=null, int depth=0) {
      fg := getForegroundColor(cc, colorProfileName, depth+1);
      bg := getBackgroundColor(cc, colorProfileName, depth+1);
      ff := getFontFlags(cc, colorProfileName, depth+1);
      ff &= ~(F_INHERIT_STYLE|F_INHERIT_FG_COLOR);
      parentId := getParentColorIndex();
      if (parentId <= 0 || parentId > CFG_LAST_DEFAULT_COLOR) parentId = 0;
      colorId := _AllocColor(fg,bg,ff,parentId,colorProfileName);
      return colorId;
   }

   /**
    *  
    * Get the color information for the given color ID
    * 
    * @param colorId          color index, either a default color, embedded color, 
    *                         or something allocated by {@link _AllocColor()}. 
    * @param colorProfileName (optional) name of color scheme to fetch color for 
    */
   void getColor(int colorId, _str colorProfileName=null) {
      color_info := "";
      if (colorProfileName == null && colorProfileName == "") {
         color_info = _default_color(colorId);
      } else {
         color_info = _default_color(colorId, -1, -1, -1, 0, colorProfileName);
      }
      parse color_info with auto fg auto bg auto fontFlags;
      if (fg == "2147483656") fg = (int)VSDEFAULT_FOREGROUND_COLOR;
      if (bg == "2147483656") bg = (int)VSDEFAULT_FOREGROUND_COLOR;
      if (fg == "2147483653") fg = (int)VSDEFAULT_BACKGROUND_COLOR;
      if (bg == "2147483653") bg = (int)VSDEFAULT_BACKGROUND_COLOR;
      m_foreground = (int) fg;
      m_background = (int) bg;
      m_fontFlags  = (int) fontFlags;
      m_parentName = null;
   }

   /**
    * Update the color information for this color specification. 
    *  
    * @param colorId            color index to set color for 
    * @param cc                 (optional) color collection object 
    * @param colorProfileName   (optional) name of color scheme to fetch color for 
    *  
    * @see _default_color 
    */
   void setColor(int colorId, IColorCollection *cc=null, _str colorProfileName=null) {
      fg := getForegroundColor(cc, colorProfileName);
      bg := getBackgroundColor(cc, colorProfileName);
      ff := getFontFlags(cc, colorProfileName);
      parentId := getParentColorIndex();
      _default_color(colorId, fg, bg, ff, parentId, colorProfileName);
   }

   /**
    * Swap foreground and background colors. 
    *  
    * @param cc                 (optional) color collection object 
    * @param colorProfileName   (optional) name of color scheme to fetch color for 
    */
   void invertColor(IColorCollection *cc=null, _str colorProfileName=null) {
      fg := getForegroundColor(cc, colorProfileName);
      bg := getBackgroundColor(cc, colorProfileName);
      m_foreground = bg;
      m_background = fg;
      m_fontFlags &= ~(F_INHERIT_BG_COLOR|F_INHERIT_FG_COLOR);
   }

   /** 
    * @return 
    * Return 'true' if this colorInfo object matches the color set 
    * for the given colorId. 
    *  
    * @param colorId            color index for color to compare this color to 
    * @param colorProfileName   (optional) name of color scheme to fetch color for 
    * @param cc                 (optional) color collection object 
    */
   bool matchesColor(int colorId, IColorCollection *cc=null, _str colorProfileName=null) {
      ColorInfo colorInfo;
      colorInfo.getColor(colorId, colorProfileName);
      if (colorInfo == this) {
         return true;
      }
      if (colorInfo.getForegroundColor(cc, colorProfileName) == getForegroundColor(cc, colorProfileName) &&
          colorInfo.getBackgroundColor(cc, colorProfileName) == getBackgroundColor(cc, colorProfileName) &&
          colorInfo.getFontFlags(cc, colorProfileName) == getFontFlags(cc, colorProfileName)) {
         return true;
      }
      return false;
   }

   /**
    * Does this color inherit everything (foreground, background, and font flags)?
    */
   bool inheritsEverything() {
      parentColor := getParentColorIndex();
      return (parentColor > 0 && (m_fontFlags & (F_INHERIT_BG_COLOR|F_INHERIT_FG_COLOR|F_INHERIT_STYLE)) == (F_INHERIT_BG_COLOR|F_INHERIT_FG_COLOR|F_INHERIT_STYLE));
   }

   /**
    * @return
    * Convert font flags to a string representation for writing to 
    * the XML configuration file.  This way the information in the 
    * configuration file is symbolic and readable. 
    *  
    * @param font_flags    Font flags to convert. 
    */
   static _str fontFlagsToString(int font_flags) {
      s := "";
      if ( font_flags & F_BOLD)              s :+= "F_BOLD|";
      if ( font_flags & F_ITALIC )           s :+= "F_ITALIC|";
      if ( font_flags & F_STRIKE_THRU )      s :+= "F_STRIKE_THRU|";
      if ( font_flags & F_UNDERLINE )        s :+= "F_UNDERLINE|";
      if ( font_flags & F_PRINTER )          s :+= "F_PRINTER|";
      if (( font_flags & F_INHERIT_STYLE    ) &&
          ( font_flags & F_INHERIT_BG_COLOR ) &&
          ( font_flags & F_INHERIT_FG_COLOR )) {
         s :+= "F_INHERIT_ALL|";
      } else {
         if ( font_flags & F_INHERIT_STYLE )    s :+= "F_INHERIT_STYLE|";
         if ( font_flags & F_INHERIT_BG_COLOR ) s :+= "F_INHERIT_BG_COLOR|";
         if ( font_flags & F_INHERIT_FG_COLOR ) s :+= "F_INHERIT_FG_COLOR|";
      }
      _maybe_strip(s, '|');
      return s;
   }

   /**
    * Convert a color value to a SlickEdit RGB value.
    */
   static int parseColorValue(_str value) {
      if (_first_char(value) == '#') {
         r := substr(value, 2, 2);
         g := substr(value, 4, 2);
         b := substr(value, 6, 2);
         return _hex2dec("0x":+b:+g:+r);
      }
      return _hex2dec(value);
   }

   /** 
    * @return
    * Convert the given SlickEdit RGB color value to an HTML color (#RRGGBB) 
    */
   static _str formatHTMLHexColor(int rgb) {
      if (rgb <= 0xFFFFFF) {
         html_val := _dec2hex(rgb,16,6);
         blue  := substr(html_val,1,2);
         green := substr(html_val,3,2);
         red   := substr(html_val,5,2);
         html_val ='#':+red:+green:+blue;
         return upcase(html_val);
      }
      return "0x" :+ upcase(_dec2hex(rgb, 16, 6));
   }


   /** 
    * @return 
    * Parse a list of font flags and return their integer value. 
    *  
    * @param s    string containing font flags from XML config file. 
    */
   static int parseFontFlags(_str s) {
      font_flags := 0;
      split(s, "|", auto flag_names);
      foreach (auto flag in flag_names) {
         switch (flag) {
         case "F_BOLD":               font_flags |= F_BOLD; break;           
         case "F_ITALIC":             font_flags |= F_ITALIC; break;    
         case "F_STRIKE_THRU":        font_flags |= F_STRIKE_THRU; break;  
         case "F_UNDERLINE":          font_flags |= F_UNDERLINE; break;
         case "F_PRINTER":            font_flags |= F_PRINTER; break;
         case "F_INHERIT_STYLE":      font_flags |= F_INHERIT_STYLE; break; 
         case "F_INHERIT_BG_COLOR":   font_flags |= F_INHERIT_BG_COLOR; break;
         case "F_INHERIT_FG_COLOR":   font_flags |= F_INHERIT_FG_COLOR; break;
         case "F_INHERIT_ALL":        font_flags |= F_INHERIT_ALL; break;
         }
      }
      return font_flags;
   }

   /**
    * Insert the macro code required to set this color for the user's color profile. 
    *  
    * @param cfgName           name of CFG_* constant to set 
    * @param colorProfileName  (optional) name of color scheme to fetch color for 
    */
   void insertMacroCode(_str cfgName, bool macroRecording, _str colorProfileName=null) {
      fontFlagsString := fontFlagsToString(m_fontFlags);
      parentAndSchemeArgs := "";
      if (colorProfileName != null && colorProfileName != "" && colorProfileName != def_color_scheme) {
         parentAndSchemeArgs = ",0,":+_quote(colorProfileName);
      }
      if (fontFlagsString == "") fontFlagsString=0;
      if (macroRecording) {
         _macro_append('_default_color('cfgName',0x'_dec2hex(m_foreground,16,6)',0x'_dec2hex(m_background,16,6)','fontFlagsString:+parentAndSchemeArgs');');
      } else {
         insert_line('  _default_color('cfgName',0x'_dec2hex(m_foreground,16,6)',0x'_dec2hex(m_background,16,6)','fontFlagsString:+parentAndSchemeArgs');');
      }
   }

};
