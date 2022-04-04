#pragma option(pedantic,on)
#region Imports
#include "slick.sh"
#import "guiopen.e"
#import "help.e"
#import "main.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "svc.e"
#import "svcautodetect.e"
#import "vc.e"
#import "wkspace.e"
#require "se/vc/GitVersionedFile.e"
#endregion

using se.vc.IVersionControl;

// Wholesale a couple of static functions from svc.e
static void getListFromProjectTree(STRARRAY &fileList)
{
   int info;
   for (ff:=1;;ff=0) {
      index := _TreeGetNextSelectedIndex(ff,info);
      if ( index<0 ) break;
      cap := _TreeGetCaption(index);
      parse cap with "\t" auto fullPath;
      fullPath = _AbsoluteToWorkspace(fullPath, _file_path(_workspace_filename));
      if ( fullPath!="" ) {
         fileList :+= fullPath;
      }
   }
}

static bool isProjectToolWindow()
{
   return p_name=='_proj_tooltab_tree' && p_parent.p_name=='_tbprojects_form';
}

const EXAM_DIFF_PATH = 'C:\Program Files\ExamDiff Pro\ExamDiff.exe';

_command void run_exam_diff() name_info(',')
{
   // Be sure we're running pro version
   if (!_haveVersionControl()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Version control");
      return;
   }

   // Get the version control system interface
   VCSystemName := svc_get_vc_system();
   IVersionControl *pInterface = svcGetInterface(VCSystemName);
   if ( pInterface==null ) {
         _message_box("Could not get interface for version control system "VCSystemName".\n\nSet up version control from Tools>Version Control>Setup");
         vcsetup();
         return;
   }

   // Get the filename(s) from current window, projects tool window, etc.
   STRARRAY fileList;
   if ( isProjectToolWindow() ) {
      getListFromProjectTree(fileList);
   } else if ( _no_child_windows() ) {
      cap := lowcase(pInterface->getCaptionForCommand(SVC_COMMAND_DIFF,false,false));
      _str result=_OpenDialog('-modal',
                              'Select file to 'cap,// Dialog Box Title
                              '',                   // Initial Wild Cards
                              def_file_types,       // File Type List
                              OFN_FILEMUSTEXIST,
                              '',
                              ''
                             );
      if ( result=='' ) return;
      fileList[0]=result;
   } else {
      fileList[0]=p_buf_name;
   }

   // Get number of selected file(s)
   len := fileList._length();
   for (i:=0;i<len;++i) {
      // Get the remote file from git
      status := pInterface->getFile(fileList[i],"",auto originalFileWID=0);
      if (status) {
         _message_box(nls(get_message(status,fileList[i])));
         return;
      }

      tempRemoteFilename := mktemp();
      originalFileWID._save_file('+o '_maybe_quote_filename(tempRemoteFilename));

      status = shell('"'EXAM_DIFF_PATH'" "'fileList[i]'" "'_maybe_quote_filename(tempRemoteFilename)'"');

      if (!status) {
         _delete_temp_view(originalFileWID);
         delete_file(tempRemoteFilename);
      }
   }
}

#if 1
// Include this code to be prompted to run report when diff is over
void _diffOnExit_prompt_to_run_report()
{
   result := _message_box(nls("Run ExamDiff report?"),"",MB_YESNO);
   if (result!=IDYES) {
      return;
   }

   // Code to build output filename here.  Modify this as necessary.  Also could
   // prompt for output filename.  Contact us for help if necessary.
   outputFilename := "out."_ctlfile1.p_buf_name;

   status := shell(_maybe_quote_filename(EXAM_DIFF_PATH)' '_maybe_quote_filename(_ctlfile1.p_buf_name)' '_maybe_quote_filename(_ctlfile2.p_buf_name)' "/o:'outputFilename'" /html /no');
}
#endif
