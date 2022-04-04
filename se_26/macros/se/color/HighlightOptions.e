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
#import "files.e"
#endregion


/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;


/**
 * Options for highlight tool window.
 *  
 * The following options control the highlight style and are mutually exclusive.
 * <ul> 
 * <li>{@link HIGHLIGHT_TW_USE_PALETTE_COLORS}</li>
 * <li>{@link HIGHLIGHT_TW_USE_REVERSE_COLORS}</li>
 * <li>{@link HIGHLIGHT_TW_USE_HIGHLIGHT_COLOR}</li>
 * <li>{@link HIGHLIGHT_TW_USE_BOLD_TEXT}</li>
 * <li>{@link HIGHLIGHT_TW_USE_UNDERLINE_TEXT}</li>
 * <li>{@link HIGHLIGHT_TW_USE_STRIKETHRU_TEXT}</li>
 * </ul> 
 *  
 * This option can be combined with any of the style options above 
 * (even though it does not look good with some).
 * <ul> 
 * <li>{@link HIGHLIGHT_TW_DRAW_BOX_TEXT}</li>
 * </ul> 
 *  
 * This option specifies whether not to add scroll bar markup for each 
 * word pattern matched and colored.
 * <ul> 
 * <li>{@link HIGHLIGHT_TW_DRAW_SCROLL_MARKERS}</li>
 * </ul> 
 *  
 * The folowing options control the default case-sensitivity options when 
 * adding a new word pattern, and are mutually exclusive. 
 * <ul> 
 * <li>{@link HIGHLIGHT_TW_CASE_SENSITIVE}</li>
 * <li>{@link HIGHLIGHT_TW_CASE_LANGUAGE}</li>
 * </ul> 
 *  
 * This option specifics that by default, when adding a new word pattern, 
 * it should be restricted to the current language mode. 
 * <ul> 
 * <li>{@link HIGHLIGHT_TW_RESTRICT_LANGUAGE}</li>
 * </ul> 
 *  
 * The following constants are defined for obvious utility. 
 * <ul> 
 * <li>{@link HIGHLIGHT_TW_NULL}</li>
 * <li>{@link HIGHLIGHT_TW_DEFAULT}</li>
 * </ul>
 */
enum_flags HighlightToolWindowOptions {
   /**
    * If no other color option flag is set, use the extended 
    * extended color palette colors as-is (no additional style)
    */
   HIGHLIGHT_TW_USE_PALETTE_COLORS  = 0x0000,
   /**
    * Use the extended color palette with reverse colors.
    */
   HIGHLIGHT_TW_USE_REVERSE_COLORS  = 0x0001,
   /**
    * Use the extended color palette with the highlight color background.
    */
   HIGHLIGHT_TW_USE_HIGHLIGHT_COLOR = 0x0002,
   /**
    * Use the extended color palette with bold text.
    */
   HIGHLIGHT_TW_USE_BOLD_TEXT       = 0x0004,
   /**
    * Use the extended color palette with underlined text.
    */
   HIGHLIGHT_TW_USE_UNDERLINE_TEXT  = 0x0008,
   /**
    * Use the extended color palette with strike-through text.
    */
   HIGHLIGHT_TW_USE_STRIKETHRU_TEXT = 0x0010,

   /**
    * Draw a box around the highlighted text matches.
    */
   HIGHLIGHT_TW_DRAW_BOX_TEXT       = 0x0020,

   /**
    * Draw scroll bar markup for highlighted text matches.
    */
   HIGHLIGHT_TW_DRAW_SCROLL_MARKERS = 0x0040,

   /**
    * By default, when adding a new word pattern, make it a case-sensitive match.
    */
   HIGHLIGHT_TW_CASE_SENSITIVE      = 0x0080,
   /**
    * By default, when adding a new word pattern, make it's case-sensitivity depend 
    * on the current language mode case-sensitivity. 
    */
   HIGHLIGHT_TW_CASE_LANGUAGE       = 0x0100,

   /**
    * By default, when adding a new word pattern, restrict it to the current 
    * langauge mode.
    */
   HIGHLIGHT_TW_RESTRICT_LANGUAGE   = 0x0200,

   /**
    * No options specified.
    */
   HIGHLIGHT_TW_NULL    = 0x0000,

   /**
    * Default option settings ({@literal 0x41}).
    */
   HIGHLIGHT_TW_DEFAULT = ( HIGHLIGHT_TW_USE_REVERSE_COLORS  |
                            HIGHLIGHT_TW_DRAW_SCROLL_MARKERS ),

   /**
    * Mask containing all text style options.
    */
   HIGHLIGHT_TW_USE_STYLE_MASK = ( HIGHLIGHT_TW_USE_PALETTE_COLORS  |
                                   HIGHLIGHT_TW_USE_REVERSE_COLORS  |
                                   HIGHLIGHT_TW_USE_HIGHLIGHT_COLOR |
                                   HIGHLIGHT_TW_USE_BOLD_TEXT       |
                                   HIGHLIGHT_TW_USE_UNDERLINE_TEXT  |
                                   HIGHLIGHT_TW_USE_STRIKETHRU_TEXT ),

   /**
    * Mask containing all case-sensitivity options.
    */
   HIGHLIGHT_TW_CASE_MASK = ( HIGHLIGHT_TW_CASE_SENSITIVE |
                              HIGHLIGHT_TW_CASE_LANGUAGE  ),
};


/**
 * Use the extended color palette with reverse colors.
 */
static const HIGHLIGHT_STYLE_REVERSE_COLORS  = "Reverse colors";
/**
 * If no other color option flag is set, use the extended 
 * extended color palette colors as-is (no additional style)
 */
static const HIGHLIGHT_STYLE_COLOR_TEXT      = "Color text";
/**
 * Use the extended color palette with bold text.
 */
static const HIGHLIGHT_STYLE_BOLD_TEXT       = "Bold text";
/**
 * Use the extended color palette with underlined text.
 */
static const HIGHLIGHT_STYLE_UNDERLINE_TEXT  = "Underline text";
/**
 * Use the extended color palette with strike-through text.
 */
static const HIGHLIGHT_STYLE_STRIKETHRU_TEXT = "Strikethrough";
/**
 * Use the extended color palette with the highlight color background.
 */
static const HIGHLIGHT_STYLE_HIGHLIGHT_COLOR = "Highlight color";


/**
 * Read-only table mapping highlight word kind codes used by 
 * {@link se.color.HighlightToolWindowOptions} style flags to captions 
 * to display in the Highlight tool window. 
 */
static _str g_HighlightStyleOptions:[] = {
   HIGHLIGHT_TW_USE_REVERSE_COLORS  => HIGHLIGHT_STYLE_REVERSE_COLORS,
   HIGHLIGHT_TW_USE_PALETTE_COLORS  => HIGHLIGHT_STYLE_COLOR_TEXT,
   HIGHLIGHT_TW_USE_BOLD_TEXT       => HIGHLIGHT_STYLE_BOLD_TEXT,
   HIGHLIGHT_TW_USE_UNDERLINE_TEXT  => HIGHLIGHT_STYLE_UNDERLINE_TEXT,
   HIGHLIGHT_TW_USE_STRIKETHRU_TEXT => HIGHLIGHT_STYLE_STRIKETHRU_TEXT,
   HIGHLIGHT_TW_USE_HIGHLIGHT_COLOR => HIGHLIGHT_STYLE_HIGHLIGHT_COLOR,
};


class HighlightOptions {

   /** 
    * @return
    * Map the given highlight style option to the caption to display for it.
    * 
    * @param highlight_option    bitset of HIGHLIGHT_TW_USE_*
    *  
    * @see HighlightToolWindowOptions
    */
   static _str textStyleCaption(HighlightToolWindowOptions highlight_option)
   {
      if (g_HighlightStyleOptions._indexin(highlight_option)) {
         return g_HighlightStyleOptions:[(int)highlight_option];
      }
      style_caption := "";
      foreach (auto kind => auto caption in g_HighlightStyleOptions) {
         if (highlight_option & kind) {
            _maybe_append(style_caption, ", ");
            style_caption :+= caption;
         }
      }
      return style_caption;
   }

   /**
    * @return 
    * Map the given caption to the corresponding highlight style option.
    * 
    * @param caption     caption from Highlight tool window. 
    *  
    * @see HighlightToolWindowOptions
    */
   static HighlightToolWindowOptions textStyleOption(_str caption)
   {
      foreach (auto option => auto option_caption in g_HighlightStyleOptions) {
         if (caption == option_caption) {
            return option;
         }
      }
      return HIGHLIGHT_TW_NULL;
   }
   
   /** 
    * Place all of the highlight style captions in an array of strings.
    */
   static void textStyleCaptionList(_str (&list)[])
   {
      list._makeempty();
      list :+= HIGHLIGHT_STYLE_REVERSE_COLORS;
      list :+= HIGHLIGHT_STYLE_COLOR_TEXT;
      list :+= HIGHLIGHT_STYLE_BOLD_TEXT;
      list :+= HIGHLIGHT_STYLE_UNDERLINE_TEXT;
      list :+= HIGHLIGHT_STYLE_STRIKETHRU_TEXT;
      list :+= HIGHLIGHT_STYLE_HIGHLIGHT_COLOR;
   }

};


namespace default;


/**
 * Options for highlight tool window.  Primarly controls what colors are 
 * selected from the color palette for highlighting. 
 * 
 * @default  3
 * @category Configuration_Variables
 */
int def_highlight_tw_options = se.color.HIGHLIGHT_TW_DEFAULT;


/** 
 * Number of milliseconds of idle time to wait before updating 
 * the word highlighting for the current file.
 * 
 * @default 500 ms (1/2 second)
 * @categories Configuration_Variables
 */
int def_highlight_tw_delay = 500;

/** 
 * Number of milliseconds of time to allow word highlighting to spend 
 * during each pass.  If this isn't enough time, the screen may 
 * be only partially painted. 
 * 
 * @default 100 ms (1/10 second)
 * @categories Configuration_Variables
 */
int def_highlight_tw_timeout = 100;

/** 
 * Number of lines to color above and below the current page when 
 * calculating highlighting.  The lines on the current page are 
 * calculated first, then the off-page lines are calculated on 
 * subsequent passes.  This makes it possible for highlighting 
 * to already be up-to-date and available immediately when you page 
 * up if there has been a sufficient amount of time for it to be 
 * pre-calculated. 
 *
 * @default 200 lines
 * @categories Configuration_Variables
 */
int def_highlight_tw_off_page_lines = 2000;

/** 
 * Number of lines to color per pass when calculating highlighting 
 * for off-page lines.  By breaking the highlighting work into passes, 
 * each one doing a small chunk of lines, we are able to guard against 
 * highlighting monopolizing the CPU and provide more consistent smooth 
 * performance. 
 *
 * @default 50 lines
 * @categories Configuration_Variables
 */
int def_highlight_tw_chunk_size = 100;


/**
 * Which windows to perform highlighting for.  Use the 
 * VISIBLE_EDITOR_WINDOWS_SCOPE enum.  Possible values: 
 * <ul> 
 * <li>VT_CURRENT_WINDOW  - color current window only </li>
 * <li>VT_VISIBLE_WINDOWS - color all visible windows </li>
 * <li>VT_ALL_WINDOWS     - color all windows         </li>
 * </ul>
 *
 * @default VT_CURRENT_WINDOW
 * @categories Configuration_Variables
 */
int def_highlight_tw_windows = VT_VISIBLE_WINDOWS;


