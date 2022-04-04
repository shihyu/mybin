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
#include "markers.sh"
#include "plugin.sh"
#require "se/color/HighlightWordInfo.e"
#import "se/color/HighlightOptions.e"
#import "cfg.e"
#import "listbox.e"
#import "markfilt.e"
#import "stdcmds.e"
#import "stdprocs.e"
#endregion

/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;


/**
 * Set the Highlight tool window to this profile to disable highlighting.
 */
static const HIGHLIGHT_DISABLE_PROFILE_NAME = "(None)";

/**
 * Default highlight profile name.
 */
static const HIGHLIGHT_DEFAULT_PROFILE_NAME = "Default";


/**
 * Attribute name used in highlight profile node for the word pattern.
 */
static const HIGHLIGHT_PROFILE_STRING_NAME  = "str";
/**
 * Attribute name used in highlight profile node for options.
 */
static const HIGHLIGHT_PROFILE_OPTIONS_NAME = "opt";
/**
 * Attribute name used in highlight profile node for the langauge mode.
 */
static const HIGHLIGHT_PROFILE_LANG_NAME    = "lang";


/**
 * Hash table of profile names and their latest generation counters.
 */
static long g_HighlightProfileGenerations:[] = null;


/**
 * This class represents a Highlight profile used by the Highglight tool 
 * window and the {@link HighlightAnalyzer}.  It contains a profile name and 
 * a list of word patterns ({@link HighlightWordInfo}. 
 */
class HighlightProfile {

   /**
    * The 'generation' of this highlight profile instance. 
    * Each time a profile is modified its generation is incremented. 
    * This can be used to detect if a profile has been updated. 
    */
   protected long m_generation = 0;

   /**
    * The name of the profile. 
    *  
    * The names {@literal "Default"} and {@literal "(None)"} are reserved.
    */
   protected _str m_profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;

   /**
    * The list of word patterns in this profile. 
    * @see HighlightWordInfo
    */
   HighlightWordInfo m_words[] = null;

   /**
    * The SlickEdit regular expression calculated after combing all of the 
    * word patterns that are not Perl or Vim regular exprssions. 
    */
   private _str m_slick_regex = "";
   /**
    * The Perl regular expression calculated after combing all of the 
    * word patterns that are not SlickEdit or Vim regular exprssions. 
    */
   private _str m_perl_regex = "";
   /**
    * The Vim regular expression calculated after combing all of the 
    * word patterns that are not SlickEdit or Perl regular exprssions. 
    */
   private _str m_vim_regex = "";

   /**
    * The common regular expression type shared by all the regular expression 
    * type word patterns in the collection.  If there are mixed regular 
    * expression types, this will be the first one. 
    *  
    * @see se.color.HighlightWordInfo#m_wordKind 
    */
   private _str m_common_re_type = "";

   /**
    * Set to {@code true} if there are SlickEdit regular expression patterns 
    * in the collection. 
    */
   private bool m_have_mixed_slick_re = false;
   /**
    * Set to {@code true} if there are Perl regular expression patterns 
    * in the collection. 
    */
   private bool m_have_mixed_perl_re = false;
   /**
    * Set to {@code true} if there are Vim regular expression patterns 
    * in the collection. 
    */
   private bool m_have_mixed_vim_re = false;


   /**
    * Initialize this object with the given profile. 
    *  
    * @param profileName   name of this profile
    */
   HighlightProfile(_str profileName="")
   {
      m_profileName         = profileName;
      m_words               = null;

      m_slick_regex         = "";
      m_perl_regex          = "";
      m_vim_regex           = "";
      m_common_re_type      = "";
      m_have_mixed_slick_re = false;
      m_have_mixed_perl_re  = false;
      m_have_mixed_vim_re   = false;

      m_generation = 0;
      if (g_HighlightProfileGenerations._indexin(profileName)) {
         m_generation = g_HighlightProfileGenerations:[profileName];
      } else {
         g_HighlightProfileGenerations:[profileName] = 0;
      }
   }


   /** 
    * @return
    * Return the name for this profile.
    */
   _str getProfileName() {
      return m_profileName;
   }
   /**
    * Set the name of this profile.
    * @param profilename    new profile name
    */
   void setProfileName(_str newProfileName) {
      m_profileName = newProfileName;
   }


   /**
    * @return 
    * Return the generation of this highlighting profile. 
    */
   long getGeneration() {
      return m_generation;
   }
   /**
    * Set the generation counter for this highlighting profile.
    */
   void setGeneration(long n) {
      m_generation = n;
   }
   /**
    * Increment the generation counter for this highlighting profile.
    */
   void incrementGeneration() {
      m_generation++;
   }

   /**
    * Increment the global generation counter for this highlighting profile.
    */
   static void incrementSavedGeneration(_str profileName)
   {
      if (g_HighlightProfileGenerations._indexin(profileName)) {
         g_HighlightProfileGenerations:[profileName]++;
      } else {
         g_HighlightProfileGenerations:[profileName] = 0;
      }
   }

   /**
    * Has the generation changed for this profile information?
    */
   bool hasGenerationChanged()
   {
      if (!g_HighlightProfileGenerations._indexin(m_profileName) ||
           m_generation != g_HighlightProfileGenerations:[m_profileName]) {
         return true;
      }
      return false;
   }


   /**
    * Construct a new word pattern for the current text under the cursor.
    * If the user has a selection, use the selected text, otherwise, take 
    * the identifier under the cursor.  If there is no identifier under the 
    * cursor, and the cursor is in column 1, use the entire line as a pattern. 
    * 
    * @param editorctl_wid    editor control window, 0 for current window
    * @param wordInfo         (output) matching word pattern (if found) 
    * @param quiet            no message boxes if we can not get a result 
    * 
    * @return 
    * Returns the index (&gt;=0) of the word pattern found, 
    * otherwise returns an error &lt;0.
    */
   int getNewPatternUnderCursor(int editorctl_wid, HighlightWordInfo &wordInfo, bool quiet=false)
   {
      // make sure the current object is an editor control
      if (!editorctl_wid && _isEditorCtl()) {
         editorctl_wid = p_window_id;
      } else if (!editorctl_wid || !editorctl_wid._isEditorCtl()) {
         return VSRC_INVALID_ARGUMENT;
      }
      orig_wid := p_window_id;
      p_window_id = editorctl_wid;

      // create a hash table of the existing wod patterns
      // and calculate the last index in use
      bool wordHash:[];
      wordIndex := m_words._length();
      lastIndexUsed := -HIGHLIGHT_TW_LARGE_COLOR_INCREMENT;
      foreach (wordInfo in m_words) {
         if (wordInfo._isempty()) continue;
         wordHash:[wordInfo.m_wordKind:+wordInfo.m_wordPattern] = true;
         if (wordInfo.m_colorIndex > lastIndexUsed) {
            lastIndexUsed = wordInfo.m_colorIndex;
         }
      }

      // calculate the new color index and other options
      wordInfo.m_colorIndex = (lastIndexUsed + HIGHLIGHT_TW_LARGE_COLOR_INCREMENT);
      wordInfo.m_enabled = false;
      wordInfo.m_caseOption = (def_highlight_tw_options & HIGHLIGHT_TW_CASE_SENSITIVE)? 'E':'I';
      if (def_highlight_tw_options & HIGHLIGHT_TW_CASE_LANGUAGE) {
         wordInfo.m_caseOption = 'L';
      }
      wordInfo.m_langId = "";
      if (def_highlight_tw_options & HIGHLIGHT_TW_RESTRICT_LANGUAGE) {
         wordInfo.m_langId = p_LangId;
      }

      // have active selection?
      if (select_active2()) {
         wordInfo.m_wordKind = 'S';
         mark_locked := 0;
         if (_select_type('', 'S') == 'C') {
            mark_locked = 1;
            _select_type('', 'S', 'E');
         }
         filter_init();
         filter_get_string(wordInfo.m_wordPattern, 1024);
         filter_restore_pos();
         if (mark_locked) {
            _select_type('', 'S','C');
         }
      } else {
         // check for current identifier under cursor or whole line
         word := cur_identifier(auto start_col);
         if (word != "") {
            wordInfo.m_wordKind = 'W';
            wordInfo.m_wordPattern = word;
         } else if (p_col == 1) {
            wordInfo.m_wordKind = 'S';
            get_line(wordInfo.m_wordPattern);
         } else {
            wordInfo.m_wordKind = 'S';
            wordInfo.m_wordPattern = "";
         }
      }

      // no word pattern found
      if (wordInfo.m_wordPattern == "") {
         if (!quiet) {
            _message_box("No word under cursor to highlight.\nMove cursor to column 1 to highlight entire line.");
         }
         p_window_id = orig_wid;
         return STRING_NOT_FOUND_RC;
      }

      // found a new word pattern, but we already have one
      if (!quiet && wordHash._indexin(wordInfo.m_wordKind:+wordInfo.m_wordPattern)) {
         _message_box("Word '":+wordInfo.m_wordPattern:+'" is already highlighted.');
         p_window_id = orig_wid;
         return TEXT_ALREADY_SELECTED_RC;
      }

      // success
      p_window_id = orig_wid;
      return wordIndex;
   }

   /**
    * Search the current line for a word pattern match in this configuration 
    * which falls under the current cursor position. 
    * 
    * @param editorctl_wid    editor control window, 0 for current window
    * @param wordInfo         (output) matching word pattern (if found)
    * 
    * @return 
    * Returns the index (&gt;=0) of the word pattern found, 
    * otherwise returns an error &lt;0.
    */
   int findWordMatchUnderCursor(int editorctl_wid, HighlightWordInfo &wordInfo)
   {
      // make sure the current object is an editor control
      if (!editorctl_wid && _isEditorCtl()) {
         editorctl_wid = p_window_id;
      } else if (!editorctl_wid || !editorctl_wid._isEditorCtl()) {
         return VSRC_INVALID_ARGUMENT;
      }
      orig_wid := p_window_id;
      p_window_id = editorctl_wid;

      // get the raw line under the cursor, truncate if necessary
      get_line_raw(auto line);
      if (p_TruncateLength > 0) {
         line=substr(line,1,_TruncateLengthC());
      }
      //say("FindHighlightWordMatchUnderCursor H"__LINE__": line="line);

      // iterate though the words in the list and see if their regex would match
      foreach (auto i => wordInfo in m_words) {
         // skip deleted words
         if (wordInfo._isempty()) continue;

         // figure out the case sensitivity option
         search_options := "";
         case_sensitive := p_LangCaseSensitive;
         switch (upcase(wordInfo.m_caseOption)) {
         case 'E':
         case 'I':
            search_options :+= wordInfo.m_caseOption;
            break;
         case 'L':
            search_options :+= (p_LangCaseSensitive? 'E':'I');
            break;
         }

         // convert to a regular expression
         word_re := wordInfo.m_wordPattern;
         switch (upcase(wordInfo.m_wordKind)) {
         case 'W':
            word_re = '\o<' :+ _escape_re_chars(word_re, 'R') :+ '\o>';
            search_options :+= 'R';
            break;
         case 'R':
            search_options :+= 'R';
            break;
         case 'S':
            break;
         case 'L':
         case 'U':
         case 'B':
            search_options :+= 'L';
            break;
         case 'V':
         case '~':
            search_options :+= '~';
            break;
         default:
            break;
         }

         col := 1;
         loop {
            p := pos(word_re, line, col, p_rawpos:+search_options);
            //say("highlight_toggle_word_enabled H"__LINE__": pattern="word_re" col="col" options="search_options" p="p);
            if (p <= 0) {
               break;
            }
            col = _text_colc(p, 'I');
            //say("highlight_toggle_word_enabled H"__LINE__": col="col" p_col="p_col" length="pos(''));
            if (p_col >= col && p_col <= col+pos('')) {
               p_window_id = orig_wid;
               return i;
            }
            col++;
         }
      }

      p_window_id = orig_wid;
      return STRING_NOT_FOUND_RC;
   }

   /**
    * Check if there is a highlighted word under the cursor, and if so, 
    * return the word pattern information and it's index in the word list. 
    * 
    * @param editorctl_wid        editor control window, 0 for current window 
    * @param streamMarkerType     marker type ID for Highlight stream markers
    * @param wordInfo             (output) matching word pattern (if found)
    * @param lookForDisabledWords if {@code true}, check if there is a match 
    *                             for a pattern which is currently disabled 
    * 
    * @return 
    * Returns the index (&gt;=0) of the word pattern found, 
    * otherwise returns an error &lt;0.
    */
   int getWordUnderCursor(int editorctl_wid, 
                          int streamMarkerType,
                          HighlightWordInfo &wordInfo, 
                          bool lookForDisabledWords=false)
   {
      // make sure the current object is an editor control
      if (!editorctl_wid && _isEditorCtl()) {
         editorctl_wid = p_window_id;
      } else if (!editorctl_wid || !editorctl_wid._isEditorCtl()) {
         return VSRC_INVALID_ARGUMENT;
      }
      orig_wid := p_window_id;
      p_window_id = editorctl_wid;

      wordIndex := 0;
      id := cur_identifier(auto start_col);
      if (id == "") {
         id = get_text();
         start_col = p_col;
      }
      _StreamMarkerFindList(auto list, 0, _QROffset() - (p_col-start_col), length(id), start_col, streamMarkerType);
      if (list._length() > 0) {
         foreach (auto item in list) {
            wordIndex = (int)_StreamMarkerGetUserDataInt64(item);
            //say("se.color.HighlightProfile.getWordUnderCursor H"__LINE__": wordIndex="wordIndex);
            if (wordIndex > 0 && wordIndex <= m_words._length()) {
               wordInfo = m_words[wordIndex-1];
               p_window_id = orig_wid;
               //say("se.color.HighlightProfile.getWordUnderCursor H"__LINE__": FOUND STREAM MARKER, wordIndex="(wordIndex-1));
               return wordIndex-1;
            }
         }
      }

      if (lookForDisabledWords) {
         wordIndex = findWordMatchUnderCursor(editorctl_wid, wordInfo);
         //say("se.color.HighlightProfile.getWordUnderCursor H"__LINE__": DISABLED: wordIndex="wordIndex);
         p_window_id = orig_wid;
         return wordIndex;
      }

      p_window_id = orig_wid;
      return STRING_NOT_FOUND_RC;

   }


   /**
    * Reset the common regular expression type so that it will be recalculated.
    */
   void resetRegexTypes()
   {
      m_common_re_type      = "";
      m_have_mixed_slick_re = false;
      m_have_mixed_perl_re  = false;
      m_have_mixed_vim_re   = false;
      m_slick_regex         = "";
      m_perl_regex          = "";
      m_vim_regex           = "";
   }

   /** 
    * @return 
    * Return the common regular expression type shared by all the regular 
    * expression type word patterns in the collection.  If there are mixed 
    * regular expression types, this will be the first one. 
    *  
    * @param editorctl_wid     editor control window (for p_LangId)
    *  
    * @see se.color.HighlightWordInfo#m_wordKind 
    */
   _str getCommonRegexType(int editorctl_wid=0)
   {
      // already calculated common regex type?
      if (length(m_common_re_type) > 0) {
         return m_common_re_type;
      }

      // get the active language mode
      langId := "";
      if (editorctl_wid && editorctl_wid._isEditorCtl()) {
         langId = editorctl_wid.p_LangId;
      } else if (!editorctl_wid && _isEditorCtl()) {
         langId = p_LangId;
      }

      // re-initialize mixed RE
      m_common_re_type      = "";
      m_have_mixed_slick_re = false;
      m_have_mixed_perl_re  = false;
      m_have_mixed_vim_re   = false;

      // loop through words and calculate common regex type and what
      // other regular expressions are mixed in.
      common_re_type := "";
      foreach (auto wordInfo in m_words) {
         // skip deleted and disabled words
         if (wordInfo._isempty()) continue;
         if (!wordInfo.m_enabled) continue;

         // skip words whose language mode does not match
         if (length(wordInfo.m_langId) > 0 && wordInfo.m_langId != langId) {
            continue;
         }

         switch (wordInfo.m_wordKind) {
         case 'r':
         case 'R':
            if (common_re_type == "") {
               common_re_type = 'R';
            } else if (common_re_type != 'R') {
               m_have_mixed_slick_re = true;
            }
            break;
         case 'l':
         case 'L':
            if (common_re_type == "") {
               common_re_type = 'L';
            } else if (common_re_type != 'L') {
               m_have_mixed_perl_re = true;
            }
            break;
         case 'v':
         case 'V':
            if (common_re_type == "") {
               common_re_type = '~';
            } else if (common_re_type != '~') {
               m_have_mixed_vim_re = true;
            }
            break;
         }
      }

      // if there are no regular expressions in the list, 
      // default to Perl regex syntax
      if (common_re_type == "") {
         common_re_type = 'L';
      }

      // set the common regex type and return
      m_common_re_type = common_re_type;
      return common_re_type;
   }

   /** 
    * @return 
    * Return a cummulative regular expression for all the word patterns that 
    * can use SlickEdit regular expressions. 
    *  
    * @param editorctl_wid         editor control window (for p_LangId)
    * @param defaultCaseSensitive  default to case-sensitive search?
    */
   _str getSlickRegex(int editorctl_wid=0, bool defaultCaseSensitive=false)
   {
      // already calculated regex?
      if (length(m_slick_regex) > 0) {
         return m_slick_regex;
      }

      // get the active language mode
      langId := "";
      if (editorctl_wid && editorctl_wid._isEditorCtl()) {
         langId = editorctl_wid.p_LangId;
      } else if (!editorctl_wid && _isEditorCtl()) {
         editorctl_wid = p_window_id;
         langId = p_LangId;
      }

      slick_search_string := "";
      if (m_have_mixed_slick_re || m_common_re_type == 'R') {
         foreach (auto i => auto wordInfo in m_words) {
            // skip deleted and disabled words
            if (wordInfo._isempty()) continue;
            if (!wordInfo.m_enabled) continue;

            // skip everything except Slick regex
            if (m_common_re_type != 'R') {
               switch (wordInfo.m_wordKind) {
               case 'w':
               case 'W':
               case 's':
               case 'S':
               case 'l':
               case 'L':
               case 'v':
               case 'V':
                  continue;
               }
            }

            // skip words whose language mode does not match
            if (length(wordInfo.m_langId) > 0 && wordInfo.m_langId != langId) {
               continue;
            }

            // figure out the case sensitivity option
            case_sensitive := defaultCaseSensitive;
            switch (wordInfo.m_caseOption) {
            case 'e':
            case 'E':
               case_sensitive = true;
               break;
            case 'i':
            case 'I':
               case_sensitive = false;
               break;
            case 'a':
            case 'A':
               if (editorctl_wid && editorctl_wid._isEditorCtl()) {
                  case_sensitive = p_LangCaseSensitive;
               }
               break;
            }

            // convert to a regular expression
            word_re := "";
            switch (wordInfo.m_wordKind) {
            case 'w':
            case 'W':
               if (case_sensitive) {
                  word_re = '(#<hi'i'>\o<\oc(' :+ _escape_re_chars(wordInfo.m_wordPattern, 'R') :+ ')\o>)';
               } else {
                  word_re = '(#<hi'i'>\o<\oi(' :+ _escape_re_chars(wordInfo.m_wordPattern, 'R') :+ ')\o>)';
               }
               break;
            case 's':
            case 'S':
               if (case_sensitive) {
                  word_re = '(#<hi'i'>\oc(' :+ _escape_re_chars(wordInfo.m_wordPattern, 'R') :+ '))';
               } else {
                  word_re = '(#<hi'i'>\oi(' :+ _escape_re_chars(wordInfo.m_wordPattern, 'R') :+ '))';
               }
               break;
            case 'r':
            case 'R':
               if (case_sensitive) {
                  word_re = '(#<hi'i'>\oc(' :+ wordInfo.m_wordPattern :+ '))';
               } else {
                  word_re = '(#<hi'i'>\oi(' :+ wordInfo.m_wordPattern :+ '))';
               }
               break;
            default:
               // should never happen
               continue;
            }

            _maybe_append(slick_search_string, '|');
            slick_search_string :+= word_re;
         }
      }

      m_slick_regex = slick_search_string;
      return slick_search_string;
   }

   /** 
    * @return 
    * Return a cummulative regular expression for all the word patterns that 
    * can use Perl regular expressions. 
    *  
    * @param editorctl_wid         editor control window (for p_LangId)
    * @param defaultCaseSensitive  default to case-sensitive search?
    */
   _str getPerlRegex(int editorctl_wid=0, bool defaultCaseSensitive=false)
   {
      // already calculated regex?
      if (length(m_perl_regex) > 0) {
         return m_perl_regex;
      }

      // get the active language mode
      langId := "";
      if (editorctl_wid && editorctl_wid._isEditorCtl()) {
         langId = editorctl_wid.p_LangId;
      } else if (!editorctl_wid && _isEditorCtl()) {
         editorctl_wid = p_window_id;
         langId = p_LangId;
      }

      perl_search_string := "";
      if (m_have_mixed_perl_re || m_common_re_type == 'L') {
         foreach (auto i => auto wordInfo in m_words) {
            // skip deleted and disabled words
            if (wordInfo._isempty()) continue;
            if (!wordInfo.m_enabled) continue;

            // skip everything except Perl regex
            if (m_common_re_type != 'L') {
               switch (wordInfo.m_wordKind) {
               case 'w':
               case 'W':
               case 's':
               case 'S':
               case 'r':
               case 'R':
               case 'v':
               case 'V':
                  continue;
               }
            }

            // skip words whose language mode does not match
            if (length(wordInfo.m_langId) > 0 && wordInfo.m_langId != langId) {
               continue;
            }

            // figure out the case sensitivity option
            case_sensitive := defaultCaseSensitive;
            switch (wordInfo.m_caseOption) {
            case 'e':
            case 'E':
               case_sensitive = true;
               break;
            case 'i':
            case 'I':
               case_sensitive = false;
               break;
            case 'a':
            case 'A':
               if (editorctl_wid && editorctl_wid._isEditorCtl()) {
                  case_sensitive = p_LangCaseSensitive;
               }
               break;
            }

            // convert to a regular expression
            word_re := "";
            switch (wordInfo.m_wordKind) {
            case 'w':
            case 'W':
               if (case_sensitive) {
                  word_re = '(?<hi'i'>\o<\oc(?:' :+ _escape_re_chars(wordInfo.m_wordPattern, 'L') :+ ')\o>)';
               } else {
                  word_re = '(?<hi'i'>\o<\oi(?:' :+ _escape_re_chars(wordInfo.m_wordPattern, 'L') :+ ')\o>)';
               }
               break;
            case 's':
            case 'S':
               if (case_sensitive) {
                  word_re = '(?<hi'i'>\oc(?:' :+ _escape_re_chars(wordInfo.m_wordPattern, 'L') :+ '))';
               } else {
                  word_re = '(?<hi'i'>\oi(?:' :+ _escape_re_chars(wordInfo.m_wordPattern, 'L') :+ '))';
               }
               break;
            case 'l':
            case 'L':
               if (case_sensitive) {
                  word_re = '(?<hi'i'>\oc(?:' :+ wordInfo.m_wordPattern :+ '))';
               } else {
                  word_re = '(?<hi'i'>\oi(?:' :+ wordInfo.m_wordPattern :+ '))';
               }
               break;
            default:
               // should never happen
               continue;
            }

            _maybe_append(perl_search_string, '|');
            perl_search_string :+= word_re;
         }
      }

      m_perl_regex = perl_search_string;
      return perl_search_string;
   }

   /** 
    * @return 
    * Return a cummulative regular expression for all the word patterns that 
    * can use Vim regular expressions. 
    *  
    * @param editorctl_wid         editor control window (for p_LangId)
    * @param defaultCaseSensitive  default to case-sensitive search?
    */
   _str getVimRegex(int editorctl_wid=0, bool defaultCaseSensitive=false)
   {
      // already calculated regex?
      if (length(m_vim_regex) > 0) {
         return m_vim_regex;
      }

      // get the active language mode
      langId := "";
      if (editorctl_wid && editorctl_wid._isEditorCtl()) {
         langId = editorctl_wid.p_LangId;
      } else if (!editorctl_wid && _isEditorCtl()) {
         editorctl_wid = p_window_id;
         langId = p_LangId;
      }

      vim_search_string := "";
      if (m_have_mixed_vim_re || m_common_re_type == '~') {
         foreach (auto i => auto wordInfo in m_words) {
            // skip deleted and disabled words
            if (wordInfo._isempty()) continue;
            if (!wordInfo.m_enabled) continue;

            // skip everything except Vim regex
            if (m_common_re_type != '~') {
               switch (wordInfo.m_wordKind) {
               case 'w':
               case 'W':
               case 's':
               case 'S':
               case 'r':
               case 'R':
               case 'l':
               case 'L':
                  continue;
               }
            }

            // skip words whose language mode does not match
            if (length(wordInfo.m_langId) > 0 && wordInfo.m_langId != langId) {
               continue;
            }

            // figure out the case sensitivity option
            case_sensitive := defaultCaseSensitive;
            switch (wordInfo.m_caseOption) {
            case 'e':
            case 'E':
               case_sensitive = true;
               break;
            case 'i':
            case 'I':
               case_sensitive = false;
               break;
            case 'a':
            case 'A':
               if (editorctl_wid && editorctl_wid._isEditorCtl()) {
                  case_sensitive = p_LangCaseSensitive;
               }
               break;
            }

            // convert to a regular expression
            word_re := "";
            switch (wordInfo.m_wordKind) {
            case 'w':
            case 'W':
               if (case_sensitive) {
                  word_re = '\(\?<hi'i'>\>\(\?-i:' :+ _escape_re_chars(wordInfo.m_wordPattern, '~') :+ '\)\>\)';
               } else {
                  word_re = '\(\?<hi'i'>\<\(\?i:' :+ _escape_re_chars(wordInfo.m_wordPattern, '~') :+ '\)\>\)';
               }
               break;
            case 's':
            case 'S':
               if (case_sensitive) {
                  word_re = '\(\?<hi'i'>\(\?-i:' :+ _escape_re_chars(wordInfo.m_wordPattern, '~') :+ '\)\)';
               } else {
                  word_re = '\(\?<hi'i'>\(\?i:' :+ _escape_re_chars(wordInfo.m_wordPattern, '~') :+ '\)\)';
               }
               break;
            case 'v':
            case 'V':
               if (case_sensitive) {
                  word_re = '\(\?<hi'i'>\(\?-i:' :+ wordInfo.m_wordPattern :+ '\)\)';
               } else {
                  word_re = '\(\?<hi'i'>\(\?i:' :+ wordInfo.m_wordPattern :+ '\)\)';
               }
               break;
            default:
               // should never happen
               continue;
            }

            _maybe_append(vim_search_string, '\|');
            vim_search_string :+= word_re;
         }
      }

      m_vim_regex = vim_search_string;
      return vim_search_string;
   }

   /**
    * Calculate all the regular expression information. 
    *  
    * @param force   force it to be recalculated, otherwise can use previous values 
    */
   void calculateRegexTypes(bool force=false, int editorctl_wid=0, bool defaultCaseSensitive=false)
   {
      if (force) {
         resetRegexTypes();
      }
      getCommonRegexType();
      getSlickRegex(editorctl_wid, defaultCaseSensitive);
      getPerlRegex(editorctl_wid, defaultCaseSensitive);
      getVimRegex(editorctl_wid, defaultCaseSensitive);
   }

   /**
    * @return 
    * Return {@code true} if this profile has no word patterns.
    */
   bool isEmpty() 
   {
      return (m_words._length() <= 0);
   }
   
   /**
    * @return 
    * Return the number of word patterns in this profile. 
    */
   int getNumWordPatterns() 
   {
      return m_words._length();
   }

   /**
    * Get the next available word index in the table.
    */
   int getNextWordIndex() 
   {
      foreach (auto i => auto wordInfo in m_words) {
         if (wordInfo._isempty()) {
            return i;
         }
      }
      return m_words._length();
   }

   /** 
    * @return 
    * Returns {@code true} if the given index a valid index into the array of words, 
    * Returns {@code false} otherwise.
    *  
    * @param wordIndex    index to check if in range [ 0 .. m_words._length()-1 ] 
    */
   bool isValidWordIndex(int wordIndex)
   {
      return (wordIndex >= 0 && wordIndex < m_words._length() && !m_words[wordIndex]._isempty());
   }

   /**
    * @return 
    * Return the word pattern at the given index. 
    * Return {@code null} if the word index is invalid. 
    */
   HighlightWordInfo getWordPattern(int wordIndex)
   {
      if (wordIndex >= 0 && wordIndex < m_words._length()) {
         return m_words[wordIndex];
      }
      return null;
   }

   /**
    * @return 
    * Return a pointer to the word pattern at the given index. 
    * Return {@code null} if the word index is invalid. 
    */
   HighlightWordInfo *getWordPatternPointer(int wordIndex)
   {
      if (wordIndex >= 0 && wordIndex < m_words._length()) {
         return &m_words[wordIndex];
      }
      return null;
   }

   /**
    * Replace the word pattern at the given index with a new word pattern. 
    * Will not replace an invalid word index, except for the case
    * {@code wordIndex == m_words._length()} where we are merely extending the array. 
    *  
    * @param wordIndex    index to check if in range [ 0 .. m_words._length() ] 
    * @param wordInfo     new word pattern 
    */
   void replaceWordPattern(int wordIndex, HighlightWordInfo &wordInfo)
   {
      if (wordIndex >= 0 && wordIndex <= m_words._length()) {
         m_words[wordIndex] = wordInfo;
         m_generation++;
         resetRegexTypes();
      }
   }

   /**
    * Delete the word pattern at the given index with a new word pattern. 
    *  
    * @param wordIndex    index to in range [ 0 .. m_words._length()-1 ] 
    * @param reallyDelete really delete this item form the array, 
    *                     otherwise the item is just set to null. 
    */
   void deleteWordPattern(int wordIndex, bool reallyDelete=false)
   {
      if (wordIndex >= 0 && wordIndex < m_words._length()) {
         if (reallyDelete || wordIndex == m_words._length()-1) {
            m_words._deleteel(wordIndex);
         } else {
            m_words[wordIndex] = null;
         }
         m_generation++;
         resetRegexTypes();
      }
   }

   /**
    * Replace the entire array of word patterns.
    */
   void setWordPatternArray(HighlightWordInfo (&words)[])
   {
      m_words = words;
      resetRegexTypes();
   }


   /**
    * Load the given Highlight tool window profile information. 
    *  
    * @param profileName     profile to load, loads default profile if not given 
    * @param optionLevel     optionLevel=0 specifies the user level settings. 
    *                        There may be project and workspace levels in the future.
    *  
    * @return 
    * Returns {@literal 0} on success, error {@literal &lt;0} on error. 
    */
   int loadProfile(_str profileName, int optionLevel=0)
   {
      if (length(profileName) <= 0) {
         profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
      }

      resetRegexTypes();
      m_profileName = profileName;
      m_words._makeempty();
      if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
         return 0;
      }

      handle := _plugin_get_profile(VSCFGPACKAGE_HIGHLIGHT_PROFILES, profileName, optionLevel);
      if (handle < 0) {
         return handle;
      }

      // the top level node ID
      profile_node := _xmlcfg_set_path(handle,"/profile");

      // parse out the words for this profile
      property_node := _xmlcfg_get_first_child(handle, profile_node, VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
      while (property_node >= 0) {

         if (_xmlcfg_get_name(handle,property_node) != VSXMLCFG_PROPERTY) {
            property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
            continue;
         }

         key := _xmlcfg_get_attribute(handle,property_node,VSXMLCFG_PROPERTY_NAME);
         if (!isinteger(key)) {
            property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
            continue;
         }

         HighlightWordInfo wordInfo;
         wordInfo.m_colorIndex = (int)key;

         wordInfo.m_wordPattern = _xmlcfg_get_attribute(handle, property_node, HIGHLIGHT_PROFILE_STRING_NAME);
         if (wordInfo.m_wordPattern == "") {
            property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
            continue;
         }

         wordInfo.m_enabled = true;
         wordInfo.m_wordKind = 'S';
         wordInfo.m_caseOption = 'I';
         wordInfo.m_langId = _xmlcfg_get_attribute(handle, property_node, HIGHLIGHT_PROFILE_LANG_NAME);

         options := _xmlcfg_get_attribute(handle, property_node, HIGHLIGHT_PROFILE_OPTIONS_NAME);
         while (options != "") {
            switch (upcase(_first_char(options))) {
            case '+':
               wordInfo.m_enabled = true;
               break;
            case '-':
               wordInfo.m_enabled = false;
               break;
            case 'I':
            case 'E':
            case 'A':
               wordInfo.m_caseOption = _first_char(options);
               break;
            default:
               wordInfo.m_wordKind = _first_char(options);
               break;
            }
            options = substr(options,2);
         }

         // add it to the array
         m_words :+= wordInfo;

         // next please
         property_node=_xmlcfg_get_next_sibling(handle,property_node,VSXMLCFG_NODE_ELEMENT_START|VSXMLCFG_NODE_ELEMENT_START_END);
      }

      // that's all folks
      _xmlcfg_close(handle);
      return 0;
   }

   /**
    * Save the given Highlight tool window profile information. 
    *  
    * @param profileName     profile name to save as, uses current profile if not given 
    *  
    * @return 
    * Returns {@literal 0} on success, error {@literal &lt;0} on error. 
    */
   int saveProfile(_str profileName="")
   {
      if (length(profileName) <= 0) {
         profileName = m_profileName;
      }
      if (length(profileName) <= 0) {
         profileName = HIGHLIGHT_DEFAULT_PROFILE_NAME;
      }
      if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
         return 0;
      }

      if (m_generation > 0 || !g_HighlightProfileGenerations._indexin(profileName)) {
         g_HighlightProfileGenerations:[profileName] = m_generation;
      }

      handle := _xmlcfg_create_profile(auto profile_node,
                                       VSCFGPACKAGE_HIGHLIGHT_PROFILES, 
                                       profileName, 
                                       VSCFGPROFILE_HIGHLIGHT_VERSION);
      if (handle < 0) {
         return handle;
      }
      _xmlcfg_set_name(handle, profile_node, VSCFGPACKAGE_HIGHLIGHT_PROFILES);

      foreach (auto wordInfo in m_words) {
         if (wordInfo._isempty()) continue;
         property_node := _xmlcfg_add_property(handle, profile_node, wordInfo.m_colorIndex);
         options := (wordInfo.m_enabled? '+' : '-') :+ wordInfo.m_wordKind :+ wordInfo.m_caseOption;
         _xmlcfg_set_attribute(handle, property_node, HIGHLIGHT_PROFILE_STRING_NAME, wordInfo.m_wordPattern);
         _xmlcfg_set_attribute(handle, property_node, HIGHLIGHT_PROFILE_OPTIONS_NAME, options);
         if (wordInfo.m_langId != null && wordInfo.m_langId != "") {
            _xmlcfg_set_attribute(handle, property_node, HIGHLIGHT_PROFILE_LANG_NAME, wordInfo.m_langId);
         }
      }

      _plugin_set_profile(handle);
      return _xmlcfg_close(handle);
   }


   /**
    * Delete the Highlight profile with the given name. 
    *  
    * @param profileName  name of profile to delete 
    */
   static void deleteProfile(_str profileName)
   {
      if (profileName == null || profileName=="" || profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
         return;
      }
      if (profileName == HIGHLIGHT_DEFAULT_PROFILE_NAME) {
         HighlightProfile defaultProfile;
         defaultProfile.saveProfile(profileName);
         return;
      }
      _plugin_delete_profile(VSCFGPACKAGE_HIGHLIGHT_PROFILES, profileName);
   }

   /**
    * Load all available profile names into a sorted array.
    */
   static void listProfiles(_str (&profileNames)[]) 
   {
      profileNames._makeempty();
      _plugin_list_profiles(VSCFGPACKAGE_HIGHLIGHT_PROFILES, profileNames);
      profileNames._sort('i');
   }

   /**
    * @return 
    * Return {@code true} if there is a builtin profile with the given name. 
    *  
    * @param profileName    profile name to look for 
    */
   static bool hasBuiltinProfile(_str profileName) {
      if (profileName == HIGHLIGHT_DEFAULT_PROFILE_NAME) return true;
      if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) return true;
      return _plugin_has_builtin_profile(VSCFGPACKAGE_HIGHLIGHT_PROFILES, profileName);
   }

   /**
    * @return 
    * Return {@code true} if there is a builtin or user-defeind profile with the given name. 
    *  
    * @param profileName    profile name to look for 
    */
   static bool hasProfile(_str profileName) {
      if (profileName == HIGHLIGHT_DEFAULT_PROFILE_NAME) return true;
      if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) return true;
      return _plugin_has_profile(VSCFGPACKAGE_HIGHLIGHT_PROFILES, profileName);
   }

   /**
    * Add all available profile naems to a combo box (or list box).
    */
   static void addProfilesToList(int combo_wid)
   {
      _str allProfileNames[];
      _plugin_list_profiles(VSCFGPACKAGE_HIGHLIGHT_PROFILES, allProfileNames);
      allProfileNames._sort('i');

      // load the profile names from the configuration settings, 
      // always have a "Default" profile name first
      combo_wid._lbclear();
      combo_wid._lbadd_item(HIGHLIGHT_DISABLE_PROFILE_NAME, 60, _pic_lbvs);
      combo_wid._lbadd_item(HIGHLIGHT_DEFAULT_PROFILE_NAME, 60, _pic_lbvs);
      foreach (auto profileName in allProfileNames) {
         if (profileName == "") continue;
         if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) continue;
         if (profileName == HIGHLIGHT_DEFAULT_PROFILE_NAME) continue;
         if (hasBuiltinProfile(profileName)) {
            combo_wid._lbadd_item(profileName,60,_pic_lbvs);
         } else {
            combo_wid._lbadd_item(profileName,60,_pic_lbuser);
         }
      }
   }





};


namespace default;


definit()
{
   // forces marks to recalculate
   se.color.g_HighlightProfileGenerations = null;
}
