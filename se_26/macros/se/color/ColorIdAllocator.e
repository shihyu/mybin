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
#endregion


/**
 * The "se.color" namespace contains interfaces and classes that are
 * necessary for managing syntax coloring and other color information 
 * within SlickEdit. 
 */
namespace se.color;

/**
 * Utility class for allocating custom colors. 
 * Will recycle color combinations which have already been alocated. 
 *  
 * This class allocates color ID's, but it never free's any. 
 */
class ColorIdAllocator {
  
   /**
    * Hash table of all color IDs allocated.
    * 
    */
   private static int s_AllocatedColorIds:[];

   /**
    * Reset hash table.
    */
   static void resetAllocatedColors() {
      s_AllocatedColorIds._makeempty();
   }

   /**
    * @return Returns an RGB color used by several Slick-C&reg; functions. 
    * The <i>red</i>, <i>green</i>, and <i>blue</i> parameters are numbers 
    * between 0 and 255.   The return value is ((blue<<16)|(green<<8)|red).
    */ 
   static int rgb(int r, int g, int b)
   {
      return ((b<<16) | (g<<8) | r);
   }

   /**
    * Decompose a RGB color into it's <i>red</i>, <i>green</i>, and <i>blue</i> 
    * color component values between 0 and 255.
    */ 
   static void get_rgb(int rgb, int &r, int &g, int &b)
   {
      r = (rgb & 0xFF);
      rgb = rgb intdiv 256;
      g = (rgb & 0xFF);
      rgb = rgb intdiv 256;
      b = (rgb & 0xFF);
   }

   /**
    * Adjust a background color which may not bee a good match for the 
    * window text background color.  Will make the color darker or lighter 
    * so that it combines well. 
    * 
    * @param bg_rgb    RGB background color of some color constant      
    * @param win_rgb   RBG background color of CFG_WINDOW_TEXT color constant
    * 
    * @return 
    * RGB color of adjusted background color with better constrast.
    */
   static int adjustBackgroundColor(int bg_rgb, int win_rgb) 
   {
      // decompose the colors into red, green, blue
      get_rgb(bg_rgb,  auto r,  auto g,  auto b);
      get_rgb(win_rgb, auto wr, auto wg, auto wb);

      // if the primitive color distance is close enough, just go with it    
      if ((wr-r)*(wr-r) + (wg-g)*(wg-g) + (wb-b)*(wb-b) < 3*96*96) {
         return rgb(r,g,b);
      }

      // have to adjust the color
      if (r+g+b < wr+wg+wb) {
         // dark scheme, go lighter (charcoal)
         r += 96; if (r > 255) r = 255;
         g += 96; if (g > 255) g = 255;
         b += 96; if (b > 255) b = 255;
      } else {
         // light scheme, go darker (gray)
         r -= 96; if (r < 0) r = 0;
         g -= 96; if (g < 0) g = 0;
         b -= 96; if (b < 0) b = 0;
      }

      return rgb(r,g,b);
   }

   /** 
    * @return
    * Look for or possibly allocate a new color ID for the given custom color 
    * combination. 
    * 
    * @param fg               foreground color (RGB)
    * @param bg               background color (RGB)
    * @param fontFlags        font flags (bitset of F_*)
    * @param parentColor      color to inherit attributes from  
    * @param colorSchemeName  (optional) color profile to allocate color in
    * 
    * @return CFGColorConstants 
    */
   static CFGColorConstants getColorId(int fg, int bg, int fontFlags=0, 
                                       CFGColorConstants parentColor=CFG_HILIGHT, 
                                       _str colorSchemeName=def_color_scheme)
   {
      key := (fg' 'bg' 'fontFlags' 'parentColor);
      if (s_AllocatedColorIds._indexin(key)) {
         return (CFGColorConstants)s_AllocatedColorIds:[key];
      }
      return (CFGColorConstants)_AllocColor((int)fg, (int)bg, fontFlags, parentColor, colorSchemeName);
   }

   /** 
    * @return
    * Return the number of custom colors allocated.
    */
   static int numColorsAllocated()
   {
      return s_AllocatedColorIds._length();
   }

};


namespace default;

definit()
{
   // do not need to reset settings if just reloading, only for initialization
   if ( arg(1) != 'L' ) {
      se.color.ColorIdAllocator.resetAllocatedColors();
   }
}

