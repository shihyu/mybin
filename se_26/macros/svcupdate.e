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
#import "diffedit.e"
#import "diffsetup.e"
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
#import "saveload.e"
#import "seltree.e"
#import "sellist.e"
#import "sellist2.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "svcautodetect.e"
#import "svc.e"
#import "svccomment.e"
#import "svcshelf.e"
#import "treeview.e"
#import "vc.e"
#import "wkspace.e"
#import "se/vc/IVersionControl.e"
#import "se/lang/api/ExtensionSettings.e"
#endregion

using se.vc.IVersionControl;
using se.lang.api.ExtensionSettings;

const FIRST_BUTTON_INDEX = 1;
const SAVE_ALL_BUTTTON_INDEX = FIRST_BUTTON_INDEX;
const SAVE_NONE_BUTTON_INDEX = FIRST_BUTTON_INDEX+2;// There will be a close button

static int gInDiffFilesWithVersionControl;

definit()
{
   gInDiffFilesWithVersionControl = 0;
}

defeventtab _svc_update_save_all_button;

void _svc_update_save_all_button.lbutton_up()
{
   p_active_form._delete_window(SAVE_NONE_BUTTON_INDEX);
}

defeventtab _svc_mfupdate_form;
void ctldiff_binary_files.lbutton_up()
{
   _nocheck _control _ctlfile1;
   _SetDialogInfoHt("diffThisBinaryFile", 1, _ctlfile1);
   _SVCSetupDiffTextFiles();

   index := ctltree1._TreeCurIndex();
   ctltree1._TreeGetInfo(index,auto state,auto bmindex1,auto bmindex2,auto flags,auto lineNumber,-1,auto overlays);
   SVC_UPDATE_DIFF_INFO diffInfo;
   diffInfo.bmindex1 = bmindex1;
   diffInfo.diffableFiles = true;
   diffInfo.index = index;
   diffInfo.overlays = overlays;
   diffInfo.treeWID = ctltree1;

   filename := _SVCGetFilenameFromUpdateTree(index);
//   _SetDialogInfoHt("lastBufID1:":+filename, _ctlfile1.p_buf_id, _ctlfile1);
//   _SetDialogInfoHt("lastBufID2:":+filename, _ctlfile2.p_buf_id, _ctlfile1);
   diffFilesWithVersionControl(diffInfo);
   _SetDialogInfoHt("diffThisBinaryFile", 0, _ctlfile1);
}
void ctlupdate_all.lbutton_up()
{
   _str Captions[];
   Captions[0]='Update only new files and files that are not modified';
   Captions[1]='Update all files that are not in conflict';

   int result=RadioButtons("Update all files",Captions,1,'cvs_update_all');
   updateAll := false;
   if ( result==COMMAND_CANCELLED_RC ) {
      return;
   } else if ( result==1 ) {
   } else if ( result==2 ) {
      updateAll = true;
   }
   // Select all the out of date files.
   ctltree1.updateSelectOutOfDate(true,TREE_ROOT_INDEX,updateAll);

   // Be sure the buttons are enabled right
   svcEnableGUIUpdateButtons();

   // Call the button, but first be sure it is an update button
   if ( ctlupdate.p_caption==SVC_UPDATE_CAPTION_UPDATE ) {
      ctlupdate.call_event(ctlupdate,LBUTTON_UP);
   }
}

void _SVCGUIUpdateDialog(SVC_UPDATE_INFO (&fileStatusList)[],_str path,_str moduleName,
                         bool modal=false,_str VCSystemName="",STRARRAY &pathsToUpdate=null,
                         _str workspaceOrProject="")
{
   _DiffInitGSetupData();
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;
   modalOption := "";
   if ( modal ) modalOption = " -modal ";
   int formid=show('-xy -app -new ':+modalOption:+' _svc_mfupdate_form',fileStatusList,path,moduleName,VCSystemName,pathsToUpdate,workspaceOrProject);
   if ( !modal ) {
      if ( workspaceOrProject=="" ) {
         formid.p_active_form.p_caption=pInterface->getSystemNameCaption():+' ':+formid.p_active_form.p_caption;
      } else {
         formid.p_active_form.p_caption=pInterface->getSystemNameCaption():+' Update 'workspaceOrProject;
      }
   }
}

void ctlclose.on_create(SVC_UPDATE_INFO (&fileStatusList)[]=null,_str path="",
                        _str moduleName="",_str VCSystemName="",
                        STRARRAY pathsToUpdate=null)
{
   // There should not be anything in the delete list at this point.
   // We are adding the ORIGINAL buffers that were in the diff, because we have
   // our own set for the diff being disabled.
   DIFF_DELETE_ITEM delItemList[];
   if ( _find_control('_ctlfile1') ) {
      // This could be a dialog that inherits from the diff dialog but let's
      // you do consecutive files (probably svc update)

      _nocheck _control _ctlfile1;
      _DiffGetDeleteList(delItemList,_ctlfile1);
      delItemList[0].item = _ctlfile1.p_buf_id;
      delItemList[0].isView = false;
      delItemList[0].isSuspended = false;
      delItemList[0].attachedToBufferName = "";

      delItemList[1].item = _ctlfile2.p_buf_id;
      delItemList[1].isView = false;
      delItemList[1].isSuspended = false;
      delItemList[1].attachedToBufferName = "";
      _DiffSetDeleteList(delItemList,_ctlfile1);
   }

   ctllocal_path_label.p_caption = SVC_LOCAL_ROOT_LABEL:+path;
   ctlrep_label.p_caption = "Repository:":+moduleName;
   origWID := p_window_id;

   _nocheck _control ctltree1;
   p_window_id = ctltree1;
   if ( !_find_control('_ctlclose') ) {
      _DiffSetCloseMissing();
   }

   SVCSetupTree(fileStatusList,path,moduleName,VCSystemName,pathsToUpdate);
   _nocheck _control _ctlfile1;
   _SetDialogInfoHt("promptForNextFile",1,_ctlfile1);
//   ctlpicture1.p_border_style = BDS_NONE;
   p_window_id = origWID;
   ctlsave_all.p_visible = true;
   ctltypetoggle.p_visible = ctltypetoggle.p_enabled = false;
   _nocheck _control ctlgaugeWID;
   ctlpicture1.ctlgaugeWID.p_caption = "";

   ctlcollapseHistory.resizeToolButtonToLabel(ctlrep_label.p_window_id);
   ctlExpandDiff.resizeToolButtonToLabel(ctlrep_label.p_window_id);
}

// We get away with having both of these because this is in a container and 
// will always be called after the other one.  We do have to call the function
// that the on_create would run though.
void _ctlfile1.on_create() 
{
   _ctlfile1.p_eventtab = defeventtab _diff_form._ctlfile1;
   _DiffFile1OnCreate("","","");
}

void ctlhistory.lbutton_up()
{
   VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;

   index := ctltree1._TreeCurIndex();
   if ( index<0 ) return;
   filename := _SVCGetFilenameFromUpdateTree(index);
   if ( filename=="" ) return;
   svc_history(filename);
}

static void diffGUIUpdate(INTARRAY &selectedIndexList,STRARRAY &selectedFileList,INTARRAY (&selectedFileBitmaps)[],bool &filesModifiedInDiff)
{
   VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;

   // If no items were selected, add the current item
   if ( selectedIndexList==null || selectedIndexList._length()==0 ) {
      index := _TreeCurIndex();
      if ( index >= 0 ) {
         ctltree1._TreeGetInfo(index,auto state,auto bm1,0,0,auto junk, -1, auto overlays);
         filename := _SVCGetFilenameFromUpdateTree(index);
         selectedIndexList   :+= index;
         selectedFileBitmaps :+= overlays;
         selectedFileList    :+= filename;
      }
   }

   len := selectedIndexList._length();
   for ( i:=0;i<len;++i ) {
      filename := selectedFileList[i];
      if ( filename=="" ) continue;
      orig_file_date := _file_date(filename,'B');
      curOverlays := selectedFileBitmaps[i];
      svcGetStatesFromOverlays(curOverlays,auto hadAddedOverlay,auto hadDeletedOverlay,auto hadModOverlay,auto hadDateOverlay,auto hadCheckoutOverlay, auto hadUnknownOverlay, i==0);
      if ( hadModOverlay && hadDateOverlay) {
         STRARRAY captions;
         pInterface->getCurLocalRevision(filename,auto curLocalRevision);
         pInterface->getCurRevision(filename,auto curRevision);
         captions[0]='Compare local version of 'filename' 'curLocalRevision' with remote version 'curLocalRevision;
         captions[1]='Compare local version of 'filename' 'curLocalRevision' with remote version 'curRevision;
         captions[2]='Compare remote version of 'filename' 'curLocalRevision' with remote version 'curRevision;
         int result=RadioButtons("Newer version exists",captions,1,'cvs_diff');
         if ( result==COMMAND_CANCELLED_RC ) {
            return;
         } else if ( result==1 ) {
            svc_diff_with_tip(filename,curLocalRevision,"",true);
         } else if ( result==2 ) {
            svc_diff_with_tip(filename,curRevision,"",true);
         } else if ( result==3 ) {
            status := pInterface->getFile(filename,curLocalRevision,auto curLocalRevisionRemoteWID);
            if ( status ) {
               _message_box(nls(get_message(VSRC_SVC_COULD_NOT_GET_REMOTE_REPOSITORY_INFORMATION,filename':'curLocalRevision)));
               return;
            }
            status = pInterface->getFile(filename,curRevision,auto curRemoteRevisionWID);
            if ( status ) {
               _message_box(nls(get_message(VSRC_SVC_COULD_NOT_GET_REMOTE_REPOSITORY_INFORMATION,filename':'curRevision)));
               return;
            }
            pInterface->getLocalFileURL(filename,auto URL);
            diff('-modal -r1 -r2 -file1title "'URL' 'curLocalRevision'" -file2title "'URL' 'curRevision'" -viewid1 -viewid2 'curLocalRevisionRemoteWID' 'curRemoteRevisionWID);
            _delete_temp_view(curRemoteRevisionWID);
            _delete_temp_view(curLocalRevisionRemoteWID);
         }
      } else if ( hadCheckoutOverlay ) {
         pInterface->getFileStatus(filename,auto fileStatus);
         if ( fileStatus&SVC_STATUS_UPDATED_IN_INDEX ) {
            STRARRAY captions;
            captions[0]='Compare local version of 'filename' with last committed version';
            captions[1]='Compare local version of 'filename' with staged version';
            captions[2]='Compare staged version of 'filename' with last commited version';
            int result=RadioButtons("Staged version exists",captions,1,'cvs_diff');
            if ( result==COMMAND_CANCELLED_RC ) {
               return;
            }
            if ( result==1 ) {
               svc_diff_with_tip(filename,"",VCSystemName,true);
            }else if ( result==2 ) {
               status := _open_temp_view(filename,auto curLocalFileWID,auto origWID);
               p_window_id = origWID;
               if ( !status ) {
                  status = pInterface->getFile(filename,"",auto curStagedRevisionWID,true);
                  if ( !status ) {
                     pInterface->getLocalFileURL(filename,auto URL);
                     pInterface->getCurLocalRevision(filename,auto curLocalRevision);
                     pInterface->getCurRevision(filename,auto curRevision);
                     diff('-modal -r1 -r2 -file1title "'URL' 'curLocalFileWID'(local)" -file2title "'URL'(staged) 'curRevision'" -viewid1 -viewid2 'curLocalFileWID' 'curStagedRevisionWID);
                     _delete_temp_view(curStagedRevisionWID);
                  }
                  _delete_temp_view(curLocalFileWID);
               }
            }else if ( result==3 ) {
               status := pInterface->getFile(filename,"",auto curStagedRevisionWID,true);
               if ( !status ) {
                  pInterface->getLocalFileURL(filename,auto URL);
                  status = pInterface->getFile(filename,"",auto curRemoteRevisionWID);
                  if ( !status ) {
                     pInterface->getCurLocalRevision(filename,auto curLocalRevision);
                     pInterface->getCurRevision(filename,auto curRevision);
                     diff('-modal -r1 -r2 -file1title "'URL' 'curLocalRevision'(staged)" -file2title "'URL' 'curRevision'" -viewid1 -viewid2 'curStagedRevisionWID' 'curRemoteRevisionWID);
                     _delete_temp_view(curStagedRevisionWID);
                  }
                  _delete_temp_view(curRemoteRevisionWID);
               }
            }
         }
      } else if ( hadModOverlay && pInterface->getBaseRevisionSpecialName() != "") {
         svc_diff_with_tip(filename,pInterface->getBaseRevisionSpecialName(),VCSystemName,true);
      } else {
         svc_diff_with_tip(filename,"",VCSystemName,true);
      }
      diff_file_date := _file_date(filename,'B');
      if (diff_file_date != orig_file_date) {
         filesModifiedInDiff = true;
      }
   }
}

void ctldiff.lbutton_up()
{
   VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;

   filesModifiedInDiff := false;
   int selectedIndexList[];
   _str selectedFileList[];
   int selectedFileBitmaps[][];
   int info;

   origWID := p_window_id;
   origFID := p_active_form;
   p_window_id = ctltree1;
   // Add all the selected items
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      ctltree1._TreeGetInfo(index,auto state,auto bm1,0,0,auto junk, -1, auto overlays);
      filename := _SVCGetFilenameFromUpdateTree(index);
      selectedIndexList   :+= index;
      selectedFileBitmaps :+= overlays;
      selectedFileList    :+= filename;
   }
   p_window_id = origWID;

   ctltree1.diffGUIUpdate(selectedIndexList,selectedFileList,selectedFileBitmaps, filesModifiedInDiff);

   if (filesModifiedInDiff) {
      origFID._SVCUpdateRefreshAfterOperation(selectedFileList,selectedIndexList,null,pInterface,false);
   }
   origFID.ctltree1._set_focus();
}

void ctlupdate.lbutton_up()
{
   VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;

   isUpdateButton := lowcase(stranslate(p_caption,"",'&'))==lowcase(pInterface->getCaptionForCommand(SVC_COMMAND_UPDATE,false));
   isCommitButton := lowcase(stranslate(p_caption,"",'&'))==lowcase(pInterface->getCaptionForCommand(SVC_COMMAND_COMMIT,false));
   isMergeButton :=  lowcase(stranslate(p_caption,"",'&'))==lowcase(pInterface->getCaptionForCommand(SVC_COMMAND_MERGE,false));
   isAddButton :=    lowcase(stranslate(p_caption,"",'&'))==lowcase(pInterface->getCaptionForCommand(SVC_COMMAND_ADD,false));

#if 0 //9:27am 4/4/2013
   say('ctlupdate.lbutton_up isUpdateButton='isUpdateButton);
   say('ctlupdate.lbutton_up isCommitButton='isCommitButton);
   say('ctlupdate.lbutton_up isMergeButton='isMergeButton);
   say('ctlupdate.lbutton_up isAddButton='isAddButton);
#endif

   INTARRAY selectedIndexList;
   STRARRAY selectedFileList;

   mou_hour_glass(true);
   origWID := p_window_id;
   origFID := p_active_form;
   p_window_id = ctltree1;
   // Add all the selected items
   _str fileTable:[];
   directoriesAreInList := false;
   info := 0;
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      if ( index==TREE_ROOT_INDEX ) continue;
      if ( _TreeGetCheckState(index)==TCB_CHECKED ) {
         selectedIndexList :+= index;
         filename := _SVCGetFilenameFromUpdateTree(index,true);
//         if (last_char(filename)==FILESEP) continue;
         selectedFileList :+= filename;
         if ( _last_char(filename)==FILESEP ) {
            directoriesAreInList = true;
         }
         fileTable:[_file_case(filename)] = "";
      }
   }

   // If no items were selected, add the current item
   if ( selectedIndexList._length()==0 ) {
      index := _TreeCurIndex();
      if ( index>=0 )selectedIndexList :+= index;
      filename := _SVCGetFilenameFromUpdateTree(index);
      selectedFileList :+= filename;
   }
   p_window_id = origWID;

   refreshAfterOperation := true;
   status := 0;
   if ( isUpdateButton ) {
      if ( pInterface->getSystemSpecificFlags()&SVC_UPDATE_PATHS_RECURSIVE &&
           directoriesAreInList
           ) {
         removeChildFiles(selectedFileList);
      }
      status = pInterface->updateFiles(selectedFileList);
   } else if ( isCommitButton ) {
      STRARRAY removedItems;
      if ( pInterface->getSystemSpecificFlags()&SVC_UPDATE_PATHS_RECURSIVE &&
           directoriesAreInList
           ) {
         if ( def_svc_logging ) {
            logSelectedList(selectedFileList,"ctlupdate.lbutton_up 10 list");
         }
         removeChildFiles(selectedFileList);
         if ( def_svc_logging ) {
            logSelectedList(selectedFileList,"ctlupdate.lbutton_up 20 list");
         }
      }
      if ( def_svc_logging ) {
         logSelectedList(selectedFileList,"ctlupdate.lbutton_up 30 list");
      }
      useSVCCommentAndCommit := pInterface->commandsAvailable()&SVC_COMMAND_AVAILABLE_GET_COMMENT_AND_COMMIT;
      maybePromptToSaveFiles();
      if (useSVCCommentAndCommit) {
         status = _SVCGetCommentAndCommit(selectedFileList,selectedIndexList,fileTable,pInterface,p_active_form);
         refreshAfterOperation = false;
      } else {
         status = pInterface->commitFiles(selectedFileList);
      }
      if (!status) {
         disableDiffControls();
         _SVCLoadBlankFilesForDisabled();
      }
   } else if ( isAddButton ) {
      ctltree1.maybeRemoveParentItems(selectedIndexList,selectedFileList);
      status = pInterface->addFiles(selectedFileList);
   } else if ( isMergeButton ) {
      if (!_haveMerge()) {
         popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Merge");
      } else {
         // We only allow the merge button for a single file
         status = pInterface->mergeFile(selectedFileList[0]);
      }
   }
   _filewatchRefreshFiles(selectedFileList);
   if ( status ) {
      // If something failed, or a commit was cancelled, we don't want to clear
      // the checkboxes below
      return;
   }

   if (refreshAfterOperation) _SVCUpdateRefreshAfterOperation(selectedFileList,selectedIndexList,fileTable,pInterface,!isAddButton,isAddButton == true);
   if ( status ) return;
   p_window_id = origWID;
   origFID.ctltree1._set_focus();
}

static void maybeRemoveParentItems(INTARRAY &selectedIndexList,STRARRAY &selectedFileList)
{
   // Go through the selectedIndexList, and figure out which items in 
   // selectedFileList have "normal" parents.  Add those parent paths to 
   // pathsToRemove.
   info := 0;
   STRHASHTAB pathsToRemove;
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      if ( index==TREE_ROOT_INDEX ) continue;
      if ( _TreeGetCheckState(index)==TCB_CHECKED ) {
         filename := _SVCGetFilenameFromUpdateTree(index,true);
         parentIndex := _TreeGetParentIndex(index);
         _TreeGetInfo(parentIndex,auto state,auto bm1,auto bm2);
         if ( bm1==_pic_fldopen ) {
            parentCaption := _TreeGetCaption(parentIndex);
            pathsToRemove:[_file_case(parentCaption)] = "";
         }
      }
   }

   // Go through pathsToRemove and take out the items out of selectedFileList
   foreach (auto curPath => auto junk in pathsToRemove) {
      len := selectedFileList._length();
      for (i:=len-1;i>=0;--i) {
         if ( _file_eq(curPath,selectedFileList[i]) ) {
            selectedFileList._deleteel(i);
         }
      }
   }
}

static void logSelectedList(STRARRAY &selectedFileList,_str label)
{
   dsay('logSelectedList','svc');
   dsay(label,'svc');

   len := selectedFileList._length();
   for (i:=0;i<len;++i) {
      dsay('   'selectedFileList[i],'svc');
   }
}

static void buildPathIndexTable(int (&pathIndexTable):[], int tree_index=TREE_ROOT_INDEX)
{
   node_index := _TreeGetFirstChildIndex(tree_index);
   while (node_index > 0) {
      file_name := _SVCGetFilenameFromUpdateTree(node_index);
      pathIndexTable:[_file_case(file_name)] = node_index;
      _TreeGetInfo(node_index, auto state);
      if (state >= 0) {
         _maybe_append_filesep(file_name);
         pathIndexTable:[_file_case(file_name)] = node_index;
         buildPathIndexTable(pathIndexTable,node_index);
      }
      node_index = _TreeGetNextSiblingIndex(node_index);
   }
}

/**
 * Refresh the list of images according to Version control 
 * system specified by pInterface 
 * 
 * @author dhenry (9/27/2021)
 * 
 * @param selectedFileList list of filenames
 * @param selectedIndexList  list of tree indexes that 
 *                           correspond to <b>selectedFileList</b>
 * @param fileTable          
 * @param pInterface         
 * @param uncheck Uncheck tree indexes for selectedIndexList
 * @param isAdd              
 * @param removedAllOverlays 
 * 
 * @return int 
 */
void _SVCUpdateRefreshAfterOperation(STRARRAY &selectedFileList,
                                     INTARRAY &selectedIndexList,
                                     _str (&fileTable):[],
                                     IVersionControl *pInterface,
                                     bool uncheck=true,
                                     bool isAdd=false,
                                     bool &removedAllOverlays=false)
{
   numRemovedOverlays := 0;   
   SVCFileStatus dirStatusInfo:[];
   int pathIndexTable:[];
   // now got thru and set appropriate pictures
   len := selectedFileList._length();
   origWID := p_window_id;
   p_window_id = ctltree1;
   buildPathIndexTable(pathIndexTable);
   for ( i:=0;i<len;++i ) {
      SVC_UPDATE_INFO curFileInfo;
      curFileInfo.filename = selectedFileList[i];
      curFileInfo.status = SVC_STATUS_NONE;
      //say("refreshAfterOperation: file="curFileInfo.filename);
      
      // For the case of a diff, the fileTable can be null
      if ( fileTable!=null ) fileTable._deleteel(_file_case(selectedFileList[i]));

      if ( _last_char(curFileInfo.filename)==FILESEP ) {
         //say("refreshAfterOperation: DIRECTORY");

         if (!dirStatusInfo._indexin(_file_case(curFileInfo.filename))) {
            status := pInterface->getMultiFileStatus(curFileInfo.filename,auto fileStatusList);
            SVCUpdateCheckedItemsToData(fileStatusList,isAdd,curFileInfo.filename);
            if (status == 0) {
               for (j:=0; j<fileStatusList._length(); j++) {
                  dirStatusInfo:[_file_case(fileStatusList[j].filename)] = fileStatusList[j].status;
                  //say("refreshAfterOperation: found file status for: "fileStatusList[j].filename);
               }
            }
         }

      } else {

         // have we already done this file?
         status := FILE_NOT_FOUND_RC;
         if (dirStatusInfo._indexin(_file_case(curFileInfo.filename))) {
            curFileInfo.status = dirStatusInfo:[_file_case(curFileInfo.filename)];
            //say("refreshAfterOperation: FILE ALREADY DONE");
            status = 0;
         }

         // haven't found status for this file yet, so try directory.
         curPath := _file_path(curFileInfo.filename);
         _maybe_append_filesep(curPath);
         if (status && len > 1) {
            if (dirStatusInfo._indexin(_file_case(curPath))) {
               //say("refreshAfterOperation: PATH ALREADY DONE");
               status = 0;
            } else {
               //say("refreshAfterOperation: CHECKING FILE PATH");
               // get multiple file status for the directory containing this file
               status = pInterface->getMultiFileStatus(curPath,auto fileStatusList,SVC_UPDATE_PATH,true);
               SVCUpdateCheckedItemsToData(fileStatusList,isAdd);
               if (status == 0) {
                  dirStatusInfo:[_file_case(curPath)] = SVC_STATUS_NONE;
                  for (j:=0; j<fileStatusList._length(); j++) {
                     dirStatusInfo:[_file_case(fileStatusList[j].filename)] = fileStatusList[j].status;
                     //say("refreshAfterOperation: found file status for: "fileStatusList[j].filename);
                     if (_file_eq(fileStatusList[j].filename, curFileInfo.filename)) {
                        curFileInfo.status = fileStatusList[j].status;
                        //say("refreshAfterOperation: THAT'S THE FILE WE WERE LOOKING FOR!");
                     }
                  }
               }
            }
         }

         // Get the status from the version control system
         if (status) {
            //say("refreshAfterOperation: CHECKING INDIVIDUAL FILE STATUS");
            status = pInterface->getFileStatus(curFileInfo.filename,curFileInfo.status);
            dirStatusInfo:[_file_case(curFileInfo.filename)] = curFileInfo.status;
            if ( status ) break;
         }

         // Get the picture for the status
         _SVCGetFileBitmap(curFileInfo,auto bitmap,auto overlays=null);
         moddedPathIndex := pathIndexTable:[_file_case(curPath)];
         //say("refreshAfterOperation: looking up index of "curPath" => "((modedPathIndex==null)? "null":modedPathIndex));
         if ( moddedPathIndex==null ) {
            moddedPathIndex = _TreeSearch(TREE_ROOT_INDEX,_file_case(curPath),'T'_fpos_case);
            if (moddedPathIndex > 0) pathIndexTable:[_file_case(curPath)] = moddedPathIndex;
            //say("refreshAfterOperation: TREE SEARCH FOR "curPath" => "modedPathIndex);
         }
         // If the new picture doesn't match, set the new picture
         modedIndex := pathIndexTable:[_file_case(curFileInfo.filename)];
         //say("refreshAfterOperation: looking up index of "curFileInfo.filename" => "((modedIndex==null)? "null":modedIndex));
         if ( modedIndex==null ) {
            modedIndex = _TreeSearch(moddedPathIndex,_strip_filename(curFileInfo.filename,'P'),_fpos_case);
            if (modedIndex > 0) pathIndexTable:[_file_case(curFileInfo.filename)] = modedIndex;
            //say("refreshAfterOperation: TREE SEARCH FOR "curFileInfo.filename" => "modedIndex);
         }
         if ( modedIndex>=0 ) {
            _TreeGetInfo(modedIndex,auto state,auto curBitmap,curBitmap, 0,auto lineNumber, -1,auto origOverlays);
            if ( origOverlays!=overlays ) {
               ++numRemovedOverlays;
               _TreeSetInfo(modedIndex,state,bitmap,bitmap,0,1,-1,overlays);
            }
         }
         if ( fileTable!=null ) {
            // For the case of a diff, the fileTable can be null
            foreach ( auto curFilename => auto curValue in fileTable ) {
               curPath = _file_path(_file_case(curFilename));
               moddedPathIndex = pathIndexTable:[curPath];
               //say("refreshAfterOperation: looking up path index of "curPath" => "((modePathIndex==null)? "null":modePathIndex));
               if ( moddedPathIndex==null ) {
                  moddedPathIndex = _TreeSearch(TREE_ROOT_INDEX,curPath,'T'_fpos_case);
                  //say("refreshAfterOperation: TREE SEARCH FOR path index of "curPath" => "modePathIndex);
                  if (moddedPathIndex > 0) pathIndexTable:[curPath] = moddedPathIndex;
               }
               fileIndex := pathIndexTable:[_file_case(curFilename)];
               //say("refreshAfterOperation: looking up file index of "curFilename" => "((fileIndex==null)? "null":fileIndex));
               if (fileIndex == null) {
                  fileIndex = _TreeSearch(TREE_ROOT_INDEX,_strip_filename(curFilename,'P'),'T'_fpos_case);
                  if (fileIndex > 0) pathIndexTable:[_file_case(curFilename)] = fileIndex;
                  //say("refreshAfterOperation: TREE SEARCH for file index of "curFilename" => "fileIndex);
               }
               if ( fileIndex>=0 ) {
                  _TreeGetInfo(fileIndex,auto state, auto origBitmap,origBitmap, 0,auto lineNumber, -1,auto origOverlays);
                  if ( origOverlays!=overlays ) {
                     ++numRemovedOverlays;
                     _TreeSetInfo(fileIndex,state,_pic_cvs_file,_pic_cvs_file,0,1,-1,overlays);
                  }
               }
            }
         }
      }
   }

   removedAllOverlays = numRemovedOverlays!=0;
   if ( uncheck ) {
      foreach ( auto curIndex in selectedIndexList ) {
         _TreeSetCheckState(curIndex,TCB_UNCHECKED);
      }
   }
   svcEnableGUIUpdateButtons();

   mou_hour_glass(false);
   p_window_id = origWID;
}

/**
 * Remove files from <B>selectedFileList</B> that are children 
 * of directories that are also in <B>selectedFileList</B>.
 * 
 * @param selectedFileList list of files and directories that 
 *                         were selected in the dialog
 */
static void removeChildFiles(STRARRAY &selectedFileList)
{
   len := selectedFileList._length();
   STRHASHTAB dirTable;
   INTARRAY dirIndexes;

   // Go through and find all the directories and store them in a hashtable
   for ( i:=0;i<len;++i ) {
      curFile := _file_case(selectedFileList[i]);
      if ( _last_char(curFile)==FILESEP ) {
         dirTable:[_file_case(curFile)] = "";
         dirIndexes :+= i;
      }
   }

   // Go through all the files.  If the file is in a directory that will be 
   // updated already because it is a directory that will be updated, queue 
   // that file to be removed.
   STRHASHTAB usedDirs;
   INTARRAY delList;
   for ( i=0;i<len;++i ) {
      curFile := _file_case(selectedFileList[i]);
      if ( _last_char(curFile)!=FILESEP ) {
         curPath := _file_path(curFile);
         if ( dirTable:[_file_case(curPath)]!=null ) {
            // This file will be handled by the directory
            delList :+= i;
            usedDirs:[_file_case(curFile)] = "";
         }
      }
   }
   // Go through the list of files backwards, and delete the files that we do
   // not need. Actually, we're sorting the array descending, so we can go 
   // through it forwards.
   delList._sort('ND');
   len = delList._length();
   for ( i=0;i<len;++i ) {
      selectedFileList._deleteel(delList[i]);
   }
}


static _str getParentPath(_str path)
{
   _maybe_strip_filesep(path);
   return _strip_filename(path,'N');
}

static _str revertSelTreeCallback(int sl_event, typeless user_data, typeless info=null)
{
   // We don't want the DEL key to do antyhing
   switch (sl_event) {
   case SL_ONDELKEY:
      return "";
   case SL_ONDEFAULT:
      return 0;
   case SL_ONCLOSE:
      return 0;
   }
   return "";
}


bool svc_user_confirms_revert(STRARRAY &selectedFileList)
{
   msg := "This operation will revert the following files:\n";
   len := selectedFileList._length();
   // First go through and find any blank items and remove them
   for (i:=selectedFileList._length()-1;i>=0;--i) {
      if ( selectedFileList[i]=="" ) {
         selectedFileList._deleteel(i);
      }
   }
   len = selectedFileList._length();
   // If we have 5 items or less, use a message box to show the user the files
   // being reverted
   if ( selectedFileList._length()<=5 ) {
      for ( i =0; i< len; ++i) {
         msg :+= "\n"selectedFileList[i];
      }
      msg :+= "\n\nContinue?";
      result := _message_box(nls(msg),"", MB_YESNO);
      if (result==IDYES) return true;
      return false;
   }

   // Show the user a list of the files to be reverted
   status := select_tree(selectedFileList,callback:revertSelTreeCallback,caption:"Revert the following files?",SL_DESELECTALL|SL_DEFAULTCALLBACK);
   if ( status<0 ) {
      // Negative return code, probably COMMAND_CANCELLED_RC
      return false;
   }
   // It will return us the currently selected item, but we're going to do 
   // all items.  Return true.
   return true;
}

void ctlrevert.lbutton_up()
{
   // The revert button is currently only visible or invisible.  There is no 
   // other possible caption to concern ourselves with.  Since the button will
   // only be visible when it is possible to press it, we can simplly get our
   // information and perform the revert
   isAddButton := p_caption==SVC_UPDATE_CAPTION_ADD;
   VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;

   INTARRAY selectedIndexList;
   STRARRAY selectedFileList;
   int info;

   mou_hour_glass(true);
   origWID := p_window_id;
   origFID := p_active_form;
   p_window_id = ctltree1;

   // Add all the selected items
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      selectedIndexList :+= index;
      selectedFileList :+= _SVCGetFilenameFromUpdateTree(index);
   }

   // If no items were selected, add the current item
   if ( selectedIndexList._length()==0 ) {
      index := _TreeCurIndex();
      if ( index>=0 ){
         selectedIndexList :+= index;
         selectedFileList :+= _SVCGetFilenameFromUpdateTree(index);
      }
   }
   p_window_id = origWID;

   if ( !svc_user_confirms_revert(selectedFileList) ) {
      return;
   }

   status := pInterface->revertFiles(selectedFileList);
   disableDiffControls();
   _SVCLoadBlankFilesForDisabled();
   _filewatchRefreshFiles(selectedFileList);

   _str fileTable:[];
   // now go thru and set appropriate pictures
   len := selectedFileList._length();
   for ( i:=0;i<len;++i ) {
      fileTable:[_file_case(selectedFileList[i])] = "";
   }

   _SVCUpdateRefreshAfterOperation(selectedFileList,selectedIndexList,fileTable,pInterface);
   _SVCSetupDiffTextFiles();
   disableDiffControls();

   mou_hour_glass(false);
   if ( status ) return;
   origFID.ctltree1._set_focus();
}

void ctlmerge.lbutton_up()
{
   // The revert button is currently only visible or invisible.  There is no 
   // other possible caption to concern ourselves with.  Since the button will
   // only be visible when it is possible to press it, we can simplly get our
   // information and perform the revert
   isResolveButton := p_caption==SVC_UPDATE_CAPTION_RESOLVE;
   isMergeButton := p_caption==SVC_UPDATE_CAPTION_MERGE;

   INTARRAY selectedIndexList;
   STRARRAY selectedFileList;
   int info;

   mou_hour_glass(true);
   origWID := p_window_id;
   origFID := p_active_form;
   p_window_id = ctltree1;

   // Add all the selected items
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      selectedIndexList :+= index;
      selectedFileList :+= _SVCGetFilenameFromUpdateTree(index);
   }

   // If no items were selected, add the current item
   if ( selectedIndexList._length()==0 ) {
      index := _TreeCurIndex();
      if ( index>=0 )selectedIndexList :+= index;
      filename := _SVCGetFilenameFromUpdateTree(index);
      selectedFileList :+= filename;
   }
   p_window_id = origWID;

   if ( selectedFileList._length()==0 ) {
      _message_box(nls("No files selected"));
      return;
   }

   autoVCSystem := svc_get_vc_system(selectedFileList[0]);
   IVersionControl *pInterface = svcGetInterface(autoVCSystem);
   if ( pInterface==null ) return;

   status := 0;
   if ( isResolveButton ) {
      status = pInterface->resolveFiles(selectedFileList);
   }
   _filewatchRefreshFiles(selectedFileList);

   // now got thru and set appropriate pictures
   len := selectedFileList._length();
   for ( i:=0;i<len;++i ) {

      SVC_UPDATE_INFO curFileInfo;
      curFileInfo.filename = selectedFileList[i];

      // Get the status from the version control system
      status = pInterface->getFileStatus(curFileInfo.filename,curFileInfo.status);
      if ( status ) break;

      // Get the picture for the status
      _SVCGetFileBitmap(curFileInfo,auto bitmap,auto overlays);

      // If the new picture doesn't match, set the new picture
      p_window_id = ctltree1;
      _TreeGetInfo(selectedIndexList[i],auto state,auto curBitmap);
      _TreeSetInfo(selectedIndexList[i],state,bitmap,bitmap,0,1,-1,overlays);
      p_window_id = origWID;
   }

   mou_hour_glass(false);
   if ( status ) return;
   origFID.ctltree1._set_focus();
}

// Remove CVSGetFilenameFromUpdateTree when this solidifies
_str _SVCGetFilenameFromUpdateTree(int index=-1,bool allowFolders=false, bool allowUnkownFolders=false, int treeWID=ctltree1)
{
   wid := p_window_id;
   p_window_id=treeWID;
   int curindex=index;
   if ( curindex==-1 ) {
      curindex=_TreeCurIndex();

      if ( _TreeGetNumSelectedItems()==1 ) {
         int info;
         selIndex := _TreeGetNextCheckedIndex(1,info);
         if ( selIndex>=0 && selIndex!=curindex ) curindex=selIndex;
      }
   }
   int state,bmindex1,bmindex2;
   _TreeGetInfo(curindex,state,bmindex1,bmindex2);
   filename := "";
   // 1/19/2021
   // This stil works even though we've gone to overlays because _pic_cvs_file 
   // is at the top
   if ( bmindex1==_pic_cvs_file
        || bmindex1==_pic_cvs_file_qm
        || bmindex1==_pic_file_old
        || bmindex1==_pic_file_old_mod
        || bmindex1==_pic_file_mod
        || bmindex1==_pic_file_mod_prop
        || bmindex1==_pic_cvs_filep
        || bmindex1==_pic_cvs_filem
        || bmindex1==_pic_cvs_file_new
        || bmindex1==_pic_cvs_file_obsolete
        || bmindex1==_pic_cvs_file_conflict
        || bmindex1==_pic_cvs_file_conflict_updated
        || bmindex1==_pic_cvs_file_conflict_local_added
        || bmindex1==_pic_cvs_file_conflict_local_deleted
        || bmindex1==_pic_cvs_file_error
        || bmindex1==_pic_cvs_filem_mod
        || bmindex1==_pic_file_del
        || bmindex1==_pic_cvs_fld_date
        || bmindex1==_pic_cvs_fld_mod_date
        || bmindex1==_pic_filep
      ) {
      filename=_TreeGetCaption(curindex);
      filename=_TreeGetCaption(_TreeGetParentIndex(curindex)):+filename;
      if ( bmindex1==_pic_cvs_fld_qm ) {
         filename :+= FILESEP;
      }
   } else if ( bmindex1==_pic_cvs_fld_qm && allowUnkownFolders ) {
      filename=_TreeGetCaption(curindex);
      filename=_TreeGetCaption(_TreeGetParentIndex(curindex)):+filename;
      filename :+= FILESEP;
   } else if (    bmindex1==_pic_cvs_fld_m
               || bmindex1==_pic_cvs_fld_p
               || bmindex1==_pic_cvs_fld_qm
               || bmindex1==_pic_cvs_fld_mod
               || (allowFolders && bmindex1==_pic_fldopen)
             ) {
      filename=_TreeGetCaption(curindex);
   }
   p_window_id=wid;
   return(filename);
}


static void getWorkspaceFilesHt(STRARRAY &workspaceFileList, STRHASHTAB &workspaceFileHT)
{
   foreach (auto curFile in workspaceFileList) {
      workspaceFileHT:[_file_case(curFile)] = curFile;
   }
}

static bool haveWildcardsInWorkspace(STRARRAY &projectFileList)
{
   len := projectFileList._length();
   for (i:=0;i<len;++i) {
      int project_handle=_ProjectHandle(projectFileList[i]);
      _xmlcfg_find_simple_array(project_handle,
                                VPJX_FILES"//"VPJTAG_F:+
                                //XPATH_CONTAINS('N','['_escape_re_chars(WILDCARD_CHARS)']','r'),
                                XPATH_CONTAINS('N','['_escape_re_chars(WILDCARD_CHARS)']','r'),
                                auto refiltered,TREE_ROOT_INDEX,VSXMLCFG_FIND_VALUES);
      if (refiltered._length()) return true;
   }
   return false;
}

static void SVCSetupTree(SVC_UPDATE_INFO (&fileStatusList)[],_str rootPath,_str moduleName,_str VCSystemName,STRARRAY &pathsToUpdate)
{
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;
   _SetDialogInfoHt("VCSystemName",VCSystemName,_ctlfile1);
   _SetDialogInfoHt("inSVCSetupTree",1,_ctlfile1);
   rootPath = strip(rootPath,'B','"');
   _maybe_append_filesep(rootPath);
   len := pathsToUpdate._length();
   int pathIndexes:[]=null;
   if ( pathsToUpdate._length()>0 ) {
      for (i:=0;i<len;++i) {
         curRootIndex := _TreeAddItem(TREE_ROOT_INDEX,pathsToUpdate[i],TREE_ADD_AS_CHILD,_pic_fldopen,_pic_fldopen);
         _TreeSetCheckable(curRootIndex,1,1);
         _SVCSeedPathIndexes(pathsToUpdate[i],pathIndexes,curRootIndex);
      }
   } else {
      rootIndex :=_TreeAddItem(TREE_ROOT_INDEX,rootPath,TREE_ADD_AS_CHILD,_pic_fldopen,_pic_fldopen);
      _TreeSetCheckable(rootIndex,1,1);
      _SVCSeedPathIndexes(rootPath,pathIndexes,rootIndex);
   }
   len = fileStatusList._length();
   
   _getProjectFilesInWorkspace(_workspace_filename,auto projectFileList);
   haveWildcards := false;
   if ( def_svc_update_only_shows_wkspace_files ) {
      haveWildcards = haveWildcardsInWorkspace(projectFileList);
   }
   STRARRAY workspaceFileList;
   STRHASHTAB workspaceFileHT;
   if ( def_svc_update_only_shows_wkspace_files && haveWildcards ) {
      _getWorkspaceFiles(_workspace_filename, workspaceFileList);
      getWorkspaceFilesHt(workspaceFileList, workspaceFileHT);
      getWorkspaceFilesHt(projectFileList, workspaceFileHT);
   }

   for ( i:=0;i<len;++i ) {
      if ( def_svc_update_only_shows_wkspace_files && haveWildcards ) {
         if ( workspaceFileHT:[_file_case(fileStatusList[i].filename)] == null ) {
            continue;
         }
      }
      curPath := _file_path(fileStatusList[i].filename);
      if ( _last_char(fileStatusList[i].filename)==FILESEP ) {
         curPath = fileStatusList[i].filename;
         _maybe_append_filesep(curPath);
         pathIndex := _SVCGetPathIndex(curPath,rootPath,pathIndexes);
         _SVCGetFileBitmap(fileStatusList[i],auto bmIndex,auto overlays);
         _TreeGetInfo(pathIndex,auto state, auto bm1);
         _TreeSetInfo(pathIndex,state,bmIndex,bmIndex,0,1,-1,overlays);
         _TreeSetCheckable(pathIndex,1,0);
      } else {
         parentIndex := -1;
         // If a directory needs to be updated, or committed, it will come 
         // through as a filename without a trailing FILESEP.  Need to check for
         // that.
         if ( isdirectory(fileStatusList[i].filename) ) {
            parentIndex = _SVCGetPathIndex(fileStatusList[i].filename:+FILESEP,rootPath,pathIndexes);
         } else {
            parentIndex = _SVCGetPathIndex(curPath,rootPath,pathIndexes);
         }
         skip := def_svc_update_only_shows_controlled_files && (fileStatusList[i].status&SVC_STATUS_NOT_CONTROLED);
         if ( !skip ) {
            _SVCGetFileBitmap(fileStatusList[i],auto bmIndex,auto overlays);
            newIndex := _TreeAddItem(parentIndex,_strip_filename(fileStatusList[i].filename,'P'),TREE_ADD_AS_CHILD,bmIndex,bmIndex,-1);
            _TreeSetInfo(newIndex,-1,bmIndex,bmIndex, 0, 1, -1, overlays);
            _TreeSetCheckable(newIndex,1,0);
         }
      }
   }
   origWID := p_window_id;
   p_window_id = ctltree1;
   // Have to be sure the version control system will always list files under 
   // empty folders before we remove empty folders
   if (pInterface->listsFilesInUncontrolledDirectories()) removeEmptyFolders();
   _TreeSortTree();

   selectInitialIndex();
   p_window_id = origWID;
   _SetDialogInfoHt("inSVCSetupTree",null,_ctlfile1);
}

static int gOnChangeTimerHandle = -1;

static void selectInitialIndex()
{
   modIndex := -1;
   outerloop:
   for (index := _TreeGetFirstChildIndex(TREE_ROOT_INDEX); index>0; index = _TreeGetNextIndex(index)  ) {
      _TreeGetInfo(index, auto state, auto bm1, auto bm2, auto nodeFlags,auto lineNumber, -1, auto overlays);
      if ( bm1 == _pic_cvs_file && overlays._length()>0 ) {
         len := overlays._length();
         for ( i := 0; i < len; ++i ) {
            if ( overlays[i] == _pic_file_mod_overlay ) {
               modIndex = index;
               break outerloop;
            }
         }
      }
   }
   if ( modIndex > 0 ) {
      _TreeSetCurIndex(modIndex);
      _SetDialogInfoHt("setInitIndex", 1, _ctlfile1);
      _TreeSetCheckState(modIndex,0);
   }
}

static void removeEmptyFolders()
{
   INTARRAY delList;
   index := _TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   for (;;) {
      if (index<0) break;
      _TreeGetInfo(index,auto state, auto bm1);
      if ( bm1==_pic_fldopen ) {
         childIndex := _TreeGetFirstChildIndex(index);
         if ( childIndex<0 ) {
            delList :+= index;
         }
      }
      index = _TreeGetNextIndex(index);
   }
   len := delList._length();
   for (i:=0;i<len;++i) {
      _TreeDelete(delList[i]);
   }
}

/**
 * 
 * 
 * @param fileStatusList List of files to update
 * @param isAdd          Set this to true if this is used after 
 *                       an add operation
 * @param topFilename    Set this to a filename or directory if 
 *                       you are sure it will be the top most
 *                       one it the tree.
 */
static void SVCUpdateCheckedItemsToData(SVC_UPDATE_INFO (&fileStatusList)[],bool isAdd=false,
                                        _str topFilename="")
{
   SVC_UPDATE_INFO statusTable:[];
   len := fileStatusList._length();
   for ( i:=0;i<len;++i ) {
      // Have to be sure we have the FILESEP in case we wind up adding this item
      // to the tree at the bottom of the function.
      if ( isdirectory(fileStatusList[i].filename) ) _maybe_append_filesep(fileStatusList[i].filename);
      statusTable:[_file_case(fileStatusList[i].filename)] = fileStatusList[i];
   }
   info := 0;
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if (ff==1 && index<0) {
         // Do this in case the item was not actually checked, the user just
         // wants to operate on the current item.
         index = _TreeCurIndex();
      }
      if ( index<0 ) break;
      curFilename := _SVCGetFilenameFromUpdateTree(index);
      if ( length(curFilename) < length(topFilename)) {
         continue;
      }
      _TreeGetInfo(index,auto state,auto bm1);
      
      bmIndex := bm1;
      INTARRAY overlays;
      if ( statusTable:[_file_case(curFilename)]==null ) {
         if ( _last_char(curFilename)==FILESEP || isdirectory(curFilename) ) {
            bmIndex = _pic_fldopen;
         } else {
            bmIndex = _pic_cvs_file;
         }
      } else {
         _SVCGetFileBitmap(statusTable:[_file_case(curFilename)],bmIndex,overlays);
      }
      // Delete the item from the hash table.  This is so that when we get to 
      // the bottom of the function we know that anything left can be added
      statusTable._deleteel(_file_case(curFilename));
      _TreeSetInfo(index,state,bmIndex,bmIndex,0,1,-1,overlays);
   }

   // If we are updating after an add operation, the rest of the items in the 
   // hashtable need to be added to the tree
   if ( isAdd ) {
      int pathIndexes:[]=null;
      getLocalRootFromDialog(auto rootPath);
      typeless j;
      seedCurrentDirectories(pathIndexes);
      for (j._makeempty();;) {
         statusTable._nextel(j);
         if (j._isempty()) break;
         curPath := j;
         pathIndex := _SVCGetPathIndex(_strip_filename(curPath,'N'),rootPath,pathIndexes);
         if (pathIndex>=0) {
            _SVCGetFileBitmap(statusTable:[_file_case(curPath)],auto bmIndex,auto overlays);
            curPath = _strip_filename(curPath,'P');
            findIndex := _TreeSearch(pathIndex,curPath);
            if ( findIndex<0 ) {
               int newIndex = _TreeAddItem(pathIndex,curPath,TREE_ADD_AS_CHILD,bmIndex,bmIndex,-1);
               _TreeSetCheckable(newIndex,1,1);
            } else {
               _TreeGetInfo(findIndex,auto state);
               _TreeSetInfo(findIndex,state,bmIndex,bmIndex,0,1,-1,overlays);
               _TreeSetCheckable(findIndex,1,1);
            }
         }
      }
   }
   ctltree1._TreeSortTree();
}

static void seedCurrentDirectories(int (&pathIndexes):[]) 
{
   index := _TreeGetFirstChildIndex(TREE_ROOT_INDEX);

   for (;;) {
      if (index<0) break;
      _TreeGetInfo(index,auto state,auto bm1);
      if ( bm1==_pic_cvs_fld_p
           || bm1==_pic_cvs_fld_qm
           || bm1==_pic_cvs_fld_date
           || bm1==_pic_cvs_fld_mod_date
           || bm1==_pic_fldopen ) {
         cap := _TreeGetCaption(index);
         pathIndexes:[_file_path(cap)] = index;
      }
      index = _TreeGetNextIndex(index);
   }
}

static _str getStatus(SVC_UPDATE_INFO &fileStatus) {
   str:=fileStatus.filename' ';
   if (fileStatus.status&SVC_STATUS_SCHEDULED_FOR_ADDITION) str :+= '|SVC_STATUS_SCHEDULED_FOR_ADDITION';
   if (fileStatus.status&SVC_STATUS_SCHEDULED_FOR_DELETION) str :+= '|SVC_STATUS_SCHEDULED_FOR_DELETION';
   if (fileStatus.status&SVC_STATUS_MODIFIED) str :+= '|SVC_STATUS_MODIFIED';
   if (fileStatus.status&SVC_STATUS_CONFLICT) str :+= '|SVC_STATUS_CONFLICT';
   if (fileStatus.status&SVC_STATUS_EXTERNALS_DEFINITION) str :+= '|SVC_STATUS_EXTERNALS_DEFINITION';
   if (fileStatus.status&SVC_STATUS_IGNORED) str :+= '|SVC_STATUS_IGNORED';
   if (fileStatus.status&SVC_STATUS_NOT_CONTROLED) str :+= '|SVC_STATUS_NOT_CONTROLED';
   if (fileStatus.status&SVC_STATUS_MISSING) str :+= '|SVC_STATUS_MISSING';
   if (fileStatus.status&SVC_STATUS_NODE_TYPE_CHANGED) str :+= '|SVC_STATUS_NODE_TYPE_CHANGED';
   if (fileStatus.status&SVC_STATUS_PROPS_MODIFIED) str :+= '|SVC_STATUS_PROPS_MODIFIED';
   if (fileStatus.status&SVC_STATUS_PROPS_ICONFLICT) str :+= '|SVC_STATUS_PROPS_ICONFLICT';
   if (fileStatus.status&SVC_STATUS_LOCKED) str :+= '|SVC_STATUS_LOCKED';
   if (fileStatus.status&SVC_STATUS_SCHEDULED_WITH_COMMIT) str :+= '|SVC_STATUS_SCHEDULED_WITH_COMMIT';
   if (fileStatus.status&SVC_STATUS_SWITCHED) str :+= '|SVC_STATUS_SWITCHED';
   if (fileStatus.status&SVC_STATUS_NEWER_REVISION_EXISTS) str :+= '|SVC_STATUS_NEWER_REVISION_EXISTS';
   if (fileStatus.status&SVC_STATUS_TREE_ADD_CONFLICT) str :+= '|SVC_STATUS_TREE_ADD_CONFLICT';
   if (fileStatus.status&SVC_STATUS_TREE_DEL_CONFLICT) str :+= '|SVC_STATUS_TREE_DEL_CONFLICT';
   if (fileStatus.status&SVC_STATUS_EDITED) str :+= '|SVC_STATUS_EDITED';
   if (fileStatus.status&SVC_STATUS_NO_LOCAL_FILE) str :+= '|SVC_STATUS_NO_LOCAL_FILE';
   if (fileStatus.status&SVC_STATUS_PROPS_NEWER_EXISTS) str :+= '|SVC_STATUS_PROPS_NEWER_EXISTS';
   if (fileStatus.status&SVC_STATUS_DELETED) str :+= '|SVC_STATUS_DELETED';
   if (fileStatus.status&SVC_STATUS_UNMERGED) str :+= '|SVC_STATUS_UNMERGED';
   if (fileStatus.status&SVC_STATUS_COPIED_IN_INDEX) str :+= '|SVC_STATUS_COPIED_IN_INDEX';
   if (fileStatus.status&SVC_STATUS_UPDATED_IN_INDEX) str :+= '|SVC_STATUS_UPDATED_IN_INDEX';
   if (!fileStatus.status) str:+= '|SVC_STATUS_NONE';
   return str;
}

static void _SVCGetFileBitmap(SVC_UPDATE_INFO &fileStatus,int &bitmap1, INTARRAY &overlays,
                              int defaultBitmap=_pic_cvs_file,
                              int defaultBitmapFolder=_pic_fldopen)
{
   if ( _last_char(fileStatus.filename)==FILESEP ) {
      bitmap1=_pic_fldopen;
   } else {
      bitmap1=_pic_cvs_file;
   }
   if ( fileStatus.status & SVC_STATUS_NOT_CONTROLED ) {
      overlays :+=  _pic_file_unknown_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_MISSING ) {
      overlays :+=  _pic_file_deleted_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_UPDATED_IN_INDEX ) {
      overlays :+=  _pic_file_add_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_SCHEDULED_FOR_DELETION ) {
      overlays :+=  _pic_file_deleted_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_SCHEDULED_FOR_ADDITION ) {
      overlays :+=  _pic_file_add_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_TREE_ADD_CONFLICT ) {
      overlays :+=  _pic_file_add_overlay;
      overlays :+=  _pic_file_conflict_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_TREE_DEL_CONFLICT ) {
      overlays :+=  _pic_file_deleted_overlay;
      overlays :+=  _pic_file_conflict_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_UNMERGED ) {
      overlays :+=  _pic_file_not_merged_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_COPIED_IN_INDEX ) {
      overlays :+=  _pic_file_copied_overlay;
   }
   if ( fileStatus.status & SVC_STATUS_LOCKED ) {
      overlays :+=  _pic_file_locked_overlay;
   }

   if ( fileStatus.status & SVC_STATUS_CONFLICT ) {
      overlays :+=  _pic_file_conflict_overlay;
   }else{
      if ( fileStatus.status & SVC_STATUS_MODIFIED ) {
         overlays :+=  _pic_file_mod_overlay;
         if ( _SVCTreatAsBinaryFile(fileStatus.filename) ) {
            overlays :+=  _pic_file_bin_svc_overlay;
         }
      }
      if ( fileStatus.status & SVC_STATUS_NEWER_REVISION_EXISTS ) {
         overlays :+=  _pic_file_vc_date_overlay;
      }
   }
}

void ctlcollapseHistory.lbutton_up()
{
   p_active_form.call_event(p_active_form,ON_RESIZE);
   if ( p_value == 1 ) {
      ctltree1.call_event(CHANGE_SELECTED,ctltree1._TreeCurIndex(),ctltree1,ON_CHANGE,'W');
   }
}

static void getModifiedFileList(STRARRAY &modifiedBufIDList, STRARRAY &modifiedFilenameCaptions)
{
   _DiffGetAllMiscInfo(auto allMiscInfo);
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   foreach ( auto curBufIndex => auto curMiscInfo in allMiscInfo ) {
      status := load_files('+bi 'curBufIndex);
      if (!status && p_modify) {
         modifiedBufIDList :+= curBufIndex;
         status = load_files('+bi 'curMiscInfo.buffer1.WholeFileBufId);
         if (!status) {
            modifiedFilenameCaptions :+= _strip_filename(p_buf_name,'p'):+"\t":+_strip_filename(p_buf_name,'N');
         }
      }
   }
   p_window_id = origWID;
}

static void saveAllFiles(STRARRAY &modifiedBufIDList=null, STRARRAY &modifiedFilenameCaptions=null)
{
   _DiffGetAllMiscInfo(auto allMiscInfo);
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();
   foreach ( auto curBufIndex => auto curMiscInfo in allMiscInfo ) {
      status := load_files('+bi 'curBufIndex);
      if (!status && p_modify) {
         modifiedBufIDList :+= curBufIndex;
         status = load_files('+bi 'curMiscInfo.buffer2.WholeFileBufId);
         if (!status) {
            modifiedFilenameCaptions :+= _strip_filename(p_buf_name,'p'):+"\t":+_strip_filename(p_buf_name,'N');
         }
      }
   }

   unsavedList := "";
   p_window_id = origWID;
   p_window_id = _ctlfile1;
   origBufID := _ctlfile1.p_buf_id;
   foreach ( auto curBufID in modifiedBufIDList ) {
      status := load_files("+bi ":+curBufID);
      if ( !status ) {
         _diff_save();
      } else {
         unsavedList :+= p_buf_name :+ "\n";
      }
   }
   load_files("+bi ":+origBufID);
   p_window_id = origBufID;
}
     
static _str promptToSaveCB(int reason, typeless user_data, typeless info=null)
{

   switch ( reason ) {
   case SL_ONINITFIRST:
      select_tree_message(user_data);
      _nocheck _control ctl_ok;
      _nocheck _control ctl_cancel;
      _nocheck _control ctl_invert;
      _nocheck _control ctl_selectall;
      ctl_ok.p_caption = "&Save Selected";
      ctl_ok.p_width = _text_width(ctl_ok.p_caption) + 240;
      ctl_cancel.p_x = ctl_ok.p_x_extent + 60;

      ctl_invert.p_caption = "Save &None";
      ctl_invert.p_x = ctl_cancel.p_x_extent + 60;
      ctl_invert.p_eventtab = defeventtab _svc_update_save_all_button;

      ctl_selectall.p_x = ctl_invert.p_x_extent + 60;
      break;
   case SL_ONCLOSE:
      break;
   }

   return "";
}

static int maybePromptToSaveFiles()
{
   origWID := p_window_id;
   getModifiedFileList(auto modifiedBufIDList,auto modifiedFilenameCaptions);
   p_window_id = origWID;

   bool treeSelectList[];
   for ( i:=0;i<modifiedFilenameCaptions._length();++i ) {
      treeSelectList :+= true;
   }

   if ( modifiedBufIDList._length()>0 ) {
      result := select_tree(modifiedFilenameCaptions,
                            modifiedBufIDList,
                            select_array:treeSelectList,
                            callback:promptToSaveCB,caption:"Save modified local files?",
                            sl_flags:SL_CHECKLIST|SL_COLWIDTH|SL_SELECTALL|SL_INVERT|SL_CLOSEBUTTON,
                            col_names:"Filename,Path",
                            col_flags:(TREE_BUTTON_SORT|TREE_BUTTON_PUSHBUTTON|TREE_BUTTON_SORT_FILENAME)','(TREE_BUTTON_SORT|TREE_BUTTON_PUSHBUTTON|TREE_BUTTON_SORT_FILENAME),
                            modal:true
                            );
      if ( result==COMMAND_CANCELLED_RC ) {
         return COMMAND_CANCELLED_RC;
      } else if ( result==SAVE_NONE_BUTTON_INDEX ) {
         p_window_id = origWID;
         return 0; 
      }
      // Save all selected files
      INTARRAY bufIDList;
      resultList := result;
      for ( ;; ) {
         parse resultList with auto curDiffBufID "\n" resultList;
         if ( curDiffBufID=="" ) break;
         bufIDList :+= (int)curDiffBufID;
      }

      for ( i=0;i<bufIDList._length();++i ) {
         // in svcupdate we can do this because the right side is always from 
         // verison control and will not be saved
         p_window_id = origWID._ctlfile1;

         status := load_files("+bi ":+bufIDList[i]);
         if ( !status ) {
            _diff_save();
         }
      }         
   }
   p_window_id = origWID;
   return 0;
}

void _svc_mfupdate_form.on_close()
{
   origBufIDList := _DiffGetListOfOriginalBufIDs();
   foreach ( auto curBufID in origBufIDList ) {
      _DiffSetBufferIsDiffed(curBufID, false);
   }
   status := maybePromptToSaveFiles();
   if ( status==COMMAND_CANCELLED_RC ) return;

   p_active_form._delete_window(0);
}

void ctlsave_all.lbutton_up()
{
   saveAllFiles();
}

static void deleteBuffersForDisabledDiff()
{
   disabledDiffBufID1 := _GetDialogInfoHt("disabledDiffBufID1",_ctlfile1);
   disabledDiffBufID2 := _GetDialogInfoHt("disabledDiffBufID2",_ctlfile1);
   origWID := p_window_id;
   p_window_id = HIDDEN_WINDOW_ID;
   _safe_hidden_window();

   if ( disabledDiffBufID1!=null ) {
      status := load_files('+bi 'disabledDiffBufID1);
      if ( !status ) {
         _delete_buffer();
      }
   }
   if ( disabledDiffBufID2!=null ) {
      status := load_files('+bi 'disabledDiffBufID2);
      if ( !status ) {
         _delete_buffer();
      }
   }

   p_window_id = origWID;
   _SetDialogInfoHt("disabledDiffBufID1",null,_ctlfile1);
   _SetDialogInfoHt("disabledDiffBufID2",null,_ctlfile1);
}

void _svc_mfupdate_form.on_destroy()
{
   if ( gOnChangeTimerHandle>0 ) {
      _kill_timer(gOnChangeTimerHandle);
   }
   gOnChangeTimerHandle = -1;
   // Save the state of the expand history button
   _moncfg_append_retrieve( ctlcollapseHistory, ctlcollapseHistory.p_value, "_svc_mfupdate_form.ctlcollapseHistory" );

   // Save the postition of the sizer bar
   _nocheck _control _grabbar_vert;
   _moncfg_append_retrieve(_grabbar_vert, _grabbar_vert.p_x, "_svc_mfupdate_form._grabbar_vert" );

   // Save expand state of diff
   _nocheck _control ctlExpandDiff;
   _moncfg_append_retrieve( ctlExpandDiff, ctlExpandDiff.p_value, "_svc_mfupdate_form.ctlExpandDiff" );

   // Save the position of the diff pic contaniner
   _nocheck _control ctlpicture1;
   _moncfg_append_retrieve( ctlpicture1, ctlpicture1.p_x, "_svc_mfupdate_form.ctlpicture1" );

   _DiffUnsuspendItems();
   deleteBuffersForDisabledDiff();

   _SetDialogInfoHt("inSVCUpdateTreeOnChange",0,_ctlfile1);

   // Don't need to call _diff_form's on_destroy here, it will get run
   _DiffKillUpdateTimer();
}

void ctlExpandDiff.lbutton_up()
{
   inResize := _GetDialogInfoHt("inResize",_ctlfile1);
   if (inResize==1) return;
   int xbuffer=ctllocal_path_label.p_x;
   if ( p_value ) {
      p_active_form.p_width = ctlpicture1.p_x_extent;
      _SetDialogInfoHt("overrideSameIndexFile", 1, _ctlfile1);
   } else {
      p_active_form.p_width = ctlpicture1.p_x - xbuffer;
      lastLocalFilename := "";
      misc := _DiffGetDiffShowingInfo();
      if (misc!=null) {
         lastLocalFilename = _DiffGetFilenameFromDialog(misc, '1');
      }
      _DiffCloseFileFromSVCUpdate(_ctlfile1, lastLocalFilename, auto bufferIDsRemoved);
      _SVCLoadBlankFilesForDisabled();
   }
   p_active_form.call_event(p_active_form,ON_RESIZE);
   ctltree1.call_event(CHANGE_SELECTED,ctltree1._TreeCurIndex(),ctltree1,ON_CHANGE,'W');
}

/**
 * @param client_width if this is -1 (default), we will use the 
 *                     client_width for the (collapsed) dialog
 *                     itself.  If <B>client_width</B> is passed
 *                     in, it is the width we need to resize the
 *                     update (left) portion of the dialog
 *                     separate from the diff (right) portion
 */
static void resizeUpdatePortionOfDialog(int client_width=-1)
{
   int xbuffer = ctllocal_path_label.p_x;
   int ybuffer = ctllocal_path_label.p_y;
   if ( client_width<0 ) {
      client_width = _dx2lx(SM_TWIP, p_active_form.p_client_width);
   }
   int client_height = _dy2ly(SM_TWIP,p_active_form.p_client_height);

   ctltree1.p_width=client_width-(2*xbuffer);
   _grabbar_vert.p_x = ctltree1.p_x_extent+xbuffer;
   ctlrep_label.p_x=ctltree1.p_x+(ctltree1.p_width intdiv 2);

   if ( ctlcollapseHistory.p_value==0 ) {
      ctltree1.p_height=client_height-(ctllocal_path_label.p_height+ctlclose.p_height+ctlcollapseHistory.p_height+(xbuffer*5));
      ctlminihtml1.p_visible = false;

      ctlclose.p_y=ctlcollapseHistory.p_y_extent+(ybuffer);

      alignControlsHorizontal(ctlclose.p_x, ctlclose.p_y,
                              xbuffer,
                              ctlclose,
                              ctlhistory,
                              ctldiff,
                              ctlupdate,
                              ctlupdate_all,
                              ctlrevert,
                              ctlmerge);
   } else {
      ctltree1.p_height=client_height-(ctltree1.p_y+ctlcollapseHistory.p_height+ctlclose.p_height+(xbuffer*5)+ctlminihtml1.p_height);
      ctlminihtml1.p_visible = true;
      ctlminihtml1.p_y = ctlcollapseHistory.p_y_extent+xbuffer;
      ctlminihtml1.p_width = ctltree1.p_width;

      ctlclose.p_y=ctlminihtml1.p_y_extent+(xbuffer);

      alignControlsHorizontal(ctlclose.p_x, ctlclose.p_y,
                              xbuffer,
                              ctlclose,
                              ctlhistory,
                              ctldiff,
                              ctlupdate,
                              ctlupdate_all,
                              ctlrevert,
                              ctlmerge);

   }
   ctlcollapseHistory.p_next.p_x = ctlcollapseHistory.p_x_extent + xbuffer;

   ctlcollapseHistory.p_y = ctlcollapseHistory.p_next.p_y = ctlExpandDiff.p_prev.p_y = ctlExpandDiff.p_y =  ctltree1.p_y_extent+xbuffer;
   ctlExpandDiff.p_x = ctltree1.p_x_extent - ctlExpandDiff.p_width;
   ctlExpandDiff.p_prev.p_x = ctlExpandDiff.p_x - ctlExpandDiff.p_prev.p_width - xbuffer;

   // Shrink the path for the Repository if necessary
   repositoryList := _GetDialogInfoHt("CaptionRepository",_ctlfile1);
   if ( repositoryList!=null ) {
      parse ctlrep_label.p_caption with auto label ':' auto rest;
      labelWidth := ctlrep_label._text_width(label);
      wholeLabelWidth := (client_width - ctlrep_label.p_x) - labelWidth;
      wholeCaption := label':'ctlrep_label._ShrinkFilename(strip(repositoryList),wholeLabelWidth);
      ctlrep_label.p_caption = wholeCaption;
   }
   if ( ctllocal_path_label.p_x_extent > ctlrep_label.p_x ) {
      ctlrep_label.p_x = ctllocal_path_label.p_x_extent+(2*_twips_per_pixel_x());
   }
   ctlpicture1.p_x = ctltree1.p_x_extent + (xbuffer*2);
}

void _svc_mfupdate_form.on_load()
{
   // Get the previous value of the expand history button
   collapseValue := _moncfg_retrieve_value( "_svc_mfupdate_form.ctlcollapseHistory" );
   if (isinteger(collapseValue)) {
      ctlcollapseHistory.p_value = collapseValue;
   }
   // Get the previous value of the expand diff button
   diffValue := _moncfg_retrieve_value( "_svc_mfupdate_form.ctlExpandDiff" );
   if (isinteger(diffValue)) {
      ctlExpandDiff.p_value = diffValue;
   }

   // Get the position of the diff pic contaniner
   diffContainerXPos := _moncfg_retrieve_value( "_svc_mfupdate_form.ctlpicture1" );
   if (isinteger(diffContainerXPos)) {
      ctlpicture1.p_x = diffContainerXPos;
   }

   // Restore the position of the sizebar (and size of update and diff portions
   // of the dialog)
   retrieveValueGrabBarVertX := _moncfg_retrieve_value( "_svc_mfupdate_form._grabbar_vert" );
   if (isinteger(retrieveValueGrabBarVertX)) {
      _nocheck _control _grabbar_vert;
      _grabbar_vert.p_x = retrieveValueGrabBarVertX;
   } else {
      _grabbar_vert.p_x = ctltree1.p_x_extent;
   }
}

static void resizeDiffPortionOfDialog()
{
   int xbuffer=ctllocal_path_label.p_x;
   int ybuffer=ctllocal_path_label.p_y;
   int client_width=_dx2lx(SM_TWIP, p_active_form.p_client_width);
   int client_height=_dy2ly(SM_TWIP,p_active_form.p_client_height);

   // 2*_twips_per_pixel_y() becuase we start at -1 pixel at top
   // and want to go to the bottom +1 pixel
   ctlpicture1.p_height = client_height + (2*_twips_per_pixel_y());
   ctlpicture1.p_x_extent = client_width + _twips_per_pixel_x();

   _DiffResizeDialog(ctlpicture1);
}

void _svc_mfupdate_form.on_resize()
{
   inResize := _GetDialogInfoHt("inResize",_ctlfile1);
   if (inResize==1) return;
   _SetDialogInfoHt("inResize",1,_ctlfile1);
   int xbuffer=ctllocal_path_label.p_x;
//   _ctlfile1label.p_x=_ctlfile1.p_x;_ctlfile2label.p_x=_ctlfile2.p_x;

   if ( ctlExpandDiff.p_value ) {
      clientWidth := ctlpicture1.p_x - xbuffer;
      if ( ctlpicture1.p_value ) {
         clientWidth = _grabbar_vert.p_x;
      }
      resizeUpdatePortionOfDialog(_grabbar_vert.p_x);
      resizeDiffPortionOfDialog();
   } else {
      resizeUpdatePortionOfDialog();
   }

   _grabbar_vert.p_y = 0;
   _grabbar_vert.p_height = p_active_form.p_height;
   _SetDialogInfoHt("inResize",0,_ctlfile1);
}

void _SVCSeedPathIndexes(_str Path,int (&PathTable):[],int SeedIndex)
{
   PathTable:[_file_case(Path)]=SeedIndex;
}

static int getParentPathIndex(_str Path,int (&PathTable):[])
{
   parentPath := _parent_path(Path);
   if ( PathTable:[parentPath]!=null ) {
      return PathTable:[parentPath];
   }
   return TREE_ROOT_INDEX;
}

static bool isChildPath(_str Path,_str BasePath)
{
   if ( _file_eq( substr(Path,1,length(BasePath)),BasePath ) ) {
      return true;
   }
   return false;
}

static _str getCommonChildPath(_str Path,_str BasePath)
{
   while (!isChildPath(Path,BasePath)) {
      BasePath = _parent_path(BasePath);
      if ( BasePath=="" 
           || (_isWindows() && length(BasePath)<=2)
           ) {
         break;
      }
   }
   return BasePath;
}

int _SVCGetPathIndex(_str Path,_str BasePath,int (&PathTable):[],
                     int ExistFolderIndex=_pic_fldopen,
                     int NoExistFolderIndex=_pic_cvs_fld_m,
                     _str OurFilesep=FILESEP,
                     int state=1,
                     int checkable=1)
{
   if ( !isChildPath(Path,BasePath) ) {
      BasePath = getCommonChildPath(Path,BasePath);
   }

   _str PathsToAdd[];int count=0;
   _str OtherPathsToAdd[];
   Othercount := 0;
   Path=strip(Path,'B','"');
   BasePath=strip(BasePath,'B','"');
   if (PathTable._indexin(_file_case(Path))) {
      return(PathTable:[_file_case(Path)]);
   }
   int Parent=TREE_ROOT_INDEX;
   for (;;) {
      if (Path=='') {
         break;
      }
      PathsToAdd[count++]=Path;
      Path=substr(Path,1,length(Path)-1);
      tPath := _strip_filename(Path,'N');
      if (_file_eq(Path:+OurFilesep,BasePath) || _file_eq(tPath,Path)) break;
      if (isunc_root(Path)) break;
      Path=tPath;
      if (PathTable._indexin(_file_case(Path))) {
         Parent=PathTable:[_file_case(Path)];
         break;
      }
   }
   PathsToAdd._sort('F');
   int i;
   for (i=0;i<PathsToAdd._length();++i) {
      int bmindex;
      if ( isdirectory(PathsToAdd[i] )) {
         bmindex=ExistFolderIndex;
      }else{
         bmindex=NoExistFolderIndex;
      }
      Parent=_TreeAddItem(Parent,
                          PathsToAdd[i],
                          TREE_ADD_AS_CHILD/*|TREE_ADD_SORTED_FILENAME*/,
                          bmindex,
                          bmindex,
                          state);
      isTriState := checkable;
      _TreeSetCheckable(Parent,checkable,isTriState);
      PathTable:[_file_case(PathsToAdd[i])]=Parent;
   }
   return(Parent);
}

void ctltree1.c_o()
{
   index := _TreeCurIndex();
   if (index>0) {
      filename := _SVCGetFilenameFromUpdateTree(index,false,true);
      if ( filename!="" ) {
         svc_rclick_command('open '_maybe_quote_filename(filename));
      }
   }
}

void _SVCLoadBlankFilesForDisabled()
{
   disabledDiffBufID1 := _GetDialogInfoHt("disabledDiffBufID1",_ctlfile1);
   disabledDiffBufID2 := _GetDialogInfoHt("disabledDiffBufID2",_ctlfile1);

   if ( disabledDiffBufID1==null && disabledDiffBufID2==null ) {
      origWID := p_window_id;
      p_window_id = HIDDEN_WINDOW_ID;
      _safe_hidden_window();
      status := load_files('+t');  // These are just blank files to show when the 
                                   // diff is disabled.  No need for undo etc.
      if ( !status ) {
         disabledDiffBufID1 = p_buf_id;
         p_buf_flags |= VSBUFFLAG_HIDDEN;
      }
      status = load_files('+t');   // These are just blank files to show when the 
                                   // diff is disabled.  No need for undo etc.
      if ( !status ) {
         disabledDiffBufID2 = p_buf_id;
         p_buf_flags |= VSBUFFLAG_HIDDEN;
      }
      p_window_id = origWID;

      // These are set on the dialog, so we can't set them while the hidden
      // window is active
      _SetDialogInfoHt("disabledDiffBufID1",disabledDiffBufID1,_ctlfile1);
      _SetDialogInfoHt("disabledDiffBufID2",disabledDiffBufID2,_ctlfile1);
   }

   // If this fails there isn't a lot to be done.  The diff portion of the 
   // dialog will be disabled
   status := _ctlfile1.load_files('+bi 'disabledDiffBufID1);
   status = _ctlfile2.load_files('+bi 'disabledDiffBufID2);
}

bool _SVCHaveDiffableFile(int index,INTARRAY &overlays)
{
   origWID := p_window_id;
   p_window_id = ctltree1;
   haveMod := false;
   haveNewer := false;
   for ( i:=0;i<overlays._length();++i ) {
      if ( overlays[i]==_pic_file_mod_overlay ) {
         haveMod = true;
      } else if ( overlays[i]==_pic_file_vc_date_overlay ) {
         haveNewer = true;
      }
      if ( haveMod && haveNewer ) break;
   }
   p_window_id = origWID;
   return haveMod || haveNewer;
}

static void disableDiffControls(bool enabled=false)
{
   curWID := firstWID := ctlpicture1.p_child;
   for ( ;; ) {
      if ( curWID.p_name != "_ctlcopy_right" &&
           curWID.p_name != "_ctlcopy_right_line" && 
           curWID.p_name != "_ctlfile2_readonly" ) {
         curWID.p_enabled = enabled;
      }
      curWID = curWID.p_next;
      if ( curWID == firstWID ) break;
   }
}

static void enableDiffControls()
{
   disableDiffControls(true);
}

static int inDiffFilesWithVersionControl()
{
   val := _GetDialogInfoHt("inDiffFilesWithVersionControl", _ctlfile1);
   inDiffFilesWithVersionControl := (val==null?0:val);
   return inDiffFilesWithVersionControl;
}

static int diffFilesWithVersionControl(SVC_UPDATE_DIFF_INFO &updateFileInfo)
{
   val := _GetDialogInfoHt("inDiffFilesWithVersionControl",updateFileInfo.dataWID);
   inDiffFilesWithVersionControl := (val==null?0:val);
   if ( inDiffFilesWithVersionControl>0 ) {
      return 0;
   }
   ++inDiffFilesWithVersionControl;
   _SetDialogInfoHt("inDiffFilesWithVersionControl",inDiffFilesWithVersionControl,updateFileInfo.dataWID);

   index := updateFileInfo.index;
   treeWID  := updateFileInfo.treeWID;
   filename := treeWID._SVCGetFilenameFromUpdateTree(index);

   origWID := p_window_id;
   p_window_id = treeWID;
   status := 0;
   do {
      VCSystemName := svc_get_vc_system(filename);
      IVersionControl *pInterface = svcGetInterface(VCSystemName);
      if ( pInterface==null ) {
         status = VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC;
         break;
      }
      overlays := updateFileInfo.overlays;
      if ( updateFileInfo.index != treeWID._TreeCurIndex() && _GetDialogInfoHt("setInitIndex", _ctlfile1)==null ) {
         status = 0;
         break;
      }

      if ( index<0 ) {
         status = INVALID_ARGUMENT_RC;
         break;
      }
      filename = _SVCGetFilenameFromUpdateTree(index);
      if ( ctlcollapseHistory.p_value==1 && filename!="" && _last_char(filename) != FILESEP &&
           updateFileInfo.bmindex1!=_pic_cvs_file_qm) {
         SVCHistoryInfo historyInfo[];
         status = pInterface->getHistoryInformation(filename,historyInfo,SVC_HISTORY_NO_BRANCHES|SVC_HISTORY_LAST_ENTRY_ONLY);
         if ( !status && historyInfo._length()>=1 ) {
            setVersionInfo(index,historyInfo[historyInfo._length()-1]);

            if ( index>-1 ) {
               HISTORY_USER_INFO userInfo = ctltree1._TreeGetUserInfo(index);
               if ( VF_IS_STRUCT(userInfo) ) {
                  _TextBrowserSetHtml(ctlminihtml1,"");
                  len := userInfo.lineArray._length();
                  infoStr := "";
                  for ( i:=0;i<len;++i ) {
                     infoStr :+= "\n":+userInfo.lineArray[i];
                  }
                  _TextBrowserSetHtml(ctlminihtml1,infoStr);
               } else {
                  _TextBrowserSetHtml(ctlminihtml1,"");
               }
            } else {
               _TextBrowserSetHtml(ctlminihtml1,"");
            }
         } else {
            _TextBrowserSetHtml(ctlminihtml1,"");
         }
      } else {
         _TextBrowserSetHtml(ctlminihtml1,"");
      }

      if ( ctlExpandDiff.p_value==1 ) {
         _nocheck _control _ctlfile1;
         lastDiffIndex := _GetDialogInfoHt("lastDiffIndex",_ctlfile1);

         // Don't need to look at what's checked here.  Use those for buttons.
         // We made sure the the dialog is expanded selected, we diff it
         curIndex := _TreeCurIndex();
         if ( curIndex>=0 ) {
            curCaption := _TreeGetCaption(curIndex);
            if ( !endsWith(curCaption,FILESEP) ) {
               curDiffIndex := _GetDialogInfoHt("curDiffIndex", _ctlfile1);
               SomeBuf1:=gDiffSetupData.file1.isBuffer || gDiffSetupData.file1.bufID>-1;
               SomeBuf2:=gDiffSetupData.file2.isBuffer || gDiffSetupData.file2.bufID>-1;
               _DiffFileBufferOrFileInViewExists(gDiffSetupData.file1.fileName,!SomeBuf1,gDiffSetupData.file1.bufID,auto DocName1="",gDiffSetupData.file1.viewID!=0);
               _DiffFileBufferOrFileInViewExists(gDiffSetupData.file2.fileName,!SomeBuf2,gDiffSetupData.file2.bufID,auto DocName2="",gDiffSetupData.file2.viewID!=0);
               parse buf_match(gDiffSetupData.file1.fileName,1,'xhv') with auto buf_id auto otherbufinfo1;
               parse buf_match(gDiffSetupData.file2.fileName,1,'xhv') with buf_id auto otherbufinfo2;
               file1disk:=_DiffGetForceDiskLoadString(false,
                                                      gDiffSetupData.file1.isBuffer,
                                                      gDiffSetupData.file1.bufID,
                                                      gDiffSetupData.file1.firstLine,
                                                      gDiffSetupData.file1.lastLine);
               file2disk:=_DiffGetForceDiskLoadString(false,
                                                      gDiffSetupData.file2.isBuffer,
                                                      gDiffSetupData.file2.bufID,
                                                      gDiffSetupData.file2.firstLine,
                                                      gDiffSetupData.file2.lastLine);
               _SetDialogInfo(DIFFEDIT_READONLY1_VALUE,gDiffSetupData.file1.readOnly,_ctlfile1);

               lastLocalFilename := "";
               misc := _DiffGetDiffShowingInfo();
               if (misc!=null) {
                  lastLocalFilename = _DiffGetFilenameFromDialog(misc, '1');
               }
               if ( !_ctlfile1.p_modify && _GetDialogInfoHt(DIFFEDIT_CONST_MISC_INFO,_ctlfile1)!=null ) {
                  _DiffCloseFileFromSVCUpdate(_ctlfile1, lastLocalFilename, auto bufferIDsRemoved);
                  _TreeGetInfo(lastDiffIndex,auto lastExpandState, auto lastBM1, auto lastBM2, auto moreFlags, auto lastLineNumber, -1, auto lastOverlays);
                  origOverlays := updateFileInfo.overlays;
                  hadOverlay := false;
                  for (i:=0;i<overlays._length();++i) {
                     if ( overlays[i]==_pic_file_edited_overlay ) {
                        overlays._deleteel(i);
                        hadOverlay = true;
                        break;
                     }
                  }
                  if (hadOverlay) {
                     _TreeSetInfo(lastDiffIndex, lastExpandState, lastBM1, lastBM2, 0, 0, -1, overlays);
                  }
               } else if ( _ctlfile1.p_modify ) {
                  // If the previous file was modified, save the buffer IDs.  Next time we load
                  // these files, we'll just load the buffers

                  if ( def_svc_update_flags&SVC_UPDATE_AUTO_PROMPT_TO_SAVE_ON_JUMP ) {
                     result := _message_box(nls("Save '%s'?",lastLocalFilename),"",MB_YESNOCANCEL);
                     switch ( result ) {
                     case IDCANCEL:
                        p_window_id = origWID;
                        break;
                     case IDYES:
                        status = _ctlfile1._diff_save(lastDiffIndex);
                        if ( status ) {
                           _message_box(nls(get_message(status)));
                        }
                        break;
                     case IDNO:
                        // Need to add in that this is modified
                        _TreeGetInfo(lastDiffIndex,auto lastExpandState, auto lastBM1, auto lastBM2, auto moreFlags, auto lastLineNumber, -1, auto lastOverlays);
                        origOverlays := overlays;
                        if ( lastDiffIndex!=null ) {
                           overlays[overlays._length()] = _pic_file_edited_overlay;
                        }
                        if (overlays != origOverlays) {
                           _TreeSetInfo(lastDiffIndex, lastExpandState, lastBM1, lastBM2, 0, 0, -1, overlays);
                        }
                        break;
                     }
                  }
                  _SetDialogInfoHt("lastBufID1:":+lastLocalFilename, _ctlfile1.p_buf_id, _ctlfile1);
                  _SetDialogInfoHt("lastBufID2:":+lastLocalFilename, _ctlfile2.p_buf_id, _ctlfile1);
               }
               status = diffOrReloadFiles(curIndex);
               if ( !status ) {
                  _SetDialogInfoHt("curDiffIndex", curIndex, _ctlfile1);
               }
            }
         }
         if ( !status ) {
            _SetDialogInfoHt("lastDiffIndex", curIndex,_ctlfile1);
         }
      }
   } while ( false );
   if ( !status ) {
      p_window_id = origWID;
   }
   --inDiffFilesWithVersionControl;
   if ( !status ) {
      // If we got a status back, the updateFileInfo.dataWID may not be valid
      _SetDialogInfoHt("inDiffFilesWithVersionControl",inDiffFilesWithVersionControl,updateFileInfo.dataWID);
   }
   return status;
}

static void onChangeCallback(SVC_UPDATE_DIFF_INFO callbackInfo)
{
   _kill_timer(gOnChangeTimerHandle);
   gOnChangeTimerHandle = -1;

   if ( callbackInfo.treeWID._TreeCurIndex() != callbackInfo.index ) {
      if ( _GetDialogInfoHt("setInitIndex",callbackInfo.dataWID._ctlfile1)==null ) {
         return;
      }
   }

   dataWID := callbackInfo.dataWID;
   treeWID := callbackInfo.treeWID;

   origWID := p_window_id;
   p_window_id = treeWID;

   do {
      curDiffIndex := _GetDialogInfoHt("curDiffIndex", dataWID);
      curIndex := _TreeCurIndex();
      if ( !callbackInfo.diffableFiles ) {
         _SetDialogInfoHt("curDiffIndex", _TreeCurIndex(), dataWID);
         _SVCSetupDiffTextFiles();
         break;
      }
      if ( _GetDialogInfoHt("overrideSameIndexFile", dataWID)==1 || curDiffIndex!=curIndex || _GetDialogInfoHt("setInitIndex", dataWID)!=null ) {
         status := diffFilesWithVersionControl(callbackInfo);
         if ( status ) {
            break;
         }
      }
      _SetDialogInfoHt("setInitIndex",null, dataWID);
   } while ( false );
   p_window_id = origWID;
}

void ctltree1.on_change(int reason,int index=-1)
{
   if ( inDiffFilesWithVersionControl() ) {
      val := _GetDialogInfoHt("lastIndexToOnChange",_ctlfile1);
      lastIndexToOnChange := (val==null?-1:val);
      if ( lastIndexToOnChange > 0 ) {
         _TreeSetCurIndex(lastIndexToOnChange);
      }
      return;
   }
   inOnChange := _GetDialogInfoHt("inSVCUpdateTreeOnChange",_ctlfile1);
   if ( index<0 || inOnChange==1 ) {
      svcEnableGUIUpdateButtons();
      return;
   }

   _SetDialogInfoHt("inSVCUpdateTreeOnChange",1,_ctlfile1);
   _SetDialogInfoHt("lastIndexToOnChange",index,_ctlfile1);
   do {
      filename := _SVCGetFilenameFromUpdateTree(index);
      VCSystemName := svc_get_vc_system(filename);
      IVersionControl *pInterface = svcGetInterface(VCSystemName);
      if ( pInterface==null ) break;
      path := _TreeGetCaption(index);
      int state,bmindex1;
      _TreeGetInfo(index,state,bmindex1,bmindex1,auto flags,auto lineNumber,-1,auto overlays);
      Nofselected := _TreeGetNumSelectedItems();

      if (Nofselected>1) {
         ctlhistory.p_enabled=false;
      }
      diffableFiles := _SVCHaveDiffableFile(index,overlays);
      if ( !diffableFiles ) {
         // If we don't have diffable files, first we have to close the existing
         // files before the buffer ID in the editor windows changes
         lastLocalFilename := "";
         misc := _DiffGetDiffShowingInfo();
         if (misc!=null) {
            lastLocalFilename = _DiffGetFilenameFromDialog(misc, '1');
         }
         if ( !_ctlfile1.p_modify && _GetDialogInfoHt(DIFFEDIT_CONST_MISC_INFO,_ctlfile1)!=null ) {
            _DiffCloseFileFromSVCUpdate(_ctlfile1, lastLocalFilename, auto bufferIDsRemoved);
         }

         disableDiffControls();
         _SVCLoadBlankFilesForDisabled();
      } else {
         enableDiffControls();
      }
      switch ( reason ) {
      case CHANGE_SELECTED:
         if ( _GetDialogInfoHt("inSVCSetupTree",_ctlfile1) != null ) break;
         if ( gOnChangeTimerHandle < 0 ) {
            SVC_UPDATE_DIFF_INFO callbackInfo;
            callbackInfo.bmindex1 = bmindex1;
            callbackInfo.diffableFiles = diffableFiles;
            callbackInfo.index = index;
            callbackInfo.overlays = overlays;
            callbackInfo.treeWID = ctltree1;
            callbackInfo.dataWID = _ctlfile1;
            gOnChangeTimerHandle = _set_timer(200,onChangeCallback,callbackInfo);
         }
         break;
      case CHANGE_LEAF_ENTER:
         if ( ctlExpandDiff.p_value==1 ) break;
         int numSelected = ctltree1._TreeGetNumSelectedItems();
         if (numSelected==1) {
            origWID := p_window_id;
            diffGUIUpdate(null,null,null,auto filesModifiedInDiff=false);
            if ( filesModifiedInDiff ) {
               SVC_UPDATE_INFO info;
               info.filename = filename;
               SVCFileStatus fileStatus;
               status := pInterface->getFileStatus(info.filename,info.status);
               if ( status ) break;

               // Get the overlay for the status
               origOverlays := overlays;
               overlays = null;
               _SVCGetFileBitmap(info,auto bitmap,overlays);

               p_window_id = origWID;
               if (origOverlays!=overlays) {
                  _TreeSetInfo(index,state,bitmap,bitmap,0,1,-1,overlays);
               }
               origWID._set_focus();
            } else {
               p_window_id = origWID;
               origWID._set_focus();
            }
         }
         break;
      }
      svcEnableGUIUpdateButtons();
   } while ( false );
   _SetDialogInfoHt("inSVCUpdateTreeOnChange",0,_ctlfile1);
}

void _SVCSetupDiffTextFiles()
{
   ctlpicture1.p_visible = true;
   ctlbinary_file_message.p_visible = false;
   ctldiff_binary_files.p_visible = false;
}

static void setupCompareBinaryFiles(bool filesMatch, int status)
{
   filename := _SVCGetFilenameFromUpdateTree();
   if ( status ) {
      ctlbinary_file_message.p_text = "<code>":+filename:+"</code> has been detected as a binary file getting the status failed.  Click the button to diff it.";
   } else if ( !filesMatch ) {
      ctlbinary_file_message.p_text = "<code>":+filename:+"</code> has been detected as a binary file. Your version control system reported it does not match.  Click the button to diff it.";
   } else if ( filesMatch ) {
      ctlbinary_file_message.p_text = "<code>":+filename:+"</code> has been detected as a binary file. Your version control system reported it does not match.  Click the button to view it.";

      VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
      if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
      IVersionControl *pInterface = svcGetInterface(VCSystemName);
      if ( pInterface==null ) return;

      STRARRAY selectedFileList;
      INTARRAY selectedIndexList;
      selectedFileList[0]  = filename;
      selectedIndexList[0] = ctltree1._TreeCurIndex();
      _SVCUpdateRefreshAfterOperation(selectedFileList,selectedIndexList,null,pInterface,false);

   }
   ctlpicture1.p_visible = false;
   ctlbinary_file_message.p_visible = true;
   ctldiff_binary_files.p_visible = true;
}

static bool compareBinaryFiles(_str filename, int curRemoteRevisionWID, int &status)
{
   status = _open_temp_view(filename, auto localFileWID, auto origWID);
   p_window_id = origWID;
   if ( status ) {
      return false;
   }
   diffStatus := FastBinaryCompare(localFileWID,0,curRemoteRevisionWID,0);
   
   _delete_temp_view(localFileWID);
   status = 0;
   return diffStatus==0;
}

bool _SVCTreatAsBinaryFile(_str filename)
{
   return !(def_svc_update_flags&SVC_UPDATE_NO_AUTO_BINARY_COMPARE) && (_IsBinaryModeFile(filename) || (_file_size(filename) >= (def_diff_force_bin_compare_limit*1024)) ) ;
}

static int diffOrReloadFiles(int curIndex)
{
   VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) {
      _message_box(nls(get_message(VCSystemName)));
      return VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC;
   }

   _TreeGetInfo(curIndex,auto state,auto bm1,0,0,auto junk, -1, auto overlays);
   svcGetStatesFromOverlays(overlays,auto hadAddedOverlay,auto hadDeletedOverlay,auto hadModOverlay,auto hadDateOverlay,auto hadCheckoutOverlay, auto hadUnknownOverlay);
   if ( !hadModOverlay && !hadDateOverlay ) {
      return 0;
   }

   filename := _SVCGetFilenameFromUpdateTree(curIndex);
   // See if we have a copy of a buffer for this file already
   lastBufID1 := _GetDialogInfoHt("lastBufID1:":+filename, _ctlfile1);
   lastBufID2 := _GetDialogInfoHt("lastBufID2:":+filename, _ctlfile1);
   status := 0;
   if ( lastBufID1==null ) {
      status = pInterface->getCurLocalRevision(filename,auto curLocalRevision);
      if ( status ) {
         _message_box(nls(get_message(VSRC_SVC_COULD_NOT_GET_CURRENT_LOCAL_VERSION_FILE,filename)));
         return VSRC_SVC_COULD_NOT_GET_REMOTE_REPOSITORY_INFORMATION;
      }

      status = pInterface->getCurRevision(filename,auto curRevision);
      if ( status ) {
         _message_box(nls(get_message(VSRC_SVC_COULD_NOT_GET_CURRENT_VERSION_FILE,filename)));
         return VSRC_SVC_COULD_NOT_GET_REMOTE_REPOSITORY_INFORMATION;
      }
      curRemoteRevisionWID := -1;
      if ( lastBufID2==null ) {
         status = pInterface->getFile(filename,curRevision,curRemoteRevisionWID);
         if ( status ) {
            _message_box(nls(get_message(VSRC_SVC_COULD_NOT_GET_REMOTE_REPOSITORY_INFORMATION,filename':'curRevision)));
            return VSRC_SVC_COULD_NOT_GET_REMOTE_REPOSITORY_INFORMATION;
         }
      }
      STRHASHTAB binaryFileList = _GetDialogInfoHt("binaryFileList", _ctlfile1);
      if ( (( _GetDialogInfoHt("diffThisBinaryFile", _ctlfile1) != 1) || (_GetDialogInfoHt("overrideSameIndexFile", _ctlfile1) != 1)) && _SVCTreatAsBinaryFile(filename) ) {
         filesMatch := compareBinaryFiles(filename, curRemoteRevisionWID, status);
         setupCompareBinaryFiles(filesMatch, status);
         _delete_temp_view(curRemoteRevisionWID);
         return 0;
      }

      pInterface->getLocalFileURL(filename,auto URL);

      fileIsBuffer1 := _DiffFileBufferOrFileInViewExists(filename);
      pInterface->getRemoteFilename(filename,auto remoteFilename="");

      _SVCSetupDiffTextFiles();
      if ( ctlpicture1.p_visible!=true ) ctlpicture1.p_visible = true;
      origDiffEditFlags := def_diff_edit_flags;
      origFocusWID := _get_focus();
      _nocheck _control ctlgaugeWID;

      parse buf_match(filename,1,'xhv') with auto buf_id auto otherbufinfo1;
      file1disk := "";
      if ( buf_id=="" ) {
         file1disk = "";
      } else {
         file1disk = _DiffGetForceDiskLoadString(buf_id=="",
                                                  buf_id!="",
                                                  (int)buf_id,
                                                  0,
                                                  0);
      }
      file2disk := _DiffGetForceDiskLoadString(false,
                                               false,
                                               curRemoteRevisionWID.p_buf_id,
                                               0,
                                               0);
      name1 := name2 := "";
      _DiffSetupDocumentNames(-1,0,name1,
                              "","",file1disk,"",
                             filename,0);
      _DiffSetupDocumentNames(-1,curRemoteRevisionWID,name2,
                              "","","","",
                              "",0);

      name1NoType := _DiffStripFileOrBufferFromCaption(name1);
      name2NoType := _DiffStripFileOrBufferFromCaption(name2);
      _DiffSetDialogTitles(name1NoType,name2NoType);

      _nocheck _control gauge1;
      _nocheck _control ctlcancel;
      if ( ctlpicture1.ctlgaugeWID.ctlcancel.p_visible == true ) {
         ctlpicture1.ctlgaugeWID.ctlcancel.p_visible = false;
         ctlpicture1.ctlgaugeWID.p_height -= (ctlpicture1.ctlgaugeWID.gauge1.p_height+label1.p_y);
      }
      if ( remoteFilename=="" ) {
         status = diff('-r2 -donotcopybuffer2 -matchmode2 -viewid2 '_maybe_quote_filename(filename)' 'curRemoteRevisionWID,diff_form_wid:ctlpicture1,gaugeFormWID:ctlpicture1.ctlgaugeWID);
      } else {
         status = diff('-r2 -donotcopybuffer2 -matchmode2 -viewid2 -file2title '_maybe_quote_filename(remoteFilename)' '_maybe_quote_filename(filename)' 'curRemoteRevisionWID,diff_form_wid:ctlpicture1,gaugeFormWID:ctlpicture1.ctlgaugeWID);
      }
      if ( status ) return status;
      def_diff_edit_flags = origDiffEditFlags;
      if ( origFocusWID ) origFocusWID._set_focus();

      misc := _DiffGetDiffShowingInfo(_ctlfile1);
      _DiffSetDiffShowingInfo(misc,_ctlfile1);

      //_ctlfile1label.p_caption = file1CaptionName;
      // Get rid of the extra window but do not get rid of the buffer
      _delete_temp_view(curRemoteRevisionWID,false);

      // Have to call this to set up the file labels.  It doesn't happen in the
      // diff because it would normally be handled in on_create, which we do not
      // use because the same diff dialog is being re-used over and over
//      _DiffSetDialogTitles(file1CaptionName,_ctlfile2label.p_caption);

      _SetDialogInfoHt("lastBufID1:":+filename, _ctlfile1.p_buf_id, _ctlfile1);
      _SetDialogInfoHt("lastBufID2:":+filename, _ctlfile2.p_buf_id, _ctlfile1);
//      _SetDialogInfoHt("lastCaption1:":+filename, _ctlfile1label.p_caption, _ctlfile1);
//      _SetDialogInfoHt("lastCaption2:":+filename, _ctlfile2label.p_caption, _ctlfile1);
      _DiffSuspendDelete(_ctlfile1.p_buf_id);
      _DiffSuspendDelete(_ctlfile2.p_buf_id);
      return status;
   }

   // Both of these files are in memory already, so do not make copies of them.
   // They were kept open because they were modified.
   //
   // Don't have to perform diff because it has already been done, just load
   // buffers.
   status = _ctlfile1.load_files('+bi 'lastBufID1);
   status = _ctlfile2.load_files('+bi 'lastBufID2);

#if 0 //6:43am 9/1/2021
   _ctlfile1label.p_caption = _GetDialogInfoHt("lastCaption1:":+filename, _ctlfile1);
   _ctlfile2label.p_caption = _GetDialogInfoHt("lastCaption2:":+filename, _ctlfile1);
#endif

   // Be sure the version control buffer is set to read only and the read only
   // checkbox is disabled
   _ctlfile2_readonly.p_enabled = false;
   misc := _DiffGetDiffShowingInfo(_ctlfile1);

   _DiffSetBuffersAreDiffed(true,misc);

   // Set full buffer on left to read only manually
   if ( misc.buffer1.WholeFileBufId != null && misc.buffer1.WholeFileBufId > 0 ) {
      origWID := p_window_id;
      p_window_id = HIDDEN_WINDOW_ID;
      _safe_hidden_window();
      status = load_files('+bi 'misc.buffer1.WholeFileBufId);
      if (!status) {
         p_readonly_mode = true;
      }
      p_window_id = origWID;
      // Don't have to suspend here because these are in memory
   }

   return status;
}

static void setVersionInfo(int index,SVCHistoryInfo &historyInfo)
{
//   say('setVersionInfo historyInfo.revision='historyInfo.revision' comment='historyInfo.comment);
   _str lineArray[];
   if ( historyInfo.author!="" ) lineArray[lineArray._length()]='<B>Author:</B>&nbsp;'historyInfo.author'<br>';
   if ( historyInfo.date!="" && historyInfo.date!=0) {
      ftime := strftime("%c",historyInfo.date);
      if ( ftime == "" ) {
         // If this would not convert cleanly, display the date we have
         ftime = historyInfo.date;
      }
      lineArray[lineArray._length()]='<B>Date:</B>&nbsp;':+ftime'<br>';
   }
   if ( historyInfo.revisionCaption!="" ) {
      // There is a revision caption (git), this is what is displayed in the 
      // tree, so we'll add a revision under the date
      lineArray[lineArray._length()]='<B>Revision:</B>&nbsp;'historyInfo.revision'<br>';
   }
   if ( historyInfo.changelist!=null && historyInfo.changelist!="" ) {
      lineArray[lineArray._length()]='<B>Changelist:</B>&nbsp;'historyInfo.changelist'<br>';
   }
   // Replace comment string line endings with <br> to preserve formatting
   commentBR := stranslate(historyInfo.comment, '<br>', '\n', 'l');
   if ( commentBR!="" ) {
      lineArray[lineArray._length()]='<B>Comment:</B>&nbsp;'commentBR;
   }
   if( historyInfo.affectedFilesDetails :!= '' ) {
      lineArray[lineArray._length()]='<br><B>Changed paths:</B><font face="Menlo, Monaco, Consolas, Courier New, Monospace">'historyInfo.affectedFilesDetails'</font>';
   }
   HISTORY_USER_INFO info;
   info.actualRevision = historyInfo.revision;
   info.lineArray      = lineArray;
   ctltree1._TreeSetUserInfo(index,info);
}

void ctltree1.rbutton_up,context()
{
   index := _TreeCurIndex();
   filename := _SVCGetFilenameFromUpdateTree(index,false,true);

   _TreeGetInfo(index,auto state,auto bm1,auto CurrentBMIndex,auto moreFlags,auto lineNumber,-1,auto overlays);
   isUpdate  := _TreeHaveOverlay(overlays,_pic_file_vc_date_overlay);
   isCommit  := _TreeHaveOverlay(overlays,_pic_file_mod_overlay)||_TreeHaveOverlay(overlays,_pic_file_add_overlay);
   isUnknown := _TreeHaveOverlay(overlays,_pic_file_unknown_overlay);

   int MenuIndex=find_index("_svc_update_rclick",oi2type(OI_MENU));
   int menu_handle=_mdi._menu_load(MenuIndex,'P');

   int x,y;
   mou_get_xy(x,y);

   copyPathCaption := "Copy filename to clipboard";
   if ( filename!="" ) {
      menuItem := 0;
      // First menu item is diff
      _menu_get_state(menu_handle,menuItem,auto flags,'P',auto caption="",auto command="");
      _menu_set_state(menu_handle,menuItem,flags,'P',caption' 'filename);
      ++menuItem;

      // Second menu item is update or commit, depending on what is selected (not checked)
      updateButtonCaption := ctlupdate.p_caption;
      _menu_get_state(menu_handle,menuItem,flags,'P',caption,command);
      if ( isUpdate ) {
         _menu_set_state(menu_handle,menuItem,flags,'P','Update 'filename,'svc_rclick_command update 'filename);
         ++menuItem;
      } else if ( isCommit ) {
         _menu_set_state(menu_handle,menuItem,flags,'P','Commit 'filename,'svc_rclick_command commit 'filename);
         ++menuItem;
      } else {
         _menu_delete(menu_handle,menuItem);
      }

      _menu_find(menu_handle,"svc-rclick-command createShelf",auto outputHandle,auto outputPos,'M');
      if ( outputPos>=0 ) {
         len := svc_shelf_name_get_count();
         if ( len>0 ) {
            testHandle := _menu_insert(menu_handle,++outputPos,MF_SUBMENU,"Add to shelf");
            if ( testHandle ) {
               for ( i:=0;i<len;++i ) {
                  curShelfName := svc_get_shelf_name_from_index(i);
                  _menu_insert(testHandle,i,MF_ENABLED,curShelfName,'svc-rclick-command addToShelf '_maybe_quote_filename(curShelfName)' '_maybe_quote_filename(filename));
               }
               _menu_insert(testHandle,i,MF_ENABLED,"Add to other shelf...",'svc-rclick-command addToOtherShelf');
            }
         }
      }

      // Next menu item is history
      _menu_get_state(menu_handle,menuItem,flags,'P',caption,command);
      _menu_set_state(menu_handle,menuItem,flags,'P',caption' 'filename);

      ++menuItem;
      // Next menu item is history diff
      _menu_get_state(menu_handle,menuItem,flags,'P',caption,command);
      _menu_set_state(menu_handle,menuItem,flags,'P',caption' 'filename,'svc-history-diff 'filename);

      ++menuItem;
      // Next menu item is -
      ++menuItem;
      // Next menu item is open
      _menu_get_state(menu_handle,menuItem,flags,'P',caption,command);
      _menu_set_state(menu_handle,menuItem,flags,'P',caption' 'filename,'svc-rclick-command open '_maybe_quote_filename(filename));
      ++menuItem;
#if 0 //11:32am 10/8/2021
      _menu_get_state(menu_handle,menuItem,flags,'P',caption,command);
      _menu_set_state(menu_handle,menuItem,flags,'P',caption' 'filename,'svc-rclick-command delete '_maybe_quote_filename(filename));
#endif
   }
   menuItem := _menu_find_loaded_menu_caption(menu_handle,"Deselect out of date");
   // Next menu item is -
   ++menuItem;
   ++menuItem;
   _menu_get_state(menu_handle,menuItem,auto flags,'P',auto caption,auto command);
   if ( last_char(filename) == FILESEP ) {
      copyPathCaption = "Copy path to clipboard";
   }
   _menu_set_state(menu_handle,menuItem,flags,'P',copyPathCaption, command' '_maybe_quote_filename(filename));

   int status=_menu_show(menu_handle,VPM_RIGHTBUTTON,x-1,y-1);
   _menu_destroy(menu_handle);
}

void ctltree1.del()
{
   curIndex := _TreeCurIndex();
   if (curIndex<0) return;
   _TreeGetInfo(curIndex,auto state,auto bm1, auto bm2, auto nodeFlags,auto lineNumber, -1, auto overlays);
   indexHasUnknownOverlay := false;
   svcGetStatesFromOverlays(overlays,hadUnknownOverlay:indexHasUnknownOverlay);
   if (indexHasUnknownOverlay) {
      filename := _TreeGetCaption(_TreeGetParentIndex(curIndex)):+_TreeGetCaption(curIndex);
      status := _message_box(nls("Are you sure you want to delete the file '%s'",filename),"",MB_YESNO);
      if ( status==IDYES ) {
         orig := def_delete_uses_recycle_bin;
         def_delete_uses_recycle_bin = true;
         status = recycle_file(filename);
         def_delete_uses_recycle_bin = orig;
         if ( !status ) {
            _TreeDelete(curIndex);
         }
      }
      return;
   }
   VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
   if ( VCSystemName=="") VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;

   origWID := p_window_id;
   p_window_id = ctltree1;
   INTARRAY selectedIndexList;
   STRARRAY selectedFileList;

   mou_hour_glass(true);
   origFID := p_active_form;
   p_window_id = ctltree1;
   // Add all the selected items
   _str fileTable:[];
   directoriesAreInList := false;
   info := 0;
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      if ( index==TREE_ROOT_INDEX ) continue;
      if ( _TreeGetCheckState(index)==TCB_CHECKED ) {
         selectedIndexList :+= index;
         filename := _SVCGetFilenameFromUpdateTree(index,true);
//         if (last_char(filename)==FILESEP) continue;
         selectedFileList :+= filename;
         if ( _last_char(filename)==FILESEP ) {
            directoriesAreInList = true;
         }
         fileTable:[_file_case(filename)] = "";
      }
   }

   // If no items were selected, add the current item
   if ( selectedIndexList._length()==0 ) {
      index := _TreeCurIndex();
      if ( index>=0 )selectedIndexList :+= index;
      filename := _SVCGetFilenameFromUpdateTree(index);
      selectedFileList :+= filename;
   }
   p_window_id = origWID;
   status := pInterface->removeFiles(selectedFileList);
   _filewatchRefreshFiles(selectedFileList);
   _SVCUpdateRefreshAfterOperation(selectedFileList,selectedIndexList,fileTable,pInterface);
   mou_hour_glass(false);
}

static void svcGetValidBitmaps(int BitmapIndex,_str &ValidBitmaps,_str systemName)
{
   if ( pos(' 'BitmapIndex' ',' 'SVC_BITMAP_LIST_UPDATE' ') ) {
      ValidBitmaps=SVC_BITMAP_LIST_UPDATE;
   }else if ( pos(' 'BitmapIndex' ',' 'SVC_BITMAP_LIST_COMMITABLE' ') ) {
      ValidBitmaps=SVC_BITMAP_LIST_COMMITABLE;
   }else if ( pos(' 'BitmapIndex' ',' 'SVC_BITMAP_LIST_ADD' ') ) {
      ValidBitmaps=SVC_BITMAP_LIST_ADD;
   }else if ( pos(' 'BitmapIndex' ',' 'SVC_BITMAP_LIST_CONFLICT' ') ) {
      ValidBitmaps=SVC_BITMAP_LIST_CONFLICT;
   }else if ( systemName=="hg" && pos(' 'BitmapIndex' ',' 'SVC_BITMAP_LIST_FOLDER' ') ) {
      ValidBitmaps=SVC_BITMAP_LIST_FOLDER;
   }
}

static void svcEnableRevertButton(bool checkForUpdateDashC)
{
   ctlrevert.p_visible=true;
}

static void svcGetStatesFromOverlays(INTARRAY &overlays,
                                     bool &hadAddedOverlay=false,
                                     bool &hadDeletedOverlay=false,
                                     bool &hadModOverlay=false,
                                     bool &hadDateOverlay=false,
                                     bool &hadCheckoutOverlay=false,
                                     bool &hadUnknownOverlay=false,
                                     bool initialize=true)
{
   if ( initialize ) {
      hadAddedOverlay = false;
      hadDeletedOverlay = false;
      hadModOverlay = false;
      hadDateOverlay = false;
      hadCheckoutOverlay = false;
      hadUnknownOverlay = false;
   }
   len := overlays._length();
   for (i:=0; i<len; ++i) {
      curOverlay := overlays[i];
      if ( curOverlay==_pic_file_add_overlay) {
         hadAddedOverlay=true;
      }
      if ( curOverlay==_pic_file_deleted_overlay ) {
         hadDeletedOverlay=true;
      }
      if ( curOverlay==_pic_file_mod_overlay ) {
         hadModOverlay = true;
      }
      if ( curOverlay==_pic_file_vc_date_overlay ) {
         hadDateOverlay = true;
      }
      if ( curOverlay==_pic_file_checkout_overlay ) {
         hadCheckoutOverlay = true;
      }
      if ( curOverlay==_pic_file_unknown_overlay ) {
         hadUnknownOverlay = true;
      }
   }
}

static void svcEnableGUIUpdateButtons()
{
   VCSystemName := _GetDialogInfoHt("VCSystemName",_ctlfile1);
   if ( VCSystemName=="" || VCSystemName==null ) VCSystemName = svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) return;

   systemName := lowcase(pInterface->getSystemNameCaption());

   isCVS := systemName=="cvs";
   isHg  := systemName=="hg";
   checkForUpdateDashC := isCVS;
   wid := p_window_id;
   p_window_id=ctltree1;
   curindex := _TreeCurIndex();
   int state,bmindex1,bmindex2;
   _TreeGetInfo(curindex,state,bmindex1,bmindex2);
   bmindex := -1;
   last_selected := -1;
   valid_bitmaps := "";
   invalid := false;
   bm1 := 0;
   addedFile   := false;
   deletedFile := false;
   oldModFile  := false;
   directoriesAreSelected := false;
   selinfo := 0;
   checkedItem := false;
   canDiffFile := false;
   hadModOverlay := false;
   hadDateOverlay := false;
   hadAddedOverlay := false;
   hadDeletedOverlay := false;
   hadCheckoutOverlay := false;
   hadUnknownOverlay := false;
   int indexTable:[][];
   i:=0;
   INTARRAY overlays = null;
   for ( ff:=1;;ff=0,++i ) {
      index := _TreeGetNextCheckedIndex(ff,selinfo);
      if ( index<1 ) {
         break;
      }
      checkedItem = true;
      _TreeGetInfo(index,state,bm1,bm1,0,auto lineNumber, -1, overlays);
      if ( bm1== _pic_fldopen && overlays._length()>0 ) {
         directoriesAreSelected = true;
      }
      svcGetStatesFromOverlays(overlays,hadAddedOverlay,hadDeletedOverlay,hadModOverlay,hadDateOverlay,hadCheckoutOverlay,hadUnknownOverlay,ff==1);
      if ( hadAddedOverlay && hadDeletedOverlay && hadModOverlay && hadDateOverlay && hadCheckoutOverlay && hadUnknownOverlay) {
         // If we've had everything, we can stop looking
         break;
      }
      overlays = null;
   }
   //say('svcEnableGUIUpdateButtons checkedItem='checkedItem' directoriesAreSelected='directoriesAreSelected);

   if ( !checkedItem ) {
      index := _TreeCurIndex();
      _TreeGetInfo(index,state,bm1,bm1,0,auto lineNumber,-1,overlays);
      if ( bm1== _pic_fldopen && overlays._length()>0 ) {
         directoriesAreSelected = true;
      }
      svcGetStatesFromOverlays(overlays,hadAddedOverlay,hadDeletedOverlay,hadModOverlay,hadDateOverlay,hadCheckoutOverlay,hadUnknownOverlay);
   }
   p_window_id=ctlupdate;
   if ( (hadModOverlay || hadDateOverlay) && !(hadDeletedOverlay || hadAddedOverlay || directoriesAreSelected || hadCheckoutOverlay) ) {
      ctlhistory.p_enabled=true;
      ctldiff.p_enabled=true;
      if ( hadDateOverlay ) {
         ctlupdate.p_enabled=true;
      } else {
         ctlupdate.p_enabled=false;
      }
      ctlrevert.p_visible=true;
      ctlmerge.p_visible=false;
      if (hadDateOverlay) {
         p_caption=SVC_UPDATE_CAPTION_UPDATE;
      } else {
         p_caption = pInterface->getCaptionForCommand(SVC_COMMAND_COMMIT);
      }
      p_enabled=true;
   } else if ( hadUnknownOverlay ) {
      ctlhistory.p_enabled=false;
      ctldiff.p_enabled=false;
      ctlupdate.p_enabled=false;
      ctlupdate_all.p_enabled=false;
      ctlrevert.p_visible=false;
      ctlmerge.p_visible=false;
      p_enabled=true;
      p_caption=SVC_UPDATE_CAPTION_ADD;
   } else if ( hadDeletedOverlay || hadAddedOverlay || hadCheckoutOverlay ) {
      if ( hadAddedOverlay ) {
         ctlhistory.p_enabled=false;
         ctldiff.p_enabled=false;
      }else{
         ctlhistory.p_enabled=true;
         ctldiff.p_enabled=true;
      }
      ctlupdate.p_enabled=false;
      ctlupdate_all.p_enabled=false;
      ctlrevert.p_visible=true;
      ctlmerge.p_visible=false;

      p_enabled=true;
      p_caption = pInterface->getCaptionForCommand(SVC_COMMAND_COMMIT);
   }
   hadNoOverlays := !hadModOverlay && !hadDateOverlay && !hadDeletedOverlay && !addedFile && !hadCheckoutOverlay;
   if ( directoriesAreSelected && hadNoOverlays ) {
      ctlhistory.p_enabled=false;
      ctldiff.p_enabled=false;
      ctlupdate.p_enabled=false;
      ctlupdate_all.p_enabled=false;
      ctlrevert.p_visible=false;
      ctlmerge.p_visible=false;
      p_enabled=false;
      p_caption=SVC_UPDATE_CAPTION_ADD;
   }

   int button_width=max(p_width,_text_width(p_caption)+400);
   if ( button_width>p_width ) {
      orig_button_width := p_width;
      p_width=button_width;
      int width_difference=(button_width-orig_button_width);
      ctlupdate_all.p_x+=width_difference;
      ctlrevert.p_x+=width_difference;
   }

   p_window_id = ctltree1;
   index := _TreeCurIndex();
   if ( index>=0 ) {
      _TreeGetInfo(index,state,bm1);
   }

   int numselected = ctltree1._TreeGetNumSelectedItems();
   if ( numselected>1 && ctlupdate.p_enabled && ctlupdate.p_caption==SVC_UPDATE_CAPTION_MERGE ) {
      // Do not allow merge for multiple files
      ctlupdate.p_enabled = false;
   }

   p_window_id=wid;
}

int mfdiffCreateShelf()
{
   _nocheck _control ctlpath1label;
   _nocheck _control ctlpath2label;
   _nocheck _control tree1;
   _nocheck _control tree2;
   int info;
   STRARRAY captions;
   path1 := ctlpath1label.p_caption;
   path2 := ctlpath2label.p_caption;

   parse path1 with 'Path &1:' path1;
   parse path2 with 'Path &2:' path2;
   int numSelected=0;
   INTARRAY selectedIndexList;
   for (ff:=1;;ff=0,++numSelected) {
      index := _TreeGetNextSelectedIndex(ff,info);
      if (index<0) break;
      selectedIndexList :+= index;
   }

#if 0 //12:59pm 8/8/2019
   captions[0] = "Use "path1" as the base";
   captions[1] = "Use "path2" as the base";
   status := RadioButtons("Create Shelf",captions);
   if (status==COMMAND_CANCELLED_RC) return status;
#endif

   modPathWID := p_window_id;
   basePathWID := modPathWID==tree1?tree1:tree2;
   basePath := "";
   localPath := "";
   if (basePathWID == tree1) {
      basePath = path2;
      localPath = path1;
   } else if (basePathWID == tree2) {
      basePath = path1;
      localPath = path2;
   }
   status := 0;



   ShelfInfo shelf;
   promptForNewShelfName(shelf.shelfName);
   if ( shelf.shelfName=="" ) return COMMAND_CANCELLED_RC;
   mou_hour_glass(true);
   STRARRAY selectedFileVersionList;
   shelf.VCSystemName = "";

   do {
      origWID := p_window_id;
      origFID := p_active_form;
      // Add all the selected items
      shelf.localRoot = localPath;
      _maybe_append_filesep(basePath);
      shelf.baseRoot = basePath;
      // If no items were selected, add the current item
      if ( selectedIndexList._length()==0 ) {
         index := _TreeCurIndex();
         if ( index>=0 )selectedIndexList :+= index;
         _TreeGetInfo(index,auto state,auto bm1);
      }

      len := selectedIndexList._length();
      if ( len==0 ) {
         return COMMAND_CANCELLED_RC;
      }

      for ( i:=0;i<len;++i ) {
         curIndex := selectedIndexList[i];
         if ( curIndex<0 ) break;
         curFilename := _SVCGetFilenameFromUpdateTree(curIndex,false,false,p_window_id);
         if ( curFilename=="" || _last_char(curFilename)==FILESEP ) continue;

         ShelfFileInfo curFile;
         curFile.filename = relative(curFilename,shelf.localRoot);
         curFile.revision = "mfdiff";
         if ( curFile.filename!="" ) {
            shelf.fileList :+= curFile;
         }
      }
      mou_hour_glass(false);
      len = shelf.fileList._length();
      if ( len ) {
         zipFilename := shelf.shelfName;
         if ( !path_exists(svc_get_shelf_base_path()) ) {
            make_path(svc_get_shelf_base_path());
         }
         if ( !status ) {
            svc_gui_edit_shelf(&shelf,zipFilename,false);
            svc_shelf_name_remove(zipFilename);
            svc_shelf_name_insert(0,zipFilename);
            _config_modify_flags(CFGMODIFY_DEFVAR);
         }
      }
   } while (false);
   mou_hour_glass(false);
   return status;
}

static int svcCreateShelf()
{
   ShelfInfo shelf;
   promptForNewShelfName(shelf.shelfName);
   if ( shelf.shelfName=="" ) return COMMAND_CANCELLED_RC;
   mou_hour_glass(true);
   STRARRAY selectedFileVersionList;
   int info;

   status := 0;
   mou_hour_glass(true);
   do {
      origWID := p_window_id;
      origFID := p_active_form;
      p_window_id = ctltree1;
      // Add all the selected items
      getLocalRootFromDialog(shelf.localRoot);
      _maybe_append_filesep(shelf.localRoot);
      INTARRAY selectedIndexList;
      for ( ff:=1;;ff=0 ) {
         index := _TreeGetNextCheckedIndex(ff,info);
         if ( index<0 ) break;
         selectedIndexList :+= index;
      }
      // If no items were selected, add the current item
      if ( selectedIndexList._length()==0 ) {
         index := _TreeCurIndex();
         if ( index>=0 )selectedIndexList :+= index;
         ctltree1._TreeGetInfo(index,auto state,auto bm1);
      }

      len := selectedIndexList._length();
      if ( len==0 ) {
         return COMMAND_CANCELLED_RC;
      }

      autoVCSystem := svc_get_vc_system(selectedIndexList[0]);
      IVersionControl *pInterface = svcGetInterface(autoVCSystem);
      if ( pInterface==null ) return VSRC_SVC_COULD_NOT_GET_VC_INTERFACE_RC;

      shelf.VCSystemName = pInterface->getSystemNameCaption();

      for ( i:=0;i<len;++i ) {
         curIndex := selectedIndexList[i];
         if ( curIndex<0 ) break;
         curFilename := _SVCGetFilenameFromUpdateTree(curIndex);
         if ( curFilename=="" || _last_char(curFilename)==FILESEP ) continue;

         curLocalRevision := "";

         status = pInterface->getFileStatus(curFilename,auto fileStatus=SVC_STATUS_NONE,checkForUpdates:false);

         if ( !_file_eq(shelf.localRoot,substr(curFilename,1,length(shelf.localRoot))) ) {
            child := _TreeGetFirstChildIndex(TREE_ROOT_INDEX);
            if ( child > 0) {
               shelf.localRoot = _TreeGetCaption(child);
            }
         }

         ShelfFileInfo curFile;
         curFile.filename = relative(curFilename,shelf.localRoot);
         curFile.revision = "";
         curRevision := "";
         if ( !status && !(fileStatus&SVC_STATUS_NOT_CONTROLED) ) {
            pInterface->getCurRevision(curFilename,curRevision,"",true);
            status = pInterface->getCurLocalRevision(curFilename,curLocalRevision,true);
            curFile.revision = curLocalRevision;
         }
         if ( curFile.filename!="" ) {
            shelf.fileList :+= curFile;
            selectedFileVersionList :+= curRevision;
         }
      }
      mou_hour_glass(false);
      len = shelf.fileList._length();
      if ( len ) {
         warnAboutOutOfDateFiles := false;
         for (i=0;i<len;++i) {
            curFilename := shelf.fileList[i];

            if ( selectedFileVersionList[i] != shelf.fileList[i].revision ) {
               warnAboutOutOfDateFiles = true;
            }
         }
         if ( warnAboutOutOfDateFiles ) {
            result := _message_box(nls("You have files that are not up-to-date.\n\nDo you still wish to create the shelf?"),"",MB_YESNOCANCEL);
            if (result != IDYES) {
               status = 1;break;
            }
         }
         shelf.VCSystemName = pInterface->getSystemNameCaption();
         zipFilename := shelf.shelfName;
         if ( !path_exists(svc_get_shelf_base_path()) ) {
            make_path(svc_get_shelf_base_path());
         }
         if ( !status ) {
            svc_gui_edit_shelf(&shelf,zipFilename,false);
            result := _message_box(nls("Revert these files now?"),"",MB_YESNO);
            if ( result==IDYES ) {
               ctlrevert.call_event(ctlrevert,LBUTTON_UP);
            }
            svc_shelf_name_remove(zipFilename);
            svc_shelf_name_insert(0,zipFilename);
            _config_modify_flags(CFGMODIFY_DEFVAR);
         }
      }
   } while (false);
   mou_hour_glass(false);
   return status;
}

static _str getCheckedFileList()
{
   checkedFileList := "";
   int info;
   for (ff:=1;;ff=0) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      if ( _TreeGetFirstChildIndex(index)==-1 ) {
         parent := _TreeGetParentIndex(index);
         parentCaption := _TreeGetCaption(parent);
         caption := _TreeGetCaption(index);
         checkedFileList :+= ' '_maybe_quote_filename(parentCaption:+caption);
      }
   }
   return checkedFileList;
}

int _OnUpdate_svc_rclick_command(CMDUI &cmdui,int target_wid,_str command)
{
   parse command with auto commandName auto commandLine;
   pseudoCommandName := parse_file(commandLine);
   switch ( lowcase(pseudoCommandName) ) {
   case "select":
      {
//         say('_OnUpdate_svc_rclick_command select');
         return MF_ENABLED;
      }
      break;
   case "deselect":
      {
//         say('_OnUpdate_svc_rclick_command deselect');
         return MF_ENABLED;
      }
      break;
   case "diff":
      {
//         say('_OnUpdate_svc_rclick_command diff');
      }
      break;
   case "createshelf":
      {
//         say('_OnUpdate_svc_rclick_command createShelf');
      }
      break;
   case "addtoshelf":
      {
//         say('_OnUpdate_svc_rclick_command addtoshelf');
      }
      break;
   case "commit":
   case "update":
      {
//         say('_OnUpdate_svc_rclick_command commmit/update');
      }
      break;
   case "history":
      {
//         say('_OnUpdate_svc_rclick_command history');
      }
      break;
   case "historydiff":
      {
//         say('_OnUpdate_svc_rclick_command historydiff');
      }
      break;
   case "open":
      {
//         say('_OnUpdate_svc_rclick_command open');
      }
      break;
   case "delete":
      {
         if ( ctltree1._TreeGetNumSelectedItems() < 1 ) {
            status := _menu_delete(cmdui.menu_handle,cmdui.menu_pos);
            return MF_DELETED;
         }
         ctltree1._TreeGetInfo(_TreeCurIndex(),auto state,auto bm1,0,0,auto junk, -1, auto overlays);
         svcGetStatesFromOverlays(overlays,auto hadAddedOverlay,auto hadDeletedOverlay,auto hadModOverlay,auto hadDateOverlay,auto hadCheckoutOverlay, auto hadUnknownOverlay);
         if ( hadUnknownOverlay ) {
            return MF_ENABLED;
         }
         status := _menu_delete(cmdui.menu_handle,cmdui.menu_pos);
         return MF_DELETED;
      }
      break;
   case "copypathtoclipboard":
      {
         parse commandLine with auto copyCommand auto pathToCopy;
      }
      break;
   }
   return MF_ENABLED;
}

_command void svc_rclick_command(_str commandLine="") name_info(','VSARG2_EXECUTE_FROM_MENU_ONLY|VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      return;
   }
   command := parse_file(commandLine);
   index := _TreeCurIndex();

   switch ( lowcase(command) ) {
   case "select":
      {
         if ( commandLine=="mod" ) {
            updateSelectModified();
         }
         if ( commandLine=="update" ) {
            updateSelectOutOfDate();
         }
      }
      break;
   case "deselect":
      {
         if ( commandLine=="mod" ) {
            updateSelectModified(false);
         }
         if ( commandLine=="update" ) {
            updateSelectOutOfDate(false);
         }
      }
      break;
   case "diff":
      {
         saveChecks(auto checkList);
         clearChecks();
         _TreeSetCheckState(index,TCB_CHECKED);
         ctldiff.call_event(ctldiff,LBUTTON_UP);
         clearChecks();
         restoreChecks(checkList);
      }
      break;
   case "createshelf":
      {
         svcCreateShelf();
         clearChecks();
      }
      break;
   case "addtoshelf":
      {
         zipFilename := strip(parse_file(commandLine),'B','"');
         filename := strip(parse_file(commandLine),'B','"');
         checkedFileList := getCheckedFileList();
         if (checkedFileList=="") {
            index = _TreeCurIndex();
            parent := _TreeGetParentIndex(index);
            parentCaption := _TreeGetCaption(parent);
            checkedFileList = parentCaption:+_TreeGetCaption(index);
         }
         status := svc_add_controlled_file_to_shelf(zipFilename,checkedFileList);
         if ( !status ) {
            result := _message_box(nls("Revert these files now?"),"",MB_YESNO);
            if ( result==IDYES ) {
               ctlrevert.call_event(ctlrevert,LBUTTON_UP);
            }
         }
         clearChecks();
      }
   case "addtoothershelf":
      {
         initialDirectory := svc_get_shelf_base_path();
         result := _OpenDialog('-modal',
                            'Add To Existing Shelf zip file',                   // Dialog Box Title
                            '',                   // Initial Wild Cards
                            'Zip Files (*.zip)',
                            OFN_FILEMUSTEXIST,
                            'zip',
                            '',
                            initialDirectory
                            );
         if ( result=="" ) {
            return;
         }
         zipFilename := result;
         checkedFileList := getCheckedFileList();
         if (checkedFileList=="") {
            index = _TreeCurIndex();
            parent := _TreeGetParentIndex(index);
            parentCaption := _TreeGetCaption(parent);
            checkedFileList = parentCaption:+_TreeGetCaption(index);
         }
         status := svc_add_controlled_file_to_shelf(zipFilename,checkedFileList);
         if ( !status ) {
            result = _message_box(nls("Revert these files now?"),"",MB_YESNO);
            if ( result==IDYES ) {
               ctlrevert.call_event(ctlrevert,LBUTTON_UP);
            }
         }
         clearChecks();
      }
      break;
   case "commit":
   case "update":
      {
         IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
         if ( pInterface==null ) return;

         filename := parse_file(commandLine);
         if ( lowcase(command)=="update" ) {
            pInterface->updateFile(filename);
         } else if ( lowcase(command)=="commit" ) {
            pInterface->commitFile(filename);
         }

         _str selectedFileList[];
         selectedFileList[0] = filename;
         INTARRAY selectedIndexList;
         selectedIndexList[0] = index;
         _str fileTable:[];
         fileTable:[_file_case(filename)] = "";
         _SVCUpdateRefreshAfterOperation(selectedFileList,selectedIndexList,fileTable,pInterface);
      }
      break;
   case "history":
      {
         IVersionControl *pInterface = svcGetInterface(svc_get_vc_system());
         if ( pInterface==null ) return;

         filename := parse_file(commandLine);
         saveChecks(auto checkList);
         clearChecks();
         _TreeSetCheckState(index,TCB_CHECKED);
         ctlhistory.call_event(ctlhistory,LBUTTON_UP);
         clearChecks();
         restoreChecks(checkList);
      }
      break;
   case "historydiff":
      {
         filename := parse_file(commandLine);
         saveChecks(auto checkList);
         clearChecks();
         _TreeSetCheckState(index,TCB_CHECKED);
         svc_history_diff(filename);
         clearChecks();
         restoreChecks(checkList);
      }
      break;
   case "open":
      {
         filename := parse_file(commandLine);
         ext := _get_extension(filename);
         if(ext != '') {
            ext = lowcase(ext);
            appCommand := ExtensionSettings.getOpenApplication(ext, '');
            assocType := (int)ExtensionSettings.getUseFileAssociation(ext);

            if (!assocType) {
               if (appCommand != "") {
                  _projecttbRunAppCommand(appCommand, _maybe_quote_filename(absolute(filename)));
               } else {
                  edit(_maybe_quote_filename(filename),EDIT_DEFAULT_FLAGS);
               }
               return;
            }

            status := _ShellExecute(absolute(filename));
            if ( status<0 ) {
               _message_box(get_message(status)' ':+ filename);
            }
         } else {
            // extensionless file
            edit(_maybe_quote_filename(filename),EDIT_DEFAULT_FLAGS);
         }
      }
      break;
   case "delete":
      {
         filename := parse_file(commandLine);
         if ( file_exists(filename) ) {
            result := _message_box(nls("Do you wish to delete '%s'?",filename),"",MB_YESNO);
            if ( result == IDYES) {
               status := delete_file(filename);
               if ( !status ) {
                  ctltree1._TreeDelete(ctltree1._TreeCurIndex());
               }
            }
         }
         break;
      }
      break;
   case "copypathtoclipboard":
      {
         filename := parse_file(commandLine);
         push_clipboard(filename);
      }
      break;
   }
}

int _checkForshelf(_str shelfName)
{
   if ( svc_shelf_exists(shelfName) ) {
      result := _message_box(nls("A shelf named %s already exists.\n\nOverwrite?",shelfName),"",MB_YESNOCANCEL);
      if (result==IDYES) return 0;
      return 1;
   }
   return 0;
}

static void promptForNewShelfName(_str &shelfName)
{
   shelfName = "";
   initialDirectory := svc_get_shelf_base_path();
   make_path(initialDirectory);
   result := _OpenDialog('-modal',
                      'Create Shelf zip file',                   // Dialog Box Title
                      '',                   // Initial Wild Cards
                      'Zip Files (*.zip)',
                      OFN_SAVEAS,
                      'zip',
                      '',
                      initialDirectory
                      );
   shelfName = strip(result,'B','"');
}

static void saveChecks(INTARRAY &selectedIndexList)
{
   int info;

   mou_hour_glass(true);
   origWID := p_window_id;
   origFID := p_active_form;
   p_window_id = ctltree1;
   // Add all the selected items
   _str fileTable:[];
   directoriesAreInList := false;
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      if ( index==TREE_ROOT_INDEX ) continue;
      if ( _TreeGetCheckState(index)==TCB_CHECKED ) {
         selectedIndexList :+= index;
      }
   }
}

static void clearChecks()
{
   int info;
   INTARRAY selectedIndexList;

   mou_hour_glass(true);
   origWID := p_window_id;
   origFID := p_active_form;
   p_window_id = ctltree1;
   // Add all the selected items
   _str fileTable:[];
   directoriesAreInList := false;
   for ( ff:=1;;ff=0 ) {
      index := _TreeGetNextCheckedIndex(ff,info);
      if ( index<0 ) break;
      if ( index==TREE_ROOT_INDEX ) continue;
      if ( _TreeGetCheckState(index)==TCB_CHECKED ) {
         selectedIndexList :+= index;
      }
   }
   foreach ( auto curIndex in selectedIndexList ) {
      _TreeSetCheckState(curIndex,TCB_UNCHECKED);
   }
}

static int findNextCheckedIndex()
{
   _nocheck _control _ctlfile1;
   info := _GetDialogInfoHt("checkedInfo",_ctlfile1);
   _nocheck _control ctltree1;
   nextIndex := -1;
   if ( info==null ) {
      nextIndex = ctltree1._TreeGetNextCheckedIndex(1,info);
      if ( nextIndex!=-1 ) {
         _SetDialogInfoHt("checkedInfo",info,_ctlfile1);
      }
   } else {
      nextIndex = ctltree1._TreeGetNextCheckedIndex(0, info);
      _SetDialogInfoHt("checkedInfo",info,_ctlfile1);
   }
   return nextIndex;
}

static int findPrevCheckedIndex()
{
   _nocheck _control _ctlfile1;
   info := _GetDialogInfoHt("checkedInfo",_ctlfile1);
   _nocheck _control ctltree1;
   prevIndex := -1;
   if ( info==null ) {
      prevIndex = ctltree1._TreeGetPrevCheckedIndex(1, info);
      if ( prevIndex!=-1 ) {
         _SetDialogInfoHt("checkedInfo",info,_ctlfile1);
      }
   } else {
      prevIndex = ctltree1._TreeGetPrevCheckedIndex(0, info);
      _SetDialogInfoHt("checkedInfo",info,_ctlfile1);
   }
   return prevIndex;
}

int _SVCGetCheckedIndex(_str nextOrPrev)
{
   nextOrPrev = upcase(nextOrPrev);
   if ( upcase(nextOrPrev)!='N' && upcase(nextOrPrev)!='P' ) {
      return -1;
   }
   findNext := nextOrPrev=='N';
   if ( findNext ) {
      return findNextCheckedIndex();
   }
   return findPrevCheckedIndex();
}

static void restoreChecks(INTARRAY &selectedIndexList)
{
   foreach (auto curIndex in selectedIndexList) {
      _TreeSetCheckState(curIndex,TCB_CHECKED);
   }
}

static void updateSelectModified(bool select=true,int index=TREE_ROOT_INDEX)
{
   for (;index>=0;) {
      childIndex := _TreeGetFirstChildIndex(index);
      if ( childIndex>=0 ) {
         updateSelectModified(select,childIndex);
      }
      _TreeGetInfo(index,auto state,auto bm1,0,0,auto junk, -1, auto overlays);
      hadModOverlay := false;
      svcGetStatesFromOverlays(overlays, hadModOverlay:hadModOverlay);
      if ( hadModOverlay ) {
         if ( select ) {
            _TreeSetCheckState(index,TCB_CHECKED);
         } else {
            _TreeSetCheckState(index,TCB_UNCHECKED);
         }
      }
      index = _TreeGetNextSiblingIndex(index);
   }
}

static void updateSelectOutOfDate(bool select=true,int index=TREE_ROOT_INDEX,bool includeMod=true)
{
   for (;index>=0;) {
      childIndex := _TreeGetFirstChildIndex(index);
      if ( childIndex>=0 ) {
         updateSelectOutOfDate(select,childIndex,includeMod);
      }
      _TreeGetInfo(index,auto state,auto bm1,0,0,auto junk, -1, auto overlays);
      hadDateOverlay := false;
      svcGetStatesFromOverlays(overlays,hadDateOverlay:hadDateOverlay);
      if ( hadDateOverlay ) {
         if ( select ) {
            _TreeSetCheckState(index,TCB_CHECKED);
         } else {
            _TreeSetCheckState(index,TCB_UNCHECKED);
         }
      }
      index = _TreeGetNextSiblingIndex(index);
   }
}

static void getLocalRootFromDialog(_str &localRoot)
{
   parse ctllocal_path_label.p_caption with (SVC_LOCAL_ROOT_LABEL) localRoot;
}

void _grabbar_vert.lbutton_down()
{
   origWID := p_window_id;
   p_window_id = p_active_form;
   clientHeight := _dy2ly(SM_TWIP,p_client_height);
   clientWidth := _dx2lx(SM_TWIP,p_client_width);
   p_window_id = origWID;

   _ul2_image_sizebar_handler(0, clientWidth);
}
