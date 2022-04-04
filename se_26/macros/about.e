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
#include "license.sh"
#include "minihtml.sh"
#import "fileproject.e"
#import "files.e"
#import "hotfix.e"
#import "html.e"
#import "main.e"
#import "markfilt.e"
#import "os2cmds.e"
#import "pipe.e"
#import "projconv.e"
#import "project.e"
#import "setupext.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "tagform.e"
#import "wkspace.e"
#endregion


static const MIN_PROG_INFO_WIDTH=8000;
static const MIN_PROG_INFO_HEIGHT=7000;


static _str _os_version_name = "";
static _str gX11WindowManager = "";

definit()
{
   _str initArg=arg(1);
   if ( initArg :!= 'L' ) {
      _os_version_name="";
      gX11WindowManager = "";
   }
}


defeventtab _program_info_form;

void _program_info_form.on_resize() {
   // make sure the dialog doesn't get too scrunched
   // if the minimum width has not been set, it will return 0
   if (!_minimum_width()) {
      _set_minimum_size(MIN_PROG_INFO_WIDTH, MIN_PROG_INFO_HEIGHT);
   }
   // resize the width of the tabs and html controls
   ctlsstab1.p_x_extent = p_width;
   minihtml_width := ctlsstab1.p_width - _dx2lx(SM_TWIP,4)- 2*MINIHTML_INDENT_X;
   ctlminihtml_about.p_width      = minihtml_width;
   ctlminihtml_notes.p_width      = minihtml_width;
   ctlminihtml_copyrights.p_width = minihtml_width;
   ctlminihtml_license.p_width    = minihtml_width;
   ctlminihtml_contact.p_width    = minihtml_width;

   if( ctlbob_banner.p_picture!=0 ) {
      // set the width of the picture box to the width of the dialog
      ctl_banner_box.p_width=p_width;
   } else {
      // No picture, so size down to 0x0 to force the html control to the
      // top of the dialog.
      ctlbob_banner.p_width=0;
      ctlbob_banner.p_height=0;
      ctl_banner_box.p_width=0;
      ctl_banner_box.p_height=0;
   }

   // place the buttons and size the tabs/html controls appropriately
   ctlok.p_y=ctlcopy.p_y=p_height-ctlok.p_height-p_active_form._top_height()-p_active_form._bottom_height()-100;
   ctlsstab1.p_height=ctlok.p_y-ctl_banner_box.p_height-100;

   SSTABCONTAINERINFO info;
   ctlsstab1._getTabInfo(0, info);
   minihtml_height := ctlsstab1.p_height - _dy2ly(SM_TWIP,info.by-info.ty+1);
   ctlminihtml_about.p_height      = minihtml_height;
   ctlminihtml_notes.p_height      = minihtml_height;
   ctlminihtml_copyrights.p_height = minihtml_height;
   ctlminihtml_license.p_height    = minihtml_height;
   ctlminihtml_contact.p_height    = minihtml_height;
}

void ctlcopy.lbutton_up()
{
   switch (ctlsstab1.p_ActiveTab) {
   case 0:
      ctlminihtml_about._minihtml_command("copy");
      break;
   case 1:
      ctlminihtml_notes._minihtml_command("copy");
      break;
   case 2:
      ctlminihtml_copyrights._minihtml_command("copy");
      break;
   case 3:
      ctlminihtml_license._minihtml_command("copy");
      break;
   case 4:
      ctlminihtml_contact._minihtml_command("copy");
      break;
   }
}

void ctlminihtml_about.on_change(int reason,_str hrefText)
{
   if (reason==CHANGE_CLICKED_ON_HTML_LINK) {
       // is this a command or function we should run?
       if (substr(hrefText,1,6)=="<<cmd") {
           cmdStr := substr(hrefText,7);
           cmd := "";
           params := "";
           parse cmdStr with cmd params;
           index := find_index(cmd, COMMAND_TYPE|PROC_TYPE);
           if (index && index_callable(index)) {
              // get the active window
              int curWid = _mdi;
              get_window_id(curWid);
              // activate the MDI window
              activate_window(_mdi);
              if (params == "") {
                 call_index(index);
              } else {
                 call_index(params,index);
              }
              // restore the current window
              if (_iswindow_valid(curWid)) {
                 activate_window(curWid);
              }
           }
           return;
       }
   }
}

static _str aboutLicenseInfo()
{
   // locate the license file, on Windows it is installed under 'docs'
   license_name := "";
   if (isEclipsePlugin()) {
      license_name = "license_eclipse.htm";
   } else {
      license_name = "license.htm";
   }
   _str vsroot = _getSlickEditInstallPath();
   license_file :=  vsroot"docs"FILESEP :+ license_name;
   if (!file_exists(license_file)) {
      // Unix case, check in root installation directory
      license_file = vsroot""FILESEP:+ license_name;
   }
   if (!file_exists(license_file)) {
      // this is only needed for running out of the build directory
      license_file = vsroot"tools"FILESEP:+ license_name;
   }

   // get the contents of the license file
   license_text := "";
   _GetFileContents(license_file, license_text);

   return license_text;
}

static _str aboutReleaseNotesInfo()
{
   // Get the contents of the readme and load it into ctlminihtml_notes
   _str vsroot = _getSlickEditInstallPath();
   readme_text := "";
   readme_file := "";
   _maybe_append_filesep(vsroot);
   if (isEclipsePlugin()) {
      readme_file = vsroot"readme-eclipse.html";
   } else {
      readme_file = vsroot"readme.html";
   }
   _GetFileContents(readme_file, readme_text);
   return readme_text;
}

static _str aboutCopyrightInfo()
{
   // Get the contents of the readme and load it into ctlminihtml_copyrights
   _str vsroot = _getSlickEditInstallPath();
   readme_text := "";
   readme_file := "";
   _maybe_append_filesep(vsroot);
   if (isEclipsePlugin()) {
      readme_file = vsroot"copyrights.html";
   } else {
      readme_file = vsroot"copyrights.html";
   }
   _GetFileContents(readme_file, readme_text);
   return readme_text;
}

// @param text            HTML text to display.
// @param caption         (optional). Dialog title bar caption.
// @param bannerPicIndex  (optional). Alternate picture index to use for banner.
//                        @see load_picture
// @param bannerBackColor (optional). Alternate picture background color.
//                        Set this if you are providing your own banner picture,
//                        and you are not centering the picture. The color will
//                        be used to fill the empty space to the right of the
//                        banner created by sizing the dialog to fit the text.
//                        @see _rgb
// @param options         (optional). "C"=center banner picture instead of
//                        right-aligning and filling extra space with background
//                        color. "S"=size the dialog to fit the width of the
//                        banner picture.
void ctlok.on_create(_str text="", _str caption="", int bannerPicIndex=-1, int bannerBackColor=-1, _str options="")
{
/*
IMPORTANT!!!!! This dialog is too difficult to size correctly. The proper way to
write this dialog is similar to the find dialog. The minihtml controls should NOT
be inside the tab control tabs. The tab control should just be a small tab control
displayed below one of the current visible minihtml control. Then you place the
small tab control at y=ctlminihtml.p_y_extent; x=ctlminihtml.p_x,
width=ctlminihtml.p_width;

*/
   if( caption!="" ) {
      p_active_form.p_caption=caption;
   } else {
      p_active_form.p_caption=editor_name('A');
   }

   typeless font_name, font_size, flags, charset;
   parse _default_font(CFG_DIALOG) with font_name","font_size","flags","charset;
   if( !isinteger(charset) ) charset=-1;
   if( !isinteger(font_size) ) font_size=8;

   ctlminihtml_about.p_text=text;

   // RGH - 5/15/2006
   // New banner for Eclipse Plugin
   if (isEclipsePlugin()) {
      bitmapsPath := _getSlickEditInstallPath():+VSE_BITMAPS_DIR:+FILESEP;
      ctlbob_banner.p_picture = _find_or_add_picture(bitmapsPath:+"_eclipse_banner.png");
   } else if (_default_option(VSOPTIONZ_APP_THEME) == "Dark" && bannerPicIndex < 0) {
      ctlbob_banner.p_picture = ctlbob_banner_dark.p_picture;
   }
   // If specified, set the banner picture displayed, otherwise
   // leave as default.
   if( bannerPicIndex!=-1 ) {
      // Since the banner box (ctl_banner_box) is contained by the form,
      // we must make sure that the form is big enough to hold the banner
      // box BEFORE we set the width of the banner box, or else it will
      // get clipped.
      p_active_form.p_width *= 2;
      p_active_form.p_height *= 2;
      // Since the banner picture control (ctlbob_banner) is contained
      // by the banner box (ctl_banner_box), we must make sure that the
      // banner box is big enough to hold the picture BEFORE we set the
      // picture index, or else it will get clipped.
      ctl_banner_box.p_width *= 2;
      ctl_banner_box.p_height *= 2;
      // Set the picture
      ctlbob_banner.p_picture=bannerPicIndex;
      // Setting p_stretch has the side-effect of kicking the picture
      // control into resizing to fit the picture (if p_auto_size=true).
      ctlbob_banner.p_stretch=false;
   }
   if( ctlbob_banner.p_picture==0 ) {
      // No picture, so size down to 0x0 to force the html control to the
      // top of the dialog.
      ctlbob_banner.p_width=0;
      ctlbob_banner.p_height=0;
      ctl_banner_box.p_width=0;
      ctl_banner_box.p_height=0;
   }

   // Adjust banner image geometry to account for frame-width
   fw := _dx2lx(SM_TWIP,ctl_banner_box._frame_width());
   fh := _dy2ly(SM_TWIP,ctl_banner_box._frame_width());
   if( ctlbob_banner.p_x < fw ) {
      ctlbob_banner.p_x += fw - ctlbob_banner.p_x;
   }
   if( ctlbob_banner.p_y < fh ) {
      ctlbob_banner.p_y += fh - ctlbob_banner.p_y;
   }

   // Size the bounding background picture control for the banner to fit
   // the banner image.
   ctl_banner_box.p_width = ctlbob_banner.p_x_extent + fw;
   ctl_banner_box.p_height = ctlbob_banner.p_y_extent +fh;


   // Force form width to initially equal width of bounding banner box
//   p_active_form.p_width=ctl_banner_box.p_width;

   // Set the background color of bounding background picture control
   if( bannerBackColor!=-1 ) {
      ctl_banner_box.p_backcolor=bannerBackColor;
   } else if (_default_option(VSOPTIONZ_APP_THEME) != "Dark") {
      // Set product-specific background color
      if( isEclipsePlugin() ) {
         ctl_banner_box.p_backcolor=0x712d34;
      } else {
         //ctl_banner_box.p_backcolor=0x003BDDA0;
         ctl_banner_box.p_backcolor=0x00FFFFFF;
      }
   }

   // Leave a vertical gap between banner box and mini html box
   //ctlminihtml_about.p_y=ctl_banner_box.p_y_extent+90;

   ctlminihtml_about.p_x=MINIHTML_INDENT_X;
   options=upcase(options);
   if( pos('S',options)!=0 ) {
      // Do not allow the width of the form and html control to be
      // greater than the width of the banner image.
      //
      // Note: The width of the form already matches the width of the
      // banner image, so we only need to adjust the width of the html
      // control.
      int client_width=_dx2lx(SM_TWIP,p_active_form.p_client_width);
      // Note: ctlminihtml_about.p_x*2 = gap on left and right side of control
      ctlminihtml_about.p_width=client_width - ctlminihtml_about.p_x*2;
      ctlsstab1.p_width=ctlminihtml_notes.p_width=ctlminihtml_copyrights.p_width=ctlminihtml_license.p_width=ctlminihtml_contact.p_width;
   } else {
      // Resize dialog (if necessary) to fit the text
      if( ctlminihtml_about.p_width+2*ctlsstab1.p_x < ctl_banner_box.p_width+ctlok.p_width) {
         p_active_form.p_width=ctl_banner_box.p_width+ctlok.p_width;
      } else {
         // Note: ctlminihtml_about.p_x*2 = gap on left and right side of control
         //p_active_form.p_width=ctlminihtml_about.p_x*2 + ctlminihtml_about.p_width + p_active_form._left_width()*2;
         p_active_form.p_width=ctlsstab1.p_x_extent +  p_active_form._left_width()*2;
      }
      // Form width changed, have to recalculate the client width
      int client_width=_dx2lx(SM_TWIP,p_active_form.p_client_width);
      // Increase width of bounding background picture control so everything
      // continues to look nice.
      ctl_banner_box.p_width=client_width;
      if( pos('C',options)!=0 ) {
         // Center banner image
         ctlbob_banner.p_x = (ctl_banner_box.p_width - ctlbob_banner.p_width) intdiv 2;
      }
   }
   // RGH - 5/15/2006
   // Line up the tab control and html controls appropriately
   ctlminihtml_notes.p_x ctlminihtml_copyrights.p_x = ctlminihtml_license.p_x = ctlminihtml_contact.p_x = ctlminihtml_about.p_x;
   ctlsstab1.p_y = ctl_banner_box.p_y_extent;
   ctlminihtml_about.p_y = ctlminihtml_notes.p_y = ctlminihtml_copyrights.p_y = ctlminihtml_license.p_y = ctlminihtml_contact.p_y = 0;

   //ctlcopy.p_y=ctlok.p_y=ctlminihtml_about.p_y_extent+100;
   //ctlminihtml_about.p_backcolor=0x80000022;
   //ctlminihtml_notes.p_backcolor=0x80000022;
   //ctlminihtml_license.p_backcolor=0x80000022;
   ctlminihtml_notes.p_text = aboutReleaseNotesInfo();
   ctlminihtml_copyrights.p_text = aboutCopyrightInfo();
   ctlminihtml_license.p_text = aboutLicenseInfo();
   ctlminihtml_contact.p_text = aboutContactInfo();

   // default start tab is program information,
   // change tabs here to readme or license depending on options
   if( pos('R',options) != 0 ) {
      ctlsstab1.p_ActiveTab=1;
   } else if( pos('L',options) != 0 ) {
      ctlsstab1.p_ActiveTab=2;
   }
}

static _str _get_eurl()
{
   temp := "h";temp=temp"t";temp=temp"t";temp=temp"p";temp=temp":";
   temp :+= "/";temp=temp"/";temp=temp"w";temp=temp"w";temp=temp"w";
   temp :+= ".";temp=temp"s";temp=temp"l";temp=temp"i";temp=temp"c";
   temp :+= "k";temp=temp"e";temp=temp"d";temp=temp"i";temp=temp"t";
   temp :+= ".";temp=temp"c";temp=temp"o";temp=temp"m";temp=temp"/";
   temp :+= "e";temp=temp"a";temp=temp"s";temp=temp"t";temp=temp"e";
   temp :+= "r";temp=temp"e";temp=temp"g";temp=temp"g";temp=temp".";
   temp :+= "h";temp=temp"t";temp=temp"m";temp=temp"l";
   return(temp);
}

void ctlbob_banner.lbutton_up()
{
   int x,y;
   mou_get_xy(x,y);
   _map_xy(0,p_window_id,x,y);
   if (x>=133 && x<=140 &&
       y>=7 && y<=10) {
      goto_url(_get_eurl());
   }
}

_str MBRound(long ksize)
{
   typeless before, after;
   parse ksize/(1024) with before"." +0 after;

   if (after>=.5) {
      before+=1;
   }
   return(before"MB");
}
static void appendDiskInfo(_str &diskinfo,_str path,_str DirCaption,_str UsageCaption="")
{
   if( diskinfo!="" ) {
      diskinfo :+= "\n";
   }
   if( diskinfo!="" ) {
      diskinfo :+= "\n";
   }
   diskinfo :+= "<b>"DirCaption"</b>:  "path;
   diskinfo :+= getDiskInfo(path);

}
_str getDiskInfo(_str path)
{
   diskinfo := "";
   status := 0;
   if (_isWindows()) {
      FSInfo := "";
      FSName := "";
      FSFlags := 0;
      UsageInfo := "";
      long TotalSpace, FreeSpace;
      status=_GetDiskSpace(path,TotalSpace,FreeSpace);
      if (!status) {
         UsageInfo = ","MBRound(FreeSpace)" free";
      }
      if (substr(path,1,2)=='\\') {
         typeless machinename, sharename;
         parse path with '\\'machinename'\'sharename'\';
         status=ntGetVolumeInformation('\\'machinename'\'sharename'\',FSName,FSFlags);
         if (!status) {
            FSInfo=","FSName;
         }
         diskinfo :+= " (remote"FSInfo:+UsageInfo")";
      } else {
         status=ntGetVolumeInformation(substr(path,1,3),FSName,FSFlags);
         if (!status) {
            FSInfo=","FSName;
         }
         _str dt=_drive_type(substr(path,1,2));
         if (dt==DRIVE_NOROOTDIR) {
            diskinfo :+= " (invalid drive)";
         } else if (dt==DRIVE_FIXED) {
            diskinfo :+= " (non-removable drive"FSInfo:+UsageInfo")";
         } else if (dt==DRIVE_CDROM){
            diskinfo :+= " (CD-ROM"FSInfo:+UsageInfo")";
         } else if (dt==DRIVE_REMOTE){
            diskinfo :+= " (remote"FSInfo:+UsageInfo")";
         } else {
            diskinfo :+= " (removable drive"FSInfo:+UsageInfo")";
         }
      }
   }
   return diskinfo;
}

_str _version()
{
   number := "";
   parse get_message(SLICK_EDITOR_VERSION_RC) with . "Version" number . ;
   return(number);
}

_str _product_year()
{
   year := "";
   parse get_message(SLICK_EDITOR_VERSION_RC) with . "Copyright" ."-"year .;

   return year;
}

_str _getProduct(bool includeVersion=true,bool includeArchInfo=false)
{
   product := _getApplicationName();
   if( isEclipsePlugin() ) {
      if (_isUnix()) {
         product :+= " Core v"eclipse_get_version()" for Eclipse";
      } else {
         product :+= " v"eclipse_get_version()" for Eclipse";
      }
   } else {
      product :+= " "_product_year();
   }


   verInfo := "";
   archInfo := "";

   if( includeVersion ) {
      _str version = _getVersion();
      if( isEclipsePlugin() ) {
         // Product name is so long that the version just
         // looks better on the next line.
         verInfo = "\n\n<b> Library Version:</b> "version;
      } else {
         verInfo = "v"version;
      }
   }

   if ( includeArchInfo ) {
      archInfo = machine_bits()"-bit";
      archInfo :+= " Qt"_QtMajorVersion();
   }

   if (verInfo != "" || archInfo != "") {
      if (!isEclipsePlugin()) {
         product :+= " (";
      }
      if (verInfo != "") {
         product :+= verInfo;
      }

      if (archInfo != "") {
         if (verInfo != "") {
            product :+= " ";
         }
         product :+= archInfo;
      }

      if (!isEclipsePlugin()) {
         product :+= ")";
      }
   }

   return product;
}

_str aboutProduct(bool includeVersion=false, _str altCaption=null)
{
   line := "";

   includeArchInfo := false;
   if (_isWindows()) {
      includeArchInfo = true;
   } else {
      includeArchInfo = _isLinux();
   }

   _str product = _getProduct(includeVersion, includeArchInfo);
   line=product;
   if( altCaption!=null ) {
      line=altCaption:+product;
   }

   return line;
}

_str _getVersion(bool includeSuffix=true)
{
   version := "";
   suffix := "";
   parse get_message(SLICK_EDITOR_VERSION_RC) with . "Version" version suffix .;
   if( includeSuffix && stricmp(suffix,"Beta") == 0 ) {
      version :+= " "suffix;
   }
   return version;
}
_str _getUserSysFileName() {
   return(USERSYSO_FILE_PREFIX:+_getVersion(false):+USERSYSO_FILE_SUFFIX);
}

_str aboutVersion(_str altCaption=null)
{
   _str line = _getVersion();
   if( altCaption!=null ) {
      line=altCaption:+line;
   }
   return line;
}

_str _getCopyright()
{
   copyright := "";
   parse get_message(SLICK_EDITOR_VERSION_RC) with . "Copyright" +0 copyright;
   return copyright;
}

_str aboutCopyright(_str altCaption=null)
{
   _str line = _getCopyright();
   if( altCaption!=null ) {
      line=altCaption:+line;
   }
   return line;
}

_str _getInstalledSerial()
{
   return _SerialNumber();
}

_str _getSerial()
{
   return _getInstalledSerial();
}

_str aboutSerial(_str altCaption=null)
{
   _str line = _getSerial();
   if (line == "") {
      line = "No license found";
   }
   if( altCaption != null ) {
      line = altCaption:+line;
   } else {
      line = "<b>"get_message(VSRC_CAPTION_SERIAL_NUMBER)"</b>: "line;
   }
   return line;
}

_str _getLicenseType()
{
   type := _LicenseType();
   switch(type) {
   case LICENSE_TYPE_TRIAL:
      return("Trial");
      break;
   case LICENSE_TYPE_NOT_FOR_RESALE:
      return("Not For Resale");
      break;
   case LICENSE_TYPE_BETA:
      return("Beta License");
      break;
   case LICENSE_TYPE_SUBSCRIPTION:
      return("Subscription");
      break;
   case LICENSE_TYPE_ACADEMIC:
      return("Academic");
      break;
   case LICENSE_TYPE_CONCURRENT:
      return("Concurrent");
      break;
   case LICENSE_TYPE_STANDARD:
      return("Standard");
      break;
   case LICENSE_TYPE_FILE:
      return("File");
      break;
   case LICENSE_TYPE_BORROW:
      return("Borrow");
      break;
   default:
      return("Unknown licensing ("type")");
   }
}

_str _getLicensedNofusers()
{
   type := _LicenseType();
   switch(type) {
   case LICENSE_TYPE_TRIAL:
      return("Trial");
   case LICENSE_TYPE_NOT_FOR_RESALE:
      return("Not For Resale");
   case LICENSE_TYPE_BETA:
      return("Beta License");
   case LICENSE_TYPE_SUBSCRIPTION:
      return("Subscription");
   case LICENSE_TYPE_ACADEMIC:
      return("Academic");
   case LICENSE_TYPE_CONCURRENT:
   case LICENSE_TYPE_STANDARD:
   case LICENSE_TYPE_FILE:
   case LICENSE_TYPE_BORROW:
      // 0 means that this is not a concurrent license
      return(_FlexlmNofusers());
   }
   return("Unknown licensing ("type")");
}

bool _singleUserTypeLicense()
{
   switch(_LicenseType()) {
   case LICENSE_TYPE_TRIAL:
   case LICENSE_TYPE_NOT_FOR_RESALE:
   case LICENSE_TYPE_BETA:
   case LICENSE_TYPE_ACADEMIC:
   case LICENSE_TYPE_BORROW:
      return true;
   }
   return false;
}

_str aboutLicensedNofusers(_str altCaption=null)
{
   _str line = _getLicensedNofusers();
   // 0 means that this is not a concurrent license
   // 1 means that this IS a concurrent license of 1.
   // We may one to change what gets displayed if "1" is returned.
   if ((_LicenseType() != LICENSE_TYPE_CONCURRENT) && (line == "" || line=="1" || line=="0")) {
      line = "Single user";
      if (_LicenseType() == LICENSE_TYPE_BORROW) {
         line :+= " (borrowed)";
      }
   }
   if( altCaption != null ) {
      line = altCaption:+line;
   } else {
      if (isEclipsePlugin() || _singleUserTypeLicense()) {
         line = "<b>License type</b>: "line;
      } else {
         line = "<b>"get_message(VSRC_CAPTION_NOFUSERS)"</b>: "line;
      }
   }
   return line;
}

_str aboutLicensedExpiration(_str altCaption=null)
{
   int caption = VSRC_CAPTION_LICENSE_EXPIRATION;
   _str line = _LicenseExpiration();
   if (line=="") return("");
   if( altCaption != null ) {
      line = altCaption:+line;
   } else {
      if (_LicenseType() == LICENSE_TYPE_BORROW) {
         caption = VSRC_CAPTION_LICENSE_BORROW_EXPIRATION;
      }
      line_b := "";
      line_e := "";
      /*
      if (_fnpLastLicenseExpiresInDays() < 5) {
         line_b = "<font color='red'>";
         line_e = "</font>";
      }*/
      line = "<b>"get_message(caption)"</b>: ":+line_b:+line:+line_e;
   }
   return line;
}
_str aboutLicensedFile(_str altCaption=null)
{
   line := "";
   caption := -1;
   if (_LicenseType() == LICENSE_TYPE_CONCURRENT) {
      line = _LicenseServerName();
      caption = VSRC_CAPTION_LICENSE_SERVER;
   }
   if (line == "") {
      line = _LicenseFile();
      caption = VSRC_CAPTION_LICENSE_FILE;
   }
   if (line=="") return("");
   if( altCaption != null ) {
      line = altCaption:+line;
   } else {
      line = "<b>"get_message(caption)"</b>: "line;
   }
   return line;
}
_str aboutLicensedTo(_str altCaption=null)
{
   _str line = _LicenseToInfo();
   if (line=="") return("");
   if( altCaption != null ) {
      line = altCaption:+line;
   } else {
      line = "<b>"get_message(VSRC_CAPTION_LICENSE_TO)"</b>: "line;
   }
   return line;
}

_str aboutUnlicensedFeatures() {
   unlicensedFeatures := "";
   if (!_haveBuild()) {
      unlicensedFeatures :+= ", Build";
   }
   if (!_haveDebugging()) {
      unlicensedFeatures :+= ", Debugging";
   }
   if (!_haveContextTagging()) {
      unlicensedFeatures :+= ", Context Tagging(TM)";
   }
   if (!_haveVersionControl()) {
      unlicensedFeatures :+= ", Version Control";
   }
   if (!_haveProMacros()) {
      unlicensedFeatures :+= ", Pro Macros";
   }
   if (!_haveBeautifiers()) {
      unlicensedFeatures :+= ", Beautifiers";
   }
   if (!_haveProDiff()) {
      unlicensedFeatures :+= ", Pro Diff";
   }
   if (!_haveMerge()) {
      unlicensedFeatures :+= ", Merge";
   }
   if (!_haveRefactoring()) {
      unlicensedFeatures :+= ", Refactoring";
   }
   if (!_haveRealTimeErrors()) {
      unlicensedFeatures :+= ", Java Real Time Errors";
   }

   if (_isCommunityEdition()) {
      unlicensedFeatures :+= ", Large File";
   }
   if (!_haveDiff()) {
      unlicensedFeatures :+= ", Diff";
   }
   if (!_haveBackupHistory()) {
      unlicensedFeatures :+= ", Backup History";
   }
   if (!_haveXMLValidation()) {
      unlicensedFeatures :+= ", XML Validation";
   }
   if (!_haveSmartOpen()) {
      unlicensedFeatures :+= ", Smart Open";
   }
   if (!_haveFTP()) {
      unlicensedFeatures :+= ", FTP";
   }
   /*
   if (!_haveMainframeLangs()) {
      unlicensedFeatures :+= ", Mainframe Languages Tagging";
   }
   if (!_haveHardwareLangs()) {
      unlicensedFeatures :+= ", Hardware Languages Tagging";
   }
   if (!_haveAdaLangs()) {
      unlicensedFeatures :+= ", Ada Language Tagging";
   }
   if (!_haveSQLLangs()) {
      unlicensedFeatures :+= ", SQL Languages Tagging";
   }
   */
   if (!_haveDefsToolWindow()) {
      unlicensedFeatures :+= ", Defs Tool Window";
   }
   if (!_haveCurrentContextToolBar()) {
      unlicensedFeatures :+= ", Current Context Toolbar";
   }
   if (!_haveCtags()) {
      unlicensedFeatures :+= ", Ctags";
   }
   if (!_haveCodeAnnotations()) {
      unlicensedFeatures :+= ", Code Annotations";
   }
   unlicensedFeatures=strip(unlicensedFeatures,'L',',');
   unlicensedFeatures=strip(unlicensedFeatures);
   if (unlicensedFeatures!="") {
      unlicensedFeatures="<b>Unlicensed Pro Features</b>:"unlicensedFeatures;
   }
   return unlicensedFeatures;
}

_str aboutUnlicensedLanguages() {
   unlicensedLanguages := "";
   if (!_haveMainframeLangs()) {
      unlicensedLanguages :+= "Cobol, HLASM, PL/I, ";
   }
   if (!_haveHardwareLangs()) {
      unlicensedLanguages :+= "VHDL, TTCN3, Vera, Verilog, SystemVerilog, ";
   }
   if (!_haveAdaLangs()) {
      unlicensedLanguages :+= "Ada, Modula-2, ";
   }
   if (!_haveSQLLangs()) {
      unlicensedLanguages :+= "ANSI SQL, PL/SQL, SQL Server, DB2, ";
   }
   unlicensedLanguages=strip(unlicensedLanguages);
   unlicensedLanguages=strip(unlicensedLanguages,'T',',');
   if (unlicensedLanguages != "") {
      unlicensedLanguages="<b>Unlicensed Standard/Pro Languages Tagging</b>: "unlicensedLanguages;
   }
   return unlicensedLanguages;
}

static _str _localizeBuildDate(_str MMM_DD_YYYY)
{
   // break it down into short month, day, and year
   parse MMM_DD_YYYY with auto month auto day auto year;

   // Switch out short month name for long month name
   split(def_short_month_mames, ' ', auto monthNames);
   for (m:=0; m<monthNames._length(); m++) {
      if (beginsWith(monthNames[m], month, false, 'i')) break;
   }
   split(def_long_month_names, ' ', monthNames);
   if (m < monthNames._length()) {
      month = monthNames[m];
   }

   // make sure that day of month does not have a leading zero
   if (length(day) >= 2 && _first_char(day) == '0') {
      day = _last_char(day);
   }

   // return date in standard format -- should localize this
   // using DateTime class, just trying to avoid a dependency
   return month:+" ":+day:+", ":+year;
}

_str _getStateFileBuildDate()
{
   build_date := __DATE__;
   return _localizeBuildDate(build_date);
}

_str _getProductBuildDate()
{
   build_date := _getSlickEditBuildDate();
   return _localizeBuildDate(build_date);
}

_str aboutProductBuildDate(_str altCaption=null)
{
   line := "";
   if (isEclipsePlugin()) {
      line = _getEclipseBuildDate();
   } else {
      line = _getProductBuildDate();
   }

   // include the state file build date if it differs
   state_line := _getStateFileBuildDate();
   if (state_line != line) {
      line :+= "&nbsp;&nbsp;&nbsp;("get_message(VSRC_CAPTION_STATE_BUILD_DATE)": "state_line")";
   }
   if( altCaption!=null ) {
      line=altCaption:+line;
   } else {
      line="<b>"get_message(VSRC_CAPTION_BUILD_DATE)"</b>: "line;
   }
   return line;
}

_str _getExpirationDate()
{
   expiration := "";
   return expiration;
}

_str aboutExpirationDate(_str altCaption=null)
{
   _str line= _getExpirationDate();
   if( line!="" ) {
      if( altCaption!=null ) {
         line=altCaption:+line;
      } else {
         line="<b>"get_message(VSRC_CAPTION_EXPIRATION_DATE)"</b>: ":+line;
      }
   }
   return line;
}

_str longEmulationName (_str name=def_keys)
{
   switch (name) {
   case "slick-keys":
      return "SlickEdit";
   case "":
      return "SlickEdit";
   case "bbedit-keys":
      return "BBEdit";
   case "brief-keys":
      return "Brief";
   case "codewarrior-keys":
      return "CodeWarrior";
   case "codewright-keys":
      return "CodeWright";
   case "emacs-keys":
      return "Epsilon";
   case "gnuemacs-keys":
      return "GNU Emacs";
   case "ispf-keys":
      return "ISPF";
   case "vcpp-keys":
      return "Visual C++ 6";
   case "vi-keys":
      return "Vim";
   case "vsnet-keys":
      return "Visual Studio";
   case "cua-keys":
       return "CUA";
   case "windows-keys":
      return "CUA";
   case "macosx-keys":
      return "macOS";
   case "xcode-keys":
      return "Xcode";
   case "eclipse-keys":
      return "Eclipse";
   }
   return "";
}

_str shortEmulationName (_str name)
{
   switch (name) {
   case "SlickEdit":
      return "slick";
   case "BBEdit":
      return "bbedit";
   case "Brief":
      return "brief";
   case "CodeWarrior":
      return "codewarrior";
   case "CodeWright":
      return "codewright";
   case "Epsilon":
      return "emacs";
   case "GNU Emacs":
      return "gnuemacs";
   case "ISPF":
      return "ispf";
   case "Visual C++ 6":
      return "vcpp";
   case "Vim":
      return "vi";
   case "Visual Studio":
      return "vsnet";
   case "Windows":
   case "CUA":
      return "windows";
   case "macOS":
       return "macosx";
   case "Xcode":
      return "xcode";
   case "Eclipse":
      return "eclipse";
   }
   return "";
}

_str _getEmulation()
{
   // special cases
   if (def_keys == "") {
      return "SlickEdit (text mode edition)";
   }

   return longEmulationName(def_keys);
}

_str aboutEmulation(_str altCaption=null)
{
   _str line = _getEmulation();
   if( altCaption!=null ) {
      line=altCaption:+line;
   } else {
      line="<b>"get_message(VSRC_CAPTION_EMULATION)"</b>: "line;
   }
   return line;
}

/**
 * Retrieve the current project type, suitable for display.
 *
 * @param altCaption
 *
 * @return _str
 */
_str aboutProject(_str altCaption=null, bool protectCustom = false)
{
   line := "No project open";
   // do we have a project name?
   if (_project_name._length() > 0 || _fileProjectHandle()>0) {
      handle := _ProjectHandle();
      // do we have an open project?
      if (handle > 0) {
         // it might be visual studio?
         line = _ProjectGet_AssociatedFileType(handle);
         if (line == "") {
            // some projects will just tell you the type
            line = _ProjectGet_ActiveType();
            if (line == "") {
               // check for a template name attribute - these were added in v16, so
               // all projects will not have them
               line = _ProjectGet_TemplateName(handle);
               if (line != "" && protectCustom && _ProjectGet_IsCustomizedProjectType(handle)) {
                  line = "Customized";
               }

               if (line == "") {
                  // try one last thing...it's hokey!
                  line = determineProjectTypeFromTargets(handle);
                  if (line == "") {
                     line = "Other";
                  }
               }
            }
         }
         // capitalize the first letter of each word if there's a project open
         line = _cap_string(line);
         if (_project_name=="") {
            line="Single file project - "line;
         }
      }
   }

   if (altCaption!=null ) {
      line=altCaption:+line;
   } else {
      line="<b>"get_message(VSRC_CAPTION_CURRENT_PROJECT_TYPE)"</b>: "line;
   }
   return line;
}

/**
 * Try to determine the project type by examining the target commandlines.  This
 * will not always work, in the case that the user has changed them.
 *
 * @param handle           handle of project file
 *
 * @return _str            project type, blank if one could not be determined
 */
static _str determineProjectTypeFromTargets(int handle)
{
   // NAnt
   // shackett 7-27-10 (removed Ch checking because the criteria is too broad, too much
   // stuff was being falsely reported as Ch)
   node := _xmlcfg_find_simple(handle, "/Project/Config/Menu/Target/Exec/@CmdLine[contains(., 'ch', 'I')]");
   if (node > 0) {
      node = _xmlcfg_find_simple(handle, "/Project/Files/Folder/@Filters[contains(., '*.build', 'I')]");
      if (node > 0) {
         return "NAnt";
      }
   }

   // SAS
   node = _xmlcfg_find_simple(handle, "/Project/Config/Menu/Target/Exec/@CmdLine[contains(., 'sassubmit', 'I')]");
   if (node > 0) {
      return "SAS";
   }

   // Vera
   node = _xmlcfg_find_simple(handle, "/Project/Config/Menu/Target/Exec/@CmdLine[contains(., 'vera', 'I')]");
   if (node > 0) {
      return "Vera";
   }

   // Verilog
   node = _xmlcfg_find_simple(handle, "/Project/Config/Menu/Target/Exec/@CmdLine[contains(., 'vlog', 'I')]");
   if (node > 0) {
      return "Verilog";
   }

   // VHDL
   node = _xmlcfg_find_simple(handle, "/Project/Config/Menu/Target/Exec/@CmdLine[contains(., 'vcom', 'I')]");
   if (node > 0) {
      return "VHDL";
   }

   return "";
}

_str aboutLanguage(_str altCaption=null)
{
   // is there a file open?
   line := "";
   bufId := _mdi.p_child;
   if (bufId && !_no_child_windows()) {
      lang := _LangGetModeName(bufId.p_LangId);
      line = "."_get_extension(bufId.p_buf_name);
      if (lang != "") {
         line :+= " ("lang")";
      }
   } else {
      line = "No file open";
   }

   if( altCaption!=null ) {
      line=altCaption:+line;
   } else {
      line="<b>"get_message(VSRC_CAPTION_CURRENT_LANGUAGE)"</b>: "line;
   }
   return line;
}

_str aboutEncoding(_str altCaption=null)
{
   // is there a file open?
   line := "";
   bufId := _mdi.p_child;
   if (bufId && !_no_child_windows()) {
      if (bufId.p_encoding==VSCP_ACTIVE_CODEPAGE) {
         line='ACP ('_GetACP()')';
      } else {
         line = encodingToTitle(bufId.p_encoding);
      }
   } else {
      line = "No file open";
   }

   if( altCaption!=null ) {
      line=altCaption:+line;
   } else {
      line="<b>"get_message(VSRC_CAPTION_CURRENT_ENCODING)"</b>: "line;
   }
   return line;
}

#if 1 /* __UNIX__*/
   _str macGetOSVersion();
   _str macGetOSName();
   _str macGetProcessorArch();
#endif

_str _getOsName()
{
   osname := "";

   if (_isWindows()) {
      typeless MajorVersion, MinorVersion, BuildNumber, PlatformId, ProductType;
      _str CSDVersion;
      ntGetVersionEx(MajorVersion, MinorVersion, BuildNumber, PlatformId, CSDVersion, ProductType);
      if (length(MinorVersion) < 1) {
         MinorVersion = "0";
      }
      if (MajorVersion>=10) {
         if(MajorVersion==10 && MinorVersion==0) {
            osname = "Windows 10";
         } else {
            osname = "Windows 10 or Later";
         }
      } else if (PlatformId == 1) {
         bool IsWindows98orLater = (PlatformId == 1) &&
            ((MajorVersion > 4) ||
             ((MajorVersion == 4) && (MinorVersion > 0))
             );
         osname = "Windows 95";
         if (MajorVersion == "4" && MinorVersion == "90") {
            osname = "Windows ME";
         } else if (IsWindows98orLater) {
            osname = "Windows 98 or Later";
         }
      } else if (PlatformId == 2) {
         if (MajorVersion <= 4) {
            osname = "Windows NT";
         } else if (MajorVersion <= 5) {
            if (MinorVersion >= 2) {
               if (ProductType == 1) {
                  osname = "Windows XP";
               } else {
                  osname = "Windows Server 2003";
               }
            } else if (MinorVersion == 1) {
               osname = "Windows XP";
            } else {
               osname = "Windows 2000";
            }
         } else if (MajorVersion <= 6) {
            if (MinorVersion == 0) {
               if (ProductType == 1) {
                  osname = "Windows Vista";
               } else {
                  osname = "Windows Server 2008";
               }
            } else if (MinorVersion == 1) {
               if (ProductType == 1) {
                  osname = "Windows 7";
               } else {
                  osname = "Windows Server 2008 R2";
               }
            } else if (MinorVersion == 2) {
               if (ProductType == 1) {
                  osname = "Windows 8";
               } else {
                  osname = "Windows Server 2012";
               }
            } else {
               osname="Windows 8 or Later";
            }
         } else {
            osname = "Windows 8 or Later";
         }
      } else {
         osname = "Windows ("PlatformId")";
      }
      // add an indicator if this is 64 bit
      if (ntIs64Bit() != 0) {
         osname :+= " x64";
      }
   } else {
      UNAME info;
      _uname(info);
      osname = info.sysname;

      // get a little more specific for Solaris platforms
      if (machine() == "SPARCSOLARIS") {
         osname :+= " Sparc";
      } else if (machine() == "INTELSOLARIS") {
         osname :+= " Intel";
      } else if (_isMac()) {
         osname =  macGetOSName();
      }
   }

   return osname;
}

/**
 * Get processor and/or operating system architecture
 */
static _str _getArchitecture()
{
   architecture := "";
   if (_isUnix()) {
      if(_isMac()) {
         architecture = macGetProcessorArch();
      } else {
         UNAME info;
         _uname(info);
         architecture :+= info.cpumachine;
      }
   }
   return architecture;
}

/**
 * Get extra OS version information, such as the distro name and
 * version on Linux.
 *
 * @return _str OS version information
 */
static _str _getOsVersion()
{
   if (length(_os_version_name) > 0) {
      // Cached version name
      return _os_version_name;
   }

   if (_isMac()) {
      _os_version_name = macGetOSVersion();
      return _os_version_name;
   }

   osver := "Unknown";

   // Try lsb_release command first (for LSB-compliant Linux distro)
   _str com_name = path_search("lsb_release");
   if (com_name != "" && _getOsVersionLSB(osver)) {
      // New version name.  Cache it.
      _os_version_name = osver;
      return osver;
   }

   // Try "/etc/issue" next.
   if (_getOsVersionUnix(osver)) {
      _os_version_name = osver;
      return osver;
   }

   return osver;
}

/**
 * Get just the first line from file specified.  In case the
 * first line is empty, keep going down until the last line is
 * reached.
 *
 * @param filename full path of file to open
 * @param line first line
 *
 * @return bool true on success, false otherwise.
 */
static bool _getFirstLineFromFile(_str filename, _str &line)
{
   // open the file in a temp view
   temp_view_id := 0;
   orig_view_id := 0;
   int status = _open_temp_view(filename, temp_view_id, orig_view_id);
   if (status) {
      return false;
   }

   top();
   do {
      get_line_raw(line);
      line = strip(line);
      if (line != "") {
         break;
      }
   } while (down() != BOTTOM_OF_FILE_RC);

   _delete_temp_view(temp_view_id);
   activate_window(orig_view_id);
   if (line == "") {
      return false;
   }
   return true;
}

/**
 * Get the OS version string from /etc/issue.  This may be used
 * on older Linux distros, or UNIX platforms where command
 * 'lsb_release' is not available.
 *
 * @param osver (reference) OS version name
 *
 * @return bool true on success, false otherwise
 */
static bool _getOsVersionUnix(_str& osver)
{
   issue_file := "";
   if (!_getFirstLineFromFile("/etc/issue", issue_file)) {
      return false;
   }
   osver = "";
   // First, read everything up to the first backslash (\).
   if (pos('{[~\\]#}', issue_file, 1, 'R') == 0) {
      return false;
   }
   osver = strip(substr(issue_file, pos('S0'), pos('0')));

   // In case the string starts with 'Welcome to', strip it.
   if (pos("Welcome to", osver, 1, 'I') == 1) {
      osver = strip(substr(osver, length("Welcome to")+1));
   }
   return true;
}

/**
 * Determine the distribution name and version for Linux. On
 * LSB-compliant Linux distro, it is determined from the system
 * command 'lsb_release -d'.  This command produces one-line
 * string of the format:
 * <pre>
 *   'Description: <disto name and version>'
 * </pre>
 *
 * @param osver (reference) OS version name
 *
 * @return bool true if successful, false otherwise.
 */
static bool _getOsVersionLSB(_str& osver)
{
   _str com_name = path_search("lsb_release");
   if (com_name == "") {
      // Command not available.
      return false;
   }
   com_name :+= " -d";

   int hstdout, hstderr, hstdin;
   int phandle = _PipeProcess(com_name, hstdin, hstdout, hstderr, '');
   if (phandle < 0) {
      // Pipe process failed.
      return false;
   }

   _str buf;
   int start_time = (int)_time('G');
   while (!_PipeIsReadable(hstdin)) {
      int cur_time = (int)_time('G');
      if (cur_time - start_time >= 5) {
         // Wait for stdout pipe up to 5 seconds to avoid infinite loop.
         return false;
      }
   }
   if (_PipeRead(hstdin, buf, 100, 0) < 0) {
      // Pipe read failed.
      return false;
   }
   _PipeCloseProcess(phandle);
   if (buf == "") {
      return false;
   }

   // Now I have the output string from 'lsb_release -d'.
   // Get the substring that is the name of distro.
   //   format: 'Description:   SUSE Linux 10.1...'
   buf = strip(buf, 'T', "\n");
   if (pos("Description\\:[ \t]#{?#}", buf, 1, "R") == 0) {
      return false;
   }
   buf = substr(buf, pos('S0'), pos('0'));
   osver = buf;
   return true;
}

_str aboutOsName(_str altCaption=null)
{
   line := _getOsName();
   if( altCaption!=null ) {
      line=altCaption:+line;
   } else {
      line="<b>"get_message(VSRC_CAPTION_OPERATING_SYSTEM)"</b>: "line;
   }
   return line;
}

_str aboutInstallationDirectory(_str altCaption=null)
{
   line := "";

   install_dir := "";
   caption := "";
   if( altCaption!=null ) {
      caption=altCaption;
   } else {
      caption=get_message(VSRC_CAPTION_INSTALLATION_DIRECTORY);
   }
   appendDiskInfo(install_dir,_getSlickEditInstallPath(),caption);

   line=install_dir;

   return line;
}

_str aboutConfigurationDirectory(_str altDirectoryCaption=null, _str altUsageCaption=null)
{
   line := "";

   config_info := "";
   dir_caption := "";
   if( altDirectoryCaption!=null ) {
      dir_caption=altDirectoryCaption;
   } else {
      dir_caption=get_message(VSRC_CAPTION_CONFIGURATION_DIRECTORY);
   }
   usage_caption := "";
   if( altUsageCaption!=null ) {
      usage_caption=altUsageCaption;
   } else {
      usage_caption=get_message(VSRC_CAPTION_CONFIGURATION_DRIVE_USAGE);
   }
   appendDiskInfo(config_info,_ConfigPath(),dir_caption,usage_caption);

   line=config_info;

   return line;
}

_str aboutMigratedConfigurationDirectory(_str altCaption=null)
{
   line := "";
   if (def_config_transfered_from_dir != "") {

      dirCaption := "";
      if (altCaption != null) {
         dirCaption=altCaption;
      } else {
         dirCaption=get_message(VSRC_CAPTION_MIGRATED_CONFIG);
      }

      line="<b>"dirCaption"</b>:  "def_config_transfered_from_dir;
   }

   return line;
}

_str aboutImportedOptions(_str altCaption=null)
{
   line := "";
   if (def_config_imports_from!='' && def_config_imports_ver==_version()) {

      dirCaption := "";
      if (altCaption != null) {
         dirCaption=altCaption;
      } else {
         dirCaption=get_message(VSRC_CAPTION_IMPORTED_CONFIG);
      }

      line="<b>"dirCaption"</b>:  "def_config_imports_from;
   }

   return line;
}

_str aboutSpillFileDirectory(_str altDirectoryCaption=null, _str altUsageCaption=null)
{
   line := "";

   spill_info := "";
   if( _SpillFilename()!="" ) {
      // Spill File: C:\DOCUME~1\joesmith\LOCALS~1\Temp\$slk.1 (non-removable drive,FAT32)
      // Spill File Directory Drive Usage: 31446MB / 36860MB
      dir_caption := "";
      if( altDirectoryCaption!=null ) {
         dir_caption=altDirectoryCaption;
      } else {
         dir_caption=get_message(VSRC_CAPTION_SPILL_FILE);
      }
      usage_caption := "";
      if( altUsageCaption!=null ) {
         usage_caption=altUsageCaption;
      } else {
         usage_caption=get_message(VSRC_CAPTION_SPILL_FILE_DIRECTORY_DRIVE_USAGE);
      }
      appendDiskInfo(spill_info,_SpillFilename(),dir_caption,usage_caption);
   }

   line=spill_info;

   return line;
}

_str aboutDiskInfo()
{
   line := "";

   line=line                        :+
      aboutInstallationDirectory()  :+
      "\n"                          :+
      aboutConfigurationDirectory();

   _str mig_cfg_line = aboutMigratedConfigurationDirectory();
   if( mig_cfg_line!="" ) {
      line=line                     :+
         "\n"                       :+
         mig_cfg_line;
   }
   mig_cfg_line = aboutImportedOptions();
   if( mig_cfg_line!="" ) {
      line=line                     :+
         "\n"                       :+
         mig_cfg_line;
   }

   _str spill_line = aboutSpillFileDirectory();
   if( spill_line!="" ) {
      line=line                     :+
         "\n"                       :+
         spill_line;
   }

   return line;
}

const DISPLAYMANAGER_FILE='/etc/X11/default-display-manager';
const DISPLAYMANAGER_UNIT='/etc/systemd/system/display-manager.service';

static _str x11WindowManager()
{
   ds := '';
   show_output := false;
   // Look and see if window manager atom is set.
   rc := exec_command_to_temp_view('xprop -root -notype', auto tempView, auto origView, -1, 0, show_output);
   if (rc == 0) {
      top();
      rc = search('^_NET_SUPPORTING_WM_CHECK: window id # ([A-Fa-f0-9x]+)', '@L');
      wid := '';
      if (rc == 0) {
         wid = get_text(match_length('1'), match_length('S1'));
      }
      p_window_id = origView;
      _delete_temp_view(tempView);
      if (rc == 0) {
         rc = exec_command_to_temp_view('xprop -id 'wid' _NET_WM_NAME', tempView, origView, -1, 0, show_output);
         if (rc == 0) {
            top();
            rc = search('^[^=]+= "([^"]+)"', '@L');
            if (rc == 0) {
               ds = get_text(match_length('1'), match_length('S1'));
            }
            p_window_id = origView;
            _delete_temp_view(tempView);
         }
      }
   }

   if (ds == '') {
      // Maybe not always what we want, but good enough usually if it is available.
      ds = get_env('XDG_SESSION_DESKTOP');
   }

   if (ds == '') {
      ds = 'Unknown';
   }
   gX11WindowManager = ds;

   rv := '<b>Window Manager</b>: 'ds;

   dm := '';
   if (file_exists(DISPLAYMANAGER_FILE)) {
      rc = exec_command_to_temp_view('cat 'DISPLAYMANAGER_FILE, tempView, origView, -1, 0, show_output);
      if (rc == 0) {
         p_line = 1;
         get_line(dm);
         p_window_id = origView;
         _delete_temp_view(tempView);
      }
   }  else if (file_exists(DISPLAYMANAGER_UNIT)) {
      rc = exec_command_to_temp_view('grep ExecStart= 'DISPLAYMANAGER_UNIT, tempView, origView, -1, 0, show_output);
      if (rc == 0) {
         p_line = 1;
         get_line(dm);
         epos := pos('=', dm);
         if (epos > 0) {
            dm = substr(dm, epos+1);
         }
      }
   } else {
      rc = 0;
      dm = 'Unknown';
   }

   if (dm == '') {
      dm = 'Unknown';
   }
   rv :+= "\n<b>Display manager</b>: "dm;

   return rv"\n";
}

_str getX11WindowManager()
{
   if (gX11WindowManager == "") {
       x11WindowManager();
   }

   return gX11WindowManager;
}

bool wmNeedsModalWorkaround()
{
   wm := getX11WindowManager();
   rv := wm ==  "Openbox";
   //say('workaround='rv', wm='wm);
   return rv;
}

_str aboutOsInfo(_str altCaption=null)
{
   line := "";

   osinfo := "";
   if (_isWindows()) {
      // OS: Windows XP
      // Version: 5.01.2600  Service Pack 1
      typeless MajorVersion,MinorVersion,BuildNumber,PlatformId,ProductType;
      _str CSDVersion;
      ntGetVersionEx(MajorVersion,MinorVersion,BuildNumber,PlatformId,CSDVersion,ProductType);
      if( length(MinorVersion)<1 ) {
         MinorVersion="0";
      }
      // Pretty-up the minor version number for display
      if( length(MinorVersion)<2 ) {
         MinorVersion="0"MinorVersion;
      }
      osinfo :+= "<b>"get_message(VSRC_CAPTION_OPERATING_SYSTEM)"</b>:  "_getOsName();
      osinfo :+= "\n";
      osinfo :+= "<b>"get_message(VSRC_CAPTION_OPERATING_SYSTEM_VERSION)"</b>:  "MajorVersion"."MinorVersion"."BuildNumber"&nbsp;&nbsp;"CSDVersion;
   } else {
      // OS: SunOS
      // Kernel Level: 5.7
      // Build Version: Generic_106541-31
      // X Server Vendor: Hummingbird Communications Ltd.
      UNAME info;
      _uname(info);
      osinfo :+= "<b>"get_message(VSRC_CAPTION_OPERATING_SYSTEM)"</b>: "_getOsName();
      osinfo :+= "\n";
      if (_isLinux() || _isMac()) {
         osinfo :+= "<b>"get_message(VSRC_CAPTION_OPERATING_SYSTEM_VERSION)"</b>: "_getOsVersion();
         osinfo :+= "\n";
      }

      if (_isMac() == false) {
         osinfo :+= "<b>"get_message(VSRC_CAPTION_KERNEL_LEVEL)"</b>: "info.release;
         osinfo :+= "\n";
         osinfo :+= "<b>"get_message(VSRC_CAPTION_BUILD_VERSION)"</b>: "info.version;
         osinfo :+= "\n";
      }
      // Display processor architecture
      osinfo :+= "<b>"get_message(VSRC_CAPTION_PROCESSOR_ARCH)"</b>: "_getArchitecture();
      osinfo :+= "\n";

      // Display X server details
      if (_isMac() == false) {
         osinfo :+= "\n";
         osinfo :+= "<b>"get_message(VSRC_CAPTION_XSERVER_VENDOR)"</b>: "_XServerVendor();
         osinfo :+= "\n"x11WindowManager();
      }
   }

   line=osinfo;
   if( altCaption!=null ) {
      line=altCaption:+line;
   }

   return line;
}

/**
 * Get the total amount of virtual memory on the current machine
 * and the amount of available memory.
 *
 * @param TotalVirtual   (k) virtual address size
 * @param AvailVirtual   (k) free virtual address size
 *
 * @return 0 on success, <0 on error
 */
int _VirtualMemoryInfo(long &TotalVirtual, long &AvailVirtual)
{
   // initialize results
   TotalVirtual = AvailVirtual = 0;

   if (_isUnix()) {
      if (_isMac()) {
         //TotalVirtual=8388608;
         //AvailVirtual=8388608;
         _MacGetMemoryInfo(TotalVirtual, AvailVirtual);
         return 0;
      }
      // find the vmstat program
      vmstat_name := "vmstat";
      if (file_exists("/usr/bin/vmstat")) {
         vmstat_name = "/usr/bin/vmstat";
      } else if (file_exists("/usr/bin/vm_stat")) {
         vmstat_name = "/usr/bin/vm_stat"; // psycho mac
      } else {
         vmstat_name = path_search(vmstat_name);
         if (vmstat_name == "") {
            return FILE_NOT_FOUND_RC;
         }
      }

      // shell out the command and get the result
      vmstat_status := 0;
      vmstat_info := _PipeShellResult(vmstat_name, vmstat_status);
      if (vmstat_status) {
         return vmstat_status;
      }

      // split the result into lines
      split(vmstat_info, "\n", auto vmstat_lines);

      if (_isMac() && vmstat_lines._length() >= 5) {
         // get the number of bytes per page
         numBytesPerPage := 4096;
         parse vmstat_lines[0] with . "page size of" auto numBytesStr "bytes";
         numBytesStr = strip(numBytesStr);
         if (isuinteger(numBytesStr)) {
            numBytesPerPage = (int) numBytesStr;
         }

         parse vmstat_lines[1] with . " free:"       auto pagesFreeStr     ".";
         parse vmstat_lines[2] with . " active:"     auto pagesActiveStr   ".";
         parse vmstat_lines[3] with . " inactive:"   auto pagesInactiveStr ".";
         parse vmstat_lines[4] with . " wired down:" auto pagesWiredDownStr ".";
         if (pagesWiredDownStr=="") {
            // Speculate data is messing this up. Try next line
            parse vmstat_lines[5] with . " wired down:" pagesWiredDownStr ".";
         }

         pagesFreeStr = strip(pagesFreeStr);
         pagesActiveStr = strip(pagesActiveStr);
         pagesInactiveStr = strip(pagesInactiveStr);
         pagesWiredDownStr = strip(pagesWiredDownStr);

         // get the totals
         if (isuinteger(pagesFreeStr)) {
            TotalVirtual = AvailVirtual = (int) pagesFreeStr;
         }
         if (isuinteger(pagesActiveStr)) {
            TotalVirtual += (int) pagesActiveStr;
         }
         if (isuinteger(pagesInactiveStr)) {
            TotalVirtual += (int) pagesInactiveStr;
         }
         if (isuinteger(pagesWiredDownStr)) {
            TotalVirtual += (int) pagesWiredDownStr;
         }

         // adjust totals to block size
         AvailVirtual = AvailVirtual * (numBytesPerPage intdiv 1024);
         TotalVirtual = TotalVirtual * (numBytesPerPage intdiv 1024);

      } else {

         // scan for the line containing the field names, then get data
         _str vmstat_fields[];
         _str vmstat_data[];
         gotFree := false;
         foreach (auto line in vmstat_lines) {
            line = stranslate(line," ","\t");
            line = stranslate(line," "," #","r");
            line = strip(line);
            if (pos(" free ", line) > 0 || pos(" fre ", line) > 0) {
               gotFree = true;
               split(line, " ", vmstat_fields);
            }
            if (gotFree && isnumber(_first_char(line))) {
               split(line, " ", vmstat_data);
               break;
            }
         }

         // get the data from the columns for free and swap space
         for (i:=0; i<vmstat_fields._length(); i++) {
            if (i >= vmstat_data._length()) break;
            switch (vmstat_fields[i]) {
            case "free":
            case "fre":
               if (isuinteger(vmstat_data[i])) {
                  AvailVirtual = (long) vmstat_data[i];
                  TotalVirtual += AvailVirtual;
               }
               break;
            case "avm":
            case "buff": // Linux specific
               if (isuinteger(vmstat_data[i])) {
                  TotalVirtual += (long) vmstat_data[i];
               }
               break;
            case "swpd":
            case "swap":
               if (isuinteger(vmstat_data[i])) {
                  TotalVirtual += (long) vmstat_data[i];
               }
               break;
            case "cache": // Linux specific comes after 'buff'
               if (isuinteger(vmstat_data[i])) {
                  TotalVirtual += (long) vmstat_data[i];
               }
            }
         }

         // block size reported by AIX and HPUX is 4k, not 1k
         if (machine() == "RS6000" || machine() == "HP9000") {
            TotalVirtual *= 4;
            AvailVirtual *= 4;
         }
      }
   } else {

      index := find_index("ntGlobalMemoryStatus", PROC_TYPE|DLLCALL_TYPE);
      if (index_callable(index)) {
         long MemoryLoadPercent, TotalPhys, AvailPhys, TotalPageFile, AvailPageFile;
         ntGlobalMemoryStatus(MemoryLoadPercent,TotalPhys,AvailPhys,TotalPageFile,AvailPageFile,TotalVirtual,AvailVirtual);
         if (AvailPhys < AvailVirtual) AvailVirtual = AvailPhys;
         if (TotalPhys > TotalVirtual) TotalVirtual = TotalPhys;
      }

   }

   // success?
   if (TotalVirtual > 0) {
      return 0;
   }

   // did not find what we needed
   return -1;
}

long _getTotalKMemory() {
   if (_isWindows()) {
      long MemoryLoadPercent, TotalPhys, AvailPhys, TotalPageFile, AvailPageFile, TotalVirtual, AvailVirtual;
      ntGlobalMemoryStatus(MemoryLoadPercent,TotalPhys,AvailPhys,TotalPageFile,AvailPageFile,TotalVirtual,AvailVirtual);
      return TotalPhys;
   }
   long TotalVirtual=0, AvailVirtual=0;
   if (!_VirtualMemoryInfo(TotalVirtual, AvailVirtual)) {
      return TotalVirtual;
   }
   return 0;
}

#if 0
_str aboutPluginsInfo() {
   _str plugins[];
   _plgman_get_installed_plugins(plugins);
   result := "";
   for (i:=0;i<plugins._length();++i) {
      if (result=='') {
         result=maybe_quote_filename(plugins[i]);
      } else {
         strappend(result,',');
         strappend(result,maybe_quote_filename(plugins[i]));
      }
   }
   if (result!='') {
       result="<b>"get_message(VSRC_CAPTION_PLUGINS)":  </b>" :+ result;
   }
   return result;
}
#endif

_str aboutMemoryInfo(_str altCaption=null)
{
   line := "";
   memory := "";
   if (_isWindows()) {
      // Memory Load: %39
      // Physical Memory Usage: 413MB / 1048MB
      // Page File Usage: 339MB / 2521MB
      // Virtual Memory Usage: 107MB / 2097MB
      long MemoryLoadPercent, TotalPhys, AvailPhys, TotalPageFile, AvailPageFile, TotalVirtual, AvailVirtual;
      ntGlobalMemoryStatus(MemoryLoadPercent,TotalPhys,AvailPhys,TotalPageFile,AvailPageFile,TotalVirtual,AvailVirtual);
      memory :+= MemoryLoadPercent"%";
      memory :+= " "get_message(VSRC_CAPTION_MEMORY_LOAD);
      memory :+= ", ";
      memory :+= MBRound(TotalPhys-AvailPhys)"/"MBRound(TotalPhys);
      memory :+= " "get_message(VSRC_CAPTION_PHYSICAL_MEMORY_USAGE);
      memory :+= ", ";
      memory :+= MBRound(TotalPageFile-AvailPageFile)"/"MBRound(TotalPageFile);
      memory :+= " "get_message(VSRC_CAPTION_PAGE_FILE_USAGE);
      memory :+= ", ";
      memory :+= MBRound(TotalVirtual-AvailVirtual)"/"MBRound(TotalVirtual);
      memory :+= " "get_message(VSRC_CAPTION_VIRTUAL_MEMORY_USAGE);
   } else {
      long TotalVirtual=0, AvailVirtual=0;
      if (!_VirtualMemoryInfo(TotalVirtual, AvailVirtual)) {
         if(TotalVirtual > 0 && AvailVirtual > 0) {
             MemoryLoadPercent := 100 * (TotalVirtual - AvailVirtual) intdiv TotalVirtual;
             memory :+= MemoryLoadPercent"%";
             memory :+= " "get_message(VSRC_CAPTION_MEMORY_LOAD);
             memory :+= ", ";
             // report virtual memory statistics
             memory :+= MBRound(TotalVirtual-AvailVirtual)"/"MBRound(TotalVirtual);
             memory :+= " "get_message(VSRC_CAPTION_VIRTUAL_MEMORY_USAGE);
         }
      }
   }

   if (memory != "") {
      line=memory;
      if( altCaption!=null ) {
         line=altCaption:+memory;
      } else {
         line="<b>"get_message(VSRC_CAPTION_MEMORY)":  </b>" :+ memory;
      }
   }

   return line;
}

_str aboutShellInfo(_str altCaption=null)
{
   line := _get_process_shell(true);
   if (line != "") {
      if( altCaption!=null ) {
         line=altCaption:+line;
      } else {
         line="<b>"get_message(VSRC_CAPTION_SHELL_INFO)"</b>: "line;
      }
   }
   return line;
}

_str aboutScreenResolutionInfo(_str altCaption = null)
{
   _ScreenInfo list[];
   _GetAllScreens(list);

   line := "";
   for (i := 0; i < list._length(); i++) {
      if (line != "") {
         line :+= ", ";
      }
      if (_isWindows() && list[i].actual_width) {
         line :+= list[i].actual_width" x "list[i].actual_height' ('list[i].x' 'list[i].y' 'list[i].width' 'list[i].height')';
      } else {
         line :+= list[i].width" x "list[i].height;
      }
   }

   if( altCaption!=null ) {
      line=altCaption:+line;
   } else {
      line="<b>"get_message(VSRC_CAPTION_SCREEN_RESOLUTION)"</b>: "line;
   }
   return line;
}

_str aboutEclipseInfo(_str altCaption=null)
{
   line := "";

   eclipse_info := "";
   if( isEclipsePlugin() ) {
      eclipse_version := "";
      jdt_version := "";
      cdt_version := "";
      _eclipse_get_eclipse_version_string(eclipse_version);
      _eclipse_get_jdt_version_string(jdt_version);
      _eclipse_get_cdt_version_string(cdt_version);
      eclipse_info :+= "<b>Eclipse: </b> ":+eclipse_version;
      eclipse_info :+= "\n";
      eclipse_info :+= "<b>JDT: </b> ":+jdt_version;
      eclipse_info :+= "\n";
      eclipse_info :+= "<b>CDT: </b> ":+cdt_version;
   }

   line=eclipse_info;
   if( line!="" && altCaption!=null ) {
      line=altCaption:+line;
   }

   return line;
}

static _str aboutContactInfo()
{
   vsroot := _getSlickEditInstallPath();
   _maybe_append_filesep(vsroot);
   contact_file := vsroot:+"contact.html";
   contact_text := "";
   _GetFileContents(contact_file, contact_text);

   // remove notes about support and maintenance
   if (_isCommunityEdition()) {
      return stranslate(contact_text, "", "[<]li[>][^\n\r]*(Support|Maintenance)[^\n\r]*[<][/]li[>]", 'r');
   }
   return contact_text;
}

static const MINIHTML_INDENT_X= 100;

/**
 * Displays version of editor in message box.
 *
 * <p>
 * Note to OEMs: You can override the version()
 * command in order to display your own custom
 * About dialog box. Do NOT override the vsversion()
 * command, which is the default About dialog, because
 * you may need its information to debug problems.
 * </p>
 *
 * @categories Miscellaneous_Functions
 *
 */
_command void version() name_info(','VSARG2_EDITORCTL|VSARG2_READ_ONLY)
{
   vsversion();
}

//
// DO NOT ALLOW AN OEM TO OVERRIDE THIS FUNCTION!
//
// OEMs can override the version() command in order to replace
// our About dialog. Keep vsversion() safe because it may display
// more information than the OEM version displays, and will therefore
// be useful in a debugging situation.
_command void vsversion(_str options="", bool doModal = false) name_info(','VSARG2_EDITORCTL|VSARG2_READ_ONLY)
{
   //
   // Product name, version, copyright
   //

   // SlickEdit Version 10.0
   _str product = aboutProduct(true);
   product = "<b>"product"</b>";
   // Copyright 1988-2005 SlickEdit Inc.
   _str copyright = aboutCopyright();
   // Check for not-for-resale version
   not_for_resale := "";
   if( _NotForResale() ) {
      not_for_resale="<b>NOT FOR RESALE</b>";
   }

   //
   // License
   //

   // Serial number: WB0123456789
   _str serial = aboutSerial();

   // Licensed number of users: 5
   _str nofusers = aboutLicensedNofusers();

   // Licensed number of users: 5
   _str licenseExpiration = aboutLicensedExpiration();

   _str licenseFile = aboutLicensedFile();
   _str unlicensedFeatures = aboutUnlicensedFeatures();
   _str unlicensedLanguages = aboutUnlicensedLanguages();

   //_str licensedTo=aboutLicensedTo();

   // Licensed packages:
   //
   // PKGA
   //_str basePackNofusers = "";
   //_str licensedPacks = aboutInstalledPackages(basePackNofusers);
   //if( basePackNofusers!="" ) {
   //   // Append nofusers for the base package license to the serial number.
   //   // Although not part of the serial number, it makes it easier for a
   //   // user to report the number of users in a concurrent license if we
   //   // put it with the serial number.
   //   _str raw_serial = _getSerial();
   //   serial=stranslate(serial,raw_serial"-"basePackNofusers,raw_serial);
   //}

   //
   // Build date
   //

   _str build_date = aboutProductBuildDate();
   _str expiration = aboutExpirationDate();


   //
   // Emulation
   //

   // Emulation: CUA
   _str emulation = aboutEmulation();

   //
   // Project and language info
   //
   _str projInfo = aboutProject();
   _str langInfo = aboutLanguage();
   _str encInfo = aboutEncoding();

   //
   // Disk usage info
   //

   // Installation Directory: C:\slickedit\ (non-removable drive,FAT32)
   // Configuration Directory: c:\My Documents\joesmith\My SlickEdit Config\ (non-removable drive,FAT32)
   // Configuration Drive Usage: 28632MB / 32748MB
   _str diskinfo = aboutDiskInfo();


   //
   // Memory usage info
   //
   _str memoryinfo = aboutMemoryInfo();

   //
   // Shell used in build window
   //
   _str shellInfo = aboutShellInfo();

   //
   // Screen resolution info
   //
   _str screeninfo = aboutScreenResolutionInfo();

   // System info
   //

   // OS: Windows XP
   // Version: 5.01.2600  Service Pack 1
   //
   // --or--
   //
   // OS: SunOS
   // Kernel Level: 5.7
   // Build Version: Generic_106541-31
   // X Server Vendor: Hummingbird Communications Ltd.
   _str osinfo = aboutOsInfo();


   //
   // Eclipse plug-in only
   //

   // Eclipse: 3.0.0
   // JDT: 3.0.0
   // CDT: 2.0.0
   _str eclipse_info = aboutEclipseInfo();

   _str hotfix_info = aboutHotfixesList();

   // Put it all together
   text := "";
   text = text            :+
      product;
   if( not_for_resale != "" ) {
      text = text         :+
      "\n\n"              :+  // (blank line)
      not_for_resale;         // NOT FOR RESALE
   }
   if( serial != "" && (!isEclipsePlugin() || !_OEM())) {
      text = text         :+
         "\n";              // (blank line)
      text = text         :+
         "\n"             :+
         serial;         // Serial number: WB0123456789
   }
// if( licensedTo != "" ) {
//    text = text         :+
//       "\n"             :+
//       licensedTo;       // Licensed to: ...
// }
   if( nofusers != "" && (!isEclipsePlugin() || !_OEM())) {
      text = text         :+
         "\n"             :+
         nofusers;       // Number of licensed users: 5
   }
   if (licenseExpiration!="") {
      text = text         :+
         "\n"             :+
         licenseExpiration;     // License expiration: 15/1/2008
   }
   if (licenseFile!="") {
      text = text         :+
         "\n"             :+
         licenseFile;     // License file: c:\...\slickedit.lic
   }
   if (unlicensedFeatures!="") {
      text = text         :+
         "\n"             :+
         unlicensedFeatures;     // License file: c:\...\slickedit.lic
   }
   if (unlicensedLanguages!="") {
      text = text         :+
         "\n"             :+
         unlicensedLanguages;     // License file: c:\...\slickedit.lic
   }
   if( build_date != "" || expiration != "" || emulation != "" ) {
      text = text         :+
         "\n";              // (blank line)
      if( build_date != "" ) {
         text = text      :+
            "\n"          :+
            build_date;      // Build Date: June 30, 2004
      }
      if( expiration != "" ) {
         text = text      :+
            "\n"          :+
            expiration;      // Build Date: June 30, 2004
      }
      if( emulation != "" ) {
         text = text      :+
            "\n"          :+
            emulation;      // Emulation: CUA
      }
   }
   if( eclipse_info != "" ) {
      text = text         :+
      "\n\n"              :+
      eclipse_info;         // Eclipse: 3.0.0
                            // JDT: 3.0.0
                            // CDT: 2.0.0
   }
   if( osinfo != "" ) {
      text = text         :+
         "\n\n"           :+  // (blank line)
         osinfo;            // OS: Windows XP
                            // Version: 5.01.2600  Service Pack 1
   }
   if( memoryinfo != "" ) {
      text :+= "\n"  :+
               memoryinfo;  // Memory: 74% Load, 1554MB/2095MB Physical, 204MB/2097MB Virtual
   }

   if ( shellInfo != "" ) {
      text :+= "\n" :+
               shellInfo;
   }

   if ( screeninfo != "" ) {
      text :+= "\n" :+ screeninfo;
   }

   if (projInfo != "") {
      text :+= "\n\n"projInfo;
   }
   if (langInfo != "") {
      text :+= "\n"langInfo;
   }
   if (encInfo != "") {
      text :+= "\n"encInfo;
   }

   if( diskinfo != "" ) {
      text = text         :+
         "\n\n"           :+  // (blank line)
         diskinfo;          // Installation Directory: C:\vslick\ (non-removable drive,FAT32)
                            // Configuration Directory: c:\My Documents\joesmith\My SlickEdit Config\ (non-removable drive,FAT32)
                            // Configuration Drive Usage: 28632MB / 32748MB
                            // Spill File: C:\DOCUME~1\joesmith\LOCALS~1\Temp\$slk.1 (non-removable drive,FAT32)
                            // Spill File Directory Drive Usage: 31446MB / 36860MB
   }
   if( hotfix_info != "" ) {
      text = text         :+
         "\n\n"           :+  // (blank line)
         hotfix_info;
   }

   text :+= "\n\n";

   // Convert to HTML for the dialog
   text = stranslate(text,"<br>","\n");

   // Need to show Eclipse About dialog modal because it Slick-C stacks if you press the X
   // RGH - 5/15/2006
   // This dialog is now modal all the time (display the readme tab first if it's a first time startup)
   showCmdline := "";
   if( isEclipsePlugin() || doModal ) {
      showCmdline = "-modal _program_info_form";
   } else{
      showCmdline = "-xy _program_info_form";
   }
   show(showCmdline,text,"",-1,-1,options);
}

