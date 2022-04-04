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
#include "cvs.sh"
#import "stdprocs.e"
#import "cvs.e"
#endregion Imports

/**
 * The "se.vc" namespace contains interfaces and classes that 
 * are intrinisic to supporting 3rd party verrsion control 
 * systems. 
 */
namespace se.vc;

class VCInfo {
   public _str getExePath(_str vcsName) {
      switch ( lowcase(vcsName) ) {
      case "cvs":
         cvsFilename := _CVSGetExePath();
         if ( !_file_eq(cvsFilename,absolute(cvsFilename)) ) {
            cvsFilename = path_search(cvsFilename);
         }
         return cvsFilename;
      default:
         return "";
      }
   }
};
