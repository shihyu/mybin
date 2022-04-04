////////////////////////////////////////////////////////////////////////////////////
// Copyright 2013 SlickEdit Inc. 
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
#include 'slick.sh'
#include 'svc.sh'
#import 'clipbd.e'
#import 'diff.e'
#import 'dir.e'
#import 'files.e'
#import 'fileman.e'
#import 'guiopen.e'
#import "help.e"
#import 'historydiff.e'
#import 'listbox.e'
#import 'main.e'
#import 'mprompt.e'
#import 'picture.e'
#import 'projconv.e'
#import 'sellist2.e'
#import 'seltree.e'
#import 'stdcmds.e'
#import 'stdprocs.e'
#import 'treeview.e'
#import 'saveload.e'
#import 'se/datetime/DateTime.e'
#import 'se/vc/IVersionControl.e'
#import 'svcrepobrowser.e'
#import 'svcupdate.e'
#import 'tbdeltasave.e'
#import 'varedit.e'
#import 'wkspace.e'
#import 'xml.e'
#import 'se/datetime/DateTime.e'
#import 'se/datetime/DateTimeInterval.e'
#endregion Imports

using se.datetime.DateTime;
using se.datetime.DateTimeInterval;


struct FILE_INFO {
   se.datetime.DateTime date;
   _str filename;
};

const DELTA_ELEMENT_MOST_RECENT     = "M";
const DELTA_ELEMENT_NODE            = "D";
const DELTA_ATTR_DATE               = "D";
const DELTA_ATTR_TIME               = "T";
const DELTA_ELEMENT_MOST_RECENT_OLD = "MostRecent";
const DELTA_ELEMENT_NODE_OLD        = "Delta";
const DELTA_ATTR_DATE_OLD           = "Date";
const DELTA_ATTR_TIME_OLD           = "Time";

static _str getDateForIndex(int xmlhandle,int index,_str ext)
{
   dateAttrName := DELTA_ATTR_DATE_OLD;
   timeAttrName := DELTA_ATTR_TIME_OLD;
   if ( _file_eq(ext,DELTA_ARCHIVE_EXT) ) {
      dateAttrName = DELTA_ATTR_DATE;
      timeAttrName = DELTA_ATTR_TIME;
   }
   if (index<0) {
      return "";
   }
   date := _xmlcfg_get_attribute(xmlhandle,index,dateAttrName);
   date :+= " " _xmlcfg_get_attribute(xmlhandle,index,timeAttrName);
   return date;
}

static void addToDateTable(_str date,STRHASHTAB &dateTable,_str filename)
{
   if ( !dateTable._indexin(date) ) {
      dateTable:[date] = _maybe_quote_filename(filename);
   } else {
      dateTable:[date] :+= ' '_maybe_quote_filename(filename);
   }
}

static _str getSourceFilenameFromDeltaFilename(_str basePath,_str deltaFilename)
{
   deltaFilename = substr(deltaFilename,length(basePath)+1);
   STRHASHTAB driveLetters;
   if (_isWindows()) {
      if (pos(FILESEP,deltaFilename)==2) {
         // Figure out if we have something that should have a drive letter
         dl := substr(deltaFilename,1,1);
         if (driveLetters:[dl]!=null) {
            if (file_match('+p 'dl,1)!="") {
               driveLetters:[dl] = "";
               deltaFilename = substr(deltaFilename,1,1)':'substr(deltaFilename,2);
            }
         } else {
            deltaFilename = substr(deltaFilename,1,1)':'substr(deltaFilename,2);
         }
      } else if ( pos(FILESEP,deltaFilename)==4 && 
                  _file_eq(substr(deltaFilename,1,3),"ftp") ) {
         deltaFilename = _ConfigPath():+deltaFilename;
      } else {
         deltaFilename = '\\'deltaFilename;
      }
   } else {
      if ( pos(FILESEP,deltaFilename)==4 && 
           _file_eq(substr(deltaFilename,1,3),"ftp") ) {
         deltaFilename = _ConfigPath():+deltaFilename;
      } else {
         // For UNIX this will be the root directory
         deltaFilename = '/' :+ deltaFilename;
      }
   }
   deltaFilename = _strip_filename(deltaFilename,'E');
   return deltaFilename;
}

static void getNewArchiveHT(FILE_INFO (&newArchiveHT):[],_str path)
{
   origWID := _create_temp_view(auto tempWID);
   insert_file_list("+t +v +p "_maybe_quote_filename(path:+"*"DELTA_ARCHIVE_EXT));
   top();up();
   STRHASHTAB driveLetters;
   while (!down()) {
      get_line(auto line);
      FILE_INFO temp;
      temp.filename = substr(line,DIR_FILE_COL);
      if (_isWindows()) {
         if (pos(FILESEP,temp.filename)==2) {
            // Figure out if we have something that should have a drive letter
            dl := substr(temp.filename,1,1);
            if (driveLetters:[dl]!=null) {
               if (file_match('+p 'dl,1)!="") {
                  driveLetters:[dl] = "";
                  temp.filename = substr(temp.filename,1,1)':'substr(temp.filename,2);
               }
            } else {
               temp.filename = substr(temp.filename,1,1)':'substr(temp.filename,2);
            }
         }
      }
      date := substr(line,DIR_DATE_COL,DIR_DATE_WIDTH);
      parse date with auto month '-' auto day '-' auto year;
      time := substr(line,DIR_TIME_COL,DIR_TIME_WIDTH);
      parse time with auto hh ":" auto mm;
      if (_last_char(mm)=='p') {
         int tempMM = (int)substr(mm,1,2);
         tempMM += 12;
         mm= tempMM;
      } else {
         mm = substr(mm,1,2);
      }
      hhint := (int)strip(hh);
      mmint := (int)strip(mm);
      yearint := (int)strip(year);
      monthint := (int)strip(month);
      dayint := (int)strip(day);

      se.datetime.DateTime tempDate(yearint,monthint,dayint,hhint,mmint);

      temp.date = tempDate;
      dtstr := temp.date.toString();
      newArchiveHT:[_file_case(temp.filename)] = temp;
   }
   p_window_id = origWID;
   _delete_temp_view(tempWID);
}

const DELTA_ARCHIVE_EXT_PRE22 = ".vsdelta";
static void getFileList(_str path,FILE_INFO (&fileList)[])
{
   FILE_INFO newArchiveHT:[];
   // First get all the new new archive extension, and put that in a hashtable
   // indexed by the whole path.
   getNewArchiveHT(newArchiveHT,path);
   origWID := _create_temp_view(auto tempWID);
   // Now list all the files with the old archive extension and list those like
   // we always have.
   insert_file_list("+t +v +p "_maybe_quote_filename(path:+"*"DELTA_ARCHIVE_EXT_PRE22));
   top();up();
   STRHASHTAB driveLetters;
   while (!down()) {
      get_line(auto line);
      FILE_INFO temp;
      curFilename := substr(line,DIR_FILE_COL);
      newArchiveExtFilename := _file_case((_strip_filename(curFilename,'E'):+DELTA_ARCHIVE_EXT));
      // Build the same filename with the new extension. See if we have this
      // with a new archive extension already
      temp = newArchiveHT:[newArchiveExtFilename];
      if ( temp==null ) {
         // Add the information as we always have.  Anything we use will be 
         // upgraded as soon as we touch it.
         temp.filename = curFilename;
         if (_isWindows()) {
            if (pos(FILESEP,temp.filename)==2) {
               // Figure out if we have something that should have a drive letter
               dl := substr(temp.filename,1,1);
               if (driveLetters:[dl]!=null) {
                  if (file_match('+p 'dl,1)!="") {
                     driveLetters:[dl] = "";
                     temp.filename = substr(temp.filename,1,1)':'substr(temp.filename,2);
                  }
               } else {
                  temp.filename = substr(temp.filename,1,1)':'substr(temp.filename,2);
               }
            }
         }
         date := substr(line,DIR_DATE_COL,DIR_DATE_WIDTH);
         parse date with auto month '-' auto day '-' auto year;
         time := substr(line,DIR_TIME_COL,DIR_TIME_WIDTH);
         parse time with auto hh ":" auto mm;
         if (_last_char(mm)=='p') {
            int tempMM = (int)substr(mm,1,2);
            tempMM += 12;
            mm= tempMM;
         } else {
            mm = substr(mm,1,2);
         }
         hhint := (int)strip(hh);
         mmint := (int)strip(mm);
         yearint := (int)strip(year);
         monthint := (int)strip(month);
         dayint := (int)strip(day);

         se.datetime.DateTime tempDate(yearint,monthint,dayint,hhint,mmint);

         temp.date = tempDate;
         dtstr := temp.date.toString();
         // Remove ".vsdelta"
         // temp.filename = _strip_filename(temp.filename,'E');
      } else {
         // Delete this item from the hashtable, we'll add it below
         newArchiveHT._deleteel(newArchiveExtFilename);
      }

      // Whether it came from the hashtable or we got the information from an
      // old archive, add it.
      ARRAY_APPEND(fileList,temp);
   }
   // Whatever is left in the hashtable, add that to the array.  We have to
   // do check for null because of the way it was assigned above.
   foreach ( auto filename => auto curTemp in newArchiveHT) {
      if (curTemp!=null) {
         ARRAY_APPEND(fileList,curTemp);
      }
   }
   p_window_id = origWID;
   _delete_temp_view(tempWID);
}

int _repairBHFile(_str filename)
{
   status := _open_temp_view(filename,auto tempWID,auto origWID);
   if ( status ) return status;

   _SetEditorLanguage();

   haveMostRecent := true;
   do {
      p_line = 3;  // Put cursor on MostRecent line
      if ( status ) {
         break;
      }
      status = _xml_find_matching_word(false,0x7fffffff);
      if ( status ) {
         haveMostRecent = false;
         break;
      }
   } while (false);
   if ( status ) {
      if ( !haveMostRecent ) {
         p_window_id = origWID;
         _delete_temp_view(tempWID);
         result := _message_box(nls("SlickEdit cannot find the most recent version of the file and will not be able to repair this archive.\n\nWould you like to remove it?"),"",MB_YESNO);
         if ( result == IDYES ) {
            _removeArchive(filename);
         }
         return -1;
      }
   }
   // Move down and postion on what should be first <Delta> entry
   markid := _alloc_selection();

   // For some reason, blank lines get inserted after the most recent version.
   // Skip over them.
   nextLine := "";
   for (;;) {
      down();
      get_line(nextLine);
      if ( nextLine!="" ) break;
   }
   _select_line(markid);
   for (;;) {
      get_line(auto beginline);
      if ( substr(beginline,1,7)!="<Delta " ) break;
      status = _xml_find_matching_word(false,0x7fffffff);
      if ( status ) break;
      down();
   }
   if ( status ) {
      // If we had a status, delete everything to the bottom
      bottom(); // This will take us to the </DeltaFile> entry
      up();     // this should be the last </Delta> entry
      _select_line(markid);
      _delete_selection(markid);
      status = saveArchive(p_window_id,filename);
   }
   _free_selection(markid);
   p_window_id = origWID;
   _delete_temp_view(tempWID);
   return status;
}

static int saveArchive(int archiveWID,_str filename)
{
   origWID := p_window_id;
   p_window_id = archiveWID;
   int status;
   if (_isUnix()) {
      status = _chmod('u+w '_maybe_quote_filename(filename));
   } else {
      status = _chmod('-r '_maybe_quote_filename(filename));
   }
   if ( status ) return status;
   status = _save_file('+o 'filename);
   if ( status ) return status;
   if (_isUnix()) {
      status = _chmod('u-w '_maybe_quote_filename(filename));
   } else {
      status = _chmod('+r '_maybe_quote_filename(filename));
   }
   p_window_id = origWID;
   return status;
}

int _removeArchive(_str filename)
{
   int status;
   if (_isUnix()) {
      status = _chmod('u+w '_maybe_quote_filename(filename));
   } else {
      status = _chmod('-r '_maybe_quote_filename(filename));
   }
   if ( status ) return status;
   status = delete_file(filename);
   if ( status ) return status;
   if (_isUnix()) {
      status = _chmod('u-w '_maybe_quote_filename(filename));
   } else {
      status = _chmod('+r '_maybe_quote_filename(filename));
   }
   return status;
}

static int addItemToTable(int xmlhandle,_str basePath,_str filename,STRHASHTAB &dateTable)
{
   ext := _get_extension(filename,true);
   mr := DELTA_ELEMENT_MOST_RECENT_OLD;
   dn := DELTA_ELEMENT_NODE_OLD;
   if ( _file_eq(ext,DELTA_ARCHIVE_EXT) ) {
      mr = DELTA_ELEMENT_MOST_RECENT;
      dn = DELTA_ELEMENT_NODE;
   }
   index := _xmlcfg_find_simple(xmlhandle,"//"mr);
   if (index<0) return index;
   date := getDateForIndex(xmlhandle,index,ext);
   sourceFilename := getSourceFilenameFromDeltaFilename(basePath,filename);
   addToDateTable(date,dateTable,sourceFilename);
   _xmlcfg_find_simple_array(xmlhandle,"//"dn,auto arrayIndex);
   indexArrayLen := arrayIndex._length();
   for ( j:=0;j<indexArrayLen;++j ) {
      date = getDateForIndex(xmlhandle,(int)arrayIndex[j],ext);
      addToDateTable(date,dateTable,sourceFilename);
   }
   return 0;
}

_command void rebuild_backup_history_log() name_info(',')
{
   if (!_haveBackupHistory()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_OR_STANDARD_EDITION_1ARG, "Backup History");
      return;
   }
   basePath := _getBackupHistoryPath();
   origMaxArraySize:=_default_option(VSOPTION_WARNING_ARRAY_SIZE);
   _default_option(VSOPTION_WARNING_ARRAY_SIZE,MAXINT);
   mou_hour_glass(true);
   _maybe_append_filesep(basePath);
   FILE_INFO fileList[];
   getFileList(basePath,fileList);

   len := fileList._length();
   STRHASHTAB dateTable;
   for (i:=0;i<len;++i) {
      filename := fileList[i].filename;
      xmlhandle := _xmlcfg_open(filename,auto status);
      if ( status ) {
         result := _message_box(nls("Could not open '%s', it may be damaged.\n\nWould you like to try to repair it now?",filename),"",MB_YESNO);
         if ( result==IDYES ) {
            status = _repairBHFile(filename);
            if ( !status ) {
               xmlhandle = _xmlcfg_open(filename,status);
            }
         }
      }
      if ( xmlhandle>=0 ) {
         status = addItemToTable(xmlhandle,basePath,filename,dateTable);
         if (status) break;
         _xmlcfg_close(xmlhandle);
      }
   }
   STRARRAY dateArray;
   foreach (auto key => auto value in dateTable) {
      ARRAY_APPEND(dateArray,key);
   }
   dateArray._sort();
   saveLogFilename := basePath:+SAVELOG_FILE;
   xmlhandle := _xmlcfg_create(saveLogFilename,VSENCODING_UTF8);
   _xmlcfg_delete(xmlhandle,TREE_ROOT_INDEX,true);

   saveLogIndex := _xmlcfg_add(xmlhandle,TREE_ROOT_INDEX,"SaveLog",VSXMLCFG_NODE_ELEMENT_START,VSXMLCFG_ADD_AS_CHILD);

   foreach (auto curDate in dateArray) {
      curIndex := _xmlcfg_add(xmlhandle,saveLogIndex,"f",VSXMLCFG_NODE_ELEMENT_START_END,VSXMLCFG_ADD_AS_CHILD);
      fileListStr := dateTable:[curDate];
      for (;;) {
         curFile := parse_file(fileListStr);
         if ( curFile=="" ) break;
         // Be sure not to add double quoted files to log
         curFile = strip(curFile,'B','"');
         _xmlcfg_add_attribute(xmlhandle,curIndex,"n",curFile);
         _xmlcfg_add_attribute(xmlhandle,curIndex,"d",curDate);
      }
   }

   _xmlcfg_save(xmlhandle,-1,VSXMLCFG_SAVE_ATTRS_ON_ONE_LINE);
   _xmlcfg_close(xmlhandle);
   _default_option(VSOPTION_WARNING_ARRAY_SIZE,origMaxArraySize);
   mou_hour_glass(false);
}

defeventtab _backup_history_browser_form;
void ctlsearch_clear.lbutton_up()
{
   p_prev.p_text = "";
}

void _grabbar_horz.lbutton_down()
{
   // figure out orientation
   min := 0;
   max := 0;

   getGrabbarMinMax(min, max);

   _ul2_image_sizebar_handler(min, max);
}

#if 1
static void getGrabbarMinMax(int &min, int &max)
{
//   typeless (*pposTable):[] = getPointerToPositionTable();

   // use what is saved in the table if we don't know any better
//   if (orientation == '') orientation = (*pposTable):["lastOrientation"];

   min = max = 0;
   min = 2 * ctltree1.p_y;
   max = ctlclose.p_y - min;
}
#endif

static void resizeDialog()
{
   clientHeight := _dy2ly(SM_TWIP,p_active_form.p_client_height);
   clientWidth := _dx2lx(SM_TWIP,p_active_form.p_client_width);
   ybuffer := ctlfilespec.p_prev.p_y;
   xbuffer := ctlscope.p_prev.p_x;
   ctlscope.p_width = (clientWidth - ctlscope.p_prev.p_x_extent) - 2*ybuffer;

   origWID := p_window_id;
   p_window_id = ctltree1;
   p_x = ctltree2.p_x = ybuffer;
   p_width = ctltree2.p_width = clientWidth - 2*ybuffer;

   // Size the first two columns to the content width, this will leave room
   // for the path
   _TreeSizeColumnToContents(0);
   _TreeSizeColumnToContents(1);
   p_window_id = origWID;

   // Some controls on dialog are not currently visible, because they might not
   // be used by first pass
   treeHeight := treeHeight1 := 0;
   if ( ctlscope.p_visible ) {
      ctltree1.p_y = ctlscope.p_y_extent+ybuffer;
   } else {
      ctltree1.p_y = ctlfilespec.p_y_extent+ybuffer;
   }
   treeHeight1 = _grabbar_horz.p_y - ctltree1.p_y - ybuffer;
   ctltree1.p_height = treeHeight1;

   _grabbar_horz.p_y = ctltree1.p_y_extent+ybuffer;
   restOfDialog := clientHeight - _grabbar_horz.p_y_extent;
   ctlfilesSavedSince.p_y = _grabbar_horz.p_y_extent+ybuffer;
   ctltree2.p_y = ctlfilesSavedSince.p_y_extent+ybuffer;
   treeHeight2 := ((restOfDialog - ctlview.p_height)- ctlfilesSavedSince.p_height) - (4 * ybuffer);
   ctltree2.p_height = treeHeight2;

   ctlview.p_y = ctlrestore.p_y = ctlrebuildSaveLog.p_y = ctlrebuildSaveLog.p_next.p_y = ctldiff.p_y = ctlclose.p_y = ctltree2.p_y_extent+ybuffer;
   _grabbar_horz.p_width = clientWidth;

   ctlfilespec.p_x = ctlfilespec.p_prev.p_x_extent + xbuffer;
   sizeBrowseButtonToTextBox(ctlfilespec.p_window_id, ctlsearch_clear.p_window_id, ctlfilespec_help.p_window_id, clientWidth);
}

_backup_history_browser_form.on_resize()
{
   resizeDialog();
}

extern void _loadThisWeeksFileDates(int);
extern void _loadOlderFileDates(int,int);
extern void _GetFileTableFromBHBrowser(STRHASHTAB &fileTable,_str filespecs);
extern int  _filterRepoBrowserTree(_str filter,bool clearCache=false);
extern int  _filterRepoBrowserTreeOneFileMatches(_str filter,_str filename);

_str _getBackupHistoryPath()
{
   deltaArchivePath := get_env("VSLICKBACKUP");
   if (deltaArchivePath=="") {
      deltaArchivePath = get_env(_SLICKEDITCONFIG);
      _maybe_append_filesep(deltaArchivePath);
      deltaArchivePath :+= DELTA_DIR_NAME;
   }
   _maybe_append_filesep(deltaArchivePath);
   return deltaArchivePath;
}

static _str getSaveLogFilename()
{
   basePath := _getBackupHistoryPath();
   saveLogFilename := basePath:+SAVELOG_FILE;
   return saveLogFilename;
}

static void loadThisWeeksDatesIntoTree()
{
   saveLogFilename := getSaveLogFilename();
   xmlhandle := _xmlcfg_open(saveLogFilename,auto status);
   needRebuild := false;
   if (status==PATH_NOT_FOUND_RC) {
      _message_box(nls("Path '%s' does not exist.  It will be created when a file is backed up.",_getBackupHistoryPath()));
      p_active_form._delete_window();
      return;
   }
   if ( xmlhandle<0 ) {
      basePath := _getBackupHistoryPath();
      if ( file_match('+p +t 'basePath:+ALLFILES_RE,1)!="" ) {
         needRebuild = true;
      }
   } else {
      nodeIndex := _xmlcfg_find_child_with_name(xmlhandle,TREE_ROOT_INDEX,"SaveLog");
      if ( nodeIndex >- 1 ) {
         rebuild := _xmlcfg_get_attribute(xmlhandle,nodeIndex,"Rebuild");
         if ( rebuild == 1 ) {
            needRebuild = true;
         }
      }
   }
   if ( needRebuild ) {
      result := _message_box(nls("Your %s file needs to be rebuilt.\n\nRebuild now?",SAVELOG_FILE),"",MB_YESNO);
      if (result==IDYES) {
         if ( xmlhandle>0 ) _xmlcfg_close(xmlhandle);
         rebuild_backup_history_log();
         xmlhandle = _xmlcfg_open(saveLogFilename,status);
         if ( xmlhandle<0 ) {
            return;
         }
      } else {
         return;
      }
   }
   int fileDateTable:[]:[];

   origWID := p_window_id;
   p_window_id = ctltree1;
   _TreeBeginUpdate(TREE_ROOT_INDEX);

   mou_hour_glass(true);
   _loadThisWeeksFileDates(xmlhandle);
   _TreeEndUpdate(TREE_ROOT_INDEX);
//   olderIndex := _TreeAddItem(TREE_ROOT_INDEX,"Older",TREE_ADD_AS_CHILD,0,0,0,TREENODE_BOLD);
   olderIndex := _TreeAddItem(TREE_ROOT_INDEX,"Older",TREE_ADD_AS_CHILD,0,0,0,TREENODE_BOLD);
   _SetDialogInfoHt("olderIndex",olderIndex);
//   _loadOlderFileDates(xmlhandle,olderIndex);
   _TreeTop();

   mou_hour_glass(false);

   p_window_id = origWID;
   _xmlcfg_close(xmlhandle);
}

void ctlclose.on_create()
{
   origWID := p_window_id;
   p_window_id = ctltree1;
   _TreeSetColButtonInfo(0,ctltree1.p_width intdiv 3,-1,-1,"Date");
   _TreeSetColButtonInfo(1,ctltree1.p_width intdiv 3,TREE_BUTTON_IS_DATETIME,-1,"Filename");
   _TreeSetColButtonInfo(2,ctltree1.p_width intdiv 3,TREE_BUTTON_IS_DATETIME,-1,"Path");
   p_window_id = origWID;
   loadThisWeeksDatesIntoTree();
}

static int gChangeSelectedTimer = -1;
static int gFilespecTimer = -1;

void ctlclose.on_destroy()
{
   if ( gChangeSelectedTimer>-1 ) {
      _kill_timer(gChangeSelectedTimer);
      gChangeSelectedTimer = -1;
   }
   if ( gFilespecTimer>-1 ) {
      _kill_timer(gFilespecTimer);
      gFilespecTimer = -1;
   }
   _filterRepoBrowserTree("", true);
}

void ctltree1.on_got_focus()
{
   _SetDialogInfoHt("lastTreeControlWID",p_window_id);
}

void ctltree2.on_got_focus()
{
   _SetDialogInfoHt("lastTreeControlWID",p_window_id);
}

static const DAY_DEPTH  = 1;
static const FILE_DEPTH = 2;

void ctltree1.on_change(int reason,int index)
{
   if ( index  < 0 ) return;
   inOnChange := _GetDialogInfoHt("inOnChange");
   if (inOnChange) {
      return;
   }
   _SetDialogInfoHt("inOnChange",1);
   depth := _TreeGetDepth(index);
   switch (reason) {
   case CHANGE_EXPANDED:
      if (_TreeGetCaption(index)=="Older") {
         olderIndex := _GetDialogInfoHt("olderIndex");
         if (olderIndex>0) {
            saveLogFilename := getSaveLogFilename();
            xmlhandle := _xmlcfg_open(saveLogFilename,auto status);
            if ( xmlhandle<0 ) {
               return;
            }
            mou_hour_glass(true);
            _TreeBeginUpdate(index);
            _loadOlderFileDates(xmlhandle,olderIndex);
            if (ctlfilespec.p_text != "") {
               _filterRepoBrowserTree(ctlfilespec.p_text);
            }
            _TreeEndUpdate(index);
            mou_hour_glass(false);
            _xmlcfg_close(xmlhandle);
         }
         ctlrestore.p_enabled = ctlview.p_enabled = false;
      }
      break;
   case CHANGE_LEAF_ENTER:
      {
         diffFromTopOrBottomTreeTree(index);
      }
      break;
   case CHANGE_SELECTED:
      {
         if ( gChangeSelectedTimer>=0 ) {
            _kill_timer(gChangeSelectedTimer);
         }
         gChangeSelectedTimer = _set_timer(50,treeChangeSelectedCallback,p_active_form' 'index);
         ctlrestore.p_enabled = ctlview.p_enabled = depth == FILE_DEPTH;
      }
   }
   _SetDialogInfoHt("inOnChange",0);
}

static void filespecTimerCallback(_str info)
{
   if (gFilespecTimer>-1) {
      _kill_timer(gFilespecTimer);
      gFilespecTimer = -1;
   }

   parse info with auto fid auto text;
   if ( fid.ctlfilespec.p_text != text ) {
      return;
   }

   origWID := p_window_id;
   p_window_id = (int)fid.ctltree1;
   origBottomPaneFilename := getFilenameFromBottomPane();
   _SetDialogInfoHt("origBottomPaneFilename",origBottomPaneFilename);
//   t1 := _time('b');
//   filterTree(ctlfilespec.p_text);
   _filterRepoBrowserTree(ctlfilespec.p_text);
//   t10 := _time('b');
//   say('filespecTimerCallback (int)t10-(int)t1='(int)t10-(int)t1);

   topPaneIndex := _TreeCurIndex();
   _TreeGetInfo(topPaneIndex,auto state, auto bm1, auto bm2,auto nodeFlags);

   if ( ctlfilespec.p_text=="" || nodeFlags&TREENODE_HIDDEN ) {
      // We may have deleted a filter, where the user selected something in the
      // top pane.  Be sure it's visible.  Need _TreeCenterNode()
      status := _TreeUp();
      if ( !status ) {
         _TreeDown();
      }
   }
   fid.ctltree1.call_event(CHANGE_SELECTED,fid.ctltree1._TreeCurIndex(),fid.ctltree1,ON_CHANGE,'W');
   p_window_id = origWID;
}

void ctltree1.UP()
{
   status := _TreeUp();
   if ( status ) {
      ctlfilespec._set_focus();
   }
}

void ctlfilespec.DOWN()
{
   ctltree1._set_focus();
}

void ctlfilespec.END()
{
   if ( p_text=="" ) {
      ctltree1._set_focus();
      return;
   }
   call_event(defeventtab _ul2_textbox,last_event(),'e');
}

void ctlfilespec.on_change()
{
   inOnChangeFilespecs := _GetDialogInfoHt("inOnChangeFilespecs");
   if (inOnChangeFilespecs) {
      return;
   }
   _SetDialogInfoHt("inOnChangeFilespecs",1);
   if (gFilespecTimer>-1) {
      _kill_timer(gFilespecTimer);
      gFilespecTimer = -1;
   }
   gFilespecTimer = _set_timer(250,filespecTimerCallback,p_active_form' 'p_text);
   _SetDialogInfoHt("inOnChangeFilespecs",0);
}

static bool noItemsSelected()
{
   index := _TreeGetNextCheckedIndex(1,auto info);
   return index<0;
}

void ctltree2.on_change(int reason,int index)
{
   inOnChange := _GetDialogInfoHt("inOnChange");
   if (inOnChange) {
      return;
   }
   _SetDialogInfoHt("inOnChange",1);
   switch (reason) {
   case CHANGE_SELECTED:
      if ( noItemsSelected() ) {
         diff := false;
         restore := false;
         view := false;
         _TreeGetInfo(index,auto state, auto bm1, auto bm2);
         if ( bm1 == _pic_file || bm1 == _pic_cvs_filem ) {
            diff = true;
            view = true;
            restore = true;
         }
         if ( diff ) ctldiff.p_enabled = true;
         if ( restore ) ctlrestore.p_enabled = true;
         if ( view ) ctlview.p_enabled = true;
      }
      break;
   case CHANGE_LEAF_ENTER:
      diffFromTopOrBottomTreeTree();
      break;
   case CHANGE_EXPANDED:
      break;
   case CHANGE_CHECK_TOGGLED:
      {
         getCheckedIndexList(auto indexList);
         len := indexList._length();
         diff := false;
         restore := false;
         view := false;
         for (i:=0;i<len;++i) {
            _TreeGetInfo(indexList[i],auto state, auto bm1, auto bm2);
            if ( bm1 == _pic_file || bm1 == _pic_cvs_filem ) {
               diff = true;
               view = true;
               restore = true;
            } else {
            }
            if ( diff && restore && view ) break; // Nothing else we can accomplish
         }
         if ( diff ) ctldiff.p_enabled = true;
         if ( restore ) ctlrestore.p_enabled = true;
         if ( view ) ctlview.p_enabled = true;
      }
      break;
   }
   _SetDialogInfoHt("inOnChange",0);
}

static const FOLDER_DEPTH   = 1;
static const FILE_DEPTH     = 2;

static const JUST_NAME_COL  = 1;
static const JUST_PATH_COL  = 2;

static _str getFilenameFromBottomPane()
{
   origWID := p_window_id;
   p_window_id = ctltree2;

   filename := "";

   do {
      index := _TreeCurIndex();
      _TreeGetInfo(index, auto state);
      if ( state != TREE_NODE_LEAF ) {
         break;
      }

      justName := _TreeGetCaption(index);
      justPath := _TreeGetCaption(_TreeGetParentIndex(index));
      filename = justPath:+justName;
   } while (false);

   p_window_id = origWID;

   return filename;
}
static _str getFilenameFromTopPane()
{
   origWID := p_window_id;
   p_window_id = ctltree1;

   index := _TreeCurIndex();
   filename := "";
   if ( index ) {
      filename = _TreeGetCaption(index, JUST_PATH_COL):+_TreeGetCaption(index, JUST_NAME_COL);
   }

   p_window_id = origWID;
   return filename;
}

static int maybeSelectBottomPaneFilename(_str filename)
{
   origWID := p_window_id;
   p_window_id = ctltree2;

   status := 0;

   do {
      path := _file_path(filename);

      pathIndex := _TreeSearch(TREE_ROOT_INDEX,path,'T':+_fpos_case);
      if ( pathIndex < 0 ) {
         status =  PATH_NOT_FOUND_RC;
         break;
      }

      justName := _strip_filename(filename,'P');
      nameIndex := _TreeSearch(pathIndex,justName,_fpos_case);

      if ( nameIndex >0 ) _TreeSetCurIndex(nameIndex);
   } while (false);

   p_window_id = origWID;
   return status;
}

static void treeChangeSelectedCallback(int info)
{
   if ( gChangeSelectedTimer>=0 ) _kill_timer(gChangeSelectedTimer);
   gChangeSelectedTimer = -1;

   parse info with auto fid auto index;
   if (fid.ctltree1._TreeCurIndex()!=index) {
      return;
   }

   origWID := p_window_id;
   p_window_id = (int)fid;
   tree1CurIndex := ctltree1._TreeCurIndex();
   tree1ChildIndex := ctltree1._TreeGetFirstChildIndex(tree1CurIndex);
   if ( ctltree1._TreeGetDepth(tree1CurIndex)==FILE_DEPTH ) {
      indexAbove := ctltree1._TreeGetPrevIndex(tree1CurIndex);
      if ( indexAbove <0 ) {
         ctltree2._TreeDelete(TREE_ROOT_INDEX,'C');
         p_window_id = origWID;
         return;
      }
   }

   STRHASHTAB fileTable;
   int pathTable:[];

   ctltree1.getFileTable(fileTable, ctlfilespec.p_text);

   onFolder := ctltree1._TreeGetDepth(tree1CurIndex) == FOLDER_DEPTH;

   mou_hour_glass(true);
   ctltree2._TreeDelete(TREE_ROOT_INDEX,'C');

   if ( onFolder ) {
      p_window_id = ctltree1;
      // This is not the child index, items could be hidden
      belowIndex := _TreeGetNextIndex(tree1CurIndex);
      if ( belowIndex >= 0 && ctltree1._TreeGetDepth(belowIndex) != FOLDER_DEPTH ) {
         justName := _TreeGetCaption(belowIndex,1);
         justPath := _TreeGetCaption(belowIndex,2);
         filename := justPath:+justName;

         filters := ctlfilespec.p_text;
         if ( filters == "" ) {
            fileTable:[filename] = _file_case(filename);
         } else {
            match := pos(filters, justName) || _FileRegexMatchExcludePath(filters,filename);
            if ( match ) {
               fileTable:[filename] = _file_case(filename);
            }
         }
      }
   }
   p_window_id = ctltree2;

   mou_hour_glass(true);
   _TreeDelete(TREE_ROOT_INDEX,'C');
   _TreeBeginUpdate(TREE_ROOT_INDEX);
   buildPathTable(fileTable,pathTable);
   foreach (auto filename in fileTable) {
      pathIndex := _SVCGetPathIndex(_file_path(filename),'',pathTable);
      bmIndex := _pic_file;
      curIndex := _TreeAddItem(pathIndex,_strip_filename(filename,'P'),TREE_ADD_AS_CHILD,bmIndex,bmIndex,-1);
      _TreeSetCheckable(curIndex,1,0);
   }
   _TreeEndUpdate(TREE_ROOT_INDEX);

   // Now sort everything
   firstChild := _TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   if (firstChild >= 0) {
      _TreeSortCaption(firstChild,'FT');
   }

   p_window_id = ctltree1;
   origTreeIndex := treeIndex := _TreeCurIndex();
   isFolder := _TreeGetDepth(treeIndex) == FOLDER_DEPTH;
   if ( isFolder ) {
      treeIndex = _TreeGetPrevIndex(treeIndex);
   } else {
      treeIndex = _TreeGetFirstChildIndex(treeIndex);
   }
   if ( treeIndex<0 ) treeIndex = origTreeIndex;

   if ( treeIndex>0 ) {
      _TreeGetDateTimeStr(treeIndex,0,auto date);
      ctlfilesSavedSince.p_caption = "Files saved since "date':';
   } else {
      ctlfilesSavedSince.p_caption = "";
   }
   // If this is a folder, is there a child?
   if ( isFolder ) {
      childIndex := _TreeGetFirstChildIndex(treeIndex);
      if ( childIndex<0 ) {
         // Go up until we find a file, or a folder with children
      }
   }

   origBottomPaneFilename := _GetDialogInfoHt("origBottomPaneFilename");
   if ( origBottomPaneFilename != null && origBottomPaneFilename != "" ) {
      maybeSelectBottomPaneFilename(origBottomPaneFilename);
      _SetDialogInfoHt("origBottomPaneFilename",null);
   }

   ctldiff.p_enabled = _TreeGetDepth(origTreeIndex) == FILE_DEPTH;

   mou_hour_glass(false);
   p_window_id = origWID;
}

static void buildPathTable(STRHASHTAB &fileTable, 
                           int (&pathTable):[], 
                           int ExistFolderIndex=_pic_fldopen,
                           int NoExistFolderIndex=_pic_cvs_fld_m,
                           _str OurFilesep=FILESEP,
                           int state=1,
                           int checkable=1)
{
   // temporaries
   subpath := path := "";
   cased_path := "";
   cased_subpath := "";

   // Hash table and list of paths we want to keep
   // The hash table maps paths to their parent path in the heirarchy.
   _str filePathsTable:[];
   _str sortedPaths[];
   // All paths and sub-paths we have seen so far
   bool allPathsTable:[];

   // Go through each file in the file table
   foreach (auto filename => auto value in fileTable) {
      // Check if we already have seen this path
      path = _strip_filename(filename, 'N');
      cased_path = _file_case(path);
      if ( filePathsTable._indexin(cased_path) ) {
         continue;
      }
      // Add the path to all the tables
      filePathsTable:[cased_path] = "";
      allPathsTable:[cased_path] = true;
      sortedPaths[sortedPaths._length()] = path;
      // Then traverse over interior paths and see if we find
      // a common interior path with another path we already saw
      subpath = path;
      while (subpath != "") {
         // Remove the trailing file separator and
         // check that we didn't hit a top level path
         subpath = strip(subpath,'T',OurFilesep);
         if (!pos(OurFilesep,strip(subpath,'L',OurFilesep))) break;
         // Get the interior path and see if we have seen it before
         // and then add it to the table.
         subpath = _strip_filename(subpath, 'N');
         cased_subpath = _file_case(subpath);
         if (filePathsTable._indexin(cased_subpath)) {
            filePathsTable:[cased_path] = subpath;
            break;
         }
         if (allPathsTable._indexin(cased_subpath)) {
            filePathsTable:[cased_subpath] = "";
            sortedPaths[sortedPaths._length()] = subpath;
            break;
         }
         allPathsTable:[cased_subpath] = true;
      }
   }

   // Second pass through the paths in order to patch up any
   // paths that may share an interior path with another
   foreach (path in sortedPaths) {
      subpath = path;
      while (subpath != "") {
         // Remove the trailing file separator and
         // check that we didn't hit a top level path
         subpath = strip(subpath,'T',OurFilesep);
         if (!pos(OurFilesep,strip(subpath,'L',OurFilesep))) break;
         // Get the interior path and see if we have seen it before
         // and then modify the table
         subpath = _strip_filename(subpath, 'N');
         if (filePathsTable._indexin(_file_case(subpath))) {
            filePathsTable:[_file_case(path)] = subpath;
            break;
         }
      }
   }

   // Sort the list of paths, this way interior paths get inserted
   // before their child nodes.  Also insures things are sorted
   // when building a flattened tree.
   sortedPaths._sort('F');

   // Insert the required paths into the tree
   foreach (path in sortedPaths) {
      // Find the interior node that this path should be inserted under
      cased_path = _file_case(path);
      subpath = filePathsTable:[cased_path];
      cased_subpath = _file_case(subpath);
      treeIndex := TREE_ROOT_INDEX;
      if (subpath != "" && pathTable._indexin(cased_subpath)) {
         treeIndex = pathTable:[cased_subpath];
      }
      // Determine which bitmap index to use
      bmindex := ExistFolderIndex;

      // Then add the item to the tree
      treeIndex = _TreeAddItem(treeIndex, 
                               path, 
                               TREE_ADD_AS_CHILD, 
                               bmindex,
                               bmindex,
                               state);
      _TreeSetCheckable(treeIndex, checkable, checkable);
      // And, finally, update the path table
      pathTable:[cased_path] = treeIndex;
   }
}



static void getFileTable(STRHASHTAB &fileTable,_str filespecs)
{
   curTreeIndex := index := _TreeCurIndex();
   cache := _GetDialogInfoHt("cache:":+index:+':':+filespecs);
   if ( cache != null ) {
      fileTable = cache;
      return;
   }
   _GetFileTableFromBHBrowser(fileTable,filespecs);
   _SetDialogInfoHt("cache:"index:+':':+filespecs,fileTable);
}

static void getCheckedIndexList(INTARRAY &indexList)
{
   int info;
   for (ff:=1;;ff=0) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      _TreeGetInfo(index,auto state, auto bm1);
      if ( bm1 != _pic_fldopen && bm1 != _pic_cvs_fld_m ) {
         ARRAY_APPEND(indexList,index);
      }
   }
   if ( indexList._length() == 0 ) {
      index := _TreeCurIndex();
      if ( index>= 0 ) {
         ARRAY_APPEND(indexList,index);
      }
   }
}

#define USING_USER_INFO 0

static void diffSelectedFiles()
{
   origWID := p_window_id;
   p_window_id = ctltree1;
   index := _TreeCurIndex();
   while ( _TreeGetDepth(index)==1 ) {
      index = _TreeGetPrevIndex(index);
   }

   datestr := "";
   filename := "";
   _TreeGetDateTimeStr(index, 0, datestr, "YYYY/MM/DD HH:mm:ssmmm");
   filename = _TreeGetCaption(index,JUST_PATH_COL):+_TreeGetCaption(index,JUST_NAME_COL);

   origWID = p_window_id;
   p_window_id = ctltree2;
   getCheckedIndexList(auto indexList);
   len := indexList._length();
   STRHASHTAB versionList;
   STRARRAY oldVersionList;
   for (i:=0;i<len;++i) {
      curIndex := indexList[i];
      cap := _TreeGetCaption(curIndex);
      _TreeGetInfo(curIndex,auto state, auto bm1, auto bm2);
      if ( bm1 != _pic_file ) {
         continue;
      }
      filename = _TreeGetCaption(_TreeGetParentIndex(curIndex)):+_TreeGetCaption(curIndex);
      version := getVersionOfFile(filename,datestr,auto oldestVersion);
      if ( version < 0 ) {
         version = oldestVersion;
         ARRAY_APPEND(oldVersionList,filename);
      }
      versionList:[filename] = version;
   }
   if ( oldVersionList._length() ) {
      oldVersionStr := "";
      foreach (auto curFile in oldVersionList) {
         oldVersionStr :+= curFile"\n";
      }
      result := _message_box(nls("The following files do not have enough versions for the selected date.\n\n%s\n\nWould you like to view the oldest versions of the files?",oldVersionStr),"",MB_YESNO);
      if (result==IDNO) {
         foreach (curFile in oldVersionList) {
            versionList._deleteel(curFile);
         }
      }
   }
   foreach (auto curFilename => auto curVersion in versionList) {
      _HistoryDiffBackupHistoryFile(curFilename, curVersion);
   }
   p_window_id = origWID;
}

static void diffFromTopOrBottomTreeTree(int topTreeFilenameIndex =- 1)
{
   origWID := p_window_id;
   p_window_id = ctltree1;
   index := _TreeCurIndex();
   while ( _TreeGetDepth(index)==1 ) {
      index = _TreeGetPrevIndex(index);
   }
   datestr := "";
   filename := "";
   _TreeGetDateTimeStr(index, 0, datestr, "YYYY/MM/DD HH:mm:ssmmm");
   if ( topTreeFilenameIndex > 0 ) {
      filename = _TreeGetCaption(index,JUST_PATH_COL):+_TreeGetCaption(index,JUST_NAME_COL);
   } else {
      filename = getFilenameFromBottomPane();
   }

   p_window_id = origWID;

   version := getVersionOfFile(filename,datestr,auto oldestVersion);
   // Don't have to check version, we know we have this exact version
   _HistoryDiffBackupHistoryFile(filename, version);
   p_window_id = origWID;
}

int getLastActiveTreeControl()
{
   lastTreeControlWID := _GetDialogInfoHt("lastTreeControlWID");
   if (lastTreeControlWID!=null) {
      return lastTreeControlWID;
   }
   return 0;
}

void ctldiff.lbutton_up()
{
   treeWID := getLastActiveTreeControl();
   if ( treeWID!=0 ) {
      treeWID.call_event(CHANGE_LEAF_ENTER,treeWID._TreeCurIndex(),treeWID,ON_CHANGE,'W');
      return;
   }
//   diffSelectedFiles();
}

void ctlrebuildSaveLog.lbutton_up()
{
   rebuild_backup_history_log();

   origWID := p_window_id;
   p_window_id = ctltree1;
   _TreeDelete(TREE_ROOT_INDEX,'C');
   loadThisWeeksDatesIntoTree();
   p_window_id = origWID;
}

static _str selectVersionCallback(int reason, typeless user_data, typeless info=null)
{
   switch (reason) {
   case SL_ONINITFIRST:
      _nocheck _control ctl_tree;
      origWID := p_window_id;
      p_window_id = ctl_tree;
      {
         index := _TreeGetFirstChildIndex(TREE_ROOT_INDEX);
         curVersionIndex := -1;
         for (;;) {
            if (index<0) break;
            cap := _TreeGetCaption(index);
            parse cap with auto curVersion "\t" auto dateStr;
            _setDateForTreeFromVCString(index,1,dateStr);
            if ( curVersion==user_data ) {
               _TreeGetInfo(index,auto state, auto bm1, auto bm2, auto nodeFlags);
               _TreeSetInfo(index, state,  bm1,  bm2, nodeFlags|TREENODE_BOLD);
               curVersionIndex = index;
            }
            index = _TreeGetNextSiblingIndex(index);
         }
         if ( curVersionIndex > 0 ) {
            _TreeSetCurIndex(curVersionIndex);
         }
      }
      p_window_id = origWID;
      break;
   default:
      break;
   }
   return '';
}

static int restoreFileAndBuffer(_str filename,_str destFilename,int versionToRestore)
{
   // filename Has to be the current file to run the delta save (backup history)
   // operations
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   inmem := true;
   status := load_files("+b ":+filename);
   if (status) {
      inmem = false;
      status = load_files(filename);
   }
   status = DSExtractVersionToFile(filename,versionToRestore,destFilename);
   if (!status) {
      stauts := DS_CreateDelta(filename);
      if ( !status && _file_eq(filename,destFilename) ) {
         DSSetVersionComment(filename, -1, "Restore of version ":+versionToRestore); 
      }
   }
   p_window_id = origWID;

   if (status) {
      _message_box(nls(get_message(status)));
      return status;
   }

   // Check to see if the file is open
   bufInfo := buf_match(destFilename,1,'xv');
   if (bufInfo!="") {
      parse bufInfo with auto bufID auto bufFlags auto bufName;
      windowID := window_match(destFilename,1,'x');

      bfiledate := _file_date(destFilename,'B');
      if ( windowID!=0 ) {
         // If it is open and in a window, reload it in that window
         windowID._ReloadCurFile(windowID,bfiledate,false,false);
      } else {
         // If it is open but not in a window, create a temp view and reload it
         // there
         status = _open_temp_view('', auto temp_wid, auto preOpenWID, "+bi "bufID);
         temp_wid.save_pos(auto p);
         if (!status) _ReloadCurFile(temp_wid, bfiledate, false, true, null, false);
         temp_wid.restore_pos(p);
         p_window_id = preOpenWID;
      }
   }

   p_window_id = origWID;
   return 0;
}

static void restoreOneFile(int index)
{
   origWID := p_window_id;
   p_window_id = ctltree2;
   _TreeGetInfo(index, auto state, auto bm1);
#if 0 //10:14am 9/27/2016
   // We didn't used to allow restoring files that exist, but now are going to
   if ( bm1!=_pic_cvs_filem ) {
      p_window_id = origWID;
      return;
   }
#endif
   filename := getFilenameFromBottomPane();
   p_window_id = origWID;
   destFilename := filename;
   path := _file_path(filename);
   justName := _strip_filename(filename,'P');
   status := make_path(path);
   while ( status ) {
      result := _message_box(nls("Could not create path '%s'\n\nWould you like to save '%s' to another directory?",path,filename),"",MB_YESNO);
      if ( result!=IDYES ) return;

      // Default dest path to current directory
      initPath := getcwd();

      // If there is a current project, default to it's working directory
      if ( _project_name!="" ) {
         int project_handle=_ProjectHandle(_project_name);
         initPath = absolute(_ProjectGet_WorkingDir(project_handle),_file_path(_project_name));
      }

      destFilename = _OpenDialog('-new -modal',
                                 'Save As',
                                 '',     // Initial wildcards
                                 def_file_types,  // file types
                                 OFN_SAVEAS,
                                 '',      // Default extensions
                                 justName, // Initial filename
                                 initPath,      // Initial directory
                                 '',      // Reserved
                                 "Save As dialog box"
                                );
      if ( destFilename=='' ) return;

      status = _make_path(_file_path(destFilename));
      if ( !status ) break;
   }

   p_window_id = ctltree1;
   dateIndex := getDateIndex();

//   say("diffFromTopTree H"__LINE__": USERINFO datestr="datestr);
   _TreeGetDateTimeStr(dateIndex, 0, auto dateStr, "YYYY/MM/DD HH:mm:ssmmm");
//   say("diffSelectedFiles H"__LINE__": TREEGET datestr="datestr);

   p_window_id = origWID;
   curVersion := getVersionOfFile(filename,dateStr,auto oldestVersion);
   if ( curVersion<0 ) {
      // This means the version was not found. Which means there probably isn't
      // a version of the selected file that is as old as the selected date.
      // It means the version is 0, if there's something to restore, restore it.
      curVersion = 0;
   }
   STRARRAY versionList;
   status = DSListVersions(filename, versionList);
   if ( status ) return;

   result := show('-modal _backup_history_browser_version_form',filename, curVersion, versionList);
   if ( result == "" ) return;

   versionToRestore := result;
   restoreFileAndBuffer(filename,destFilename,versionToRestore);

   p_window_id = ctltree2;
   if ( !status ) {
      // Set the picture to show the file exists
      _TreeGetInfo(index,state, bm1);
      _TreeSetInfo(index, state, _pic_file);
      index = _TreeGetParentIndex(index);
      // Set all the parent pictures to reflect that the directories exist now
      for (;;) {
         if (index<=TREE_ROOT_INDEX) break;
         _TreeGetInfo(index, state, bm1);
         if ( bm1!=_pic_fldopen ) {
            _TreeSetInfo(index, state, _pic_fldopen);
         }
         index = _TreeGetParentIndex(index);
      }
   }
   p_window_id = origWID;
}

static void restoreFileVersionFromBottomPane()
{
   ctltree2.getCheckedIndexList(auto indexList);
   len := indexList._length();

#if 0 //19:31pm 8/26/2021
   numWarnings := ctltree2.accumRestoreWarnings(indexList);
   if ( numWarnings ) {
      result := _message_box(nls("%s of these files already exist.  Restoring them will replace the contents.\n\nContinue?",numWarnings),"",MB_YESNO);
      if ( result!=IDYES ) {
         return;
      }
   }
#endif

   for (i:=0;i<len;++i) {
      int useDefaultToResoreAll=0;
      restoreOneFile(indexList[i]);
   }
}

static int getVersionFromTopPane(_str selectedDateStr, STRARRAY &versionList)
{
   curVersion := -1;
   len := versionList._length();
   for (i:=len-1;i>=0;--i) {
      parse versionList[i] with auto version "\t" auto curDateStr "\t" auto curTimeStr;
   }
   for (i=0;i<len;++i) {
      parse versionList[i] with auto version "\t" auto curDateStr "\t" auto curTimeStr;
      if ( selectedDateStr==curDateStr:+" ":+curTimeStr ) {
         curVersion = version;
      }
   }
   return curVersion;
}

static bool bufferIsModified(_str filename, _str bufInfo, int existingWindowID)
{
   if ( bufInfo=="" ) return false;
   if (existingWindowID) {
      return existingWindowID.p_modify;
   }
   parse bufInfo with auto bufID auto bufFlags auto bufName;
   status := _open_temp_view('', auto tempWID, auto origWID, "+bi "bufID);
   if ( status ) return false;
   modified := p_modify;
   p_window_id = origWID;
   _delete_temp_view(tempWID);
   return modified;
}

static int restoreVersionInPlace(_str filename, int versionToRetrieve)
{
   bufInfo := buf_match(filename,1,'xv');
   existingWindowID := window_match(filename,1,'x');
   if ( bufferIsModified(filename, bufInfo, existingWindowID) ) {
      _message_box(nls("Cannot replace open modified files"));
      return VSRC_SVC_COULD_NOT_GET_LOCALLY_MODIFIED_FILES;
   }
   typeless bufID    = 0;
   typeless bufFlags = 0;
   typeless bufName  = "";

   localFileWID := 0;

   origWID := p_window_id;
   if (bufInfo=="") {
      status := _open_temp_view(filename,localFileWID,auto unused);
      if (status) return status;
      bufID = localFileWID.p_buf_id;
      localFileWID.p_DocumentName = versionToRetrieve'|'filename;
   } else {
      parse bufInfo with bufID bufFlags bufName;
      status := _open_temp_view('',localFileWID,auto unused,'+bi 'bufID);
      if (status) return status;
   }
   status := 0;

   localFileWID = p_window_id;
   extractedVersionWID := DSExtractVersion(filename, versionToRetrieve,status);
   if ( status ) return status;

   _SaveMarkersInFile(auto markerSaves);

   markid := _alloc_selection();
   top();
   _select_line(markid);
   bottom();
   status = _select_line(markid);
   if ( status ) clear_message();
   _delete_selection(markid);

   p_window_id = extractedVersionWID;
   top();
   _select_line(markid);
   bottom();
   status = _select_line(markid);
   if ( status ) clear_message();

   p_window_id = localFileWID;
   _copy_to_cursor(markid);
   _free_selection(markid);

   _str options = build_save_options(p_buf_name)" -l";
   if (isEclipsePlugin()) {
      options = "-CFE "options;
   }
   status = (int)save_file(_maybe_quote_filename(p_buf_name), options);

   if (bufInfo=="") {
      _delete_temp_view(localFileWID);
   }
   p_window_id = origWID;
   return 0;
}

static int getDateIndex()
{
   origWID := p_window_id;
   p_window_id = ctltree1;
   origIndex := index := _TreeCurIndex();
   do {

      if (index<0) break;

      while (index>0 && _TreeGetDepth(index)<FILE_DEPTH) {
         // _TreeGetPrevIndex, not _TreeGetPrevSiblingIndex, this so that we get
         // the next line that is a date/time.  Use a while loop because we could be on
         // "Older" with some empty folders in between.
         index = _TreeGetPrevIndex(index);
      }
      if ( index<0 ) {
         index = origIndex;
         // Must have been on top folder, find a child.  Again, there could be
         // empty folders
         while (index>0 && _TreeGetDepth(index)<FILE_DEPTH) {
            // _TreeGetNextIndex, not _TreeGetPrevSiblingIndex, this so that we get
            // the next line that is a date/time.  Use a while loop because we could be on
            // "Today" with some empty folders in between "Today" and the next foler
            // with a child
            index = _TreeGetNextIndex(index);
         }
      }
   } while ( false );
   p_window_id = origWID;
   return index;
}

static void restoreFileVersionFromTopPane()
{
   // Have to get the filename, can only be one item selected
   filename := getFilenameFromTopPane();
   status := DSListVersionDates(filename, auto versionList=null);
   if (status) return;

   index := getDateIndex();
   _TreeGetDateTimeStr(index, 0, auto selectedDateStr, "YYYY/MM/DD HH:mm:ssmmm");
   curVersion := getVersionFromTopPane(selectedDateStr, versionList);
   result := show('-modal _backup_history_browser_version_form',filename, curVersion, versionList);
   if ( result == "" ) return;
   versionToRestore := (int) result;

   result = _message_box(nls("Replace current version of '%s' with version %s",filename, versionToRestore),"",MB_YESNO);
   if ( result!=IDYES ) return;

   // filename Has to be the current file to run the delta save (backup history)
   // operations

   restoreFileAndBuffer(filename,filename,versionToRestore);
}

void ctlrestore.lbutton_up()
{
   treeWID := getLastActiveTreeControl();

   if ( treeWID == ctltree1 ) {
      ctltree1.restoreFileVersionFromTopPane();
   } else if ( treeWID == ctltree2 ) {
      ctltree2.restoreFileVersionFromBottomPane();
   }
}

static int accumRestoreWarnings(INTARRAY &indexList)
{
   numWarnings := 0;
   len := indexList._length();
   for (i:=0;i<len;++i) {
      filename := getFilenameFromBottomPane();
      if ( file_exists(filename) ) {
         ++numWarnings;
      }
   }
   return numWarnings;
}

static int showVersionOfFile(_str filename, int version)
{
   newWID := DSExtractVersion(filename,version,auto status);
   if ( status ) return status;
   _showbuf(newWID.p_buf_id,true,'-new -modal',filename' (Version 'version')','S',true);
   _delete_temp_view(newWID);
   return 0;
}

static void viewFileVersionFromTopPane()
{
   // Have to get the filename, can only be one item selected
   filename := getFilenameFromTopPane();
   status := DSListVersionDates(filename, auto versionList=null);
   if (status) return;
   index := getDateIndex();

   len := versionList._length();
   _TreeGetDateTimeStr(index, 0, auto selectedDateStr, "YYYY/MM/DD HH:mm:ssmmm");
   curVersion := getVersionFromTopPane(selectedDateStr, versionList);

   showVersionOfFile(filename,curVersion);
}

static void viewFileVersionFromBottomPane(int index)
{
   origWID := p_window_id;
   p_window_id = ctltree2;
   _TreeGetInfo(index, auto state, auto bm1);
   if ( bm1!=_pic_file && bm1!=_pic_cvs_filem ) {
      p_window_id = origWID;
      return;
   }
   filename := getFilenameFromBottomPane();
   p_window_id = origWID;

   p_window_id = ctltree1;
   dateIndex := getDateIndex();

   if ( dateIndex<0 ) return;

   _TreeGetDateTimeStr(dateIndex, 0, auto datestr, "YYYY/MM/DD HH:mm:ssmmm");

   curVersion := getVersionOfFile(filename,datestr,auto oldestVersion);
   if ( curVersion<0 ) {
      // This means the version was not found. Which means there probably isn't
      // a version of the selected file that is as old as the selected date.
      // It means the version is 0, if there's something to view, view it.
      curVersion = 0;
   }
   showVersionOfFile(filename,curVersion);
}

void ctlview.lbutton_up()
{
   treeWID := getLastActiveTreeControl();

   if ( treeWID == ctltree1 ) {
      ctltree1.viewFileVersionFromTopPane();
   } else if ( treeWID == ctltree2 ) {
      ctltree2.getCheckedIndexList(auto indexList);
      len := indexList._length();
      for (i:=0;i<len;++i) {
         viewFileVersionFromBottomPane(indexList[i]);
      }
   }
}

static int getVersionOfFile(_str filename,_str datestr,int &oldestVersion)
{
   status := DSListVersionDates(filename,auto list=null);
   if ( status ) {
      _message_box(nls("Could not get version list for '%s'",filename));
      return status;
   }
   len := list._length();
   se.datetime.DateTime selectedDate;
   ctltree1.getDateFromDateStr(datestr,selectedDate);
   found := false;
   foundGreater := false;
   version := "";
   lastVersion := "";
   oldestVersion = -1;
   selectedVersion := -1;
   lastSelectedVersion := -1;
   for (i:=len-1;i>=0;--i) {
      parse list[i] with version "\t" auto curDateStr "\t" auto comment;
      se.datetime.DateTime curDate;
      getDateFromDateStr(curDateStr,curDate);
      if ( curDate == selectedDate ) {
         found = true;
         selectedVersion = version;
         break;
      } else if ( curDate < selectedDate ) {
         found = true;
         selectedVersion = lastSelectedVersion;
         break;
      }
      lastSelectedVersion = selectedVersion;
#if 0 //17:35pm 8/19/2021
      if ( curDate == selectedDate ) {
         say('getVersionOfFile 200 curDate == selectedDate');
         found = true;
         selectedVersion = version;
         break;
      } else if ( selectedDate < curDate ) {
         say('getVersionOfFile selectedDate < curDate');
         found = true;
         if ( lastVersion=="" ) {
            lastVersion = 0;
         }
         version = lastVersion;
         break;
      }
      if (!found) {
         say('getVersionOfFile selectedDate.toString()='selectedDate.toString()' curDate.toString()='curDate.toString());
      }
      lastVersion = version;
      if ( oldestVersion < 0 ) {
         lastVersion = oldestVersion = (int)version;
      }
#endif
   }
   if ( !found ) {
      return -1;
   } else {
      return(int)version;
   }
}

static void getDateFromDateStr(_str datestr,se.datetime.DateTime &selectedDate)
{
   parse datestr with auto yyyy'/'auto mm'/'auto dd auto hh':' auto mins':' auto ss;
   se.datetime.DateTime dateTime((int)yyyy,(int)mm,(int)dd,(int)hh,(int)mins,(int)ss);
   selectedDate = dateTime;
}

_command void backup_history_browser() name_info(','VSARG2_REQUIRES_PRO_OR_STANDARD_EDITION)
{
   if (!_haveBackupHistory()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_OR_STANDARD_EDITION_1ARG, "Backup History");
      return;
   }
   show('-xy _backup_history_browser_form');
}

int _cbsave_BackupHistoryBrowser()
{
   fid := _find_formobj('_backup_history_browser_form','N');
   if (fid) {
      localFilename := p_buf_name;
      mostRecentFilename := DSGetArchiveFilename(localFilename, true);
      mostRecentDate := _file_date(mostRecentFilename,'B');
      todayFolderIndex := fid.ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
      if ( todayFolderIndex>=0 ) {
         lastDateIndex := fid.ctltree1._TreeGetFirstChildIndex(todayFolderIndex);
         addFlags := TREE_ADD_BEFORE;

         // This could be the first entry under "Today"
         if ( lastDateIndex<0 ) {
            addFlags = TREE_ADD_AS_CHILD;
            lastDateIndex = todayFolderIndex;
         }
         filename := _strip_filename(localFilename,'P'):+"\t":+_file_path(localFilename);
         nodeFlags := fid.ctltree1._filterRepoBrowserTreeOneFileMatches(fid.ctlfilespec.p_text,filename)? 0 : TREENODE_HIDDEN;
         newIndex := fid.ctltree1._TreeAddItem(lastDateIndex,"\t"filename,addFlags,0,0,-1,nodeFlags);
         if ( newIndex>=0 ) {
            se.datetime.DateTime dateTime;
            dateTime.fromTimeB(mostRecentDate);
            dateTime.toParts(auto year,auto month,auto day,
                             auto hour,auto minute,auto second,
                             auto milliseconds);
            fid.ctltree1._TreeSetDateTime(newIndex,0,
                                          year,month,day,
                                          hour,minute,second,
                                          milliseconds,false);
         }
      }
   }

   return 0;
}

_command void backup_history_browser_top_context_menu(_str cmdline="") name_info(','VSARG2_EXECUTE_FROM_MENU_ONLY|VSARG2_REQUIRES_PRO_EDITION)
{
   if ( !_haveBackupHistory() ) return;
   if ( cmdline=="" ) return;

   command := parse_file(cmdline);
   switch ( command ) {
   case "copypath":
      {
         index := ctltree1._TreeCurIndex();
         if ( index<0 ) return;
         filename := ctltree1._TreeGetCaption(index, JUST_PATH_COL):+ctltree1._TreeGetCaption(index, JUST_NAME_COL);
         push_clipboard(filename);
         return;
      }
   }
}

_command void backup_history_browser_bottom_context_menu(_str cmdline="") name_info(','VSARG2_EXECUTE_FROM_MENU_ONLY|VSARG2_REQUIRES_PRO_EDITION)
{
   if ( !_haveBackupHistory() ) return;
   if ( cmdline=="" ) return;

   index := _TreeCurIndex();
   if ( index<0 ) return;

   _TreeGetInfo(index,auto state, auto bm1);
   onFolder := bm1==_pic_fldopen;

   command := parse_file(cmdline);
   switch ( command ) {
   case "copypath":
      {
         filename := "";
         if ( onFolder ) {
            filename = _TreeGetCaption(index);
         } else {
            filename = _TreeGetCaption(_TreeGetParentIndex(index)):+_TreeGetCaption(index);
         }
         push_clipboard(filename);
         return;
      }
   }
}

void ctltree1.rbutton_up,context()
{
   index := _TreeCurIndex();
   if ( index<0 ) return;

   int MenuIndex=find_index("_backup_history_browser_top_context_menu",oi2type(OI_MENU));
   int menu_handle=_mdi._menu_load(MenuIndex,'P');

   depth := _TreeGetDepth(index);

   if ( depth != FILE_DEPTH  ) {
      _menu_set_state(menu_handle,0,MF_GRAYED,'P');
   }

   int x,y;
   mou_get_xy(x,y);

   _menu_show(menu_handle,VPM_RIGHTBUTTON,x-1,y-1);
   _menu_destroy(menu_handle);
}

void ctltree2.rbutton_up,context()
{
   index := _TreeCurIndex();
   if ( index<0 ) return;

   int MenuIndex=find_index("_backup_history_browser_bottom_context_menu",oi2type(OI_MENU));
   int menu_handle=_mdi._menu_load(MenuIndex,'P');

   _TreeGetInfo(index,auto state, auto bm1);
   if ( bm1==_pic_fldopen ) {
      // This is a path, but we can stil copy it
      _menu_set_state(menu_handle,0,0,'P',"Copy path to clipboard");
   }

   int x,y;
   mou_get_xy(x,y);

   _menu_show(menu_handle,VPM_RIGHTBUTTON,x-1,y-1);
   _menu_destroy(menu_handle);
}


defeventtab _backup_history_browser_version_form;

void ctlok.on_create(_str filename="", typeless selectedVersion=-1, STRARRAY &versionList=null)
{
   _SetDialogInfoHt("filename",filename);
   p_active_form.p_caption = "Choose a version of ":+filename:+" to restore";

   origWID := p_window_id;
   p_window_id = ctltree1;
   col0Width := p_width intdiv 3;
   col1Width := 2*(p_width intdiv 3);
   _TreeSetColButtonInfo(0, col0Width,-1,-1,"Version");
   _TreeSetColButtonInfo(1, -1,-1,-1,"Date");
   _TreeSizeColumnToContents(1);
   len := versionList._length();
   flags := 0;
   curIndex := -1;

   for (i:=len-1;i>=0;--i) {
      parse versionList[i] with auto curVersion "\t" auto date "\t" auto time "\t" .;
      cap := curVersion:+"\t"date:+" ":+time;
      flags = 0;
      if ( curVersion==selectedVersion ) {
         flags |= TREENODE_BOLD;
      }
      index := _TreeAddItem(TREE_ROOT_INDEX,cap, TREE_ADD_AS_CHILD,0,0,-1,flags);
      if ( flags!=0 ) {
         curIndex = index;
      }
      _setDateForTreeFromVCString(index,1,date:+" ":+time);
   }
   if (curIndex > 0) {
      _TreeSetCurIndex(curIndex);
   }
   p_window_id = origWID;
}

void ctlview.lbutton_up()
{
   filename := _GetDialogInfoHt("filename");
   if ( filename==null ) return;

   index := ctltree1._TreeCurIndex();
   if ( index<0 ) return;

   version := ctltree1._TreeGetCaption(index,0);
   if ( !isinteger(version) ) {
      _message_box(nls("%s is not a valid version number",version));
      return;
   }
   showVersionOfFile(filename,(int)version);
}

int ctlok.lbutton_up()
{
   origWID := p_window_id;
   p_window_id = ctltree1;

   version := (int)_TreeGetCaption(_TreeCurIndex(),0);

   p_window_id = origWID;
   p_active_form._delete_window(version);
   return version;
}
