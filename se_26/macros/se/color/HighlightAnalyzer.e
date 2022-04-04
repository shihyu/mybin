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
#require "se/color/SeekPositionRanges.e"
#require "se/color/HighlightProfile.e"
#import "se/color/ColorIdAllocator.e"
#import "se/color/HighlightOptions.e"
#import "se/color/HighlightTextChangeListener.e"
#import "se/ui/TextChange.e"
#import "se/ui/toolwindow.e"
#import "diff.e"
#import "files.e"
#import "stdcmds.e"
#import "stdprocs.e"
#endregion


/**
 * ID for th highlight stream marker type.
 */
int gHighlightStreamMarkerType = -1;

/**
 * The highlight analyzer needs the text change listener to determine what 
 * lines need to be refreshed. 
 *  
 * @note 
 * This functionality is currently disabled. 
 */
static se.color.HighlightTextChangeListener gHighlightTextListener = null;


/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;

/**
 * Key used in buffer info hash table for string an instance of the analyzer 
 * object for each buffer. 
 */
static const HIGHLIGHT_BUFFER_INFO_KEY = "HighlightAnalyzer";

/**
 * Since the Highlight tool window works with seek positions rather than 
 * line numbers, we use this value to generously estimate the number of bytes 
 * per line in order to calculate how far back to go to color off-page lines. 
 */
static const HIGHLIGHT_TW_LINE_LENGTH = 200;

/**
 * The text change listener was an attempt to make word highlighting slightly 
 * faster by only recalculating highlights for lines of code that were modified 
 * or newly inserted.  It did not seem like the overhead was worth it, the full 
 * visible page can be recalculated so fast, this optimization only adds 
 * complexity, so it is disabled. 
 */
static const HIGHLIGHT_TW_USE_TEXT_CHANGE_LISTENER = false;


/**
 * This class manages highlighting word pattern matches in a single editor 
 * control for the Highlight tool window.  It is typically attached to the 
 * editor control buffer user data hash table.
 */
class HighlightAnalyzer {

   /**
    * Highglight tool window profile information. 
    * A set of word patterns to highlight. 
    */
   HighlightProfile m_profileInfo;

   /**
    * Color profile name for editor control.
    */
   protected _str m_colorSchemeName;

   /**
    * Current file name for the buffer being highlighted.
    */
   protected _str m_fileName;

   /**
    * Current langauge mode for the buffer being highlighted.
    */
   protected _str m_langId;

   /**
    * Last modify counter for the buffer being highlighted. 
    * Need to recolor if this changes. 
    */
   protected long m_lastModified;

   /**
    * Data structure for keeping track of what lines we have colored so far.
    */
   protected SeekPositionRanges m_coloredLines = null;

   /**
    * When we have colored as much as we should color, set this {@code true} 
    * to indicate that there is no more work to do.  Saves us the work of 
    * looking for a hole in {@link m_coloredLines}. 
    */
   protected bool m_finished = false;

   /**
    * Text change listener object for this buffer. 
    *  
    * @note 
    * This is not currently used. 
    */
   typeless *m_pListener = null;


   /**
    * Default constructor
    */
   HighlightAnalyzer(int editorctl_wid=0, HighlightProfile profileInfo=null) 
   {
      m_profileInfo = profileInfo;
      if (editorctl_wid && editorctl_wid._isEditorCtl()) {
         m_colorSchemeName = editorctl_wid.p_WindowColorProfile;
         m_fileName = editorctl_wid.p_buf_name;
         m_langId = editorctl_wid.p_LangId;
         m_lastModified = editorctl_wid.p_LastModified;
      } else {
         m_colorSchemeName = "";
         m_fileName = "";
         m_langId = "";
         m_lastModified = -1;
      }
   }

   /**
    * Destructor
    */
   ~HighlightAnalyzer()
   {
      m_profileInfo = null;
      m_fileName = null;
      m_langId = null;
      m_coloredLines = null;
      m_pListener = null;
   }

   /**
    * Initialize this highlight analyzer object. 
    *  
    * @param profileName    Highlight tool window profile name 
    * @param pProfileInfo   (optional) pointer to profile info object to copy in 
    */
   void initAnalyzer(_str profileName, HighlightProfile *pProfileInfo=null)
   {
      if (pProfileInfo != null) {
         m_profileInfo = *pProfileInfo;
         m_profileInfo.calculateRegexTypes();
      } else {
         HighlightProfile emptyProfile(profileName);
         m_profileInfo = emptyProfile;
         m_profileInfo.calculateRegexTypes();
      }

      m_fileName        = p_buf_name;
      m_langId          = p_LangId;
      m_lastModified    = 0;
      m_colorSchemeName = p_WindowColorProfile;

      SeekPositionRanges emptySet;
      m_coloredLines = emptySet;
      m_finished     = false;
      m_pListener    = null;
   }

   /**
    * Clear all markers for the given editor control and reset this
    * highlight analyzer object. 
    *  
    * @param editorctl_wid   editor control to clear markers for. 
    */
   void resetAnalyzer(int editorctl_wid=0)
   {
      if (editorctl_wid) {
         clearHighlightMarkers(editorctl_wid);
      }

      m_fileName        = p_buf_name;
      m_langId          = p_LangId;
      m_lastModified    = 0;
      m_colorSchemeName = p_WindowColorProfile;

      SeekPositionRanges emptySet;
      m_coloredLines = emptySet;
      m_finished     = false;
      m_pListener    = null;
   }


   /**
    * Initializer the highlight stream marker type.
    */
   static void initHighlightMarkerType(int options)
   {
      //say("HighlightAnalyzer.initHighlightMarkerType: IN, options="_dec2hex(options));
      draw_flags := 0;
      if (options & HIGHLIGHT_TW_DRAW_BOX_TEXT) {
         draw_flags |= VSMARKERTYPEFLAG_DRAW_BOX;
      }
      if (options & HIGHLIGHT_TW_DRAW_SCROLL_MARKERS) {
         draw_flags |= VSMARKERTYPEFLAG_DRAW_SCROLL_BAR_MARKER;
      }

      font_flags := 0;
      if (options & HIGHLIGHT_TW_USE_REVERSE_COLORS ) {
         font_flags = VSMARKERTYPEFLAG_REVERSE_COLOR;
      } else if (options & HIGHLIGHT_TW_USE_HIGHLIGHT_COLOR) {
         font_flags = 0;
      } else if (options & HIGHLIGHT_TW_USE_BOLD_TEXT ) {
         font_flags = VSMARKERTYPEFLAG_FONT_BOLD;
      } else if (options & HIGHLIGHT_TW_USE_UNDERLINE_TEXT ) {
         font_flags = VSMARKERTYPEFLAG_FONT_UNDERLINE;
      } else if (options & HIGHLIGHT_TW_USE_STRIKETHRU_TEXT) {
         font_flags = VSMARKERTYPEFLAG_FONT_STRIKETHRU;
      } else {
         font_flags = 0;
      }


      if (gHighlightStreamMarkerType <= 0) {
         gHighlightStreamMarkerType = _MarkerTypeAlloc();
         _MarkerTypeSetFlags(gHighlightStreamMarkerType, VSMARKERTYPEFLAG_AUTO_REMOVE|draw_flags|font_flags);
         _MarkerTypeSetPriority(gHighlightStreamMarkerType, VSMARKER_TYPE_PRIORITY_HIGHLIGHT);
      } else {
         MARKER_FLAGS_MASK := ( VSMARKERTYPEFLAG_DRAW_BOX               |
                                VSMARKERTYPEFLAG_DRAW_SCROLL_BAR_MARKER |
                                VSMARKERTYPEFLAG_REVERSE_COLOR          |
                                VSMARKERTYPEFLAG_FONT_BOLD              |
                                VSMARKERTYPEFLAG_FONT_ITALIC            |
                                VSMARKERTYPEFLAG_FONT_UNDERLINE         |
                                VSMARKERTYPEFLAG_FONT_STRIKETHRU        );

         // may need to reset box drawing flag and/or font flags
         have_flags := (_MarkerTypeGetFlags(gHighlightStreamMarkerType) & MARKER_FLAGS_MASK);
         if (have_flags != (draw_flags|font_flags)) {
            _MarkerTypeSetFlags(gHighlightStreamMarkerType, VSMARKERTYPEFLAG_AUTO_REMOVE|draw_flags|font_flags);
         }
      }
   }


   /**
    * Clear highlight markers for the given editor control. 
    * If no editor control is given, clear all highlight markers. 
    * 
    * @param editorctl_wid     editor control window
    */
   static void clearHighlightMarkers(int editorctl_wid=0)
   {
      if (gHighlightStreamMarkerType >= 0) {
         if (editorctl_wid && editorctl_wid._isEditorCtl()) {
            _StreamMarkerRemoveType(editorctl_wid, gHighlightStreamMarkerType);
         } else {
            _StreamMarkerRemoveAllType(gHighlightStreamMarkerType);
         }
      }
   }

   /**
    * Clear highlight markers for the given seek position range in the given 
    * editor control window. 
    * 
    * @param editorctl_wid     editor control window
    * @param startOffset       start of range to clear (inclusive)
    * @param endOffset         end of range to clear (inclusive)
    * 
    * @return 
    * Return {@code true} if markers were cleared, {@code false} otherwise. 
    */
   static bool clearHighlightMarkersForRange(int editorctl_wid, long startOffset, long endOffset)
   {
      if (gHighlightStreamMarkerType >= 0) {
         if (editorctl_wid && editorctl_wid._isEditorCtl()) {
            _StreamMarkerFindList(auto list, editorctl_wid, startOffset, (endOffset-startOffset+1), HIGHLIGHT_TW_LINE_LENGTH, gHighlightStreamMarkerType);
            foreach (auto markerId in list) {
               _StreamMarkerRemove(markerId);
            }
            return true;
         }
      }
      return false;
   }

   /**
    * Clear highlight markers with the given word index.   This is used when 
    * a word pattern is disabled or removed from the highlighting profile. 
    * 
    * @param editorctl_wid     editor control window
    * @param wordIndex         highlight word pattern index in highlight profile
    * 
    * @return
    * Return {@code true} if markers were cleared, {@code false} otherwise. 
    */
   static bool clearHighlightMarkersWithIndex(int editorctl_wid, int wordIndex)
   {
      if (gHighlightStreamMarkerType >= 0) {
         if (editorctl_wid && editorctl_wid._isEditorCtl()) {
            _StreamMarkerRemoveUserDataInt64(editorctl_wid, gHighlightStreamMarkerType, wordIndex+1);
         } else {
            _StreamMarkerRemoveAllUserDataInt64(gHighlightStreamMarkerType, wordIndex+1);
         }
      }
      return false;
   }

   /**
    * Set a highlight marker for the given word pattern at the given location. 
    * The current object is expected to be an editor control. 
    * 
    * @param wordInfo         highlight word pattern information
    * @param wordIndex        index of word pattern in highlight profile
    * @param colorSchemeName  window color profileInfo name
    * @param offset           seek position within file
    * @param len              length of item to highlight
    */
   static void setHighlightMarker(HighlightWordInfo &wordInfo, int wordIndex, 
                                  _str colorSchemeName, 
                                  long offset, int len,
                                  bool drawBox)
   {
      //say("HighlightAnalyzer.setHighlightMarker H"__LINE__": stream marker type="gHighlightStreamMarkerType);
      marker_flags := 0;
      cfg_color := wordInfo.getHighlightMarkerColor(colorSchemeName, marker_flags);
      markerIndex := _StreamMarkerAdd(p_window_id, offset, len, true, 0, gHighlightStreamMarkerType, null);
      _ScrollMarkupAddOffset(p_window_id, offset, gHighlightStreamMarkerType, len);
      //_StreamMarkerSetStyleFlags(markerIndex, marker_flags);
      _StreamMarkerSetTextColor(markerIndex, cfg_color);
      if (drawBox) {
         typeless fg=0;
         parse _default_color(CFG_WINDOW_TEXT, -1, -1, -1, 0, colorSchemeName) with fg . . ;
         _StreamMarkerSetStyleColor(markerIndex, fg);
      }
      //say("HighlightAnalyzer.setHighlightMarker H"__LINE__": wordIndex="wordIndex);
      //_dump_var(wordInfo, "HighlightAnalyzer.setHighlightMarker H"__LINE__": wordInfo");
      _StreamMarkerSetUserDataInt64(markerIndex, wordIndex+1);
   }


   /**
    * Update the word highlighting for the current buffer.
    * 
    * @param editorctl_wid    editor control window
    * @param profileName      highlight profile name
    * @param pWords           (optional) pointer ot list of word patterns from 
    *                         Highlight tool window form. 
    * @param doMinimalWork    do minimal work for the current form
    * @param okToRefresh      ok to refresh the editor control after
    * 
    * @return 
    * Returns {@literal 0} if the window has been completed. 
    * Returns {@literal 1} if we timed out or otherwise did not finish.
    */
   int updateWordHighlighting(int editorctl_wid,
                              HighlightProfile &profileInfo,
                              int options=def_highlight_tw_options,
                              bool doMinimalWork=false, 
                              bool okToRefresh=false)
   {
      // disabled highlighting case, or no words to highlight?
      profileName := profileInfo.getProfileName();
      if (profileName == HIGHLIGHT_DISABLE_PROFILE_NAME) {
         if (!m_finished) {
            clearHighlightMarkers(editorctl_wid);
            m_finished = true;
            //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": DISABLED");
         }
         return 0;
      }

      // make sure they gave us a valid editor control window
      if (!editorctl_wid || !editorctl_wid._isEditorCtl(/*allowHiddenWindow*/false)) {
         return 0;
      }

      // switch to the given editor window
      orig_wid := p_window_id;
      p_window_id = editorctl_wid;

      // has the address of the listener changed (usually the result of a reload)?
      if (HIGHLIGHT_TW_USE_TEXT_CHANGE_LISTENER && gHighlightTextListener != null && gHighlightTextListener.m_ready) {
         if (m_pListener != &gHighlightTextListener) {
            //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": RESTART");
            if (m_pListener != null) {
               se.ui.TextChangeNotify.removeListener(m_pListener);
               m_pListener = null;
            }
            se.ui.TextChangeNotify.addListener(&gHighlightTextListener);
            m_pListener = &gHighlightTextListener;
            initAnalyzer(profileName, &profileInfo);
         }
      }

      // has the highlighting profile information changed?
      if (m_profileInfo == null ||
          m_profileInfo.getProfileName() != profileName ||
          m_profileInfo.getGeneration() != profileInfo.getGeneration() ||
          m_profileInfo.getNumWordPatterns() != profileInfo.getNumWordPatterns()) {
         //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": INIT PROFILER");
         clearHighlightMarkers(p_window_id);
         initAnalyzer(profileName, &profileInfo);
      }

      // calculate the default case-sensitive option
      case_sensitive := (options & HIGHLIGHT_TW_CASE_SENSITIVE) != 0;
      if (options & HIGHLIGHT_TW_CASE_LANGUAGE) {
         case_sensitive = p_LangCaseSensitive;
      }
      //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": case_sensitive="case_sensitive" file="p_buf_name" doc="p_DocumentName" mode="p_mode_name);

      // if the word array is empty, or we need to update it
      if (m_profileInfo.getNumWordPatterns() <= 0) {

         // need to update the list of word patterns
         clearHighlightMarkers(p_window_id);
         m_profileInfo.loadProfile(profileName);
         initAnalyzer(profileName, &m_profileInfo);

         // double-check that we have word patterns now
         if (m_profileInfo.getNumWordPatterns() <= 0) {
            m_finished = true;
            p_window_id = orig_wid;
            //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": NO PATTERNS");
            return 0;
         }

         // new array of words, need to recalculate regular expressions
         // determine the common regular expression type, and other regular expressions
         m_profileInfo.calculateRegexTypes(force:true, p_window_id, case_sensitive);
      }

      // has the buffer been modified since last update?
      if (HIGHLIGHT_TW_USE_TEXT_CHANGE_LISTENER && m_lastModified != p_LastModified && 
          gHighlightTextListener != null && gHighlightTextListener.m_ready) {
         m_lastModified = p_LastModified;
      }

      // has the window language mode, buffer name, or color scheme name changed?
      if (m_lastModified    != p_LastModified ||
          m_langId          != p_LangId       ||
          m_fileName        != p_buf_name     ||
          m_colorSchemeName != p_WindowColorProfile) {
         initAnalyzer(profileName, &m_profileInfo);
         clearHighlightMarkers(p_window_id);
         m_lastModified = p_LastModified;
      }

      // no more work to do?
      if (m_finished) {
         p_window_id = orig_wid;
         //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": FINISHED");
         return 0;
      }

      // determine what lines we need to color
      p_window_id = editorctl_wid;
      save_pos(auto p);
      startLineOffset := 0L;
      endLineOffset   := 0L;
      doRefresh       := false; 
      doMinimap       := false; 
      doOffScreen     := false; 
      if (!m_coloredLines.determineLineRangeToColor(editorctl_wid,
                                                    startLineOffset, endLineOffset, 
                                                    doRefresh, 
                                                    doMinimap, 
                                                    doOffScreen, 
                                                    def_highlight_tw_chunk_size * HIGHLIGHT_TW_LINE_LENGTH, 
                                                    def_highlight_tw_off_page_lines * HIGHLIGHT_TW_LINE_LENGTH)) {
         //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": NO HOLES TO FILL");

         // no holes to fill in the current range, 
         // but we are only done when we've done everything.
         if (m_coloredLines.containsRange(0, p_RBufSize)) {
            m_finished = true;
         }

         // do nothing, no coloring information to update at this time
         p_window_id = orig_wid;
         return 0;
      }

      //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": startOffset="startLineOffset" endOffset="endLineOffset);
      //_dump_var(m_profileInfo, "HighlightAnalyzer.updateWordHighlighting H"__LINE__": m_profileInfo");

      // if offscreen is true, then we have colored all the visible lines in the editor
      if (doOffScreen) {
         // this is the least that I can do for you
         if (doMinimalWork) {
            restore_pos(p);
            p_window_id = orig_wid;
            return 0;
         }
         // just double the delay if we are still working on the minimap
         if (doMinimap) {
            if (_idle_time_elapsed() < 2*def_highlight_tw_delay) {
               restore_pos(p);
               p_window_id = orig_wid;
               return 0;
            }
         } else {
            // wait longer before doing off-screen lines, and do not do off-screen
            // lines if we are waiting on a keypress already
            if (_idle_time_elapsed() < 4*def_highlight_tw_delay) {
               restore_pos(p);
               p_window_id = orig_wid;
               return 0;
            }
         }
      }

      // initialize all the highlighting marker types
      initHighlightMarkerType(options);
      drawBox := (options & HIGHLIGHT_TW_DRAW_BOX_TEXT) != 0;

      // save current editor position, search settings, and selection info
      save_pos(p);
      save_search(auto s1, auto s2, auto s3, auto s4, auto s5);
      mark_status := save_selection(auto old_mark);

      //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": SLICK="m_profileInfo.getSlickRegex());
      //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": PERL="m_profileInfo.getPerlRegex());
      //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": VIM="m_profileInfo.getVimRegex());

      _deselect();
      _GoToROffset(endLineOffset);
      _end_line();
      _select_char();
      _GoToROffset(startLineOffset);
      _begin_line();
      _select_char();

      slick_regex := m_profileInfo.getSlickRegex(p_window_id, case_sensitive);
      if (length(slick_regex) > 0) {
         _begin_select();
         status := search(slick_regex, '@MHR<');
         while (!status) {
            //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": p_line="p_line" match_group_names()="match_group_names()" match_length()="match_length());
            parse match_group_names() with '<hi' auto index '>';
            pWordInfo := m_profileInfo.getWordPatternPointer((int)index);
            if (pWordInfo) {
               setHighlightMarker(*pWordInfo, (int)index, m_colorSchemeName, _QROffset(), match_length(), drawBox);
            }
            _GoToROffset(_QROffset()+match_length()-1);
            status = repeat_search('@MHR<');
         }
      }

      perl_regex := m_profileInfo.getPerlRegex(p_window_id, case_sensitive);
      if (length(perl_regex) > 0) {
         _begin_select();
         status := search(perl_regex, '@MHL<');
         while (!status) {
            //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": p_line="p_line" match_group_names()="match_group_names()" match_length()="match_length());
            parse match_group_names() with '<hi' auto index '>';
            pWordInfo := m_profileInfo.getWordPatternPointer((int)index);
            if (pWordInfo) {
               setHighlightMarker(*pWordInfo, (int)index, m_colorSchemeName, _QROffset(), match_length(), drawBox);
            }
            _GoToROffset(_QROffset()+match_length()-1);
            status = repeat_search('@MHL<');
         }
      }

      vim_regex := m_profileInfo.getVimRegex(p_window_id, case_sensitive);
      if (length(vim_regex) > 0) {
         _begin_select();
         status := search(vim_regex, '@MH~<');
         while (!status) {
            //say("HighlightAnalyzer.updateWordHighlighting H"__LINE__": p_line="p_line" match_group_names()="match_group_names()" match_length()="match_length());
            parse match_group_names() with '<hi' auto index '>';
            pWordInfo := m_profileInfo.getWordPatternPointer((int)index);
            if (pWordInfo) {
               setHighlightMarker(*pWordInfo, (int)index, m_colorSchemeName, _QROffset(), match_length(), drawBox);
            }
            _GoToROffset(_QROffset()+match_length()-1);
            status = repeat_search('@MH~<');
         }
      }

      // keep track of our highs and our lows
      m_coloredLines.addRange(startLineOffset, endLineOffset);

      // and restore where we were
      restore_selection(old_mark);
      restore_search(s1, s2, s3, s4, s5);
      restore_pos(p);

      // do a refresh, if necessary
      if (doRefresh && okToRefresh) {
         refresh();
      }

      p_window_id = orig_wid;
      return 0;
   }

};

namespace default;

definit()
{
   // reset the text change listener object
   gHighlightTextListener.m_ready = true;

   // do not need to reset settings if just reloading, only for initialization
   if ( arg(1) != 'L' ) {
      gHighlightStreamMarkerType = -1;
   }
}

void _on_unload_module_highlight_analyzer(_str module="")
{
   if (!file_eq("HighlightAanalyzer", _strip_filename(module, 'pe'))) {
      return;
   }
   //say("_on_unload_module_highlight_analyzer H"__LINE__": filename="module);
   se.color.HighlightAnalyzer.clearHighlightMarkers();
   if (se.color.HIGHLIGHT_TW_USE_TEXT_CHANGE_LISTENER && gHighlightTextListener != null && gHighlightTextListener.m_ready) {
      gHighlightTextListener.m_ready = true;
      se.ui.TextChangeNotify.removeListener(&gHighlightTextListener);
   }

   se.color.HighlightAnalyzer.clearHighlightMarkers();
}

void _on_load_module_highlight_analyzer(_str module, int option=0)
{
   if (!file_eq("HighlightAanalyzer", _strip_filename(module, 'pe'))) {
      return;
   }
   //say("_on_load_module_highlight_analyzer H"__LINE__": module="module);
   se.color.HighlightAnalyzer.clearHighlightMarkers();
   if (se.color.HIGHLIGHT_TW_USE_TEXT_CHANGE_LISTENER && gHighlightTextListener != null && gHighlightTextListener.m_ready) {
      gHighlightTextListener.m_ready = false;
      se.ui.TextChangeNotify.removeListener(&gHighlightTextListener);
   }

   se.color.HighlightAnalyzer.clearHighlightMarkers();
}

void _cbquit_highlight_analyzer(int buffid, _str name, _str docname= "", int flags = 0)
{
   // check if we have a highlighter object for this buffer, and remove it
   // since we are quitting the buffer.
   if (_isEditorCtl()) {
      se.color.HighlightAnalyzer *pHighlighter = _GetBufferInfoHtPtr(se.color.HIGHLIGHT_BUFFER_INFO_KEY);
      if (pHighlighter != null) {
         if (se.color.HIGHLIGHT_TW_USE_TEXT_CHANGE_LISTENER && pHighlighter->m_pListener != null) {
            se.ui.TextChangeNotify.removeListener(pHighlighter->m_pListener);
            pHighlighter->m_pListener = null;
         }
         _SetBufferInfoHt(se.color.HIGHLIGHT_BUFFER_INFO_KEY, null);
         se.color.HighlightAnalyzer.clearHighlightMarkers(p_window_id);
      }
   }
}

