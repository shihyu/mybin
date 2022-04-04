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
#require "se/ui/ITextChangeListener.e"
#import "stdprocs.e"
#endregion

/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;


/**
 * This class is used to track changes in the current buffer as they happen 
 * so that we can flag them immediately as lines that need to be rescanned 
 * for highlighting. 
 *  
 * @note 
 * This feature is disabled because it turned out to be unnecessary. 
 */
class HighlightTextChangeListener : se.ui.ITextChangeListener {
   /**
    * Callback called when text is inserted, modified, or deleted between 
    * {@code startOffset} and {@code endOffset}. 
    * 
    * @param startOffset   start seek position within current buffer 
    * @param endOffset     end seek position within current buffer 
    */
   void onTextChange(long startOffset, long endOffset) {

      //say("HighlightTextChangeListener.onTextChange H"__LINE__": IN");
      if (!_isEditorCtl()) {
         return;
      }

      //say("HighlightTextChangeListener.onTextChange H"__LINE__": p_buf_name="p_buf_name);
#if 0
      // check if we already have an highlighter object for this buffer?
      HighlightTWData *pHighlighter = _GetBufferInfoHtPtr(HIGHLIGHT_BUFFER_INFO_KEY);
      if (pHighlighter == null) {
         return;
      }
      if (!m_ready) {
         return;
      }

      if (pHighlighter) {
         if (endOffset < pHighlighter->lo_seekpos) {
            // modified lines before our colored range, so ignore it
         } else if (startOffset > pHighlighter->hi_seekpos) {
            // modified lines after our colored range, so ignore it
         } else if (startOffset >= pHighlighter->lo_seekpos && endOffset <= pHighlighter->hi_seekpos) {
            // new range is contained in current hi/lo
            if ((startOffset - pHighlighter->lo_seekpos) > (pHighlighter->hi_seekpos - endOffset)) {
               pHighlighter->hi_seekpos = startOffset;
            } else {
               pHighlighter->lo_seekpos = endOffset;
            }
         } else if (startOffset < pHighlighter->lo_seekpos) {
            pHighlighter->lo_seekpos = endOffset;
         } else {
            pHighlighter->hi_seekpos = startOffset;
         }
         //say("HighlightTextChangeListener.onTextChange H"__LINE__": clear range, start="startOffset" end="endOffset);
         pHighlighter->m_coloredLines.clearRange(startOffset, endOffset);
         pHighlighter->finished = false;
         ClearHighlightMarkersForRange(p_window_id, startOffset, endOffset);
      }
#endif
   }

   /**
    * Callback called on update?
    */
   void onTextChangeUpdate() {
      //say("HighlightTextChangeListener.onTextChangeUpdate H"__LINE__": HERE");
   }

   /**
    * This member exists only to be able to differentiate between a uninitialized 
    * instance of this class and an initialized instance. 
    */
   bool m_ready = false;
};

