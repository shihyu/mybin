////////////////////////////////////////////////////////////////////////////////////
// Copyright 2021 SlickEdit Inc. 
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
#include "plugin.sh"
#include "xml.sh"
#import "se/color/ColorInfo.e"
#import "se/color/ColorScheme.e"
#import "se/color/DefaultColorsConfig.e"
#import "cfg.e"
#import "color.e"
#import "guiopen.e"
#import "htmltool.e"
#import "listbox.e"
#import "main.e"
#import "picture.e"
#import "stdprocs.e"
#endregion

/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;

/**
 * Semi-abstract class for import color themes from other products 
 * as a color profile. Derive from this class to import a working 
 * color importer (see derived classes below).
 */
class ColorImport {
   
   /**
    * Import a color theme from the given file and populate the given 
    * color profile object. 
    *  
    * @note 
    * This function is implemented in a pretty generic manner, calling 
    * out to virtual functions to do most of the work.  however, this 
    * function itself can also be overloaded and implemented in any manner 
    * necessary, for example, if importing from a color theme file which is 
    * not XML.
    * 
    * @param scm              color profile
    * @param importFileName   file to import from  
    * 
    * @return 0 on success, &lt;0 on error.
    */
   int importColorProfile(se.color.ColorScheme &scm, _str importFileName) {

      // open the file, assuming it is XML
      status := 0;
      fileHandle := _xmlcfg_open(importFileName, status, VSXMLCFG_OPEN_ADD_ALL_PCDATA);
      if (status < 0) {
         return status;
      }

      // get the default window colors
      initCanvasColors(fileHandle, scm);

      // find all the color categories defined
      getCategoryIndexes(fileHandle, auto catIndexes);

      // do two passes over all the color combinations, the is because we need
      // to correctly resolve the canvas background colors when processing
      // other colors.  This allows us to determine what colors inherit the
      // background color and what colors do not.
      //
      for (pass := 0; pass<2; pass++) {

         // for each color category
         foreach (auto catNode in catIndexes) {

            // get the category name
            catName := getCategoryName(fileHandle, (int)catNode);

            // find all the colors defined
            getColorIndexes(fileHandle, catNode, catName, auto colorIndexes);
            foreach (auto colorNode in colorIndexes) {

               // get the color name
               colorName := getColorName(fileHandle, colorNode);

               // map the category and color name to a color constant (or several)
               awesomeness := 0;
               cfg2 := cfg3 := cfg4 := 0;
               cfg := getColorFromName(catName, colorName, cfg2, cfg3, cfg4, awesomeness);
               if (cfg == CFG_NULL) {
                  //say("import_visual_studio_theme H"__LINE__": category="catName" colorName="colorName);
                  continue;
               }

               // already have a better setting for this color
               if (cfg > 0 && awesomeness < m_currentAwesomeness[cfg]) {
                  continue;
               }

               // get the original colors for this item
               bgColor := fgColor := emColor := fontFlags := 0;
               pColorInfo := getColorFromProfile(scm, cfg, bgColor, fgColor, emColor, fontFlags);

               // get the background color
               if (getColorFromNode(fileHandle, colorNode, colorName, bgColor, fgColor, fontFlags) < 0) {
                  continue;
               }

               // save the color in the color profile
               saveColorInProfile(scm, pColorInfo, cfg, cfg2, cfg3, cfg4, bgColor, fgColor, -1, fontFlags);
            }
         }
      }

      // final cleanup, tries to fill in missing colors
      interpolateMissingColors(scm);

      // final step, close the file and return
      _xmlcfg_close(fileHandle);
      return 0;
   }

   /**
    * Get the list of color category nodes from the color theme file.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catIndexes    (output) array of index of category nodes 
    *  
    * @note 
    * This function usually needs to be overloaded. <br>
    * The default version of this function just creates an array {0}, serving 
    * as a placeholder for color themes which do not have categories. 
    */
   protected void getCategoryIndexes(int fileHandle, int (&catIndexes)[]) {
      catIndexes._makeempty();
      catIndexes :+= 0;
   }

   /** 
    * @return 
    * Return the name of the given category node.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catNode       category node to get name of
    * 
    * @note 
    * This function usually needs to be overloaded. <br>
    * The default version of this function just returns ""
    */
   protected _str getCategoryName(int fileHandle, int catNode) {
      return "";
   }

   /**
    * Get the list of color definition nodes from the color theme file.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle) 
    * @param catNode       category node to get colors from 
    * @param catName       category name 
    * @param colorIndexes  (output) array of index of color nodes 
    *  
    * @note 
    * This function needs to be overloaded. 
    * The default implementation returns an empty array. 
    */
   protected void getColorIndexes(int fileHandle, int catNode, _str catName, int (&colorIndexes)[]) {
      colorIndexes._makeempty();
   }

   /** 
    * @return 
    * Return the name of the given color definition node.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to get name of
    * 
    * @note 
    * This function usually needs to be overloaded.
    */
   protected _str getColorName(int fileHandle, int colorNode) {
      return _xmlcfg_get_attribute(fileHandle, colorNode, "Name");
   }

   /**
    * Get the background color, foreground color, and font flags for this color 
    * description node. 
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to extract information from
    * @param bgColor       (output) background color
    * @param fgColor       (output) foreground color
    * @param fontFlags     (output) font flags
    * 
    * @return 0 on success, &lt;0 on error.
    *  
    * @note 
    * This function must be overloaded. 
    */
   protected int getColorFromNode(int fileHandle, int colorNode, _str colorName, int &bgColor, int &fgColor, int &fontFlags) {
      return STRING_NOT_FOUND_RC;
   }

   /**
    * @return 
    * Returns the color constant (CFG_*) mapped from the given color category 
    * and color name.  It can also return up to three more color constants, for 
    * related colors that should be set along with a given color, such as the 
    * closely related string and number color constants. 
    * 
    * @param catName        color category name
    * @param colorName      color names
    * @param cfg2           (output) alternate color constant (CFG_*)
    * @param cfg3           (output) alternate color constant (CFG_*)
    * @param cfg4           (output) alternate color constant (CFG_*)
    * @param awesomeness    Rating form 0 .. 10 on how sure we are about this color
    * 
    * @note 
    * This function must be overloaded. 
    *  
    * @note 
    * The 'awesomeness' parameter helps us sort out when there are multiple 
    * color categories and color names that could map to the same color constant. 
    * It allows us to rank the ones that are there and select the best one to use.
    */
   protected int getColorFromName(_str catName, _str colorName, 
                                  int &cfg2, int &cfg3, int &cfg4, 
                                  int &awesomeness) {
      cfg2 = cfg3 = cfg4 = CFG_NULL;
      awesomeness = 0;
      return CFG_NULL;
   }

   /**
    * Initialize the canvas colors based on the colors found in the initial 
    * color scheme.  These colors are likely to be overridden by the imported 
    * theme, but this creates a starting point.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param scm           color profile
    */
   protected void initCanvasColors(int fileHandle, ColorScheme &scm) {
      canvasColor := scm.getColor(CFG_WINDOW_TEXT);
      if (canvasColor != null) {
         m_canvasBgColor = canvasColor->getBackgroundColor(&scm);
         m_canvasFgColor = canvasColor->getForegroundColor(&scm);
      }
      embeddedCanvasColor := scm.getColor(-CFG_WINDOW_TEXT);
      if (embeddedCanvasColor != null) {
         m_canvasEmColor = embeddedCanvasColor->getBackgroundColor(&scm);
      }
   }

   /**
    * @return 
    * Fetch the current color information for the given color from the color profile. 
    * If the given item is not part of the profile, create a default color.
    * 
    * @param scm         color profile
    * @param cfg         color constant (CFG_*)
    * @param bgColor     (output) background color
    * @param fgColor     (output) foreground color
    * @param emColor     (output) embedded color
    * @param fontFlags   (output) font flags (F_*)
    */
   protected ColorInfo *getColorFromProfile(ColorScheme &scm, int cfg, 
                                            int &bgColor, int &fgColor, int &emColor, int &fontFlags) {
      // get the original colors for this item
      fontFlags = 0;
      bgColor = m_canvasBgColor;
      fgColor = m_canvasFgColor;
      emColor = m_canvasEmColor;
      pColorInfo := scm.getColor(cfg);
      if (pColorInfo == null) {
         se.color.ColorInfo newColor;
         newColor.m_background = bgColor;
         newColor.m_foreground = fgColor;
         newColor.m_fontFlags = F_INHERIT_BG_COLOR;
         scm.setColor(cfg, newColor);
         pColorInfo = scm.getColor(cfg);
      } else {
         bgColor = pColorInfo->getBackgroundColor(&scm);
         fgColor = pColorInfo->getForegroundColor(&scm);
         emColor = m_canvasEmColor;
      }
      return pColorInfo;
   }

   /**
    * Save the given color information in the given color profile object.
    * 
    * @param scm        color profile
    * @param pColorInfo color information
    * @param cfg        color constant (CFG_*)
    * @param cfg2       alternate color constant (CFG_*)
    * @param cfg3       alternate color constant (CFG_*)
    * @param cfg4       alternate color constant (CFG_*)
    * @param bgColor    background color
    * @param fgColor    foreground color 
    * @param emColor    (optional) embedded background color
    * @param fontFlags  (optional) font flags (F_*)
    */
   protected void saveColorInProfile(ColorScheme &scm, 
                                     ColorInfo *pColorInfo, 
                                     int cfg, int cfg2, int cfg3, int cfg4, 
                                     int bgColor, int fgColor, 
                                     int emColor=-1, int fontFlags=0) {

      // change background canvas once we get the window color
      if (cfg == CFG_WINDOW_TEXT) {
         m_canvasBgColor = bgColor;
      } else if (cfg == -CFG_WINDOW_TEXT) {
         m_canvasEmColor = bgColor;
      }

      // if they did not give us pColorInfo, get it now
      if (pColorInfo == null) {
         pColorInfo = scm.getColor(cfg);
      }

      // modify the color information
      pColorInfo->m_background = bgColor;
      if ( cfg > 0 ) {
         pColorInfo->m_foreground = fgColor;
      }
      if (bgColor == m_canvasBgColor) {
         pColorInfo->m_fontFlags |= F_INHERIT_BG_COLOR;
      }
      switch (cfg) {
      case CFG_WINDOW_TEXT:
      case -CFG_WINDOW_TEXT:
      case CFG_SELECTED_CLINE:
      case CFG_SELECTION:
         pColorInfo->m_fontFlags &= ~F_INHERIT_BG_COLOR;
         break;
      }

      // and save the color
      scm.setColor(cfg, *pColorInfo);

      // and it's alternate colors too!
      if (cfg2 != CFG_NULL) {
         scm.setColor(cfg2, *pColorInfo);
      }
      if (cfg3 != CFG_NULL) {
         if (cfg == CFG_INACTIVE_CODE && cfg3 == CFG_INACTIVE_KEYWORD) {
            pColorInfo->m_fontFlags |= F_BOLD;
         } else if (cfg == CFG_DOCUMENTATION && cfg3 == CFG_DOC_KEYWORD) {
            pColorInfo->m_fontFlags |= F_BOLD;
         } else if (cfg != CFG_STRING && cfg != CFG_NUMBER && cfg != CFG_WINDOW_TEXT) {
            pColorInfo->m_fontFlags |= F_ITALIC;
         }
         scm.setColor(cfg3, *pColorInfo);
      }
      if (cfg4 != CFG_NULL) {
         if (cfg == CFG_DOCUMENTATION && cfg3 == CFG_DOC_PUNCTUATION) {
            pColorInfo->m_fontFlags |= F_BOLD;
         } else if (cfg != CFG_STRING && cfg != CFG_NUMBER && cfg != CFG_WINDOW_TEXT) {
            pColorInfo->m_fontFlags |= F_ITALIC;
         }
         scm.setColor(cfg4, *pColorInfo);
      }

      // repeat logic to handle embedded colors 
      // if we were given an embedded background color
      if (emColor >= 0 && cfg > 0) {
         saveColorInProfile(scm, null, -cfg, -cfg2, -cfg3, -cfg4, emColor, fgColor, -1, fontFlags);
      }
   }

   /**
    * Save standard colors in the color scheme. 
    * Used when initializing the color scheme.
    */
   void saveStandardWindowColors( ColorScheme &scm, 
                                  int windowBgColor = -1,
                                  int windowEmColor = -1,
                                  int windowFgColor = -1,
                                  int currentLineColor = -1,
                                  int selectionColor = -1,
                                  int selectionLineColor = -1,
                                  int findHighlightBgColor = -1,
                                  int findHighlightFgColor = -1,
                                  int prefixBgColor = -1,
                                  int prefixFgColor = -1,
                                  int bracketsBgColor = -1,
                                  int bracketsFgColor = -1,
                                  int specialCharsColor = -1,
                                  int selectiveDisplayColor = -1) {

      saveColorInProfile(scm, null,
                         CFG_WINDOW_TEXT, CFG_NULL, CFG_NULL, CFG_NULL,
                         windowBgColor, windowFgColor, windowEmColor);
      m_currentAwesomeness[CFG_WINDOW_TEXT] = 10;

      int inheritWindowText[];
      inheritWindowText :+= CFG_IDENTIFIER;
      inheritWindowText :+= CFG_IDENTIFIER2;
      inheritWindowText :+= CFG_OPERATOR;
      inheritWindowText :+= CFG_PUNCTUATION;
      inheritWindowText :+= CFG_USER_DEFINED;
      foreach (auto cfg in inheritWindowText) {
         saveColorInProfile(scm, null,
                            cfg, CFG_NULL, CFG_NULL, CFG_NULL,
                            windowBgColor, windowFgColor, windowEmColor, F_INHERIT_BG_COLOR);
      }

      /*
      if (cursorColor >= 0) {
         pColorInfo = scm.getColor(CFG_CURSOR);
         saveColorInProfile(scm, pColorInfo,
                            CFG_CURSOR, CFG_NULL, CFG_NULL, CFG_NULL,
                            cursorColor, cursorColor); 
         m_currentAwesomeness[CFG_CURSOR] = 10;
      }
      */

      if (currentLineColor >= 0) {
         saveColorInProfile(scm, null,
                            CFG_CLINE, CFG_NULL, CFG_NULL, CFG_NULL,
                            currentLineColor, windowFgColor, 
                            biasEmbeddedColor(windowBgColor, windowEmColor, currentLineColor));
         m_currentAwesomeness[CFG_CLINE] = 10;
      }

      if (selectionColor >= 0) {
         saveColorInProfile(scm, null,
                            CFG_SELECTION, CFG_NULL, CFG_NULL, CFG_NULL,
                            selectionColor, windowFgColor, 
                            biasEmbeddedColor(windowBgColor, windowEmColor, selectionColor));
         m_currentAwesomeness[CFG_SELECTION] = 10;
      }

      // combine selection and current line if we do not have both
      if (selectionLineColor < 0 && selectionColor >= 0 && currentLineColor >= 0) {
         selectionLineColor = interpolateColors(selectionColor, currentLineColor);
         saveColorInProfile(scm, null,
                            CFG_SELECTED_CLINE, CFG_NULL, CFG_NULL, CFG_NULL,
                            selectionLineColor, windowFgColor,
                            biasEmbeddedColor(windowBgColor, windowEmColor, selectionLineColor));
         m_currentAwesomeness[CFG_SELECTED_CLINE] = 10;
      }

      if (specialCharsColor >= 0) {
         saveColorInProfile(scm, null,
                            CFG_SPECIALCHARS, CFG_NULL, CFG_NULL, CFG_NULL,
                            windowBgColor, specialCharsColor);       
         m_currentAwesomeness[CFG_SPECIALCHARS] = 10;
      }

      if (findHighlightBgColor >= 0 || findHighlightFgColor >= 0) {
         if (findHighlightFgColor < 0) findHighlightFgColor = m_canvasFgColor;
         if (findHighlightBgColor < 0) findHighlightBgColor = m_canvasBgColor;
         saveColorInProfile(scm, null,
                            CFG_INC_SEARCH_MATCH, CFG_NULL, CFG_NULL, CFG_NULL,
                            findHighlightBgColor, findHighlightFgColor,
                            biasEmbeddedColor(windowBgColor, windowEmColor, findHighlightBgColor));
         m_currentAwesomeness[CFG_INC_SEARCH_MATCH] = 10;
      }

      if (bracketsBgColor >= 0 || bracketsFgColor >= 0) {
         if (bracketsFgColor < 0) bracketsFgColor = m_canvasFgColor;
         if (bracketsBgColor < 0) bracketsBgColor = m_canvasBgColor;
         saveColorInProfile(scm, null,
                            CFG_HILIGHT, CFG_NULL, CFG_NULL, CFG_NULL,
                            bracketsBgColor, bracketsFgColor);    
         m_currentAwesomeness[CFG_BLOCK_MATCHING] = 10;
      }

      if (prefixFgColor >= 0 || prefixBgColor >= 0) {
         if (prefixFgColor < 0) prefixFgColor = m_canvasFgColor;
         if (prefixBgColor < 0) prefixBgColor = m_canvasBgColor;
         saveColorInProfile(scm, null,
                            CFG_LINEPREFIXAREA, CFG_NULL, CFG_NULL, CFG_NULL,
                            prefixBgColor, prefixFgColor,
                            biasEmbeddedColor(windowBgColor, windowEmColor, prefixBgColor));
         m_currentAwesomeness[CFG_LINEPREFIXAREA] = 10;
      }

      if (selectiveDisplayColor >= 0) {
         saveColorInProfile(scm, null,
                            CFG_SELECTIVE_DISPLAY_LINE, CFG_MARGINS_COL_LINE, CFG_NULL, CFG_NULL,
                            windowBgColor, selectiveDisplayColor);
         m_currentAwesomeness[CFG_SELECTIVE_DISPLAY_LINE] = 10;
      }
   }

   /**
    * Interpolate two colors by averaging red, green, and blue components.
    */
   protected int interpolateColors(int color1, int color2) {
      r1 := ((color1 >> 0) & 0xff);
      r2 := ((color2 >> 0) & 0xff);
      g1 := ((color1 >> 8) & 0xff);
      g2 := ((color2 >> 8) & 0xff);
      b1 := ((color1 >> 16) & 0xff);
      b2 := ((color2 >> 16) & 0xff);
      r := ((r1 + r2) intdiv 2);
      g := ((g1 + g2) intdiv 2);
      b := ((b1 + b2) intdiv 2);
      return ((b << 16) | (g << 8) | r);
   }

   /**
    * Interpolate two colors by averaging red, green, and blue components.
    */
   protected int biasEmbeddedColor(int windowBgColor, int windowEmColor, int otherBgColor) {
      rb := ((windowBgColor >> 0) & 0xff);
      rm := ((windowEmColor >> 0) & 0xff);
      ro := ((otherBgColor >> 0) & 0xff);
      gb := ((windowBgColor >> 8) & 0xff);
      gm := ((windowEmColor >> 8) & 0xff);
      go := ((otherBgColor >> 8) & 0xff);
      bb := ((windowBgColor >> 16) & 0xff);
      bm := ((windowEmColor >> 16) & 0xff);
      bo := ((otherBgColor >> 16) & 0xff);
      r_shift := (rb - rm);
      g_shift := (gb - gm);
      b_shift := (bb - bm);
      r := (ro + r_shift intdiv 2);
      g := (go + g_shift intdiv 2);
      b := (bo + b_shift intdiv 2);
      r  = clamp(r,0,255);
      g  = clamp(g,0,255);
      b  = clamp(b,0,255);
      return ((b << 16) | (g << 8) | r);
   }

   /**
    * Some colors can be deduced from other colors, so if they are 
    * missing from the imported color specification, see if we can plug 
    * them in now. 
    */
   void interpolateMissingColors(ColorScheme &scm) {

      // selected current line can be deduced form selection and current line
      if (m_currentAwesomeness[CFG_SELECTED_CLINE] <= 0) {
         if (m_currentAwesomeness[CFG_SELECTION] > 0 && m_currentAwesomeness[CFG_CLINE] > 0) {

            selectionBgColor := selectionFgColor := selectionEmColor := selectionFlags := 0;
            getColorFromProfile(scm, CFG_SELECTION, selectionBgColor, selectionFgColor, selectionEmColor, selectionFlags);
            currentLineBgColor := currentLineFgColor := currentLineEmColor := currentLineFlags := 0;
            getColorFromProfile(scm, CFG_CLINE, currentLineBgColor, currentLineFgColor, currentLineEmColor, currentLineFlags);

            selectedLineFgColor := interpolateColors(selectionFgColor, currentLineFgColor);
            selectedLineBgColor := interpolateColors(selectionBgColor, currentLineBgColor);
            selectedLineEmColor := interpolateColors(selectionEmColor, currentLineBgColor);

            saveColorInProfile(scm, null,
                               CFG_SELECTED_CLINE, CFG_NULL, CFG_NULL, CFG_NULL,
                               selectedLineBgColor, selectedLineFgColor, selectedLineEmColor, (selectionFlags & currentLineFlags));
            m_currentAwesomeness[CFG_SELECTED_CLINE] = 10;
         }
      }

      // current incremental search highlight can be deduced form search highlight and current line
      if (m_currentAwesomeness[CFG_INC_SEARCH_CURRENT] <= 0) {
         if (m_currentAwesomeness[CFG_INC_SEARCH_MATCH] > 0 && m_currentAwesomeness[CFG_CLINE] > 0) {

            findHighlightBgColor := findHighlightFgColor := findHighlightEmColor := findHighlightFlags := 0;
            getColorFromProfile(scm, CFG_INC_SEARCH_MATCH, findHighlightBgColor, findHighlightFgColor, findHighlightEmColor, findHighlightFlags);
            currentLineBgColor := currentLineFgColor := currentLineEmColor := currentLineFlags := 0;
            getColorFromProfile(scm, CFG_CLINE, currentLineBgColor, currentLineFgColor, currentLineEmColor, currentLineFlags);

            currentHighlightFgColor := interpolateColors(findHighlightFgColor, currentLineFgColor);
            currentHighlightBgColor := interpolateColors(findHighlightBgColor, currentLineBgColor);
            currentHighlightEmColor := interpolateColors(findHighlightEmColor, currentLineBgColor);

            saveColorInProfile(scm, null,
                               CFG_INC_SEARCH_CURRENT, CFG_NULL, CFG_NULL, CFG_NULL,
                               currentHighlightBgColor, currentHighlightFgColor, currentHighlightEmColor, (findHighlightFlags & currentLineFlags));
            m_currentAwesomeness[CFG_INC_SEARCH_CURRENT] = 10;
         }
      }

      // punctuation and operators can just use window text if the scheme did not define them
      if (m_currentAwesomeness[CFG_PUNCTUATION] <= 0 && m_currentAwesomeness[CFG_WINDOW_TEXT] > 0) {
         saveColorInProfile(scm, null, CFG_PUNCTUATION, CFG_NULL, CFG_NULL, CFG_NULL, 
                            m_canvasBgColor, m_canvasFgColor, m_canvasEmColor);
      }
      if (m_currentAwesomeness[CFG_OPERATOR] <= 0 && m_currentAwesomeness[CFG_WINDOW_TEXT] > 0) {
         saveColorInProfile(scm, null, CFG_OPERATOR, CFG_NULL, CFG_NULL, CFG_NULL, 
                            m_canvasBgColor, m_canvasFgColor, m_canvasEmColor);
      }

      // the prefix area line can be interpolated from the prefix area color and gray
      if (m_currentAwesomeness[CFG_PREFIX_AREA_LINE] <= 0 && m_currentAwesomeness[CFG_LINEPREFIXAREA] > 0) {
         prefixBgColor := prefixFgColor := prefixEmColor := prefixFlags := 0;
         getColorFromProfile(scm, CFG_LINEPREFIXAREA, prefixBgColor, prefixFgColor, prefixEmColor, prefixFlags);
         linePrefixColor := interpolateColors(prefixBgColor, 0x808080);
         saveColorInProfile(scm, null, CFG_LINEPREFIXAREA, CFG_NULL, CFG_NULL, CFG_NULL, 
                            linePrefixColor, linePrefixColor);
      }
      if (m_currentAwesomeness[CFG_MINIMAP_DIVIDER] <= 0 && m_currentAwesomeness[CFG_LINEPREFIXAREA] > 0) {
         prefixBgColor := prefixFgColor := prefixEmColor := prefixFlags := 0;
         getColorFromProfile(scm, CFG_LINEPREFIXAREA, prefixBgColor, prefixFgColor, prefixEmColor, prefixFlags);
         linePrefixColor := interpolateColors(prefixBgColor, 0x808080);
         saveColorInProfile(scm, null, CFG_MINIMAP_DIVIDER, CFG_NULL, CFG_NULL, CFG_NULL, 
                            linePrefixColor, linePrefixColor);
      }

      // if we have a punctuation color, but no block matching color, just make block matching bold punctuation
      if (m_currentAwesomeness[CFG_BLOCK_MATCHING] <= 0 && m_currentAwesomeness[CFG_PUNCTUATION] > 0) {
         punctuationBgColor := punctuationFgColor := punctuationEmColor := punctuationFlags := 0;
         getColorFromProfile(scm, CFG_PUNCTUATION, punctuationBgColor, punctuationFgColor, punctuationEmColor, punctuationFlags);
         saveColorInProfile(scm, null, CFG_BLOCK_MATCHING, CFG_NULL, CFG_NULL, CFG_NULL, 
                              punctuationBgColor, punctuationFgColor, -1, F_BOLD);
      }

      // if we have an identifier color, but not a function color
      if (m_currentAwesomeness[CFG_FUNCTION] <= 0 && m_currentAwesomeness[CFG_IDENTIFIER] > 0) {
         identifierBgColor := identifierFgColor := identifierEmColor := identifierFlags := 0;
         getColorFromProfile(scm, CFG_IDENTIFIER, identifierBgColor, identifierFgColor, identifierEmColor, identifierFlags);
         saveColorInProfile(scm, null, CFG_FUNCTION, CFG_NULL, CFG_NULL, CFG_NULL, 
                              identifierBgColor, identifierFgColor, -1, F_BOLD);
      }
      if (m_currentAwesomeness[CFG_IDENTIFIER2] <= 0 && m_currentAwesomeness[CFG_IDENTIFIER] > 0) {
         identifierBgColor := identifierFgColor := identifierEmColor := identifierFlags := 0;
         getColorFromProfile(scm, CFG_IDENTIFIER2, identifierBgColor, identifierFgColor, identifierEmColor, identifierFlags);
         saveColorInProfile(scm, null, CFG_IDENTIFIER2, CFG_NULL, CFG_NULL, CFG_NULL, 
                              identifierBgColor, identifierFgColor);
      }

      // if we have an find highlight and a current line highlight, but not a current find highlight
      if (m_currentAwesomeness[CFG_DOCUMENTATION] > 0) {
         documentationBgColor := documentationFgColor := documentationEmColor := documentationFlags := 0;
         getColorFromProfile(scm, CFG_DOCUMENTATION, documentationBgColor, documentationFgColor, documentationEmColor, documentationFlags);
           if (m_currentAwesomeness[CFG_DOC_KEYWORD] <= 0) {
              saveColorInProfile(scm, null, CFG_DOC_KEYWORD, CFG_NULL, CFG_NULL, CFG_NULL, 
                                 documentationBgColor, documentationFgColor,
                                 biasEmbeddedColor(m_canvasBgColor, m_canvasEmColor, documentationBgColor), F_BOLD);
           }
           if (m_currentAwesomeness[CFG_DOC_PUNCTUATION] <= 0) {
              saveColorInProfile(scm, null, CFG_DOC_PUNCTUATION, CFG_NULL, CFG_NULL, CFG_NULL, 
                                 documentationBgColor, documentationFgColor, 
                                 biasEmbeddedColor(m_canvasBgColor, m_canvasEmColor, documentationBgColor), F_BOLD);
           }
           if (m_currentAwesomeness[CFG_DOC_ATTRIBUTE] <= 0) {
              saveColorInProfile(scm, null, CFG_DOC_ATTRIBUTE, CFG_NULL, CFG_NULL, CFG_NULL,
                                 documentationBgColor, documentationFgColor, 
                                 biasEmbeddedColor(m_canvasBgColor, m_canvasEmColor, documentationBgColor), F_BOLD);
           }
           if (m_currentAwesomeness[CFG_DOC_ATTR_VALUE] <= 0) {
              saveColorInProfile(scm, null, CFG_DOC_ATTR_VALUE, CFG_NULL, CFG_NULL, CFG_NULL, 
                                 documentationBgColor, documentationFgColor,
                                 biasEmbeddedColor(m_canvasBgColor, m_canvasEmColor, documentationBgColor));
           }
      }

      // if we have an find highlight and a current line highlight, but not a current find highlight
      if (m_currentAwesomeness[CFG_INACTIVE_CODE] > 0) {
         inactiveBgColor := inactiveFgColor := inactiveEmColor := inactiveFlags := 0;
         getColorFromProfile(scm, CFG_INACTIVE_CODE, inactiveBgColor, inactiveFgColor, inactiveEmColor, inactiveFlags);
         if (m_currentAwesomeness[CFG_INACTIVE_KEYWORD] <= 0) {
            saveColorInProfile(scm, null, CFG_INACTIVE_KEYWORD, CFG_NULL, CFG_NULL, CFG_NULL, 
                               inactiveBgColor, inactiveFgColor, -1, F_BOLD);
         }
         if (m_currentAwesomeness[CFG_INACTIVE_COMMENT] <= 0) {
            saveColorInProfile(scm, null, CFG_INACTIVE_COMMENT, CFG_NULL, CFG_NULL, CFG_NULL, 
                               inactiveBgColor, inactiveFgColor, -1, F_ITALIC);
         }
      }

      // if we have documentation comment, but not the others
      if (m_currentAwesomeness[CFG_FUNCTION] <= 0 && m_currentAwesomeness[CFG_IDENTIFIER] > 0) {
         identifierBgColor := identifierFgColor := identifierEmColor := identifierFlags := 0;
         getColorFromProfile(scm, CFG_IDENTIFIER, identifierBgColor, identifierFgColor, identifierEmColor, identifierFlags);
         saveColorInProfile(scm, null, CFG_BLOCK_MATCHING, CFG_NULL, CFG_NULL, CFG_NULL, 
                            identifierBgColor, identifierFgColor, -1, F_BOLD);
      }

      // if we have documentation comment, but not the others
      if (m_currentAwesomeness[CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND] <= 0 && m_currentAwesomeness[CFG_ERROR] > 0) {
         errorBgColor := errorFgColor := errorEmColor := errorFlags := 0;
         getColorFromProfile(scm, CFG_ERROR, errorBgColor, errorFgColor, errorEmColor, errorFlags);
         saveColorInProfile(scm, null, CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND, CFG_NULL, CFG_NULL, CFG_NULL, 
                            errorBgColor, errorFgColor);
      }
   }

   /**
    * use this to keep track of best color settings when there are duplicates
    */
   protected int m_currentAwesomeness[];

   /**
    * use these to keep track of default window text background and embedded colors
    */
   protected int m_canvasBgColor = 0xffffff;
   protected int m_canvasFgColor = 0x000000;
   protected int m_canvasEmColor = 0xd0d0d0;

   /**
    * Default constructor.
    */
   ColorImport() {
      for (i:=CFG_NULL; i<CFG_LAST_COLOR_PLUS_ONE; i++) {
         m_currentAwesomeness[i] = 0;
      }
   }
      
};

/**
 * Implementation of color importer for Visual Studio VSSettings color themes.
 */
class ColorImporterForVisualStudioSettings : ColorImport {
   
   /**
    * Get the list of color definition nodes from the color theme file.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catNode       category node to get colors from 
    * @param catName       category name 
    * @param colorIndexes  (output) array of index of color nodes 
    *  
    * @note 
    * This function needs to be overloaded.
    */
   protected void getColorIndexes(int fileHandle, int catNode, _str catName, int (&colorIndexes)[]) {
      _xmlcfg_find_simple_array(fileHandle, "/UserSettings/Category/Category/FontsAndColors/Categories/Category/Items/Item", auto strColorIndexes);
      foreach (auto i in strColorIndexes) {
         if (!isinteger(i)) continue;
         colorIndexes :+= (int)i;
      }
   }

   /**
    * Get the background color, foreground color, and font flags for this color 
    * description node. 
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to extract information from
    * @param bgColor       (output) background color
    * @param fgColor       (output) foreground color
    * @param fontFlags     (output) font flags
    * 
    * @return 0 on success, &lt;0 on error.
    *  
    * @note 
    * This function must be overloaded. 
    */
   protected int getColorFromNode(int fileHandle, int colorNode, _str colorName, int &bgColor, int &fgColor, int &fontFlags) {

      fgString := _xmlcfg_get_attribute(fileHandle, colorNode, "Foreground");
      bgString := _xmlcfg_get_attribute(fileHandle, colorNode, "Background");
      bold := _xmlcfg_get_attribute(fileHandle, colorNode, "BoldFont");
      italic := _xmlcfg_get_attribute(fileHandle, colorNode, "ItalicFont");
      underline := _xmlcfg_get_attribute(fileHandle, colorNode, "UnderlineFont");
      strikeout := _xmlcfg_get_attribute(fileHandle, colorNode, "StrikeoutFont");

      if (fgString == "0x02000000") {
         fgColor = m_canvasFgColor;
      } else if (fgString != "") {
         fgColor = _hex2dec(fgString);
         fgColor = ColorInfo.parseColorValue('#':+_dec2hex(fgColor & 0xFFFFFF));
      }
      if (bgString == "0x02000000") {
         bgColor = m_canvasBgColor;
      } else if (bgString != "") {
         bgColor = _hex2dec(bgString);
         bgColor = ColorInfo.parseColorValue('#':+_dec2hex(bgColor & 0xFFFFFF));
      }

      if (lowcase(bold) == "yes") {
         fontFlags |= F_BOLD;
      } else if (lowcase(bold) == "no") {
         fontFlags &= ~F_BOLD;
      }
      if (lowcase(italic) == "yes") {
         fontFlags |= F_ITALIC;
      } else if (lowcase(italic) == "no") {
         fontFlags &= ~F_ITALIC;
      }
      if (lowcase(underline) == "yes") {
         fontFlags |= F_UNDERLINE;
      } else if (lowcase(underline) == "no") {
         fontFlags &= ~F_UNDERLINE;
      }
      if (lowcase(strikeout) == "yes") {
         fontFlags |= F_STRIKE_THRU;
      } else if (lowcase(strikeout) == "no") {
         fontFlags &= ~F_STRIKE_THRU;
      }

      if (bgString == "" && fgString == "") {
         return STRING_NOT_FOUND_RC;
      }
      return 0;
   }

   /** 
    * @return 
    * Return the name of the given color definition node.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to get name of
    * 
    * @note 
    * This function usually needs to be overloaded.
    */
   protected _str getColorName(int fileHandle, int colorNode) {
      return _xmlcfg_get_attribute(fileHandle, colorNode, "Name");
   }

   /**
    * @return 
    * Returns the color constant (CFG_*) mapped from the given color category 
    * and color name.  It can also return up to three more color constants, for 
    * related colors that should be set along with a given color, such as the 
    * closely related string and number color constants. 
    * 
    * @param catName        color category name
    * @param colorName      color names
    * @param cfg2           (output) alternate color constant (CFG_*)
    * @param cfg3           (output) alternate color constant (CFG_*)
    * @param cfg4           (output) alternate color constant (CFG_*)
    * @param awesomeness    Rating form 0 .. 10 on how sure we are about this color
    * 
    * @note 
    * This function must be overloaded. 
    *  
    * @note 
    * The 'awesomeness' parameter helps us sort out when there are multiple 
    * color categories and color names that could map to the same color constant. 
    * It allows us to rank the ones that are there and select the best one to use.
    */
   protected int getColorFromName(_str catName, _str colorName, 
                                  int &cfg2, int &cfg3, int &cfg4, 
                                  int &awesomeness) {

      // initialize everything
      cfg := cfg2 = cfg3 = cfg4 = CFG_NULL;
      awesomeness = 1;

      switch (colorName) {
      case "Plain Text":
         cfg = CFG_WINDOW_TEXT;
         cfg2 = CFG_PUNCTUATION;
         cfg3 = CFG_IDENTIFIER;
         cfg4 = CFG_IDENTIFIER2;
         awesomeness = 10;
         break;
      case "Comment":
      case "Comments":
         cfg = CFG_COMMENT;
         cfg = CFG_LINE_COMMENT;
         cfg3 = CFG_DOCUMENTATION;
         awesomeness = 10;
         break;
      case "Selected Text":
         cfg = CFG_SELECTION;
         awesomeness = 10;
         break;
      case "Brace Matching (Rectangle)":
         cfg = CFG_BLOCK_MATCHING;
         awesomeness = 10;
         break;
      case "Identifier":
         cfg = CFG_IDENTIFIER;
         cfg2 = CFG_IDENTIFIER2;
         break;
      case "Number":
         cfg = CFG_NUMBER;
         cfg2 = CFG_FLOATING_NUMBER;
         cfg3 = CFG_HEX_NUMBER;
         awesomeness = 5;
         break;
      case "Operator":
         cfg = CFG_OPERATOR;
         cfg2 = CFG_PUNCTUATION;
         awesomeness = 10;
         break;
      case "String":
         cfg = CFG_STRING;
         cfg2 = CFG_UNTERMINATED_STRING;
         cfg3 = CFG_SINGLEQUOTED_STRING;
         cfg4 = CFG_BACKQUOTED_STRING;
         awesomeness = 10;
         break;
      case "String(C# @ Verbatim)":
         cfg = CFG_BACKQUOTED_STRING;
         awesomeness = 11;
         break;
      case "urlformat":
         cfg = CFG_NAVHINT;
         break;
      case "User Types":
         cfg = CFG_USER_DEFINED;
         awesomeness = 10;
         break;
      case "User Types(Enums)":
         cfg = CFG_SYMBOL_COLOR_ENUMERATED_TYPE;
         cfg2 = CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT;
         break;
      case "User Types(Interfaces)":
         cfg = CFG_SYMBOL_COLOR_INTERFACE_CLASS;
         break;
      case "User Types(Delegates)":
         break;
      case "User Types(Value types)":
         cfg = CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_GLOBAL_VARIABLE;
         cfg3 = CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE;
         cfg4 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE;
         break;
      case "Indicator Margin":
         cfg = CFG_LINEPREFIXAREA;
         break;
      case "Line Numbers":
         cfg = CFG_LINENUM;
         awesomeness = 10;
         break;
      case "Preprocessor Keyword":
         cfg = CFG_PPKEYWORD;
         awesomeness = 10;
         break;
      case "Keyword":
         cfg = CFG_KEYWORD;
         awesomeness = 10;
         break;
      case "XML Doc Comment":
         cfg = CFG_DOCUMENTATION;
         cfg2 = CFG_DOC_ATTR_VALUE;
         cfg3 = CFG_DOC_KEYWORD;
         cfg4 = CFG_DOC_PUNCTUATION;
         break;
      case "XML Doc Tag":
         cfg = CFG_DOC_KEYWORD;
         break;
      case "CurrentLineActiveFormat":
         cfg = CFG_CLINE;
         awesomeness = 5;
         break;
      case "CurrentLineInactiveFormat":
         break;
      case "CSS Comment":
         break;
      case "CSS Keyword":
         cfg = CFG_CSS_CLASS;
         break;
      case "CSS Property Name":
         cfg = CFG_CSS_PROPERTY;
         break;
      case "CSS Property Value":
         cfg = CFG_CSS_ELEMENT;
         break;
      case "CSS Selector":
         cfg = CFG_CSS_SELECTOR;
         break;
      case "CSS String Value":
         break;
      case "HTML Attribute":
         cfg = CFG_ATTRIBUTE;
         cfg2 = CFG_UNKNOWN_ATTRIBUTE;
         break;
      case "HTML Attribute Value":
         break;
      case "HTML Comment":
         break;
      case "HTML Element Name":
         cfg = CFG_TAG;
         break;
      case "HTML Entity":
         cfg = CFG_XML_CHARACTER_REF;
         break;
      case "HTML Operator":
         break;
      case "HTML Server-Side Script":
         cfg = -CFG_WINDOW_TEXT;
         cfg2 = -CFG_PUNCTUATION;
         cfg3 = -CFG_IDENTIFIER;
         cfg4 = -CFG_IDENTIFIER2;
         break;
      case "HTML Tag Delimiter":
         break;
      case "Razor Code":
         break;
      case "Script Comment":
         cfg = -CFG_COMMENT;
         cfg2 = -CFG_LINE_COMMENT;
         cfg3 = -CFG_DOCUMENTATION;
         break;
      case "Script Identifier":
         cfg = -CFG_IDENTIFIER;
         cfg2 = -CFG_IDENTIFIER2;
         break;
      case "Script Keyword":
         cfg = -CFG_KEYWORD;
         break;
      case "Script Number":
         cfg = -CFG_NUMBER;
         break;
      case "Script Operator":
         cfg = -CFG_OPERATOR;
         break;
      case "Script String":
         cfg = -CFG_STRING;
         cfg2 = -CFG_SINGLEQUOTED_STRING;
         break;
      case "XML Attribute":
         cfg = CFG_ATTRIBUTE;
         cfg2 = CFG_UNKNOWN_ATTRIBUTE;
         break;
      case "XML Attribute Quotes":
         break;
      case "XML Attribute Value":
         break;
      case "XML CData Section":
         break;
      case "XML Comment":
         cfg = CFG_COMMENT;
         break;
      case "XML Delimiter":
         break;
      case "XML Name":
         cfg = CFG_TAG;
         cfg = CFG_UNKNOWN_TAG;
         awesomeness = 10;
         break;
      case "XML Keyword":
         cfg = CFG_TAG;
         break;
      case "XML Text":
         break;
      case "XML Processing Instruction":
         break;
      case "XSLT Keyword":
         cfg = CFG_XHTMLELEMENTINXSL;
         break;
      case "XAML Text":
         cfg = CFG_YAML_TEXT;
         break;
      case "XAML Keyword":
         cfg = CFG_YAML_TAG;
         break;
      case "XAML Delimiter":
         cfg = CFG_YAML_PUNCTUATION;
         break;
      case "XAML Comment":
      case "XAML Name":
      case "XAML Attribute":
      case "XAML CData Section":
         break;
      case "XAML Processing Instruction":
         cfg = CFG_YAML_DIRECTIVE;
         break;
      case "XAML Attribute Value":
      case "XAML Attribute Quotes":
      case "XAML Markup Extension Class":
      case "XAML Markup Extension Parameter Name":
      case "XAML Markup Extension Parameter Value":
         break;
      case "Inactive Selected Text":
         cfg = CFG_SELECTED_CLINE;
         break;
      case "outlining.square":
         cfg = CFG_MARGINS_COL_LINE;
         cfg2 = CFG_SELECTIVE_DISPLAY_LINE;
         awesomeness = 5;
         break;
      case "outlining.verticalrule":
         cfg = CFG_SELECTIVE_DISPLAY_LINE;
         cfg2 = CFG_MARGINS_COL_LINE;
         awesomeness = 5;
         break;
      case "Syntax Error":
         cfg = CFG_ERROR;
         awesomeness = 1;
         break;
      case "Compiler Error":
         cfg = CFG_ERROR;
         awesomeness = 5;
         break;
      case "Warning":
         cfg = CFG_ERROR;
         break;
      case "outlining.collapsehintadornment":
         //cfg = CFG_SELECTIVE_DISPLAY_LINE;
         break;
      case "Collapsible Text":
         break;
      case "Excluded Code":
         cfg = CFG_INACTIVE_CODE;
         cfg3 = CFG_INACTIVE_KEYWORD;
         cfg4 = CFG_INACTIVE_COMMENT;
         break;
      case "MarkerFormatDefinition/HighlightedReference":
         cfg = CFG_HILIGHT;
         break;
      case "Breakpoint (Enabled)":
         break;
      case "Current Statement":
         cfg = CFG_CLINE;
         awesomeness = 1;
         break;

      case "CppMacroSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO;
         break;
      case "CppEnumSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_ENUMERATED_TYPE;
         break;
      case "CppGlobalVariableSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_GLOBAL_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE;
         break;
      case "CppLocalVariableSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE;
         break;
      case "CppParameterSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_PARAMETER;
         break;
      case "CppTypeSemanticTokenFormat":
      case "CppRefTypeSemanticTokenFormat":
      case "CppValueTypeSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS;
         break;
      case "CppFunctionSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_GLOBAL_FUNCTION;
         cfg2 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION;
         break;
      case "CppMemberFunctionSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION;
         break;
      case "CppMemberFieldSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE;
         break;
      case "CppStaticMemberFunctionSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION;
         break;
      case "CppStaticMemberFieldSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE;
         break;
      case "CppPropertySemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY;
         break;
      case "CppEventSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_EVENT_TABLE;
         break;
      case "CppClassTemplateSemanticTokenFormat":
      case "CppGenericTypeSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_TEMPLATE_CLASS;
         break;
      case "CppFunctionTemplateSemanticTokenFormat":
         break;
      case "CppNamespaceSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE;
         break;
      case "CppLabelSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_STATEMENT_LABEL;
         break;
      case "CppUDLRawSemanticTokenFormat":
      case "CppUDLNumberSemanticTokenFormat":
      case "CppUDLStringSemanticTokenFormat":
      case "CppOperatorSemanticTokenFormat":
      case "CppMemberOperatorSemanticTokenFormat":
         break;
      case "CppNewDeleteSemanticTokenFormat":
         cfg = CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR;
         cfg2 = CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR;
         break;
      case "CppSuggestedActionFormat":
         break;
      case "C/C++ User Keywords":
         cfg = CFG_USER_DEFINED;
         break;
      case "Markdown Heading":
         cfg = CFG_MARKDOWN_HEADER;
         break;
      case "Markdown Blockquote":
         cfg = CFG_MARKDOWN_BLOCKQUOTE;
         break;
      case "Markdown Bold Text":
         cfg = CFG_MARKDOWN_EMPHASIS2;
         break;
      case "Markdown Italic Text":
         cfg = CFG_MARKDOWN_EMPHASIS;
         break;
      case "Markdown Bold Italic Text":
         cfg = CFG_MARKDOWN_EMPHASIS3;
         break;
      case "Markdown List Item":
         cfg = CFG_MARKDOWN_BULLET;
         break;
      case "Markdown Monospace":
         cfg = CFG_MARKDOWN_CODE;
         break;
      case "Markdown Alt Text":
         cfg = CFG_MARKDOWN_BLOCKQUOTE;
         break;
      case "Markdown Code Background":
         break;
      case "deltadiff.remove.line":
         cfg = CFG_IMAGINARY_LINE;
         awesomeness = 5;
         break;
      case "deltadiff.add.line":
         cfg = CFG_INSERTED_LINE;
         awesomeness = 5;
         break;
      case "deltadiff.remove.word":
      case "deltadiff.add.word":
         cfg = CFG_MODIFIED_LINE;
         awesomeness = 5;
         break;
      default:
         break;
      }

      return cfg;
   }

};

/**
 * Implementation of color importer for Visual Studio XML color themes 
 * used by the Visual Studio VSIX Color Scheme compiler. 
 */
class ColorImporterForVisualStudioVSIX : ColorImport {
   
   /**
    * Get the list of color category nodes from the color theme file.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catIndexes    (output) array of index of category nodes 
    *  
    * @note 
    * This function usually needs to be overloaded. <br>
    * The default version of this function just creates an array {0}, serving 
    * as a placeholder for color themes which do not have categories. 
    */
   protected void getCategoryIndexes(int fileHandle, int (&catIndexes)[]) {
      _xmlcfg_find_simple_array(fileHandle, "/Themes/Theme/Category", auto strCatIndexes);
      foreach (auto i in strCatIndexes) {
         if (!isinteger(i)) continue;
         catIndexes :+= (int)i;
      }
   }

   /** 
    * @return 
    * Return the name of the given category node.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catNode       category node to get name of
    * 
    * @note 
    * This function usually needs to be overloaded. <br>
    * The default version of this function just returns ""
    */
   protected _str getCategoryName(int fileHandle, int catNode) {
      return _xmlcfg_get_attribute(fileHandle, catNode, "Name");
   }

   /**
    * Get the list of color definition nodes from the color theme file.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catNode       category node to get colors from 
    * @param catName       category name 
    * @param colorIndexes  (output) array of index of color nodes 
    *  
    * @note 
    * This function needs to be overloaded.
    */
   protected void getColorIndexes(int fileHandle, int catNode, _str catName, int (&colorIndexes)[]) {
      _xmlcfg_find_simple_array(fileHandle, "Color", auto strColorIndexes, catNode);
      foreach (auto i in strColorIndexes) {
         if (!isinteger(i)) continue;
         colorIndexes :+= (int)i;
      }
   }

   /**
    * Get the background color, foreground color, and font flags for this color 
    * description node. 
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to extract information from
    * @param bgColor       (output) background color
    * @param fgColor       (output) foreground color
    * @param fontFlags     (output) font flags
    * 
    * @return 0 on success, &lt;0 on error.
    *  
    * @note 
    * This function must be overloaded. 
    */
   protected int getColorFromNode(int fileHandle, int colorNode, _str colorName, int &bgColor, int &fgColor, int &fontFlags) {
      // get the background color
      bgIndex := _xmlcfg_find_child_with_name(fileHandle, (int)colorNode, "Background");
      if (bgIndex > 0) {
         type := _xmlcfg_get_attribute(fileHandle, bgIndex, "Type");
         if (type == "" || type == "CT_RAW") {
            source := _xmlcfg_get_attribute(fileHandle, bgIndex, "Source");
            bgColor = _hex2dec(substr(source,3));
         } else if (type == "CT_AUTOMATIC") {
            fontFlags |= F_INHERIT_BG_COLOR;
         }
      }
      // get the foreground color
      fgIndex := _xmlcfg_find_child_with_name(fileHandle, (int)colorNode, "Foreground");
      if (fgIndex > 0) {
         type := _xmlcfg_get_attribute(fileHandle, fgIndex, "Type");
         if (type == "" || type == "CT_RAW") {
            source := _xmlcfg_get_attribute(fileHandle, fgIndex, "Source");
            fgColor = _hex2dec(substr(source,3));
         } else if (type == "CT_AUTOMATIC") {
            fontFlags |= F_INHERIT_FG_COLOR;
         }
      }
      if (bgIndex <= 0 && fgIndex <= 0) {
         return STRING_NOT_FOUND_RC;;
      }
      return 0;
   }

   /** 
    * @return 
    * Return the name of the given color definition node.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to get name of
    * 
    * @note 
    * This function usually needs to be overloaded.
    */
   protected _str getColorName(int fileHandle, int colorNode) {
      return _xmlcfg_get_attribute(fileHandle, colorNode, "Name");
   }

   /**
    * @return 
    * Returns the color constant (CFG_*) mapped from the given color category 
    * and color name.  It can also return up to three more color constants, for 
    * related colors that should be set along with a given color, such as the 
    * closely related string and number color constants. 
    * 
    * @param catName        color category name
    * @param colorName      color names
    * @param cfg2           (output) alternate color constant (CFG_*)
    * @param cfg3           (output) alternate color constant (CFG_*)
    * @param cfg4           (output) alternate color constant (CFG_*)
    * @param awesomeness    Rating form 0 .. 10 on how sure we are about this color
    * 
    * @note 
    * This function must be overloaded. 
    *  
    * @note 
    * The 'awesomeness' parameter helps us sort out when there are multiple 
    * color categories and color names that could map to the same color constant. 
    * It allows us to rank the ones that are there and select the best one to use.
    */
   protected int getColorFromName(_str catName, _str colorName, 
                                  int &cfg2, int &cfg3, int &cfg4, 
                                  int &awesomeness) {

      // initialize everything
      cfg := cfg2 = cfg3 = cfg4 = CFG_NULL;
      awesomeness = 1;

      switch (catName) {
      case "Autos":
         switch (colorName) {
         case "ChangedText":
            cfg = CFG_MODIFIED_ITEM;
            break;
         }
         break;
      case "Environment":
         switch (colorName) {
         case "EnvironmentBackground":
            cfg = CFG_WINDOW_TEXT;
            cfg2 = CFG_PUNCTUATION;
            cfg3 = CFG_IDENTIFIER;
            cfg4 = CFG_IDENTIFIER2;
            awesomeness = 10;
            break;
         }
      case "ColorizedSignatureHelp colors":
         switch (colorName) {
         case "Type":
            cfg = CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS;
            break;
         case "Excluded Code":
            cfg = CFG_INACTIVE_CODE;
            cfg3 = CFG_INACTIVE_KEYWORD;
            cfg4 = CFG_INACTIVE_COMMENT;
            awesomeness = 5;
            break;
         case "Preprocessor Keyword":
            cfg = CFG_PPKEYWORD;
            break;
         case "Operator":
            cfg = CFG_OPERATOR;
            awesomeness = 10;
            break;
         case "Literal":
            cfg = CFG_NUMBER;
            cfg2 = CFG_FLOATING_NUMBER;
            cfg3 = CFG_HEX_NUMBER;
            awesomeness = 5;
            break;
         case "deltadiff.remove.line":
            cfg = CFG_IMAGINARY_LINE;
            awesomeness = 5;
            break;
         case "deltadiff.add.line":
            cfg = CFG_INSERTED_LINE;
            awesomeness = 5;
            break;
         case "deltadiff.remove.word":
         case "deltadiff.add.word":
            cfg = CFG_MODIFIED_LINE;
            awesomeness = 5;
            break;
         case "CSS Keyword":
            cfg = CFG_CSS_ELEMENT;
            break;
         case "CSS Comment":
            //cfg = CFG_COMMENT;
            break;
         case "CSS Selector":
            cfg = CFG_CSS_SELECTOR;
            break;
         case "CSS Property Name":
            cfg = CFG_CSS_PROPERTY;
            break;
         case "CSS Property Value":
            cfg = CFG_CSS_PROPERTY;
            break;
         case "CSS String Value":
            //cfg = CFG_STRING;
            break;
         case "HTML Attribute":
            cfg = CFG_ATTRIBUTE;
            cfg2 = CFG_UNKNOWN_ATTRIBUTE;
            awesomeness = 5;
            break;
         case "HTML Attribute Value":
            //cfg = CFG_STRING;
            break;
         case "HTML Comment":
            //cfg = CFG_COMMENT;
            break;
         case "HTML Element Name":
            cfg = CFG_TAG;
            awesomeness = 5;
            break;
         case "HTML Entity":
            cfg = CFG_XML_CHARACTER_REF;
            break;
         case "HTML Operator":
            break;
         case "HTML Server-Side Script":
            cfg = -CFG_WINDOW_TEXT;
            cfg2 = -CFG_PUNCTUATION;
            cfg3 = -CFG_IDENTIFIER;
            cfg4 = -CFG_IDENTIFIER2;
            break;
         case "HTML Tag Delimiter":
            break;
         case "VBScript Keyword":
            cfg = -CFG_KEYWORD;
            break;
         case "VBScript Comment":
            cfg = -CFG_COMMENT;
            cfg2 = -CFG_LINE_COMMENT;
            break;
         case "VBScript Operator":
            cfg = -CFG_OPERATOR;
            break;
         case "VBScript Number":
            cfg = -CFG_NUMBER;
            cfg2 = CFG_FLOATING_NUMBER;
            cfg3 = CFG_HEX_NUMBER;
            break;
         case "VBScript String":
            cfg = -CFG_STRING;
            cfg2 = -CFG_UNTERMINATED_STRING;
            cfg3 = -CFG_SINGLEQUOTED_STRING;
            break;
         case "VBScript Identifier":
            cfg = -CFG_IDENTIFIER;
            break;
         case "VBScript Function Block Start":
            cfg = -CFG_PUNCTUATION;
            break;
         case "FileLineClassificationFormat":
         case "InstructionLineClassificationFormat":
         case "SourceLineClassificationFormat":
         case "SymbolLineClassificationFormat":
            cfg = CFG_LINENUM;
            break;
         case "CodeAnalysisCurrentStatementSelection":
            cfg = CFG_SELECTED_CLINE;
            break;
         case "punctuation":
            cfg = CFG_PUNCTUATION;
            awesomeness = 10;
            break;
         case "interface name":
            cfg = CFG_SYMBOL_COLOR_INTERFACE_CLASS;
            break;
         case "type parameter name":
            cfg = CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER;
            break;
         case "enum name":
            cfg = CFG_SYMBOL_COLOR_ENUMERATED_TYPE;
            cfg2 = CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT;
            break;
         case "module name":
            cfg = CFG_SYMBOL_COLOR_MODULE;
            break;
         case "class name":
            cfg = CFG_SYMBOL_COLOR_CLASS;
            cfg3 = CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR;
            cfg4 = CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR;
            break;
         case "delegate name":
            break;
         case "struct name":
            cfg = CFG_SYMBOL_COLOR_STRUCT;
            cfg2 = CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE;
            break;
         case "string - verbatim":
            cfg = CFG_BACKQUOTED_STRING;
            break;
         case "preprocessor text":
            cfg = CFG_INACTIVE_CODE;
            cfg3 = CFG_INACTIVE_KEYWORD;
            cfg4 = CFG_INACTIVE_COMMENT;
            break;
         case "MarkerFormatDefinition/HighlightedDefinition":
            cfg = CFG_HILIGHT;
            break;
         case "xml doc comment - attribute name":
            cfg = CFG_DOC_ATTRIBUTE;
            break;
         case "xml doc comment - attribute quotes":
         case "xml doc comment - attribute value":
            cfg = CFG_DOC_ATTR_VALUE;
            break;
         case "xml doc comment - cdata section":
            break;
         case "xml doc comment - comment":
            break;
         case "xml doc comment - delimiter":
            cfg = CFG_DOC_PUNCTUATION;
            break;
         case "xml doc comment - entity reference":
         case "xml doc comment - name":
            cfg = CFG_DOC_KEYWORD;
            break;
         case "xml doc comment - processing instruction":
            break;
         case "xml doc comment - text":
            cfg = CFG_DOCUMENTATION;
            cfg2 = CFG_DOC_ATTR_VALUE;
            cfg3 = CFG_DOC_KEYWORD;
            cfg4 = CFG_DOC_PUNCTUATION;
            break;
         case "xml literal - attribute name":
            cfg = CFG_ATTRIBUTE;
            cfg2 = CFG_UNKNOWN_ATTRIBUTE;
            awesomeness = 5;
            break;
         case "xml literal - attribute quotes":
            //cfg = CFG_STRING;
            break;
         case "xml literal - attribute value":
            //cfg = CFG_STRING;
            break;
         case "xml literal - cdata section":
            break;
         case "xml literal - comment":
            //cfg = CFG_COMMENT;
            break;
         case "xml literal - delimiter":
            //cfg = CFG_PUNCTUATION;
            break;
         case "xml literal - embedded expression":
            //cfg = -CFG_WINDOW_TEXT;
            break;
         case "xml literal - entity reference":
            //cfg = CFG_XML_CHARACTER_REF;
            break;
         case "xml literal - name":
            //cfg = CFG_KEYWORD;
            break;
         case "xml literal - processing instruction":
            // cfg = CFG_PPKEYWORD;
            break;
         case "xml literal - text":
            // cfg = CFG_WINDOW_TEXT;
            break;
         case "MarkerFormatDefinition/HighlightedWrittenReference":
            cfg = CFG_HILIGHT;
            break;
         case "brace matching":
            cfg = CFG_BLOCK_MATCHING;
            awesomeness = 10;
            break;
         case "Stale Code":
            cfg = CFG_INACTIVE_CODE;
            cfg3 = CFG_INACTIVE_KEYWORD;
            cfg4 = CFG_INACTIVE_COMMENT;
            awesomeness = 2;
            break;
         case "data.tools.diff.remove.line":
            cfg = CFG_IMAGINARY_LINE;
            break;
         case "data.tools.diff.add.line":
            cfg = CFG_INSERTED_LINE;
            break;
         case "data.tools.diff.remove.word":
         case "data.tools.diff.add.word":
            cfg = CFG_MODIFIED_LINE;
            break;
         case "Line Number":
            cfg = CFG_LINENUM;
            break;
         case "outlining.verticalrule":
            cfg = CFG_SELECTIVE_DISPLAY_LINE;
            cfg2 = CFG_MARGINS_COL_LINE;
            break;
         case "Selected Text in High Contrast":
            cfg = CFG_SELECTION;
            awesomeness = 5;
            break;
         case "XML Doc Comment":
            cfg = CFG_DOCUMENTATION;
            cfg2 = CFG_DOC_ATTR_VALUE;
            cfg3 = CFG_DOC_KEYWORD;
            cfg4 = CFG_DOC_PUNCTUATION;
            break;
         case "XML Doc Tag":
            cfg = CFG_DOC_KEYWORD;
            break;
         case "MarkerFormatDefinition/VerticalHighlight":
            cfg = CFG_VERTICAL_COL_LINE;
            break;
         case "Python Interactive - Error":
         case "Node.js Interactive - Error":
            cfg = CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND;
            break;
         case "Python Interactive - Black":
         case "Node.js Interactive - Black":
            cfg = CFG_SYMBOL_COLOR_PALETTE_00;
            break;
         case "Python Interactive - DarkRed":
         case "Node.js Interactive - DarkRed":
            cfg = CFG_SYMBOL_COLOR_PALETTE_01;
            break;
         case "Python Interactive - DarkGreen":
         case "Node.js Interactive - DarkGreen":
            cfg = CFG_SYMBOL_COLOR_PALETTE_02;
            break;
         case "Python Interactive - DarkYellow":
         case "Node.js Interactive - DarkYellow":
            cfg = CFG_SYMBOL_COLOR_PALETTE_03;
            break;
         case "Python Interactive - DarkBlue":
         case "Node.js Interactive - DarkBlue":
            cfg = CFG_SYMBOL_COLOR_PALETTE_04;
            break;
         case "Python Interactive - DarkMagenta":
         case "Node.js Interactive - DarkMagenta":
            cfg = CFG_SYMBOL_COLOR_PALETTE_05;
            break;
         case "Python Interactive - DarkCyan":
         case "Node.js Interactive - DarkCyan":
            cfg = CFG_SYMBOL_COLOR_PALETTE_06;
            break;
         case "Python Interactive - Gray":
         case "Node.js Interactive - Gray":
            cfg = CFG_SYMBOL_COLOR_PALETTE_07;
            break;
         case "Python Interactive - DarkGray":
         case "Node.js Interactive - DarkGray":
            cfg = CFG_SYMBOL_COLOR_PALETTE_08;
            break;
         case "Python Interactive - Red":
         case "Node.js Interactive - Red":
            cfg = CFG_SYMBOL_COLOR_PALETTE_09;
            break;
         case "Python Interactive - Green":
         case "Node.js Interactive - Green":
            cfg = CFG_SYMBOL_COLOR_PALETTE_10;
            break;
         case "Python Interactive - Yellow":
         case "Node.js Interactive - Yellow":
            cfg = CFG_SYMBOL_COLOR_PALETTE_11;
            break;
         case "Python Interactive - Blue":
         case "Node.js Interactive - Blue":
            cfg = CFG_SYMBOL_COLOR_PALETTE_12;
            break;
         case "Python Interactive - Magenta":
         case "Node.js Interactive - Magenta":
            cfg = CFG_SYMBOL_COLOR_PALETTE_13;
            break;
         case "Python Interactive - Cyan":
         case "Node.js Interactive - Cyan":
            cfg = CFG_SYMBOL_COLOR_PALETTE_14;
            break;
         case "Python Interactive - White":
         case "Node.js Interactive - White":
            cfg = CFG_SYMBOL_COLOR_PALETTE_15;
            break;
         case "UnnecessaryCode":
            break;
         case "keyword - control":
            cfg = CFG_KEYWORD;
            awesomeness = 5;
            break;
         case "operator - overloaded":
            cfg = CFG_OPERATOR;
            awesomeness = 5;
            break;
         case "field name":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE;
            break;
         case "enum member name":
            cfg = CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT;
            break;
         case "constant name":
            cfg = CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT;
            break;
         case "local name":
            cfg = CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
            break;
         case "parameter name":
            cfg = CFG_SYMBOL_COLOR_PARAMETER;
            break;
         case "method name":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION;
            break;
         case "extension method name":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION;
            break;
         case "property name":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY;
            break;
         case "event name":
            cfg = CFG_SYMBOL_COLOR_EVENT_TABLE;
            break;
         case "namespace name":
            cfg = CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE;
            break;
         case "label name":
            cfg = CFG_SYMBOL_COLOR_STATEMENT_LABEL;
            break;
         case "urlformat":
            cfg = CFG_NAVHINT;
            break;
         case "CppMacroSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO;
            break;
         case "CppEnumSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_ENUMERATED_TYPE;
            cfg2 = CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT;
            break;
         case "CppGlobalVariableSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_GLOBAL_VARIABLE;
            cfg2 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE;
            break;
         case "CppLocalVariableSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
            cfg2 = CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE;
            break;
         case "CppParameterSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_PARAMETER;
            break;
         case "CppTypeSemanticTokenFormat":
         case "CppRefTypeSemanticTokenFormat":
         case "CppValueTypeSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS;
            break;
         case "CppFunctionSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_GLOBAL_FUNCTION;
            cfg2 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION;
            break;
         case "CppMemberFunctionSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION;
            break;
         case "CppMemberFieldSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE;
            break;
         case "CppStaticMemberFunctionSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION;
            break;
         case "CppStaticMemberFieldSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE;
            break;
         case "CppPropertySemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_PUBLIC_CLASS_PROPERTY;
            cfg2 = CFG_SYMBOL_COLOR_PACKAGE_CLASS_PROPERTY;
            cfg3 = CFG_SYMBOL_COLOR_PROTECTED_CLASS_PROPERTY;
            cfg4 = CFG_SYMBOL_COLOR_PRIVATE_CLASS_PROPERTY;
            break;
         case "CppEventSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_EVENT_TABLE;
            break;
         case "CppClassTemplateSemanticTokenFormat":
         case "CppGenericTypeSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_TEMPLATE_CLASS;
            break;
         case "CppFunctionTemplateSemanticTokenFormat":
            break;
         case "CppNamespaceSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_PACKAGE_OR_NAMESPACE;
            break;
         case "CppLabelSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_STATEMENT_LABEL;
            break;
         case "CppUDLRawSemanticTokenFormat":
         case "CppUDLNumberSemanticTokenFormat":
         case "CppUDLStringSemanticTokenFormat":
         case "CppOperatorSemanticTokenFormat":
         case "CppMemberOperatorSemanticTokenFormat":
            break;
         case "CppNewDeleteSemanticTokenFormat":
            cfg = CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR;
            cfg2 = CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR;
            break;
         case "CppSuggestedActionFormat":
            break;
         case "C/C++ User Keywords":
            cfg = CFG_USER_DEFINED;
            break;
         case "Markdown Heading":
            cfg = CFG_MARKDOWN_HEADER;
            break;
         case "Markdown Blockquote":
            cfg = CFG_MARKDOWN_BLOCKQUOTE;
            break;
         case "Markdown Bold Text":
            cfg = CFG_MARKDOWN_EMPHASIS2;
            break;
         case "Markdown Italic Text":
            cfg = CFG_MARKDOWN_EMPHASIS;
            break;
         case "Markdown Bold Italic Text":
            cfg = CFG_MARKDOWN_EMPHASIS3;
            break;
         case "Markdown List Item":
            cfg = CFG_MARKDOWN_BULLET;
            break;
         case "Markdown Monospace":
            cfg = CFG_MARKDOWN_CODE;
            break;
         case "Markdown Alt Text":
            cfg = CFG_MARKDOWN_BLOCKQUOTE;
            break;
         case "Markdown Code Background":
            break;
         }
         break;
      case "Text Editor Language Service Items":
         switch (colorName) {
         case "Keyword":
            cfg = CFG_KEYWORD;
            awesomeness = 10;
            break;
         case "Comment":
            cfg = CFG_COMMENT;
            cfg = CFG_LINE_COMMENT;
            cfg3 = CFG_DOCUMENTATION;
            awesomeness = 10;
            break;
         case "Identifier":
            cfg = CFG_IDENTIFIER;
            awesomeness = 10;
            break;
         case "String":
            cfg = CFG_STRING;
            cfg2 = CFG_UNTERMINATED_STRING;
            cfg3 = CFG_SINGLEQUOTED_STRING;
            awesomeness = 10;
            break;
         case "Number":
            cfg = CFG_NUMBER;
            cfg2 = CFG_FLOATING_NUMBER;
            cfg3 = CFG_HEX_NUMBER;
            awesomeness = 10;
            break;
         case "Text":
            cfg = CFG_WINDOW_TEXT;
            cfg2 = CFG_PUNCTUATION;
            cfg3 = CFG_IDENTIFIER;
            cfg4 = CFG_IDENTIFIER2;
            awesomeness = 10;
            break;
         case "SQL Stored Procedure":
            break;
         case "SQL System Table":
            cfg = CFG_SYMBOL_COLOR_DATABASE_TABLE;
            break;
         case "SQL System Function":
         case "SQL Operator":
         case "SQL String":
         case "SQLCMD Command":
            break;
         case "Error":
            cfg = CFG_ERROR;
            awesomeness = 1;
            break;
         case "XAML Text":
            cfg = CFG_YAML_TEXT;
            break;
         case "XAML Keyword":
            cfg = CFG_YAML_TAG;
            break;
         case "XAML Delimiter":
            cfg = CFG_YAML_PUNCTUATION;
            break;
         case "XAML Comment":
         case "XAML Name":
         case "XAML Attribute":
         case "XAML CData Section":
            break;
         case "XAML Processing Instruction":
            cfg = CFG_YAML_DIRECTIVE;
            break;
         case "XAML Attribute Value":
         case "XAML Attribute Quotes":
         case "XAML Markup Extension Class":
         case "XAML Markup Extension Parameter Name":
         case "XAML Markup Extension Parameter Value":
            break;
         case "XML Text":
         case "XML Keyword":
         case "XML Delimiter":
            break;
         case "XML Name":
            cfg = CFG_TAG;
            awesomeness = 10;
            break;
         case "XML Attribute":
            cfg = CFG_ATTRIBUTE;
            cfg2 = CFG_UNKNOWN_ATTRIBUTE;
            awesomeness = 10;
            break;
         case "XML Processing Instruction":
            break;
         case "XML Attribute Value":
         case "XML Attribute Quotes":
            break;
         case "XSLT Keyword":
            cfg = CFG_XHTMLELEMENTINXSL;
            break;
         case "Function":
            cfg = CFG_FUNCTION;
            break;
         }
         break;
      case "Text Editor Text Manager Items":
         switch (colorName) {
         case "Plain Text":
            cfg = CFG_WINDOW_TEXT;
            cfg2 = CFG_PUNCTUATION;
            cfg3 = CFG_IDENTIFIER;
            cfg4 = CFG_IDENTIFIER2;
            awesomeness = 5;
            break;
         case "Selected Text":
            cfg = CFG_SELECTION;
            awesomeness = 10;
            break;
         case "Inactive Selected Text":
            break;
         case "Indicator Margin":
            cfg = CFG_LINEPREFIXAREA;
            break;
         case "Line Number":
            cfg = CFG_LINENUM;
            awesomeness = 5;
            break;
         case "Visible Whitespace":
            //cfg = CFG_SPECIALCHARS;
            break;
         }
         break;
      case "JavascriptRequiredForMonacoEditor":
         switch (colorName) {
         case "ThemeColor":
            //cfg = CFG_WINDOW_TEXT;
            //haveWindowColor = true;
            break;
         case "PluginEditorSelectedTextBackgroundColor":
            cfg = CFG_SELECTION;
            awesomeness = 2;
            break;
         case "PluginFontEditorCommentColor":
            cfg = CFG_COMMENT;
            cfg = CFG_LINE_COMMENT;
            cfg3 = CFG_DOCUMENTATION;
            awesomeness = 2;
            break;
         case "PluginFontEditorCssNameColor":
            cfg = CFG_CSS_ELEMENT;
            break;
         case "PluginFontEditorCssSelectorColor":
            cfg = CFG_CSS_SELECTOR;
            break;
         case "PluginFontEditorCssValueColor":
            cfg = CFG_CSS_PROPERTY;
            break;
         case "PluginFontEditorHtmlAttributeNameColor":
            cfg = CFG_ATTRIBUTE;
            cfg2 = CFG_UNKNOWN_ATTRIBUTE;
            awesomeness = 2;
            break;
         case "PluginFontEditorHtmlElementColor":
         case "PluginFontEditorHtmlTagColor":
            cfg = CFG_TAG;
            awesomeness = 2;
            break;
         case "PluginFontEditorKeywordColor":
            cfg = CFG_KEYWORD;
            awesomeness = 2;
            break;
         case "PluginFontEditorLiteralColor":
            cfg = CFG_NUMBER;
            cfg2 = CFG_FLOATING_NUMBER;
            cfg3 = CFG_HEX_NUMBER;
            awesomeness = 2;
            break;
         case "PluginFontEditorMarginBackgroundColor":
            cfg = CFG_LINEPREFIXAREA;
            awesomeness = 2;
            break;
         case "PluginFontEditorStringColor":
            cfg = CFG_STRING;
            cfg2 = CFG_UNTERMINATED_STRING;
            cfg3 = CFG_SINGLEQUOTED_STRING;
            awesomeness = 2;
            break;
         case "PluginWordHighlightColor":
            cfg = CFG_INC_SEARCH_MATCH;
            awesomeness = 2;
            break;
         case "PluginWordHighlightStrongColor":
            cfg = CFG_INC_SEARCH_CURRENT;
            awesomeness = 2;
            break;
         }
         break;
      }
      return cfg;
   }

};

/**
 * Implementation of color importer for Atom / Sublime / VSCode / TextMate 
 * color themes (.tmTheme).
 */
class ColorImporterForAtom : ColorImport {
   
   /**
    * Import a color theme from the given file and populate the given 
    * color profile object. 
    *  
    * @note 
    * This function is implemented in a pretty generic manner, calling 
    * out to virtual functions to do most of the work.  however, this 
    * function itself can also be overloaded and implemented in any manner 
    * necessary, for example, if importing from a color theme file which is 
    * not XML.
    * 
    * @param scm              color profile
    * @param importFileName   file to import from  
    * 
    * @return 0 on success, &lt;0 on error.
    */
   int importColorProfile(se.color.ColorScheme &scm, _str importFileName) {

      // open the file, assuming it is XML
      status := 0;
      fileHandle := _xmlcfg_open(importFileName, status, VSXMLCFG_OPEN_ADD_ALL_PCDATA);
      if (status < 0) {
         return status;
      }

      // get the default window colors
      initCanvasColors(fileHandle, scm);

      // find all the color categories defined
      getCategoryIndexes(fileHandle, auto catIndexes);

      // do two passes over all the color combinations, the is because we need
      // to correctly resolve the canvas background colors when processing
      // other colors.  This allows us to determine what colors inherit the
      // background color and what colors do not.
      //
      for (pass := 0; pass<2; pass++) {

         // for each color category
         foreach (auto catNode in catIndexes) {

            // get the category name
            catName := getCategoryName(fileHandle, (int)catNode);

            // find all the colors defined
            getColorIndexes(fileHandle, catNode, catName, auto colorIndexes);
            foreach (auto colorNode in colorIndexes) {

               // get the color name
               colorNames := getColorName(fileHandle, colorNode);
               while (colorNames != "") {
                  parse colorNames with auto colorName ',' colorNames;
                  colorName = strip(colorName);

                  // map the category and color name to a color constant (or several)
                  awesomeness := 0;
                  cfg2 := cfg3 := cfg4 := 0;
                  cfg := getColorFromName(catName, colorName, cfg2, cfg3, cfg4, awesomeness);
                  if (cfg == CFG_NULL) {
                     //say("import_visual_studio_theme H"__LINE__": category="catName" colorName="colorName);
                     continue;
                  }

                  // already have a better setting for this color
                  if (cfg > 0 && awesomeness < m_currentAwesomeness[cfg]) {
                     continue;
                  }

                  // get the original colors for this item
                  bgColor := fgColor := emColor := fontFlags := 0;
                  pColorInfo := getColorFromProfile(scm, cfg, bgColor, fgColor, emColor, fontFlags);

                  // get the background color
                  if (getColorFromNode(fileHandle, colorNode, colorName, bgColor, fgColor, fontFlags) < 0) {
                     continue;
                  }

                  // save the color in the color profile
                  saveColorInProfile(scm, pColorInfo, cfg, cfg2, cfg3, cfg4, bgColor, fgColor, -1, fontFlags);
               }
            }
         }
      }

      // final cleanup, tries to fill in missing colors
      interpolateMissingColors(scm);

      // final step, close the file and return
      _xmlcfg_close(fileHandle);
      return 0;
   }

   /**
    * Initialize the canvas colors based on the colors found in the initial 
    * color scheme.  These colors are likely to be overridden by the imported 
    * theme, but this creates a starting point.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param scm           color profile
    */
   protected void initCanvasColors(int fileHandle, ColorScheme &scm) {
      ColorImport.initCanvasColors(fileHandle, scm);

      int colorIndexes[];
      _xmlcfg_find_simple_array(fileHandle, "/plist/dict/array/dict", auto strColorIndexes);
      foreach (auto i in strColorIndexes) {
         if (!isinteger(i)) continue;
         colorNode := (int)i;

         getDictionaryForKey(fileHandle, colorNode, "settings", auto dict);

         cursorColor := -1;
         currentLineColor := -1;
         selectionColor := -1;
         selectionLineColor := -1;
         specialCharsColor := -1;
         findHighlightBgColor := -1;
         findHighlightFgColor := -1;
         prefixBgColor := -1;
         prefixFgColor := -1;
         bracketsBgColor := -1;
         bracketsFgColor := -1;
         selectiveDisplayColor := -1;

         foreach (auto key => auto val in dict) {
            switch (key) {
            case "background":
               m_canvasBgColor = convert_html_color_to_rgb(val);
               break;
            case "foreground":
               m_canvasFgColor = convert_html_color_to_rgb(val);
               break;
            case "shadow":
               m_canvasEmColor = convert_html_color_to_rgb(val);
               break;
            case "lineHighlight":
               currentLineColor = convert_html_color_to_rgb(val);
               break;
               break;
            case "selection":
               selectionColor = convert_html_color_to_rgb(val);
               break;
            case "invisibles":
               //specialCharsColor = convert_html_color_to_rgb(val);
               break;
            case "findHighlight":
               findHighlightBgColor = convert_html_color_to_rgb(val);
               break;
            case "findHighlightForeground":
               findHighlightFgColor = convert_html_color_to_rgb(val);
               break;
            case "gutterForeground":
               prefixFgColor = convert_html_color_to_rgb(val);
               break;
            case "gutter":
            case "gutterBackground":
               prefixBgColor = convert_html_color_to_rgb(val);
               break;
               break;
            case "bracketsForeground":
               bracketsFgColor = convert_html_color_to_rgb(val);
               break;
            case "brackets":
            case "bracketsBackground":
               bracketsBgColor = convert_html_color_to_rgb(val);
               break;
            case "guide":
            case "stackGuide":
               selectiveDisplayColor = convert_html_color_to_rgb(val);
               break;
            }
         }

         saveStandardWindowColors(scm, 
                                  m_canvasBgColor, m_canvasEmColor, m_canvasFgColor,
                                  currentLineColor, selectionColor, selectionLineColor,
                                  findHighlightBgColor, findHighlightFgColor,
                                  prefixBgColor, prefixFgColor,
                                  bracketsBgColor, bracketsFgColor,
                                  specialCharsColor, selectiveDisplayColor);

         // stop, we have what we were looking for
         break;
      }
   }

   /**
    * Get the list of color definition nodes from the color theme file.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catNode       category node to get colors from 
    * @param catName       category name 
    * @param colorIndexes  (output) array of index of color nodes 
    */
   protected void getColorIndexes(int fileHandle, int catNode, _str catName, int (&colorIndexes)[]) {
      _xmlcfg_find_simple_array(fileHandle, "/plist/dict/array/dict", auto strColorIndexes);
      foreach (auto i in strColorIndexes) {
         if (!isinteger(i)) continue;
         colorIndexes :+= (int)i;
      }
   }

   /**
    * Fetch the dictionary associated with the given key in the XML dictionary.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to get dictionary from 
    * @param keyName       dictionary name that has sub-dictionary 
    * @param dict          (output) dictionary to return 
    */
   protected void getDictionaryForKey(int fileHandle, int colorNode, _str keyName, _str (&dict):[]) {
      childNode := _xmlcfg_get_first_child_element(fileHandle, colorNode);
      while (childNode > 0) {
         childName := _xmlcfg_get_name(fileHandle, childNode);
         if (childName == "key") {
            contentsNode := _xmlcfg_get_first_child(fileHandle, childNode);
            if (contentsNode > 0) {
               contentsValue := _xmlcfg_get_value(fileHandle, contentsNode);
               if (contentsValue == keyName) {
                  childNode = _xmlcfg_get_next_sibling_element(fileHandle,childNode);
                  if (childNode <= 0) {
                     break;
                  }
                  childName = _xmlcfg_get_name(fileHandle, childNode);
                  if (childName == "dict") {
                     dictNode := _xmlcfg_get_first_child_element(fileHandle, childNode);
                     while (dictNode > 0) {
                        childName = _xmlcfg_get_name(fileHandle, dictNode);
                        if (childName == "key") {
                           contentsNode = _xmlcfg_get_first_child(fileHandle, dictNode);
                           if (contentsNode > 0) {
                              dictValue := "";
                              dictKey := _xmlcfg_get_value(fileHandle, contentsNode);
                              dictNode = _xmlcfg_get_next_sibling_element(fileHandle,dictNode);
                              if (dictNode <= 0) {
                                 break;
                              }
                              childName = _xmlcfg_get_name(fileHandle, dictNode);
                              if (childName == "string") {
                                 contentsNode = _xmlcfg_get_first_child(fileHandle, dictNode);
                                 if (contentsNode > 0) {
                                    dictValue = _xmlcfg_get_value(fileHandle, contentsNode);
                                 }
                              }
                              dict:[dictKey] = dictValue;
                           }
                        }
                        // next please
                        dictNode = _xmlcfg_get_next_sibling_element(fileHandle,dictNode);
                     }
                  }
                  return;
               }
            }
         }
         childNode = _xmlcfg_get_next_sibling_element(fileHandle,childNode);
      }
   }

   /** 
    * @return 
    * Return the value associated with the given key in the XML dictionary 
    * under the given node.
    */
   protected _str getValueForKey(int fileHandle, int colorNode, _str keyName) {
      childNode := _xmlcfg_get_first_child_element(fileHandle, colorNode);
      while (childNode > 0) {
         childName := _xmlcfg_get_name(fileHandle, childNode);
         if (childName == "key") {
            contentsNode := _xmlcfg_get_first_child(fileHandle, childNode);
            if (contentsNode > 0) {
               contentsValue := _xmlcfg_get_value(fileHandle, contentsNode);
               if (contentsValue == keyName) {
                  childNode = _xmlcfg_get_next_sibling_element(fileHandle,childNode);
                  if (childNode <= 0) {
                     break;
                  }
                  childName = _xmlcfg_get_name(fileHandle, childNode);
                  if (childName == "string") {
                     contentsNode = _xmlcfg_get_first_child(fileHandle, childNode);
                     if (contentsNode > 0) {
                        contentsValue = _xmlcfg_get_value(fileHandle, contentsNode);
                        return contentsValue;
                     }
                  }
               }
            }
         }
         childNode = _xmlcfg_get_next_sibling_element(fileHandle,childNode);
      }
      return "";
   }

   /** 
    * @return 
    * Return the name of the given color definition node.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to get name of
    * 
    * @note 
    * This function usually needs to be overloaded.
    */
   protected _str getColorName(int fileHandle, int colorNode) {
      return getValueForKey(fileHandle, colorNode, "name");
   }

   /**
    * Get the background color, foreground color, and font flags for this color 
    * description node. 
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to extract information from
    * @param bgColor       (output) background color
    * @param fgColor       (output) foreground color
    * @param fontFlags     (output) font flags
    * 
    * @return 0 on success, &lt;0 on error.
    *  
    * @note 
    * This function must be overloaded. 
    */
   protected int getColorFromNode(int fileHandle, int colorNode, _str colorName, int &bgColor, int &fgColor, int &fontFlags) {

      getDictionaryForKey(fileHandle, colorNode, "settings", auto dict);

      foreach (auto key => auto val in dict) {
         switch (key) {
         case "background":
            bgColor = convert_html_color_to_rgb(val);
            break;
         case "foreground":
            fgColor = convert_html_color_to_rgb(val);
            break;
         case "fontStyle":
            foreach (auto fontStyle in val) {
               switch (fontStyle) {
               case "bold":
                  fontFlags |= F_BOLD;
                  break;
               case "underline":
                  fontFlags |= F_UNDERLINE;
                  break;
               case "strike":
                  fontFlags |= F_STRIKE_THRU;
                  break;
               case "italic":
                  fontFlags |= F_ITALIC;
                  break;
               }
            }
            break;
         }
      }
      return 0;
   }

   /**                               alternatee                      
    * @return 
    * Returns the color constant (CFG_*) mapped from the given color category 
    * and color name.  It can also return up to three more color constants, for 
    * related colors that should be set along with a given color, such as the 
    * closely related string and number color constants. 
    * 
    * @param catName        color category name
    * @param colorName      color names
    * @param cfg2           (output) alternate color constant (CFG_*)
    * @param cfg3           (output) alternate color constant (CFG_*)
    * @param cfg4           (output) alternate color constant (CFG_*)
    * @param awesomeness    Rating form 0 .. 10 on how sure we are about this color
    * 
    * @note 
    * This function must be overloaded. 
    *  
    * @note 
    * The 'awesomeness' parameter helps us sort out when there are multiple 
    * color categories and color names that could map to the same color constant. 
    * It allows us to rank the ones that are there and select the best one to use.
    */
   protected int getColorFromName(_str catName, _str colorName, 
                                  int &cfg2, int &cfg3, int &cfg4, 
                                  int &awesomeness) {

      // initialize everything
      cfg := cfg2 = cfg3 = cfg4 = CFG_NULL;
      awesomeness = 1;

      switch (colorName) {
      case "Comment":
      case "Comments":
         cfg = CFG_COMMENT;
         cfg2 = CFG_LINE_COMMENT;
         cfg3 = CFG_DOCUMENTATION;
         break;
      case "Variable":
         cfg = CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_GLOBAL_VARIABLE;
         cfg3 = CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE;
         cfg4 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE;
         break;
      case "Colors":
         break;
      case "Invalid":
         break;
      case "Unimplemented":
         break;
      case "Invalid deprecated":
         break;
      case "Keyword":
         cfg = CFG_KEYWORD;
         break;
      case "Storage":
         break;
      case "Operator":
         cfg = CFG_OPERATOR;
         awesomeness = 10;
         break;
      case "Misc":
         cfg = CFG_PUNCTUATION;
         awesomeness = 2;
         break;
      case "Tag":
         cfg = CFG_TAG;
         break;
      case "Function":
         cfg = CFG_FUNCTION;
         break;
      case "Special Method":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION;
         break;
      case "Block Level":
         cfg = CFG_SYMBOL_COLOR_GLOBAL_FUNCTION;
         cfg2 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION;
         break;
      case "Other Variable":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE;
         break;
      case "String Link":
         cfg = CFG_NAVHINT;
         break;
      case "Number":
         cfg = CFG_NUMBER;
         cfg2 = CFG_HEX_NUMBER;
         cfg3 = CFG_FLOATING_NUMBER;
         break;
      case "Constant":
         cfg = CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT;
         break;
      case "Function Argument":
         cfg = CFG_SYMBOL_COLOR_PARAMETER;
         break;
      case "Tag Attribute":
         cfg = CFG_ATTRIBUTE;
         cfg2 = CFG_UNKNOWN_ATTRIBUTE;
         break;
      case "Embedded":
         cfg = -CFG_WINDOW_TEXT;
         break;
      case "String":
         cfg = CFG_STRING;
         break;
      case "Symbols":
         cfg = CFG_IDENTIFIER;
         break;
      case "Inherited Class":
         cfg = CFG_SYMBOL_COLOR_ABSTRACT_CLASS;
         break;
      case "Markup Heading":
         cfg = CFG_MARKDOWN_HEADER;
         break;
      case "Class":
         cfg = CFG_SYMBOL_COLOR_CLASS;
         break;
      case "Support":
         break;
      case "CSS Class and Support":
         cfg = CFG_CSS_CLASS;
         break;
      case "Sub-methods":
         cfg = CFG_SYMBOL_COLOR_NESTED_FUNCTION;
         break;
      case "Language methods":
         cfg = CFG_USER_DEFINED;
         break;
      case "entity.name.method.js":
         break;
      case "meta.method.js":
         break;
      case "Attributes":
         cfg = CFG_ATTRIBUTE;
         cfg2 = CFG_UNKNOWN_ATTRIBUTE;
         break;
      case "HTML Attributes":
         cfg = CFG_ATTRIBUTE;
         cfg2 = CFG_UNKNOWN_ATTRIBUTE;
         break;
      case "CSS Classes":
         cfg = CFG_CSS_CLASS;
         break;
      case "CSS Id":
         cfg = CFG_CSS_SELECTOR;
         break;
      case "Inserted":
         cfg = CFG_INSERTED_LINE;
         break;
      case "Deleted":
         cfg = CFG_IMAGINARY_LINE;
         break;
      case "Changed":
         cfg = CFG_MODIFIED_LINE;
         break;
      case "Regular Expressions":
         break;
      case "Escape Characters":
         break;
      case "URL":
         cfg = CFG_NAVHINT;
         break;
      case "Search Results Nums":
         break;
      case "Search Results Lines":
         cfg = CFG_FILENAME;
         break;
      case "Decorators":
         break;
      case "ES7 Bind Operator":
         break;
      case "JSON Key - Level 8":
         break;
      case "JSON Key - Level 7":
         break;
      case "JSON Key - Level 6":
         break;
      case "JSON Key - Level 5":
         break;
      case "JSON Key - Level 4":
         break;
      case "JSON Key - Level 3":
         break;
      case "JSON Key - Level 2":
         break;
      case "JSON Key - Level 1":
         break;
      case "JSON Key - Level 0":
         break;
      case "Markdown - Plain":
         break;
      case "Markdown - Markup Raw Inline":
         cfg = CFG_MARKDOWN_CODE;
         break;
      case "Markdown - Markup Raw Inline Punctuation":
         break;
      case "Markdown - Line Break":
         break;
      case "Markdown - Heading":
         cfg = CFG_MARKDOWN_HEADER;
         break;
      case "Markup - Italic":
         cfg = CFG_MARKDOWN_EMPHASIS;
         break;
      case "Markup - Bold":
         cfg = CFG_MARKDOWN_EMPHASIS2;
         break;
      case "Markup - Bold & Italic":
         cfg = CFG_MARKDOWN_EMPHASIS3;
         break;
      case "Markup - Underline":
         break;
      case "Markup - Strike":
         cfg = CFG_MARKDOWN_EMPHASIS4;
         break;
      case "Markdown - Blockquote":
         cfg = CFG_MARKDOWN_BLOCKQUOTE;
         break;
      case "Markup - Quote":
         break;
      case "Markdown - Link":
         cfg = CFG_MARKDOWN_LINK;
         break;
      case "Markdown - Link Description":
         cfg = CFG_MARKDOWN_LINK2;
         break;
      case "Markdown - Link Anchor":
         break;
      case "Markup - Raw Block":
         cfg = CFG_MARKDOWN_CODE;
         break;
      case "Markdown - Raw Block Fenced":
         cfg = CFG_MARKDOWN_CODE;
         break;
      case "Markdown - Fenced Bode Block":
         cfg = CFG_MARKDOWN_CODE;
         break;
      case "Markdown - Fenced Bode Block Variable":
         cfg = CFG_MARKDOWN_CODE;
         break;
      case "Markdown - Fenced Language":
         cfg = CFG_MARKDOWN_CODE;
         break;
      case "Markdown - Punctuation Definition":
         break;
      case "Markdown HTML - Punctuation Definition":
         break;
      case "Markdown - Separator":
         break;
      case "Markup - Table":
         break;
      case "AceJump Label - Blue":
         break;
      case "AceJump Label - Green":
         break;
      case "AceJump Label - Orange":
         break;
      case "AceJump Label - Purple":
         break;
      case "SublimeLinter Warning":
         break;
      case "SublimeLinter Gutter Mark":
         break;
      case "SublimeLinter Error":
         cfg = CFG_ERROR;
         awesomeness = 1;
         break;
      case "SublimeLinter Annotation":
         break;
      case "GitGutter Ignored":
         break;
      case "GitGutter Untracked":
         break;
      case "GitGutter Inserted":
         break;
      case "GitGutter Changed":
         break;
      case "GitGutter Deleted":
         break;
      case "Bracket Curly":
         cfg = CFG_BLOCK_MATCHING;
         awesomeness = 10;
         break;
      case "Bracket Quote":
         break;
      case "Bracket Unmatched":
         break;
      case "Preprocessor Statements":
         cfg = CFG_PPKEYWORD;
         break;
      case "Built-in constant":
         cfg = CFG_LIBRARY_SYMBOL;
         break;
      case "User-defined constant":
         cfg = CFG_USER_DEFINED;
         break;
      case "Class name":
         cfg = CFG_SYMBOL_COLOR_CLASS;
         break;
      case "Inherited class":
         cfg = CFG_SYMBOL_COLOR_ABSTRACT_CLASS;
         break;
      case "Function name":
         cfg = CFG_FUNCTION;
         break;
      case "Function argument":
         cfg = CFG_SYMBOL_COLOR_PARAMETER;
         cfg3 = CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER;
         break;
      case "Tag name":
         cfg = CFG_TAG;
         break;
      case "Tag attribute":
         cfg = CFG_ATTRIBUTE;
         cfg2 = CFG_UNKNOWN_ATTRIBUTE;
         break;
      case "Library function":
         cfg = CFG_LIBRARY_SYMBOL;
         break;
      case "User Defined Functions":
         cfg = CFG_USER_DEFINED;
         break;
      case "Library constant":
         cfg = CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT;
         break;
      case "Library class/type":
         cfg = CFG_SYMBOL_COLOR_STRUCT;
         cfg2 = CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE;
         break;
      case "Library variable":
         cfg = CFG_SYMBOL_COLOR_GLOBAL_VARIABLE;
         break;
      case "Markup Bold":
         cfg = CFG_MARKDOWN_EMPHASIS2;
         break;
      case "Markup Italic":
         cfg = CFG_MARKDOWN_EMPHASIS;
         break;
      case "Markup Underline":
         cfg = CFG_MARKDOWN_EMPHASIS4;
         break;
      case "Markup Quote":
         cfg = CFG_MARKDOWN_BLOCKQUOTE;
         break;
      case "Markup List":
         cfg = CFG_MARKDOWN_BULLET;
         break;
      default:
         //say("getColorFromName H"__LINE__": colorName="colorName);
         break;
      }
      return cfg;
   }
};

/**
 * Implementation of color importer for Xcode color themes 
 * (.xccolortheme or .dvtcolortheme),  This file format is, of course, a plist.
 */
class ColorImporterForXcode : ColorImport {
   
   /**
    * Initialize the canvas colors based on the colors found in the initial 
    * color scheme.  These colors are likely to be overridden by the imported 
    * theme, but this creates a starting point.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param scm           color profile
    */
   protected void initCanvasColors(int fileHandle, ColorScheme &scm) {
      ColorImport.initCanvasColors(fileHandle, scm);

      _str dict:[];
      int colorIndexes[];
      getColorIndexes(fileHandle, 0, "", colorIndexes);
      foreach (auto i in colorIndexes) {
         colorName := getColorName(fileHandle, i);
         stringNode := _xmlcfg_get_next_sibling_element(fileHandle, i);
         contentsNode := _xmlcfg_get_first_child(fileHandle, stringNode);
         if (contentsNode <= 0) {
            continue;
         }
         colorInfo := _xmlcfg_get_value(fileHandle, contentsNode);
         dict:[colorName] = colorInfo;
      }

      cursorColor := -1;
      currentLineColor := -1;
      selectionColor := -1;
      selectionLineColor := -1;
      specialCharsColor := -1;
      selectiveDisplayColor := -1;
      findHighlightBgColor := -1;
      findHighlightFgColor := -1;
      prefixBgColor := -1;
      prefixFgColor := -1;
      bracketsBgColor := -1;
      bracketsFgColor := -1;

      foreach (auto key => auto val in dict) {
         switch (key) {
         case "DVTSourceTextBackground":
            m_canvasBgColor = convertCMYK2RGB(val);
            break; 
         case "DVTSourceTextBlockDimBackgroundColor":
            m_canvasEmColor = convertCMYK2RGB(val);
            break; 
         case "DVTSourceTextCurrentLineHighlightColor": 
            currentLineColor = convertCMYK2RGB(val);
            break; 
         case "DVTSourceTextInsertionPointColor": 
            cursorColor = convertCMYK2RGB(val);
            break; 
         case "DVTSourceTextSelectionColor":
            selectionColor = convertCMYK2RGB(val);
            break; 
         case "DVTSourceTextSyntaxColors": 
            specialCharsColor = convertCMYK2RGB(val);
            break; 
         }
      }

      saveStandardWindowColors(scm, 
                               m_canvasBgColor, m_canvasEmColor, m_canvasFgColor,
                               currentLineColor, selectionColor, selectionLineColor,
                               findHighlightBgColor, findHighlightFgColor,
                               prefixBgColor, prefixFgColor,
                               bracketsBgColor, bracketsFgColor,
                               specialCharsColor, selectiveDisplayColor);
   }

   /**
    * Get the list of color definition nodes from the color theme file.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catNode       category node to get colors from 
    * @param catName       category name 
    * @param colorIndexes  (output) array of index of color nodes 
    */
   protected void getColorIndexes(int fileHandle, int catNode, _str catName, int (&colorIndexes)[]) {
      _xmlcfg_find_simple_array(fileHandle, "/plist/dict/key", auto strColorIndexes);
      foreach (auto i in strColorIndexes) {
         if (!isinteger(i)) continue;
         colorIndexes :+= (int)i;
      }
      strColorIndexes._makeempty();
      _xmlcfg_find_simple_array(fileHandle, "/plist/dict/dict/key", strColorIndexes);
      foreach (i in strColorIndexes) {
         if (!isinteger(i)) continue;
         colorIndexes :+= (int)i;
      }
   }

   /** 
    * @return 
    * Return the value associated with the given key in the XML dictionary 
    * under the given node.
    */
   protected _str getValueForKey(int fileHandle, int colorNode, _str keyName) {
      childNode := _xmlcfg_get_first_child_element(fileHandle, colorNode);
      while (childNode > 0) {
         childName := _xmlcfg_get_name(fileHandle, childNode);
         if (childName == "key") {
            contentsNode := _xmlcfg_get_first_child(fileHandle, childNode);
            if (contentsNode > 0) {
               contentsValue := _xmlcfg_get_value(fileHandle, contentsNode);
               if (contentsValue == keyName) {
                  childNode = _xmlcfg_get_next_sibling_element(fileHandle,childNode);
                  if (childNode <= 0) {
                     break;
                  }
                  childName = _xmlcfg_get_name(fileHandle, childNode);
                  if (childName == "string") {
                     contentsNode = _xmlcfg_get_first_child(fileHandle, childNode);
                     if (contentsNode > 0) {
                        contentsValue = _xmlcfg_get_value(fileHandle, contentsNode);
                        return contentsValue;
                     }
                  }
               }
            }
         }
         childNode = _xmlcfg_get_next_sibling_element(fileHandle,childNode);
      }
      return "";
   }

   /** 
    * @return 
    * Return the name of the given color definition node.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to get name of
    * 
    * @note 
    * This function usually needs to be overloaded.
    */
   protected _str getColorName(int fileHandle, int colorNode) {
      contentsNode := _xmlcfg_get_first_child(fileHandle, colorNode);
      if (contentsNode <= 0) {
         return "";
      }
      return _xmlcfg_get_value(fileHandle, contentsNode);
   }

   /**
    * Convert the given Xcode HSL color information to RGB
    */
   int convertCMYK2RGB(_str colorInfo) {
      parse colorInfo with auto sc auto sm auto sy auto sk;
      if (sk == "") sk = 1;
      if (!isnumber(sc) || !isnumber(sm) || !isnumber(sy) || !isnumber(sk)) {
         return STRING_NOT_FOUND_RC;
      }
      c := (double)sc;
      m := (double)sm;
      y := (double)sy;
      k := (double)sk;

      blackLevel := (255 * k);
      if (blackLevel > 255) blackLevel = 255;
      r := (int)(blackLevel * c);
      g := (int)(blackLevel * m);
      b := (int)(blackLevel * y);
      return ((b << 16) | (g << 8) | r);
   }

   /**
    * Get the background color, foreground color, and font flags for this color 
    * description node. 
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to extract information from
    * @param bgColor       (output) background color
    * @param fgColor       (output) foreground color
    * @param fontFlags     (output) font flags
    * 
    * @return 0 on success, &lt;0 on error.
    *  
    * @note 
    * This function must be overloaded. 
    */
   protected int getColorFromNode(int fileHandle, int colorNode, _str colorName, int &bgColor, int &fgColor, int &fontFlags) {
      stringNode := _xmlcfg_get_next_sibling_element(fileHandle, colorNode);
      contentsNode := _xmlcfg_get_first_child(fileHandle, stringNode);
      if (contentsNode <= 0) {
         return STRING_NOT_FOUND_RC;
      }
      colorInfo := _xmlcfg_get_value(fileHandle, contentsNode);
      rgb := convertCMYK2RGB(colorInfo);
      if (rgb < 0) {
         return STRING_NOT_FOUND_RC;
      }
      fgColor = rgb;
      return 0;
   }

   /**
    * @return 
    * Returns the color constant (CFG_*) mapped from the given color category 
    * and color name.  It can also return up to three more color constants, for 
    * related colors that should be set along with a given color, such as the 
    * closely related string and number color constants. 
    * 
    * @param catName        color category name
    * @param colorName      color names
    * @param cfg2           (output) alternate color constant (CFG_*)
    * @param cfg3           (output) alternate color constant (CFG_*)
    * @param cfg4           (output) alternate color constant (CFG_*)
    * @param awesomeness    Rating form 0 .. 10 on how sure we are about this color
    * 
    * @note 
    * This function must be overloaded. 
    *  
    * @note 
    * The 'awesomeness' parameter helps us sort out when there are multiple 
    * color categories and color names that could map to the same color constant. 
    * It allows us to rank the ones that are there and select the best one to use.
    */
   protected int getColorFromName(_str catName, _str colorName, 
                                  int &cfg2, int &cfg3, int &cfg4, 
                                  int &awesomeness) {

      // initialize everything
      cfg := cfg2 = cfg3 = cfg4 = CFG_NULL;
      awesomeness = 1;

      switch (colorName) {
      case "DVTMarkupTextEmphasisColor": 
         cfg = CFG_MARKDOWN_EMPHASIS;
         break; 
      case "DVTMarkupTextInlineCodeColor": 
         cfg = CFG_MARKDOWN_CODE;
         break; 
      case "DVTMarkupTextLinkColor": 
         cfg = CFG_MARKDOWN_LINK;
         break; 
      case "DVTMarkupTextOtherHeadingColor": 
         cfg = CFG_MARKDOWN_HEADER;
         awesomeness = 2;
         break; 
      case "DVTMarkupTextOtherHeadingFont": 
         cfg = CFG_MARKDOWN_HEADER;
         break; 
      case "DVTMarkupTextPrimaryHeadingColor": 
         cfg = CFG_MARKDOWN_HEADER;
         awesomeness = 4;
         break; 
      case "DVTMarkupTextSecondaryHeadingColor": 
         cfg = CFG_MARKDOWN_HEADER;
         break; 
      case "DVTMarkupTextStrongColor": 
         cfg = CFG_MARKDOWN_EMPHASIS3;
         break; 
      case "DVTSourceTextInvisiblesColor": 
         cfg = CFG_SPECIALCHARS;
         break; 
      case "xcode.syntax.attribute":
         cfg = CFG_ATTRIBUTE;
         cfg2 = CFG_UNKNOWN_ATTRIBUTE;
         break;
      case "xcode.syntax.character":
         cfg = CFG_SINGLEQUOTED_STRING;
         break;
      case "xcode.syntax.comment":
         cfg = CFG_COMMENT;
         cfg2 = CFG_LINE_COMMENT;
         cfg3 = CFG_DOCUMENTATION;
         break;
      case "xcode.syntax.comment.doc":
         cfg = CFG_DOCUMENTATION;
         cfg2 = CFG_DOC_ATTR_VALUE;
         cfg3 = CFG_DOC_KEYWORD;
         cfg4 = CFG_DOC_PUNCTUATION;
         awesomeness = 10;
         break;
      case "xcode.syntax.comment.doc.keyword":
         cfg = CFG_DOC_KEYWORD;
         cfg2 = CFG_DOC_PUNCTUATION;
         awesomeness = 11;
         break;
      case "xcode.syntax.identifier.class":
         cfg = CFG_SYMBOL_COLOR_CLASS;
         cfg2 = CFG_SYMBOL_COLOR_ABSTRACT_CLASS;
         break;
      case "xcode.syntax.identifier.class.system":
         cfg = CFG_SYMBOL_COLOR_STRUCT;
         cfg2 = CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE;
         break;
      case "xcode.syntax.identifier.constant":
         cfg = CFG_IDENTIFIER2;
         break;
      case "xcode.syntax.identifier.constant.system":
         cfg = CFG_SYMBOL_COLOR_SYMBOLIC_CONSTANT;
         break;
      case "xcode.syntax.identifier.function":
         cfg = CFG_FUNCTION;
         break;
      case "xcode.syntax.identifier.function.system":
         cfg = CFG_SYMBOL_COLOR_GLOBAL_FUNCTION;
         cfg2 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_FUNCTION;
         break;
      case "xcode.syntax.identifier.macro":
         cfg = CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO;
         awesomeness = 2;
         break;
      case "xcode.syntax.identifier.macro.system":
         cfg = CFG_SYMBOL_COLOR_PREPROCESSOR_MACRO;
         break;
      case "xcode.syntax.identifier.type":
         cfg = CFG_SYMBOL_COLOR_TYPE_DEFINITION_OR_ALIAS;
         break;
      case "xcode.syntax.identifier.type.system":
         cfg = CFG_SYMBOL_COLOR_STRUCT;
         cfg2 = CFG_SYMBOL_COLOR_UNION_OR_VARIANT_TYPE;
         break;
      case "xcode.syntax.identifier.variable":
         cfg = CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_GLOBAL_VARIABLE;
         cfg3 = CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE;
         cfg4 = CFG_SYMBOL_COLOR_STATIC_GLOBAL_VARIABLE;
         break;
      case "xcode.syntax.identifier.variable.system":
         cfg = CFG_IDENTIFIER;
         break;
      case "xcode.syntax.keyword":
         cfg = CFG_KEYWORD;
         awesomeness = 10;
         break;
      case "xcode.syntax.number":
         cfg = CFG_NUMBER;
         cfg2 = CFG_HEX_NUMBER;
         cfg3 = CFG_FLOATING_NUMBER;
         awesomeness = 10;
         break;
      case "xcode.syntax.plain":
         cfg = CFG_WINDOW_TEXT;
         awesomeness = 10;
         break;
      case "xcode.syntax.preprocessor":
         cfg = CFG_PPKEYWORD;
         awesomeness = 10;
         break;
      case "xcode.syntax.string":
         cfg = CFG_STRING;
         cfg2 = CFG_UNTERMINATED_STRING;
         cfg3 = CFG_SINGLEQUOTED_STRING;
         cfg4 = CFG_BACKQUOTED_STRING;
         awesomeness = 10;
         break;
      case "xcode.syntax.url":
         cfg = CFG_NAVHINT;
         awesomeness = 10;
         break;
      default:
         //say("getColorFromName H"__LINE__": colorName="colorName);
         break;
      }
      return cfg;
   }
};

/**
 * Implementation of color importer for Eclipse XML color themes. 
 */
class ColorImporterForEclipse : ColorImport {
   
   /**
    * Get the list of color definition nodes from the color theme file.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param catNode       category node to get colors from 
    * @param catName       category name 
    * @param colorIndexes  (output) array of index of color nodes 
    *  
    * @note 
    * This function needs to be overloaded.
    */
   protected void getColorIndexes(int fileHandle, int catNode, _str catName, int (&colorIndexes)[]) {
      _xmlcfg_find_simple_array(fileHandle, "/colorTheme", auto strColorIndexes);
      foreach (auto i in strColorIndexes) {
         if (!isinteger(i)) continue;
         catIndex := (int)i;
         colorIndex := _xmlcfg_get_first_child_element(fileHandle, catIndex);
         while (colorIndex > 0) {
            colorIndexes :+= colorIndex;
            colorIndex = _xmlcfg_get_next_sibling_element(fileHandle, colorIndex);
         }
      }
   }

   /**
    * Get the background color, foreground color, and font flags for this color 
    * description node. 
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to extract information from
    * @param bgColor       (output) background color
    * @param fgColor       (output) foreground color
    * @param fontFlags     (output) font flags
    * 
    * @return 0 on success, &lt;0 on error.
    *  
    * @note 
    * This function must be overloaded. 
    */
   protected int getColorFromNode(int fileHandle, int colorNode, _str colorName, int &bgColor, int &fgColor, int &fontFlags) {

      fgString := _xmlcfg_get_attribute(fileHandle, colorNode, "color");
      if (fgString != "") {
         color := ColorInfo.parseColorValue(fgString);
         if (pos("background", colorName, 1, 'i') > 0 ) {
            bgColor = color;
         } else {
            fgColor = color;
         }
      }
      if (fgString == "") {
         return STRING_NOT_FOUND_RC;
      }
      return 0;
   }

   /** 
    * @return 
    * Return the name of the given color definition node.
    * 
    * @param fileHandle    file handle (usually an XMLCFG file handle)
    * @param colorNode     color node to get name of
    * 
    * @note 
    * This function usually needs to be overloaded.
    */
   protected _str getColorName(int fileHandle, int colorNode) {
      return _xmlcfg_get_name(fileHandle, colorNode);
   }

   /**
    * @return 
    * Returns the color constant (CFG_*) mapped from the given color category 
    * and color name.  It can also return up to three more color constants, for 
    * related colors that should be set along with a given color, such as the 
    * closely related string and number color constants. 
    * 
    * @param catName        color category name
    * @param colorName      color names
    * @param cfg2           (output) alternate color constant (CFG_*)
    * @param cfg3           (output) alternate color constant (CFG_*)
    * @param cfg4           (output) alternate color constant (CFG_*)
    * @param awesomeness    Rating form 0 .. 10 on how sure we are about this color
    * 
    * @note 
    * This function must be overloaded. 
    *  
    * @note 
    * The 'awesomeness' parameter helps us sort out when there are multiple 
    * color categories and color names that could map to the same color constant. 
    * It allows us to rank the ones that are there and select the best one to use.
    */
   protected int getColorFromName(_str catName, _str colorName, 
                                  int &cfg2, int &cfg3, int &cfg4, 
                                  int &awesomeness) {

      // initialize everything
      cfg := cfg2 = cfg3 = cfg4 = CFG_NULL;
      awesomeness = 1;

      switch (colorName) {
      case "occurrenceIndication":
         cfg = CFG_SYMBOL_HIGHLIGHT;
         break;
      case "findScope":
         break;
      case "deletionIndication":
         cfg = CFG_IMAGINARY_LINE;
         break;
      case "singleLineComment":
         cfg = CFG_LINE_COMMENT;
         awesomeness = 10;
         break;
      case "multiLineComment":
         cfg = CFG_COMMENT;
         cfg3 = CFG_DOCUMENTATION;
         awesomeness = 10;
         break;
      case "commentTaskTag":
         break;
      case "javadoc":
         cfg2 = CFG_DOCUMENTATION;
         break;
      case "javadocLink":
         cfg = CFG_NAVHINT;
         break;
      case "javadocTag":
         cfg = CFG_DOC_KEYWORD;
         break;
      case "javadocKeyword":
         cfg = CFG_DOC_KEYWORD;
         awesomeness = 10;
         break;
      case "class":
         cfg = CFG_SYMBOL_COLOR_CLASS;
         cfg3 = CFG_SYMBOL_COLOR_CLASS_CONSTRUCTOR;
         cfg4 = CFG_SYMBOL_COLOR_CLASS_DESTRUCTOR;
         break;
      case "interface":
         cfg = CFG_SYMBOL_COLOR_ABSTRACT_CLASS;
         break;
      case "method":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_FUNCTION;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_FUNCTION;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_FUNCTION;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_FUNCTION;
         break;
      case "methodDeclaration":
         break;
      case "bracket":
         cfg = CFG_BLOCK_MATCHING;
         awesomeness = 10;
         break;
      case "number":
         cfg = CFG_NUMBER;
         cfg2 = CFG_HEX_NUMBER;
         cfg3 = CFG_FLOATING_NUMBER;
         break;
      case "string":
         cfg = CFG_STRING;
         cfg2 = CFG_UNTERMINATED_STRING;
         cfg3 = CFG_SINGLEQUOTED_STRING;
         cfg4 = CFG_BACKQUOTED_STRING;
         awesomeness = 10;
         break;
      case "operator":
         cfg = CFG_OPERATOR;
         awesomeness = 10;
         break;
      case "keyword":
         cfg = CFG_KEYWORD;
         awesomeness = 10;
         break;
      case "staticMethod":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_FUNCTION;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_FUNCTION;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_FUNCTION;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_FUNCTION;
         break;
      case "localVariable":
         cfg = CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE;
         awesomeness = 10;
         break;
      case "localVariableDeclaration":
         cfg = CFG_SYMBOL_COLOR_LOCAL_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_STATIC_LOCAL_VARIABLE;
         awesomeness = 5;
         break;
      case "field":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_MEMBER_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_MEMBER_VARIABLE;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_MEMBER_VARIABLE;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_MEMBER_VARIABLE;
         break;
      case "staticField":
         cfg = CFG_SYMBOL_COLOR_PUBLIC_STATIC_MEMBER_VARIABLE;
         cfg2 = CFG_SYMBOL_COLOR_PACKAGE_STATIC_MEMBER_VARIABLE;
         cfg3 = CFG_SYMBOL_COLOR_PROTECTED_STATIC_MEMBER_VARIABLE;
         cfg4 = CFG_SYMBOL_COLOR_PRIVATE_STATIC_MEMBER_VARIABLE;
         break;
      case "staticFinalField":
         break;
      case "deprecatedMember":
         break;
      case "enum":
         cfg = CFG_SYMBOL_COLOR_ENUMERATED_TYPE;
         cfg2 = CFG_SYMBOL_COLOR_ENUMERATION_CONSTANT;
         break;
      case "inheritedMethod":
         break;
      case "abstractMethod":
         break;
      case "parameterVariable":
         cfg = CFG_SYMBOL_COLOR_PARAMETER;
         break;
      case "typeArgument":
         cfg = CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER;
         break;
      case "typeParameter":
         cfg = CFG_SYMBOL_COLOR_TEMPLATE_PARAMETER;
         awesomeness = 10;
         break;
      case "background":
         cfg = CFG_WINDOW_TEXT;
         cfg2 = CFG_PUNCTUATION;
         cfg3 = CFG_IDENTIFIER;
         cfg4 = CFG_IDENTIFIER2;
         awesomeness = 1;
         break;
      case "currentLine":
         cfg = CFG_CLINE;
         awesomeness = 10;
         break;
      case "foreground":
         cfg = CFG_WINDOW_TEXT;
         cfg2 = CFG_PUNCTUATION;
         cfg3 = CFG_IDENTIFIER;
         cfg4 = CFG_IDENTIFIER2;
         awesomeness = 2;
         break;
      case "lineNumber":
         cfg = CFG_LINENUM;
         break;
      case "selectionBackground":
         cfg = CFG_SELECTION;
         awesomeness = 10;
         break;
      case "selectionForeground":
         cfg = CFG_SELECTION;
         awesomeness = 10;
         break;
      default:
         break;
      }
      return cfg;
   }

};

///////////////////////////////////////////////////////////////////////////
// Switch to the global namespace
//
namespace default;


//////////////////////////////////////////////////////////////
// COLOR PROFILE IMPORT FORM
//////////////////////////////////////////////////////////////

defeventtab _import_color_profile_form;

void ctl_okay.on_create()
{
   // load default schemes and the current symbol coloring scheme
   se.color.DefaultColorsConfig dcc;
   dcc.loadFromDefaultColors();

   // add the color profile names to inherit from
   ctl_inherit_profile._lbaddColorProfileNames(dcc, includeAutomatic:false, includeOnlyBuiltin:true);
   ctl_inherit_profile._cbset_text(se.color.ColorScheme.addProfilePrefix(se.color.ColorScheme.realProfileName(CONFIG_AUTOMATIC)));

   // adjust size of browse button for file import
   sizeBrowseButtonToTextBox(ctl_import_file.p_window_id, 
                             ctl_import_browse.p_window_id, 0, 
                             ctl_profile_name.p_x_extent);

   // select which kind of profile to import by default
   if ( _isWindows() ) {
      ctl_visual_studio.p_value = 1;
   } else if ( _isMac() ) {
      ctl_xcode.p_value = 1;
   } else {
      ctl_eclipse.p_value = 1;
   }
}

void ctl_okay.lbutton_up()
{
   // have to have a file to import
   if (ctl_import_file.p_text == "") {
      _message_box(nls("Specify file to import."));
      ctl_import_file._set_focus();
      return;
   }
   importFileName := ctl_import_file.p_text;
   if (!file_exists(importFileName)) {
      _message_box(get_message(UPDATE_FILE_DOES_NOT_EXIST_RC, importFileName));
      ctl_import_file._set_focus();
      return;
   }

   // have to have a profile name
   if (ctl_profile_name.p_text == "") {
      _message_box(nls("Specify a name for the new color profile."));
      ctl_profile_name._set_focus();
      return;
   }

   // check if profile file matches what we expect to see.
   ext := get_extension(importFileName);
   suspicious_choice := false;
   switch (ext) {
   case "tmTheme":
      suspicious_choice = (ctl_atom.p_value != 1);
      break;
   case "xccolortheme":
   case "dvtcolortheme":
      suspicious_choice = (ctl_xcode.p_value != 1);
      break;
   case "vssettings":
      suspicious_choice = (ctl_visual_studio.p_value != 1);
      break;
   case "xml":
      suspicious_choice = (ctl_atom.p_value || ctl_xcode.p_value);
      break;
   }
   if (suspicious_choice) {
      mbrc :=  _message_box(nls("File extension (.%s) does not match type of color theme import.  Are you sure?", ext), "SlickEdit", MB_YESNOCANCEL|MB_ICONQUESTION);
      if (mbrc == IDNO) {
         return;
      } else if (mbrc == IDCANCEL) {
         p_active_form._delete_window("");
         return;
      }
   }

   // let's see if we can open this file
   {
      status := 0;
      xmlHandle := _xmlcfg_open(importFileName, status);
      if (status < 0) {
         _message_box(nls("Invalid XML: ") :+ get_message(status, importFileName));
         ctl_import_file._set_focus();
         return;
      }
      suspicious_choice = false;
      topNode := _xmlcfg_get_document_element(xmlHandle);
      if (topNode >= 0) {
         topName := _xmlcfg_get_name(xmlHandle, topNode);
         if (ctl_visual_studio.p_value) {
            if (get_extension(importFileName) == "xml") {
               suspicious_choice = (topName != "Schemes");
            } else {
               suspicious_choice = (topName != "UserSettings");
            }
         } else if (ctl_xcode.p_value) {
            suspicious_choice = (topName != "plist");
         } else if (ctl_eclipse.p_value) {
            suspicious_choice = (topName != "colorTheme");
         } else if (ctl_atom.p_value) {
            suspicious_choice = (topName != "plist");
         }
      }
      _xmlcfg_close(xmlHandle);
      if (suspicious_choice) {
         mbrc :=  _message_box(nls("File does not appear to be the right type of XML file.  Are you sure?"), "SlickEdit", MB_YESNOCANCEL|MB_ICONQUESTION);
         if (mbrc == IDNO) {
            return;
         } else if (mbrc == IDCANCEL) {
            p_active_form._delete_window("");
            return;
         }
      }
   }

   // load default schemes and the current symbol coloring scheme
   newProfileName := ctl_profile_name.p_text;
   if (_plugin_has_profile(VSCFGPACKAGE_COLOR_PROFILES, newProfileName)) {
      mbrc :=  _message_box(nls("A profile with this name already exists.  Overwrite?"), "SlickEdit", MB_YESNOCANCEL|MB_ICONQUESTION);
      if (mbrc == IDNO) {
         ctl_profile_name._set_focus();
         return;
      } else if (mbrc == IDCANCEL) {
         p_active_form._delete_window("");
         return;
      }
   }

   // load the profile we are inheriting from
   parentProfileName := se.color.ColorScheme.removeProfilePrefix(ctl_inherit_profile._lbget_text());
   se.color.ColorScheme scm;
   scm.loadProfile(parentProfileName);
   scm.m_name = newProfileName;
   scm.m_inheritsProfile = parentProfileName;

   // now we can import
   status := 0;
   if (ctl_visual_studio.p_value) {
      status = import_visual_studio_theme(scm, importFileName);
   } else if (ctl_xcode.p_value) {
      status = import_xcode_color_theme(scm, importFileName);
   } else if (ctl_eclipse.p_value) {
      status = import_eclipse_color_theme(scm, importFileName);
   } else if (ctl_atom.p_value) {
      status = import_atom_color_theme(scm, importFileName);
   } else {
      _message_box(nls("Must select type of file to import."));
      ctl_visual_studio._set_focus();
      return;
   }

   // how did that go?
   if ( status < 0 ) {
      _message_box(nls("Error importing theme:  ") :+ get_message(status, importFileName));
      ctl_profile_name._set_focus();
      return;
   }

   // save the color scheme
   scm.saveProfile();

   // check if the color scheme imported fits with the inherited scheme
   parentProfileWithPrefix := se.color.ColorScheme.addProfilePrefix(parentProfileName);
   newProfileWithPrefix := se.color.ColorScheme.addProfilePrefix(newProfileName);
   parse parentProfileWithPrefix with auto parentPrefix ':' .;
   parse newProfileWithPrefix with auto importedPrefix ':' .;
   if (parentPrefix != importedPrefix) {
      mbrc :=  _message_box(nls("You have imported a %s theme over a %s theme (%s).\n\nDo you want to choose a different theme to inherit from?", 
                                importedPrefix, parentPrefix, parentProfileName), "SlickEdit", MB_YESNOCANCEL|MB_ICONQUESTION);
      if (mbrc == IDYES) {
         if (importedPrefix == "Light") {
            ctl_inherit_profile._cbset_text(se.color.ColorScheme.addProfilePrefix("Default"));
         } else {
            ctl_inherit_profile._cbset_text(se.color.ColorScheme.addProfilePrefix("Slate"));
         }
         ctl_inherit_profile._set_focus();
         return;
      } else if (mbrc == IDCANCEL) {
         p_active_form._delete_window("");
         return;
      }
   }

   // we are done with the import now
   p_active_form._delete_window(newProfileName);
   return;
}

static void select_import_file_type(_str file_name)
{
   if (file_name != "" && ctl_profile_name.p_text == "") {
      ctl_profile_name.p_text = _strip_filename(file_name, 'PE');
   }
   if (file_name != "") {
      ext := get_extension(file_name);
      switch (ext) {
      case "tmTheme":
         ctl_atom.p_value = 1;
         break;
      case "xccolortheme":
      case "dvtcolortheme":
         ctl_xcode.p_value = 1;
         break;
      case "vssettings":
         ctl_visual_studio.p_value = 1;
         break;
      case "xml":
         ctl_eclipse.p_value = 1;
         break;
      }
   }
}

void ctl_import_browse.lbutton_up()
{
   importFileName := ctl_import_file.p_text;

   filters := "";
   wildcards := "";
   if (ctl_visual_studio.p_value) {
      filters = "Visual Studio Themes (*.xml;*.vssettings)";
      filters = "*.xml;*.vssettings";
   } else if (ctl_xcode.p_value) {
      filters = "Xcode Color Themes (*.xccolortheme;*.dvtcolortheme)";
      filters = "*.xccolortheme;*.dvtcolortheme";
   } else if (ctl_eclipse.p_value) {
      filters = "Eclipse Themes (*.xml)";
      filters = "*.xml";
   } else if (ctl_atom.p_value) {
      filters = "TextMate Themes (*.tmTheme)";
      filters = "*.tmTheme";
   } else {
      // not possible
   }

   base := _strip_filename(importFileName, 'N');
   file   := _strip_filename(importFileName, 'P');
   rv := _OpenDialog('-modal', "Select file to import", wildcards, filters, OFN_FILEMUSTEXIST, "", file, base);
   if (rv != '') {
      rv = _maybe_unquote_filename(rv);
      ctl_import_file.p_text = rv;
      select_import_file_type(rv);
   }
}

void ctl_import_file.on_lost_focus()
{
   select_import_file_type(p_text);
}

static int import_visual_studio_theme(se.color.ColorScheme &scm, _str importFileName)
{
   if (get_extension(importFileName) == "xml") {
      se.color.ColorImporterForVisualStudioVSIX vsxmlColorImporter();
      status := vsxmlColorImporter.importColorProfile(scm, importFileName);
      return status;
   } else {
      se.color.ColorImporterForVisualStudioSettings vssColorImporter();
      status := vssColorImporter.importColorProfile(scm, importFileName);
      return status;
   }
}
static int import_xcode_color_theme(se.color.ColorScheme &scm, _str importFileName)
{
   se.color.ColorImporterForXcode xcodeColorImporter();
   status := xcodeColorImporter.importColorProfile(scm, importFileName);
   return status;
}
static int import_eclipse_color_theme(se.color.ColorScheme &scm, _str importFileName)
{
   se.color.ColorImporterForEclipse eclipseColorImporter();
   status := eclipseColorImporter.importColorProfile(scm, importFileName);
   return status;
}
static int import_atom_color_theme(se.color.ColorScheme &scm, _str importFileName)
{
   se.color.ColorImporterForAtom tmColorImporter();
   status := tmColorImporter.importColorProfile(scm, importFileName);
   return status;
}

