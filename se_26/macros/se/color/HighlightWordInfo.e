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
#include "search.sh"
#import "dlgman.e"
#import "stdprocs.e"
#import "se/color/ColorIdAllocator.e"
#import "se/color/HighlightOptions.e"
#import "se/lang/api/LanguageSettings.e"
#endregion

/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;


////////////////////////////////////////////////////////////////////////////////

/**
 * Increment {@link se.color.HighlightWordInfo#m_colorIndex} by this amount to 
 * cycle to the next color in the extended palette. 
 */
const HIGHLIGHT_TW_SMALL_COLOR_INCREMENT = 1;
/**
 * Increment {@link se.color.HighlightWordInfo#m_colorIndex} by this amount to 
 * cycle to the previous color in the extended palette. 
 */
const HIGHLIGHT_TW_SMALL_COLOR_DECREMENT = -1;
/**
 * Increment {@link se.color.HighlightWordInfo#m_colorIndex} by this amount to cycle 
 * to the next more visually distinct color in the extended palette. 
 *  
 * @note 
 * This number is chosen because {@literal 13 &times; 5} is {@literal 65}, 
 * which is one more than the number of colors in the extended color palette.  
 */
const HIGHLIGHT_TW_LARGE_COLOR_INCREMENT = 5;


////////////////////////////////////////////////////////////////////////////////

/**
 * Caption to use for SlickEdit regular expression.
 */
static const HIGHLIGHT_TYPE_SLICK_REGEX = "Slick RE";
/**
 * Caption to use for Perl regular expression.
 */
static const HIGHLIGHT_TYPE_PERL_REGEX  = "Perl RE";
/**
 * Caption to use for Vim regular expression.
 */
static const HIGHLIGHT_TYPE_VIM_REGEX   = "Vim RE";
/**
 * Caption to use for word match (identifier match). 
 * The pattern must match a word both beginning and ending on a word boundary.
 */
static const HIGHLIGHT_TYPE_WORD        = "Word";
/**
 * Caption to use for simple substring/string match.
 */
static const HIGHLIGHT_TYPE_STRING      = "String";


////////////////////////////////////////////////////////////////////////////////

/**
 * Case sensitive (exact case)
 */
static const HIGHLIGHT_TYPE_CASE_SENSITIVE   = "Match";
/**
 * Case insensitive (ignore case)
 */
static const HIGHLIGHT_TYPE_CASE_INSENSITIVE = "Ignore";
/**
 * Case depends on language mode case sensitivity (Language case)
 */
static const HIGHLIGHT_TYPE_CASE_LANGUAGE    = "Language";


////////////////////////////////////////////////////////////////////////////////

/**
 * Word pattern applies to all language modes.
 */
static const HIGHLIGHT_TW_ALL_LANGUAGES = "(All)";


////////////////////////////////////////////////////////////////////////////////

/**
 * Read-only table mapping highlight word kind codes used by 
 * {@link se.color.HighlightWordInfo#m_wordKind} to captions to display in 
 * the Highlight tool window. 
 */
static _str g_HighlightWordKinds:[] = {
   'R' => HIGHLIGHT_TYPE_SLICK_REGEX,
   'L' => HIGHLIGHT_TYPE_PERL_REGEX,
   'V' => HIGHLIGHT_TYPE_VIM_REGEX,
   'W' => HIGHLIGHT_TYPE_WORD,
   'S' => HIGHLIGHT_TYPE_STRING,
};

/**
 * Read-only table mapping highlight word case option codes used by 
 * {@link se.color.HighlightWordInfo#m_caseOption} to captions to display in 
 * the Highlight tool window. 
 */
static _str g_HighlightWordCaseOptions:[] = {
   'E' => HIGHLIGHT_TYPE_CASE_SENSITIVE,
   'I' => HIGHLIGHT_TYPE_CASE_INSENSITIVE,
   'A' => HIGHLIGHT_TYPE_CASE_LANGUAGE,
};


////////////////////////////////////////////////////////////////////////////////

/**
 * The {@code HighlightWordInfo} class represents one word pattern for the 
 * Highlight tool window.  A word pattern can be either a regular expression, 
 * a substring match, or a word match.  There are three case-sensitivity 
 * options, and the pattern can be restricted to certain languages. 
 * Finally, a word pattern can be disabled. 
 *  
 * An array of word patterns make a highlighting profile, which is represented 
 * by the {@link HighlightProfile} class. 
 */
class HighlightWordInfo {

   /**
    * Is this word pattern enabled or disabled?
    */
   bool m_enabled = false;

   /**
    * The word pattern.  This is the expression, either a word, string, or 
    * regular expression to search using. 
    */
   _str m_wordPattern = "";

   /**
    * This value is used to select a color from the extended coloring palette. 
    * The value should be non-negative, but otherwise there are no restrictions. 
    * It will be by 64 and the remainder will be used to select which color is used. 
    */
   int m_colorIndex = 0;

   /**
    * The kind of word pattern.  One of the following: 
    * <dl compact> 
    * <dt>{@literal 'S'}</dt><dd>String match</dd>
    * <dt>{@literal 'W'}</dt><dd>Word (language-defined identifier) match</dd>
    * <dt>{@literal 'R'}</dt><dd>SlickEdit regular expression</dd>
    * <dt>{@literal 'L'}</dt><dd>Perl regular expression</dd>
    * <dt>{@literal 'V'}</dt><dd>Vim regular expression</dd>
    * </dl>
    *  
    * @see g_HighlightWordKinds 
    * @see HIGHLIGHT_TYPE_SLICK_REGEX
    * @see HIGHLIGHT_TYPE_PERL_REGEX
    * @see HIGHLIGHT_TYPE_VIM_REGEX
    * @see HIGHLIGHT_TYPE_WORD
    * @see HIGHLIGHT_TYPE_STRING
    */
   _str m_wordKind = 'S';

   /**
    * Defines whether or not the word pattern should be matched using 
    * a case-sensitive string search.  One of teh following: 
    * <dl compact> 
    * <dt>{@literal 'I'}</dt><dd>Case insensitive (Ignore case)</dd>
    * <dt>{@literal 'E'}</dt><dd>Case sensitive   (Exact case)</dd>
    * <dt>{@literal 'A'}</dt><dd>Case depends on language mode.</dd>
    * </dl> 
    *  
    * @see HIGHLIGHT_TYPE_CASE_SENSITIVE
    * @see HIGHLIGHT_TYPE_CASE_INSENSITIVE
    * @see HIGHLIGHT_TYPE_CASE_LANGUAGE
    */
   _str m_caseOption = 'I';

   /**
    * If null or the empty string, this word pattern will apply to all 
    * language modes.  Otherwise, it applies only in the selected mode. 
    */
   _str m_langId = "";


   // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   // ┃ WORD PATTERN                                                           ┃
   // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

   /** 
    * @return 
    * Escape special characters in the word pattern in order to display it 
    * clearly in a tree control caption.
    */
   _str getEscapedWordPattern()
   {
      word := m_wordPattern;
      index := pos('[\n\t\v\b\r\f\a\0\1\2\3\4\5\6]', word, 1, 'r');
      while (index > 0) {
         ch := "";
         switch (substr(word, index, 1)) {
         case "\n":  ch = '\n'; break;
         case "\t":  ch = '\t'; break;
         case "\v":  ch = '\v'; break;
         case "\b":  ch = '\b'; break;
         case "\r":  ch = '\r'; break;
         case "\f":  ch = '\f'; break;
         case "\a":  ch = '\a'; break;
         case "\0":  ch = '\0'; break;
         case "\1":  ch = '\1'; break;
         case "\2":  ch = '\2'; break;
         case "\3":  ch = '\3'; break;
         case "\4":  ch = '\4'; break;
         case "\5":  ch = '\5'; break;
         case "\6":  ch = '\6'; break;
         }
         if (ch :!= "") {
            word = substr(word,1,index-1) :+ ch :+ substr(word, index+1);
         }
         index = pos('[\n\t\v\b\r\f\a\0\1\2\3\4\5\6\7]', word, index+1, 'r');
      }
      return word;
   }

   /**
    * Replace the word pattern with the given word pattern, which may include 
    * escaped special characters.
    * 
    * @param word      word pattern from tree control caption
    */
   void setEscapedWordPattern(_str word)
   {
      index := pos('\', word, 1);
      while (index > 0) {
         ch := "";
         switch (substr(word,index+1,1)) {
         case 'n':  ch = "\n"; break;
         case 't':  ch = "\t"; break;
         case 'v':  ch = "\v"; break;
         case 'b':  ch = "\b"; break;
         case 'r':  ch = "\r"; break;
         case 'f':  ch = "\f"; break;
         case 'a':  ch = "\a"; break;
         case '0':  ch = "\0"; break;
         case '1':  ch = "\1"; break;
         case '2':  ch = "\2"; break;
         case '3':  ch = "\3"; break;
         case '4':  ch = "\4"; break;
         case '5':  ch = "\5"; break;
         case '6':  ch = "\6"; break;
         case '7':  ch = "\7"; break;
         case '"':  ch = "\""; break;
         case "'":  ch = "\'"; break;
         case '?':  ch = "\?"; break;
         case '\':  ch = "\\"; break;
         }
         if (ch :!= "") {
            word = substr(word, 1, index-1) :+ ch :+ substr(word, index+2);
         }
         index = pos('\', word, index+1);
      }
      m_wordPattern = word;
   }

   /**
    * Replace the word pattern with the given regex pattern, which may include 
    * escaped delimeters slash or backtick
    * 
    * @param word      word pattern from tree control caption
    */
   void setEscapedRegexPattern(_str word)
   {
      index := pos('\', word, 1);
      while (index > 0) {
         ch := "";
         switch (substr(word,index+1,1)) {
         case '/':  ch = "/";  break;
         case '`':  ch = "`";  break;
         }
         if (ch :!= "") {
            word = substr(word, 1, index-1) :+ ch :+ substr(word, index+2);
         }
         index = pos('\', word, index+1);
      }
      m_wordPattern = word;
   }



   // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   // ┃ WORD COLOR                                                             ┃
   // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

   /**
    * Get the color options for highlighting this word pattern 
    * in the Highlight tool window's tree control. 
    * 
    * @param colorSchemeName    editor color profile name to use
    * @param fg_color           (output) set foreground color to use
    * @param bg_color           (output) set background color to use
    * @param font_flags         (output) set to font flags (F_*) to use
    */
   void getHighlightWordColor(_str colorSchemeName,
                              int &fg_color, int &bg_color, int &font_flags)
   {
      font_flags = 0;
      fg_color = 0;
      bg_color = 0xffffff;

      reverseColors := false;
      index  := (m_colorIndex % (CFG_LAST_SYMBOL_COLOR - CFG_SYMBOL_COLOR_PALETTE_00 + 1));
      fg_cfg := (CFGColorConstants)(CFG_SYMBOL_COLOR_PALETTE_00 + index);
      bg_cfg := fg_cfg;

      if (def_highlight_tw_options & HIGHLIGHT_TW_USE_REVERSE_COLORS ) {
         reverseColors = true;
      } else if (def_highlight_tw_options & HIGHLIGHT_TW_USE_HIGHLIGHT_COLOR) {
         bg_cfg = CFG_HILIGHT;
      } else if (def_highlight_tw_options & HIGHLIGHT_TW_USE_BOLD_TEXT ) {
         font_flags = F_BOLD;
      } else if (def_highlight_tw_options & HIGHLIGHT_TW_USE_UNDERLINE_TEXT ) {
         font_flags = F_UNDERLINE;
      } else if (def_highlight_tw_options & HIGHLIGHT_TW_USE_STRIKETHRU_TEXT) {
         font_flags = F_STRIKE_THRU;
      } else {
         font_flags = 0;
      }

      parse _default_color(fg_cfg, -1, -1, -1, 0, colorSchemeName) with auto fg auto bg . ;
      if (bg_cfg == CFG_HILIGHT) {
         parse _default_color(CFG_HILIGHT, -1, -1, -1, 0, colorSchemeName) with . bg . ;
         parse _default_color(CFG_WINDOW_TEXT, -1, -1, -1, 0, colorSchemeName) with . auto win_bg . ;
         bg = ColorIdAllocator.adjustBackgroundColor((int)bg, (int)win_bg);
      }
      if (reverseColors) {
         if (isinteger(fg)) bg_color = (int)fg;
         if (isinteger(bg)) fg_color = (int)bg;
      } else {
         if (isinteger(fg)) fg_color = (int)fg;
         if (isinteger(bg)) bg_color = (int)bg;
      }
      return;
   }

   /**
    * @return 
    * Return the color index of the color to use for this word pattern when 
    * creating a stream marker for a word pattern match. 
    * 
    * @param colorSchemeName    editor color profile name to use
    * @param marker_flags       (output) set to stream marker flags to use, 
    *                           a bitset of VSMARKTYPEFLAG_* 
    */
   CFGColorConstants getHighlightMarkerColor(_str colorSchemeName, int &marker_flags)
   {
      index := (m_colorIndex % (CFG_LAST_SYMBOL_COLOR - CFG_SYMBOL_COLOR_PALETTE_00 + 1));
      cfg_color := (CFGColorConstants)(CFG_SYMBOL_COLOR_PALETTE_00 + index);
      marker_flags = 0;
      if (def_highlight_tw_options & HIGHLIGHT_TW_USE_REVERSE_COLORS ) {
         marker_flags = VSMARKERTYPEFLAG_REVERSE_COLOR;
      } else if (def_highlight_tw_options & HIGHLIGHT_TW_USE_HIGHLIGHT_COLOR) {
         parse _default_color(cfg_color, -1, -1, -1, 0, colorSchemeName) with auto fg auto bg . ;
         parse _default_color(CFG_HILIGHT, -1, -1, -1, 0, colorSchemeName) with . bg . ;
         parse _default_color(CFG_WINDOW_TEXT, -1, -1, -1, 0, colorSchemeName) with . auto win_bg . ;
         bg = ColorIdAllocator.adjustBackgroundColor((int)bg, (int)win_bg);
         cfg_color = ColorIdAllocator.getColorId((int)fg, (int)bg, 0, CFG_HILIGHT, colorSchemeName);
      } else if (def_highlight_tw_options & HIGHLIGHT_TW_USE_BOLD_TEXT ) {
         marker_flags = VSMARKERTYPEFLAG_FONT_BOLD;
      } else if (def_highlight_tw_options & HIGHLIGHT_TW_USE_UNDERLINE_TEXT ) {
         marker_flags = VSMARKERTYPEFLAG_FONT_UNDERLINE;
      } else if (def_highlight_tw_options & HIGHLIGHT_TW_USE_STRIKETHRU_TEXT) {
         marker_flags = VSMARKERTYPEFLAG_FONT_STRIKETHRU;
      }
      return cfg_color;
   }


   // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   // ┃ WORD KINDS                                                             ┃
   // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

   /** 
    * @return
    * Map the given word kind code to the caption to display for it.
    * 
    * @param kind    word kind 
    *  
    * @see m_wordKind 
    */
   static _str captionFromWordKind(_str kind)
   {
      kind = upcase(kind);
      if (g_HighlightWordKinds._indexin(kind)) {
         return g_HighlightWordKinds:[kind];
      }
      if (kind == '&') {
         return "Wildcards";
      }
      if (kind == '~') {
         return g_HighlightWordKinds:['V'];
      }
      return "";
   }
   /**
    * @return 
    * Map the given caption to the corresponding word kind code. 
    * 
    * @param caption     caption from Highlight tool window.
    */
   static _str wordKindFromCaption(_str caption)
   {
      switch (caption) {
      case RE_TYPE_SLICKEDIT_STRING:   return 'R';
      case RE_TYPE_PERL_STRING:        return 'L';
      case RE_TYPE_VIM_STRING:         return 'V';
      case RE_TYPE_WILDCARD_STRING:    return '&';  // not used
      }
      foreach (auto kind => auto kind_caption in g_HighlightWordKinds) {
         if (kind_caption == caption) {
            return kind;
         }
      }
      return "";
   }

   /** 
    * @return
    * Return the caption for this word pattern's type.
    */
   _str getWordKindCaption()
   {
      kind := upcase(m_wordKind);
      if (g_HighlightWordKinds._indexin(kind)) {
         return g_HighlightWordKinds:[kind];
      }
      if (m_wordKind == '&') {
         return "Wildcards";
      }
      if (m_wordKind == '~') {
         return g_HighlightWordKinds:['V'];
      }
      return "";
   }
   /**
    * Set the word kind from the given word kind caption.
    * 
    * @param caption     caption from Highlight tool window.
    */
   void setWordKindFromCaption(_str caption)
   {
      m_wordKind = wordKindFromCaption(caption);
   }

   /** 
    * @return 
    * Calculate the width of the longest word kind caption.
    * 
    * @param tree_wid        tree window ID
    * @param column_header   tree column header (default "Kind")
    */
   static int wordKindCaptionWidth(int tree_wid, _str column_header="Kind")
   {
      kind_width := tree_wid._text_width(column_header);
      foreach (auto kind_caption in g_HighlightWordKinds) {
         kind_width = max(kind_width, tree_wid._text_width(kind_caption));
      }
      return kind_width;
   }

   /** 
    * Place all of the word kind captions in an array of strings.
    */
   static void wordKindCaptionList(_str (&list)[])
   {
      list._makeempty();
      foreach (auto kind_caption in g_HighlightWordKinds) {
         list :+= kind_caption;
      }
   }


   // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   // ┃ CASE SENSITIVITY OPTIONS                                               ┃
   // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

   /** 
    * @return
    * Map the given word case code to the caption to display for it.
    * 
    * @param case    word case sensitivity option 
    *  
    * @see m_wordCase 
    */
   static _str captionFromCaseOption(_str case_option)
   {
      case_option = upcase(case_option);
      if (g_HighlightWordCaseOptions._indexin(case_option)) {
         return g_HighlightWordCaseOptions:[case_option];
      }
      return "";
   }
   /**
    * @return 
    * Map the given caption to the corresponding word case sensitivity option.
    * 
    * @param caption     caption from Highlight tool window.
    */
   static _str wordCaseFromCaption(_str caption)
   {
      foreach (auto case_option => auto case_caption in g_HighlightWordCaseOptions) {
         if (case_caption == caption) {
            return case_option;
         }
      }
      return "";
   }

   /** 
    * @return
    * Return the caption for this word pattern's case sensitivity option.
    */
   _str getWordCaseCaption()
   {
      case_option := upcase(m_caseOption);
      if (g_HighlightWordCaseOptions._indexin(case_option)) {
         return g_HighlightWordCaseOptions:[case_option];
      }
      return "";
   }
   /**
    * Set the word case sensitivity option from the given word case caption.
    * 
    * @param caption     caption from Highlight tool window.
    */
   void setWordCaseFromCaption(_str caption)
   {
      m_caseOption = wordCaseFromCaption(caption);
   }

   /** 
    * @return 
    * Calculate the width of the longest word case sensitivity option caption.
    * 
    * @param tree_wid        tree window ID
    * @param column_header   tree column header (default "Case")
    */
   static int wordCaseCaptionWidth(int tree_wid, _str column_header="Case")
   {
      case_width := tree_wid._text_width(column_header);
      foreach (auto case_caption in g_HighlightWordCaseOptions) {
         case_width = max(case_width, tree_wid._text_width(case_caption));
      }
      return case_width;
   }

   /** 
    * Place all of the word case sensitivity option captions in an array of strings.
    */
   static void wordCaseCaptionList(_str (&list)[])
   {
      list._makeempty();
      foreach (auto case_caption in g_HighlightWordCaseOptions) {
         list :+= case_caption;
      }
   }


   // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   // ┃ LANGUAGE MODE OPTIONS                                                  ┃
   // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

   /** 
    * @return
    * Map the given language mode option to the caption to display for it.
    * 
    * @param langId     empty string or a language mode ID 
    *  
    * @see m_langId
    */
   static _str captionFromLangId(_str langId)
   {
      if (length(langId) == 0) {
         return HIGHLIGHT_TW_ALL_LANGUAGES;
      }
      mode := _LangId2Modename(langId);
      if (mode == null) return "";
      return mode;
   }
   /**
    * @return 
    * Map the given caption to the corresponding language mode option.
    * 
    * @param mode     caption from Highlight tool window.
    */
   static _str langIdFromCaption(_str mode)
   {
      if (length(mode) == 0 || mode == HIGHLIGHT_TW_ALL_LANGUAGES) {
         return "";
      }
      return _Modename2LangId(mode);
   }

   /** 
    * @return
    * Return the caption for this word language mode option.
    */
   _str getLanguageModeCaption()
   {
      return captionFromLangId(m_langId);
   }
   /**
    * Set the language mode option from the given mode caption.
    * 
    * @param mode     caption from Highlight tool window.
    */
   void setLangIdFromCaption(_str mode)
   {
      if (length(mode) == 0 || mode == HIGHLIGHT_TW_ALL_LANGUAGES) {
         m_langId = "";
      } else {
         m_langId = _Modename2LangId(mode);
      }
   }

   /** 
    * @return 
    * Calculate the width of the longest language mode option caption. 
    * 
    * @param tree_wid        tree window ID
    * @param column_header   tree column header (default "Mode") 
    *  
    * @note 
    * This only considers a small set of language modes, ones with longer 
    * mode names like "Module-Definition File" will get clipped. 
    * This is intentional to make the best use of available space. 
    */
   static int languageModeCaptionWidth(int tree_wid, _str column_header="Mode")
   {
      mode_width := tree_wid._text_width(column_header);
      mode_width = max(mode_width, tree_wid._text_width(HIGHLIGHT_TW_ALL_LANGUAGES));
      mode_width = max(mode_width, tree_wid._text_width("C/C++"));
      mode_width = max(mode_width, tree_wid._text_width("Pascal"));
      mode_width = max(mode_width, tree_wid._text_width("Verilog"));
      mode_width = max(mode_width, tree_wid._text_width("Plain Text"));
      mode_width = max(mode_width, tree_wid._text_width("Bourne Shell"));
      return mode_width;
   }

   /** 
    * Place all of the language mode option captions in an array of strings.
    */
   static void languageModeCaptionList(_str (&list)[])
   {
      list._makeempty();
      list :+= HIGHLIGHT_TW_ALL_LANGUAGES;
      se.lang.api.LanguageSettings.getAllLanguageIds(auto langs);
      foreach (auto langId in langs) {
         modeName := _LangGetModeName(langId);
         list :+= modeName;
      }
      list._sort('i', 1);
   }

}

