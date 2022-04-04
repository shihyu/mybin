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

#pragma option(metadata,"4gl.e")
#include "slick.sh"

#include "alias.sh"
#include "android.sh"
#include "autocomplete.sh"
#include "blob.sh"
#include "cbrowser.sh"
#include "codetemplate.sh"
#include "color.sh"
#include "cvs.sh"
#include "debug.sh"
#include "diff.sh"
#include "dirlist.sh"
#include "dockchannel.sh"
#include "eclipse.sh"
#include "ex.sh"
#include "filewatch.sh"
#include "ftp.sh"
#include "git.sh"
#include "guidgen.sh"
#include "hthelp.sh"
#include "license.sh"
#include "listbox.sh"
#include "markers.sh"
#include "mercurial.sh"
#include "mfundo.sh"
#include "minihtml.sh"
#include "os390.sh"
#include "perforce.sh"
#include "pip.sh"
#include "pipe.sh"
#include "project.sh"
#include "quickrefactor.sh"
#include "rc.sh"
#include "refactor.sh"
#include "rte.sh"
#include "scc.sh"
#include "search.sh"
#include "subversion.sh"
#include "svc.sh"
#include "tagsdb.sh"
#include "toolbar.sh"
#include "treeview.sh"
#include "vsevents.sh"
#include "vsockapi.sh"
#include "xml.sh"
#include "xmlwrap.sh"

#import "4gl.e"
#import "actionscript.e"
#import "ada.e"
#import "adaformat.e"
#import "adaptiveformatting.e"
#import "alias.e"
#import "aliasedt.e"
#import "alllanguages.e"
#import "android.e"
#import "annotations.e"
#import "ansic.e"
#import "antlr.e"
#import "applet.e"
#import "argument.e"
#import "asm.e"
#import "assocft.e"
#import "autobracket.e"
#import "autocomplete.e"
#import "autosave.e"
#import "awk.e"
#import "b2k.e"
#import "backtag.e"
#import "bbedit.e"
#import "beautifier.e"
#import "bgsearch.e"
#import "bhrepobrowser.e"
#import "bind.e"
#import "bookmark.e"
#import "box.e"
#import "briefsch.e"
#import "briefutl.e"
#import "bufftabs.e"
#import "c.e"
#import "caddmem.e"
#import "calc.e"
#import "calendar.e"
#import "calib.e"
#import "cbrowser.e"
#import "ccode.e"
#import "ccontext.e"
#import "cformat.e"
#import "cg.e"
//#import "ch.e"
#import "changeman.e"
#import "cics.e"
#import "cjava.e"
#import "clipbd.e"
#import "cmmode.e"
#import "cobol.e"
#import "codehelp.e"
#import "codehelputil.e"
#import "codetemplate.e"
#import "codewarrior.e"
#import "coffeescript.e"
#import "color.e"
#import "combobox.e"
#import "commentformat.e"
//#import "commitset.e"
#import "compare.e"
#import "compile.e"
#import "complete.e"
#import "compword.e"
#import "config.e"
#import "contact_support.e"
#import "context.e"
#import "controls.e"
#import "coolfeatures.e"
#import "csbeaut.e"
#import "css.e"
#import "csymbols.e"
#import "ctadditem.e"
#import "ctcategory.e"
#import "ctitem.e"
#import "ctmanager.e"
#import "ctoptions.e"
#import "ctviews.e"
#import "cua.e"
#import "cutil.e"
#import "cvs.e"
#import "cvsquery.e"
#import "cvsutil.e"
#import "d.e"
#import "dart.e"
#import "db2.e"
#import "debug.e"
#import "debuggui.e"
#import "debugpkg.e"
#import "deltasave.e"
#import "deupdate.e"
#import "diff.e"
#import "diffedit.e"
#import "diffencode.e"
#import "diffinsertsym.e"
#import "diffmf.e"
#import "diffprog.e"
#import "diffsetup.e"
#import "difftags.e"
#import "dir.e"
#import "dirlist.e"
#import "dirlistbox.e"
#import "dirtree.e"
#import "dlgeditv.e"
#import "dlgman.e"
#import "docbook.e"
#import "dockchannel.e"
#import "doscmds.e"
#import "drvlist.e"
#import "eclipse.e"
#import "ejb.e"
#import "emacs.e"
#import "enterpriseoptions.e"
#import "enum.e"
#import "env.e"
#import "erlang.e"
#import "error.e"
#import "errorcfgdlg.e"
#import "event.e"
#import "ex.e"
#import "extern.e"
#import "filecfg.e"
#import "filelist.e"
#import "fileman.e"
#import "files.e"
#import "filetypemanager.e"
#import "filewatch.e"
#import "findfile.e"
#import "font.e"
#import "fontcfg.e"
#import "forall.e"
#import "fortran.e"
#import "frmopen.e"
#import "fsharp.e"
#import "fsort.e"
#import "ftp.e"
#import "ftpclien.e"
#import "ftpopen.e"
#import "ftpparse.e"
#import "ftpq.e"
#import "gemacs.e"
#import "gendtd.e"
#import "get.e"
#import "gnucopts.e"
#import "gradle.e"
#import "googlego.e"
#import "groovy.e"
#import "guicd.e"
#import "guidgen.e"
#import "guifind.e"
#import "guiopen.e"
#import "guireplace.e"
#import "gwt.e"
#import "haskell.e"
#import "help.e"
#import "hex.e"
#import "hformat.e"
#import "history.e"
#import "historydiff.e"
#import "hotfix.e"
#import "hotspots.e"
#import "html.e"
#import "htmltool.e"
#import "ini.e"
#import "inslit.e"
#import "ispf.e"
#import "ispflc.e"
#import "ispfsrch.e"
#import "j2me.e"
#import "java.e"
#import "javacompilergui.e"
#import "javadoc.e"
#import "javaopts.e"
#import "javascript.e"
#import "jrefactor.e"
#import "json.e"
#import "junit.e"
#import "keybindings.e"
#import "last.e"
#import "layouts.e"
#import "licensemgr.e"
#import "listbox.e"
#import "listedit.e"
#import "listproc.e"
#import "lua.e"
#import "main.e"
#import "makefile.e"
#import "markdown.e"
#import "markfilt.e"
#import "math.e"
#import "matlab.e"
#import "maven.e"
#import "menu.e"
#import "menuedit.e"
#import "mercurial.e"
#import "merge.e"
#import "mfsearch.e"
#import "model204.e"
#import "modula.e"
#import "mouse.e"
#import "moveedge.e"
#import "moveline.e"
#import "mprompt.e"
#import "msqbas.e"
#import "notifications.e"
#import "objc.e"
#import "options.e"
#import "optionsxml.e"
#import "os2cmds.e"
#import "output.e"
#import "packs.e"
#import "pascal.e"
#import "pconfig.e"
#import "perl.e"
#import "perlopts.e"
#import "phpopts.e"
#import "picture.e"
#import "pip.e"
#import "pipe.e"
#import "pl1.e"
#import "plsql.e"
#import "pmatch.e"
#import "poperror.e"
#import "ppedit.e"
#import "prefix.e"
#import "prg.e"
#import "print.e"
#import "printcommon.e"
#import "proctree.e"
#import "projconv.e"
#import "project.e"
#import "projmake.e"
#import "projutil.e"
#import "properties.e"
#import "propertysheetform.e"
#import "ps1.e"
#import "ptoolbar.e"
#import "pushtag.e"
#import "put.e"
#import "python.e"
#import "pythonopts.e"
#import "qtoolbar.e"
#import "quickrefactor.e"
#import "quickstart.e"
#import "recmacro.e"
#import "refactor.e"
#import "refactorgui.e"
#import "reflow.e"
#import "restore.e"
#import "rexx.e"
#import "rte.e"
#import "ruby.e"
#import "rubyopts.e"
#import "rul.e"
#import "sas.e"
#import "savecfg.e"
#import "saveload.e"
#import "sbt.e"
#import "scala.e"
#import "search.e"
#import "searchcb.e"
#import "seek.e"
#import "selcob.e"
#import "selcode.e"
#import "seldisp.e"
#import "sellist.e"
#import "sellist2.e"
#import "seltree.e"
#import "setupext.e"
#import "sftp.e"
#import "sftpclien.e"
#import "sftpopen.e"
#import "sftpparse.e"
#import "sftpq.e"
#import "slickc.e"
#import "smartp.e"
#import "spell.e"
#import "spin.e"
#import "sqlservr.e"
#import "sstab.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "subversion.e"
#import "subversionbrowser.e"
#import "subversionutil.e"
#import "surround.e"
#import "svc.e"
#import "svchistory.e"
#import "svcrepobrowser.e"
#import "svcupdate.e"
#import "svcurl.e"
#import "systemverilog.e"
#import "tagfind.e"
#import "tagform.e"
#import "taghilite.e"
#import "tagrefs.e"
#import "tags.e"
#import "tagwin.e"
#import "tbclass.e"
#import "tbclipbd.e"
#import "tbcmds.e"
#import "tbcontrols.e"
#import "tbdeltasave.e"
#import "tbfilelist.e"
#import "tbfind.e"
#import "tbnotification.e"
#import "tbopen.e"
#import "tbprojectcb.e"
#import "tbprops.e"
#import "tbregex.e"
#import "tbsearch.e"
#import "tbshell.e"
#import "tbview.e"
#import "tbxmloutline.e"
#import "tcl.e"
#import "toast.e"
#import "toolbar.e"
#import "tornado.e"
#import "tprint.e"
#import "treeview.e"
#import "ttcn.e"
#import "upcheck.e"
#import "url.e"
#import "util.e"
#import "varedit.e"
#import "vbscript.e"
#import "vc.e"
#import "vchack.e"
//#import "vcpp.e"
#import "vcppopts.e"
#import "vera.e"
#import "verilog.e"
#import "vhdl.e"
#import "vi.e"
#import "vicmode.e"
#import "viimode.e"
#import "vivmode.e"
#import "vlstobjs.e"
#import "vsnet.e"
#import "vstudiosln.e"
#import "wfont.e"
#import "window.e"
#import "winman.e"
#import "wizard.e"
#import "wkspace.e"
#import "wman.e"
#import "xcode.e"
#import "xml.e"
#import "xmlcfg.e"
#import "xmldoc.e"
#import "xmltree.e"
#import "xmlwrap.e"
#import "xmlwrapgui.e"
