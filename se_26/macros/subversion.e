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
#include "subversion.sh"
#include "cvs.sh"
#import "help.e"
#import "main.e"
#include "se/vc/IVersionControl.e"
#include "se/vc/QueuedVCCommandManager.e"
#import "svc.e"
#import "treeview.e"
#import "tags.e"
#import "taggui.e"
#import "varedit.e"
#import "vc.e"
#import "wkspace.e"
#endregion

using sc.lang.String;
using se.vc.vccache.VCBranch;
using se.vc.vccache.VCFile;
using se.vc.vccache.VCLabel;
using se.vc.vccache.VCRepositoryCache;
using se.vc.vccache.VCBaseRevisionItem;
using se.vc.vccache.VCRevision;
using se.vc.vccache.QueuedVCCommandManager;
using se.vc.vccache.QueuedVCCommand;
using se.datetime.DateTime;

_str def_svn_other_branches="";

static const SUBVERSION_ENTRIES_FILENAME= 'entries';
static const SUBVERSION_STATUS_VERSION_PREFIX= 'Status against revision:';
const VCSYSTEM_TITLE_SUBVERSION= "Subversion";

QueuedVCCommandManager gQueuedVCCommandManager = null;

// This is a table of valid URLs.  These are reset every time we start the editor
// This is used for the history dialog for mapping URLs to local paths
static bool gValidLocalPathTable:[];

definit()
{
   if ( upcase(arg(1))!='L' ) {
#if 0 //1:15pm 4/1/2013
      QueuedVCCommandManager newMgr();
      gQueuedVCCommandManager = newMgr;
      gQueuedVCCommandManager.start();
#endif

      gValidLocalPathTable = null;
   }
}
static const ALT_SVN_LOCATION_1= "/Applications/Xcode.app/Contents/Developer/usr/bin/svn";
static const ALT_SVN_LOCATION_2= "/Library/Developer/CommandLineTools/usr/bin/svn";

_str _SVNGetExePath() {
   result:=_GetCachedExePath(def_svn_exe_path,_svn_cached_exe_path,("svn":+EXTENSION_EXE));
   if (_isMac()) {
      if (_file_eq(result,"/usr/bin/svn")) {
         if ( !file_exists(ALT_SVN_LOCATION_1)&& 
              !file_exists(ALT_SVN_LOCATION_2)
               ) {
            return '';
         }
      }
   }
   return result;
}

static void getTopSVNPath(_str curPath,_str topPath,_str &topSVNPath)
{
   lastCurPath := curPath;
   for ( ;; ) {
      if ( !_pathIsParentDirectory(curPath,topPath) ) {
         topSVNPath = lastCurPath;
         break;
      }
      validSVNPath := svnIsCheckedoutPath(curPath,auto curURL="");
      if ( !validSVNPath ) {
         topSVNPath = lastCurPath;
         break;
      }
      lastCurPath = curPath;
      _maybe_strip_filesep(curPath);
      curPath = _strip_filename(curPath,'N');
   }
   topPathWasCheckedOut := svnIsCheckedoutPath(topSVNPath,auto curURL="");
   if ( !topPathWasCheckedOut ) topSVNPath = "";
}

/**
 * Go through <B>projPaths</B> and figure out the minimum paths 
 * that need to be updated and return that in 
 * <B>workspacePath</B>.  Use <B>workspacePath</B> if possible 
 * 
 * @param projPaths list of project working paths returned by 
 *                  <B>GetAllProjectPaths</B>
 * @param workspacePath path that the workspace file exists in
 * @param pathsToUpdate list of paths that must be updated to 
 *                      get their version control status
 */
void _SVNGetUpdatePathList(_str (&projPaths)[],_str workspacePath,_str (&pathsToUpdate)[])
{
   _str pathsSoFar:[];

   len := projPaths._length();
//   say('****************************************************************************************************');
   for ( i:=0;i<len;++i ) {
      curPath := projPaths[i];
      getTopSVNPath(curPath,workspacePath,auto topSVNPath);
//      say('_SVNGetUpdatePathList curPath='curPath' topSVNPath='topSVNPath);
      if ( topSVNPath!="" && !pathsSoFar._indexin(topSVNPath) ) {
         pathsToUpdate[pathsToUpdate._length()] = topSVNPath;
         pathsSoFar:[topSVNPath] = "";
      }
   }

   // If we have a workspace with files added from several other directories, 
   // this still may not be the minimum set of paths.  Sort, and then remove any
   // paths where pathsToUpdate[i+1] is a substr of pathsToUpdate[i].  This will
   // elimate cases like:
   // pathsToUpdate[0] = c:\src\Proj1
   // pathsToUpdate[1] = c:\src\Proj1\io
   // pathsToUpdate[2] = c:\src\Proj1\log
   // pathsToUpdate[3] = c:\src\Proj1\diff
   //
   // Where only c:\src\Proj1 needs to be updated
   pathsToUpdate._sort('F');
   for ( i=0;i<pathsToUpdate._length();++i ) {
      if ( i+1>=pathsToUpdate._length() ) break;

      if ( _file_eq(pathsToUpdate[i],substr(pathsToUpdate[i+1],1,length(pathsToUpdate[i]))) ) {
         pathsToUpdate._deleteel(i+1);
         --i;
      }
   }
}
/**
 * @param path path to test
 * @param parentPath possible parent of <b>path</b>
 * 
 * @return bool true if <b>path</b> is a child of <b>parentPath</b>
 */
bool _pathIsParentDirectory(_str path,_str parentPath)
{
   lenPath := length(path);
   lenParentPath := length(parentPath);
   if ( lenPath < lenParentPath )  {
      return false;
   }
   pieceOfPath := substr(path,1,lenParentPath);
   match := _file_eq(pieceOfPath,parentPath);
   return match;
}
static bool svnIsCheckedoutPath(_str localPath,_str URL)
{
   urlExists := false;
   if ( gValidLocalPathTable:[_file_case(localPath)]==null ) {
      
      _maybe_append_filesep(localPath);
      status := 0;
      if ( !path_exists(localPath:+SUBVERSION_CHILD_DIR_NAME) ) {
         status = 1;
      } else {
#if 0 //10:56am 4/18/2011
         // For the sake of performance, it is sufficient to check for a .svn/
         // directory.  If we get a false positive, svn will fail when it runs 
         // later.  We are not saving any URL info so there is no need to run 
         // this
         status = _SVNGetFileURL(localPath,auto remote_filename);
#else
         status = 0;
#endif
      }
      urlExists = !status;
      gValidLocalPathTable:[_file_case(localPath)] = urlExists;
   }else{
      urlExists = gValidLocalPathTable:[_file_case(localPath)];
   }
   return urlExists;
}

_command void reset_queued_command_mgr() name_info(','VSARG2_REQUIRES_PRO_EDITION)
{
   gQueuedVCCommandManager=null;
}

_command void show_queued_command_mgr() name_info(','VSARG2_REQUIRES_PRO_EDITION)
{
   if ( gQueuedVCCommandManager==null ) {
   }
   _dump_var(gQueuedVCCommandManager);
}

void _before_write_state_SVNCache()
{
   if ( gQueuedVCCommandManager!=null ) gQueuedVCCommandManager.prepareForWriteState();
}

void _after_write_state_SVNCache()
{
   if ( gQueuedVCCommandManager!=null ) gQueuedVCCommandManager.recoverFromWriteState();
}

void _exit_SVNCache()
{
   gQueuedVCCommandManager = null;
}
/**
 * Display the Subversion history dialog for <b>filename</b>
 * @param filename file to display Subversion history dialog for.  If this is
 *        '', uses the current buffer.  If there is no window open, it will
 *        display an open file dialog
 * @param quiet if true, do not display error messages
 * @param version if this is not null, it will set the current tree node in the
 *        dialog to this version
 *
 * @return int 0 if successful
 */
_command int svn_history(_str filename='',bool quiet=false,
                         _str version=null,bool useNewHistory=def_svn_use_new_history!=0) name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   noBranches := SVC_HISTORY_NOT_SPECIFIED;
   if ( def_svn_flags&SVN_FLAG_SHOW_BRANCHES ) {
      noBranches = SVC_HISTORY_WITH_BRANCHES;
   }
   orig_def_vc := def_vc_system;
   def_vc_system = "Subversion";
   svc_history(filename,noBranches);
   def_vc_system = orig_def_vc;
   return 0;
}

/**
 * Commit the current buffer, or <b>filename</b> if it is specified
 * @param filename file to commit, uses current buffer if ''.  If '' and no
 *        windows are open, it uses the Open file dialog to prompt
 * @return int 0 if successful
 */
_command int svn_commit(typeless filename='',_str comment=NULL_COMMENT) name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   orig_def_vc := def_vc_system;
   def_vc_system = "Subversion";
   svc_commit(filename,comment);
   def_vc_system = orig_def_vc;
   return 0;
#if 0 //10:24am 4/10/2013
   int status=cvs_commit(filename,comment,_SVNCommit);
   return(status);
#endif
}

#if 0 //3:42pm 4/15/2019
/**
 * Command to be run from menu on history dialog, cannot be run from command line or key
 * Diffs two past verisons of the file being displayed
 *
 * @return int 0 if successful
 */
_command int svn_history_diff_past() name_info(','VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   if ( p_active_form.p_name!='_cvs_history_form' ) {
      // Do not want to run this from the command line, etc.
      return(COMMAND_CANCELLED_RC);
   }
   _str filename=SVNGetFilenameFromHistoryDialog();
   remote_filename := "";
   int status=_SVNGetFileURL(filename,remote_filename);
   if ( status ) {
      _message_box(nls("Could not get remote filename for %s\n\n%s",filename,get_message(status)));
      return(status);
   }
   CVSHistoryDiffPast(remote_filename,SVNDiffPastVersions);
   return(0);
}
#endif

#if 0 //3:43pm 4/15/2019
/**
 * Command to be run from menu on history dialog, cannot be run from command line or key
 *
 * Diffs the current item in the tree with the prior version
 *
 * @return int 0 if successful
 */
_command int svn_history_diff_predecessor() name_info(','VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   if ( p_active_form.p_name!='_cvs_history_form' ) {
      // Do not want to run this from the command line, etc.
      return(COMMAND_CANCELLED_RC);
   }
   int wid=ctltree1;
   ver1 := ver2 := "";
   int status=_SVNGetVersionsFromHistoryTree(ver1,ver2,auto treeIndex1,auto treeIndex2);
   if ( status ) {
      return(status);
   }
   _str filename=SVNGetFilenameFromHistoryDialog();
   remote_filename := "";
   status=_SVNGetFileURL(filename,remote_filename);
   if ( status ) {
      getURLErrorMessage(filename,status);
      return(status);
   }
   // Have to do some extra work to get the branches for each file to be sure we
   // are comparing the right files.
   ctltree1.getSVNURLFromTreeIndex(auto fileURL1,treeIndex1);
   ctltree1.getSVNURLFromTreeIndex(auto fileURL2,treeIndex2); 
   if ( fileURL1!="" &&fileURL2!="" ) {
      SVNDiffTwoURLs(fileURL1,fileURL2,ver1,ver2);
   }else{
      SVNDiffPastVersions(remote_filename,ver1,ver2);
   }
   wid._set_focus();
   return(status);
}
#endif


_command int svn_review_and_commit(_str cmdline='') name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   int status = svc_diff_with_tip(cmdline, modal:true);
   if (status == COMMAND_CANCELLED_RC) {
      return status;
   }
   return svn_commit(cmdline);
}


/**
 * Diff the current file, or file specified in <b>cmdline</b> with the tip
 * of the current branch in Subversion
 * @param cmdline a filename to be diffed
 *
 * @return int 0 if successful
 */
_command int svn_diff_with_tip(_str cmdline='') name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   // 4/10/2013
   // We supported a -readonly arg here. It seems we never used it.  Continue
   // pull off args.  We could potentially allow versions here.
   filename := "";
   for ( ;; ) {
      _str cur=parse_file(cmdline);
      if ( cur=='' ) break;
      ch1 := substr(cur,1,1);
      if ( ch1=='-' ) {
      } else {
         filename = cur;
      }
   }
   if ( filename=='' ) filename=p_buf_name;
   orig_def_vc := def_vc_system;
   def_vc_system = "Subversion";
   svc_diff_with_tip(filename);
   def_vc_system = orig_def_vc;
   return 0;
#if 0 //10:27am 4/10/2013
   read_only := false;
   filename := "";
   lang := "";
   if ( _no_child_windows() && cmdline=='' ) {
      _str result=_OpenDialog('-modal',
                              'Select file to diff',// Dialog Box Title
                              '',                   // Initial Wild Cards
                              def_file_types,       // File Type List
                              OFN_FILEMUSTEXIST,
                              '',
                              ''
                             );
      if ( result=='' ) return(COMMAND_CANCELLED_RC);
      filename=result;
   } else if ( cmdline=='' ) {
      filename=p_buf_name;
      lang=p_LangId;
   } else {
      for ( ;; ) {
         _str cur=parse_file(cmdline);
         if ( cur=='' ) break;
         ch1 := substr(cur,1,1);
         if ( ch1=='-' ) {
            switch ( upcase(substr(cur,2)) ) {
            case 'READONLY':
               read_only=true;
               break;
            }
         } else {
            filename=cur;
         }
      }
   }
   _LoadEntireBuffer(filename,lang);
   int status=SVNDiffWithVersion(filename,-1,false,'',lang);
   return(status);
#endif
}


/**
 * Diff the current file, or file specified in <b>cmdline</b> 
 * with the current BASE revision in the local working copy 
 * @param cmdline a filename to be diffed
 *
 * @return int 0 if successful
 */
_command int svn_diff_with_base(_str cmdline='') name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   // 4/10/2013
   // We supported a -readonly arg here. It seems we never used it.  Continue
   // pull off args.  We could potentially allow versions here.
   filename := "";
   for ( ;; ) {
      _str cur=parse_file(cmdline);
      if ( cur=='' ) break;
      ch1 := substr(cur,1,1);
      if ( ch1=='-' ) {
      } else {
         filename = cur;
      }
   }
   if ( filename=='' ) filename=p_buf_name;
   orig_def_vc := def_vc_system;
   def_vc_system = "Subversion";
   svc_diff_with_tip(filename,"BASE");
   def_vc_system = orig_def_vc;
   return 0;

#if 0 //10:32am 4/10/2013
   read_only := false;
   filename := "";
   lang := "";
   if ( _no_child_windows() && cmdline=='' ) {
      _str result=_OpenDialog('-modal',
                              'Select file to diff',// Dialog Box Title
                              '',                   // Initial Wild Cards
                              def_file_types,       // File Type List
                              OFN_FILEMUSTEXIST,
                              '',
                              ''
                             );
      if ( result=='' ) return(COMMAND_CANCELLED_RC);
      filename=result;
   } else if ( cmdline=='' ) {
      filename=p_buf_name;
      lang=p_LangId;
   } else {
      for ( ;; ) {
         _str cur=parse_file(cmdline);
         if ( cur=='' ) break;
         ch1 := substr(cur,1,1);
         if ( ch1=='-' ) {
            switch ( upcase(substr(cur,2)) ) {
            case 'READONLY':
               read_only=true;
               break;
            }
         } else {
            filename=cur;
         }
      }
   }
   // Load the working copy version of the file
   _LoadEntireBuffer(filename,lang);

   // get the relative filename
   path := _strip_filename(filename,'N');
   relativeFilename := relative(filename,path);

   // Use <svn cat -r BASE filename>  to get the local working
   // copy BASE revision, and place it in a temp buffer.
   tempFileBase := "";
   status := _SVNCheckoutFile(relativeFilename,filename, ' -r BASE', tempFileBase, true);
   if ( status ) {
      if ( status!=FILE_NOT_FOUND_RC ) {
         _str msg=nls("Could not checkout BASE version of '%s'",filename);
         _message_box(msg);
      }
      return(status);
   }

   wid := p_window_id;
   int temp_view_id,orig_view_id;
   _str encoding_option=_load_option_encoding(filename);
   status=_open_temp_view(tempFileBase,temp_view_id,orig_view_id,encoding_option);
   p_window_id = wid;
   if ( status ) {
      if ( status ) {
         _message_box(nls("Could not open BASE version of  '%s'",filename));
      }
      delete_file(tempFileBase);
      return(status);
   }
   temp_view_id._SetEditorLanguage(lang);
   delete_file(tempFileBase);


   // Run diff between filename and the temp_view_id
   file1Title :=  '"' :+ filename :+ ' (Working Copy)"';
   file2Title :=  '"' :+ filename :+ ' (BASE)"';
   diffCmdLine :=  '-modal -nomapping -vcdiff svn -r2 -viewid2 -file1Title ' :+ file1Title :+ ' -file2title ' :+ file2Title :+ ' ' :+ _maybe_quote_filename(filename) :+ ' ' :+ temp_view_id;
   status = _DiffModal(diffCmdLine,"svn");
   
   _delete_temp_view(temp_view_id);
   
   return (status);
#endif
}

enum SVN_UPDATE_TYPE {
   SVN_UPDATE_PATH,
   SVN_UPDATE_WORKSPACE,
   SVN_UPDATE_PROJECT
};

/**
 * Shows the GUI update dialog for <b>path</b>
 * @param path Path to show update dialog for.  If path is "", it will use a dialog to prompt
 *
 * @return int
 */
_command int svn_update_directory,svn_gui_mfupdate(_str path='',SVN_UPDATE_TYPE updateType=SVN_UPDATE_PATH ) name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   orig_def_vc := def_vc_system;
   def_vc_system = "Subversion";
   svc_gui_mfupdate(path);
   def_vc_system = orig_def_vc;
   return 0;
#if 0 //10:33am 4/10/2013
   path = strip(path,'B','"');
   if ( path=='' ) {
      path=_SVNGetPath();
      if ( path=='' ) {
         return(COMMAND_CANCELLED_RC);
      }
   }
   if ( updateType!=SVN_UPDATE_PROJECT ) _maybe_append_filesep(path);
   _str list=path;
   recurse_option := false;
   tag_name := "";
   for ( ;; ) {
      _str cur=parse_file(path);
      ch := substr(cur,1,1);
      if ( ch=='+' || ch=='-' ) {
         switch ( lowcase(substr(cur,2)) ) {
         case 'r':
            recurse_option=true;
            break;
         }
      } else {
         path=cur;
         break;
      }
   }
   path=absolute(path);

   could_not_verify_setup := false;
   status := 0;
   if ( status==COMMAND_CANCELLED_RC ) {
      return(status);
   }else if ( status ) could_not_verify_setup=true;

   SVN_STATUS_INFO Files[];
   vcs := "Communicating with the ":+VCSYSTEM_TITLE_SUBVERSION:+" server.  This may take a moment";
   operation_failed := false;

   STRARRAY pathList;
   STRARRAY pathsToUpdate;
   if ( updateType==SVN_UPDATE_WORKSPACE || updateType==SVN_UPDATE_PROJECT ) {
      // If this is a workspace comparison, we have to calculate which paths to
      // do. We get all of the workking paths for the projects, and then calculate
      // the minimum number of paths we do the update for
      workspacePath := _file_path(_workspace_filename);
      pathList = null;
      if ( updateType==SVN_UPDATE_WORKSPACE ) {
         _GetAllFilePathsForWorkspace(_workspace_filename,pathList);
         _SVNGetUpdatePathList(pathList,workspacePath,pathsToUpdate);
      } else if ( updateType==SVN_UPDATE_PROJECT ) {
         projectFilename := path;
         _GetAllFilePathsForProject(projectFilename,_workspace_filename,pathList);
         projectWorkingDir := _ProjectGet_WorkingDir(_ProjectHandle(projectFilename));
         _SVNGetUpdatePathList(pathList,projectWorkingDir,pathsToUpdate);
      }

      numPathsToUpdate := pathsToUpdate._length();

      badPathList := "";
      if ( numPathsToUpdate ) {
         // We use a pointer to _CVSShowStallForm so that it is only called the first
         // iteration (because we set it to null after that)
         pfnStallForm := _CVSShowStallForm;
         for ( i:=0;i<numPathsToUpdate;++i ) {
            status=_SVNGetVerboseFileInfo(pathsToUpdate[i],Files,recurse_option,recurse_option,'',true,pfnStallForm/*_CVSShowStallForm*/,null/*_CVSKillStallForm*/,&vcs,null,false,-1,operation_failed,true);
            if ( status ) {
               if ( status == FILE_NOT_FOUND_RC ) {
                  badPathList :+= ', 'pathsToUpdate[i];
               } else {
                  if (could_not_verify_setup) {
                     _message_box(nls("Could not get Subversion status information.\n\nSlickEdit's %s setup check also failed.  You may not have read access to these files, or your Subversion setup may be incorrect.",VCSYSTEM_TITLE_SUBVERSION));
                  }
                  // Have to manuall call _CVSKillStallForm
                  _CVSKillStallForm();
                  return(status);
               }
            }
            pfnStallForm = null;
         }
         
         // First get spaces
         badPathList = strip(badPathList);
         // Now get commas
         badPathList = strip(badPathList,'B',',');

         if ( badPathList!="" ) {
            _message_box(get_message(SVN_COMMAND_RETURNED_ERROR_FOR_PATH_RC,badPathList));
         }
         // Have to manuall call _CVSKillStallForm
         _CVSKillStallForm();
      }
   } else {
      status=_SVNGetVerboseFileInfo(path,Files,recurse_option,recurse_option,'',true,_CVSShowStallForm,_CVSKillStallForm,&vcs,null,false,-1,operation_failed);
      if (status) {
         if (could_not_verify_setup) {
            _message_box(nls("Could not get Subversion status information.\n\nSlickEdit's %s setup check also failed.  You may not have read access to these files, or your Subversion setup may be incorrect.",VCSYSTEM_TITLE_SUBVERSION));
         }
         return(status);
      }
   }
   if ( Files._length() ) {
      SVNGUIUpdateDialog(Files,path,pathsToUpdate,'',recurse_option);
   } else if ( !status && !operation_failed ) {
      _message_box(nls("All files up to date"));
   }

   return(0);
#endif
}


static _str _SVNGetFilenameFromHistoryDialog(_str DialogPrefix='Log ')
{
   filename := "";
   parse p_active_form.p_caption with (DialogPrefix) 'info for 'filename;
   return(filename);
}

/**
 * Get the name of the file the history dialog is being displayed for from the
 * dialog's caption
 *
 * @return _str name of the file that the dialog is being displayed for
 */
static _str SVNGetFilenameFromHistoryDialog()
{
   return( _SVNGetFilenameFromHistoryDialog(VCSYSTEM_TITLE_SUBVERSION:+' ') );
}

_command int svn_gui_update_workspace() name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   orig_def_vc := def_vc_system;
   def_vc_system = "Subversion";
   svc_gui_mfupdate_workspace();
   def_vc_system = orig_def_vc;
   return 0;
#if 0 //10:34am 4/10/2013
   status := 0;
   workspacePath := _file_path(_workspace_filename);
   status = svn_gui_mfupdate(' -r '_maybe_quote_filename(workspacePath),SVN_UPDATE_WORKSPACE);
   return status;
#endif
}


_command int svn_gui_update_project(_str projectName=_project_name) name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   orig_def_vc := def_vc_system;
   def_vc_system = "Subversion";
   svc_gui_mfupdate_project();
   def_vc_system = orig_def_vc;
   return 0;
#if 0 //10:36am 4/10/2013
   status := 0;
   status = svn_gui_mfupdate(' -r '_maybe_quote_filename(projectName),SVN_UPDATE_PROJECT);
   return status;
#endif
}


/**
 * Runs svn update on the current buffer or <b>filename</b>.  This should
 * probably be re-done to do something more like _SVNCommit and re-use more
 * of the cvs code
 * @param filename name of file to update.  If "", uses the current buffer, if
 *        no current window, uses the open file dialog
 *
 * @return int 0 if successful
 */
_command int svn_update(_str filename='') name_info(FILE_ARG'*,'VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   orig_def_vc := def_vc_system;
   def_vc_system = "Subversion";
   svc_update(filename);
   def_vc_system = orig_def_vc;
   return 0;
#if 0 //10:37am 4/10/2013
   if ( _no_child_windows() && filename=='' ) {
      _str result=_OpenDialog('-modal',
                              'Select file to update',// Dialog Box Title
                              '',                   // Initial Wild Cards
                              def_file_types,       // File Type List
                              OFN_FILEMUSTEXIST,
                              '',
                              ''
                             );
      if ( result=='' ) return(COMMAND_CANCELLED_RC);
      filename=result;
   } else if ( filename=='' ) {
      filename=p_buf_name;
   }
   if ( !file_exists(filename) ) {
      _message_box(nls("The file '%s' does not exist",filename));
      return(FILE_NOT_FOUND_RC);
   }

   ismodified := _SVCBufferIsModified(filename);
   if ( ismodified ) {
      _message_box(nls("Cannot update file '%s' because the file is open and modified",filename));
      return 1;
   }

   _str temp[]=null;
   temp[0]=filename;
   OutputFilename := "";
   int status=_SVNUpdate(temp,OutputFilename);
   _SVCDisplayErrorOutputFromFile(OutputFilename,status);
   delete_file(OutputFilename);
   return(status);
#endif
}

defeventtab _svn_history_choose_form;

void ctlok.on_create()
{
   if ( def_svn_flags&SVN_FLAG_SHOW_BRANCHES ) {
      ctlAllBranches.p_value = 1;
   }else{
      ctlCurBranch.p_value = 1;
   }
   // Retrieve prev form.  If user chooses not to prompt for this 
   // (SVN_FLAG_DO_NOT_PROMPT_FOR_BRANCHES) we will use def_svn_flags&SVN_FLAG_SHOW_BRANCHES
   // rather than show this form at all
   _retrieve_prev_form();
}

void ctlok.lbutton_up()
{
   showBranches := 0;
   if ( ctlAllBranches.p_value == 1 ) {
      // value for whether or not the user will show branches is returned in 
      // _param1
      _param1 = 1;
   }else if ( ctlCurBranch.p_value == 1 ) {
      _param1 = 0;
   }
   if ( ctlremember.p_value ) {
      // depending on whether or not the user has chosen to remember the setting
      // we will set the SVN_FLAG_SHOW_BRANCHES flag
      if ( _param1 ) {
         def_svn_flags |= SVN_FLAG_SHOW_BRANCHES;
      }else{
         def_svn_flags &= ~SVN_FLAG_SHOW_BRANCHES;
      }
      def_svn_flags |= SVN_FLAG_DO_NOT_PROMPT_FOR_BRANCHES;
      _config_modify_flags(CFGMODIFY_DEFVAR);
   }
   // Save the form response.  If user chooses not to prompt for this 
   // (SVN_FLAG_DO_NOT_PROMPT_FOR_BRANCHES) we will use def_svn_flags&SVN_FLAG_SHOW_BRANCHES
   // rather than show this form at all
   _save_form_response();
   p_active_form._delete_window(0);
}
