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

/**
 * The "sc.util" namespace contains interfaces and classes that 
 * serve as utilies/tools. 
 */
namespace sc.util;

/** 
 * This class is used to represent an set of ranges of numbers,
 * compactly and effeciently as possible without creating a bitset, 
 * since the numbers could be arbitrary in size. 
 * <p>
 * This can is used for keeping track of which sections of a file have 
 * already been processed by an engine that works in chunks.
 */
class NumberRanges {

   /**
    * Parallel sorted arrays of <code>startNum ... endNum</code> ranges.
    */
   private long m_startNums[];
   private long m_endNums[];

   /** 
    * Construct an initially empty set.
    */
   NumberRanges() {
      //say("NumberRanges H"__LINE__": INIT");
      m_startNums = null;
      m_endNums = null;
   }

   /** 
    * Find the segment of contiguous numbers surrounding the given integer.   
    * 
    * @param n          integer to look for
    * @param spanIndex  (output) set to index of span containing {@code n}. 
    *                   if no span contains {@code n}, return the index of
    *                   the span that will need to be created to contain {@code n}.
    * 
    * @return 
    * Returns {@literal true} if {@code n} is in the set, {@literal false} otherwise.
    */
   protected bool findSpanContaining(long n, int *spanIndex=null) {

      //say("findSpanContaining H"__LINE__": n="n);
      // we won't find anything in an empty list, we know that
      if (m_startNums == null) {
         if (spanIndex) *spanIndex = 0;
         //say("findSpanContaining H"__LINE__": NOPE");
         return false;
      }

      // Search for the specified item in the array.
      // A binary search is used.
      firstIndex := 0;
      lastIndex  := m_startNums._length()-1;
      while ( firstIndex <= lastIndex ) {
         middleIndex := ( firstIndex + lastIndex ) >> 1;
         middleStart := m_startNums[ middleIndex ];
         middleEnd   := m_endNums[ middleIndex ];
         if ( n >= middleStart && n <= middleEnd ) {
            if (spanIndex) {
               *spanIndex = middleIndex;
            }
            //say("findSpanContaining H"__LINE__": FOUND IT, span="middleIndex);
            return true;
         }
         if ( n < middleStart ) {
            lastIndex = middleIndex - 1;
         } else {
            firstIndex = middleIndex + 1;
         }
      }

      // did not find a matching range, make sure we are aligned
      // correctly and set the span index where we expect
      if (firstIndex > 0) firstIndex--;
      while (firstIndex < m_startNums._length() && m_startNums[firstIndex] < n) {
         firstIndex++;
      }
      if (spanIndex) {
         *spanIndex = firstIndex;
      }
      //say("findSpanContaining H"__LINE__": NOPE");
      return false;
   }

   /**
    * Check if the given segment can be joined with the segment before or after it.
    * 
    * @param index    index of segment
    */
   private void maybeJoinSegment(int index) {
      // try to join the segment after this one
      if (index+1 < m_startNums._length() && m_endNums[index] >= m_startNums[index+1]) {
         //say("maybeJoinSegment H"__LINE__": join m_endNums["index"]="m_endNums[index]" m_startNums["index+1"]="m_startNums[index+1]);
         if (m_endNums[index] < m_endNums[index+1]) {
            m_endNums[index] = m_endNums[index+1];
         }
         if (m_startNums[index] > m_startNums[index+1]) {
            m_startNums[index] = m_startNums[index+1];
         }
         m_startNums._deleteel(index+1);
         m_endNums._deleteel(index+1);
      }
      // try to join the segment before this one
      if (index > 0 && m_endNums[index-1] >= m_startNums[index]) {
         //say("maybeJoinSegment H"__LINE__": join m_endNums["index-1"]="m_endNums[index-1]" m_startNums["index"]="m_startNums[index]);
         if (m_endNums[index-1] < m_endNums[index]) {
            m_endNums[index-1] = m_endNums[index];
         }
         if (m_startNums[index-1] > m_startNums[index]) {
            m_startNums[index-1] = m_startNums[index];
         }
         m_startNums._deleteel(index);
         m_endNums._deleteel(index);
      }
   }

   /**
    * Add a single number to the set.
    * 
    * @param n    Integer to add to the set. 
    */
   void addNumber(long n) {
      //say("addNumber H"__LINE__": n="n);
      spanIndex := 0;
      if (findSpanContaining(n, &spanIndex)) {
         return;
      }
      nearIndex := 0;
      if (findSpanContaining(n-1, &nearIndex)) {
         if (m_endNums[nearIndex] < n) {
            m_endNums[nearIndex] = n;
         }
         maybeJoinSegment(nearIndex);
         //_dump_var(m_startNums, "addNumber H"__LINE__": m_startNums");
         //_dump_var(m_endNums, "addNumber H"__LINE__": m_endNums");
         return;
      }
      if (findSpanContaining(n+1, &nearIndex)) {
         if (m_startNums[nearIndex] > n) {
            m_startNums[nearIndex] = n;
         }
         maybeJoinSegment(nearIndex);
         //_dump_var(m_startNums, "addNumber H"__LINE__": m_startNums");
         //_dump_var(m_endNums, "addNumber H"__LINE__": m_endNums");
         return;
      }
      m_startNums._insertel(n, spanIndex);
      m_endNums._insertel(n, spanIndex);
      //_dump_var(m_startNums, "addNumber H"__LINE__": m_startNums");
      //_dump_var(m_endNums, "addNumber H"__LINE__": m_endNums");
   }

   /**
    * Add a range of numbers <code>[startNum ...endNum]</code> to the set.
    * 
    * @param startNum   start number (inclusive)
    * @param endNum     end number (inclusive)
    */
   void addRange(long startNum, long endNum) {
      //say("addRange H"__LINE__": startNum="startNum" endNum="endNum);
      startSpanIndex := endSpanIndex := 0;
      if (endNum < startNum) {
         //say("addRange H"__LINE__": FLIP IT");
         tempNum := startNum;
         startNum = endNum;
         endNum = tempNum;
      }
      if (findSpanContaining(startNum, &startSpanIndex) &&
          findSpanContaining(endNum,  &endSpanIndex)) {
         if (startSpanIndex == endSpanIndex) {
            //_dump_var(m_startNums, "addNumber H"__LINE__": m_startNums");
            //_dump_var(m_endNums, "addNumber H"__LINE__": m_endNums");
            return;
         }
         if (m_endNums[endSpanIndex] > m_endNums[startSpanIndex]) {
            m_endNums[startSpanIndex] = m_endNums[endSpanIndex];
         }
         m_startNums._deleteel(startSpanIndex+1, endSpanIndex-startSpanIndex);
         m_endNums._deleteel(startSpanIndex+1, endSpanIndex-startSpanIndex);
         //_dump_var(m_startNums, "addNumber H"__LINE__": m_startNums");
         //_dump_var(m_endNums, "addNumber H"__LINE__": m_endNums");
      } else {
         addNumber(startNum);
         addNumber(endNum);
         addRange(startNum, endNum);
         //_dump_var(m_startNums, "addNumber H"__LINE__": m_startNums");
         //_dump_var(m_endNums, "addNumber H"__LINE__": m_endNums");
      }
   }

   /**
    * Clear the number range for the span possibly overlapping the given 
    * number range <code>[startNum ...endNum]</code>. 
    *  
    * This function will narrow either {@code startNum} or {@code endNum}, 
    * clearing the range from this span only partially clears the entire range. 
    * 
    * @param spanIndex  index of range to modify 
    * @param startNum   start number (inclusive)
    * @param endNum     end number (inclusive)
    * 
    * @return 
    * Returns {@literal true} if clearing this span clears the entire range, 
    * otherwiise returns {@literal false} to indicate more work needs to be done.
    */
   private bool clearRangeFromSpan(int spanIndex, long &startNum, long &endNum) {

      spanStartNum := m_startNums[spanIndex];
      spanEndNum   := m_endNums[spanIndex];
      //say("clearRangeFromSpan H"__LINE__": spanIndex="spanIndex" spanStartNum="spanStartNum" spanEndNum="spanEndNum" startNum="startNum" endNum="endNum);

      // span found covers entire range
      if (spanStartNum <= startNum && spanEndNum >= endNum) {
         // span starts exactly on 'startNum'
         if (spanStartNum == startNum) {
            if (spanEndNum > endNum) {
               m_startNums[spanIndex] = endNum+1;
               m_endNums[spanIndex] = spanEndNum;
            } else {
               m_startNums._deleteel(spanIndex);
               m_endNums._deleteel(spanIndex);
            }
            return true;
         }
         // span ends exactly on 'endNum'
         if (spanEndNum == endNum) {
            if (spanStartNum < startNum) {
               m_startNums[spanIndex] = spanStartNum;
               m_endNums[spanIndex] = startNum-1;
            } else {
               m_startNums._deleteel(spanIndex);
               m_endNums._deleteel(spanIndex);
            }
            return true;
         }
         // span overlaps range in both directions
         if (spanStartNum < startNum && spanEndNum > endNum) {
            m_startNums[spanIndex] = spanStartNum;
            m_endNums[spanIndex] = startNum-1;
            m_startNums._insertel(endNum+1, spanIndex+1);
            m_endNums._insertel(spanEndNum, spanIndex+1);
            return true;
         }
      }

      // span contains 'startNum', but does not go past 'endNum'
      if (spanStartNum < startNum && spanEndNum <= endNum) {
         m_startNums[spanIndex] = spanStartNum;
         m_endNums[spanIndex] = startNum-1;
         startNum = spanEndNum+1;
         return false;
      }

      // span contains 'endNum', but does not start before 'startNum'
      if (spanStartNum >= startNum && spanEndNum > endNum) {
         m_startNums[spanIndex] = endNum+1;
         m_endNums[spanIndex] = spanEndNum;
         endNum = spanStartNum-1;
         return false;
      }

      // no changes made to span
      return false;
   }

   /**
    * Clear the number range between {@code startNum} and {@code endNum}.
    * 
    * @param startNum    start of number range (inclusive) 
    * @param endNum      end of number range (inclusive)
    */
   void clearRange(long startNum, long endNum) {

      // we won't find anything in an empty list, we know that
      if (m_startNums == null) {
         return;
      }

      //say("clearRange H"__LINE__": startNum="startNum" endNum="endNum);
      if (endNum < startNum) {
         tempNum := startNum;
         startNum = endNum;
         endNum = tempNum;
      }

      // look for a span containing the start number
      startSpanIndex := 0;
      if (findSpanContaining(startNum, &startSpanIndex) && clearRangeFromSpan(startSpanIndex, startNum, endNum)) {
         return;
      }

      // skip hole between 'startNum' and next span within range
      if (startSpanIndex > 0) {
         --startSpanIndex;
      }
      while (startSpanIndex < m_startNums._length()) {
         spanStartNum := m_startNums[startSpanIndex];
         spanEndNum   := m_endNums[startSpanIndex];

         // next span starts after range, so nothing to delete
         if (spanStartNum > endNum) {
            return;
         }
         // next span starts after 'startNum', skip over hole
         if (spanStartNum >= startNum) {
            startNum = spanStartNum;
            break;
         }
         // no more ranges?
         ++startSpanIndex;
         if (startSpanIndex >= m_startNums._length()) {
            return;
         }
      }

      // look for a span containing the end number
      endSpanIndex := 0;
      if (findSpanContaining(endNum, &endSpanIndex) && clearRangeFromSpan(endSpanIndex, startNum, endNum)) {
         return;
      }

      // skip hole between 'startNum' and next span within range
      if (endSpanIndex+1 < m_endNums._length()) {
         ++endSpanIndex;
      }
      while (endSpanIndex >= 0) {
         spanStartNum := m_startNums[endSpanIndex];
         spanEndNum   := m_endNums[endSpanIndex];

         // previous span ends before range, so nothing to delete
         if (spanEndNum < startNum) {
            return;
         }
         // previous span ends before 'endNum', skip over hole
         if (spanEndNum <= endNum) {
            endNum = spanEndNum;
            break;
         }
         // no more ranges?
         if (endSpanIndex <= 0) {
            return;
         }
         --endSpanIndex;
      }

      // recusively try again, search range has to be reduced
      clearRange(startNum, endNum);
   }

   /**
    * Clear the given number from the set of number ranges.
    * 
    * @param num        lnumber to remove
    */
   void clearNumber(long num) {
      spanIndex := 0;
      if (findSpanContaining(num, &spanIndex)) {
         clearRangeFromSpan(spanIndex, num, num);
      }
   }

   /**
    * Clear all number ranges.
    */
   void clearSet() {
      //say("clearSet H"__LINE__": RESET");
      m_startNums = null;
      m_endNums = null;
   }

   /**
    * @return 
    * Returns {@literal true} if the set is empty. 
    */
   bool isEmpty() {
      return m_startNums._isempty();
   }

   /**
    * @return 
    * Returns {@literal true} if {@code startNum} is in the set. 
    * 
    * @param startNum     number to look for
    */
   bool containsNumber(long startNum) {
      //say("containsNumber H"__LINE__": startNum="startNum);
      return findSpanContaining(startNum);
   }

   /**
    * @return 
    * Returns {@literal true} if the entire range {@code [startNum ... endNum]} is in the set. 
    * 
    * @param startNum    start of number range (inclusive) 
    * @param endNum      end of number range (inclusive)
    */
   bool containsRange(long startNum, long endNum) {
      //say("containsRange H"__LINE__": startNum="startNum" endNum="endNum);
      if (endNum < startNum) {
         tempNum := startNum;
         startNum = endNum;
         endNum = tempNum;
      }
      spanIndex := 0;
      if (!findSpanContaining(startNum, &spanIndex)) {
         //say("containsRange H"__LINE__": START not found");
         return false;
      }
      if (endNum > m_endNums[spanIndex]) {
         //say("containsRange H"__LINE__": end is beyond span");
         return false;
      }
      //say("containsRange H"__LINE__": GOT IT");
      return true;
   }

   /** 
    * @return
    * If there is a number range containing {@code n}, 
    * set {@code startNum} and {@code endNum} to it's corresponding values 
    * and return {@literal true}.  Otherwise, reutrn {@literal false} and 
    * set both {@code startNum} and {@code endNum} to 0.
    * 
    * @param n          number to look for 
    * @param startNum   (output) start of number range (inclusive) 
    * @param endNum     (output) end of number range (inclusive)
    */
   protected bool getRangeSurrounding(long n, long &startNum, long &endNum) {
      //say("getRangeSurrounding H"__LINE__": n="n);
      spanIndex := 0;
      if (findSpanContaining(n, &spanIndex)) {
         startNum = m_startNums[spanIndex];
         endNum   = m_endNums[spanIndex];
         //say("getRangeSurrounding H"__LINE__": found it, startNum="startNum" endNum="endNum);
         return true;
      }
      startNum = endNum = 0;
      //say("getRangeSurrounding H"__LINE__": NOPE");
      return false;
   }

   /**
    * Find the nearest unspanned hole in the set of number ranges to {@code n}. 
    *  
    * @param n          number to look for 
    * @param minNum     minimum number for range 
    * @param maxNum     maximum number for range
    * @param startNum   (output) start of number range (inclusive) 
    * @param endNum     (output) end of number range (inclusive)
    * @param maxSize    maximum size of hole to find
    * 
    * @return 
    * Return {@literal true} on success, {@literal false} otherwise.
    */
   bool findNearestHole(long n, 
                        long minNum, long maxNum,
                        long &startNum, long &endNum, long maxSize) {

      //say("findNearestHole H"__LINE__": n="n" minNum="minNum" maxNum="maxNum" maxSize="maxSize);
      if (m_startNums._length() == 0) {
         startNum = n-(maxSize intdiv 2);
         endNum   = startNum+maxSize;
         if (startNum < minNum) startNum=minNum;
         if (startNum > maxNum) startNum=maxNum;
         if (endNum > maxNum) endNum=maxNum;
         if (endNum < minNum) endNum=minNum;
         //say("findNearestHole H"__LINE__": EMPTY LIST");
         return true;
      }

      spanIndex := 0;
      if (findSpanContaining(n, &spanIndex)) {
         startNum = m_startNums[spanIndex];
         endNum   = m_endNums[spanIndex];
         if (n - startNum < endNum - n && startNum > minNum) {
            endNum = startNum-1;
            startNum = startNum - maxSize;
            if (spanIndex > 0 && m_endNums[spanIndex-1]+1 > startNum) {
               startNum = m_endNums[spanIndex-1]+1;
            }
            if (startNum < minNum) startNum=minNum;
            if (startNum > maxNum) startNum=maxNum;
            if (endNum > maxNum) endNum=maxNum;
            if (endNum < minNum) endNum=minNum;
            //say("findNearestHole H"__LINE__": RETURNING startNum="startNum" endNum="endNum);
            return true;
         } else if (endNum < maxNum) {
            startNum = endNum+1;
            endNum   = startNum+maxSize;
            if (spanIndex+1 < m_startNums._length() && m_startNums[spanIndex+1]-1 < endNum) {
               endNum = m_startNums[spanIndex+1]-1;
            }
            if (startNum < minNum) startNum=minNum;
            if (startNum > maxNum) startNum=maxNum;
            if (endNum > maxNum) endNum=maxNum;
            if (endNum < minNum) endNum=minNum;
            //say("findNearestHole H"__LINE__": RETURNING startNum="startNum" endNum="endNum);
            return true;
         } else {
            //say("findNearestHole H"__LINE__": NO HOLES?");
            return false;
         }
      }

      if (spanIndex >= m_startNums._length()) {
         spanIndex--;
      }
      if (spanIndex > 0 && m_endNums[spanIndex] > maxNum) {
         spanIndex--;
      }
      startNum = m_endNums[spanIndex]+1;
      endNum   = startNum+maxSize;
      if (spanIndex+1 < m_startNums._length() && m_startNums[spanIndex+1]-1 < endNum) {
         endNum = m_startNums[spanIndex+1]-1;
      }
      if (startNum < minNum) startNum=minNum;
      if (startNum > maxNum) startNum=maxNum;
      if (endNum > maxNum) endNum=maxNum;
      if (endNum < minNum) endNum=minNum;
      //say("findNearestHole H"__LINE__": N NOT COVERED, RETURNING startnum="startNum" endNum="endNum);
      return true;
   }

   /** 
    * @return 
    * Return the smallest number in this set. 
    */
   long getMinimum() {
      if (m_startNums == null || m_startNums._length() <= 0) {
         //say("getMinimum H"__LINE__": EMPTY");
         return 0;
      }
      //say("getMinimum H"__LINE__": min="m_startNums[0]);
      return m_startNums[0];
   }
   /** 
    * @return 
    * Return the largest number in this set.
    */
   long getMaximum() {
      if (m_endNums == null || m_endNums._length() <= 0) {
         //say("getMaximum H"__LINE__": EMPTY");
         return 0;
      }
      //say("getMaximum H"__LINE__": max="m_endNums._lastel());
      return m_endNums[m_endNums._length()-1];
   }

};

