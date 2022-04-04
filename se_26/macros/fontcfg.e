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
#include "diff.sh"
#include "license.sh"
#import "ccode.e"
#import "cfg.e"
#import "files.e"
#import "font.e"
#import "listbox.e"
#import "main.e"
#import "picture.e"
#import "recmacro.e"
#import "seltree.e"
#import "stdprocs.e"
#import "tbcontrols.e"
#import "tbprops.e"
#import "treeview.e"
#import "wfont.e"
#endregion

struct FONT {
   /**
    * Font family name.
    */
   _str font_name;
   /**
    * Font size (default is 10)
    */
   int font_size;
   /**
    * Font style flags (bitset of F_*)
    */
   int font_style;
   /**
    * Font character set (default "", meaning VSCHARSET_DEFAULT)
    */
   _str charset;
};

struct FONTCFGINFO {
   _str name;
   _str nameid;
   _str value;
   _str desc;
};

static FONTCFGINFO gfontcfglist[];

static FONTCFGINFO gfontcfglist_editor[]={
   {"SBCS/DBCS Source Windows",'sbcs_dbcs_source_window', CFG_SBCS_DBCS_SOURCE_WINDOW, 'Editor windows that are displaying non-Unicode content (Windows: plain text).'},
   {"SBCS/DBCS Minimap Windows",'sbcs_dbcs_minimap_window', CFG_SBCS_DBCS_MINIMAP_WINDOW, 'Minimap windows that are displaying non-Unicode content (Windows: plain text).'},
   {"Hex Source Windows",'hex_source_window', CFG_HEX_SOURCE_WINDOW, 'Editor windows that are being viewed in Hex mode (View > Hex).'},
   {"Unicode Source Windows",'unicode_source_window', CFG_UNICODE_SOURCE_WINDOW, 'Editor windows that are displaying Unicode content (for example, XML).'},
   {"Unicode Minimap Windows",'unicode_minimap_window', CFG_UNICODE_MINIMAP_WINDOW, 'Minimap windows that are displaying Unicode content (for example, XML).'},
   {"File Manager Windows",'file_manager_window',CFG_FILE_MANAGER_WINDOW, 'Controls the display of the SlickEdit File Manager (File > File Manager).'},
   {"Diff Editor SBCS/DBCS Source Windows",'diff_editor_window', CFG_DIFF_EDITOR_WINDOW, 'The editor windows used by DIFFzilla (Tools > File Difference) that are displaying non-Unicode content.'},
   {"Diff Editor Unicode Source Windows",'unicode_diff_editor_window', CFG_UNICODE_DIFF_EDITOR_WINDOW, 'The editor windows used by DIFFzilla (Tools > File Difference) that are displaying Unicode content.'},
};
static FONTCFGINFO gfontcfglist_application[]={
   {"Command Line",'cmdline',CFG_CMDLINE, 'The SlickEdit command line is displayed at the bottom of the application window and is accessed by pressing ESC for most emulatios.'},
   {"Status Line",'status',CFG_STATUS, 'Status messages are displayed at the bottom of the application window.'},
   {"Selection List",'selection_list',"sellist", 'The font used for selection lists, like the document language list (Document > Select Mode).'},
#if 1 /* __UNIX__ */
   {"Menu",'menu',CFG_MENU, 'Includes the main menu, as well as context menus.'},
#endif
   {"Dialog",'dialog', CFG_DIALOG, 'Controls the font used in SlickEdit dialogs and tool windows.'},
   {"Document Tabs",'document_tabs', CFG_DOCUMENT_TABS, 'The tabs used to easily switch between open documents.'},
};

static FONTCFGINFO gfontcfglist_html[]={
   {"Parameter Information",'function_help', CFG_FUNCTION_HELP, 'Controls the fonts used to display pop-ups with information about symbols and parameters.'},
   {"Parameter Information Fixed",'function_help_fixed',CFG_FUNCTION_HELP_FIXED, 'Used when SlickEdit needs to display a fixed-width font for parameter info, such as when displaying example code.'},
   {"HTML Proportional",'minihtml_proportional', CFG_MINIHTML_PROPORTIONAL, 'The default font used by HTML controls for proportional fonts. In particular, this affects the Version Control History dialog, the About SlickEdit dialog, and the Cool Features dialog.'},
   {"HTML Fixed",'minihtml_fixed', CFG_MINIHTML_FIXED, 'The default font used by HTML controls for fixed-space fonts.'},
};

struct FONTCFGSETTINGS {
   _str id;   // This is a string because of 'sellist'
   _str nameid;
   _str orig_info;
   _str info;
   double scaled_font_size;
};

static FONTCFGSETTINGS gfontsettings:[];

/**
 * Retrieves a hash table filled with all the font names 
 * availabe on this machine.  The key and value are both the 
 * font name.  However, the key is lowercase, while the value 
 * uses the casing that is used in the actual font name. 
 * 
 * @param fontTable        font name hash table 
 * @param realFontNames    real system font names 
 * @param fixedFontsOnly   only get fixed fonts 
 * @param sortedFontArray  (output) sorted font array
 */
static void getTableOfFonts(_str (&fontTable):[], 
                            _str (&realFontNames):[]=null, 
                            bool fixedFontsOnly=false,
                            _str (&fontArray)[]=null)
{
   // open up a temp view so we can put the font names in there
   tempView := 0;
   origView := _create_temp_view(tempView);

   // put the font names into the temp view
   _insert_font_list(fixedFontsOnly? 'F':'');

   // read the fonts
   line := '';
   top();
   while (true) {
      // add the next one to our list
      get_line(line);
      line = strip(line);
      real_name := line;
      fontArray :+= line;
      if (endsWith(line, ')')) {
         parse line with line " (" real_name ')' .;
      }
      line = strip(line);
      if (line != '') {
         fontTable:[lowcase(line)] = line;
         realFontNames:[lowcase(line)] = real_name;
      }

      // next, please
      if (down()) break;
   }

   // sort the array
   fontArray._sort('I');

   // get rid of the temp view
   _delete_temp_view(tempView);
   p_window_id = origView;
}

/** 
 * @return
 * Return the real font name for the given font name which
 * is a standard font, like "Default Fixed Font"
 */
_str _real_font_name(_str font_name)
{
   parse font_name with font_name ' (' auto real_font_name ')';
   if (real_font_name != "") {
      return real_font_name;
   }
   _str fontTable:[];
   _str realFontNames:[];
   getTableOfFonts(fontTable, realFontNames);
   real_font_name = font_name;
   if (realFontNames._indexin(lowcase(font_name))) {
      real_font_name = realFontNames:[lowcase(font_name)];
   }                        
   return real_font_name;
}

/**
 * @return 
 * Return {@code true} if the given font size is valid for the given font. 
 */
bool _is_valid_font_size(_str font_name, _str font_size, bool is_minimap_font=false)
{
   if (!isinteger(font_size)) return false;
   _str fontSizes[];
   parse font_name with font_name ' (' auto real_font_name ')';
   _mdi.getTableOfFontSizes(font_name, fontSizes, is_minimap_font);
   foreach (auto fs in fontSizes) {
      if (font_size == fs) return true;
   }
   return false;
}

/**
 * Retrieves a table of font sizes to use with the given font. 
 *  
 * @param font_name        name of font 
 * @param table            array of font sizes 
 * @param is_minimap_font  is this for a minimap control?
 */
static void getTableOfFontSizes(_str font_name, _str (&table)[], bool is_minimap_font=false)
{
   // open up a temp view so we can put the font names in there
   tempView := 0;
   origView := _create_temp_view(tempView);

   // put the font sizes into the temp view
   _insert_font_list('', font_name);

   // read the fonts
   bool have_font_size:[];
   line := '';
   top();
   while (true) {
      // add the next one to our list
      get_line(line);
      line = strip(line);
      if (line != '' && isinteger(line)) {
         table :+= line;
         have_font_size:[line] = true;
      }
      // next, please
      if (down()) break;
   }

   if (!_isscalable_font(font_name) || fontHasLimitedSizes(font_name)) {
      return;
   }

   if (is_minimap_font) {
      foreach (auto ls in MINIMAP_FONT_SIZE_LIST) {
         if (!have_font_size._indexin(ls)) {
            table :+= strip(ls);
            have_font_size:[ls] = true;
         }
      }
   } else {
      foreach (auto ls in FONT_SIZE_LIST) {
         if (!have_font_size._indexin(ls)) {
            table :+= strip(ls);
            have_font_size:[ls] = true;
         }
      }
   }

   // sort the array
   table._sort('n');

   // get rid of the temp view
   _delete_temp_view(tempView);
   p_window_id = origView;
}


#region Options Dialog Helper Functions

defeventtab _font_config_form;

static int CHANGING_ELEMENT_LIST(...) {
   if (arg()) _ctl_element_tree.p_user=arg(1);
   return _ctl_element_tree.p_user;
}

static _str CURRENT_FONT_ELEMENT(...) {
   if (arg()) ctl_element_desc.p_user=arg(1);
   return ctl_element_desc.p_user;
}

void _font_config_form_init_for_options()
{
   if (!_UTF8()) {
      ctlEnableBoldAndItalic.p_visible = false;
   }

   if (!ctlEnableBoldAndItalic.p_visible) {
      yDiff := ctlAntiAliasing.p_y - ctlEnableBoldAndItalic.p_y;
      ctlAntiAliasing.p_y -= yDiff;
      _sample_frame.p_y -= yDiff;
   }

   consolidateFontConfigList();
}

bool _font_config_form_is_modified()
{
   do {
      // check each font setting for changes
      changed := false;
      foreach (auto id => auto fInfo in gfontsettings) {
         if (fInfo.orig_info != fInfo.info) {
            changed = true;
            break;
         }
      }
      if (changed) break;

      if (_UTF8()) {
         if ( ctlEnableBoldAndItalic.p_value != (_default_option(VSOPTION_OPTIMIZE_UNICODE_FIXED_FONTS)?1:0) ) break;
      }

      if ( ctlAntiAliasing.p_value != (_default_option(VSOPTION_NO_ANTIALIAS)?0:1) ) break;

      return false;

   } while (false);

   return true;
}

bool _font_config_form_apply()
{
   already_prompted := false;
   already_prompted_status := 0;
   // Now do all the macro recording
   _macro('m',_macro('s'));
   foreach (auto font_setting in gfontsettings) {
      font_id := font_setting.id;
      alt_info:='';
      bool force_change=false;
      if (font_id==CFG_SBCS_DBCS_MINIMAP_WINDOW) {
         data:=gfontsettings:['SBCS/DBCS Source Windows'];
         alt_info=data.info;
         force_change= data.orig_info!=data.info;
      } else if (font_id==CFG_UNICODE_MINIMAP_WINDOW) {
         data:=gfontsettings:['Unicode Source Windows'];
         alt_info=data.info;
         force_change= data.orig_info!=data.info;
      }
      if (font_setting.orig_info != font_setting.info || force_change) {
         _FontInfoToFont(font_setting.info, auto font,alt_info);
         if( font_setting.id=='sellist' ) {
            _macro_call('_setFont',font.font_name,font.font_size,font.font_style);
            //_macro_append("def_qt_sellist_font="_quote(font_setting.info)";");
         } else {
            _macro_append("_default_font("font_setting.id","_quote(font_setting.info)");");
         }
      }
   }

   foreach ( font_setting in gfontsettings) {
      font_id := font_setting.id;
      nameid  := font_setting.nameid;
      result  := font_setting.info;
      orig_result := font_setting.orig_info;
      alt_info:='';
      bool force_change=false;
      if (font_id==CFG_SBCS_DBCS_MINIMAP_WINDOW) {
         data:=gfontsettings:['SBCS/DBCS Source Windows'];
         alt_info=data.info;
         force_change= data.orig_info!=data.info;
      } else if (font_id==CFG_UNICODE_MINIMAP_WINDOW) {
         data:=gfontsettings:['Unicode Source Windows'];
         alt_info=data.info;
         force_change= data.orig_info!=data.info;
      }
      if( result==orig_result && !force_change) continue;

      _FontInfoToFont(result,      auto font,alt_info);
      _FontInfoToFont(orig_result, auto orig_font,alt_info);

      if ( font.font_name  == orig_font.font_name  && 
           font.font_size  == orig_font.font_size  && 
           font.font_style == orig_font.font_style && 
           font.charset    == orig_font.charset && !force_change) {
         continue;
      }
      font_setting.orig_info = result;

      charset := isinteger(font.charset)? (int)font.charset : VSCHARSET_DEFAULT;
      _set_font_profile_property(font_id, font.font_name, font.font_size, font.font_style, charset);
      if (font_id=='sellist') {
         _setSelectionListFont(result);
         continue;
      }
      isEditorFontChange := font_id==CFG_SBCS_DBCS_SOURCE_WINDOW || font_id==CFG_HEX_SOURCE_WINDOW || font_id==CFG_UNICODE_SOURCE_WINDOW || font_id==CFG_FILE_MANAGER_WINDOW;
      isMinimapFontchange:= font_id==CFG_SBCS_DBCS_MINIMAP_WINDOW  || font_id==CFG_UNICODE_MINIMAP_WINDOW;
      if (isEditorFontChange || isMinimapFontchange) {
         _macro('m',_macro('s'));   //Had to add this to get it to work consistently
         _macro_call('setall_wfonts',font.font_name, font.font_size, font.font_style, font.charset, font_id);
         setall_wfonts(font.font_name, font.font_size, font.font_style, charset, (int)font_id);
         continue;
      }
      _default_font((int)font_id, result);

      font_setting.orig_info = font_setting.info;
      switch (font_id) {
      case CFG_MDICHILDICON:
      //case CFG_MDICHILDTITLE:
         if( result==orig_result ) continue;
         _message_box(get_message(VSRC_FC_CHILD_WINDOWS_NOT_UPDATED));
         break;
      case CFG_DIALOG:
         if (index_callable(find_index("tbReloadBitmaps", COMMAND_TYPE|PROC_TYPE))) {
            if (def_toolbar_pic_auto) tbReloadBitmaps("auto","",reloadSVGFromDisk:false);
         }
         if (index_callable(find_index("tbReloadTreeBitmaps", COMMAND_TYPE|PROC_TYPE))) {
            if (def_toolbar_tree_pic_auto) tbReloadTreeBitmaps("auto","",reloadSVGFromDisk:false);
         }
         if (index_callable(find_index("tbReloadTabBitmaps", COMMAND_TYPE|PROC_TYPE))) {
            if (def_toolbar_tab_pic_auto) tbReloadTabBitmaps("auto","",reloadSVGFromDisk:false);
         }
         _message_box(get_message(VSRC_FC_MUST_EXIT_AND_RESTART_DIALOG_FONT));
         continue;
      }

   }

   if (_UTF8() && ctlEnableBoldAndItalic.p_enabled) {
      if (ctlEnableBoldAndItalic.p_value!=(_default_option(VSOPTION_OPTIMIZE_UNICODE_FIXED_FONTS)?1:0)) {
         _default_option(VSOPTION_OPTIMIZE_UNICODE_FIXED_FONTS,ctlEnableBoldAndItalic.p_value);
      }
   }

   if ( ctlAntiAliasing.p_value != (_default_option(VSOPTION_NO_ANTIALIAS)?0:1) ) {
      _default_option(VSOPTION_NO_ANTIALIAS, (ctlAntiAliasing.p_value ? 0 : 1));
   }

   return true;
}

_str _font_config_form_build_export_summary(PropertySheetItem (&table)[])
{
   settings := '';
   typeless i;
   consolidateFontConfigList();
   nationalizeElementNames();
   foreach (auto fontcfginfo in gfontcfglist) {
      id := fontcfginfo.value;

      if (id == CFG_UNICODE_SOURCE_WINDOW && !_UTF8()) continue;
      if (!allow_element(id)) continue;
      if (id == CFG_STATUS && ((_default_option(VSOPTION_APIFLAGS) & VSAPIFLAG_CONFIGURABLE_STATUS_FONT) == 0)) continue;
      if (id == CFG_CMDLINE && ((_default_option(VSOPTION_APIFLAGS) & VSAPIFLAG_CONFIGURABLE_CMDLINE_FONT) == 0)) continue;
      if (id == CFG_DOCUMENT_TABS && ((_default_option(VSOPTION_APIFLAGS) & VSAPIFLAG_CONFIGURABLE_DOCUMENT_TABS_FONT) == 0)) continue;
      if ((id == CFG_FUNCTION_HELP || id == CFG_FUNCTION_HELP_FIXED) && !_haveContextTagging()) continue;

      info := _FontElementIdToInfo(id,false);
      _FontInfoToFont(info, auto font);

      info = font.font_name' size 'font.font_size;
      if (font.charset != "" && isinteger(font.charset)) {
         _maybe_append(info, ", ");
         info :+= _CharSet2Name((int)font.charset)' Script';
      }
      if (font.font_style != 0) {
         _maybe_append(info, ", ");
         info :+= _FontFlagsToDesc(font.font_style);
      }
      
      PropertySheetItem psi;
      psi.Caption = fontcfginfo.name;
      psi.Value = info;
      psi.ChangeEvents = (id == CFG_DIALOG) ? OCEF_DIALOG_FONT_RESTART : 0;
      
      table :+= psi;
   }

   PropertySheetItem psi;
   psi.Caption = 'Use fixed spacing for bold and italic fixed Unicode fonts';
   psi.Value = _default_option(VSOPTION_OPTIMIZE_UNICODE_FIXED_FONTS) ? 'True' : 'False';
   psi.ChangeEvents = 0;

   table[table._length()] = psi;

   psi.Caption = 'Use anti-aliasing';
   psi.Value = _default_option(VSOPTION_NO_ANTIALIAS) ? 'False' : 'True';
   psi.ChangeEvents = 0;

   table[table._length()] = psi;

   return '';
}

_str _font_config_form_import_summary(PropertySheetItem (&table)[])
{
   error := '';

   consolidateFontConfigList();
   nationalizeElementNames();

   // first go through and make a table of all the names and IDs
   typeless namesIds:[];
   foreach (auto fontcfginfo in gfontcfglist) {
      namesIds:[fontcfginfo.name] = fontcfginfo.value;
   }

   // get a table of our available fonts
   _str fontTable:[];
   getTableOfFonts(fontTable);
   
   PropertySheetItem psi;
   foreach (psi in table) {
      // the caption is the value...
      set_def_unicode_font_too := false;
      if ( psi.Caption=='Diff Editor Source Windows') {
         psi.Caption='Diff Editor SBCS/DBCS Source Windows';
         set_def_unicode_font_too=true;
      }
      if (namesIds._indexin(psi.Caption)) {
         id := namesIds:[psi.Caption];
         
         // now compile the info into something we can use!
         typeless font_name, font_size, charset, rest;
         if (substr(psi.Value,1,7)==' size ') {
            font_name='';
            parse psi.Value with 'size' font_size','rest;
         } else {
            parse psi.Value with font_name 'size' font_size','rest;
         }
         
         // make sure this font exists on this machine
         font_name = lowcase(strip(font_name));

         // this font is not font on this machine,
         // maybe the font name ends with [Adobe], and this platform
         // has that, but without the [Adobe] part (Helvetica, Courier)
         if (font_name!='' && !fontTable._indexin(font_name)) {
            parse font_name with auto simplified_font_name '[' .;
            simplified_font_name = strip(simplified_font_name);
            if (fontTable._indexin(simplified_font_name)) {
               font_name = simplified_font_name;
            }
         }

         // the font is still not found, maybe it's this is a default
         // option that we can exchange for the platform-non-specific default.
         if (font_name!='' && !fontTable._indexin(font_name)) {

            // if importing options that were exported on another platform,
            // the default fonts may not be available, so try to substitute
            // it for the default font type.
            _str prop_font_names[];
            prop_font_names :+= "lucida grande";
            prop_font_names :+= "dejavu sans";
            prop_font_names :+= "lucida";
            prop_font_names :+= "arial";
            prop_font_names :+= "bitstream vera sans";
            prop_font_names :+= "helvetica";
            prop_font_names :+= "helvetica [adobe]";
            prop_font_names :+= "calibri";
            prop_font_names :+= "times new roman";
            if (_array_find_item(prop_font_names, font_name) >= 0) {
               error :+= 'Warning: replacing font configuration for element 'psi.Caption' - missing font "'font_name'" with 'VSDEFAULT_DIALOG_FONT_NAME'.'OPTIONS_ERROR_DELIMITER;
               font_name = lowcase(VSDEFAULT_DIALOG_FONT_NAME);
            }
            // try the same logic for fixed fonts
            _str fixed_font_names[];
            fixed_font_names :+= "consolas";
            fixed_font_names :+= "menlo";
            fixed_font_names :+= "andale mono";
            fixed_font_names :+= "monaco";
            fixed_font_names :+= "dejavu sans mono";
            fixed_font_names :+= "bitstream vera sans mono";
            fixed_font_names :+= "courier";
            fixed_font_names :+= "courier [adobe]";
            fixed_font_names :+= "courier new";
            if (_array_find_item(fixed_font_names, font_name) >= 0) {
               error :+= 'Warning: replacing font configuration for element 'psi.Caption' - missing font "'font_name'" with 'VSDEFAULT_FIXED_FONT_NAME'.'OPTIONS_ERROR_DELIMITER;
               font_name = lowcase(VSDEFAULT_FIXED_FONT_NAME);
            }
         }

         // try it now.
         if (font_name=='' || fontTable._indexin(font_name)) {
            if (font_name!='') {
               // the key is all lowercase, but the value is the actual name
               font_name = fontTable:[font_name];
            }
   
            parse rest with charset 'Script' rest;
            if (charset != '') {
               charset = _CharSetName2Id(charset);
            }
   
            font_style := 0;
            if (pos('Bold', rest)) {
               font_style |= F_BOLD;
            }
            if (pos('Italic', rest)) {
               font_style |= F_ITALIC;
            }
            if (pos('Underline', rest)) {
               font_style |= F_UNDERLINE;
            }
            if (pos('Strikethrough', rest)) {
               font_style |= F_STRIKE_THRU;
            }
   
            font_size = strip(font_size);
            _setFont(id,font_name,font_size,font_style);
            if ( set_def_unicode_font_too ) {
               _setFont(CFG_UNICODE_DIFF_EDITOR_WINDOW,font_name,font_size,font_style);
            }
         } else {
            // this font does not exist here - sorry!
            error :+= 'Error setting font configuration for element 'psi.Caption' - 'font_name' does not exist on this machine.'OPTIONS_ERROR_DELIMITER;
         }
      } else {
         switch (psi.Caption) {
         case 'Use anti-aliasing':
            _default_option(VSOPTION_NO_ANTIALIAS, (psi.Value == 'True') ? 0 : 1);
            break;
         case 'Use fixed spacing for bold and italic fixed Unicode fonts':
            _default_option(VSOPTION_OPTIMIZE_UNICODE_FIXED_FONTS, (psi.Value == 'True') ? 1 : 0);
            break;
         default:
            error :+= 'Error setting font configuration for element 'psi.Caption'.'OPTIONS_ERROR_DELIMITER;
            break;
         }
      }
   }

   return error;
}

void _convert_default_fonts_to_profile() 
{
   foreach (auto fontcfginfo in gfontcfglist) {
      typeless cfg = fontcfginfo.value;
      if (isinteger(cfg)) {
         if (allow_element(cfg)) {
            typeless font_name,font_size,font_flags,charset;
            parse _default_font(cfg) with font_name','font_size','font_flags','charset',';
            _set_font_profile_property(cfg,font_name,font_size,font_flags,charset);
         }
      } else if(cfg=='sellist') {
         index:=find_index('def_qt_sellist_font',VAR_TYPE);
         if (index>0) {
            _setSelectionListFont(name_info(index));
         }
      }
   }
}

void _set_font_profile_property(typeless id, _str font_name, _str font_size, int font_style, int charset) {
   nameid := _FontElementIdToNameId(id);
   if (nameid!='' && 
       (font_name!='' || (id==CFG_SBCS_DBCS_MINIMAP_WINDOW || id==CFG_UNICODE_MINIMAP_WINDOW)) &&
        isinteger(font_size) && isinteger(font_style)) {
      handle:=_xmlcfg_create('',VSENCODING_UTF8);
      property_node:=_xmlcfg_add_property(handle,0,nameid);
      attrs_node:=property_node;
      _xmlcfg_set_attribute(handle,attrs_node,'font_name',font_name);
      _xmlcfg_set_attribute(handle,attrs_node,'sizex10',((int)font_size)*10);
      _xmlcfg_set_attribute(handle,attrs_node,'flags',"0x":+_dec2hex(font_style));
      _plugin_set_property_xml(VSCFGPACKAGE_MISC,VSCFGPROFILE_FONTS,VSCFGPROFILE_FONTS_VERSION,nameid,handle);
      _xmlcfg_close(handle);
   }
}

void _setFont(typeless id, _str font_name, _str font_size, int font_style, int charset=0)
{
   info := font_name','font_size','font_style','charset',';

   editorFont := id == CFG_SBCS_DBCS_SOURCE_WINDOW ||
      id == CFG_HEX_SOURCE_WINDOW ||
      id == CFG_UNICODE_SOURCE_WINDOW ||
      id == CFG_FILE_MANAGER_WINDOW ||
      id==CFG_SBCS_DBCS_MINIMAP_WINDOW  || id==CFG_UNICODE_MINIMAP_WINDOW;
   _set_font_profile_property(id,font_name,font_size,font_style,charset);
   if (editorFont) {
      _macro('m',_macro('s'));   //Had to add this to get it to work consistently
      _macro_call('setall_wfonts', font_name, font_size, font_style, charset, id);
      setall_wfonts(font_name, font_size, font_style, charset, id);
   } else if (id=='sellist') {
      _setSelectionListFont(info);
   } else {
      if (_default_font(id) != info) {
         _default_font(id, info);
      }
   }
}

definit()
{
   gfontcfglist._makeempty();
   consolidateFontConfigList();
}

static void consolidateFontConfigList()
{
   if (gfontcfglist._isempty()) {
      foreach (auto fontcfg in gfontcfglist_editor) {
         gfontcfglist :+= fontcfg;
      }
      foreach (fontcfg in gfontcfglist_html) {
         gfontcfglist :+= fontcfg;
      }
      foreach (fontcfg in gfontcfglist_application) {
         gfontcfglist :+= fontcfg;
      }
   }
}

static void nationalizeElementNames()
{
#if 0
   typeless i=0;
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_COMMAND_LINE);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_STATUS_LINE);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_SBCS_DBCS_SOURCE_WINDOWS);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_HEX_SOURCE_WINDOWS);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_UNICODE_SOURCE_WINDOWS);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_FILE_MANAGER_WINDOWS);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_DIFF_EDITOR_WINDOWS);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_UNICODE_DIFF_EDITOR_WINDOWS);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_PARAMETER_INFO);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_PARAMETER_INFO_FIXED);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_SELECTION_LIST);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_MENU);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_DIALOG);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_MINIHTML_PROPORTIONAL);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_MINIHTML_FIXED);
   gfontcfglist[i++].name=get_message(VSRC_FCF_ELEMENTS_DOCUMENT_TABS);
#endif
}

//definit()
//{
//   _dump_var(gfontcfglist, "_ctl_element_tree.on_create H"__LINE__": gfontcfglist");
//}

_ctl_element_tree.on_create()
{
   _macro('m',_macro('s'));

   max_button_height := _ctl_element_tree.p_height intdiv 2;
   _ctl_zoomin.resizeToolButton(max_button_height);
   _ctl_zoomout.resizeToolButton(max_button_height);
   _ctl_font_chooser.resizeToolButton(max_button_height);
   _ctl_zoomin.p_x  = _sample_frame.p_x_extent - _ctl_zoomin.p_width;
   _ctl_zoomout.p_x = _sample_frame.p_x_extent - _ctl_zoomin.p_width;
   _ctl_font_chooser.p_x = _sample_frame.p_x_extent - _ctl_zoomin.p_width;
   _ctl_zoomout.p_y = _ctl_zoomin.p_y_extent + _ctl_element_tree.p_y;
   _ctl_font_chooser.p_y = _ctl_zoomout.p_y_extent + _ctl_element_tree.p_y;
   _ctl_element_tree.p_width = _ctl_zoomout.p_x - 2*_ctl_element_tree.p_x;
   _ctl_element_tree.p_EditInPlace = true;

   // From the user feed back we are getting, a number of users want bold and italic for XML files.
   // This will give them that as long as the choose a fixed Unicode font.
   ctlEnableBoldAndItalic.p_value= (_default_option(VSOPTION_OPTIMIZE_UNICODE_FIXED_FONTS)?1:0);
   ctlAntiAliasing.p_value = (_default_option(VSOPTION_NO_ANTIALIAS)?0:1);

   // The following nationalizes the content of the Elements combo box.
   // Look up the language-specific strings.
   consolidateFontConfigList();
   nationalizeElementNames();

   // Disallow ON_CHANGE events to _ctl_element_list
   CHANGING_ELEMENT_LIST(0);
   FillInElementTree();

   // select the default value
   typeless defaultId=arg(3);
   if (defaultId == '') {
      // check the current file encoding
      enc := _GetDefaultEncoding();
      if (!_no_child_windows()) {
         enc = _mdi.p_child.p_encoding;
      }

      if (enc >= VSENCODING_UTF8 && enc <= VSENCODING_UTF32BE_WITH_SIGNATURE) {
         defaultId = CFG_UNICODE_SOURCE_WINDOW;
      } else {
         defaultId = CFG_SBCS_DBCS_SOURCE_WINDOW;
      }
   }
   defaultId = _FontElementIdToName(defaultId);
   index := _ctl_element_tree._TreeSearch(TREE_ROOT_INDEX, defaultId, 'PT');
   if (index > 0) {
      _ctl_element_tree._TreeSetCurIndex(index);
   } else {
      _ctl_element_tree._TreeTop();
   }

   // Save all the original element settings
   foreach (auto fontcfginfo in gfontcfglist) {
      name := fontcfginfo.name;
      id   := fontcfginfo.value;
      //id=ghashtab:[name];
      gfontsettings:[name].id        = id;
      gfontsettings:[name].nameid    = fontcfginfo.nameid;
      gfontsettings:[name].info      = _FontElementIdToInfo(id);
      gfontsettings:[name].orig_info = gfontsettings:[name].info;
      parse gfontsettings:[name].info with . ',' auto font_size ',' .;
      gfontsettings:[name].scaled_font_size = isinteger(font_size)? (int)font_size : 10;
   }

   // Re-allow ON_CHANGE events to _ctl_element_list
   CHANGING_ELEMENT_LIST(1);

   // make sure something is selected
   index = _ctl_element_tree._TreeCurIndex();
   _ctl_element_tree.call_event(CHANGE_SELECTED, index, _ctl_element_tree,ON_CHANGE,"W");
}

static void FillInElementCategory(_str categoryName, FONTCFGINFO (&fontcfglist)[])
{
   // get a table of our available fonts
   getTableOfFonts(auto fontTable, auto realFontNames, fixedFontsOnly:false, auto fontArray);
   getTableOfFonts(auto fixedFontTable, null, fixedFontsOnly:true, auto fixedFontArray);

   category_node := _ctl_element_tree._TreeAddItem(TREE_ROOT_INDEX, categoryName, TREE_ADD_AS_CHILD, 0, 0, TREE_NODE_EXPANDED, TREENODE_BOLD);
   foreach (auto fontcfginfo in fontcfglist) {
      name  := fontcfginfo.name;
      value := fontcfginfo.value;
      if (allow_element(value)) {
         font_info := _FontElementIdToInfo(value);
         _FontInfoToFont(font_info, auto font);
         if (realFontNames._indexin(lowcase(font.font_name)) && !strieq(realFontNames:[lowcase(font.font_name)],font.font_name)) {
            font.font_name = font.font_name' (':+ realFontNames:[lowcase(font.font_name)]')';
         }
         caption := name "\t" font.font_name "\t" font.font_size "\t" _FontFlagsToDesc(font.font_style);
         index := 0;
         if (value==CFG_STATUS) {
            if ((_default_option(VSOPTION_APIFLAGS) & VSAPIFLAG_CONFIGURABLE_STATUS_FONT)) {
               index = _ctl_element_tree._TreeAddItem(category_node, caption, TREE_ADD_AS_CHILD, 0, 0, TREE_NODE_LEAF);
            }
         } else if (value==CFG_CMDLINE) {
            if ((_default_option(VSOPTION_APIFLAGS) & VSAPIFLAG_CONFIGURABLE_CMDLINE_FONT)) {
               index = _ctl_element_tree._TreeAddItem(category_node, caption, TREE_ADD_AS_CHILD, 0, 0, TREE_NODE_LEAF);
            }
         } else if (value==CFG_DOCUMENT_TABS) {
            if ((_default_option(VSOPTION_APIFLAGS) & VSAPIFLAG_CONFIGURABLE_DOCUMENT_TABS_FONT)) {
               index = _ctl_element_tree._TreeAddItem(category_node, caption, TREE_ADD_AS_CHILD, 0, 0, TREE_NODE_LEAF);
            }
         } else {
            index = _ctl_element_tree._TreeAddItem(category_node, caption, TREE_ADD_AS_CHILD, 0, 0, TREE_NODE_LEAF);
         }
         if (index > 0) {
            _ctl_element_tree._TreeSetComboDataCol(1, fontArray, PSCBO_NOEDIT);
            _ctl_element_tree._TreeSetNodeEditStyle(index, 1, TREE_EDIT_COMBOBOX);

            is_minimap_font := (value == CFG_UNICODE_MINIMAP_WINDOW || value == CFG_SBCS_DBCS_MINIMAP_WINDOW);
            _ctl_element_tree.getTableOfFontSizes(font.font_name, auto fontSizeArray, is_minimap_font);
            _ctl_element_tree._TreeSetComboDataCol(2, fontSizeArray, PSCBO_EDIT);
            _ctl_element_tree._TreeSetNodeEditStyle(index, 2, TREE_EDIT_EDITABLE_COMBOBOX);
         }
      }
   }
}

static void FillInElementTree()
{
   size_width := _ctl_element_tree._text_width("99999999");
   style_width := max(_ctl_element_tree._text_width(" Bold "),
                      _ctl_element_tree._text_width(" Italic ")/*,
                      _ctl_element_tree._text_width(" Underline "),
                      _ctl_element_tree._text_width(" Strikethrough ")*/);
   scroll_width := _ctl_element_tree._TreeGetVScrollBarWidth();
   border_width := _ctl_element_tree.p_x;
   width := _ctl_element_tree.p_width - size_width - scroll_width - border_width - style_width-1000;
   _ctl_element_tree._TreeSetColButtonInfo(0, width intdiv 2, -1, -1, "Element");
   _ctl_element_tree._TreeSetColButtonInfo(1, width intdiv 2, -1, -1, "Font Name");
   _ctl_element_tree._TreeSetColButtonInfo(2, size_width,  TREE_BUTTON_AL_RIGHT|TREE_BUTTON_FIXED_WIDTH, -1, 'Size');
   _ctl_element_tree._TreeSetColButtonInfo(3, style_width, TREE_BUTTON_FIXED_WIDTH, -1, 'Style');
   _ctl_element_tree._TreeSetColEditStyle(1, TREE_EDIT_COMBOBOX);
   _ctl_element_tree._TreeSetColEditStyle(2, TREE_EDIT_EDITABLE_COMBOBOX);

   FillInElementCategory("Editor Windows", gfontcfglist_editor);
   FillInElementCategory("HTML Controls", gfontcfglist_html);
   FillInElementCategory("Application", gfontcfglist_application);
   //_ctl_element_tree._TreeSizeColumnToContents(0);
   //_ctl_element_tree._TreeSizeColumnToContents(1);
   //_ctl_element_tree._TreeSizeColumnToContents(3);
}

// update the tree caption for the given font element
static void updateFontElementCaption(_str element)
{
}

int _ctl_element_tree.on_change(int reason, int index, int col=0, _str &text="", int combobox_wid=0)
{
   // root node or tree is being set up?
   if (index <= 0 || !CHANGING_ELEMENT_LIST()) {
      return 0;
   }

   // category node?
   if (_TreeGetDepth(index) <= 1) {
      ctl_element_desc.p_caption = "Category selected. Use the zoom in/out buttons and font selector button to modify the items in this category.";
      return 0;
   }

   // more than one item selected?
   if (_TreeGetNumSelectedItems() > 1) {
      ctl_element_desc.p_caption = "Multiple items selected.  Use the zoom in/out buttons and font selector button to modify the selected items.";
      return -1;
   }

   element := strip(_TreeGetCaption(index, 0));
   if (!gfontsettings._indexin(element)) {
      return -1;
   }
   fontsettings := gfontsettings:[element];
   font_info := fontsettings.info;
   font_id := fontsettings.id;
   parse font_info with auto font_name ',' auto font_size ',' .;

   //("_ctl_element_tree.on_change H"__LINE__": element="element);
   //say("_ctl_element_tree.on_change H"__LINE__": reason="reason" index="index);

   switch (reason) {
   case CHANGE_SELECTED:
      // did the old one just get selected again?
      orig_element := CURRENT_FONT_ELEMENT();
      if (element == orig_element) {
         return 0;
      }

      // update the current font name
      CURRENT_FONT_ELEMENT(element);

      // show the font and size
      showFontForElement(element);

      // update options help
      ctl_element_desc.p_caption = _FontElementIdToDesc(font_id);
      break;

   case CHANGE_EDIT_QUERY:
      // do not allow edit-in-place for category nodes
      if (_TreeGetDepth(index) <= 1) {
         return -1;
      }
      break;

   case CHANGE_EDIT_PROPERTY:
      if (col != 1 && col != 2) {
         return -1;
      }
      return TREE_EDIT_COLUMN_BIT|col;

   case CHANGE_EDIT_OPEN:
      if (col != 1 && col != 2) {
         return -1;
      }
      break;

   case CHANGE_EDIT_OPEN_COMPLETE:
      if (combobox_wid <= 0) {
         return -1;
      }
      combobox_wid._lbclear();

      if (col == 1 /* font name */) {

         // show fixed fonts?
         show_fixedfonts := false;
         switch (font_id) {
         case CFG_SBCS_DBCS_SOURCE_WINDOW:
         case CFG_SBCS_DBCS_MINIMAP_WINDOW:
         case CFG_HEX_SOURCE_WINDOW:
         case CFG_UNICODE_SOURCE_WINDOW:
         case CFG_UNICODE_MINIMAP_WINDOW:
         case CFG_FILE_MANAGER_WINDOW:
         case CFG_DIFF_EDITOR_WINDOW:
         case CFG_UNICODE_DIFF_EDITOR_WINDOW:
         case CFG_FUNCTION_HELP_FIXED:
         case CFG_MINIHTML_FIXED:
            show_fixedfonts = true;
            break;
         }
         combobox_wid._insert_font_list(show_fixedfonts? 'F':'');
         getTableOfFonts(auto fontTable, auto realFontNames, fixedFontsOnly:false, auto fontArray);
         if (realFontNames._indexin(lowcase(font_name))) {
            font_name = font_name' (':+ realFontNames:[lowcase(font_name)]')';
         }
         combobox_wid._cbset_text(font_name);

      } else if (col == 2 /* font size */) {

         // show minimap sizes
         show_minimap_sizes := false;
         switch (font_id) {
         case CFG_SBCS_DBCS_MINIMAP_WINDOW:
         case CFG_UNICODE_MINIMAP_WINDOW:
            show_minimap_sizes = true;
            break;
         }
         getTableOfFontSizes(font_name, auto fontSizetable, show_minimap_sizes);
         combobox_wid._lbadd_item_list(fontSizetable);
         combobox_wid._cbset_text(font_size);

      } else {
         return -1;
      }
      break;

   case CHANGE_EDIT_CLOSE:
      if (text=="") {
         return -1;
      }

      if (col == 1 /* font name */) {
         parse text with font_name ' (';
         _FontInfoToFont(font_info, auto font);
         //_TreeSetCaption(index, real_font_name, 1);
         //text = real_font_name;
         font.font_name = font_name;
         gfontsettings:[element].info = _FontToFontInfo(font);

      } else if (col == 2 /* font size */) {
         if (!isnumber(text)) {
            return -1;
         }
         new_size := (int)text;
         if (new_size <= 0 || new_size >= 100) {
            return -1;
         }

         _FontInfoToFont(font_info, auto font);
         font.font_size = new_size;
         gfontsettings:[element].info = _FontToFontInfo(font);
         gfontsettings:[element].scaled_font_size = new_size;

      } else {
         return -1;
      }

      // show the font and size
      showFontForElement(element);
      break;

   case CHANGE_LEAF_ENTER:
      chooseFont(index);
      break;
   }
   return 0;
}

void _font_config_form.on_resize()
{
   xpad := _ctl_element_tree.p_x;
   ypad := _ctl_element_tree.p_y;

   widthDiff  := p_width  - (_sample_frame.p_x_extent + xpad);
   heightDiff := p_height - (ctlAntiAliasing.p_y_extent + ypad);

   if (widthDiff) {
      // put half of this space into the element list and half into the font list
      _ctl_element_tree.p_width += widthDiff;
      _ctl_zoomin.p_x += widthDiff;
      _ctl_zoomout.p_x += widthDiff;
      _ctl_font_chooser.p_x += widthDiff;
      _ctl_element_desc_frame.p_width += widthDiff;
      ctl_element_desc.p_width += widthDiff;
      _sample_frame.p_width += widthDiff;
      picture1.p_width += widthDiff;
      _sample_text.p_width += widthDiff;
   }

   if (heightDiff) {
      oneThirdHeightDiff := 0;//heightDiff intdiv 3;
      twoThirdHeightDiff := heightDiff;//2*oneThirdHeightDiff;
      _ctl_element_tree.p_height += twoThirdHeightDiff;
      _ctl_element_desc_frame.p_y += twoThirdHeightDiff;
      _sample_frame.p_y += oneThirdHeightDiff;
      ctlEnableBoldAndItalic.p_y += heightDiff;
      ctlAntiAliasing.p_y        += heightDiff;
   }

   _sample_frame.p_y = _ctl_element_desc_frame.p_y_extent + ypad;
   ctlEnableBoldAndItalic.p_y = _sample_frame.p_y_extent + 120;
   ctlAntiAliasing.p_y        = ctlEnableBoldAndItalic.p_y + 300;

}

static void updateFontSizeForNode(int index, int direction, bool usePercent=true)
{
   tree_wid := p_window_id;
   element := strip(_TreeGetCaption(index, 0));
   if (!gfontsettings._indexin(element)) {
      return;
   }
   fontsettings := gfontsettings:[element];
   font_info := fontsettings.info;
   _FontInfoToFont(font_info, auto font);
   //say("updateFontSizeForNode H"__LINE__": element="element);

   _str fontTable:[];
   _str realFontNames:[];
   _ctl_element_tree.getTableOfFonts(fontTable, realFontNames);
   real_font_name := font.font_name;
   if (realFontNames._indexin(lowcase(font.font_name))) {
      real_font_name = realFontNames:[lowcase(font.font_name)];
   }

   font_id := gfontsettings:[element].id;
   is_minimap_font := (font_id == CFG_UNICODE_MINIMAP_WINDOW || font_id == CFG_SBCS_DBCS_MINIMAP_WINDOW);

   tree_wid.getTableOfFontSizes(real_font_name, auto font_sizes, is_minimap_font);

   // looking for next smaller or next larger font in table?
   closest_i := -1;
   closest_size := font.font_size;
   if (!usePercent) {
      foreach (auto i => auto str_size in font_sizes) {
         size := (int)str_size;
         if (abs(size-font.font_size) <= abs(closest_size-font.font_size)) {
            closest_size = size;
            closest_i = i;
         }
      }
      if (closest_i >= 0) {
         while (direction < 0 && closest_i > 0 && closest_size >= font.font_size) {
            closest_size = (int)font_sizes[--closest_i];
         }
         while (direction > 0 && closest_i+1 < font_sizes._length() && closest_size <= font.font_size) {
            closest_size = (int)font_sizes[++closest_i];
         }
      }
   }

   // try percent modification
   if (closest_size == font.font_size) {
      percent := (direction < 0)? 90 : 110;
      fontsettings.scaled_font_size *= percent;
      fontsettings.scaled_font_size /= 100;
      if (fontsettings.scaled_font_size < font_sizes[0]) {
         fontsettings.scaled_font_size = (int)font_sizes[0];
      } else if (fontsettings.scaled_font_size > font_sizes[font_sizes._length()-1]) {
         fontsettings.scaled_font_size = (int)font_sizes[font_sizes._length()-1];
      }
      gfontsettings:[element].scaled_font_size = fontsettings.scaled_font_size;
      foreach (auto i => auto str_size in font_sizes) {
         size := (int)str_size;
         if (abs(size-fontsettings.scaled_font_size) <= abs(closest_size-fontsettings.scaled_font_size)) {
            closest_size = size;
            closest_i = i;
         }
      }
      if (closest_i >= 0) {
         while (direction < 0 && closest_i > 0 && closest_size > font.font_size) {
            closest_size = (int)font_sizes[--closest_i];
         }
         while (direction > 0 && closest_i+1 < font_sizes._length() && closest_size < font.font_size) {
            closest_size = (int)font_sizes[++closest_i];
         }
      }
   }

   // last ditch effort, scale to the nearest percent above
   if (closest_size == font.font_size && !usePercent &&
       _isscalable_font(font.font_name) && 
       !fontHasLimitedSizes(font.font_name)) {
      closest_size = (int)round(fontsettings.scaled_font_size, 0);
      while (direction > 0 && closest_size <= font.font_size) {
         closest_size++;
      }
      while (direction < 0 && closest_size > 1 && closest_size >= font.font_size) {
         closest_size--;
      }
   }

   // is this font size within reason?
   if (closest_size <= 0) closest_size = 1;
   if (closest_size > 99) closest_size = 100;

   //say("updateFontSizeForNode H"__LINE__": closest_size="closest_size);
   if (closest_size != font.font_size) {
      if (real_font_name != font.font_name) {
         font.font_name = real_font_name;
         _TreeSetCaption(index, real_font_name, 1);
      }
      _TreeSetCaption(index, closest_size, 2);
      font.font_size = closest_size;
      gfontsettings:[element].info = _FontToFontInfo(font);
      gfontsettings:[element].scaled_font_size = closest_size;
   }
}

static void updateFontSizeForSelectedNodes(int direction)
{
   if (_TreeGetNumSelectedItems() <= 1) {
      // no multi-select
      index := _TreeCurIndex();
      if (index <= 0) return;
      if (_TreeGetDepth(index) == 1) {
         index = _TreeGetFirstChildIndex(index);
         while (index > 0) {
            updateFontSizeForNode(index, direction);
            index = _TreeGetNextSiblingIndex(index);
         }
      } else {
         updateFontSizeForNode(index, direction, usePercent:false);
      }

   } else {
      // multiple nodes selected
      info  := 0;
      index := _TreeGetNextSelectedIndex(ff:1, info);
      while (index > 0) {
         if (_TreeGetDepth(index) > 1) {
            updateFontSizeForNode(index, direction);
         }
         index = _TreeGetNextSelectedIndex(ff:0, info);
      }
   }

   // update the "current" node
   index := _TreeCurIndex();
   element := strip(_TreeGetCaption(index, 0));
   if (gfontsettings._indexin(element)) {
      showFontForElement(element);
   }
}

void _ctl_zoomin.lbutton_up()
{
   _ctl_element_tree.updateFontSizeForSelectedNodes(1);
}
void _ctl_zoomout.lbutton_up()
{
   _ctl_element_tree.updateFontSizeForSelectedNodes(-1);
}

static void updateFontInfoForNode(int index, 
                                  _str font_name, _str real_font_name,
                                  int  font_size, int font_flags)
{
   tree_wid := p_window_id;
   element := strip(_TreeGetCaption(index, 0));
   if (!gfontsettings._indexin(element)) {
      return;
   }
   fontsettings := gfontsettings:[element];
   font_info := fontsettings.info;
   _FontInfoToFont(font_info, auto font);
   //say("updateFontSizeForNode H"__LINE__": element="element);

   if (font_name != "") {
      font.font_name = font_name;
      _TreeSetCaption(index, real_font_name, 1);
   }
   if (font_size > 0) {
      font.font_size = font_size;
      _TreeSetCaption(index, font_size, 2);
   }
   font.font_style = font_flags;
   desc := _FontFlagsToDesc(font_flags);
   _TreeSetCaption(index, desc, 3);

   gfontsettings:[element].info = _FontToFontInfo(font);
}
static void updateFontInfoForSelectedNodes(_str font_name, _str real_font_name,
                                           int  font_size, int font_flags)
{
   if (_TreeGetNumSelectedItems() <= 1) {
      // no multi-select
      index := _TreeCurIndex();
      if (index <= 0) return;
      if (_TreeGetDepth(index) == 1) {
         index = _TreeGetFirstChildIndex(index);
         while (index > 0) {
            updateFontInfoForNode(index, font_name, real_font_name, font_size, font_flags);
            index = _TreeGetNextSiblingIndex(index);
         }
      } else {
         updateFontInfoForNode(index, font_name, real_font_name, font_size, font_flags);
      }

   } else {
      // multiple nodes selected
      info  := 0;
      index := _TreeGetNextSelectedIndex(ff:1, info);
      while (index > 0) {
         if (_TreeGetDepth(index) > 1) {
            updateFontInfoForNode(index, font_name, real_font_name, font_size, font_flags);
         }
         index = _TreeGetNextSelectedIndex(ff:0, info);
      }
   }

   // update the "current" node
   index := _TreeCurIndex();
   element := strip(_TreeGetCaption(index, 0));
   if (gfontsettings._indexin(element)) {
      showFontForElement(element);
   }
}

static void chooseFont(int clicked_index=0)
{
   tree_wid := _ctl_element_tree.p_window_id;
   index := clicked_index;
   if (index <= 0) {
      index = _ctl_element_tree._TreeCurIndex();
   }
   element := strip(_ctl_element_tree._TreeGetCaption(index, 0));
   if (!gfontsettings._indexin(element)) {
      return;
   }
   fontsettings := gfontsettings:[element];
   font_info := fontsettings.info;
   font_id   := fontsettings.id;

   // show fixed fonts?
   show_fixedfonts := false;
   switch (font_id) {
   case CFG_SBCS_DBCS_SOURCE_WINDOW:
   case CFG_SBCS_DBCS_MINIMAP_WINDOW:
   case CFG_HEX_SOURCE_WINDOW:
   case CFG_UNICODE_SOURCE_WINDOW:
   case CFG_UNICODE_MINIMAP_WINDOW:
   case CFG_FILE_MANAGER_WINDOW:
   case CFG_DIFF_EDITOR_WINDOW:
   case CFG_UNICODE_DIFF_EDITOR_WINDOW:
   case CFG_FUNCTION_HELP_FIXED:
   case CFG_MINIHTML_FIXED:
      show_fixedfonts = true;
      break;
   }

   fixed_font_option := (show_fixedfonts? 'F' : '');
   font_info = show('-modal _font_form', fixed_font_option, font_info);
   if (font_info == '') {
      return;
   }

   _FontInfoToFont(font_info, auto font);

   _str fontTable:[];
   _str realFontNames:[];
   _ctl_element_tree.getTableOfFonts(fontTable, realFontNames);
   real_font_name := font.font_name;
   if (realFontNames._indexin(lowcase(font.font_name))) {
      real_font_name = realFontNames:[lowcase(font.font_name)];
   }

   if (clicked_index > 0) {
      _ctl_element_tree.updateFontInfoForNode(index, 
                                              font.font_name, real_font_name, 
                                              font.font_size, font.font_style);
   } else {
      _ctl_element_tree.updateFontInfoForSelectedNodes(font.font_name, real_font_name, 
                                                       font.font_size, font.font_style);
   }
}

void _ctl_font_chooser.lbutton_up()
{
   chooseFont();
}

void _ctl_ok.lbutton_up()
{
   if (_font_config_form_apply()) {
      p_active_form._delete_window(0);
   }
}

static void showFontForElement(_str element)
{
   // we may need to show or disable fixed fonts, depending on our element
   disable_fixedfonts := false;
   show_fixedfonts    := false;

   // get the font info, based on the element name
   font_options := "";
   if (!gfontsettings._indexin(element)) {
      return;
   }
   font_id   := gfontsettings:[element].id;
   font_info := gfontsettings:[element].info;
   if (font_info == null) {
      return;
   }

   // show fixed fonts?
   if( font_id==CFG_SBCS_DBCS_SOURCE_WINDOW || 
       font_id==CFG_SBCS_DBCS_MINIMAP_WINDOW || 
       font_id==CFG_HEX_SOURCE_WINDOW || 
       font_id==CFG_UNICODE_SOURCE_WINDOW || 
       font_id==CFG_UNICODE_MINIMAP_WINDOW || 
       font_id==CFG_FILE_MANAGER_WINDOW || 
       font_id==CFG_DIFF_EDITOR_WINDOW || 
       font_id==CFG_UNICODE_DIFF_EDITOR_WINDOW || 
       font_id==CFG_FUNCTION_HELP_FIXED ||
       font_id==CFG_MINIHTML_FIXED) {
      show_fixedfonts = true;
   }

   // Disable fixed fonts option?
   if( disable_fixedfonts ) {
      ctlEnableBoldAndItalic.p_enabled = false;
   }

   // Show only fixed fonts?
   if( show_fixedfonts ) {
      font_options :+= 'f';
      ctlEnableBoldAndItalic.p_enabled = true;
   } else {
      ctlEnableBoldAndItalic.p_enabled = false;
   }

   _FontInfoToFont(font_info, auto font);

   if (font_id==CFG_SBCS_DBCS_MINIMAP_WINDOW || font_id==CFG_UNICODE_MINIMAP_WINDOW) {
      FONTCFGINFO cfg;
      foreach (auto i => cfg in gfontcfglist) {
         if (font_id==CFG_SBCS_DBCS_MINIMAP_WINDOW && cfg.value==CFG_SBCS_DBCS_SOURCE_WINDOW) {
            break;
         } else if (font_id==CFG_UNICODE_MINIMAP_WINDOW && cfg.value==CFG_UNICODE_SOURCE_WINDOW) {
            break;
         }
      }
      if (i<gfontcfglist._length()) {
         typeless font_name2;
         parse gfontsettings:[gfontcfglist[i].name].info with font_name2 ',';
         /*if (font_name=='') {
            font_name=font_name2;
         } */
         //typeless temp_font_size=font_size;
         //_xlat_font(font_name2,temp_font_size);
         _sample_text.p_user=font_name2;
      } else {
         _sample_text.p_user='';
      }
      _sample_text.p_font_scalable=true;
   } else {
      _sample_text.p_user='';
      _sample_text.p_font_scalable=false;
   }

   _sample_text.p_font_name = font.font_name;
   _sample_text.p_font_size = font.font_size;
   _sample_text.p_font_bold        = (font.font_style & F_BOLD       ) != 0;
   _sample_text.p_font_italic      = (font.font_style & F_ITALIC     ) != 0;
   _sample_text.p_font_underline   = (font.font_style & F_UNDERLINE  ) != 0;
   _sample_text.p_font_strike_thru = (font.font_style & F_STRIKE_THRU) != 0;

   // set the charset
   charset := isinteger(font.charset)? (int)font.charset : VSCHARSET_DEFAULT;
   _sample_text.p_font_charset = charset;
}

/**
 * Some fonts have only one size available.
 */
bool fontHasLimitedSizes(_str fontName)
{
   switch (fontName) {
      case VSDEFAULT_MENU_FONT_NAME:
      case VSDEFAULT_MDICHILD_FONT_NAME:
         return true;
         break;
      case VSOEM_FIXED_FONT_NAME:
      case VSANSI_VAR_FONT_NAME:
      case VSANSI_FIXED_FONT_NAME:
      case VSDEFAULT_UNICODE_FONT_NAME:
      case VSDEFAULT_FIXED_FONT_NAME:
      case VSDEFAULT_DIALOG_FONT_NAME:
      case VSDEFAULT_COMMAND_LINE_FONT_NAME:
         return _isUnix();
   }

   return false;
}

void setall_wfonts(_str font_name, _str font_size,int font_flags,int charset=VSCHARSET_DEFAULT,int font_id=CFG_SBCS_DBCS_SOURCE_WINDOW)
{
   _change_all_wfonts(font_name,font_size,font_flags,charset,font_id);
}
static bool allow_element(_str value) {
   if (value==CFG_MDICHILDTITLE || value==CFG_MENU) {
      return (_isUnix() && !_isMac()) && !_OEM();
   }

   if ((value == CFG_FUNCTION_HELP || value == CFG_FUNCTION_HELP_FIXED) && !_haveContextTagging()) return false;

   return true;
}

_str _FontElementIdToInfo(_str id,bool resolve_font_name=true)
{
   if( id=='sellist' ) {
      info := _getSelectionListFont();
      parse info with auto font_name ',' auto font_size ',' auto font_style ',' auto charset',';
      if (charset=='') {
         charset=VSCHARSET_DEFAULT;
         info=font_name ',' font_size ',' font_style ',' charset',';
      }
      return info;
   }
   if (isinteger(id)) {
      info := _default_font((int)id);
      alt_id := 0;
      if (id==CFG_UNICODE_MINIMAP_WINDOW)   {
         alt_id = CFG_UNICODE_SOURCE_WINDOW;
      } else if (id==CFG_SBCS_DBCS_MINIMAP_WINDOW) {
         alt_id = CFG_SBCS_DBCS_SOURCE_WINDOW;
      } else {
         return info;
      }
      alt_info := _default_font(alt_id);
      _FontInfoToFont(info, auto font);
      _FontInfoToFont(alt_info, auto alt_font);
      if (font.font_name == "" && resolve_font_name) font.font_name = alt_font.font_name;
      return _FontToFontInfo(font);
   }
   return "";
}

_str _FontElementIdToName(int id)
{
   FONTCFGINFO cfg;
   foreach (cfg in gfontcfglist) {
      if (id == cfg.value) {
         return cfg.name;
      }
   }

   return '';
}

_str _FontElementIdToNameId(int id)
{
   FONTCFGINFO cfg;
   foreach (cfg in gfontcfglist) {
      if (id == cfg.value) {
         return cfg.nameid;
      }
   }

   return '';
}

_str _FontElementIdToDesc(_str id)
{
   FONTCFGINFO cfg;
   foreach (cfg in gfontcfglist) {
      if (id == cfg.value) {
         return cfg.desc;
      }
   }

   return '';
}

bool _FontElementIsEditorFont(int id)
{
   switch (id) {
   case CFG_UNICODE_SOURCE_WINDOW:
   case CFG_SBCS_DBCS_SOURCE_WINDOW:
   case CFG_DIFF_EDITOR_WINDOW:
   case CFG_UNICODE_DIFF_EDITOR_WINDOW:
   case CFG_SBCS_DBCS_MINIMAP_WINDOW:
   case CFG_UNICODE_MINIMAP_WINDOW:
   case CFG_HEX_SOURCE_WINDOW:
   case CFG_FILE_MANAGER_WINDOW:
      return true;
   default:
      return false;
   }
}

INTARRAY _FontElementLangConfigList()
{
   int a[];
   a :+= CFG_UNICODE_SOURCE_WINDOW;
   a :+= CFG_SBCS_DBCS_SOURCE_WINDOW;
   a :+= CFG_DIFF_EDITOR_WINDOW;
   a :+= CFG_UNICODE_DIFF_EDITOR_WINDOW;
   a :+= CFG_SBCS_DBCS_MINIMAP_WINDOW;
   a :+= CFG_UNICODE_MINIMAP_WINDOW;
   return a;
}

_str _FontFlagsToDesc(int font_flags)
{
   desc := "";
   if (font_flags & F_BOLD) {
      _maybe_append(desc, ", ");
      desc :+= 'Bold';
   }
   if (font_flags & F_ITALIC) {
      _maybe_append(desc, ", ");
      desc :+= 'Italic';
   }
   if (font_flags & F_UNDERLINE) {
      _maybe_append(desc, ", ");
      desc :+= 'Underline';
   }
   if (font_flags & F_STRIKE_THRU) {
      _maybe_append(desc, ", ");
      desc :+= 'Strikethrough';
   }
   return desc;
}

void _FontInfoToFont(_str info, FONT &font,_str alt_info='')
{
   parse info with auto font_name ',' auto font_size ',' auto font_style ',' auto charset',';
   if (alt_info!='') {
      parse alt_info with auto alt_font_name ',';
      if (alt_font_name!='' && alt_font_name==font_name) {
         // Minimap font name matches editor font name
         font_name='';
      }
   }
   font.font_name = font_name;
   if (isinteger(font_size)) {
      font.font_size = (int)font_size;
   } else {
      font.font_size = 10;
   }

   if (charset != "" && isinteger(charset)) {
      font.charset = (int)charset;
   } else {
      font.charset = -1;
   }

   if (isinteger(font_style)) {
      font.font_style = (int)font_style;
   } else {
      font.font_style = 0;
   }
}

_str _FontToFontInfo(FONT font)
{
   return font.font_name ',' font.font_size ',' font.font_style ',' font.charset ',';
}

