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
#include "slick.sh"
#include "math.sh"
#require "sc/util/NumberRanges.e"

/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;

/** 
 * This class is used to represent an set of ranges of seek positions.
 * compactly and effeciently as possible without creating a bitset, 
 * since the numbers could be arbitrary in size.  This is used for 
 * keeping track of which sections of a file have already been colored 
 * by the pattern highlighting engine. 
 */
class SeekPositionRanges : sc.util.NumberRanges {

   /** 
    * Construct an initially empty set.
    */
   SeekPositionRanges() {
   }


   /**
    * Determine the first and last visible lines the given editor window.
    * 
    * @param editorctl_wid    editor control to calculate based on
    * @param startLineOffset  set to the start seek position of the first line (inclusive)
    * @param endLineOffset    set to the end seek position of the last line (inclusive)
    */
   static void determineFirstAndLastVisibleLines(int editorctl_wid, 
                                                 long &startLineOffset, 
                                                 long &endLineOffset)
   {
      orig_wid := p_window_id;
      p_window_id = editorctl_wid;

      // find the first and last visible lines on the screen
      save_pos(auto p);
      orig_cursor_y := p_cursor_y;

      // adjust screen position if we are scrolled
      if (p_scroll_left_edge >= 0) {
         _str line_pos,down_count,SoftWrapLineOffset;
         parse _scroll_page() with line_pos down_count SoftWrapLineOffset;
         goto_point(line_pos);
         down((int)down_count);
         set_scroll_pos(p_scroll_left_edge,0,(int)SoftWrapLineOffset);
      }

      p_cursor_y=0;
      _begin_line();
      startLineOffset = max(0,_QROffset());
      p_cursor_y=p_client_height-1;
      _end_line();
      endLineOffset = _QROffset()+length(p_newline);
      restore_pos(p);

      p_window_id = orig_wid;
   }


   /**
    * Calculate what range of lines in the current file needs to be colored. 
    * Generally, the lines colored are only the visible lines on the screen, 
    * however, if a user pages up, we can potentially extend the symbol 
    * coloring region instead of starting over from scratch every time. 
    * <p> 
    * The current object must be an editor control. 
    *  
    * @param editorctl_wid    editor control to calculate based on 
    * @param startLine        set to the start seek position of the first line (inclusive) to color 
    * @param endLine          set to the end seek position of the last line (inclusive) to color
    * @param doRefresh        set to true if we expect to need to do a 
    *                         screen refresh after recalculating the symbol
    *                         coloring information.
    * @param doMinimap        Set to true if the line range is off-screen, 
    *                         but visible in the minimap control.
    * @param doOffScreen      Set to true if the line range is off-screen entirely. 
    * @param chunk_size       Number of lines to color per pass when calculating
    *                         for off-page lines.
    * @param off_page_lines   Number of lines to color above and below
    *                         the current page when
    *  
    * @return 
    * Returns 'true' if we need to do work between 'startLine' and 'endLine', 
    *         'false' if everything is up to date. 
    */
   bool determineLineRangeToColor(int editorctl_wid,
                                  long &startSeekPos, 
                                  long &endSeekPos, 
                                  bool &doRefresh,
                                  bool &doMinimap,
                                  bool &doOffScreen,
                                  int chunk_size = 20,
                                  int off_page_lines = 100)
   {
      // optimistic, hopefully we don't have to reset or refresh anything
      doRefresh = false;
      doOffScreen = false;

      // find the first and last visible lines on the screen
      determineFirstAndLastVisibleLines(editorctl_wid, startSeekPos, endSeekPos);

      // check if the range is within the minimal number of lines worth coloring
      if (endSeekPos - startSeekPos  < chunk_size) {
         endSeekPos = startSeekPos + chunk_size;
      }

      // Check if we have colored all the on-screen lines
      if (containsRange(startSeekPos, endSeekPos)) {
         doOffScreen = true;
      }

      // Check if we have a minimap
      minSeekPos := startSeekPos;
      maxSeekPos :=   endSeekPos;
      if (doOffScreen && editorctl_wid.p_minimap_wid && editorctl_wid.p_show_minimap) {
         if (_iswindow_valid(editorctl_wid.p_minimap_wid) && editorctl_wid.p_minimap_wid.p_visible) {
            if (_default_option(VSOPTION_MINIMAP_SHOW_SYMBOL_COLORING)) {
               // recursively determine lines to color based on minimap.
               determineFirstAndLastVisibleLines(editorctl_wid.p_minimap_wid, auto minimapStartSeekPos, auto minimapEndSeekPos);
               if (minimapStartSeekPos < startSeekPos) minSeekPos = minimapStartSeekPos;
               if (minimapEndSeekPos   > endSeekPos  ) maxSeekPos = minimapEndSeekPos;
               doMinimap = true;

               // color the lines shown above the current page in the minimap.
               // this is a big gulp, but we'll double-buffer as much as we can
               if (minSeekPos < startSeekPos-1 && !containsRange(minSeekPos, startSeekPos-1)) {
                  endSeekPos   = startSeekPos-1;
                  startSeekPos = minSeekPos;
                  return true;
               }

               // color the lines shown below the current page in the minimap.
               // this is a big gulp, but we'll double-buffer as much as we can
               if (maxSeekPos > endSeekPos+1 && !containsRange(endSeekPos+1, maxSeekPos)) {
                  startSeekPos = endSeekPos+1;
                  endSeekPos   = maxSeekPos;
                  return true;
               }
            }
         }
      }

      // check if we have colored as much as we can color
      minSeekPos = startSeekPos - off_page_lines;
      maxSeekPos = endSeekPos + off_page_lines;
      if (minSeekPos <= 0) minSeekPos=1;
      if (containsRange(minSeekPos, maxSeekPos)) {
         return false;
      }

      // find the origin line (pivot point)
      origSeekPos := _QROffset();
      if (origSeekPos < minSeekPos) origSeekPos = minSeekPos;
      if (origSeekPos > maxSeekPos) origSeekPos = maxSeekPos;

      // calculate what lines to color
      //say("determineLineRangeToColor: startSeekPos="startSeekPos" endSeekPos="endSeekPos);
      if (containsRange(startSeekPos, endSeekPos)) {

         if (findNearestHole(origSeekPos, minSeekPos, maxSeekPos, 
                             auto nearestHoleStart=0, auto nearestHoleEnd=0,
                             chunk_size)) {
            startSeekPos = nearestHoleStart;
            endSeekPos   = nearestHoleEnd;
            return true;
         }

         return false;

      } else {
         // just color the visible lines on the screen
         doRefresh=true;
      }

      // start and end are set, and we need to do some symbol coloring
      return true;
   }

};


