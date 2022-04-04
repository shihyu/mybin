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
#require "sc/util/NumberRanges.e"

/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;

/** 
 * This class is used to represent an set of ranges of line numbers. 
 * compactly and effeciently as possible without creating a bitset, 
 * since the numbers could be arbitrary in size.  This is used for 
 * keeping track of which lines have already been colored by the 
 * symbol coloring engine. 
 */
class LineNumberRanges : sc.util.NumberRanges {

   /** 
    * Construct an initially empty set.
    */
   LineNumberRanges() {
   }

   /**
    * Determine the first and last visible lines in the given editor window. 
    *  
    * @param editorctl_wid editor control to calculate based on 
    * @param startLine     set to the first line (inclusive) to color 
    * @param endLine       set to the last line (inclusive) to color 
    */
   static void determineFirstAndLastVisibleLines(int editorctl_wid, 
                                                 int &startLine, int &endLine)
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
      startLine = p_RLine;
      if (startLine > 1) --startLine;
      p_cursor_y=p_client_height-1;
      endLine = p_RLine+1;
      p_cursor_y = orig_cursor_y;
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
    * @param startLine        set to the first line (inclusive) to color 
    * @param endLine          set to the last line (inclusive) to color
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
                                  int &startLine, 
                                  int &endLine, 
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
      determineFirstAndLastVisibleLines(editorctl_wid, startLine, endLine);

      // check if the range is within the minimal number of lines worth coloring
      if (endLine - startLine  < chunk_size) {
         endLine = startLine + chunk_size;
      }

      // Check if we have colored all the on-screen lines
      if (containsRange(startLine, endLine)) {
         doOffScreen = true;
      }

      // Check if we have a minimap
      minLine := startLine;
      maxLine :=   endLine;
      if (doOffScreen && editorctl_wid.p_minimap_wid && editorctl_wid.p_show_minimap) {
         if (_iswindow_valid(editorctl_wid.p_minimap_wid) && editorctl_wid.p_minimap_wid.p_visible) {
            if (_default_option(VSOPTION_MINIMAP_SHOW_SYMBOL_COLORING)) {
               // recursively determine lines to color based on minimap.
               determineFirstAndLastVisibleLines(editorctl_wid.p_minimap_wid, auto minimapStartLine, auto minimapEndLine);
               if (minimapStartLine < startLine) minLine = minimapStartLine;
               if (minimapEndLine   > endLine  ) maxLine = minimapEndLine;
               doMinimap = true;

               // color the lines shown above the current page in the minimap.
               // this is a big gulp, but we'll double-buffer as much as we can
               if (minLine < startLine-1 && !containsRange(minLine, startLine-1)) {
                  endLine   = startLine-1;
                  startLine = minLine;
                  return true;
               }

               // color the lines shown below the current page in the minimap.
               // this is a big gulp, but we'll double-buffer as much as we can
               if (maxLine > endLine+1 && !containsRange(endLine+1, maxLine)) {
                  startLine = endLine+1;
                  endLine   = maxLine;
                  return true;
               }
            }
         }
      }

      // check if we have colored as much as we can color
      minLine = startLine - off_page_lines;
      maxLine = endLine + off_page_lines;
      if (minLine <= 0) minLine=1;
      if (containsRange(minLine, maxLine)) {
         return false;
      }

      // find the origin line (pivot point)
      origLine := editorctl_wid.p_RLine;
      if (origLine < minLine) origLine = minLine;
      if (origLine > maxLine) origLine = maxLine;

      // calculate what lines to color
      //say("determineLineRangeToColor: startLine="startLine" endLine="endLine);
      if (containsRange(startLine, endLine)) {

         if (findNearestHole(origLine, minLine, maxLine, 
                             auto nearestHoleStart=0, auto nearestHoleEnd=0,
                             chunk_size)) {
            startLine = nearestHoleStart;
            endLine   = nearestHoleEnd;
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


