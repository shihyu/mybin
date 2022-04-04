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
#include 'slick.sh'
#pragma option(pedantic,on)
#region Imports
#include "slick.sh"
#include "svc.sh"
#import "clipbd.e"
#import "cvsutil.e"
#import "diff.e"
#import "dirlist.e"
#import "diffprog.e"
#import "fileman.e"
#import "files.e"
#import "filewatch.e"
#import "guicd.e"
#import "guiopen.e"
#import "help.e"
#import "main.e"
#import "menu.e"
#import "mprompt.e"
#import "listbox.e"
#import "picture.e"
#import "ptoolbar.e"
#import "seltree.e"
#import "sellist2.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "svcautodetect.e"
#import "svc.e"
#import "svccomment.e"
#import "svcupdate.e"
#import "treeview.e"
#import "vc.e"
#import "wkspace.e"
#import "se/vc/IVersionControl.e"
#require "se/lang/api/ExtensionSettings.e"
#endregion

using se.vc.IVersionControl;

static int copyFilesToShelf(ShelfInfo &shelf,_str modsRootPath)
{
   _maybe_append_filesep(modsRootPath);
   
   len := shelf.fileList._length();
   for (i:=0;i<len;++i) {
      destFilename := modsRootPath:+shelf.fileList[i].filename;
      destPath := _file_path(destFilename);

      if ( !path_exists(destPath) ) make_path(destPath);

      status := copy_file(shelf.localRoot:+shelf.fileList[i].filename,destFilename);
      if ( status ) {
         _message_box(nls("Could not copy '%s' to '%s'",shelf.fileList[i].filename,destFilename));
         return status;
      }
   }
   return 0;
}

static int getCleanFilesToShelf(IVersionControl *pInterface,
                                ShelfInfo &shelf,
                                _str baseRootPath)
{
   _maybe_append_filesep(baseRootPath);
   
   len := shelf.fileList._length();
   for (i:=0;i<len;++i) {
      base_rev := shelf.fileList[i].revision;
      if ( base_rev == "" ) continue;
      if (pInterface->getBaseRevisionSpecialName() != "") {
         base_rev = pInterface->getBaseRevisionSpecialName();
      }

      status := pInterface->getFile(shelf.localRoot:+shelf.fileList[i].filename,base_rev,auto newFileWID=0);
      // If we get a status the file may not exist in version control, but this
      // is actually OK.

      destFilename := baseRootPath:+shelf.fileList[i].filename;
      destPath := _file_path(destFilename);

      if ( !path_exists(destPath) ) make_path(destPath);

      status = newFileWID._save_file('+o '_maybe_quote_filename(destFilename));
      _delete_temp_view(newFileWID);
   }
   return 0;
}

static int writeManifestZipFile(_str zipFilename,ShelfInfo &shelf)
{
   status := writeManifestZipFileToTemp(zipFilename,shelf,auto tempFilename);
   if ( !status ) {
      _ZipClose(zipFilename);
      STRARRAY tempSourceArray,tempDestArray;
      tempSourceArray[0] = tempFilename;
      tempDestArray[0]   = "manifest.xml";
      status = _ZipAppend(zipFilename,tempSourceArray,auto zipStatus,tempDestArray);
      delete_file(tempFilename);
   }

   return status;
}

static int writeManifestZipFileToTemp(_str zipFilename,ShelfInfo &shelf,_str &tempFilename)
{
   tempFilename = "";
   manifestFilename := zipFilename:+FILESEP:+"manifest.xml";
   xmlhandle := _xmlcfg_create(manifestFilename,VSENCODING_UTF8,VSXMLCFG_CREATE_IF_EXISTS_CLEAR);
   if ( xmlhandle<0 ) {
      return xmlhandle;
   }
   shelfNode := _xmlcfg_add(xmlhandle,TREE_ROOT_INDEX,"Shelf",VSXMLCFG_NODE_ELEMENT_START,VSXMLCFG_ADD_AS_CHILD);
   _xmlcfg_add_attribute(xmlhandle,shelfNode,"Name",shelf.shelfName);
   _xmlcfg_add_attribute(xmlhandle,shelfNode,"LocalRoot",stranslate(shelf.localRoot,'/',FILESEP));
   _xmlcfg_add_attribute(xmlhandle,shelfNode,"VCSystemName",shelf.VCSystemName);

   commentArray := shelf.commentArray;
   addComment(xmlhandle,shelfNode,commentArray);

   STRARRAY relativeFileList;
   foreach (auto curFileInfo in shelf.fileList) {
      ARRAY_APPEND(relativeFileList,relative(curFileInfo.filename,shelf.localRoot));
   }

   filesNode := _xmlcfg_add(xmlhandle,shelfNode,"Files",VSXMLCFG_NODE_ELEMENT_START,VSXMLCFG_ADD_AS_CHILD);
   len := shelf.fileList._length();
   for (i:=0;i<len;++i) {
       curNode := _xmlcfg_add(xmlhandle,filesNode,"File",VSXMLCFG_NODE_ELEMENT_START,VSXMLCFG_ADD_AS_CHILD);
       _xmlcfg_set_attribute(xmlhandle,curNode,"N",stranslate(relativeFileList[i],'/',FILESEP));
       _xmlcfg_set_attribute(xmlhandle,curNode,"V",shelf.fileList[i].revision);
       commentArray = shelf.fileList[i].commentArray;
       addComment(xmlhandle,curNode,commentArray);
   }
   tempFilename = mktemp();
   status := _xmlcfg_save(xmlhandle,-1,VSXMLCFG_SAVE_ONE_LINE_IF_ONE_ATTR,tempFilename);
   return status;
}

static void addComment(int xmlhandle,int nodeIndex,STRARRAY &commentArray)
{
   commentLen := commentArray._length();
   comment := "";
   for (j:=0;j<commentArray._length();++j) {
      comment :+= commentArray[j]"\n";
   }
   comment = substr(comment,1,length(comment)-1);
   commentIndex := _xmlcfg_add(xmlhandle,nodeIndex,comment,VSXMLCFG_NODE_PCDATA,VSXMLCFG_ADD_AS_CHILD);
}

static const SHELVES_PATH= "shelves";

_str svc_get_shelf_base_path()
{
   return _ConfigPath():+SHELVES_PATH:+FILESEP;
}

bool svc_shelf_exists(_str shelfName)
{
   shelfPath := svc_get_shelf_base_path():+shelfName'.zip';
   return file_exists(shelfPath);
}

defeventtab _svc_shelf_review_form;
void ctlclose.on_create()
{
   sizeBrowseButtonToTextBox(ctlLocalRoot.p_window_id, ctlbrowse.p_window_id);
}

defeventtab _svc_shelf_form;

void ctlclose.on_create(_str zipFilename="",ShelfInfo *pshelf=null,bool *pPromptToRefresh=null,bool *pRefreshZipFile=null)
{
   len := pshelf->fileList._length();
   int pathTable:[];
   STRHASHTAB versionTable;
   STRHASHTABARRAY commentTable;
   commentTable:[PATHSEP] = pshelf->commentArray;
   for (i:=0;i<len;++i) {
      relFilename:= stranslate(pshelf->fileList[i].filename,FILESEP,'/');
      curPath := stranslate(_file_path(pshelf->fileList[i].filename),FILESEP,'/');
      pathIndex := ctltree1._SVCGetPathIndex(curPath,"",pathTable,_pic_fldopen,_pic_fldopen);
      if ( pathIndex>=0 ) {
         ctltree1._TreeAddItem(pathIndex,_strip_filename(relFilename,'P'),TREE_ADD_AS_CHILD,_pic_file,_pic_file,-1,0,relFilename);
      }
      versionTable:[relFilename] = pshelf->fileList[i].revision;
      commentTable:[_file_case(relFilename)] = pshelf->fileList[i].commentArray;
   }
   ctledit1._lbclear();
   ctledit2._lbclear();

   p_active_form.p_caption = zipFilename;

   _SetDialogInfoHt("pathTable",pathTable);
   _SetDialogInfoHt("zipFilename",zipFilename);
   _SetDialogInfoHt("pshelf",pshelf);

   _SetDialogInfoHt("commentTable",commentTable);
   _SetDialogInfoHt("versionTable",versionTable);
   _SetDialogInfoHt("pPromptToRefresh",pPromptToRefresh);
   _SetDialogInfoHt("pRefreshZipFile",pRefreshZipFile);
   ctlrootPathLabel.p_caption = SVC_ROOT_PATH_CAPTION:+pshelf->localRoot;
   ctledit1.fillInEditor(commentTable:[PATHSEP]);
}

void ctlok.lbutton_up()
{
   ctltree1.call_event(CHANGE_SELECTED,ctltree1._TreeCurIndex(),ctltree1,ON_CHANGE,'W');
   // We're using a pointer to a shelf.  Certain things are already filled in
   // (most notably localRoot).
   ShelfInfo *pshelf = _GetDialogInfoHt("pshelf");
   commentTable := _GetDialogInfoHt("commentTable");
   versionTable := _GetDialogInfoHt("versionTable");
   pPromptToRefresh := _GetDialogInfoHt("pPromptToRefresh");
   pRefreshZipFile := _GetDialogInfoHt("pRefreshZipFile");

   ctltree1.getFileListFromTree(auto relFileList);
   ShelfFileInfo fileList[];
   pshelf->commentArray = commentTable:[PATHSEP];

   len := relFileList._length();
   for (i:=0;i<len;++i) {
      ShelfFileInfo cur;
      cur.filename = relFileList[i];
      cur.commentArray = commentTable:[_file_case(cur.filename)];
      ARRAY_APPEND(fileList,cur);
   }
   pshelf->fileList = fileList;
   if ( pPromptToRefresh!=null && pRefreshZipFile!=null && *pPromptToRefresh==true ) {
      result := _message_box(nls("Refresh source files?"),"",MB_YESNO);
      *pRefreshZipFile = (result==IDYES);
   }
   p_active_form._delete_window(0);
}

void ctladd.lbutton_up()
{
   ShelfInfo *pshelf = _GetDialogInfoHt("pshelf");
   manifestFilename := _GetDialogInfoHt("manifestFilename");
   versionTable := _GetDialogInfoHt("versionTable");
   pathTable := _GetDialogInfoHt("pathTable");
   _control ctlrootPathLabel;

   // SHOW OPEN DIALOG, LET USER PICK FILE. ADD TO VERSION TABLE, 
   // ADD TO TREE, ETC
   result := _OpenDialog('-modal',
                         'Select file to add',// Dialog Box Title
                         '',                  // Initial Wild Cards
                         '',
                         OFN_FILEMUSTEXIST);
   if ( result=="" ) {
      return;
   }
   filename := strip(result,'B','"');

   zipFilename := p_active_form.p_caption;
   status := svc_add_controlled_file_to_shelf(zipFilename,filename);
   if ( !status ) {
      origWID := p_window_id;
      p_window_id = ctltree1;
      childIndex := _TreeGetFirstChildIndex(TREE_ROOT_INDEX);
      if (childIndex>0) {
         pathTable:[_TreeGetCaption(childIndex)] = childIndex;
      }
      index := _SVCGetPathIndex(_file_path(filename),stranslate(pshelf->localRoot,FILESEP,'/'),pathTable);
      if ( index > 0 ) {
         _TreeAddItem(index,_strip_filename(filename,'P'),TREE_ADD_AS_CHILD,_pic_file,_pic_file,-1);
      }
      p_window_id = origWID;
   }
}

static void getFileListFromTree(STRARRAY &relativeFileList,int index = TREE_ROOT_INDEX,_str path="")
{
   index = _TreeGetFirstChildIndex(index);
   for (;;) {
      if ( index<0 ) break;
      _TreeGetInfo(index,auto state,auto bm1,auto bm2);
      cap := _TreeGetCaption(index);
      if ( bm1==_pic_file ) {
         if (_TreeGetParentIndex(index)==TREE_ROOT_INDEX) {
            ARRAY_APPEND(relativeFileList,path:+cap);
         } else {
            ARRAY_APPEND(relativeFileList,_TreeGetCaption(_TreeGetParentIndex(index)):+path:+cap);
         }
      }
      index = _TreeGetNextIndex(index);
   }
}

void ctltree1.on_change(int reason,int index)
{
   inOnChange := _GetDialogInfoHt("inOnChange");
   if ( inOnChange==1 ) return;
   _SetDialogInfoHt("inOnChange",1);

   switch ( reason ) {
   case CHANGE_SELECTED:
      _TreeGetInfo(index,auto state,auto bm1);
      if ( bm1 != _pic_file ) {
         ctledit2.p_enabled = ctledit1.p_prev.p_enabled = false;
         _SetDialogInfoHt("lastSelected",index);

         commentTable := _GetDialogInfoHt("commentTable");
         STRARRAY commentArray;
         ctledit1.getCommentFromEditor(commentArray);
         commentTable:[PATHSEP] = commentArray;
         _SetDialogInfoHt("commentTable",commentTable);

      } else {
         ctledit2.p_enabled = ctledit1.p_prev.p_enabled = true;
         commentTable := _GetDialogInfoHt("commentTable");
         lastIndex := _GetDialogInfoHt("lastSelected");
         if ( lastIndex!=null ) {
            lastWholePath := _TreeGetUserInfo(lastIndex);

            STRARRAY commentArray;
            ctledit1.getCommentFromEditor(commentArray);
            commentTable:[PATHSEP] = commentArray;

            commentArray = null;

            ctledit2.getCommentFromEditor(commentArray);
            commentTable:[lastWholePath] = commentArray;
            _SetDialogInfoHt("commentTable",commentTable);
         }
         wholePath := _TreeGetUserInfo(index);
         wid := p_window_id;
         ctledit1.fillInEditor(commentTable:[PATHSEP]);
         ctledit2.fillInEditor(commentTable:[wholePath]);
         p_window_id = wid;
         _SetDialogInfoHt("lastSelected",index);
      }
   }
   _SetDialogInfoHt("inOnChange",0);
}

static void getCommentFromEditor(STRARRAY &commentArray)
{
   top();up();
   while (!down()) {
      get_line(auto curLine);
      ARRAY_APPEND(commentArray,curLine);
   }
}

static void fillInEditor(STRARRAY &commentArray)
{
   _lbclear();
   len := commentArray._length();
   for (i:=0;i<len;++i) {
      insert_line(commentArray[i]);
   }
}

void _svc_shelf_form.on_resize()
{
   clientWidth  := _dx2lx(SM_TWIP,p_active_form.p_client_width);
   clientHeight := _dy2ly(SM_TWIP,p_active_form.p_client_height);
   xbuffer := ctlrootPathLabel.p_x;
   ybuffer := ctlrootPathLabel.p_y;

   treeWidth := (clientWidth intdiv 3) - xbuffer;
   ctltree1.p_width = treeWidth;

   treeHeight := clientHeight - (ctlrootPathLabel.p_height+ctlclose.p_height+(4*ybuffer));
   ctltree1.p_height = treeHeight;
   ctlok.p_y = ctladd.p_y = ctlclose.p_y = ctltree1.p_y_extent+ybuffer;

   editorHeight := (ctltree1.p_height - ctledit2.p_prev.p_height) intdiv 2;
   ctledit1.p_height = editorHeight;
   ctledit2.p_prev.p_y = ctledit1.p_y_extent+ybuffer;
   ctledit2.p_y = ctledit2.p_prev.p_y_extent+ybuffer;
   ctledit2.p_height = editorHeight-ybuffer;

   editX := ctltree1.p_x_extent + xbuffer;
   ctledit1.p_x = ctledit1.p_prev.p_x = ctledit2.p_x = ctledit2.p_prev.p_x = editX;

   ctledit1.p_width = ctledit2.p_width = clientWidth - (treeWidth+(3*xbuffer));

   ShelfInfo *pshelf = _GetDialogInfoHt("pshelf");
   ctlrootPathLabel.p_caption = SVC_ROOT_PATH_CAPTION:+ctlrootPathLabel._ShrinkFilename(pshelf->localRoot,treeWidth-ctlrootPathLabel._text_width("Root path:"));
}

static int svcUnshelve(_str manifestFilename,_str unhelveRootDir)
{
   xmlhandle := _xmlcfg_open(manifestFilename,auto status,VSXMLCFG_OPEN_ADD_PCDATA);
   if ( xmlhandle<0 ) {
      return status;
   }
   _xmlcfg_close(xmlhandle);
   return 0;
}

// Set to true if we loaded the shelves and there were none.
static bool  gNoShelves = false;

static void svc_shelf_name_append(_str shelfName)
{
   len := def_svc_all_shelves._length();
   for ( i:=0;i<len;++i ) {
      if ( _file_eq(def_svc_all_shelves[i], shelfName) ) {
         return;
      }
   }
   def_svc_all_shelves :+= shelfName;
   _config_modify_flags(CFGMODIFY_DEFVAR);
}

int svc_shelf_name_get_count()
{
   if ( def_svc_all_shelves!=null && def_svc_all_shelves._length()==0 ) {
      return 0;
   }
   return def_svc_all_shelves._length();
}

void svc_shelf_name_remove(_str filename)
{
   INTARRAY delList;
   len := svc_shelf_name_get_count();
   for ( i:=0;i<len;++i ) {
      if ( _file_eq(filename,def_svc_all_shelves[i]) ) {
         ARRAY_APPEND(delList,i);
      }
   }
   removed := false;
   len = delList._length();
   for ( i=len;i>0;--i ) {
      def_svc_all_shelves._deleteel(delList[i-1]);
      removed = true;
   }
   if ( removed ) {
      _config_modify_flags(CFGMODIFY_DEFVAR);
   }
}

void svc_shelf_name_insert(int index,_str filename)
{
   def_svc_all_shelves._insertel(filename,index);
   _config_modify_flags(CFGMODIFY_DEFVAR);
}

static void svc_shelf_init()
{
   def_svc_all_shelves._makeempty();
   _config_modify_flags(CFGMODIFY_DEFVAR);
}

_str svc_get_shelf_name_from_index(int index)
{
   return def_svc_all_shelves[index];
}

void svcEnumerateShelves(bool loadFromDisk=false)
{
   // If the user specified load from disk or we have no shelves loaded, go 
   // look for them.
   if ( loadFromDisk || (svc_shelf_name_get_count()==0 && !gNoShelves) ) {
      svc_shelf_init();
      gNoShelves = false;
      shelfBasePath := svc_get_shelf_base_path();
      for (ff:=1;;ff=0) {
         shelf := file_match(_maybe_quote_filename(shelfBasePath'*.zip'),ff);
         if ( shelf=="" ) {
            break;
         }
         curManifestFilename := shelf:+FILESEP:+"manifest.xml";
         svc_shelf_name_append(shelf);
      }

      userShelfList := def_svc_user_shelves;
      for (;;) {
         curShelf := parse_file(userShelfList);
         if ( curShelf=="" ) break;
         if ( file_exists(curShelf) ) {
            svc_shelf_name_append(curShelf);
         }
      }

      if ( svc_shelf_name_get_count()==0 ) gNoShelves = true;
   }
   _config_modify_flags(CFGMODIFY_DEFVAR);
}

_command void svc_list_shelves() name_info(','VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return;
   }
   if ( svc_shelf_name_get_count()==0 ) {
      svcEnumerateShelves();
   }
   show('-modal _svc_shelf_list_form');
}


_command void svc_open_shelf(_str shelfPath="") name_info(FILENEW_ARG','VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return;
   }

   result := "";
   if (file_exists(shelfPath) && get_extension(shelfPath) == "zip") {
      result = shelfPath;
   } else {
      if (shelfPath == "") {
         shelfPath = svc_get_shelf_base_path();
      }
      result = _OpenDialog('-modal',
                           'Select shelf file to open',// Dialog Box Title
                           '*.zip',                    // Initial Wild Cards
                           'Zip Files (*.zip)',
                           OFN_FILEMUSTEXIST,
                           "", "", shelfPath);
   }
   if ( result=="" ) {
      return;
   }
   zipFilename := strip(result,'B','"');
   status := _open_temp_view(zipFilename"/manifest.xml",auto tempWID,auto origWID);
   if ( status ) {
      _message_box("This is not a valid shelf file");
      return;
   }
   p_window_id = origWID;
   _delete_temp_view(tempWID);

   loadShelf(zipFilename,auto shelf);
#if 0 //11:19am 8/2/2019
   if ( lowcase(shelf.VCSystemName)!=lowcase(svc_get_vc_system()) ) {
      _message_box(nls("You cannot unshelve this because it was shelved from '%s' and the current version control system is '%s'",shelf.VCSystemName,svc_get_vc_system()));
      return;
   }
#endif

   // compose prompt for directory to unshelf to
   unshelf_prompt := nls("Do you wish to unshelve to this directory?");
   if ( !path_exists(shelf.localRoot) ) {
      unshelf_prompt = nls("Local root '%s' does not exist<br>You must unshelve to a different directory",shelf.localRoot);
   }

   // retrieve new directory name
   result = textBoxDialog(nls("Unshelve Files To:"),
                          0,      // flags,
                          0,      // textbox width
                          "",     // help item
                          "OK,Cancel:_cancel\t-html "unshelf_prompt,
                          "",     // retrieve name
                          "-bd Directory:"shelf.localRoot);  // prompt
   if (result==COMMAND_CANCELLED_RC) return;
   shelf.localRoot = strip(_param1,'B','"');
   _maybe_append_filesep(shelf.localRoot);

   show('-modal _svc_unshelve_form',shelf,zipFilename);
}

static _str getFileStatusString(int curFileStatus)
{
   fileStatusString := "";
   if (curFileStatus&SVC_STATUS_SCHEDULED_FOR_ADDITION) {
      fileStatusString = "added for addition";
   }
   if (curFileStatus&SVC_STATUS_SCHEDULED_FOR_DELETION) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "scheduled for addition";
   }
   if (curFileStatus&SVC_STATUS_MODIFIED) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "locally modified";
   }
   if (curFileStatus&SVC_STATUS_CONFLICT) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "in conflict";
   }
   if (curFileStatus&SVC_STATUS_IGNORED) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "ignored";
   }
   if (curFileStatus&SVC_STATUS_MISSING) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "missing";
   }
   if (curFileStatus&SVC_STATUS_NEWER_REVISION_EXISTS) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "out of date";
   }
   if (curFileStatus&SVC_STATUS_TREE_ADD_CONFLICT) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "in tree conflict";
   }
   if (curFileStatus&SVC_STATUS_TREE_DEL_CONFLICT) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "in delete conflict";
   }
   if (curFileStatus&SVC_STATUS_DELETED) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "deleted";
   }
   if (curFileStatus&SVC_STATUS_UNMERGED) {
      if ( fileStatusString!="" ) fileStatusString :+= " and is ";
      fileStatusString :+= "unmerged";
   }
   return fileStatusString;
}

static int loadShelf(_str zipFilename,ShelfInfo &shelf)
{
   manifestFilename := zipFilename:+FILESEP:+"manifest.xml";
   xmlhandle := _xmlcfg_open(manifestFilename,auto status,VSXMLCFG_OPEN_ADD_PCDATA);
   if ( xmlhandle<0 ) return status;
   index := _xmlcfg_find_simple(xmlhandle,"/Shelf");
   if ( index>=0 ) {
      shelf.shelfName = _xmlcfg_get_attribute(xmlhandle,index,"Name");
      shelf.localRoot = _xmlcfg_get_attribute(xmlhandle,index,"LocalRoot");
      shelf.VCSystemName = _xmlcfg_get_attribute(xmlhandle,index,"VCSystemName");
      shelf.localRoot = stranslate(shelf.localRoot, FILESEP, FILESEP2);

      // Get and save the comment for the shelf itself
      commentNode := _xmlcfg_get_first_child(xmlhandle,index);
      getComment(xmlhandle,commentNode,shelf.commentArray);
   }
   _xmlcfg_find_simple_array(xmlhandle,"/Shelf/Files/File",auto indexArray);


   baseDir := _file_path(manifestFilename):+"base":+FILESEP;
   modsDir := _file_path(manifestFilename):+"mods":+FILESEP;
   len := indexArray._length();
   for (i:=0;i<len;++i) {
      ShelfFileInfo temp;
      temp.filename = _xmlcfg_get_attribute(xmlhandle,(int)indexArray[i],"N");
      temp.revision = _xmlcfg_get_attribute(xmlhandle,(int)indexArray[i],"V");
      temp.baseFile = baseDir:+temp.filename;
      temp.modFile  = modsDir:+temp.filename;
      temp.filename = stranslate(temp.filename, FILESEP, FILESEP2);

      // Get and save the comment for each file
      commentNode := _xmlcfg_get_first_child(xmlhandle,(int)indexArray[i]);
      getComment(xmlhandle,commentNode,temp.commentArray);
      ARRAY_APPEND(shelf.fileList,temp);
   }
   _xmlcfg_close(xmlhandle);

   return status;
}

static void getComment(int xmlhandle,int nodeIndex,STRARRAY &commentArray)
{
   if ( nodeIndex>=0 ) {
      comment := strip(_xmlcfg_get_value(xmlhandle,nodeIndex));
      for (;;) {
         parse comment with auto cur "\n" comment;
         if ( cur=="" ) break;
         if ( cur!="\r" ) {
            ARRAY_APPEND(commentArray,strip(cur));
         }
      }
   }
}

static _str getShelfTitle(_str manifestFilename)
{
   status := _open_temp_view(manifestFilename,auto manifestWID,auto origWID);
   xmlhandle := _xmlcfg_open_from_buffer(manifestWID,status,VSXMLCFG_OPEN_ADD_PCDATA);
   nodeIndex := _xmlcfg_get_first_child(xmlhandle,TREE_ROOT_INDEX);
   shelfTitle := "";
   if (nodeIndex>=0) {
      shelfTitle = _xmlcfg_get_attribute(xmlhandle,nodeIndex,"Name");
   }
   _xmlcfg_close(xmlhandle);
   return shelfTitle;
}

static _str getShelfLocalRoot(_str manifestFilename)
{
   xmlhandle := _xmlcfg_open(manifestFilename,auto status,VSXMLCFG_OPEN_ADD_PCDATA);
   nodeIndex := _xmlcfg_get_first_child(xmlhandle,TREE_ROOT_INDEX);
   shelfRoot := "";
   if (nodeIndex>=0) {
      shelfRoot = _xmlcfg_get_attribute(xmlhandle,nodeIndex,"LocalRoot");
      shelfRoot = stranslate(shelfRoot, FILESEP, FILESEP2);
   }
   _xmlcfg_close(xmlhandle);
   return shelfRoot;
}

defeventtab _svc_unshelve_form;

void ctlclose.on_create(ShelfInfo shelf=null,_str zipFilename="")
{
   if ( shelf==null ) return;
   IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
   if ( pInterface==null ) return;

   _SetDialogInfoHt("shelf",shelf);
   p_active_form.p_caption = "Unshelve ":+shelf.shelfName;

   // Initially, we will assume we are unshelving back where we shelved from
   _SetDialogInfoHt("localRoot",stranslate(shelf.localRoot,FILESEP,'/'));
   _SetDialogInfoHt("zipFilename",zipFilename);
   setLocalRootCaption();
   addUnshelveFilesToTree();
   ctlresolve.p_enabled = false;
   ctlunshelve.p_enabled = false;
   ctlcheckForConflicts.call_event(ctlcheckForConflicts,LBUTTON_UP);
}

void ctlclose.on_destroy()
{
   STRHASHTAB fileTab = _GetDialogInfoHt("fileTab");
   foreach (auto curTempFile => auto curFile in fileTab) {
      if ( substr(curFile,1,1)=='>' ) {
         delete_file(substr(curFile,2));
      }
   }
}

static void addUnshelveFilesToTree()
{
   localRoot := _GetDialogInfoHt("localRoot");
   ShelfInfo shelf = _GetDialogInfoHt("shelf");

   IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
   if ( pInterface==null ) return;
   origWID := p_window_id;
   p_window_id = ctltree1;

   _TreeDelete(TREE_ROOT_INDEX,'C');
   int pathIndexes:[]=null;
   rootPathIndex := _TreeAddItem(TREE_ROOT_INDEX,localRoot,TREE_ADD_AS_CHILD,_pic_fldopen,_pic_fldopen);
   _SVCSeedPathIndexes(localRoot,pathIndexes,rootPathIndex);
   len := shelf.fileList._length();
   numFiles := 0;
   for (i:=0;i<len;++i) {
      curFile := shelf.fileList[i];

      curFile.filename = stranslate(curFile.filename,FILESEP,'/');
      curFile.baseFile = stranslate(curFile.baseFile,FILESEP,'/');
      curFile.modFile = stranslate(curFile.modFile,FILESEP,'/');

      curFilename := localRoot:+curFile.filename;
      // Check to see if the file is absolute
      if ( substr(curFile.filename,2,1)==':' ||  substr(curFile.filename,1,1)=='/') {
         curFilename = curFile.filename;
      }
      curPath     := _file_path(curFilename);
      pathIndex := _SVCGetPathIndex(curPath,"",pathIndexes,_pic_fldopen,_pic_fldopen,FILESEP,1,0);
      nodeIndex := _TreeAddItem(pathIndex,_strip_filename(curFilename,'P'),TREE_ADD_AS_CHILD,_pic_file,_pic_file,TREE_NODE_COLLAPSED);
      ++numFiles;

      _SetDialogInfoHt("baseFilename:"nodeIndex,curFile.baseFile);

      _SetDialogInfoHt("modsFilename:"nodeIndex,curFile.modFile);

      _SetDialogInfoHt("curFilename:"nodeIndex,curFilename);

      if ( curFile.revision!="" ) {
         _TreeAddItem(nodeIndex,_strip_filename(curFilename,'P')' (base - clean version 'curFile.revision' from shelf)',TREE_ADD_AS_CHILD,_pic_file,_pic_file,TREE_NODE_LEAF,0,curFile.baseFile);
         _TreeAddItem(nodeIndex,_strip_filename(curFilename,'P')' (rev1 - modified version 'curFile.revision' from shelf)',TREE_ADD_AS_CHILD,_pic_file,_pic_file,TREE_NODE_LEAF,0,curFile.modFile);
         _TreeAddItem(nodeIndex,_strip_filename(curFilename,'P')' (rev2 - local file in '_strip_filename(curFilename,'N')')',TREE_ADD_AS_CHILD,_pic_file,_pic_file,TREE_NODE_LEAF,0,curFile.revision);
      } else {
         if ( file_exists(curFilename) ) {
            _TreeAddItem(nodeIndex,_strip_filename(curFilename,'P')' (local version 'curFile.revision')',TREE_ADD_AS_CHILD,_pic_file,_pic_file,TREE_NODE_LEAF,0,curFilename);
            _TreeAddItem(nodeIndex,_strip_filename(curFilename,'P')' (shelved version 'curFile.revision')',TREE_ADD_AS_CHILD,_pic_file,_pic_file,TREE_NODE_LEAF,0,curFile.modFile);
         } else {
            index := _TreeAddItem(nodeIndex,_strip_filename(curFilename,'P')' (shelved version 'curFile.revision')',TREE_ADD_AS_CHILD,_pic_file,_pic_file,TREE_NODE_LEAF,0,curFile.modFile);
         }
      }
   }
   _SetDialogInfoHt("numFiles",numFiles);
   _SetDialogInfoHt("resolvedFiles",0);
   p_window_id = origWID;
}

void _svc_unshelve_form.on_resize()
{
   labelWID := ctltree1.p_prev;
   clientWidth  := _dx2lx(SM_TWIP,p_active_form.p_client_width);
   clientHeight := _dy2ly(SM_TWIP,p_active_form.p_client_height);
   xbuffer := ctlLocalRoot.p_x;
   ybuffer := ctlLocalRoot.p_y;

   ctltree1.p_width = clientWidth - (2*xbuffer);
   ctltree1.p_y = labelWID.p_y_extent+ybuffer;
   ctltree1.p_height = clientHeight - (ctlcheckForConflicts.p_height+ctltree1.p_y+(3*ybuffer));
   ctlhelp.p_y = ctlunshelve.p_y = ctlclose.p_y = ctlcheckForConflicts.p_y = ctlresolve.p_y = ctltree1.p_y_extent + ybuffer;

   buttonBuffer := ctlcheckForConflicts.p_x-ctlclose.p_x_extent;

//   ctlresolve.p_x = ctlcheckForConflicts._ControlExtentX()+buttonBuffer;
//   ctlunshelve.p_x = ctlresolve._ControlExtentX()+buttonBuffer;

   // For the local root label, set the width, but call a function to set 
   // the caption.  We have to do this because setLocalRootCaption() calls 
   // _ShrinkFilename based on the current width
   ctlLocalRoot.p_width = ctltree1.p_width - (ctlbrowse.p_width+xbuffer);
   setLocalRootCaption();
}

static void setLocalRootCaption()
{
   xbuffer := ctlLocalRoot.p_x;
   localRoot := _GetDialogInfoHt("localRoot");
   localRootWidth := ctlLocalRoot.p_width-ctlLocalRoot._text_width(SVC_UNSHELVE_PATH_CAPTION);
   ctlLocalRoot.p_caption = SVC_UNSHELVE_PATH_CAPTION:+ctlLocalRoot._ShrinkFilename(localRoot,localRootWidth);

   ctlbrowse.resizeToolButton(ctlLocalRoot.p_height);
   ctlbrowse.p_y = ctlLocalRoot.p_y;
   ctlbrowse.p_x = ctlLocalRoot.p_x_extent + xbuffer;
}                           
                           
void ctlbrowse.lbutton_up()
{
   _str localRoot = _GetDialogInfoHt("localRoot");
   _str result = _ChooseDirDialog("Directory to Unshelve to",localRoot);
   if ( result=='' ) return;

   localRoot = result;
   _SetDialogInfoHt("localRoot",localRoot);
   setLocalRootCaption();
   addUnshelveFilesToTree();

   // If we change the unshelve location, we have to start over with checking
   // for and resolving of conflicts
   ctlcheckForConflicts.p_enabled = true;
   ctlresolve.p_enabled = false;
   ctlunshelve.p_enabled = false;
   ctlcheckForConflicts.call_event(ctlcheckForConflicts,LBUTTON_UP);
}

void ctltree1.on_change(int reason,int index)
{
   switch ( reason ) {
   case CHANGE_CHECK_TOGGLED:
      checked := _TreeGetCheckState(index);
      if ( !checked ) {
         decrementResolved();
      } else if ( checked==1 ) {
         incrementResolved();
      }
      break;
   }
}

static int getConflictList(STRARRAY &conflictFileList,int gaugeFormWID)
{
   status := ctltree1.getConflictListFromTree(ctltree1._TreeGetFirstChildIndex(TREE_ROOT_INDEX),conflictFileList,gaugeFormWID);
   return status;
}

static int getConflictListFromTree(int index,STRARRAY &conflictFileList,int gaugeFormWID)
{
   status := 0;
   ShelfInfo shelf = _GetDialogInfoHt("shelf");
   for (;;) {
      if (index<0) break;
      _TreeGetInfo(index,auto state,auto bm1,auto bm2);
      childIndex := _TreeGetFirstChildIndex(index);
      cap := _TreeGetCaption(index);

      if ( bm1==_pic_fldopen ) {
         status = getConflictListFromTree(childIndex,conflictFileList,gaugeFormWID);
         if ( status ) return status;
      } else if ( bm1==_pic_file ) {
         baseFilename := "";
         rev1Filename := "";
         rev2Revision := "";

         baseFilename = _TreeGetUserInfo(childIndex);
         rev1Index := _TreeGetNextSiblingIndex(childIndex);
         if ( rev1Index>0 ) {
            rev1Filename = _TreeGetUserInfo(rev1Index);
            rev2Index := _TreeGetNextSiblingIndex(rev1Index);
            if ( rev2Index>0 ) {
               rev2Revision = _TreeGetUserInfo(rev2Index);
            }
         }
         localFilename := _TreeGetCaption(_TreeGetParentIndex(index)):+cap;
         // Look to see if any merges are happening at all
         if ( rev1Filename=="" && rev2Revision=="" ) {
            // Just the single file, no conflicts to have
         } else if (rev2Revision=="" && shelf.VCSystemName!="") {
            gaugeFormWID._DiffSetProgressMessage("Checking for conflicts",baseFilename,"");
            status = have2WayConflict(baseFilename,rev1Filename,auto conflict=false);
            if ( status || conflict ) {
               ARRAY_APPEND(conflictFileList,localFilename);
            }
         } else {
            gaugeFormWID._DiffSetProgressMessage("Checking for conflicts",localFilename,"");
            status = have3WayConflict(baseFilename,rev1Filename,rev2Revision,localFilename,auto conflict=false);
            if ( status || conflict ) {
               ARRAY_APPEND(conflictFileList,localFilename);
            }
         }
         progress_increment(gaugeFormWID);
         _nocheck _control gauge1,label1,label2;
         gaugeFormWID.label1.refresh();
         gaugeFormWID.label2.refresh();
         orig_wid:=p_window_id;
         process_events(auto cancel=false);
         p_window_id=orig_wid;
         if ( status ) break;
      }
      index = _TreeGetNextSiblingIndex(index);
   }
   return status;
}

static void checkItemsNotInConflict(STRARRAY &conflictFileList)
{
   checkItemsNotInConflictInTree(_TreeGetFirstChildIndex(TREE_ROOT_INDEX),conflictFileList);
}

static void checkItemsNotInConflictInTree(int index,STRARRAY &conflictFileList)
{
   STRHASHTAB conflictFileTable;
   len := conflictFileList._length();
   for (i:=0;i<len;++i) {
      conflictFileTable:[_file_case(conflictFileList[i])] = "";
   }
   for (;;) {
      if (index<0) break;
      _TreeGetInfo(index,auto state,auto bm1,auto bm2,auto nodeFlags);
      childIndex := _TreeGetFirstChildIndex(index);
      cap := _TreeGetCaption(index);

      if ( bm1==_pic_fldopen ) {
         checkItemsNotInConflictInTree(childIndex,conflictFileList);
      } else if ( bm1==_pic_file ) {

         localFilename := _TreeGetCaption(_TreeGetParentIndex(index)):+cap;
         if ( conflictFileTable:[_file_case(localFilename)]==null ) {
            // There were no conflicts
            _TreeSetCheckState(index,1,0);
            _TreeSetCheckable(index,0,0);
            _TreeSetInfo(index,TREE_NODE_COLLAPSED,bm1,bm2,nodeFlags&~TREENODE_FORCECOLOR);
         } else {
            _TreeSetInfo(index,TREE_NODE_EXPANDED,bm1,bm2,nodeFlags|TREENODE_FORCECOLOR);
         }

      }
      index = _TreeGetNextSiblingIndex(index);
   }
}

static int have2WayConflict(_str localFilename,_str modFilename,bool &conflict)
{
   status := _open_temp_view(localFilename,auto localWID,auto origWID);
   if (status) return status;

   status = _open_temp_view(modFilename,auto modWID,auto origWID2);
   if (status) return status;

   conflict = FastBinaryCompare(localWID,0,modWID,0) != 0;

   _delete_temp_view(localWID);
   _delete_temp_view(modWID);
   p_window_id = origWID;
   return status;
}

static int have3WayConflict(_str baseFilename,_str rev1Filename,_str rev2Revision,_str localFilename,bool &conflict)
{
   IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
   if ( pInterface==null ) {
      _message_box(get_message(VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC,svc_get_vc_system()));
      return VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC;
   }
   baseWID := 0;
   rev1WID := 0;
   rev2WID := 0;
   origWID := 0;
   status  := 0;
   do {
      baseFilename = stranslate(baseFilename,'/::/','//');
      status = _open_temp_view(baseFilename,baseWID,origWID);
      if ( status ) break;

      rev1Filename = stranslate(rev1Filename,'/::/','//');
      status = _open_temp_view(rev1Filename,rev1WID,auto origWID2);
      if ( status ) break;

//      status = pInterface->enumerateVersions(localFilename,auto versions);
//      if ( status ) break;

//      status = pInterface->getFile(localFilename,versions[versions._length()-1],rev2WID);
      status = _open_temp_view(localFilename,rev2WID,auto origWID3);
      if (status) break;

      // if the base and local file match, then we can not have conflicts.
      if (FastBinaryCompare(baseWID,0,rev2WID,0) == 0) {
         conflict=false;
         break;
      }

      conflict = conflictExists(baseWID,rev1WID,rev2WID)!=0;
   } while (false);
   if ( baseWID ) _delete_temp_view(baseWID);
   if ( rev1WID ) _delete_temp_view(rev1WID);
   if ( rev2WID ) _delete_temp_view(rev2WID);
   if ( origWID ) p_window_id = origWID;
   return status;
}

void ctlcheckForConflicts.lbutton_up()
{
   IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
   if ( pInterface==null ) {
      _message_box(get_message(VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC,svc_get_vc_system()));
      return;
   }
   localRoot := _GetDialogInfoHt("localRoot");
   if ( !path_exists(localRoot) ) {
      _message_box(nls("Local root '%s' does not exist\n\nYou must unshelve to a different directory",localRoot));
      p_active_form.p_visible = true;
      ctlbrowse.call_event(ctlbrowse,LBUTTON_UP);
      return;
   }

   ShelfInfo shelf = _GetDialogInfoHt("shelf");
   numfiles := shelf.fileList._length();
   gaugeFormWID := show('-mdi _difftree_progress_form');
   progress_set_min_max(gaugeFormWID,0,numfiles*2);
   _nocheck _control gauge1;
   gaugeFormWID.refresh();
   SVCDisplayOutput(nls("Checking for conflicts in %s",localRoot),true);
   status := getConflictList(auto conflictFileList,gaugeFormWID);
   activeFormVisible := p_active_form.p_visible;
   if ( !status ) {
      len := conflictFileList._length();
      ctltree1.checkItemsNotInConflict(conflictFileList);
      if ( conflictFileList._length()!=0 ) {
         ctlresolve.p_enabled = true;
         activeFormVisible = true;
      }
   } else {
      _message_box(nls("You must resolve version control errors before continuing."));
      gaugeFormWID._delete_window();
      return;
   }
   progress_set_min_max(gaugeFormWID,0,(numfiles*2)-conflictFileList._length());
   ctltree1.mergeCheckedItems(auto mergedFileList,gaugeFormWID);
   p_active_form.p_visible = activeFormVisible;
   ctlcheckForConflicts.p_enabled = false;
   gaugeFormWID._delete_window();

   if ( ctlresolve.p_enabled ) {
      ctlresolve.p_default = true;
   } else {
      ctlunshelve.p_default = true;
      ctlunshelve.call_event(ctlunshelve,LBUTTON_UP);
   }
}

static int mergeCheckedItems(STRARRAY &mergedFileList,int gaugeFormWID)
{
   gaugeFormWID._DiffSetProgressMessage("Merging files","","");
   status := mergeCheckedItemsInTree(_TreeGetFirstChildIndex(TREE_ROOT_INDEX),mergedFileList,gaugeFormWID);
   return status;
}

static int mergeCheckedItemsInTree(int index,STRARRAY &mergedFileList,int gaugeFormWID,int curNum=0)
{
   IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
   if ( pInterface==null ) {
      _message_box(get_message(VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC,svc_get_vc_system()));
      return VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC;
   }

   STRHASHTAB conflictFileTable;
   status := 0;
   for (i:=curNum;;++i) {
      if (index<0) break;
      if ( progress_cancelled() ) return COMMAND_CANCELLED_RC;

      _TreeGetInfo(index,auto state,auto bm1,auto bm2,auto nodeFlags);
      childIndex := _TreeGetFirstChildIndex(index);
      cap := _TreeGetCaption(index);

      if ( bm1==_pic_fldopen ) {
         status = mergeCheckedItemsInTree(childIndex,mergedFileList,gaugeFormWID,curNum);
         if ( status ) return status;
      } else if ( bm1==_pic_file ) {
         baseFilename := "";
         rev1Filename := "";
         rev2Revision := "";

         _nocheck _control gauge1;
         gaugeFormWID.refresh();
         baseFilename = _TreeGetUserInfo(childIndex);
         rev1Index := _TreeGetNextSiblingIndex(childIndex);
         if ( rev1Index>0 ) {
            rev1Filename = _TreeGetUserInfo(rev1Index);
            rev2Index := _TreeGetNextSiblingIndex(rev1Index);
            if ( rev2Index>0 ) {
               rev2Revision = _TreeGetUserInfo(rev2Index);
            }
         }

         parentIndex := _TreeGetParentIndex(index);
         localFilename := _TreeGetCaption(parentIndex):+cap;
         _nocheck _control gauge1,label1,label2;
         gaugeFormWID._DiffSetProgressMessage("Checking for conflicts",localFilename,"");
         gaugeFormWID.label1.refresh();
         gaugeFormWID.label2.refresh();
         gaugeFormWID.refresh();

         checked := _TreeGetCheckState(index,0);
         if ( checked ) {
            STRHASHTAB fileTab = _GetDialogInfoHt("fileTab");
            if ( rev2Revision=="" || (rev2Revision=="mfdiff" && !file_exists(localFilename)) ) {
               // Just the single file, no conflicts to have
               SVCDisplayOutput(nls("New file: %s",localFilename));
               fileTab:[_file_case(localFilename)] = baseFilename;
               incrementResolved();
            } else {
               // Merge files.  Base is the clean file in the shelf, rev1 is the mod 
               // version from the shelf, rev2 is the current version of the file on
               // disk. Output is a temp file.  We will copy the temp file over when 
               // the user clicks the "unshelve" button
               //
               // If the base and the local file name match exactly, we can just
               // mark this one to be copied in, there is no merge operation required.

               if (FastRawFileCompare(localFilename, baseFilename) == 0) {
                  SVCDisplayOutput(nls("Copying file: %s",rev1Filename));

                  baseFilename = stranslate(baseFilename,'/::/','//');
                  rev1Filename = stranslate(rev1Filename,'/::/','//');
                  fileTab:[_file_case(localFilename)] = '>'rev1Filename;
                  incrementResolved();

               } else {

                  tempOutput := mktemp();
                  createBlankFile(tempOutput);

                  SVCDisplayOutput(nls("Merging file: %s to %s",localFilename,tempOutput));

                  rev2WID := 0;
                  //status = pInterface->enumerateVersions(localFilename,auto versions);
                  //if ( status ) break;
                  
                  baseFilename = stranslate(baseFilename,'/::/','//');
                  rev1Filename = stranslate(rev1Filename,'/::/','//');
                  status = merge('-smart -saveoutput -noeditoutput -quiet -noeol '_maybe_quote_filename(baseFilename)' '_maybe_quote_filename(rev1Filename)' 'localFilename' '_maybe_quote_filename(tempOutput));
                  p_window_id = ctltree1;

                  fileTab:[_file_case(localFilename)] = '>'tempOutput;
                  incrementResolved();
               }
            }
            progress_increment(gaugeFormWID);
            orig_wid:=p_window_id;
            process_events(auto cancel=false);
            p_window_id=orig_wid; // restore tree wid if it got changed.
            _SetDialogInfoHt("fileTab",fileTab);
         }
         if ( status ) break;
      }
      index = _TreeGetNextSiblingIndex(index);
   }

   return status;
}

static void incrementResolved()
{
   resolvedFiles := _GetDialogInfoHt("resolvedFiles");
   if ( resolvedFiles==null ) resolvedFiles = 0;
   ++resolvedFiles;

   numFiles := _GetDialogInfoHt("numFiles");
   _SetDialogInfoHt("resolvedFiles",resolvedFiles);

   if ( resolvedFiles >= numFiles ) {
      ctlunshelve.p_enabled = true;
   }
}

static void decrementResolved()
{
   resolvedFiles := _GetDialogInfoHt("resolvedFiles");
   if ( resolvedFiles==null ) resolvedFiles = 0;
   --resolvedFiles;

   numFiles := _GetDialogInfoHt("numFiles");
   _SetDialogInfoHt("resolvedFiles",resolvedFiles);

   if ( resolvedFiles >= numFiles ) {
      ctlunshelve.p_enabled = false;
   }
}

static int mergeSaveCallback(_str filename,int WID)
{
   status := WID._save_file('+o '_maybe_quote_filename(filename));
   return status;

}

static void createBlankFile(_str filename)
{
//   origCreated := _create_temp_view(auto tempWID=0);
//   status := tempWID._save_file('+o 'filename);
   status :=_open_temp_view(filename,auto tempWID,auto origWID,'+t');
   tempWID._save_file('+o');
   p_window_id = origWID;
//   p_window_id = origCreated;
   _delete_temp_view(tempWID);
}

static int findFirstConflictRecursive(int index)
{
   _TreeGetInfo(index,auto state,auto bm1,auto bm2,auto nodeFlags);
   if ( nodeFlags&TREENODE_FORCECOLOR ) {
      return index;
   }
   for (;;) {
      childIndex := _TreeGetFirstChildIndex(index);
      if ( childIndex>-1 ) {
         status := findFirstConflictRecursive(childIndex);
         if ( status>=0 ) return status;
      }
      index = _TreeGetNextSiblingIndex(index);
      if (index<0) break;
      _TreeGetInfo(index,state,bm1,bm2,nodeFlags);
      if ( nodeFlags&TREENODE_FORCECOLOR ) {
         return index;
      }
   }
   return -1;
}

static int findFirstConflict()
{
   return findFirstConflictRecursive(TREE_ROOT_INDEX);
}

void ctlresolve.lbutton_up()
{
   IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
   if ( pInterface==null ) {
      _message_box(get_message(VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC,svc_get_vc_system()));
      return;
   }
   _str localRoot = _GetDialogInfoHt("localRoot");
   if ( !path_exists(localRoot) ) {
      _message_box(nls("Local root '%s' does not exist\n\nYou must unshelve to a different directory"));
      p_active_form.p_visible = true;
      ctlbrowse.call_event(ctlbrowse,LBUTTON_UP);
      return;
   }
   status := 0;
   origWID := p_window_id;
   p_window_id = ctltree1;

   tempOutputFile := mktemp();
   createBlankFile(tempOutputFile);

   do {
      index := _TreeCurIndex();
      // Be sure index is the "top" with the nodes that represent versions to merge
      // as the children
      _TreeGetInfo(index,auto state,auto bm1,auto bm2,auto nodeFlags);
      if ( state==TREE_NODE_LEAF ) {
         index = _TreeGetParentIndex(index);
      } else if ( !(nodeFlags & TREENODE_FORCECOLOR) ) {
         index = findFirstConflict();
         if ( index>=0 ) {
            _TreeSetCurIndex(index);
         }
      }

      baseFilename := _GetDialogInfoHt("baseFilename:"index);
      modsFilename := _GetDialogInfoHt("modsFilename:"index);
      curFilename  := _GetDialogInfoHt("curFilename:"index);
//      curRevision  := _GetDialogInfoHt("curRevision:"index);
      curRevision := "";
      //status = pInterface->enumerateVersions(curFilename,auto versionList,true);
      //if (!status) {
      //   curRevision = versionList[versionList._length()-1];
      //}
      if (pInterface->getBaseRevisionSpecialName() != "") {
         curRevision = pInterface->getBaseRevisionSpecialName();
      } else {
         status = pInterface->getCurLocalRevision(curFilename, curRevision, true);
      }

#if 0 //1:15pm 7/25/2013
      say('ctlresolve.lbutton_up curFilename='curFilename);
      pInterface->getFileStatus(curFilename,auto curFileStatus);
      if ( curFileStatus&SVC_STATUS_MODIFIED ) {
         result := _message_box(nls("%s is modified and you will lose the changes\n\nContinue?",curFilename),"",MB_YESNO);
         break;
      }
#endif

      isReadOnly := false;
      curFileExists := file_exists(curFilename);
      if ( curFileExists ) {
         isReadOnly = localShelfFileIsReadOnly(curFilename);
         if ( isReadOnly ) {
            result := _message_box(nls("'%s' is read only.\n\n%s now?",curFilename,pInterface->getCaptionForCommand(SVC_COMMAND_EDIT,false)),"",MB_YESNOCANCEL);
            if ( result==IDYES ) {
               pInterface->editFile(curFilename);
            }else if ( result==IDCANCEL ) {
               break;
            }
         }
      }

      if ( curRevision!="" ) {
         // Merge files.  Base is the clean file in the shelf, rev1 is the mod 
         // version from the shelf, rev2 is the current version of the file on
         // disk. Output is a temp file.  We will copy the temp file over when 
         // the user clicks the "unshelve" button

         baseTitle := '-basefilecaption " '_strip_filename(curFilename,'P')' (clean base version)"';
         rev1Title := '-rev1filecaption " '_strip_filename(curFilename,'P')' (modified shelf version)"';
         rev2Title := '-rev2filecaption " '_strip_filename(curFilename,'P')' (current 'curFilename' version)"';
         outputTitle := '-outputfilecaption " '_strip_filename(tempOutputFile,'P')' (temp version)"';
         baseFilename = stranslate(baseFilename,'/::/','//');
         modsFilename = stranslate(modsFilename,'/::/','//');
         status = merge('-savecallback 'mergeSaveCallback' -noeol -smart -forceconflict -noeditoutput -saveoutput 'baseTitle' 'rev1Title' 'rev2Title' 'outputTitle' '_maybe_quote_filename(baseFilename)' '_maybe_quote_filename(modsFilename)' 'curFilename' '_maybe_quote_filename(tempOutputFile));
         if ( _file_size(tempOutputFile)>0 ) {
            // If we saved the file, the conflict is resolved to the user's
            // satisfaction.  Save the filename on the index's user info and
            // set the node checked.

            // bringing up the merge dialog and closing it probably changed the
            // active window.
            p_window_id = ctltree1;

            STRHASHTAB fileTab = _GetDialogInfoHt("fileTab");
            fileTab:[_file_case(curFilename)] = '>'tempOutputFile;
            _SetDialogInfoHt("fileTab",fileTab);

            incrementResolved();
            _TreeSetCheckState(index,1,0);
            _TreeSetCheckable(index,0,0);
         }
      } else {
         if ( curFileExists ) {
            // We don't have to copy etc.  We diffed "into" the actual local 
            // file
            diff('-modal -file2title "'_strip_filename(curFilename,'P')' (from shelf)" '_maybe_quote_filename(curFilename)' '_maybe_quote_filename(modsFilename));
            p_window_id = ctltree1;

            incrementResolved();
            _TreeSetCheckState(index,1,0);
            _TreeSetCheckable(index,0,0);
         }
      }

   } while (false);

   resolvedFiles := _GetDialogInfoHt("resolvedFiles");
   if ( resolvedFiles==null ) resolvedFiles = 0;
   numFiles := _GetDialogInfoHt("numFiles");
   if ( numFiles==null ) numFiles = 0;
   if ( numFiles==resolvedFiles ) {
      ctlresolve.p_default = false;
      ctlunshelve.p_default = true;
   }

   p_window_id = origWID;
}

void ctlunshelve.lbutton_up()
{
   STRHASHTAB fileTab = _GetDialogInfoHt("fileTab");
   zipFilename := _GetDialogInfoHt("zipFilename");
   localRoot := _GetDialogInfoHt("localRoot");

   STRARRAY roFileArray;
   foreach (auto curFile => auto curTempFile in fileTab) {
      ro := localShelfFileIsReadOnly(curFile);
      if ( ro ) {
         ARRAY_APPEND(roFileArray,curFile);
      }
   }

   len := roFileArray._length();
   if ( len ) {
      result := _message_box(nls("%s of the files to be written to are read only.\n\nCheck out read only files now?",len),"",MB_YESNO);
      if ( result!=IDYES ) {
         _message_box(nls("Cannot unshelve because of read only files"));
         return;
      }
      IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
      if ( pInterface==null ) {
         _message_box(get_message(VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC,svc_get_vc_system()));
         return;
      }
      status := pInterface->editFiles(roFileArray);
      if ( status ) {
         return;
      }
      for (i:=0;i<len;++i) {
         _filewatchRefreshFile(roFileArray[i]);
      }
   }
   foreach (auto destFilename=> auto sourceFilename in fileTab) {
      ch := substr(fileTab:[destFilename],1,1);
      if (ch=='>') {
         fileTab:[destFilename] = substr(sourceFilename,2);
      }
   }
   justZipName := _strip_filename(zipFilename,'PE');
   backupPath := svc_get_shelf_base_path():+'backup_'justZipName;
   origBackupPath := backupPath;
   for (i:=0;;++i) {
      backupPath = origBackupPath'.'i;
      if (!path_exists(backupPath)) break;
   }

   STRHASHTAB backupFiles;
   foreach (destFilename=> sourceFilename in fileTab) {
      curDestFilename := substr(destFilename,length(localRoot)+1);
      backupFiles:[destFilename] = backupPath:+FILESEP:+curDestFilename;
   }

   status := show('-modal _svc_unshelve_summary_form',fileTab,backupFiles);
   if ( status!=1 ) {
      if ( !p_active_form.p_visible ) {
         p_active_form._delete_window();
      }
      return;
   }

   SVCDisplayOutput(nls("Unshelving %s to %s",zipFilename,localRoot));
   foreach (sourceFilename => auto backupFilename in backupFiles) {
      //say('ctlunshelve.lbutton_up backup 'sourceFilename' to 'backupFilename);
      curBackupPath := _file_path(backupFilename);
      if ( !path_exists(curBackupPath) ) {
         make_path(curBackupPath);
      }
      SVCDisplayOutput(nls("Backing up %s to %s",sourceFilename,backupFilename));
      copy_file(sourceFilename,backupFilename);
   }

   STRARRAY retagArray;
   totalStatus := 0;
   foreach (destFilename=> sourceFilename in fileTab) {
      ch := substr(sourceFilename,1,1);
      if ( ch=='>' ) {
         sourceFilename = substr(sourceFilename,2);
      }
      _LoadEntireBuffer(destFilename);
      status = copy_file(sourceFilename,destFilename);
      if ( !status ) {
         SVCDisplayOutput(nls("Copy %s to %s",sourceFilename,destFilename));
         STRARRAY tempArray;
         tempArray[0] = destFilename;
         retagArray :+= destFilename;
         origWID := _create_temp_view(auto tempWID);
         _reload_vc_buffers(tempArray);
         p_window_id = origWID;
         _delete_temp_view(tempWID);
      } else {
         totalStatus = status;
         _message_box(nls("Could not copy %s to %s\n\n%s",sourceFilename,destFilename,get_message(status)));
         SVCDisplayOutput(nls("Could not copy %s to %s",sourceFilename,destFilename));
         SVCDisplayOutput(nls("   %s",get_message(status)));
      }
   }
   manifestFilename := zipFilename:+FILESEP:+"manifest.xml";
   xmlhandle := _xmlcfg_open(manifestFilename,status,VSXMLCFG_OPEN_ADD_PCDATA);
   if ( !status ) {
      // Set Unshelved attribute in manifest file and append it to the shelf.
      // We use this in the list dialog
      index := _xmlcfg_get_first_child(xmlhandle,TREE_ROOT_INDEX);
      if ( index>=0 ) {
         _xmlcfg_set_attribute(xmlhandle,index,"Unshelved",1);
         tempFilename := mktemp();
         status = _xmlcfg_save(xmlhandle,-1,VSXMLCFG_SAVE_ONE_LINE_IF_ONE_ATTR,tempFilename);
         _ZipClose(zipFilename);
         STRARRAY tempSourceArray,tempDestArray;
         tempSourceArray[0] = tempFilename;
         tempDestArray[0] = "manifest.xml";
         status = _ZipAppend(zipFilename,tempSourceArray,auto zipStatus,tempDestArray);
         delete_file(tempFilename);
      }
   }
   _retag_vc_buffers(retagArray);
   if ( !totalStatus ) {
      _message_box(nls("Files unshelved successfully"));
      p_active_form._delete_window(0);
   }
}

static bool localShelfFileIsReadOnly(_str filename)
{
   if ( !file_exists(filename) ) return false;
   attrs := file_list_field(filename,DIR_ATTR_COL,DIR_ATTR_WIDTH);
   ro := false;
   if (_isUnix()) {
      ro=!pos('w',attrs,'','i');
   } else {
      status := _open_temp_view(filename,auto temp_wid,auto orig_wid);
      ro = !_WinFileIsWritable(temp_wid);
      _delete_temp_view(temp_wid);
      p_window_id = orig_wid;
   }
   return ro;
}

defeventtab _svc_shelf_list_form;
void ctlbrowse.lbutton_up()
{
   parse ctlShelfRootLabel.p_caption with (SVC_SHELF_LOCALROOT_CAPTION) auto localRoot;
   _str result = _ChooseDirDialog("Directory to Review to",localRoot);
   if ( result=='' ) return;

   ctlShelfRootLabel.p_caption = SVC_SHELF_LOCALROOT_CAPTION:+result;
   ctlbrowse.p_x = ctlShelfRootLabel.p_x_extent;
}

void ctlclose.on_create()
{
   p_active_form.p_caption = "Shelf List";

   fillInItemsFromList();
}

static void fillInItemsFromList(bool setButtonWidths=true)
{
   origWID := p_window_id;
   p_window_id = ctltree1;
   if ( setButtonWidths ) {
      _TreeSetColButtonInfo(0,1500,TREE_BUTTON_IS_FILENAME,-1,"Filename");
      _TreeSetColButtonInfo(1,1000,0,-1,"Status");
      _TreeSetColButtonInfo(2,5000,0,-1,"Path");
   }

   _TreeDelete(TREE_ROOT_INDEX,'C');
   len := svc_shelf_name_get_count();
   for (i:=0;i<len;++i) {
      zipFilename := svc_get_shelf_name_from_index(i);
      manifestFilename := zipFilename:+FILESEP:+"manifest.xml";
      xmlhandle := _xmlcfg_open(manifestFilename,auto status,VSXMLCFG_OPEN_ADD_PCDATA);
      unshelved := false;
      if ( !status ) {
         index := _xmlcfg_get_first_child(xmlhandle,TREE_ROOT_INDEX);
         if ( index>=0 ) {
            unshelved = _xmlcfg_get_attribute(xmlhandle,index,"Unshelved",false);
         }
         _xmlcfg_close(xmlhandle);
      }
      caption := _strip_filename(svc_get_shelf_name_from_index(i),'P'):+"\t":+(unshelved?"Unshelved":"Shelved"):+"\t":+_file_path(svc_get_shelf_name_from_index(i));
      _TreeAddItem(TREE_ROOT_INDEX,caption,TREE_ADD_AS_CHILD,0,0,TREE_NODE_LEAF);
   }
   index := _TreeGetFirstChildIndex(TREE_ROOT_INDEX);

   // Be sure we refresh the dialog to match the currently selected item
   call_event(CHANGE_SELECTED,index,ctltree1,ON_CHANGE,'W');

   p_window_id = origWID;
}

void ctlMoveShelfUp.lbutton_up()
{
   origWID := p_window_id;
   p_window_id = ctltree1;

   index := _TreeCurIndex();
   if ( index<0 ) return;
   indexAbove := _TreeGetPrevIndex(index);
   if ( indexAbove<0 ) return;

   cap := _TreeGetCaption(index);
   _TreeDelete(index);
   newIndex := _TreeAddItem(indexAbove,cap,TREE_ADD_BEFORE,0,0,TREE_NODE_LEAF);
   _TreeSetCurIndex(newIndex);
      
   getShelfListFromTree();      
   call_event(CHANGE_SELECTED,_TreeCurIndex(),ctltree1,ON_CHANGE,'W');

   p_window_id = origWID;
}

void ctlMoveShelfDown.lbutton_up()
{
   origWID := p_window_id;
   p_window_id = ctltree1;

   index := _TreeCurIndex();
   if ( index<0 ) return;
   indexBelow := _TreeGetNextIndex(index);
   if ( indexBelow<0 ) return;

   cap := _TreeGetCaption(index);
   _TreeDelete(index);
   newIndex := _TreeAddItem(indexBelow,cap,0,0,0,TREE_NODE_LEAF);
   _TreeSetCurIndex(newIndex);
      
   getShelfListFromTree();      
   call_event(CHANGE_SELECTED,_TreeCurIndex(),ctltree1,ON_CHANGE,'W');

   p_window_id = origWID;
}

void ctlRemoveShelf.lbutton_up()
{
   origWID := p_window_id;
   p_window_id = ctltree1;

   index := _TreeCurIndex();
   if ( index<0 ) return;
   _TreeDelete(index);
      
   getShelfListFromTree();      
   if ( svc_shelf_name_get_count() ) {
      gNoShelves = true;
   }
   call_event(CHANGE_SELECTED,_TreeCurIndex(),ctltree1,ON_CHANGE,'W');

   p_window_id = origWID;
}

void ctlAddShelf.lbutton_up()
{
   origWID := p_window_id;
   p_window_id = ctltree1;
   index := _TreeCurIndex();
   ln := -1;
   
   // Use >0 because we do not want the root index
   if ( index>0 ) {
      ln = _TreeGetLineNumber(index);
   }
   call_event(CHANGE_SELECTED,_TreeCurIndex(),ctltree1,ON_CHANGE,'W');
   p_window_id = origWID;
   openShelf(ln+1);
}

static void getShelfListFromTree()
{
   // For this funciton, let def_svc_all_shelves be manipulated
   orig_def_svc_all_shelves := def_svc_all_shelves;
   def_svc_all_shelves = null;
   index := _TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   for (;;) {
      if ( index<0 ) break;
      cap := _TreeGetCaption(index);
      parse cap with auto name auto shelfStatus auto path;
      ARRAY_APPEND(def_svc_all_shelves,path:+name);
      index = _TreeGetNextSiblingIndex(index);
   }
   if ( def_svc_all_shelves!=orig_def_svc_all_shelves ) {
      _config_modify_flags(CFGMODIFY_DEFVAR);
   }
}

void _svc_shelf_list_form.on_resize()
{
   // set mininum size for this form
   if (!_minimum_width()) {
      _set_minimum_size(ctlclose.p_width*7, ctlclose.p_height*8);
   }

   labelWID := ctltree1.p_prev;
   clientWidth  := _dx2lx(SM_TWIP,p_active_form.p_client_width);
   clientHeight := _dy2ly(SM_TWIP,p_active_form.p_client_height);
   xbuffer := labelWID.p_x;
   ybuffer := labelWID.p_y;

   treeWidth1 := clientWidth - ctlAddShelf.p_width - (3*xbuffer);
   treeWidth2 := clientWidth - (2*xbuffer);
   ctltree1.p_width = treeWidth1;
   ctltree2.p_width = treeWidth2;
   ctltree1.p_y = labelWID.p_y_extent+ybuffer;
   treeArea := clientHeight - ctlclose.p_height;
   ctltree2.p_height = ctltree1.p_height = (treeArea intdiv 2) - ((7*ybuffer) + ctllabel1.p_height);
   ctlcommentLabel.p_y = ctltree1.p_y_extent+ybuffer;
   ctlShelfRootLabel.p_y = ctlcommentLabel.p_y_extent+ybuffer;
   ctlbrowse.p_y = ctlShelfRootLabel.p_y;
   ctlbrowse.p_x = ctlShelfRootLabel.p_x_extent + xbuffer;
   ctlbrowse.resizeToolButton(ctlShelfRootLabel.p_height);
   
   alignUpDownListButtons(ctltree1.p_window_id, 0,
                          ctlAddShelf.p_window_id, 
                          ctlMoveShelfUp.p_window_id,
                          ctlMoveShelfDown.p_window_id,
                          ctlRemoveShelf.p_window_id);

   ctltree2.p_prev.p_y = ctlShelfRootLabel.p_y_extent+ybuffer;
   ctltree2.p_y = ctltree2.p_prev.p_y_extent+ybuffer;

   alignControlsHorizontal(ctltree2.p_x, ctltree2.p_y_extent + ybuffer,
                           xbuffer,
                           ctlunshelve.p_window_id,
                           ctlclose.p_window_id,
                           ctledit.p_window_id,
                           ctldelete.p_window_id,
                           ctlopen.p_window_id,
                           ctlreview.p_window_id);

}

static void openShelf(int arrayIndex=0)
{
   result := _OpenDialog('-modal',
                         'Select file to add',                   // Dialog Box Title
                         '*.zip',// Initial Wild Cards
                         'Zip Files (*.zip)',
                         OFN_FILEMUSTEXIST);
   if ( result=="" ) {
      return;
   }
   filename := result;
   if (!pos(' '_maybe_quote_filename(filename)' ',' 'def_svc_user_shelves' ',1,_fpos_case)) {
      svc_shelf_name_remove(filename);
      svc_shelf_name_insert(arrayIndex,filename);
   }
   fillInItemsFromList(false);
   index := ctltree1._TreeSearch(TREE_ROOT_INDEX,_strip_filename(filename,'P')"\tShelved\t"_file_path(filename),'r');
   if (index<0) {
      index = ctltree1._TreeSearch(TREE_ROOT_INDEX,_strip_filename(filename,'P')"\tUnshelved\t"_file_path(filename),'r');
   }
   if (index>0) {
      ctltree1._TreeSetCurIndex(index);
   }
}

void ctlopen.lbutton_up()
{
   openShelf();
}

static void getShelfFileInfo(_str &baseFilename,_str &modFilename,_str &localFilename,_str &baseRevision)
{
   zipFilename := ctltree1.zipFilenameFromTree();
   ShelfInfo shelf = _GetDialogInfoHt("shelves."zipFilename);
   if ( shelf==null ) {
      status := loadShelf(zipFilename,shelf);
      if ( status ) return;
      _SetDialogInfoHt("shelves."zipFilename,shelf);
   }
   index := ctltree2._TreeCurIndex();
   parse ctlShelfRootLabel.p_caption with (SVC_SHELF_LOCALROOT_CAPTION) auto localRoot;
   pathAndName := ctltree2._TreeGetCaption(index);
   localFilename = localRoot:+pathAndName;
   baseFilename  = zipFilename:+FILESEP"base":+FILESEP:+pathAndName;
   modFilename  = zipFilename:+FILESEP"mods":+FILESEP:+pathAndName;

   // Have to find the file in the shelf to get the base file revision
   len := shelf.fileList._length();
   for (i:=0;i<len;++i) {
      if ( _file_eq(shelf.fileList[i].filename,stranslate(pathAndName,'/',FILESEP)) ) {
         baseRevision = shelf.fileList[i].revision;
      }
   }
}

void ctlreview.lbutton_up()
{
   origWID := p_window_id;
   p_window_id = ctltree1;

   getShelfFileInfo(auto baseFile,auto modFile,auto localFilename,auto baseRevision);

   origWID = _create_temp_view(auto tempWID);
   p_window_id = origWID;

   if ( baseRevision!="" ) {
      merge('-showchanges -noeditoutput -bouti -nosave -readonlyoutput '_maybe_quote_filename(baseFile)' '_maybe_quote_filename(modFile)' '_maybe_quote_filename(localFilename)' 'tempWID.p_buf_id);
   } else {
      status := _open_temp_view(modFile,tempWID,origWID);
      if ( !status ) {
         tempWID._SetEditorLanguage();
         p_window_id = origWID;
         _showbuf(tempWID,false,"-new -modal",localFilename);
      }
   }

   _delete_temp_view(tempWID);

   p_window_id = origWID;
}

static _str zipFilenameFromTree(int index=-1)
{
   if (index==-1) index = _TreeCurIndex();
   if ( index<0 ) return("");
   caption := _TreeGetCaption(index);
   parse caption with auto zipName "\t" auto shelfStatus "\t" auto zipFilePath;
   zipFilename := zipFilePath:+zipName;
   return zipFilename;
}

void ctltree1.on_change(int reason,int index)
{
   onChange := _GetDialogInfoHt("onChange");
   if ( onChange==1 ) return;

   _SetDialogInfoHt("onChange",1);
   if (index>0 && !(index==TREE_ROOT_INDEX && !p_ShowRoot) ) {
      ctledit.p_enabled = ctlunshelve.p_enabled = ctldelete.p_enabled = true;
      ctlMoveShelfUp.p_enabled = ctlMoveShelfDown.p_enabled = ctlRemoveShelf.p_enabled = true;
      switch ( reason ) {
      case CHANGE_SELECTED:
         {
            ShelfInfo shelves:[] = _GetDialogInfoHt("shelves");

            zipFilename := zipFilenameFromTree(index);
            manifestFilename := zipFilename:+FILESEP:+"manifest.xml";
            ShelfInfo curShelf = shelves:[_file_case(manifestFilename)];
            if ( curShelf==null ) {
               status := loadShelf(zipFilename,curShelf);
               shelves:[_file_case(manifestFilename)] = curShelf;
               _SetDialogInfoHt("shelves",shelves);
            }
            if ( curShelf!=null ) {
               startOfComment := curShelf.commentArray[0];
               if ( startOfComment==null ) startOfComment="";

               ctlcommentLabel.p_caption = SVC_SHELF_COMMENT_CAPTION:+startOfComment;
               ctlShelfRootLabel.p_caption = SVC_SHELF_LOCALROOT_CAPTION:+stranslate(curShelf.localRoot,FILESEP,'/');
               ctlbrowse.p_x = ctlShelfRootLabel.p_x_extent + 60;
               len := curShelf.fileList._length();
               ctltree2._TreeDelete(TREE_ROOT_INDEX,'C');
               for (i:=0;i<len;++i) {
                  ctltree2._TreeAddItem(TREE_ROOT_INDEX,stranslate(curShelf.fileList[i].filename,FILESEP,'/'),TREE_ADD_AS_CHILD,_pic_file,_pic_file,TREE_NODE_LEAF);
               }
            }
         }
         break;
      case CHANGE_LEAF_ENTER:
         ctlunshelve.call_event(ctlunshelve,LBUTTON_UP);
         break;
      }
   } else {
      ctledit.p_enabled = ctlunshelve.p_enabled = ctldelete.p_enabled = false;
      ctlMoveShelfUp.p_enabled = ctlMoveShelfDown.p_enabled = ctlRemoveShelf.p_enabled = false;
      ctltree2._TreeDelete(TREE_ROOT_INDEX,'C');
   }
   _SetDialogInfoHt("onChange",0);
}

void ctledit.lbutton_up()
{
   origWID := p_window_id;
   p_window_id = ctltree1;
   zipFilename := zipFilenameFromTree();
   if ( zipFilename!="" ) {
      loadShelf(zipFilename,auto shelf);
      svc_gui_edit_shelf(&shelf,zipFilename);
   }
   p_window_id = origWID;
   ctltree1._set_focus();
}

int svc_gui_edit_shelf(ShelfInfo *pshelf,_str zipFilename,bool promptToRefresh=true)
{
   refreshZipFile := true;
   if ( pshelf->fileList._length()==0 ) {
      return COMMAND_CANCELLED_RC;
   }
   status := show('-modal _svc_shelf_form',zipFilename,pshelf,&promptToRefresh,&refreshZipFile);
   if ( status==0 ) {
      if ( refreshZipFile ) {
         writeZipFileShelf(zipFilename,*pshelf);
         svc_shelf_name_append(zipFilename);
      }
   }
   return 0;
}

static int writeZipFileShelf(_str zipFilename,ShelfInfo &shelf)
{
   IVersionControl *pInterface=null;
   if (shelf.VCSystemName!="") {
      pInterface = svcGetInterface(shelf.VCSystemName);
      if ( pInterface==null ) return VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC;
   }

   _control ctlrootPathLabel;

   STRARRAY relFileList,destFileList,sourceFileList;
   // relFileList is a list from the tree.  Now we have to make lists so that
   // we have mods and base versions of each one.  Start with the dest filnnames
   len := shelf.fileList._length();
   for ( i:=0;i<len;++i ) {
      destName := "mods/"strip(shelf.fileList[i].filename,'B','"');
      if ( substr(shelf.fileList[i].filename,1,1)=='/') {
         destName = "mods/::"strip(shelf.fileList[i].filename,'B','"');
      }
      ARRAY_APPEND(destFileList,destName);
   }
   for ( i=0;i<len;++i ) {
      destName := "base/"strip(shelf.fileList[i].filename,'B','"');
      if ( substr(shelf.fileList[i].filename,1,1)=='/') {
         destName = "base/::"strip(shelf.fileList[i].filename,'B','"');
      }
      ARRAY_APPEND(destFileList,destName);
   }
   // Now the source filenames.  Get the mods first, they're the local files
   for ( i=0;i<len;++i ) {
      curFilename := shelf.localRoot:+shelf.fileList[i].filename;
      if ( substr(shelf.fileList[i].filename,2,1)==':' ||  substr(shelf.fileList[i].filename,1,1)=='/') {
         curFilename = shelf.fileList[i].filename;
      }
      ARRAY_APPEND(sourceFileList,curFilename);
   }
   mou_hour_glass(true);
   STRARRAY tempFileList;
   for ( i=0;i<len;++i ) {
      curFilename := shelf.baseRoot!=null ? shelf.baseRoot:+shelf.fileList[i].filename :shelf.localRoot:+shelf.fileList[i].filename;
      // Check to see if the file is absolute
      if ( substr(shelf.fileList[i].filename,2,1)==':' ||  substr(shelf.fileList[i].filename,1,1)=='/') {
         curFilename = shelf.fileList[i].filename;
      }
      if (shelf.VCSystemName!="") {
         status := pInterface->getCurLocalRevision(curFilename,shelf.fileList[i].revision,true);
         if ( status ) {
            _message_box("Could not get revision for %s",curFilename);
            return 1;
         }
      } else {
         if (file_exists(curFilename)) {
            shelf.fileList[i].revision = "mfdiff";
         }
      }
      base_rev := shelf.fileList[i].revision;
      if (shelf.fileList[i].revision=="") {
         if (pInterface && pInterface->getBaseRevisionSpecialName() != "") {
            base_rev = pInterface->getBaseRevisionSpecialName();
         } else {
            base_rev = "mfdiffBase";
         }
      }
      baseFileWID := 0;
      if (pInterface) {
         pInterface->getFile(curFilename,base_rev,baseFileWID);
      } else {
         status := _open_temp_view(curFilename,baseFileWID,auto origWID);
         if (status) {
            // We are creating a shelf from a multi-file diff, and there is no
            // base file.  Simulate the way we handle this in a version control
            // shelf.
            origWID = _create_temp_view(baseFileWID);
         }
         p_window_id = origWID;
      }

      baseFileSrc := mktemp();
      if (baseFileWID!=0) {
         baseFileWID._save_file('+o 'baseFileSrc);
         _delete_temp_view(baseFileWID);
         ARRAY_APPEND(tempFileList,baseFileSrc);
         ARRAY_APPEND(sourceFileList,baseFileSrc);
      }
   }


   _maybe_strip_filesep(zipFilename);
   _str tempFilename;
   status := writeManifestZipFileToTemp(zipFilename,shelf,tempFilename);
   ARRAY_APPEND(sourceFileList,tempFilename);
   ARRAY_APPEND(destFileList,"manifest.xml");
   _ZipClose(zipFilename);
   zipFilename = strip(zipFilename,'B','"');
   status = _ZipCreate(zipFilename,sourceFileList,auto zipStatus,destFileList);

   delete_file(tempFilename);
   len = tempFileList._length();
   for ( i=0;i<len;++i ) {
      delete_file(tempFileList[i]);
   }
   mou_hour_glass(false);

   return 0;
}


_command void svc_add_to_shelf(_str cmdLine="") name_info(','VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return;
   }
   zipFilename := parse_file(cmdLine);
   filename := parse_file(cmdLine);

   svc_add_controlled_file_to_shelf(zipFilename,filename);

   svc_shelf_name_remove(zipFilename);
   svc_shelf_name_insert(0,zipFilename);
   _config_modify_flags(CFGMODIFY_DEFVAR);
}

int svc_add_controlled_file_to_shelf(_str zipFilename,_str fileList)
{
   if ( fileList=="" ) return COMMAND_CANCELLED_RC;
   firstFilename := get_first_file(fileList);
   autoVCSystem := svc_get_vc_system(firstFilename);

   zipFilename = strip(zipFilename,'B','"');

   IVersionControl *pInterface = svcGetInterface(autoVCSystem);
   if ( pInterface==null ) {
      _message_box(get_message(VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC,autoVCSystem));
      return VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC;
   }
   status := loadShelf(zipFilename,auto shelf);
   if ( status ) {
      _message_box(nls("Could not open shelf file '%s'",zipFilename));
      return status;
   }
   STRARRAY srcFileList;
   STRARRAY destFileList;

   mou_hour_glass(true);
   for (;;) {
      filename := parse_file(fileList);
      if ( filename=="" ) break;
      absoluteFilename := false;
      shelf.localRoot = stranslate(shelf.localRoot,FILESEP,'/');
      if ( !_file_eq(shelf.localRoot,substr(filename,1,length(shelf.localRoot))) ) {
         result :=  _message_box(nls("Shelf '%s' has root '%s'.\n\nThis file will be added with an absolute filename. Continue?",zipFilename,shelf.localRoot),"",MB_YESNO);
         if ( result != IDYES ) {
            return 1;
         }
         absoluteFilename = true;
      }
      relFilename := relative(filename,shelf.localRoot);
      if ( absoluteFilename ) {
         relFilename = absolute(filename);
      }
      len := shelf.fileList._length();
      found := false;
      for (i:=0;i<len;++i) {
         if ( _file_eq(relFilename,shelf.fileList[i].filename) ) {
            found = true;break;
         }
      }
      // For now allow this if we found it, this way we refresh the items
      STRARRAY commentArray;

      ShelfFileInfo file;

      status = pInterface->getCurRevision(filename,auto curRevision,"",true);
      status = pInterface->getCurLocalRevision(filename,auto curLocalRevision,true);

      baseFileSrc := "";
      baseFileDest := "";
      if ( curLocalRevision!="" ) {
         pInterface->getFile(filename,curLocalRevision,auto baseFileWID);
         baseFileSrc = mktemp();
         baseFileWID._save_file('+o 'baseFileSrc);
         _delete_temp_view(baseFileWID);

         baseFileDest = "base/"stranslate(relFilename,'/',FILESEP);
      }

      modFileSrc := filename;
      modFileDest := "mods/"stranslate(relFilename,'/',FILESEP);

      if ( !found ) {
         file.filename = relFilename;
         file.baseFile = baseFileDest;
         file.commentArray = commentArray;
         file.modFile = modFileDest;
         file.revision = curLocalRevision;
         ARRAY_APPEND(shelf.fileList,file);
      }
      ARRAY_APPEND(srcFileList,baseFileSrc);
      ARRAY_APPEND(destFileList,baseFileDest);
      ARRAY_APPEND(srcFileList,modFileSrc);
      ARRAY_APPEND(destFileList,modFileDest);
   }
   _ZipClose(zipFilename);
   status = _ZipAppend(zipFilename,srcFileList,auto zipStatus,destFileList);
   writeManifestZipFile(zipFilename,shelf);
   if ( !status ) {
      svc_shelf_name_remove(zipFilename);
      svc_shelf_name_insert(0,zipFilename);
      _config_modify_flags(CFGMODIFY_DEFVAR);
   }
   mou_hour_glass(false);

   return status;
}

static void getShelfPaths(_str manifestFilename,_str &shelfPath,_str &baseFilePath,_str &modFilePath)
{
   shelfPath = _file_path(manifestFilename);
   _maybe_append_filesep(shelfPath);
   baseFilePath = shelfPath:+"base";
   _maybe_append_filesep(baseFilePath);
   modFilePath  = shelfPath:+"mods";
   _maybe_append_filesep(modFilePath);
}

void ctlunshelve.lbutton_up()
{
   mou_hour_glass(true);
   do {
      origWID := p_window_id;
      p_window_id = ctltree1;
      zipFilename := zipFilenameFromTree();
      if ( zipFilename!="" ) {
         loadShelf(zipFilename,auto shelf);
#if 0 //9:53am 8/20/2019
         if ( lowcase(shelf.VCSystemName)!=lowcase(svc_get_vc_system()) ) {
            _message_box(nls("You cannot unshelve this because it was shelved from '%s' and the current version control system is '%s'",shelf.VCSystemName,svc_get_vc_system()));
            break;
         }
#endif
         parse ctlShelfRootLabel.p_caption with (SVC_SHELF_LOCALROOT_CAPTION) auto localRoot;
         shelf.localRoot = localRoot;

         // compose prompt for directory to unshelf to
         unshelf_prompt := nls("Do you wish to unshelve to this directory?");
         if ( !path_exists(shelf.localRoot) ) {
            unshelf_prompt = nls("Local root '%s' does not exist<br>You must unshelve to a different directory",shelf.localRoot);
         }

         // retrieve new directory name
         result := textBoxDialog(nls("Unshelve Files To:"),
                                 0,      // flags,
                                 0,      // textbox width
                                 "",     // help item
                                 "OK,Cancel:_cancel\t-html "unshelf_prompt,
                                 "",     // retrieve name
                                 "-bd Directory:"shelf.localRoot);  // prompt
         if (result==COMMAND_CANCELLED_RC) return;
         shelf.localRoot = _param1;

         status := show('-modal -hidden _svc_unshelve_form',shelf,zipFilename);
         if ( !status ) {
            p_active_form._delete_window(0);
            return;
         }
      }
      p_window_id = origWID;
      mou_hour_glass(false);
      ctltree1._set_focus();
   } while (false);
   mou_hour_glass(false);
}

static void deleteCurrentItemInTree()
{
   index := _TreeCurIndex();
   if ( index<0 ) return;

   cap := _TreeGetCaption(index);
   parse cap with auto name auto status auto path;
   zipFilename := path:+name;
   result := _message_box(nls("Delete file '%s'?",zipFilename),"",MB_YESNO);
   if ( result==IDYES ) {
      orig := def_delete_uses_recycle_bin;
      def_delete_uses_recycle_bin = true;
      recycle_file(zipFilename);
      def_delete_uses_recycle_bin = orig;
      _TreeDelete(index);
      getShelfListFromTree();
      if ( svc_shelf_name_get_count()==0 ) {
         gNoShelves = true;
      }
      call_event(CHANGE_SELECTED,_TreeCurIndex(),ctltree1,ON_CHANGE,'W');
   }
}

void ctldelete.lbutton_up()
{
   ctltree1.deleteCurrentItemInTree();
}

void ctltree1.del()
{
   ctltree1.deleteCurrentItemInTree();
}


defeventtab _svc_unshelve_summary_form;

void ctlok.on_create(STRHASHTAB copyFileTab=null,STRHASHTAB backupFileTab=null)
{
   cap := "Unshelving will perform the following operations:<P>";
   cap :+= "<FONT size='2'><UL>";
   foreach (auto curFile => auto tempFile in copyFileTab) {
      if ( substr(tempFile,1,1)=='>' ) {
         tempFile = substr(tempFile,2);
      }
      cap :+= "<LI> backup "curFile" to "backupFileTab:[curFile]"</LI>";
      cap :+= "<LI> copy "tempFile" to "curFile"</LI>";
   }
   cap :+= "</UL></FONT>";
   ctlminihtml1.p_text = cap;
}

void _svc_unshelve_summary_form.on_resize()
{
   xbuf := ctlminihtml1.p_x;
   ybuf := ctlminihtml1.p_y;

   clientWidth  := _dx2lx(SM_TWIP,p_active_form.p_client_width);
   clientHeight := _dy2ly(SM_TWIP,p_active_form.p_client_height);

   ctlminihtml1.p_width = clientWidth - (2*xbuf);
   ctlminihtml1.p_height = clientHeight - ((3*xbuf)+ctlok.p_height);

   ctlok.p_y = ctlok.p_next.p_y = ctlminihtml1.p_y_extent+ybuf;
}

void ctlok.lbutton_up()
{
   p_active_form._delete_window(1);
}

defeventtab _svc_new_shelf_form;

void ctlok.on_create()
{
   ctltree1._dlpath(_ConfigPath():+SHELVES_PATH);
}

void _svc_new_shelf_form.on_resize()
{
   labelWID := p_child;
   xbuf := labelWID.p_x;
   ybuf := ctltext1.p_y;

   clientWidth  := _dx2lx(SM_TWIP,p_active_form.p_client_width);
   clientHeight := _dy2ly(SM_TWIP,p_active_form.p_client_height);

   ctltext1.p_width = (clientWidth-ctltext1.p_x) - xbuf;
   ctltree1.p_width = ctltext1.p_width;

   ctltree1.p_height = clientHeight - (ctltext1.p_height+ctlok.p_height+(4*ybuf));

   ctlok.p_y = ctlok.p_next.p_y = ctltree1.p_y_extent+ybuf;
}

void ctlok.lbutton_up()
{
   if ( ctltext1.p_text=="" ) return;
   path := ctltree1._dlpath():+ctltext1.p_text;
   _param1 = path;
   p_active_form._delete_window(1);
}

void _init_menu_shelving(int menu_handle,int no_child_windows,bool is_popup_menu=false)
{
   filename := "";
   if (no_child_windows) {
      return;
   }else{
      filename = _mdi.p_child.p_buf_name;
   }

   status := 0;
   submenuHandle := -1;
   if ( !is_popup_menu ) {
      status = _menu_find_loaded_menu_caption_prefix(menu_handle,"Version Control", submenuHandle);
   } else submenuHandle = menu_handle;
   if (status>=0) {
      status = _menu_find_loaded_menu_caption_prefix(submenuHandle,"Shelves",submenuHandle);
      if (status>=0) {
         index := _menu_find_loaded_menu_caption_prefix(submenuHandle,"Add to shelf");
         if (index>=0) {
            _menu_delete(submenuHandle,index);
         }
         len := svc_shelf_name_get_count();
         VCSystem := svc_get_vc_system(_file_path(filename));
         if ( len>0 && VCSystem!="" ) {
            testHandle := _menu_insert(submenuHandle,-1,MF_SUBMENU,"Add to shelf using "VCSystem);
            if ( testHandle ) {
               for ( i:=0;i<len;++i ) {
                  curShelfName := svc_get_shelf_name_from_index(i);
                  _menu_insert(testHandle,i,MF_ENABLED,curShelfName,'svc-add-to-shelf '_maybe_quote_filename(curShelfName)' '_maybe_quote_filename(filename));
               }
            }
         }
      }
   }
}

void _on_popup_shelving(_str menu_name,int menu_handle)
{
   _init_menu_shelving(menu_handle,_no_child_windows(),true);
}

