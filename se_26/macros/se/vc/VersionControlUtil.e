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
#region Imports
#include "slick.sh"
#include "svc.sh"
#endregion Imports

/**
 * The "se.vc" namespace contains interfaces and classes that 
 * are intrinisic to supporting 3rd party verrsion control 
 * systems. 
 */
namespace se.vc;


class VersionControlUtil {
   protected _str m_captionTable[];

   public STRARRAY getCaptions() {
      return m_captionTable;
   }
   public void setCaptionForCommand(SVCCommands command,_str menuItem) {
      m_captionTable[command] = menuItem;
   }
   public _str getCaptionForCommand(SVCCommands command,bool withHotkey=true,bool mixedCaseCaption=true) {
      caption := m_captionTable[command];
      if ( caption==null ) {
         caption = "";
      }
      if ( !withHotkey  ) {
         caption = stranslate(caption,'','&');
      }
      if ( !mixedCaseCaption ) {
         caption = lowcase(caption);
      }
      return caption;
   }


   /** 
    * Checks to see if a hotkey is already used. 
    *  
    * Implementations should return true if one of the menu 
    * captions for a command uses this letter as a hotkey. This 
    * allows generic code in svc.e to calculate hotkey items for 
    * things like "Compare with" and  "Setup"
    * 
    * @param hotkeyLetter Letter to check
    * 
    * @return bool true if <B>hotkeyLetter</B> is used as a hotkey
    */
   public bool hotkeyUsed(_str hotkeyLetter,bool onMenu=true) {
      foreach ( auto curCap in m_captionTable ) {
         if ( curCap==null ) continue;
         if ( pos('&'hotkeyLetter,curCap,1,'i') ) {
            return true;
         }
      }
      return false;
   }
};
