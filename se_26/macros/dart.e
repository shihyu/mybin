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
// 
// Language support module for Dart
// 
#pragma option(pedantic,on)
#region Imports
#include "project.sh"
#include "slick.sh"
#include "tagsdb.sh"
#import "c.e"
#import "cfcthelp.e"
#import "cjava.e"
#import "clipbd.e"
#import "compile.e"
#import "csymbols.e"
#import "cutil.e"
#import "env.e"
#import "guiopen.e"
#import "help.e"
#import "main.e"
#import "listbox.e"
#import "picture.e"
#import "projconv.e"
#import "project.e"
#import "mprompt.e"
#import "slickc.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "tags.e"
#import "util.e"
#import "wkspace.e"
#import "files.e"
#import "se/lang/api/LanguageSettings.e"
#endregion

using se.lang.api.LanguageSettings;

static const DART_LANGUAGE_ID= "dart";

_str def_dart_exe_path = "";
static _str _dart_cached_exe_path;

definit() {
   _dart_cached_exe_path="";
}

defeventtab dart_keys;
def  ' '= c_space;
def  '('= c_paren;
def  '.'= auto_codehelp_key;
def  ':'= c_colon;
def  '\'= c_backslash;
def  '{'= c_begin;
def  '}'= c_endbrace;
def  'ENTER'= c_enter;
def  'TAB'= smarttab;
def  ';'= c_semicolon;

_command dart_mode()  name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_ICON)
{
   _SetEditorLanguage(DART_LANGUAGE_ID);
}

/**
 * Callback called from _project_command to prepare the 
 * environment for running dart command-line interpreter. 
 * The value found in def_dart_exe_path takes precedence. If 
 * not found, the environment will be checked for existing 
 * values. If all else fails, a path search will be performed. 
 *
 * @param projectHandle  Project handle. Set to -1 to use 
 *                       current project. Defaults to -1.
 * @param config         Project configuration name. Set to "" 
 *                       to use current configuration. Defaults
 *                       to "".
 * @param target         Project target name (e.g. "Execute", 
 *                       "Compile", etc.).
 * @param quiet          Set to true if you do not want to 
 *                       display error messages to user.
 *                       Defaults to false.
 * @param error_hint     (out) Set to a user-friendly message on 
 *                       error suitable for display in a message.
 *
 * @return 0 on success, <0 on error.
 */
int  _dart_set_environment(int projectHandle, _str config, _str target,
                               bool quiet, _str error_hint)
{
   return set_dart_environment();
}

int set_dart_environment(_str command="dart"EXTENSION_EXE)
{
   dartExePath := guessDartExePath(command);
   // restore the original environment.  this is done so the
   // path for dart is not appended over and over
   _restore_origenv(false);
   if (dartExePath == "") {
      // Prompt user for interpreter
      int status = _MDICurrent().textBoxDialog("Dart Executable",
                                      0,
                                      0,
                                      "",
                                      "OK,Cancel:_cancel\tSpecify the path to 'dart"EXTENSION_EXE"'.",  // Button List
                                      "",
                                      "-c "FILENOQUOTES_ARG:+_chr(0)"-bf Dart Executable Path:");
      if( status < 0 ) {
         // Probably COMMAND_CANCELLED_RC
         return status;
      }

      // Save the values entered and mark the configuration as modified
      def_dart_exe_path = _param1;
      _dart_cached_exe_path="";
      _config_modify_flags(CFGMODIFY_DEFVAR);

      dartExePath = def_dart_exe_path;
   }

   // Set the environment
   dartExeCommand := dartExePath;
   if (!_file_eq(_strip_filename(dartExePath,'PE'), "dart")) {
      _maybe_append(dartExePath, FILESEP);
      dartExeCommand = dartExePath:+command;
   }
   set_env(DART_EXE_ENV_VAR, dartExeCommand);

   dartDir := _strip_filename(dartExePath, 'N');
   _maybe_strip_filesep(dartDir);
   if (dartDir != "") {

      // restore the original environment.  this is done so the
      // path for dart is not appended over and over
      _restore_origenv(false);

      // PATH
      _str path = _replace_envvars("%PATH%");
      _maybe_prepend(path, PATHSEP);
      path = dartDir :+ path;
      set("PATH="path);
   }

   // lastest version of 'Dart' wants DARTSDK set
   dartRoot := _strip_filename(dartDir, 'N');
   if (dartRoot != "") {
      set_env("DARTSDK", dartRoot);
   }

   // set the extension for the os
   set_env(DART_OUTPUT_FILE_EXT_ENV_VAR, EXTENSION_EXE);

   // if this wasn't set, then we didn't find anything
   return (dartExePath != ""?0:1);
}

int _dart_MaybeBuildTagFile(int &tfindex, bool withRefs=false, bool useThread=false, bool forceRebuild=false)
{
   if (!_haveContextTagging()) {
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   // maybe we can recycle tag file(s)
   lang := DART_LANGUAGE_ID;
   if (ext_MaybeRecycleTagFile(tfindex, auto tagfilename, lang) && !forceRebuild) {
      return 0;
   }

   // Try to guess where Dart is installed
   dartPath := guessDartExePath("dart":+EXTENSION_EXE);
   if (dartPath != "") {
      dartPath = strip(dartPath, 'T', FILESEP);
      dartPath = _strip_filename(dartPath, 'n');
      dartPath = strip(dartPath, 'T', FILESEP);
      dartPath = _strip_filename(dartPath, 'n');
   }

   // no dart
   if (dartPath == "") return 1;

   _maybe_append_filesep(dartPath);
   dartsdk_libs := dartPath :+ "lib" :+ FILESEP :+ "*.dart";
   flutter_libs := dartPath :+ "bin" :+ FILESEP :+ "*.dart";

   // Build and Save tag file
   return ext_BuildTagFile(tfindex, tagfilename, lang, 
                           "Dart Compiler Libraries", true, 
                           _maybe_quote_filename(dartsdk_libs) " " _maybe_quote_filename(flutter_libs) :+ " -E *_test.dart -E _internal/",
                           ext_builtins_path(lang),
                           withRefs, useThread);
}



static STRARRAY GetUnixDartPaths(_str command)
{
   if (!_isUnix()) {
      return null;
   }

   // /usr/local/dart-sdk is the default package installation path on MacOS
   // /opt/dart-sdk is also a reasonable place on Unix
   // /usr/local/dart is the default package installation path on MacOS
   // /opt/dart is also a reasonable place on Unix
   //
   _str potentialPaths[];
   potentialPaths :+= "/usr/local/";
   potentialPaths :+= "/opt/";
   potentialPaths :+= "/usr/";
   if (_isMac()) potentialPaths :+= "/Applications/";

   // They could also have installed the SDK under Documents,
   // odd choice, but this is suggested on the Dart language web site
   //
   hd := get_env('HOME');
   if (hd != "") potentialPaths :+= hd:+'Documents\\dart-sdk\';
   if (hd != "") potentialPaths :+= hd:+'tools\\dart-sdk\';
   if (hd != "") potentialPaths :+= hd:+'dart-sdk\';

   // search all paths, and executable extension options
   _str foundPaths[];
   foreach (auto dartPath in potentialPaths) {
      foreach (auto dartDir in "dart-sdk flutter dart Dart Flutter") {
         if (file_exists(dartPath:+dartDir:+"/bin/":+command)) {
            foundPaths :+= dartPath:+dartDir:+"/";
         }
      }
   }

   // return the list of paths found
   return foundPaths;
}

static STRARRAY GetWindowsDartPaths(_str command)
{
   if (!_isWindows()) {
      return null;
   }

   /*
   _ntRegFindValue(HKEY_LOCAL_MACHINE,
                   "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment",
                   "DARTSDK", dartPath);
   if (dartPath == "") {
      _ntRegFindValue(HKEY_CURRENT_USER,
                      "Software\\DartProgrammingLanguage",
                      "installLocation", dartPath);
   }
   */

   // strip file extension from command name, becuase it could be
   // dart without an extension or dart.bat
   command = _strip_filename(command,'e');

   // C:\Tools\dart-sdk is the default package installation path on Windows
   _str potentialPaths[];
   potentialPaths :+= 'C:\Tools\dart-sdk\';
   potentialPaths :+= 'C:\Tools\flutter\';

   // They could also have installed the SDK under Documents,
   // odd choice, but this is suggested on the Dart language web site
   hd := get_env('HOME');
   if (hd != "") potentialPaths :+= hd:+'Documents\\dart-sdk\';
   if (hd != "") potentialPaths :+= hd:+'Tools\\dart-sdk\';
   if (hd != "") potentialPaths :+= hd:+'dart-sdk\';

   // People who do not read instructions will probably put it here
   potentialPaths :+= 'C:\dart-sdk\';
   potentialPaths :+= 'C:\Dart\';
   potentialPaths :+= 'C:\Flutter\';

   // future-proofing, in case if Dart ever has a proper Windows installer
   potentialPaths :+= 'C:\Program Files\Dart\';
   potentialPaths :+= 'C:\Program Files\Flutter\';
   potentialPaths :+= 'C:\Program Files\Google\Dart\';
   potentialPaths :+= 'C:\Program Files\Google\Flutter\';

   // search all paths, and executable extension options
   _str foundPaths[];
   foreach (auto dartPath in potentialPaths) {
      foreach (auto exe_ext in ". .exe .bat") {
         dart_exe := command:+(exe_ext=="."? "":exe_ext);
         if (file_exists(dartPath:+'\bin\'dart_exe)) {
            foundPaths :+= dartPath;
            break;
         }
      }
   }

   // and then there's Cygwin
   dartPath = _path2cygwin("/bin/":+command:+".exe");
   if (dartPath != "") {
      dartPath = _cygwin2dospath(dartPath);
      if (dartPath != "") {
         dartPath = _strip_filename(dartPath, 'N');
         foundPaths :+= dartPath;
      }
   }

   // return the list of paths found
   return foundPaths;
}

void _dart_getAutoTagChoices(_str &langCaption, int &langPriority, 
                                 AUTOTAG_BUILD_INFO (&choices)[], _str &defaultChoice)
{
   _str dartExePaths[];
   langPriority = 46;
   langCaption = "Dart libraries";
   defaultChoice = "";

   // check the cached "Dart" path
   exePath := _GetCachedExePath(def_dart_exe_path,_dart_cached_exe_path,"dart"EXTENSION_EXE);
   if ( exePath != "" && file_exists(exePath)) {
      dartExePaths :+= exePath;
   }

   // try a plain old path search
   exePath = path_search("dart"EXTENSION_EXE, "", 'P');
   if (exePath != "") {
      dartExePaths :+= exePath;
   }

   // try the original path
   if (exePath != "") {
      exePath = _orig_path_search("dart"EXTENSION_EXE);
      if (exePath != "") {
         _restore_origenv(true);
         dartExePaths :+= exePath;
      }
   }

   // maybe check the registry on Windows
   if (_isWindows()) {
       dartPaths := GetWindowsDartPaths("dart.exe");
       foreach (exePath in dartPaths) {
          _maybe_append_filesep(exePath);
          dartExePaths :+= exePath :+ 'bin\dart.exe';
       }
   }

   // check likely installation paths on Unix and macOS
   if (_isUnix()) {
      dartPaths := GetUnixDartPaths("dart");
      foreach (exePath in dartPaths) {
         _maybe_append_filesep(exePath);
         dartExePaths :+= exePath :+ 'bin/dart';
      }
   }

   // set up tag file build
   foreach (auto p in dartExePaths) {
      if (p != "") {
         installPath := _strip_filename(p, 'n');;
         installPath = strip(installPath, 'T', FILESEP);
         installPath = _strip_filename(installPath, 'n');

         AUTOTAG_BUILD_INFO autotagInfo;
         autotagInfo.configName = installPath;

         autotagInfo.langId = "dart";
         autotagInfo.tagDatabase = "dart":+TAG_FILE_EXT;
         autotagInfo.directoryPath = installPath;
         autotagInfo.wildcardOptions = "";
         choices :+= autotagInfo;
      }
   }
}

int _dart_buildAutoTagFile(AUTOTAG_BUILD_INFO &autotagInfo, bool backgroundThread = true)
{
   config_name := autotagInfo.configName;
   dartPath := autotagInfo.directoryPath;
   _maybe_append_filesep(dartPath);
   std_libs := dartPath :+ "src" :+ FILESEP :+ "*.dart";

   // Build and Save tag file
   tfindex := 0;
   return ext_BuildTagFile(tfindex, 
                           _tagfiles_path():+autotagInfo.tagDatabase,
                           autotagInfo.langId,
                           "Dart Compiler Libraries", true, 
                           _maybe_quote_filename(std_libs) :+ " -E *_test.dart",
                           ext_builtins_path(autotagInfo.langId),
                           false, backgroundThread);
}

// handle of project file
static int GG_PROJECT_HANDLE(...) {
   if (arg()) ctl_ok.p_user=arg(1);
   return ctl_ok.p_user;
}
// whether we are currently changing the config
static int GG_CHANGING_CONFIG(...) {
   if (arg()) ctl_cancel.p_user=arg(1);
   return ctl_cancel.p_user;
}
// the last selected config
static _str GG_LAST_CONFIG(...) {
   if (arg()) ctllabel1.p_user=arg(1);
   return ctllabel1.p_user;
}
// list of configs for this project
static _str GG_CONFIG_LIST(...)[] {
   if (arg()) ctllabel10.p_user=arg(1);
   return ctllabel10.p_user;
}
// table of options for each config
static const GG_OPTS="GG_OPTS";

static const DEFAULT_FILE=       '"%f"';
static const DART_EXE_ENV_VAR=     "SLICKEDIT_DART_EXE";
static const DART_OUTPUT_FILE_EXT_ENV_VAR= "SLICKEDIT_DART_OUTPUT_EXT";

struct dartOptions {
   // arguments for dart build
   _str buildArgs;
   // Packages to build. If blank then current file is run.
   _str packages;
   // output file
   _str outputFile;
   // Arguments to the executable
   _str exeArgs;
};

_command void dartoptions(_str configName="") name_info(','VSARG2_REQUIRES_PRO_EDITION)
{
   if (!_haveBuild()) {
      popup_nls_message(VSRC_FEATURE_REQUIRES_PRO_EDITION_1ARG, "Build support");
      return;
   }

   mou_hour_glass(true);
   projectFilesNotNeeded(1);
   int project_prop_wid = show('-hidden -app -xy _project_form',_project_name,_ProjectHandle(_project_name));
   mou_hour_glass(false);
   if (configName == "") configName = GetCurrentConfigName();

   ctlbutton_wid := project_prop_wid._find_control("ctlcommand_options");
   typeless result = ctlbutton_wid.call_event("_dart_options_form",configName,ctlbutton_wid,LBUTTON_UP,'w');
   ctltooltree_wid := project_prop_wid._find_control("ctlToolTree");
   int status = ctltooltree_wid._TreeSearch(TREE_ROOT_INDEX,"Execute",'i');
   if( status < 0 ) {
      _message_box("EXECUTE command not found");
   } else {
      if( result == "" ) {
         opencancel_wid := project_prop_wid._find_control("_opencancel");
         opencancel_wid.call_event(opencancel_wid,LBUTTON_UP,'w');
      } else {
         ok_wid := project_prop_wid._find_control('_ok');
         ok_wid.call_event(ok_wid,LBUTTON_UP,'w');
      }
   }
   projectFilesNotNeeded(0);
}

defeventtab _dart_options_form;

void ctl_ok.on_create(int projectHandle, _str currentConfig=""/*,
                     _str projectFilename=_project_name, bool isProjectTemplate=false*/)
{
   GG_PROJECT_HANDLE(projectHandle);

   _dart_options_form_initial_alignment();

   GG_CHANGING_CONFIG(1);
   orig_wid := p_window_id;

   p_window_id = ctl_current_config.p_window_id;
   _str configList[];
   _ProjectGet_ConfigNames(projectHandle, configList);
   for (i := 0; i < configList._length(); ++i) {
      _lbadd_item(configList[i]);
   }

   // "All Configurations" config
   _lbadd_item(PROJ_ALL_CONFIGS);
   if (_lbfind_and_select_item(currentConfig)) {
      _lbfind_and_select_item(PROJ_ALL_CONFIGS, "", true);
   }
   GG_LAST_CONFIG(ctl_current_config.p_text);

   p_window_id = orig_wid;
   GG_CHANGING_CONFIG(0);

   dartOptions dartOpts:[] = null;
   getdartProjectOptions(projectHandle, configList, dartOpts);

   GG_CONFIG_LIST(configList);
   _SetDialogInfoHt(GG_OPTS,dartOpts);

   ctl_dart_exe_path.p_text = def_dart_exe_path;

   // Initialize form with options.
   // Note: Cannot simply call ctl_current_config.ON_CHANGE because
   // we do not want initial values validated (they might not be valid).
   // Note: It is not possible (through the GUI) to bring up the
   // options dialog without at least 1 configuration.
   setFormOptionsFromConfig(GG_LAST_CONFIG(), dartOpts);

}

/**
 * Does any necessary adjustment of auto-sized controls.
 */
static void _dart_options_form_initial_alignment()
{
   rightAlign := ctl_current_config.p_x_extent;
   sizeBrowseButtonToTextBox(ctl_dart_exe_path.p_window_id, ctl_browse_dart_exe.p_window_id, 0, rightAlign);

   rightAlign = ctl_exe_args.p_x_extent;
   sizeBrowseButtonToTextBox(ctl_packages.p_window_id, ctl_browse_packages.p_window_id, 0, rightAlign);
}

static void getdartProjectOptions(int projectHandle, _str (&configList)[], dartOptions (&optsList):[])
{
   foreach (auto config in configList) {
      dartOptions opts;
      buildArgs := packages := outputFile := exeArgs := "";

      // go through each config
      node := _ProjectGet_ConfigNode(projectHandle, config);
      if (node >= 0) {

         // pull the packages off the clean node - it's easier that way because clean 
         // doesn't have other arguments which may confuse the issue
         target_node := _ProjectGet_TargetNode(projectHandle, "Clean", config);
         cmdline := _ProjectGet_TargetCmdLine(projectHandle, target_node, false);
         parse cmdline with . ('"%('DART_EXE_ENV_VAR')" clean') cmdline;
         packages = strip(cmdline);

         // get the execute node for the build options and output file
         target_node = _ProjectGet_TargetNode(projectHandle, "Build", config);
         cmdline = _ProjectGet_TargetCmdLine(projectHandle, target_node, false);
         parse cmdline with . ('"%('DART_EXE_ENV_VAR')" build') cmdline;
         cmdline = strip(cmdline);
         // dart build [-o output] [build flags] [packages]

         // check for an output file argument
         if (beginsWith(cmdline, '-o')) {
            parse cmdline with '-o' cmdline;
            outputFile = parse_file(cmdline);
         }

         // now we pull the packages off the backend and VOILA! are left with the build args
         if (length(cmdline) > length(packages)) {
            buildArgs = substr(cmdline, 1, length(cmdline) - length(packages));
         }

         // this is the default, so it doesn't need to be shown
         if (packages == DEFAULT_FILE) packages = "";

         target_node = _ProjectGet_TargetNode(projectHandle, "Execute", config);
         exeArgs = _ProjectGet_TargetOtherOptions(projectHandle, target_node);
      }

      opts.buildArgs = buildArgs;
      opts.packages = packages;
      opts.outputFile = outputFile;
      opts.exeArgs = exeArgs;
      optsList:[config] = opts;
   }
}


static void setFormOptionsFromConfig(_str config,
                                     dartOptions (&dartOpts):[])
{
   dartOptions opts;
   if( config == PROJ_ALL_CONFIGS ) {
      // If options do not match across all configs, then use default options instead
      _str last_cfg, cfg;

      last_cfg = "";
      foreach (cfg => . in dartOpts) {
         if (last_cfg != "") {
            if (dartOpts:[last_cfg] != dartOpts:[cfg] ) {
               // No match, so use default options
               opts.buildArgs = opts.exeArgs = opts.packages = opts.outputFile = "";
               break;
            }
         } 
         // Match (or first config)
         opts = dartOpts:[cfg];
         last_cfg = cfg;
      }
   } else {
      opts = dartOpts:[config];
   }

   ctl_build_args.p_text = opts.buildArgs;
   ctl_packages.p_text = opts.packages;
   ctl_output_file.p_text = opts.outputFile;
   ctl_exe_args.p_text = opts.exeArgs;

}

void ctl_browse_packages.lbutton_up()
{
   format_list:=_file_types_get_filter_by_name(def_file_types, 'Dart Files');
   wildcards:=_file_types_get_wildcards_by_name(def_file_types, 'Dart Files');
   if( format_list == "" ) {
      // Fall back
      format_list = "Dart Files (*.dart)";
      wildcards = "*.dart";
   }

   // Try to be smart about the initial directory
   dir := _ProjectGet_WorkingDir(GG_PROJECT_HANDLE());
   dir = absolute(dir, _strip_filename(_project_name, 'N'));

   _str result = _OpenDialog("-modal",
                             "Packages",
                             wildcards,
                             format_list,
                             OFN_ALLOWMULTISELECT|OFN_FILEMUSTEXIST,              // OFN_* flags
                             "",             // Default extensions
                             "",             // Initial filename
                             dir,            // Initial directory
                             "",             // Retrieve name
                             ""              // Help topic
                            );

   if (result != "") {
      text := strip(p_prev.p_text);
      files := "";
      while (result != "") {
         file := parse_file(result, false);
         file = relative(file, dir);

         // make sure it's not already in there
         if (!pos(" "file" ", " "text" ") && pos('"'file'"', '"'text'"')) {
            files :+= " "_maybe_quote_filename(file);
         }
      }
      files = strip(files);

      if (files != "") {
         p_prev.p_text = text" "files;
      }
      p_prev._set_focus();
   }
}

void ctl_current_config.on_change(int reason)
{
   if (GG_CHANGING_CONFIG()) return;
   if (reason != CHANGE_CLINE) return;

   GG_CHANGING_CONFIG(1);
   changeCurrentConfig(p_text);
   GG_CHANGING_CONFIG(0);
}

static void changeCurrentConfig(_str config)
{
   dartOptions opts;
   opts.buildArgs = ctl_build_args.p_text;
   opts.packages = ctl_packages.p_text;
   opts.outputFile = ctl_output_file.p_text;
   opts.exeArgs = ctl_exe_args.p_text;

   // All good, save these settings
   if (config == PROJ_ALL_CONFIGS) {
      _str list[]=GG_CONFIG_LIST();
      for (i := 0; i < list._length(); i++) {
         _GetDialogInfoHtPtr(GG_OPTS)->:[list[i]] = opts;
      }
   } else {
      _GetDialogInfoHtPtr(GG_OPTS)->:[config] = opts;
   }

   // Set form options for new config.
   // "All Configurations" case:
   // If switching to "All Configurations" and configs do not match, then use
   // last options for the default. This is better than blasting the user's
   // settings completely with generic default options.
   GG_LAST_CONFIG(config);
   setFormOptionsFromConfig(GG_LAST_CONFIG(), *_GetDialogInfoHtPtr(GG_OPTS));
}

void ctl_browse_dart_exe.lbutton_up()
{
   _str wildcards = _isUnix()?"":"Executable Files (*.exe;*.com;*.bat;*.cmd)";
   _str format_list = wildcards;

   // Try to be smart about the initial filename and directory
   init_dir := "";
   init_filename := ctl_dart_exe_path.p_text;
   if( init_filename == "" ) {
      init_filename = guessDartExePath();
   }
   if( init_filename != "" ) {
      // Strip off the 'dart' exe to leave the directory
      init_dir = _strip_filename(init_filename,'N');
      _maybe_strip_filesep(init_dir);

      // Strip directory off 'dart' exe to leave filename-only
      init_filename = _strip_filename(init_filename,'P');
   }

   _str result = _OpenDialog("-modal",
                             "Dart",
                             wildcards,
                             format_list,
                             0,             // OFN_* flags
                             "",            // Default extensions
                             init_filename, // Initial filename
                             init_dir,      // Initial directory
                             "",            // Retrieve name
                             ""             // Help topic
                            );
   if( result != "" ) {
      result = strip(result,'B','"');
      p_prev.p_text = result;
      p_prev._set_focus();
   }
}

void ctl_ok.lbutton_up()
{
   // save current values
   changeCurrentConfig(ctl_current_config.p_text);

   // Save all configs for project
   _str list[]=GG_CONFIG_LIST();
   foreach (auto config in list) {
      setProjectOptionsForConfig(GG_PROJECT_HANDLE(), config, _GetDialogInfoHtPtr(GG_OPTS)->:[config]);
   }

   // Dart 
   dartExePath := ctl_dart_exe_path.p_text;
   if(dartExePath != def_dart_exe_path) {
      def_dart_exe_path = dartExePath;
      _dart_cached_exe_path="";
      // Flag state file modified
      _config_modify_flags(CFGMODIFY_DEFVAR);
   }

   // Success
   p_active_form._delete_window(0);
}

static void setProjectOptionsForConfig(int projectHandle, _str config, dartOptions& opts)
{
   cmdline := "";
   packages := "";
   if (opts.packages != "") {
      temp := opts.packages;
      while (temp != "") {
         packages :+= " "_maybe_quote_filename(parse_file(temp));
      }
      packages = strip(packages);
   }
   // default to current file
   if (packages == "") packages = DEFAULT_FILE;

   // build commands used by build and execute
   buildCmdLine := "";
   exeCmdLine := "";
   if (opts.outputFile != "") {
      buildCmdLine = " -o "opts.outputFile" ";
   }

   if (opts.buildArgs != "") {
      buildCmdLine :+= opts.buildArgs" ";
      exeCmdLine :+= opts.buildArgs" ";
   }

   buildCmdLine :+= packages;
   exeCmdLine :+= packages;

   if (opts.exeArgs != "") {
      exeCmdLine :+= " %~other";
   }

   // build
   int target_node = _ProjectGet_TargetNode(projectHandle, "Build", config);
   if (target_node > 0) {
      cmdline = '"%('DART_EXE_ENV_VAR')" build 'buildCmdLine;
      _ProjectSet_TargetCmdLine(projectHandle, target_node, cmdline);
   }

   // clean
   target_node = _ProjectGet_TargetNode(projectHandle, "Clean", config);
   if (target_node > 0) {
      cmdline = '"%('DART_EXE_ENV_VAR')" clean 'packages;
      _ProjectSet_TargetCmdLine(projectHandle, target_node, cmdline);
   }

   // execute
   target_node = _ProjectGet_TargetNode(projectHandle, "Execute", config);
   if (target_node > 0) {
      cmdline = '"%('DART_EXE_ENV_VAR')" run 'exeCmdLine;
      _ProjectSet_TargetCmdLine(projectHandle, target_node, cmdline, "", opts.exeArgs);
   }

   // debug
   target_node = _ProjectGet_TargetNode(projectHandle, "Debug", config);
   if (target_node > 0) {

      // figure out the output file
      outFile := "";
      if (opts.outputFile != "") {
         outFile = opts.outputFile;
      } else if (opts.packages != "") {
         // use the first package
         outFile = parse_file(opts.packages);
         outFile = _strip_filename(outFile, 'E') :+ '%('DART_OUTPUT_FILE_EXT_ENV_VAR')';
      } else {
         // the current file with .exe extension
         outFile = '%n' :+ '%('DART_OUTPUT_FILE_EXT_ENV_VAR')';

      }

      cmdline = 'vsdebugio -prog "'outFile'"';
      if (opts.exeArgs != "") {
         cmdline :+= " "opts.exeArgs;
      }

      _ProjectSet_TargetCmdLine(projectHandle, target_node, cmdline);
   }
}

static _str guessDartExePath(_str command = "dart"EXTENSION_EXE)
{
   dartPath:=_GetCachedExePath(def_dart_exe_path,_dart_cached_exe_path,"dart"EXTENSION_EXE);
   if( file_exists(dartPath)) {
      // No guessing necessary
      dartPath = _strip_filename(dartPath, 'N');
      return dartPath;
   }

   do {
      command = _replace_envvars2(command);

      // first check their DARTSDK environment variable
      dartPath = get_env("DARTSDK");
      if (dartPath != "") {
         _maybe_append_filesep(dartPath);
         dartPath :+= "bin" :+ FILESEP :+ "dart" :+ command;
         if (!file_exists(dartPath)) {
            dartPath = "";
         }
      }

      // try a plain old path search
      dartPath = path_search(command, "", 'P');
      if (dartPath != "") {
         dartPath = _strip_filename(dartPath, 'N');
         break;
      }

      dartPath = _orig_path_search(command);
      if (dartPath != "") {
         _restore_origenv(true);
         dartPath = _strip_filename(dartPath, 'N');
         break;
      }

      // look for dart, since there may be other things named dart
      dartPath = path_search("dart", "", "P");
      if (dartPath != "") {
         dartPath = _strip_filename(dartPath, 'N');
         break;
      }

      // maybe check the registry or other standard Windows installation paths
      if (_isWindows()) {
          installedDartPaths := GetWindowsDartPaths(command);
          if (installedDartPaths._length() > 0) {
             dartPath = installedDartPaths[0];
             _maybe_append_filesep(dartPath);
             dartPath :+= "bin";
             break;

          }
      }

      // check standard Unix installation paths
      if (_isUnix()) {
          installedDartPaths := GetUnixDartPaths(command);
          if (installedDartPaths._length() > 0) {
             dartPath = installedDartPaths[0];
             _maybe_append_filesep(dartPath);
             dartPath :+= "bin";
             break;

          }
      }

   } while (false);

   //say("guessDartExePath H"__LINE__": dartPath="dartPath);
   if (dartPath != "") {
      _maybe_append_filesep(dartPath);
      _dart_cached_exe_path = dartPath :+ "dart" :+ EXTENSION_EXE;
   } else {
      // clear it out, it's no good
      _dart_cached_exe_path = "";
   }

   return _dart_cached_exe_path;
}


int _dart_find_context_tags(_str (&errorArgs)[],_str prefixexp,
                              _str lastid,int lastidstart_offset,
                              int info_flags,typeless otherinfo,
                              bool find_parents,int max_matches,
                              bool exact_match, bool case_sensitive,
                              SETagFilterFlags filter_flags=SE_TAG_FILTER_ANYTHING,
                              SETagContextFlags context_flags=SE_TAG_CONTEXT_ALLOW_LOCALS,
                              VS_TAG_RETURN_TYPE (&visited):[]=null, int depth=0,
                              VS_TAG_RETURN_TYPE &prefix_rt=null)
{
   return _java_find_context_tags(errorArgs,prefixexp,lastid,lastidstart_offset,
                                  info_flags,otherinfo,find_parents,max_matches,
                                  exact_match,case_sensitive,
                                  filter_flags,context_flags,
                                  visited,depth,prefix_rt);
}


int _dart_parse_return_type(_str (&errorArgs)[], typeless tag_files,
                            _str symbol, _str search_class_name,
                            _str file_name, _str return_type, bool isjava,
                            struct VS_TAG_RETURN_TYPE &rt,
                            VS_TAG_RETURN_TYPE (&visited):[], int depth=0)
{
   return _c_parse_return_type(errorArgs,tag_files,
                               symbol,search_class_name,
                               file_name,return_type,
                               true,rt,visited,depth);
}

int _dart_analyze_return_type(_str (&errorArgs)[],typeless tag_files,
                              _str tag_name, _str class_name,
                              _str type_name, SETagFlags tag_flags,
                              _str file_name, _str return_type,
                              struct VS_TAG_RETURN_TYPE &rt,
                              struct VS_TAG_RETURN_TYPE (&visited):[],
                              int depth=0)
{
   return _c_analyze_return_type(errorArgs,tag_files,tag_name,
                                 class_name,type_name,tag_flags,
                                 file_name,return_type,
                                 rt,visited,depth);
}

/**
 * @see _c_get_type_of_expression
 */
int _dart_get_type_of_expression(_str (&errorArgs)[], 
                                   typeless tag_files,
                                   _str symbol, 
                                   _str search_class_name,
                                   _str file_name,
                                   CodeHelpExpressionPrefixFlags prefix_flags,
                                   _str expr, 
                                   struct VS_TAG_RETURN_TYPE &rt,
                                   struct VS_TAG_RETURN_TYPE (&visited):[], int depth=0)
{
   return _c_get_type_of_expression(errorArgs, tag_files, 
                                    symbol, search_class_name, file_name, 
                                    prefix_flags, expr, 
                                    rt, visited, depth);
}

int _dart_insert_constants_of_type(struct VS_TAG_RETURN_TYPE &rt_expected,
                                     int tree_wid, int tree_index,
                                     _str lastid_prefix="", 
                                     bool exact_match=false, bool case_sensitive=true,
                                     _str param_name="", _str param_default="",
                                     struct VS_TAG_RETURN_TYPE (&visited):[]=null, int depth=0)
{
   return _java_insert_constants_of_type(rt_expected,tree_wid,tree_index,lastid_prefix,exact_match,case_sensitive,param_name,param_default,visited,depth);
}

int _dart_match_return_type(struct VS_TAG_RETURN_TYPE &rt_expected,
                              struct VS_TAG_RETURN_TYPE &rt_candidate,
                              _str tag_name,_str type_name,
                              SETagFlags tag_flags,
                              _str file_name, int line_no,
                              _str prefixexp,typeless tag_files,
                              int tree_wid, int tree_index,
                              VS_TAG_RETURN_TYPE (&visited):[]=null, int depth=0)
{
   return _c_match_return_type(rt_expected,rt_candidate,
                               tag_name,type_name,tag_flags,
                               file_name,line_no,
                               prefixexp,tag_files,
                               tree_wid,tree_index,
                               visited,depth);

}

int _dart_fcthelp_get_start(_str (&errorArgs)[],
                              bool OperatorTyped,
                              bool cursorInsideArgumentList,
                              int &FunctionNameOffset,
                              int &ArgumentStartOffset,
                              int &flags,
                              int depth=0)
{
   return(_c_fcthelp_get_start(errorArgs,OperatorTyped,cursorInsideArgumentList,FunctionNameOffset,ArgumentStartOffset,flags,depth));
}

int _dart_fcthelp_get(_str (&errorArgs)[],
                      VSAUTOCODE_ARG_INFO (&FunctionHelp_list)[],
                      bool &FunctionHelp_list_changed,
                      int &FunctionHelp_cursor_x,
                      _str &FunctionHelp_HelpWord,
                      int FunctionNameStartOffset,
                      AutoCodeInfoFlags flags,
                      VS_TAG_BROWSE_INFO symbol_info=null,
                      VS_TAG_RETURN_TYPE (&visited):[]=null, int depth=0)
{
   int status=_c_fcthelp_get(errorArgs,
                             FunctionHelp_list,FunctionHelp_list_changed,
                             FunctionHelp_cursor_x,
                             FunctionHelp_HelpWord,
                             FunctionNameStartOffset,
                             flags, symbol_info,
                             visited, depth);
   return(status);
}

_str _dart_get_decl(_str lang, VS_TAG_BROWSE_INFO &info, int flags=0,
                    _str decl_indent_string="",
                    _str access_indent_string="")
{
   return(_c_get_decl(lang,info,flags,decl_indent_string,access_indent_string));
}

int _dart_get_syntax_completions(var words)
{
   return _c_get_syntax_completions(words); 
}

bool _dart_is_continued_statement()
{
   return _c_is_continued_statement();
}

