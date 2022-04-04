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
#include "project.sh"
#import "se/lang/api/LanguageSettings.e"
#import "se/tags/TaggingGuard.e"
#import "se/ui/AutoBracketMarker.e"
#import "adaptiveformatting.e"
#import "alias.e"
#require "autocomplete.e"
#import "beautifier.e"
#import "c.e"
#import "cfcthelp.e"
#import "cidexpr.e"
#import "cjava.e"
#import "context.e"
#import "csymbols.e"
#import "cua.e"
#import "cutil.e"
#import "diffprog.e"
#import "env.e"
#import "gradle.e"
#import "groovy.e"
#import "hotspots.e"
#import "java.e"
#import "javacompilergui.e"
#import "main.e"
#import "markfilt.e"
#import "mprompt.e"
#import "notifications.e"
#import "optionsxml.e"
#import "picture.e"
#import "pmatch.e"
#import "projconv.e"
#import "project.e"
#import "refactor.e"
#import "sbt.e"
#import "scala.e"
#import "setupext.e"
#import "slickc.e"
#import "smartp.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "surround.e"
#import "tags.e"
#import "vc.e"
#import "wkspace.e"
#import "compile.e"
#endregion

using se.lang.api.LanguageSettings;
using se.ui.AutoBracketMarker;

const JULIA_LANGUAGE_ID='julia';
static const JULIA_EXE_ENV_VAR="SLICKEDIT_JULIA_EXE";

/**
 * Set to the path to 'julia' executable.
 *
 * @default ""
 * @categories Configuration_Variables
 */
_str def_julia_exe_path = "";
static _str _julia_cached_exe_path;

definit() {
   _julia_cached_exe_path="";
}

_command void julia_mode() name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_ICON)
{
   _SetEditorLanguage('julia');
}
#if 0
bool _julia_find_surround_lines(int &first_line, int &last_line,
                               int &num_first_lines, int &num_last_lines,
                               bool &indent_change,
                               bool ignoreContinuedStatements=false) {
   return _c_find_surround_lines(first_line,last_line,num_first_lines,num_last_lines,indent_change,ignoreContinuedStatements);
}
#endif

_command void julia_keyin_adjust_end_indent() name_info(','VSARG2_MULTI_CURSOR|VSARG2_CMDLINE|VSARG2_REQUIRES_EDITORCTL|VSARG2_LASTKEY)
{
   if (command_state() || _MultiCursorAlreadyLooping()) {
      call_root_key(last_event());
      return;
   }
   keyin(last_event());
   left();
   word:=cur_identifier(auto start_col);
   right();
   if (!(word=='end' /*|| word=='elseif'*/ || word=='else' || word=='finally' || word=='catch')) {
      return;
   }
   if (start_col>1000 || _expand_tabsc(1,start_col-1)!='') {
      return;
   }
   p_col=start_col;
   julia_rest:= _expand_tabsc(p_col,-1,'S');
   julia_end_col:= _julia_get_end_col();
   p_col=start_col+length(word);
   if (julia_end_col && start_col!=julia_end_col) {
      if (!_macro('R')) _undo('s');
      replace_line(indent_string(julia_end_col-1):+julia_rest);
      p_col=julia_end_col+length(word);
   }
}

static bool skip_block_keyword(_str word,int word_start_col=0) {
   /* 
      'end' keyword could be part of a substript like this:

       a[end]   -- Dumb syntax!

      'if' and 'for keyword could be part of a generator like this
        println( [ (i,j) for i=1:2 
                     for j=1:2 if i+j==4 ] )
      This code is definitely not perfect but it will work for most cases.
      I could be improved by matching square brackets but it only helps a little
   */ 

   se.tags.TaggingGuard sentry;
   sentry.lockContext(false);
   _UpdateContext(true,true,VS_UPDATEFLAG_context|VS_UPDATEFLAG_statement);
   int ctx;
   if (word=='end') {
      save_pos(auto p);
      if (word_start_col) {
         p_col=word_start_col;
      }
      if (p_col==1) {
         up();_end_line();
      } else {
         left();
      }
      ctx = tag_current_statement();
      restore_pos(p);
   } else {
      ctx = tag_current_statement();
   }
   if (ctx<=0) {
      save_search(auto s1,auto s2,auto s3,auto s4, auto s5);
      save_pos(auto r1);
      status_r1:=search('[\[\];]|^','-rh@xs');
      if (!status_r1 && match_length()>0 && get_text():=='[') {
         restore_pos(r1);
         restore_search(s1,s2,s3,s4, s5);
         return true;
      }
      restore_pos(r1);
      save_pos(r1);
      status_r1=search('[\[\];]|$','rh@xs');
      if (!status_r1 && match_length()>0 && get_text():==']') {
         restore_pos(r1);
         restore_search(s1,s2,s3,s4, s5);
         return true;
      }
      restore_pos(r1);
      restore_search(s1,s2,s3,s4, s5);
      return false;
   }
   //say('word='word);
   if (word:=='end' || word:=='begin') {
      tag_get_detail2(VS_TAGDETAIL_statement_type, ctx, auto tagType);
      if (tagType=='clause' || tagType=='call') {  // Inside [...] or [...] or {...} or CALL--> array[1:min(end, nextind(s, 0, n))]
         //say('SKIP1 ctx='ctx' word='word' ln='p_line' col='p_col);
         return true;
      }
      //say('NO1 ctx='ctx' word='word' ln='p_line' col='p_col);
      return false;
#if 0
      tag_get_detail2(VS_TAGDETAIL_statement_end_seekpos, ctx, auto endSeek);
      say('endSeek='endSeek' ofst='_QROffset());
      if (endSeek==(typeless)_QROffset()+3) {
         say('GOOD****************');
         return false;
      }
      say('fail h1****************');
      return true;
#endif
   }
   tag_get_detail2(VS_TAGDETAIL_statement_type, ctx, auto tagType);
   if (tagType=='clause' || tagType=='call') {  // Inside [...] or [...] or {...}, or  CALL --> foo(x for x in list if true)
      //say('SKIP2 ctx='ctx' word='word' ln='p_line' col='p_col);
      return true;
   }
   //say('NO2 ctx='ctx' word='word' ln='p_line' col='p_col);
   return false;
   /*tag_get_detail2(VS_TAGDETAIL_statement_start_seekpos, ctx, auto startSeek);

   if (startSeek==_QROffset()) {
      return false;
   }
   return true;*/
}
#if 0
int _julia_find_matching_word(bool quiet,
                          int pmatch_max_diff_ksize=MAXINT,
                          int pmatch_max_level=MAXINT)
{
/*
   if
   elseif
   else
   end

   for
   end

   while
   end

   begin
   end

   try
   catch
   finally
   end

   module
   end

   baremodule
   end

   abstract type
   end

   primitive type
   end


   mutable struct
   end

   struct
   end

   quote
   end

   function
   end

   macro
   end

   let
   end

   foo() do
   end

*/
   
   cfg:=_clex_find(0,'G');
   if (cfg!=CFG_KEYWORD) {
      return 1;
   }
   _str word=cur_identifier(auto start_col);

   save_pos(auto p);
   if (word=='type') {
      p_col= start_col;
      if (p_col==1) {
         if (!quiet) {
            message(nls('Not on begin/end or paren pair'));
         }
         return 1;
      }
      orig_line:=p_line;
      left();_clex_skip_blanks('h-');
      word2:=cur_identifier(auto start_col2);
      if (orig_line!=p_line || (word2!='abstract' && word2!='primitive')) {
         restore_pos(p);
         if (!quiet) {
            message(nls('Not on begin/end or paren pair'));
         }
         return 1;
      }
   } else if (word=='abstract' || word=='primitive' || word=='mutable') {
      p_col=start_col+length(word);
      orig_line:=p_line;
      _clex_skip_blanks('h');
      word2:=cur_identifier(auto start_col2);
      if (orig_line!=p_line || 
          (word!='mutable' && (word2!='type')) ||
          (word=='mutable' && (word2!='struct'))
         ) {
         restore_pos(p);
         if (!quiet) {
            message(nls('Not on begin/end or paren pair'));
         }
         return 1;
      }
      word=word2;
      start_col=start_col2;
   } else if (!pos(' 'word' ',' end do let function macro if else elseif for while begin try catch finally module baremodule struct quote ')) {
      if (!quiet) {
         message(nls('Not on begin/end or paren pair'));
      }
      return 1;
   }
   if (word:=='end' || word:=='begin' || word:=='if' || word:=='for') {
      if (skip_block_keyword(word,start_col)) {
         if (!quiet) {
            message(nls('Not on begin/end or paren pair'));
         }
         return 1;
      }
   }
   bool backwards=false;
   _str options='@wrhck';
   if (word=='end') {
      options='-':+options;
      backwards=true;
   }
   re:='do|let|function|macro|if|for|while|begin|try|module|baremodule|struct|quote|end|abstract[ \t]#type|primitive[ \t]#type';
   if (!backwards) {
      re='elseif|else|catch|finally|':+re;
   }
   if (backwards) {
      if (start_col<=1) {
         up();_end_line();
      } else {
         p_col=start_col-1;
      }
   } else {
      p_col=start_col+length(word);
   }
   int nest_level=1;
   status:=search(re,options);
   for (;;) {
      if (status) {
         break;
      }
      word=cur_identifier(start_col);
      if (word=='end') {
         if (skip_block_keyword(word)) {
            status=repeat_search();
            continue;
         }
         if (backwards) {
            ++nest_level;
         } else {
            --nest_level;
            if (nest_level<1) {
               p_col=start_col;
               return 0;
            }
         }
      } else if (!backwards && pos(' 'word' ',' else elseif catch finally ')) {
         if (nest_level==1) {
            p_col=start_col;
            return 0;
         }
      } else if (pos(' 'word' ',' do let function macro if else elseif for while begin try catch finally module baremodule struct quote abstract primitive ')) {

         if (word=='for' || word=='if' || word=='begin') {
            if (skip_block_keyword(word)) {
               status=repeat_search();
               continue;
            }
         }
      
         if (backwards) {
            --nest_level;
            if (nest_level<1) {
               if (word=='struct') {
                  p_col= start_col;
                  save_pos(auto p2);
                  if (p_col>1) {
                     orig_line:=p_line;
                     left();_clex_skip_blanks('h-');
                     word1:=cur_identifier(auto start_col2);
                     if (orig_line!=p_line || (word1!='mutable')) {
                        restore_pos(p2);
                     } else {
                        start_col=start_col2;
                     }
                  }
               }
               p_col=start_col;
               return 0;
            }
         } else {
            ++nest_level;
         }
      }
      status=repeat_search();
   }
   restore_pos(p);
   return 1;
}
#endif
#if 1
int _julia_find_matching_word(bool quiet,
                          int pmatch_max_diff_ksize=MAXINT,
                          int pmatch_max_level=MAXINT)
{
   int orig_def_update_statements_max_ksize=def_update_statements_max_ksize;
   int orig_def_update_context_max_ksize=def_update_context_max_ksize;
   if (p_buf_size>=def_update_statements_max_ksize*1024) {
      def_update_statements_max_ksize=((p_buf_size intdiv 1024)+1);
   }
   if (p_buf_size>=def_update_context_max_ksize*1024) {
      def_update_context_max_ksize=((p_buf_size intdiv 1024)+1);
   }
   status:=_julia_find_matching_word2(quiet,pmatch_max_diff_ksize,pmatch_max_level);
   def_update_statements_max_ksize=orig_def_update_statements_max_ksize;
   def_update_context_max_ksize=orig_def_update_context_max_ksize;
   return status;
}
static int _julia_find_matching_word2(bool quiet,
                          int pmatch_max_diff_ksize=MAXINT,
                          int pmatch_max_level=MAXINT)
{
/*
   if
   elseif
   else
   end

   for
   end

   while
   end

   begin
   end

   try
   catch
   finally
   end

   module
   end

   baremodule
   end

   abstract type
   end

   primitive type
   end


   mutable struct
   end

   struct
   end

   quote
   end

   function
   end

   macro
   end

   let
   end

   foo() do
   end

*/
   
   cfg:=_clex_find(0,'G');
   if (cfg!=CFG_KEYWORD) {
      return 1;
   }
   _str word=cur_identifier(auto start_col);
   save_pos(auto p);
   int ctx;
   se.tags.TaggingGuard sentry;
   sentry.lockContext(false);
   _UpdateContext(true,true,VS_UPDATEFLAG_context|VS_UPDATEFLAG_statement);
   bool backwards=false;
   bool init_backwards_done=false;
   for (;;) {
      if (init_backwards_done) {
         save_pos(auto p1);
         p_col=start_col;
         if (p_col==1) {
            up();_end_line();
         } else {
            left();
         }
         ctx = tag_current_statement();
         restore_pos(p1);
      } else {
         ctx = tag_current_statement();
      }
      if (word=='type') {
         p_col= start_col;
         if (p_col==1) {
            if (!quiet) {
               message(nls('Not on begin/end or paren pair'));
            }
            return 1;
         }
         orig_line:=p_line;
         left();_clex_skip_blanks('h-');
         word2:=cur_identifier(auto start_col2);
         if (orig_line!=p_line || (word2!='abstract' && word2!='primitive')) {
            restore_pos(p);
            if (!quiet) {
               message(nls('Not on begin/end or paren pair'));
            }
            return 1;
         }
      } else if (word=='abstract' || word=='primitive' || word=='mutable') {
         p_col=start_col+length(word);
         orig_line:=p_line;
         _clex_skip_blanks('h');
         word2:=cur_identifier(auto start_col2);
         if (orig_line!=p_line || 
             (word!='mutable' && (word2!='type')) ||
             (word=='mutable' && (word2!='struct'))
            ) {
            restore_pos(p);
            if (!quiet) {
               message(nls('Not on begin/end or paren pair'));
            }
            return 1;
         }
         word=word2;
         start_col=start_col2;
      } else if (!pos(' 'word' ',' end do let function macro if else elseif for while begin try catch finally module baremodule struct quote ')) {
         if (!quiet) {
            message(nls('Not on begin/end or paren pair'));
         }
         return 1;
      }
      if (word:=='end' || word:=='begin' || word:=='if' || word:=='for') {
         if (skip_block_keyword(word,start_col)) {
            if (!quiet) {
               message(nls('Not on begin/end or paren pair'));
            }
            return 1;
         }
      }
      if (!init_backwards_done) {
         if (word=='end') {
            backwards=true;
         }
         init_backwards_done=true;
      }
      if (ctx==0) {
         if (!quiet) {
            message(nls('File too large'));
         }
         return 1;
      }

      tag_get_detail2(VS_TAGDETAIL_statement_type, ctx, auto tagType);
      if (backwards) {
         tag_get_detail2(VS_TAGDETAIL_statement_start_seekpos, ctx, auto startSeek);
         _GoToROffset(startSeek);
         word=cur_identifier(start_col);
         if (word=='else' || word=='elseif' || word=='catch' || word=='finally') {
            continue;
         }
         // else or elseif
         break;
      } else {
         tag_get_detail2(VS_TAGDETAIL_statement_end_seekpos, ctx, auto endSeek);
         _GoToROffset(endSeek);
         cfg=_clex_find(0,'G');
         if (cfg!=CFG_KEYWORD) {
            left();
            cfg=_clex_find(0,'G');
            if (cfg==CFG_KEYWORD) {
               cur_identifier(start_col);
               p_col=start_col;
            }
         }
         break;
      }
   }
   return 0;
}
#endif

int _julia_get_end_col() {
   //say('*********************************************');
   save_pos(auto p);
   end_text:=cur_identifier(auto word_start_col);
   if (end_text:=='end') {
      status:=_julia_find_matching_word(true);
      if (status) {
         return 0;
      }
      kwd:=cur_identifier(auto word_start_col2);
      int start_col;
      if (kwd=='do') {
         _insert_text('x');
         start_col=calc_nextline_indent_from_tags();
         left();_delete_text(1);
      } else { 
         start_col=calc_nextline_indent_from_tags();
      }
      _first_non_blank();
      if (p_col<start_col) {
         start_col=p_col;
      }
      //say('h1 end start_col='start_col);
      restore_pos(p);
      return start_col;
   }
   p_col=word_start_col;
   save_pos(auto p2);
   _delete_text(length(end_text));
   _insert_text('end');
   p_col=word_start_col;
   status:=_julia_find_matching_word(true);
   if (status) {
      restore_pos(p2);
      _delete_text(3);
      _insert_text(end_text);

      restore_pos(p);
      return 0;
   }
   start_col:=calc_nextline_indent_from_tags();
   _first_non_blank();
   if (p_col<start_col) {
      start_col=p_col;
   }
   restore_pos(p2);
   _delete_text(3);
   _insert_text(end_text);
   restore_pos(p);

   //say('h2 end start_col='start_col);
   return start_col;
}

bool _julia_supports_syntax_indent(bool return_true_if_uses_syntax_indent_property=true) {
   return true;
}

bool _julia_is_smarttab_supported() {
   return true;
}
int julia_smartpaste(bool char_cbtype,int first_col,int Noflines,bool allow_col_1=false)
{
   int comment_col=0;
   // Find first non-blank line which could be a comment.
   first_line := "";
   i := j := 0;
   for (j=1;j<=Noflines;++j) {
      get_line(first_line);
      i=verify(first_line,' '\t);
      if ( i ) {
         p_col=text_col(first_line,i,'I');
      }
      if (i) {
         break;
      }
      if(down()) {
         break;
      }
   }
   comment_col=p_col;  // Comment column or code column.
   //IF the lines we are pasting contain a non-blank line
   if (j<=Noflines) {
      // Skip to first code char
      int status=_clex_skip_blanks('m');
      if (!status) {
         updateAdaptiveFormattingSettings(AFF_SYNTAX_INDENT | AFF_BEGIN_END_STYLE | AFF_INDENT_CASE);
         //int syntax_indent=p_SyntaxIndent;
         word:=cur_identifier(auto start_col);
         if (word:=='end' || word:=='catch' || word:=='finally' || word:=='elseif' || word:=='else') {
            save_pos(auto p1);
            // Adjust what we are pasting relative to the comment.
            // It's ok if there was no comment. adjust_col will be 0.
            int adjust_col=comment_col-p_col;
            p_col=start_col;
            int enter_col=_julia_get_end_col();
            if (enter_col) {
               enter_col+=(adjust_col);
               if (enter_col>=1) {
                  _begin_select();up();
                  return enter_col;
               } else {
                  restore_pos(p1);
               }
            } else {
               restore_pos(p1);
            }
         }
      }
   }
   _begin_select();
   up();
   end_line();
   return calc_nextline_indent_from_tags();
}
bool _julia_is_continued_statement()
{
   get_line(auto line);
   if ( pos('^[ \t]@(else|elseif|catch|finally)([ \t]|$)', line, 1, 'r')) {
      return true;
   }

   return false;
}

static void _julia_insert_context_tag_item(_str cur, _str lastid,
                                         int &num_matches, int max_matches,
                                         bool exact_match=false,
                                         bool case_sensitive=false,
                                         _str tag_file="",
                                         SETagType tag_type=SE_TAG_TYPE_CONSTANT,
                                         VS_TAG_BROWSE_INFO *pargs=null
                                         )
{
//   say("_html_insert_context_tag_item");
   tag_init_tag_browse_info(auto cm);
   if (pargs!=null) {
      cm = *pargs;
   }

   tag_get_type(tag_type,auto type_name);

   cm.tag_database = tag_file;
   cm.member_name = cur;
   cm.type_name = type_name;
   tag_insert_match_browse_info(cm);
   ++num_matches;
}
static _str unicode_name_to_char:[] = {
    "sqrt" => "\x{221A}",
    "cbrt" => "\x{221B}",
    "female" => "\x{2640}",
    "mars" => "\x{2642}",
    "pprime" => "\x{2033}",
    "ppprime" => "\x{2034}",
    "pppprime" => "\x{2057}",
    "backpprime" => "\x{2036}",
    "backppprime" => "\x{2037}",
    "xor" => "\x{22BB}",
    "iff" => "\x{27FA}",
    "implies" => "\x{27F9}",
    "impliedby" => "\x{27F8}",
    "to" => "\x{2192}",
    "euler" => "\x{212F}",
    "ohm" => "\x{2126}",

    // Superscripts
    "^0" => "\x{2070}",
    "^1" => "\x{B9}",
    "^2" => "\x{B2}",
    "^3" => "\x{B3}",
    "^4" => "\x{2074}",
    "^5" => "\x{2075}",
    "^6" => "\x{2076}",
    "^7" => "\x{2077}",
    "^8" => "\x{2078}",
    "^9" => "\x{2079}",
    "^+" => "\x{207A}",
    "^-" => "\x{207B}",
    "^=" => "\x{207C}",
    "^(" => "\x{207D}",
    "^)" => "\x{207E}",
    "^a" => "\x{1D43}",
    "^b" => "\x{1D47}",
    "^c" => "\x{1D9C}",
    "^d" => "\x{1D48}",
    "^e" => "\x{1D49}",
    "^f" => "\x{1DA0}",
    "^g" => "\x{1D4D}",
    "^h" => "\x{2B0}",
    "^i" => "\x{2071}",
    "^j" => "\x{2B2}",
    "^k" => "\x{1D4F}",
    "^l" => "\x{2E1}",
    "^m" => "\x{1D50}",
    "^n" => "\x{207F}",
    "^o" => "\x{1D52}",
    "^p" => "\x{1D56}",
    "^r" => "\x{2B3}",
    "^s" => "\x{2E2}",
    "^t" => "\x{1D57}",
    "^u" => "\x{1D58}",
    "^v" => "\x{1D5B}",
    "^w" => "\x{2B7}",
    "^x" => "\x{2E3}",
    "^y" => "\x{2B8}",
    "^z" => "\x{1DBB}",
    "^A" => "\x{1D2C}",
    "^B" => "\x{1D2E}",
    "^D" => "\x{1D30}",
    "^E" => "\x{1D31}",
    "^G" => "\x{1D33}",
    "^H" => "\x{1D34}",
    "^I" => "\x{1D35}",
    "^J" => "\x{1D36}",
    "^K" => "\x{1D37}",
    "^L" => "\x{1D38}",
    "^M" => "\x{1D39}",
    "^N" => "\x{1D3A}",
    "^O" => "\x{1D3C}",
    "^P" => "\x{1D3E}",
    "^R" => "\x{1D3F}",
    "^T" => "\x{1D40}",
    "^U" => "\x{1D41}",
    "^V" => "\x{2C7D}",
    "^W" => "\x{1D42}",
    "^alpha" => "\x{1D45}",
    "^beta" => "\x{1D5D}",
    "^gamma" => "\x{1D5E}",
    "^delta" => "\x{1D5F}",
    "^epsilon" => "\x{1D4B}",
    "^theta" => "\x{1DBF}",
    "^iota" => "\x{1DA5}",
    "^phi" => "\x{1D60}",
    "^chi" => "\x{1D61}",
    "^Phi" => "\x{1DB2}",
    "^uparrow" => "\x{A71B}",
    "^downarrow" => "\x{A71C}",
    "^!" => "\x{A71D}",

    // Subscripts
    "_0" => "\x{2080}",
    "_1" => "\x{2081}",
    "_2" => "\x{2082}",
    "_3" => "\x{2083}",
    "_4" => "\x{2084}",
    "_5" => "\x{2085}",
    "_6" => "\x{2086}",
    "_7" => "\x{2087}",
    "_8" => "\x{2088}",
    "_9" => "\x{2089}",
    "_+" => "\x{208A}",
    "_-" => "\x{208B}",
    "_=" => "\x{208C}",
    "_(" => "\x{208D}",
    "_)" => "\x{208E}",
    "_a" => "\x{2090}",
    "_e" => "\x{2091}",
    "_h" => "\x{2095}",
    "_i" => "\x{1D62}",
    "_j" => "\x{2C7C}",
    "_k" => "\x{2096}",
    "_l" => "\x{2097}",
    "_m" => "\x{2098}",
    "_n" => "\x{2099}",
    "_o" => "\x{2092}",
    "_p" => "\x{209A}",
    "_r" => "\x{1D63}",
    "_s" => "\x{209B}",
    "_t" => "\x{209C}",
    "_u" => "\x{1D64}",
    "_v" => "\x{1D65}",
    "_x" => "\x{2093}",
    "_schwa" => "\x{2094}",
    "_beta" => "\x{1D66}",
    "_gamma" => "\x{1D67}",
    "_rho" => "\x{1D68}",
    "_phi" => "\x{1D69}",
    "_chi" => "\x{1D6A}",

    // Misc. Math and Physics
    "ldots" => "\x{2026}",
    "hbar" => "\x{127}",
    "del" => "\x{2207}",

    "sout" => "\x{336}", // ulem package, same as Elzbar
    "euro" => "\x{20AC}",

// 732 symbols generated from unicode.xml
    "exclamdown" => "\x{A1}",
    "sterling" => "\x{A3}",
    "yen" => "\x{A5}",
    "brokenbar" => "\x{A6}",
    "S" => "\x{A7}",
    "copyright" => "\x{A9}",
    "ordfeminine" => "\x{AA}",
    "neg" => "\x{AC}",
    "circledR" => "\x{AE}",
    "highminus" => "\x{AF}", // APL "high minus", or non-combining macron above
    "degree" => "\x{B0}",
    "pm" => "\x{B1}",
    "P" => "\x{B6}",
    "cdotp" => "\x{B7}",
    "ordmasculine" => "\x{BA}",
    "questiondown" => "\x{BF}",
    "AA" => "\x{C5}",
    "AE" => "\x{C6}",
    "DH" => "\x{D0}",
    "times" => "\x{D7}",
    "O" => "\x{D8}",
    "TH" => "\x{DE}",
    "ss" => "\x{DF}",
    "aa" => "\x{E5}",
    "ae" => "\x{E6}",
    "eth" => "\x{F0}",
    "dh" => "\x{F0}",
    "div" => "\x{F7}",
    "o" => "\x{F8}",
    "th" => "\x{FE}",
    "DJ" => "\x{110}",
    "dj" => "\x{111}",
    "imath" => "\x{131}",
    "jmath" => "\x{237}",
    "L" => "\x{141}",
    "l" => "\x{142}",
    "NG" => "\x{14A}",
    "ng" => "\x{14B}",
    "OE" => "\x{152}",
    "oe" => "\x{153}",
    "hvlig" => "\x{195}",
    "nrleg" => "\x{19E}",
    "doublepipe" => "\x{1C2}",
    "trna" => "\x{250}",
    "trnsa" => "\x{252}",
    "openo" => "\x{254}",
    "rtld" => "\x{256}",
    "schwa" => "\x{259}",
    "varepsilon" => "\x{3B5}",
    "pgamma" => "\x{263}",
    "pbgam" => "\x{264}",
    "trnh" => "\x{265}",
    "btdl" => "\x{26C}",
    "rtll" => "\x{26D}",
    "trnm" => "\x{26F}",
    "trnmlr" => "\x{270}",
    "ltlmr" => "\x{271}",
    "ltln" => "\x{272}",
    "rtln" => "\x{273}",
    "clomeg" => "\x{277}",
    "ltphi" => "\x{278}", // latin ϕ
    "trnr" => "\x{279}",
    "trnrl" => "\x{27A}",
    "rttrnr" => "\x{27B}",
    "rl" => "\x{27C}",
    "rtlr" => "\x{27D}",
    "fhr" => "\x{27E}",
    "rtls" => "\x{282}",
    "esh" => "\x{283}",
    "trnt" => "\x{287}",
    "rtlt" => "\x{288}",
    "pupsil" => "\x{28A}",
    "pscrv" => "\x{28B}",
    "invv" => "\x{28C}",
    "invw" => "\x{28D}",
    "trny" => "\x{28E}",
    "rtlz" => "\x{290}",
    "yogh" => "\x{292}",
    "glst" => "\x{294}",
    "reglst" => "\x{295}",
    "inglst" => "\x{296}",
    "turnk" => "\x{29E}",
    "dyogh" => "\x{2A4}",
    "tesh" => "\x{2A7}",
    "rasp" => "\x{2BC}",
    "verts" => "\x{2C8}",
    "verti" => "\x{2CC}",
    "lmrk" => "\x{2D0}",
    "hlmrk" => "\x{2D1}",
    "sbrhr" => "\x{2D2}",
    "sblhr" => "\x{2D3}",
    "rais" => "\x{2D4}",
    "low" => "\x{2D5}",
    "u" => "\x{2D8}",
    "tildelow" => "\x{2DC}",
    "grave" => "\x{300}",
    "acute" => "\x{301}",
    "hat" => "\x{302}",
    "tilde" => "\x{303}",
    "bar" => "\x{304}",
    "breve" => "\x{306}",
    "dot" => "\x{307}",
    "ddot" => "\x{308}",
    "ocirc" => "\x{30A}",
    "H" => "\x{30B}",
    "check" => "\x{30C}",
    "palh" => "\x{321}",
    "rh" => "\x{322}",
    "c" => "\x{327}",
    "k" => "\x{328}",
    "sbbrg" => "\x{32A}",
    "strike" => "\x{336}",
    "Alpha" => "\x{391}",
    "Beta" => "\x{392}",
    "Gamma" => "\x{393}",
    "Delta" => "\x{394}",
    "Epsilon" => "\x{395}",
    "Zeta" => "\x{396}",
    "Eta" => "\x{397}",
    "Theta" => "\x{398}",
    "Iota" => "\x{399}",
    "Kappa" => "\x{39A}",
    "Lambda" => "\x{39B}",
    "Xi" => "\x{39E}",
    "Pi" => "\x{3A0}",
    "Rho" => "\x{3A1}",
    "Sigma" => "\x{3A3}",
    "Tau" => "\x{3A4}",
    "Upsilon" => "\x{3A5}",
    "Phi" => "\x{3A6}",
    "Chi" => "\x{3A7}",
    "Psi" => "\x{3A8}",
    "Omega" => "\x{3A9}",
    "alpha" => "\x{3B1}",
    "beta" => "\x{3B2}",
    "gamma" => "\x{3B3}",
    "delta" => "\x{3B4}",
    "zeta" => "\x{3B6}",
    "eta" => "\x{3B7}",
    "theta" => "\x{3B8}",
    "iota" => "\x{3B9}",
    "kappa" => "\x{3BA}",
    "lambda" => "\x{3BB}",
    "mu" => "\x{3BC}",
    "nu" => "\x{3BD}",
    "xi" => "\x{3BE}",
    "pi" => "\x{3C0}",
    "rho" => "\x{3C1}",
    "varsigma" => "\x{3C2}",
    "sigma" => "\x{3C3}",
    "tau" => "\x{3C4}",
    "upsilon" => "\x{3C5}",
    "varphi" => "\x{3C6}",
    "chi" => "\x{3C7}",
    "psi" => "\x{3C8}",
    "omega" => "\x{3C9}",
    "vartheta" => "\x{3D1}",
    "phi" => "\x{3D5}",
    "varpi" => "\x{3D6}",
    "Stigma" => "\x{3DA}",
    "Digamma" => "\x{3DC}",
    "digamma" => "\x{3DD}",
    "Koppa" => "\x{3DE}",
    "Sampi" => "\x{3E0}",
    "varkappa" => "\x{3F0}",
    "varrho" => "\x{3F1}",
    "varTheta" => "\x{3F4}",
    "epsilon" => "\x{3F5}",
    "backepsilon" => "\x{3F6}",
    "enspace" => "\x{2002}",
    "quad" => "\x{2003}",
    "thickspace" => "\x{2005}",
    "thinspace" => "\x{2009}",
    "hspace" => "\x{200A}",
    "endash" => "\x{2013}",
    "emdash" => "\x{2014}",
    "Vert" => "\x{2016}",
    "lq" => "\x{2018}",
    "rq" => "\x{2019}",
    "reapos" => "\x{201B}",
    "quotedblleft" => "\x{201C}",
    "quotedblright" => "\x{201D}",
    "dagger" => "\x{2020}",
    "ddagger" => "\x{2021}",
    "bullet" => "\x{2022}",
    "dots" => "\x{2026}",
    "perthousand" => "\x{2030}",
    "pertenthousand" => "\x{2031}",
    "prime" => "\x{2032}",
    "backprime" => "\x{2035}",
    "guilsinglleft" => "\x{2039}",
    "guilsinglright" => "\x{203A}",
    "nolinebreak" => "\x{2060}",
    "pes" => "\x{20A7}",
    "dddot" => "\x{20DB}",
    "ddddot" => "\x{20DC}",
    "hslash" => "\x{210F}",
    "Im" => "\x{2111}",
    "ell" => "\x{2113}",
    "numero" => "\x{2116}",
    "wp" => "\x{2118}",
    "Re" => "\x{211C}",
    "xrat" => "\x{211E}",
    "trademark" => "\x{2122}",
    "mho" => "\x{2127}",
    "aleph" => "\x{2135}",
    "beth" => "\x{2136}",
    "gimel" => "\x{2137}",
    "daleth" => "\x{2138}",
    "bbpi" => "\x{213F}",
    "bbsum" => "\x{2140}",
    "Game" => "\x{2141}",
    "leftarrow" => "\x{2190}",
    "uparrow" => "\x{2191}",
    "rightarrow" => "\x{2192}",
    "downarrow" => "\x{2193}",
    "leftrightarrow" => "\x{2194}",
    "updownarrow" => "\x{2195}",
    "nwarrow" => "\x{2196}",
    "nearrow" => "\x{2197}",
    "searrow" => "\x{2198}",
    "swarrow" => "\x{2199}",
    "nleftarrow" => "\x{219A}",
    "nrightarrow" => "\x{219B}",
    "twoheadleftarrow" => "\x{219E}",
    "twoheadrightarrow" => "\x{21A0}",
    "leftarrowtail" => "\x{21A2}",
    "rightarrowtail" => "\x{21A3}",
    "mapsto" => "\x{21A6}",
    "hookleftarrow" => "\x{21A9}",
    "hookrightarrow" => "\x{21AA}",
    "looparrowleft" => "\x{21AB}",
    "looparrowright" => "\x{21AC}",
    "leftrightsquigarrow" => "\x{21AD}",
    "nleftrightarrow" => "\x{21AE}",
    "Lsh" => "\x{21B0}",
    "Rsh" => "\x{21B1}",
    "curvearrowleft" => "\x{21B6}",
    "curvearrowright" => "\x{21B7}",
    "circlearrowleft" => "\x{21BA}",
    "circlearrowright" => "\x{21BB}",
    "leftharpoonup" => "\x{21BC}",
    "leftharpoondown" => "\x{21BD}",
    "upharpoonright" => "\x{21BE}",
    "upharpoonleft" => "\x{21BF}",
    "rightharpoonup" => "\x{21C0}",
    "rightharpoondown" => "\x{21C1}",
    "downharpoonright" => "\x{21C2}",
    "downharpoonleft" => "\x{21C3}",
    "rightleftarrows" => "\x{21C4}",
    "dblarrowupdown" => "\x{21C5}",
    "leftrightarrows" => "\x{21C6}",
    "leftleftarrows" => "\x{21C7}",
    "upuparrows" => "\x{21C8}",
    "rightrightarrows" => "\x{21C9}",
    "downdownarrows" => "\x{21CA}",
    "leftrightharpoons" => "\x{21CB}",
    "rightleftharpoons" => "\x{21CC}",
    "nLeftarrow" => "\x{21CD}",
    "nRightarrow" => "\x{21CF}",
    "Leftarrow" => "\x{21D0}",
    "Uparrow" => "\x{21D1}",
    "Rightarrow" => "\x{21D2}",
    "Downarrow" => "\x{21D3}",
    "Leftrightarrow" => "\x{21D4}",
    "Updownarrow" => "\x{21D5}",
    "Lleftarrow" => "\x{21DA}",
    "Rrightarrow" => "\x{21DB}",
    "DownArrowUpArrow" => "\x{21F5}",
    "leftarrowtriangle" => "\x{21FD}",
    "rightarrowtriangle" => "\x{21FE}",
    "forall" => "\x{2200}",
    "complement" => "\x{2201}",
    "partial" => "\x{2202}",
    "exists" => "\x{2203}",
    "nexists" => "\x{2204}",
    "varnothing" => "\x{2205}",
    "emptyset" => "\x{2205}",
    "nabla" => "\x{2207}",
    "in" => "\x{2208}",
    "notin" => "\x{2209}",
    "ni" => "\x{220B}",
    "prod" => "\x{220F}",
    "coprod" => "\x{2210}",
    "sum" => "\x{2211}",
    "minus" => "\x{2212}",
    "mp" => "\x{2213}",
    "dotplus" => "\x{2214}",
    "setminus" => "\x{2216}",
    "ast" => "\x{2217}",
    "circ" => "\x{2218}",
#if 0
    blackboard*"semi" => "\x{2A1F}",
#endif
    "surd" => "\x{221A}",
    "propto" => "\x{221D}",
    "infty" => "\x{221E}",
    "rightangle" => "\x{221F}",
    "angle" => "\x{2220}",
    "measuredangle" => "\x{2221}",
    "sphericalangle" => "\x{2222}",
    "mid" => "\x{2223}",
    "nmid" => "\x{2224}",
    "parallel" => "\x{2225}",
    "nparallel" => "\x{2226}",
    "wedge" => "\x{2227}",
    "vee" => "\x{2228}",
    "cap" => "\x{2229}",
    "cup" => "\x{222A}",
    "int" => "\x{222B}",
    "iint" => "\x{222C}",
    "iiint" => "\x{222D}",
    "oint" => "\x{222E}",
    "oiint" => "\x{222F}",
    "oiiint" => "\x{2230}",
    "clwintegral" => "\x{2231}",
    "therefore" => "\x{2234}",
    "because" => "\x{2235}",
    "Colon" => "\x{2237}",
    "dotminus" => "\x{2238}",
    "kernelcontraction" => "\x{223B}",
    "sim" => "\x{223C}",
    "backsim" => "\x{223D}",
    "lazysinv" => "\x{223E}",
    "wr" => "\x{2240}",
    "nsim" => "\x{2241}",
    "eqsim" => "\x{2242}",
    "neqsim" => "≂\x{338}",
    "simeq" => "\x{2243}",
    "nsime" => "\x{2244}",
    "cong" => "\x{2245}",
    "approxnotequal" => "\x{2246}",
    "ncong" => "\x{2247}",
    "approx" => "\x{2248}",
    "napprox" => "\x{2249}",
    "approxeq" => "\x{224A}",
    "tildetrpl" => "\x{224B}",
    "allequal" => "\x{224C}",
    "asymp" => "\x{224D}",
    "Bumpeq" => "\x{224E}",
    "nBumpeq" => "≎\x{338}",
    "bumpeq" => "\x{224F}",
    "nbumpeq" => "≏\x{338}",
    "doteq" => "\x{2250}",
    "Doteq" => "\x{2251}",
    "fallingdotseq" => "\x{2252}",
    "risingdotseq" => "\x{2253}",
    "coloneq" => "\x{2254}",
    "eqcolon" => "\x{2255}",
    "eqcirc" => "\x{2256}",
    "circeq" => "\x{2257}",
    "wedgeq" => "\x{2259}",
    "starequal" => "\x{225B}",
    "triangleq" => "\x{225C}",
    "questeq" => "\x{225F}",
    "ne" => "\x{2260}",
    "equiv" => "\x{2261}",
    "nequiv" => "\x{2262}",
    "le" => "\x{2264}",
    "leq" => "\x{2264}",
    "ge" => "\x{2265}",
    "geq" => "\x{2265}",
    "leqq" => "\x{2266}",
    "geqq" => "\x{2267}",
    "lneqq" => "\x{2268}",
    "lvertneqq" => "≨\x{FE00}",
    "gneqq" => "\x{2269}",
    "gvertneqq" => "≩\x{FE00}",
    "ll" => "\x{226A}",
    "NotLessLess" => "≪\x{338}",
    "gg" => "\x{226B}",
    "NotGreaterGreater" => "≫\x{338}",
    "between" => "\x{226C}",
    "nless" => "\x{226E}",
    "ngtr" => "\x{226F}",
    "nleq" => "\x{2270}",
    "ngeq" => "\x{2271}",
    "lesssim" => "\x{2272}",
    "gtrsim" => "\x{2273}",
    "lessgtr" => "\x{2276}",
    "gtrless" => "\x{2277}",
    "notlessgreater" => "\x{2278}",
    "notgreaterless" => "\x{2279}",
    "prec" => "\x{227A}",
    "succ" => "\x{227B}",
    "preccurlyeq" => "\x{227C}",
    "succcurlyeq" => "\x{227D}",
    "precsim" => "\x{227E}",
    "nprecsim" => "≾\x{338}",
    "succsim" => "\x{227F}",
    "nsuccsim" => "≿\x{338}",
    "nprec" => "\x{2280}",
    "nsucc" => "\x{2281}",
    "subset" => "\x{2282}",
    "supset" => "\x{2283}",
    "nsubset" => "\x{2284}",
    "nsupset" => "\x{2285}",
    "subseteq" => "\x{2286}",
    "supseteq" => "\x{2287}",
    "nsubseteq" => "\x{2288}",
    "nsupseteq" => "\x{2289}",
    "subsetneq" => "\x{228A}",
    "varsubsetneqq" => "⊊\x{FE00}",
    "supsetneq" => "\x{228B}",
    "varsupsetneq" => "⊋\x{FE00}",
    "cupdot" => "\x{228D}",
    "uplus" => "\x{228E}",
    "sqsubset" => "\x{228F}",
    "NotSquareSubset" => "⊏\x{338}",
    "sqsupset" => "\x{2290}",
    "NotSquareSuperset" => "⊐\x{338}",
    "sqsubseteq" => "\x{2291}",
    "sqsupseteq" => "\x{2292}",
    "sqcap" => "\x{2293}",
    "sqcup" => "\x{2294}",
    "oplus" => "\x{2295}",
    "ominus" => "\x{2296}",
    "otimes" => "\x{2297}",
    "oslash" => "\x{2298}",
    "odot" => "\x{2299}",
    "circledcirc" => "\x{229A}",
    "circledast" => "\x{229B}",
    "circleddash" => "\x{229D}",
    "boxplus" => "\x{229E}",
    "boxminus" => "\x{229F}",
    "boxtimes" => "\x{22A0}",
    "boxdot" => "\x{22A1}",
    "vdash" => "\x{22A2}",
    "dashv" => "\x{22A3}",
    "top" => "\x{22A4}",
    "bot" => "\x{22A5}",
    "models" => "\x{22A7}",
    "vDash" => "\x{22A8}",
    "Vdash" => "\x{22A9}",
    "Vvdash" => "\x{22AA}",
    "VDash" => "\x{22AB}",
    "nvdash" => "\x{22AC}",
    "nvDash" => "\x{22AD}",
    "nVdash" => "\x{22AE}",
    "nVDash" => "\x{22AF}",
    "vartriangleleft" => "\x{22B2}",
    "vartriangleright" => "\x{22B3}",
    "trianglelefteq" => "\x{22B4}",
    "trianglerighteq" => "\x{22B5}",
    "original" => "\x{22B6}",
    "image" => "\x{22B7}",
    "multimap" => "\x{22B8}",
    "hermitconjmatrix" => "\x{22B9}",
    "intercal" => "\x{22BA}",
    "veebar" => "\x{22BB}",
    "rightanglearc" => "\x{22BE}",
    "bigwedge" => "\x{22C0}",
    "bigvee" => "\x{22C1}",
    "bigcap" => "\x{22C2}",
    "bigcup" => "\x{22C3}",
    "diamond" => "\x{22C4}",
    "cdot" => "\x{22C5}",
    "star" => "\x{22C6}",
    "divideontimes" => "\x{22C7}",
    "bowtie" => "\x{22C8}",
    "ltimes" => "\x{22C9}",
    "rtimes" => "\x{22CA}",
    "leftthreetimes" => "\x{22CB}",
    "rightthreetimes" => "\x{22CC}",
    "backsimeq" => "\x{22CD}",
    "curlyvee" => "\x{22CE}",
    "curlywedge" => "\x{22CF}",
    "Subset" => "\x{22D0}",
    "Supset" => "\x{22D1}",
    "Cap" => "\x{22D2}",
    "Cup" => "\x{22D3}",
    "pitchfork" => "\x{22D4}",
    "lessdot" => "\x{22D6}",
    "gtrdot" => "\x{22D7}",
    "verymuchless" => "\x{22D8}",
    "ggg" => "\x{22D9}",
    "lesseqgtr" => "\x{22DA}",
    "gtreqless" => "\x{22DB}",
    "curlyeqprec" => "\x{22DE}",
    "curlyeqsucc" => "\x{22DF}",
    "sqspne" => "\x{22E5}",
    "lnsim" => "\x{22E6}",
    "gnsim" => "\x{22E7}",
    "precnsim" => "\x{22E8}",
    "succnsim" => "\x{22E9}",
    "ntriangleleft" => "\x{22EA}",
    "ntriangleright" => "\x{22EB}",
    "ntrianglelefteq" => "\x{22EC}",
    "ntrianglerighteq" => "\x{22ED}",
    "vdots" => "\x{22EE}",
    "cdots" => "\x{22EF}",
    "adots" => "\x{22F0}",
    "ddots" => "\x{22F1}",
    "lceil" => "\x{2308}",
    "rceil" => "\x{2309}",
    "lfloor" => "\x{230A}",
    "rfloor" => "\x{230B}",
    "recorder" => "\x{2315}",
    "ulcorner" => "\x{231C}",
    "urcorner" => "\x{231D}",
    "llcorner" => "\x{231E}",
    "lrcorner" => "\x{231F}",
    "frown" => "\x{2322}",
    "smile" => "\x{2323}",
    "langle" => "\x{27E8}",
    "rangle" => "\x{27E9}",
    "obar" => "\x{233D}",
    "dlcorn" => "\x{23A3}",
    "lmoustache" => "\x{23B0}",
    "rmoustache" => "\x{23B1}",
    "visiblespace" => "\x{2423}",
    "circledS" => "\x{24C8}",
    "dshfnc" => "\x{2506}",
    "sqfnw" => "\x{2519}",
    "diagup" => "\x{2571}",
    "diagdown" => "\x{2572}",
    "blacksquare" => "\x{25A0}",
    "square" => "\x{25A1}",
    "vrecto" => "\x{25AF}",
    "bigtriangleup" => "\x{25B3}",
    "blacktriangle" => "\x{25B4}",
    "vartriangle" => "\x{25B5}",
    "bigtriangledown" => "\x{25BD}",
    "blacktriangledown" => "\x{25BE}",
    "triangledown" => "\x{25BF}",
    "lozenge" => "\x{25CA}",
    "bigcirc" => "\x{25CB}",
    "cirfl" => "\x{25D0}",
    "cirfr" => "\x{25D1}",
    "cirfb" => "\x{25D2}",
    "rvbull" => "\x{25D8}",
    "sqfl" => "\x{25E7}",
    "sqfr" => "\x{25E8}",
    "sqfse" => "\x{25EA}",
    "bigstar" => "\x{2605}",
    "mercury" => "\x{263F}",
    "venus" => "\x{2640}",
    "male" => "\x{2642}",
    "jupiter" => "\x{2643}",
    "saturn" => "\x{2644}",
    "uranus" => "\x{2645}",
    "neptune" => "\x{2646}",
    "pluto" => "\x{2647}",
    "aries" => "\x{2648}",
    "taurus" => "\x{2649}",
    "gemini" => "\x{264A}",
    "cancer" => "\x{264B}",
    "leo" => "\x{264C}",
    "virgo" => "\x{264D}",
    "libra" => "\x{264E}",
    "scorpio" => "\x{264F}",
    "sagittarius" => "\x{2650}",
    "capricornus" => "\x{2651}",
    "aquarius" => "\x{2652}",
    "pisces" => "\x{2653}",
    "spadesuit" => "\x{2660}",
    "heartsuit" => "\x{2661}",
    "diamondsuit" => "\x{2662}",
    "clubsuit" => "\x{2663}",
    "quarternote" => "\x{2669}",
    "eighthnote" => "\x{266A}",
    "flat" => "\x{266D}",
    "natural" => "\x{266E}",
    "sharp" => "\x{266F}",
    "checkmark" => "\x{2713}",
    "maltese" => "\x{2720}",
    "longleftarrow" => "\x{27F5}",
    "longrightarrow" => "\x{27F6}",
    "longleftrightarrow" => "\x{27F7}",
    "Longleftarrow" => "\x{27F8}",
    "Longrightarrow" => "\x{27F9}",
    "Longleftrightarrow" => "\x{27FA}",
    "longmapsto" => "\x{27FC}",
    "Mapsfrom" => "\x{2906}",
    "Mapsto" => "\x{2907}",
    "Uuparrow" => "\x{290A}",
    "Ddownarrow" => "\x{290B}",
    "bkarow" => "\x{290D}",
    "dbkarow" => "\x{290F}",
    "drbkarrow" => "\x{2910}",
    "UpArrowBar" => "\x{2912}",
    "DownArrowBar" => "\x{2913}",
    "twoheadrightarrowtail" => "\x{2916}",
    "hksearow" => "\x{2925}",
    "hkswarow" => "\x{2926}",
    "tona" => "\x{2927}",
    "toea" => "\x{2928}",
    "tosa" => "\x{2929}",
    "towa" => "\x{292A}",
    "rdiagovfdiag" => "\x{292B}",
    "fdiagovrdiag" => "\x{292C}",
    "seovnearrow" => "\x{292D}",
    "neovsearrow" => "\x{292E}",
    "fdiagovnearrow" => "\x{292F}",
    "rdiagovsearrow" => "\x{2930}",
    "neovnwarrow" => "\x{2931}",
    "nwovnearrow" => "\x{2932}",
    "Rlarr" => "\x{2942}",
    "rLarr" => "\x{2944}",
    "rarrx" => "\x{2947}",
    "LeftRightVector" => "\x{294E}",
    "RightUpDownVector" => "\x{294F}",
    "DownLeftRightVector" => "\x{2950}",
    "LeftUpDownVector" => "\x{2951}",
    "LeftVectorBar" => "\x{2952}",
    "RightVectorBar" => "\x{2953}",
    "RightUpVectorBar" => "\x{2954}",
    "RightDownVectorBar" => "\x{2955}",
    "DownLeftVectorBar" => "\x{2956}",
    "DownRightVectorBar" => "\x{2957}",
    "LeftUpVectorBar" => "\x{2958}",
    "LeftDownVectorBar" => "\x{2959}",
    "LeftTeeVector" => "\x{295A}",
    "RightTeeVector" => "\x{295B}",
    "RightUpTeeVector" => "\x{295C}",
    "RightDownTeeVector" => "\x{295D}",
    "DownLeftTeeVector" => "\x{295E}",
    "DownRightTeeVector" => "\x{295F}",
    "LeftUpTeeVector" => "\x{2960}",
    "LeftDownTeeVector" => "\x{2961}",
    "UpEquilibrium" => "\x{296E}",
    "ReverseUpEquilibrium" => "\x{296F}",
    "RoundImplies" => "\x{2970}",
    "Vvert" => "\x{2980}",
    "Elroang" => "\x{2986}",
    "ddfnc" => "\x{2999}",
    "Angle" => "\x{299C}",
    "lpargt" => "\x{29A0}",
    "obslash" => "\x{29B8}",
    "boxdiag" => "\x{29C4}",
    "boxbslash" => "\x{29C5}",
    "boxast" => "\x{29C6}",
    "boxcircle" => "\x{29C7}",
    "Lap" => "\x{29CA}",
    "defas" => "\x{29CB}",
    "LeftTriangleBar" => "\x{29CF}",
    "NotLeftTriangleBar" => "⧏\x{338}",
    "RightTriangleBar" => "\x{29D0}",
    "NotRightTriangleBar" => "⧐\x{338}",
    "dualmap" => "\x{29DF}",
    "shuffle" => "\x{29E2}",
    "blacklozenge" => "\x{29EB}",
    "RuleDelayed" => "\x{29F4}",
    "bigodot" => "\x{2A00}",
    "bigoplus" => "\x{2A01}",
    "bigotimes" => "\x{2A02}",
    "bigcupdot" => "\x{2A03}",
    "biguplus" => "\x{2A04}",
    "bigsqcap" => "\x{2A05}",
    "bigsqcup" => "\x{2A06}",
    "conjquant" => "\x{2A07}",
    "disjquant" => "\x{2A08}",
    "bigtimes" => "\x{2A09}",
    "iiiint" => "\x{2A0C}",
    "intbar" => "\x{2A0D}",
    "intBar" => "\x{2A0E}",
    "clockoint" => "\x{2A0F}",
    "sqrint" => "\x{2A16}",
    "intx" => "\x{2A18}",
    "intcap" => "\x{2A19}",
    "intcup" => "\x{2A1A}",
    "upint" => "\x{2A1B}",
    "lowint" => "\x{2A1C}",
    "plusdot" => "\x{2A25}",
    "minusdot" => "\x{2A2A}",
    "Times" => "\x{2A2F}",
    "btimes" => "\x{2A32}",
    "intprod" => "\x{2A3C}",
    "intprodr" => "\x{2A3D}",
    "amalg" => "\x{2A3F}",
    "And" => "\x{2A53}",
    "Or" => "\x{2A54}",
    "ElOr" => "\x{2A56}",
    "perspcorrespond" => "\x{2A5E}",
    "minhat" => "\x{2A5F}",
    "Equal" => "\x{2A75}",
    "ddotseq" => "\x{2A77}",
    "leqslant" => "\x{2A7D}",
    "nleqslant" => "⩽\x{338}",
    "geqslant" => "\x{2A7E}",
    "ngeqslant" => "⩾\x{338}",
    "lessapprox" => "\x{2A85}",
    "gtrapprox" => "\x{2A86}",
    "lneq" => "\x{2A87}",
    "gneq" => "\x{2A88}",
    "lnapprox" => "\x{2A89}",
    "gnapprox" => "\x{2A8A}",
    "lesseqqgtr" => "\x{2A8B}",
    "gtreqqless" => "\x{2A8C}",
    "eqslantless" => "\x{2A95}",
    "eqslantgtr" => "\x{2A96}",
    "NestedLessLess" => "\x{2AA1}",
    "NotNestedLessLess" => "⪡\x{338}",
    "NestedGreaterGreater" => "\x{2AA2}",
    "NotNestedGreaterGreater" => "⪢\x{338}",
    "partialmeetcontraction" => "\x{2AA3}",
    "bumpeqq" => "\x{2AAE}",
    "preceq" => "\x{2AAF}",
    "npreceq" => "⪯\x{338}",
    "succeq" => "\x{2AB0}",
    "nsucceq" => "⪰\x{338}",
    "precneqq" => "\x{2AB5}",
    "succneqq" => "\x{2AB6}",
    "precapprox" => "\x{2AB7}",
    "succapprox" => "\x{2AB8}",
    "precnapprox" => "\x{2AB9}",
    "succnapprox" => "\x{2ABA}",
    "subseteqq" => "\x{2AC5}",
    "nsubseteqq" => "⫅\x{338}",
    "supseteqq" => "\x{2AC6}",
    "nsupseteqq" => "⫆\x{338}",
    "subsetneqq" => "\x{2ACB}",
    "supsetneqq" => "\x{2ACC}",
    "mlcp" => "\x{2ADB}",
    "forks" => "\x{2ADC}",
    "forksnot" => "\x{2ADD}",
    "dashV" => "\x{2AE3}",
    "Dashv" => "\x{2AE4}",
    "interleave" => "\x{2AF4}",
    "tdcol" => "\x{2AF6}",
    "openbracketleft" => "\x{27E6}",
    "llbracket" => "\x{27E6}",
    "openbracketright" => "\x{27E7}",
    "rrbracket" => "\x{27E7}",
    "overbrace" => "\x{23DE}",
    "underbrace" => "\x{23DF}",

// 1607 symbols generated from unicode-math-table.tex:
    "Zbar" => "\x{1B5}",  // impedance (latin capital letter z with stroke)
    "overbar" => "\x{305}",  // overbar embellishment
    "ovhook" => "\x{309}",  // combining hook above
    "candra" => "\x{310}",  // candrabindu (non-spacing)
    "oturnedcomma" => "\x{312}",  // combining turned comma above
    "ocommatopright" => "\x{315}",  // combining comma above right
    "droang" => "\x{31A}",  // left angle above (non-spacing)
    "wideutilde" => "\x{330}",  // under tilde accent (multiple characters and non-spacing)
    "not" => "\x{338}",  // combining long solidus overlay
    "upMu" => "\x{39C}",  // capital mu, greek
    "upNu" => "\x{39D}",  // capital nu, greek
    "upOmicron" => "\x{39F}",  // capital omicron, greek
    "upepsilon" => "\x{3B5}",  // rounded small epsilon, greek
    "upomicron" => "\x{3BF}",  // small omicron, greek
    "upvarbeta" => "\x{3D0}",  // rounded small beta, greek
    "upoldKoppa" => "\x{3D8}",  // greek letter archaic koppa
    "upoldkoppa" => "\x{3D9}",  // greek small letter archaic koppa
    "upstigma" => "\x{3DB}",  // greek small letter stigma
    "upkoppa" => "\x{3DF}",  // greek small letter koppa
    "upsampi" => "\x{3E1}",  // greek small letter sampi
    "tieconcat" => "\x{2040}",  // character tie, z notation sequence concatenation
    "leftharpoonaccent" => "\x{20D0}",  // combining left harpoon above
    "rightharpoonaccent" => "\x{20D1}",  // combining right harpoon above
    "vertoverlay" => "\x{20D2}",  // combining long vertical line overlay
    "overleftarrow" => "\x{20D6}",  // combining left arrow above
    "vec" => "\x{20D7}",  // combining right arrow above
    "enclosecircle" => "\x{20DD}",  // combining enclosing circle
    "enclosesquare" => "\x{20DE}",  // combining enclosing square
    "enclosediamond" => "\x{20DF}",  // combining enclosing diamond
    "overleftrightarrow" => "\x{20E1}",  // combining left right arrow above
    "enclosetriangle" => "\x{20E4}",  // combining enclosing upward pointing triangle
    "annuity" => "\x{20E7}",  // combining annuity symbol
    "threeunderdot" => "\x{20E8}",  // combining triple underdot
    "widebridgeabove" => "\x{20E9}",  // combining wide bridge above
    "underrightharpoondown" => "\x{20ec}",  // combining rightwards harpoon with barb downwards
    "underleftharpoondown" => "\x{20ed}",  // combining leftwards harpoon with barb downwards
    "underleftarrow" => "\x{20ee}",  // combining left arrow below
    "underrightarrow" => "\x{20ef}",  // combining right arrow below
    "asteraccent" => "\x{20f0}",  // combining asterisk above
    "bbC" => "\x{2102}",  // /bbb c, open face c
    "eulermascheroni" => "\x{2107}",  // euler-mascheroni constant U+2107
    "scrg" => "\x{210A}",  // /scr g, script letter g
    "scrH" => "\x{210B}",  // hamiltonian (script capital h)
    "frakH" => "\x{210C}",  // /frak h, upper case h
    "bbH" => "\x{210D}",  // /bbb h, open face h
    "planck" => "\x{210E}",  // planck constant
    "scrI" => "\x{2110}",  // /scr i, script letter i
    "scrL" => "\x{2112}",  // lagrangian (script capital l)
    "bbN" => "\x{2115}",  // /bbb n, open face n
    "bbP" => "\x{2119}",  // /bbb p, open face p
    "bbQ" => "\x{211A}",  // /bbb q, open face q
    "scrR" => "\x{211B}",  // /scr r, script letter r
    "bbR" => "\x{211D}",  // /bbb r, open face r
    "bbZ" => "\x{2124}",  // /bbb z, open face z
    "frakZ" => "\x{2128}",  // /frak z, upper case z
    "turnediota" => "\x{2129}",  // turned iota
    "Angstrom" => "\x{212B}",  // angstrom capital a, ring
    "scrB" => "\x{212C}",  // bernoulli function (script capital b)
    "frakC" => "\x{212D}",  // black-letter capital c
    "scre" => "\x{212F}",  // /scr e, script letter e
    "scrE" => "\x{2130}",  // /scr e, script letter e
    "scrF" => "\x{2131}",  // /scr f, script letter f
    "Finv" => "\x{2132}",  // turned capital f
    "scrM" => "\x{2133}",  // physics m-matrix (script capital m)
    "scro" => "\x{2134}",  // order of (script small o)
    "bbpi" => "\x{213c}",  // double-struck small pi
    "bbgamma" => "\x{213D}",  // double-struck small gamma
    "bbGamma" => "\x{213E}",  // double-struck capital gamma
    "sansLturned" => "\x{2142}",  // turned sans-serif capital l
    "sansLmirrored" => "\x{2143}",  // reversed sans-serif capital l
    "Yup" => "\x{2144}",  // turned sans-serif capital y
    "itbbD" => "\x{2145}",  // double-struck italic capital d
    "itbbd" => "\x{2146}",  // double-struck italic small d
    "itbbe" => "\x{2147}",  // double-struck italic small e
    "itbbi" => "\x{2148}",  // double-struck italic small i
    "itbbj" => "\x{2149}",  // double-struck italic small j
    "PropertyLine" => "\x{214A}",  // property line
    "upand" => "\x{214B}",  // turned ampersand
    "twoheaduparrow" => "\x{219F}",  // up two-headed arrow
    "twoheaddownarrow" => "\x{21A1}",  // down two-headed arrow
    "mapsfrom" => "\x{21A4}",  // maps to, leftward
    "mapsup" => "\x{21A5}",  // maps to, upward
    "mapsdown" => "\x{21A7}",  // maps to, downward
    "updownarrowbar" => "\x{21A8}",  // up down arrow with base (perpendicular)
    "downzigzagarrow" => "\x{21AF}",  // downwards zigzag arrow
    "Ldsh" => "\x{21B2}",  // left down angled arrow
    "Rdsh" => "\x{21B3}",  // right down angled arrow
    "linefeed" => "\x{21B4}",  // rightwards arrow with corner downwards
    "carriagereturn" => "\x{21B5}",  // downwards arrow with corner leftward = carriage return
    "barovernorthwestarrow" => "\x{21B8}",  // north west arrow to long bar
    "barleftarrowrightarrowbar" => "\x{21B9}",  // leftwards arrow to bar over rightwards arrow to bar
    "nLeftrightarrow" => "\x{21CE}",  // not left and right double arrows
    "Nwarrow" => "\x{21D6}",  // nw pointing double arrow
    "Nearrow" => "\x{21D7}",  // ne pointing double arrow
    "Searrow" => "\x{21D8}",  // se pointing double arrow
    "Swarrow" => "\x{21D9}",  // sw pointing double arrow
    "leftsquigarrow" => "\x{21DC}",  // leftwards squiggle arrow
    "rightsquigarrow" => "\x{21DD}",  // rightwards squiggle arrow
    "nHuparrow" => "\x{21DE}",  // upwards arrow with double stroke
    "nHdownarrow" => "\x{21DF}",  // downwards arrow with double stroke
    "leftdasharrow" => "\x{21E0}",  // leftwards dashed arrow
    "updasharrow" => "\x{21E1}",  // upwards dashed arrow
    "rightdasharrow" => "\x{21E2}",  // rightwards dashed arrow
    "downdasharrow" => "\x{21E3}",  // downwards dashed arrow
    "barleftarrow" => "\x{21E4}",  // leftwards arrow to bar
    "rightarrowbar" => "\x{21E5}",  // rightwards arrow to bar
    "leftwhitearrow" => "\x{21E6}",  // leftwards white arrow
    "upwhitearrow" => "\x{21E7}",  // upwards white arrow
    "rightwhitearrow" => "\x{21E8}",  // rightwards white arrow
    "downwhitearrow" => "\x{21E9}",  // downwards white arrow
    "whitearrowupfrombar" => "\x{21EA}",  // upwards white arrow from bar
    "circleonrightarrow" => "\x{21F4}",  // right arrow with small circle
    "rightthreearrows" => "\x{21F6}",  // three rightwards arrows
    "nvleftarrow" => "\x{21F7}",  // leftwards arrow with vertical stroke
    "nvrightarrow" => "\x{21F8}",  // rightwards arrow with vertical stroke
    "nvleftrightarrow" => "\x{21F9}",  // left right arrow with vertical stroke
    "nVleftarrow" => "\x{21FA}",  // leftwards arrow with double vertical stroke
    "nVrightarrow" => "\x{21FB}",  // rightwards arrow with double vertical stroke
    "nVleftrightarrow" => "\x{21FC}",  // left right arrow with double vertical stroke
    "leftrightarrowtriangle" => "\x{21FF}",  // left right open-headed arrow
    "increment" => "\x{2206}",  // laplacian (delta; nabla\string^2)
    "smallin" => "\x{220A}",  // set membership (small set membership)
    "nni" => "\x{220C}",  // negated contains, variant
    "smallni" => "\x{220D}",  // /ni /owns r: contains (small contains as member)
    "QED" => "\x{220E}",  // end of proof
    "vysmblkcircle" => "\x{2219}",  // bullet operator
    "fourthroot" => "\x{221C}",  // fourth root
    "varointclockwise" => "\x{2232}",  // contour integral, clockwise
    "ointctrclockwise" => "\x{2233}",  // contour integral, anticlockwise
    "dotsminusdots" => "\x{223A}",  // minus with four dots, geometric properties
    "sinewave" => "\x{223F}",  // sine wave
    "arceq" => "\x{2258}",  // arc, equals; corresponds to
    "veeeq" => "\x{225A}",  // logical or, equals
    "eqdef" => "\x{225D}",  // equals by definition
    "measeq" => "\x{225E}",  // measured by (m over equals)
    "Equiv" => "\x{2263}",  // strict equivalence (4 lines)
    "nasymp" => "\x{226D}",  // not asymptotically equal to
    "nlesssim" => "\x{2274}",  // not less, similar
    "ngtrsim" => "\x{2275}",  // not greater, similar
    "circledequal" => "\x{229C}",  // equal in circle
    "prurel" => "\x{22B0}",  // element precedes under relation
    "scurel" => "\x{22B1}",  // succeeds under relation
    "barwedge" => "\x{22BC}",  // bar, wedge (large wedge)
    "barvee" => "\x{22BD}",  // bar, vee (large vee)
    "varlrtriangle" => "\x{22BF}",  // right triangle
    "equalparallel" => "\x{22D5}",  // parallel, equal; equal or parallel
    "eqless" => "\x{22DC}",  // equal-or-less
    "eqgtr" => "\x{22DD}",  // equal-or-greater
    "npreccurlyeq" => "\x{22E0}",  // not precedes, curly equals
    "nsucccurlyeq" => "\x{22E1}",  // not succeeds, curly equals
    "nsqsubseteq" => "\x{22E2}",  // not, square subset, equals
    "nsqsupseteq" => "\x{22E3}",  // not, square superset, equals
    "sqsubsetneq" => "\x{22E4}",  // square subset, not equals
    "disin" => "\x{22F2}",  // element of with long horizontal stroke
    "varisins" => "\x{22F3}",  // element of with vertical bar at end of horizontal stroke
    "isins" => "\x{22F4}",  // small element of with vertical bar at end of horizontal stroke
    "isindot" => "\x{22F5}",  // element of with dot above
    "varisinobar" => "\x{22F6}",  // element of with overbar
    "isinobar" => "\x{22F7}",  // small element of with overbar
    "isinvb" => "\x{22F8}",  // element of with underbar
    "isinE" => "\x{22F9}",  // element of with two horizontal strokes
    "nisd" => "\x{22FA}",  // contains with long horizontal stroke
    "varnis" => "\x{22FB}",  // contains with vertical bar at end of horizontal stroke
    "nis" => "\x{22FC}",  // small contains with vertical bar at end of horizontal stroke
    "varniobar" => "\x{22FD}",  // contains with overbar
    "niobar" => "\x{22FE}",  // small contains with overbar
    "bagmember" => "\x{22FF}",  // z notation bag membership
    "diameter" => "\x{2300}",  // diameter sign
    "house" => "\x{2302}",  // house
    "vardoublebarwedge" => "\x{2306}",  // /doublebarwedge b: logical and, double bar above [perspective (double bar over small wedge)]
    "invnot" => "\x{2310}",  // reverse not
    "sqlozenge" => "\x{2311}",  // square lozenge
    "profline" => "\x{2312}",  // profile of a line
    "profsurf" => "\x{2313}",  // profile of a surface
    "viewdata" => "\x{2317}",  // viewdata square
    "turnednot" => "\x{2319}",  // turned not sign
    "varhexagonlrbonds" => "\x{232C}",  // six carbon ring, corner down, double bonds lower right etc
    "conictaper" => "\x{2332}",  // conical taper
    "topbot" => "\x{2336}",  // top and bottom
    "notslash" => "\x{233F}",  // solidus, bar through (apl functional symbol slash bar)
    "notbackslash" => "\x{2340}",  // apl functional symbol backslash bar
    "boxupcaret" => "\x{2353}",  // boxed up caret
    "boxquestion" => "\x{2370}",  // boxed question mark
    "hexagon" => "\x{2394}",  // horizontal benzene ring [hexagon flat open]
    "overbracket" => "\x{23B4}",  // top square bracket
    "underbracket" => "\x{23B5}",  // bottom square bracket
    "bbrktbrk" => "\x{23B6}",  // bottom square bracket over top square bracket
    "sqrtbottom" => "\x{23B7}",  // radical symbol bottom
    "lvboxline" => "\x{23B8}",  // left vertical box line
    "rvboxline" => "\x{23B9}",  // right vertical box line
    "varcarriagereturn" => "\x{23CE}",  // return symbol
    "trapezium" => "\x{23e2}",  // white trapezium
    "benzenr" => "\x{23e3}",  // benzene ring with circle
    "strns" => "\x{23e4}",  // straightness
    "fltns" => "\x{23e5}",  // flatness
    "accurrent" => "\x{23e6}",  // ac current
    "elinters" => "\x{23e7}",  // electrical intersection
    "blanksymbol" => "\x{2422}",  // blank symbol
    "blockuphalf" => "\x{2580}",  // upper half block
    "blocklowhalf" => "\x{2584}",  // lower half block
    "blockfull" => "\x{2588}",  // full block
    "blocklefthalf" => "\x{258C}",  // left half block
    "blockrighthalf" => "\x{2590}",  // right half block
    "blockqtrshaded" => "\x{2591}",  // 25\% shaded block
    "blockhalfshaded" => "\x{2592}",  // 50\% shaded block
    "blockthreeqtrshaded" => "\x{2593}",  // 75\% shaded block
    "squoval" => "\x{25A2}",  // white square with rounded corners
    "blackinwhitesquare" => "\x{25A3}",  // white square containing black small square
    "squarehfill" => "\x{25A4}",  // square, horizontal rule filled
    "squarevfill" => "\x{25A5}",  // square, vertical rule filled
    "squarehvfill" => "\x{25A6}",  // square with orthogonal crosshatch fill
    "squarenwsefill" => "\x{25A7}",  // square, nw-to-se rule filled
    "squareneswfill" => "\x{25A8}",  // square, ne-to-sw rule filled
    "squarecrossfill" => "\x{25A9}",  // square with diagonal crosshatch fill
    "smblksquare" => "\x{25AA}",  // /blacksquare - sq bullet, filled
    "smwhtsquare" => "\x{25AB}",  // white small square
    "hrectangleblack" => "\x{25AC}",  // black rectangle
    "hrectangle" => "\x{25AD}",  // horizontal rectangle, open
    "vrectangleblack" => "\x{25AE}",  // black vertical rectangle
    "parallelogramblack" => "\x{25B0}",  // black parallelogram
    "parallelogram" => "\x{25B1}",  // parallelogram, open
    "bigblacktriangleup" => "\x{25B2}",  //    0x25b2 6 6d      black up-pointing triangle
    "blacktriangleright" => "\x{25B6}",  // (large) right triangle, filled
    "blackpointerright" => "\x{25BA}",  // black right-pointing pointer
    "whitepointerright" => "\x{25BB}",  // white right-pointing pointer
    "bigblacktriangledown" => "\x{25BC}",  // big down triangle, filled
    "blacktriangleleft" => "\x{25C0}",  // (large) left triangle, filled
    "blackpointerleft" => "\x{25C4}",  // black left-pointing pointer
    "whitepointerleft" => "\x{25C5}",  // white left-pointing pointer
    "mdlgblkdiamond" => "\x{25C6}",  // black diamond
    "mdlgwhtdiamond" => "\x{25C7}",  // white diamond; diamond, open
    "blackinwhitediamond" => "\x{25C8}",  // white diamond containing black small diamond
    "fisheye" => "\x{25C9}",  // fisheye
    "dottedcircle" => "\x{25CC}",  // dotted circle
    "circlevertfill" => "\x{25CD}",  // circle with vertical fill
    "bullseye" => "\x{25CE}",  // bullseye
    "mdlgblkcircle" => "\x{25CF}",  // circle, filled
    "circletophalfblack" => "\x{25D3}",  // circle, filled top half
    "circleurquadblack" => "\x{25D4}",  // circle with upper right quadrant black
    "blackcircleulquadwhite" => "\x{25D5}",  // circle with all but upper left quadrant black
    "blacklefthalfcircle" => "\x{25D6}",  // left half black circle
    "blackrighthalfcircle" => "\x{25D7}",  // right half black circle
    "inversewhitecircle" => "\x{25D9}",  // inverse white circle
    "invwhiteupperhalfcircle" => "\x{25DA}",  // upper half inverse white circle
    "invwhitelowerhalfcircle" => "\x{25DB}",  // lower half inverse white circle
    "ularc" => "\x{25DC}",  // upper left quadrant circular arc
    "urarc" => "\x{25DD}",  // upper right quadrant circular arc
    "lrarc" => "\x{25DE}",  // lower right quadrant circular arc
    "llarc" => "\x{25DF}",  // lower left quadrant circular arc
    "topsemicircle" => "\x{25E0}",  // upper half circle
    "botsemicircle" => "\x{25E1}",  // lower half circle
    "lrblacktriangle" => "\x{25E2}",  // lower right triangle, filled
    "llblacktriangle" => "\x{25E3}",  // lower left triangle, filled
    "ulblacktriangle" => "\x{25E4}",  // upper left triangle, filled
    "urblacktriangle" => "\x{25E5}",  // upper right triangle, filled
    "smwhtcircle" => "\x{25E6}",  // white bullet
    "squareulblack" => "\x{25E9}",  // square, filled top left corner
    "boxbar" => "\x{25EB}",  // vertical bar in box
    "trianglecdot" => "\x{25EC}",  // triangle with centered dot
    "triangleleftblack" => "\x{25ED}",  // up-pointing triangle with left half black
    "trianglerightblack" => "\x{25EE}",  // up-pointing triangle with right half black
    "lgwhtcircle" => "\x{25EF}",  // large circle
    "squareulquad" => "\x{25F0}",  // white square with upper left quadrant
    "squarellquad" => "\x{25F1}",  // white square with lower left quadrant
    "squarelrquad" => "\x{25F2}",  // white square with lower right quadrant
    "squareurquad" => "\x{25F3}",  // white square with upper right quadrant
    "circleulquad" => "\x{25F4}",  // white circle with upper left quadrant
    "circlellquad" => "\x{25F5}",  // white circle with lower left quadrant
    "circlelrquad" => "\x{25F6}",  // white circle with lower right quadrant
    "circleurquad" => "\x{25F7}",  // white circle with upper right quadrant
    "ultriangle" => "\x{25F8}",  // upper left triangle
    "urtriangle" => "\x{25F9}",  // upper right triangle
    "lltriangle" => "\x{25FA}",  // lower left triangle
    "mdwhtsquare" => "\x{25FB}",  // white medium square
    "mdblksquare" => "\x{25FC}",  // black medium square
    "mdsmwhtsquare" => "\x{25FD}",  // white medium small square
    "mdsmblksquare" => "\x{25FE}",  // black medium small square
    "lrtriangle" => "\x{25FF}",  // lower right triangle
    "bigwhitestar" => "\x{2606}",  // star, open
    "astrosun" => "\x{2609}",  // sun
    "danger" => "\x{2621}",  // dangerous bend (caution sign)
    "blacksmiley" => "\x{263B}",  // black smiling face
    "sun" => "\x{263C}",  // white sun with rays
    "rightmoon" => "\x{263D}",  // first quarter moon
    "varspadesuit" => "\x{2664}",  // spade, white (card suit)
    "varheartsuit" => "\x{2665}",  // filled heart (card suit)
    "vardiamondsuit" => "\x{2666}",  // filled diamond (card suit)
    "varclubsuit" => "\x{2667}",  // club, white (card suit)
    "twonotes" => "\x{266B}",  // beamed eighth notes
    "acidfree" => "\x{267e}",  // permanent paper sign
    "dicei" => "\x{2680}",  // die face-1
    "diceii" => "\x{2681}",  // die face-2
    "diceiii" => "\x{2682}",  // die face-3
    "diceiv" => "\x{2683}",  // die face-4
    "dicev" => "\x{2684}",  // die face-5
    "dicevi" => "\x{2685}",  // die face-6
    "circledrightdot" => "\x{2686}",  // white circle with dot right
    "circledtwodots" => "\x{2687}",  // white circle with two dots
    "blackcircledrightdot" => "\x{2688}",  // black circle with white dot right
    "blackcircledtwodots" => "\x{2689}",  // black circle with two white dots
    "hermaphrodite" => "\x{26a5}",  // male and female sign
    "mdwhtcircle" => "\x{26aa}",  // medium white circle
    "mdblkcircle" => "\x{26ab}",  // medium black circle
    "mdsmwhtcircle" => "\x{26ac}",  // medium small white circle
    "neuter" => "\x{26b2}",  // neuter
    "circledstar" => "\x{272A}",  // circled white star
    "varstar" => "\x{2736}",  // six pointed black star
    "dingasterisk" => "\x{273D}",  // heavy teardrop-spoked asterisk
    "draftingarrow" => "\x{279B}",  // right arrow with bold head (drafting)
    "threedangle" => "\x{27c0}",  // three dimensional angle
    "whiteinwhitetriangle" => "\x{27c1}",  // white triangle containing small white triangle
    "perp" => "\x{27c2}",  // perpendicular
    "bsolhsub" => "\x{27c8}",  // reverse solidus preceding subset
    "suphsol" => "\x{27c9}",  // superset preceding solidus
    "wedgedot" => "\x{27D1}",  // and with dot
    "upin" => "\x{27D2}",  // element of opening upwards
    "bigbot" => "\x{27D8}",  // large up tack
    "bigtop" => "\x{27D9}",  // large down tack
    "UUparrow" => "\x{27F0}",  // upwards quadruple arrow
    "DDownarrow" => "\x{27F1}",  // downwards quadruple arrow
    "longmapsfrom" => "\x{27FB}",  // long leftwards arrow from bar
    "Longmapsfrom" => "\x{27FD}",  // long leftwards double arrow from bar
    "Longmapsto" => "\x{27FE}",  // long rightwards double arrow from bar
    "longrightsquigarrow" => "\x{27FF}",  // long rightwards squiggle arrow
    "nvtwoheadrightarrow" => "\x{2900}",  // rightwards two-headed arrow with vertical stroke
    "nVtwoheadrightarrow" => "\x{2901}",  // rightwards two-headed arrow with double vertical stroke
    "nvLeftarrow" => "\x{2902}",  // leftwards double arrow with vertical stroke
    "nvRightarrow" => "\x{2903}",  // rightwards double arrow with vertical stroke
    "nvLeftrightarrow" => "\x{2904}",  // left right double arrow with vertical stroke
    "twoheadmapsto" => "\x{2905}",  // rightwards two-headed arrow from bar
    "downarrowbarred" => "\x{2908}",  // downwards arrow with horizontal stroke
    "uparrowbarred" => "\x{2909}",  // upwards arrow with horizontal stroke
    "leftbkarrow" => "\x{290C}",  // leftwards double dash arrow
    "leftdbkarrow" => "\x{290E}",  // leftwards triple dash arrow
    "rightdotarrow" => "\x{2911}",  // rightwards arrow with dotted stem
    "nvrightarrowtail" => "\x{2914}",  // rightwards arrow with tail with vertical stroke
    "nVrightarrowtail" => "\x{2915}",  // rightwards arrow with tail with double vertical stroke
    "nvtwoheadrightarrowtail" => "\x{2917}",  // rightwards two-headed arrow with tail with vertical stroke
    "nVtwoheadrightarrowtail" => "\x{2918}",  // rightwards two-headed arrow with tail with double vertical stroke
    "diamondleftarrow" => "\x{291D}",  // leftwards arrow to black diamond
    "rightarrowdiamond" => "\x{291E}",  // rightwards arrow to black diamond
    "diamondleftarrowbar" => "\x{291F}",  // leftwards arrow from bar to black diamond
    "barrightarrowdiamond" => "\x{2920}",  // rightwards arrow from bar to black diamond
    "rightarrowplus" => "\x{2945}",  // rightwards arrow with plus below
    "leftarrowplus" => "\x{2946}",  // leftwards arrow with plus below
    "leftrightarrowcircle" => "\x{2948}",  // left right arrow through small circle
    "twoheaduparrowcircle" => "\x{2949}",  // upwards two-headed arrow from small circle
    "leftrightharpoonupdown" => "\x{294A}",  // left barb up right barb down harpoon
    "leftrightharpoondownup" => "\x{294B}",  // left barb down right barb up harpoon
    "updownharpoonrightleft" => "\x{294C}",  // up barb right down barb left harpoon
    "updownharpoonleftright" => "\x{294D}",  // up barb left down barb right harpoon
    "leftharpoonsupdown" => "\x{2962}",  // leftwards harpoon with barb up above leftwards harpoon with barb down
    "upharpoonsleftright" => "\x{2963}",  // upwards harpoon with barb left beside upwards harpoon with barb right
    "rightharpoonsupdown" => "\x{2964}",  // rightwards harpoon with barb up above rightwards harpoon with barb down
    "downharpoonsleftright" => "\x{2965}",  // downwards harpoon with barb left beside downwards harpoon with barb right
    "leftrightharpoonsup" => "\x{2966}",  // leftwards harpoon with barb up above rightwards harpoon with barb up
    "leftrightharpoonsdown" => "\x{2967}",  // leftwards harpoon with barb down above rightwards harpoon with barb down
    "rightleftharpoonsup" => "\x{2968}",  // rightwards harpoon with barb up above leftwards harpoon with barb up
    "rightleftharpoonsdown" => "\x{2969}",  // rightwards harpoon with barb down above leftwards harpoon with barb down
    "leftharpoonupdash" => "\x{296A}",  // leftwards harpoon with barb up above long dash
    "dashleftharpoondown" => "\x{296B}",  // leftwards harpoon with barb down below long dash
    "rightharpoonupdash" => "\x{296C}",  // rightwards harpoon with barb up above long dash
    "dashrightharpoondown" => "\x{296D}",  // rightwards harpoon with barb down below long dash
    "measuredangleleft" => "\x{299B}",  // measured angle opening left
    "rightanglemdot" => "\x{299D}",  // measured right angle with dot
    "angles" => "\x{299E}",  // angle with s inside
    "angdnr" => "\x{299F}",  // acute angle
    "sphericalangleup" => "\x{29A1}",  // spherical angle opening up
    "turnangle" => "\x{29A2}",  // turned angle
    "revangle" => "\x{29A3}",  // reversed angle
    "angleubar" => "\x{29A4}",  // angle with underbar
    "revangleubar" => "\x{29A5}",  // reversed angle with underbar
    "wideangledown" => "\x{29A6}",  // oblique angle opening up
    "wideangleup" => "\x{29A7}",  // oblique angle opening down
    "measanglerutone" => "\x{29A8}",  // measured angle with open arm ending in arrow pointing up and right
    "measanglelutonw" => "\x{29A9}",  // measured angle with open arm ending in arrow pointing up and left
    "measanglerdtose" => "\x{29AA}",  // measured angle with open arm ending in arrow pointing down and right
    "measangleldtosw" => "\x{29AB}",  // measured angle with open arm ending in arrow pointing down and left
    "measangleurtone" => "\x{29AC}",  // measured angle with open arm ending in arrow pointing right and up
    "measangleultonw" => "\x{29AD}",  // measured angle with open arm ending in arrow pointing left and up
    "measangledrtose" => "\x{29AE}",  // measured angle with open arm ending in arrow pointing right and down
    "measangledltosw" => "\x{29AF}",  // measured angle with open arm ending in arrow pointing left and down
    "revemptyset" => "\x{29B0}",  // reversed empty set
    "emptysetobar" => "\x{29B1}",  // empty set with overbar
    "emptysetocirc" => "\x{29B2}",  // empty set with small circle above
    "emptysetoarr" => "\x{29B3}",  // empty set with right arrow above
    "emptysetoarrl" => "\x{29B4}",  // empty set with left arrow above
    "circledparallel" => "\x{29B7}",  // circled parallel
    "odotslashdot" => "\x{29BC}",  // circled anticlockwise-rotated division sign
    "circledwhitebullet" => "\x{29BE}",  // circled white bullet
    "circledbullet" => "\x{29BF}",  // circled bullet
    "olessthan" => "\x{29C0}",  // circled less-than
    "ogreaterthan" => "\x{29C1}",  // circled greater-than
    "lrtriangleeq" => "\x{29E1}",  // increases as
    "eparsl" => "\x{29E3}",  // equals sign and slanted parallel
    "smeparsl" => "\x{29E4}",  // equals sign and slanted parallel with tilde above
    "eqvparsl" => "\x{29E5}",  // identical to and slanted parallel
    "dsol" => "\x{29F6}",  // solidus with overbar
    "rsolbar" => "\x{29F7}",  // reverse solidus with horizontal stroke
    "doubleplus" => "\x{29FA}",  // double plus
    "tripleplus" => "\x{29FB}",  // triple plus
    "modtwosum" => "\x{2A0A}",  // modulo two sum
    "sumint" => "\x{2A0B}",  // summation with integral
    "cirfnint" => "\x{2A10}",  // circulation function
    "awint" => "\x{2A11}",  // anticlockwise integration
    "rppolint" => "\x{2A12}",  // line integration with rectangular path around pole
    "scpolint" => "\x{2A13}",  // line integration with semicircular path around pole
    "npolint" => "\x{2A14}",  // line integration not including the pole
    "pointint" => "\x{2A15}",  // integral around a point operator
    "ringplus" => "\x{2A22}",  // plus sign with small circle above
    "plushat" => "\x{2A23}",  // plus sign with circumflex accent above
    "simplus" => "\x{2A24}",  // plus sign with tilde above
    "plussim" => "\x{2A26}",  // plus sign with tilde below
    "plussubtwo" => "\x{2A27}",  // plus sign with subscript two
    "plustrif" => "\x{2A28}",  // plus sign with black triangle
    "commaminus" => "\x{2A29}",  // minus sign with comma above
    "minusfdots" => "\x{2A2B}",  // minus sign with falling dots
    "minusrdots" => "\x{2A2C}",  // minus sign with rising dots
    "opluslhrim" => "\x{2A2D}",  // plus sign in left half circle
    "oplusrhrim" => "\x{2A2E}",  // plus sign in right half circle
    "dottimes" => "\x{2A30}",  // multiplication sign with dot above
    "timesbar" => "\x{2A31}",  // multiplication sign with underbar
    "smashtimes" => "\x{2A33}",  // smash product
    "otimeslhrim" => "\x{2A34}",  // multiplication sign in left half circle
    "otimesrhrim" => "\x{2A35}",  // multiplication sign in right half circle
    "otimeshat" => "\x{2A36}",  // circled multiplication sign with circumflex accent
    "Otimes" => "\x{2A37}",  // multiplication sign in double circle
    "odiv" => "\x{2A38}",  // circled division sign
    "triangleplus" => "\x{2A39}",  // plus sign in triangle
    "triangleminus" => "\x{2A3A}",  // minus sign in triangle
    "triangletimes" => "\x{2A3B}",  // multiplication sign in triangle
    "capdot" => "\x{2A40}",  // intersection with dot
    "uminus" => "\x{2A41}",  // union with minus sign
    "barcup" => "\x{2A42}",  // union with overbar
    "barcap" => "\x{2A43}",  // intersection with overbar
    "capwedge" => "\x{2A44}",  // intersection with logical and
    "cupvee" => "\x{2A45}",  // union with logical or
    "twocups" => "\x{2A4A}",  // union beside and joined with union
    "twocaps" => "\x{2A4B}",  // intersection beside and joined with intersection
    "closedvarcup" => "\x{2A4C}",  // closed union with serifs
    "closedvarcap" => "\x{2A4D}",  // closed intersection with serifs
    "Sqcap" => "\x{2A4E}",  // double square intersection
    "Sqcup" => "\x{2A4F}",  // double square union
    "closedvarcupsmashprod" => "\x{2A50}",  // closed union with serifs and smash product
    "wedgeodot" => "\x{2A51}",  // logical and with dot above
    "veeodot" => "\x{2A52}",  // logical or with dot above
    "wedgeonwedge" => "\x{2A55}",  // two intersecting logical and
    "bigslopedvee" => "\x{2A57}",  // sloping large or
    "bigslopedwedge" => "\x{2A58}",  // sloping large and
    "wedgemidvert" => "\x{2A5A}",  // logical and with middle stem
    "veemidvert" => "\x{2A5B}",  // logical or with middle stem
    "midbarwedge" => "\x{2A5C}",  // ogical and with horizontal dash
    "midbarvee" => "\x{2A5D}",  // logical or with horizontal dash
    "wedgedoublebar" => "\x{2A60}",  // logical and with double underbar
    "varveebar" => "\x{2A61}",  // small vee with underbar
    "doublebarvee" => "\x{2A62}",  // logical or with double overbar
    "veedoublebar" => "\x{2A63}",  // logical or with double underbar
    "eqdot" => "\x{2A66}",  // equals sign with dot below
    "dotequiv" => "\x{2A67}",  // identical with dot above
    "dotsim" => "\x{2A6A}",  // tilde operator with dot above
    "simrdots" => "\x{2A6B}",  // tilde operator with rising dots
    "simminussim" => "\x{2A6C}",  // similar minus similar
    "congdot" => "\x{2A6D}",  // congruent with dot above
    "asteq" => "\x{2A6E}",  // equals with asterisk
    "hatapprox" => "\x{2A6F}",  // almost equal to with circumflex accent
    "approxeqq" => "\x{2A70}",  // approximately equal or equal to
    "eqqplus" => "\x{2A71}",  // equals sign above plus sign
    "pluseqq" => "\x{2A72}",  // plus sign above equals sign
    "eqqsim" => "\x{2A73}",  // equals sign above tilde operator
    "Coloneq" => "\x{2A74}",  // double colon equal
    "eqeqeq" => "\x{2A76}",  // three consecutive equals signs
    "equivDD" => "\x{2A78}",  // equivalent with four dots above
    "ltcir" => "\x{2A79}",  // less-than with circle inside
    "gtcir" => "\x{2A7A}",  // greater-than with circle inside
    "ltquest" => "\x{2A7B}",  // less-than with question mark above
    "gtquest" => "\x{2A7C}",  // greater-than with question mark above
    "lesdot" => "\x{2A7F}",  // less-than or slanted equal to with dot inside
    "gesdot" => "\x{2A80}",  // greater-than or slanted equal to with dot inside
    "lesdoto" => "\x{2A81}",  // less-than or slanted equal to with dot above
    "gesdoto" => "\x{2A82}",  // greater-than or slanted equal to with dot above
    "lesdotor" => "\x{2A83}",  // less-than or slanted equal to with dot above right
    "gesdotol" => "\x{2A84}",  // greater-than or slanted equal to with dot above left
    "lsime" => "\x{2A8D}",  // less-than above similar or equal
    "gsime" => "\x{2A8E}",  // greater-than above similar or equal
    "lsimg" => "\x{2A8F}",  // less-than above similar above greater-than
    "gsiml" => "\x{2A90}",  // greater-than above similar above less-than
    "lgE" => "\x{2A91}",  // less-than above greater-than above double-line equal
    "glE" => "\x{2A92}",  // greater-than above less-than above double-line equal
    "lesges" => "\x{2A93}",  // less-than above slanted equal above greater-than above slanted equal
    "gesles" => "\x{2A94}",  // greater-than above slanted equal above less-than above slanted equal
    "elsdot" => "\x{2A97}",  // slanted equal to or less-than with dot inside
    "egsdot" => "\x{2A98}",  // slanted equal to or greater-than with dot inside
    "eqqless" => "\x{2A99}",  // double-line equal to or less-than
    "eqqgtr" => "\x{2A9A}",  // double-line equal to or greater-than
    "eqqslantless" => "\x{2A9B}",  // double-line slanted equal to or less-than
    "eqqslantgtr" => "\x{2A9C}",  // double-line slanted equal to or greater-than
    "simless" => "\x{2A9D}",  // similar or less-than
    "simgtr" => "\x{2A9E}",  // similar or greater-than
    "simlE" => "\x{2A9F}",  // similar above less-than above equals sign
    "simgE" => "\x{2AA0}",  // similar above greater-than above equals sign
    "glj" => "\x{2AA4}",  // greater-than overlapping less-than
    "gla" => "\x{2AA5}",  // greater-than beside less-than
    "ltcc" => "\x{2AA6}",  // less-than closed by curve
    "gtcc" => "\x{2AA7}",  // greater-than closed by curve
    "lescc" => "\x{2AA8}",  // less-than closed by curve above slanted equal
    "gescc" => "\x{2AA9}",  // greater-than closed by curve above slanted equal
    "smt" => "\x{2AAA}",  // smaller than
    "lat" => "\x{2AAB}",  // larger than
    "smte" => "\x{2AAC}",  // smaller than or equal to
    "late" => "\x{2AAD}",  // larger than or equal to
    "precneq" => "\x{2AB1}",  // precedes above single-line not equal to
    "succneq" => "\x{2AB2}",  // succeeds above single-line not equal to
    "preceqq" => "\x{2AB3}",  // precedes above equals sign
    "succeqq" => "\x{2AB4}",  // succeeds above equals sign
    "Prec" => "\x{2ABB}",  // double precedes
    "Succ" => "\x{2ABC}",  // double succeeds
    "subsetdot" => "\x{2ABD}",  // subset with dot
    "supsetdot" => "\x{2ABE}",  // superset with dot
    "subsetplus" => "\x{2ABF}",  // subset with plus sign below
    "supsetplus" => "\x{2AC0}",  // superset with plus sign below
    "submult" => "\x{2AC1}",  // subset with multiplication sign below
    "supmult" => "\x{2AC2}",  // superset with multiplication sign below
    "subedot" => "\x{2AC3}",  // subset of or equal to with dot above
    "supedot" => "\x{2AC4}",  // superset of or equal to with dot above
    "subsim" => "\x{2AC7}",  // subset of above tilde operator
    "supsim" => "\x{2AC8}",  // superset of above tilde operator
    "subsetapprox" => "\x{2AC9}",  // subset of above almost equal to
    "supsetapprox" => "\x{2ACA}",  // superset of above almost equal to
    "lsqhook" => "\x{2ACD}",  // square left open box operator
    "rsqhook" => "\x{2ACE}",  // square right open box operator
    "csub" => "\x{2ACF}",  // closed subset
    "csup" => "\x{2AD0}",  // closed superset
    "csube" => "\x{2AD1}",  // closed subset or equal to
    "csupe" => "\x{2AD2}",  // closed superset or equal to
    "subsup" => "\x{2AD3}",  // subset above superset
    "supsub" => "\x{2AD4}",  // superset above subset
    "subsub" => "\x{2AD5}",  // subset above subset
    "supsup" => "\x{2AD6}",  // superset above superset
    "suphsub" => "\x{2AD7}",  // superset beside subset
    "supdsub" => "\x{2AD8}",  // superset beside and joined by dash with subset
    "forkv" => "\x{2AD9}",  // element of opening downwards
    "lllnest" => "\x{2AF7}",  // stacked very much less-than
    "gggnest" => "\x{2AF8}",  // stacked very much greater-than
    "leqqslant" => "\x{2AF9}",  // double-line slanted less-than or equal to
    "geqqslant" => "\x{2AFA}",  // double-line slanted greater-than or equal to
    "squaretopblack" => "\x{2b12}",  // square with top half black
    "squarebotblack" => "\x{2b13}",  // square with bottom half black
    "squareurblack" => "\x{2b14}",  // square with upper right diagonal half black
    "squarellblack" => "\x{2b15}",  // square with lower left diagonal half black
    "diamondleftblack" => "\x{2b16}",  // diamond with left half black
    "diamondrightblack" => "\x{2b17}",  // diamond with right half black
    "diamondtopblack" => "\x{2b18}",  // diamond with top half black
    "diamondbotblack" => "\x{2b19}",  // diamond with bottom half black
    "dottedsquare" => "\x{2b1a}",  // dotted square
    "lgblksquare" => "\x{2b1b}",  // black large square
    "lgwhtsquare" => "\x{2b1c}",  // white large square
    "vysmblksquare" => "\x{2b1d}",  // black very small square
    "vysmwhtsquare" => "\x{2b1e}",  // white very small square
    "pentagonblack" => "\x{2b1f}",  // black pentagon
    "pentagon" => "\x{2b20}",  // white pentagon
    "varhexagon" => "\x{2b21}",  // white hexagon
    "varhexagonblack" => "\x{2b22}",  // black hexagon
    "hexagonblack" => "\x{2b23}",  // horizontal black hexagon
    "lgblkcircle" => "\x{2b24}",  // black large circle
    "mdblkdiamond" => "\x{2b25}",  // black medium diamond
    "mdwhtdiamond" => "\x{2b26}",  // white medium diamond
    "mdblklozenge" => "\x{2b27}",  // black medium lozenge
    "mdwhtlozenge" => "\x{2b28}",  // white medium lozenge
    "smblkdiamond" => "\x{2b29}",  // black small diamond
    "smblklozenge" => "\x{2b2a}",  // black small lozenge
    "smwhtlozenge" => "\x{2b2b}",  // white small lozenge
    "blkhorzoval" => "\x{2b2c}",  // black horizontal ellipse
    "whthorzoval" => "\x{2b2d}",  // white horizontal ellipse
    "blkvertoval" => "\x{2b2e}",  // black vertical ellipse
    "whtvertoval" => "\x{2b2f}",  // white vertical ellipse
    "circleonleftarrow" => "\x{2b30}",  // left arrow with small circle
    "leftthreearrows" => "\x{2b31}",  // three leftwards arrows
    "leftarrowonoplus" => "\x{2b32}",  // left arrow with circled plus
    "longleftsquigarrow" => "\x{2b33}",  // long leftwards squiggle arrow
    "nvtwoheadleftarrow" => "\x{2b34}",  // leftwards two-headed arrow with vertical stroke
    "nVtwoheadleftarrow" => "\x{2b35}",  // leftwards two-headed arrow with double vertical stroke
    "twoheadmapsfrom" => "\x{2b36}",  // leftwards two-headed arrow from bar
    "twoheadleftdbkarrow" => "\x{2b37}",  // leftwards two-headed triple-dash arrow
    "leftdotarrow" => "\x{2b38}",  // leftwards arrow with dotted stem
    "nvleftarrowtail" => "\x{2b39}",  // leftwards arrow with tail with vertical stroke
    "nVleftarrowtail" => "\x{2b3a}",  // leftwards arrow with tail with double vertical stroke
    "twoheadleftarrowtail" => "\x{2b3b}",  // leftwards two-headed arrow with tail
    "nvtwoheadleftarrowtail" => "\x{2b3c}",  // leftwards two-headed arrow with tail with vertical stroke
    "nVtwoheadleftarrowtail" => "\x{2b3d}",  // leftwards two-headed arrow with tail with double vertical stroke
    "leftarrowx" => "\x{2b3e}",  // leftwards arrow through x
    "leftcurvedarrow" => "\x{2b3f}",  // wave arrow pointing directly left
    "equalleftarrow" => "\x{2b40}",  // equals sign above leftwards arrow
    "bsimilarleftarrow" => "\x{2b41}",  // reverse tilde operator above leftwards arrow
    "leftarrowbackapprox" => "\x{2b42}",  // leftwards arrow above reverse almost equal to
    "rightarrowgtr" => "\x{2b43}",  // rightwards arrow through greater-than
    "rightarrowsupset" => "\x{2b44}",  // rightwards arrow through subset
    "LLeftarrow" => "\x{2b45}",  // leftwards quadruple arrow
    "RRightarrow" => "\x{2b46}",  // rightwards quadruple arrow
    "bsimilarrightarrow" => "\x{2b47}",  // reverse tilde operator above rightwards arrow
    "rightarrowbackapprox" => "\x{2b48}",  // rightwards arrow above reverse almost equal to
    "similarleftarrow" => "\x{2b49}",  // tilde operator above leftwards arrow
    "leftarrowapprox" => "\x{2b4a}",  // leftwards arrow above almost equal to
    "leftarrowbsimilar" => "\x{2b4b}",  // leftwards arrow above reverse tilde operator
    "rightarrowbsimilar" => "\x{2b4c}",  // righttwards arrow above reverse tilde operator
    "medwhitestar" => "\x{2b50}",  // white medium star
    "medblackstar" => "\x{2b51}",  // black medium star
    "smwhitestar" => "\x{2b52}",  // white small star
    "rightpentagonblack" => "\x{2b53}",  // black right-pointing pentagon
    "rightpentagon" => "\x{2b54}",  // white right-pointing pentagon
    "postalmark" => "\x{3012}",  // postal mark
    "boldA" => "\x{1D400}",  // mathematical bold capital a
    "boldB" => "\x{1D401}",  // mathematical bold capital b
    "boldC" => "\x{1D402}",  // mathematical bold capital c
    "boldD" => "\x{1D403}",  // mathematical bold capital d
    "boldE" => "\x{1D404}",  // mathematical bold capital e
    "boldF" => "\x{1D405}",  // mathematical bold capital f
    "boldG" => "\x{1D406}",  // mathematical bold capital g
    "boldH" => "\x{1D407}",  // mathematical bold capital h
    "boldI" => "\x{1D408}",  // mathematical bold capital i
    "boldJ" => "\x{1D409}",  // mathematical bold capital j
    "boldK" => "\x{1D40A}",  // mathematical bold capital k
    "boldL" => "\x{1D40B}",  // mathematical bold capital l
    "boldM" => "\x{1D40C}",  // mathematical bold capital m
    "boldN" => "\x{1D40D}",  // mathematical bold capital n
    "boldO" => "\x{1D40E}",  // mathematical bold capital o
    "boldP" => "\x{1D40F}",  // mathematical bold capital p
    "boldQ" => "\x{1D410}",  // mathematical bold capital q
    "boldR" => "\x{1D411}",  // mathematical bold capital r
    "boldS" => "\x{1D412}",  // mathematical bold capital s
    "boldT" => "\x{1D413}",  // mathematical bold capital t
    "boldU" => "\x{1D414}",  // mathematical bold capital u
    "boldV" => "\x{1D415}",  // mathematical bold capital v
    "boldW" => "\x{1D416}",  // mathematical bold capital w
    "boldX" => "\x{1D417}",  // mathematical bold capital x
    "boldY" => "\x{1D418}",  // mathematical bold capital y
    "boldZ" => "\x{1D419}",  // mathematical bold capital z
    "bolda" => "\x{1D41A}",  // mathematical bold small a
    "boldb" => "\x{1D41B}",  // mathematical bold small b
    "boldc" => "\x{1D41C}",  // mathematical bold small c
    "boldd" => "\x{1D41D}",  // mathematical bold small d
    "bolde" => "\x{1D41E}",  // mathematical bold small e
    "boldf" => "\x{1D41F}",  // mathematical bold small f
    "boldg" => "\x{1D420}",  // mathematical bold small g
    "boldh" => "\x{1D421}",  // mathematical bold small h
    "boldi" => "\x{1D422}",  // mathematical bold small i
    "boldj" => "\x{1D423}",  // mathematical bold small j
    "boldk" => "\x{1D424}",  // mathematical bold small k
    "boldl" => "\x{1D425}",  // mathematical bold small l
    "boldm" => "\x{1D426}",  // mathematical bold small m
    "boldn" => "\x{1D427}",  // mathematical bold small n
    "boldo" => "\x{1D428}",  // mathematical bold small o
    "boldp" => "\x{1D429}",  // mathematical bold small p
    "boldq" => "\x{1D42A}",  // mathematical bold small q
    "boldr" => "\x{1D42B}",  // mathematical bold small r
    "bolds" => "\x{1D42C}",  // mathematical bold small s
    "boldt" => "\x{1D42D}",  // mathematical bold small t
    "boldu" => "\x{1D42E}",  // mathematical bold small u
    "boldv" => "\x{1D42F}",  // mathematical bold small v
    "boldw" => "\x{1D430}",  // mathematical bold small w
    "boldx" => "\x{1D431}",  // mathematical bold small x
    "boldy" => "\x{1D432}",  // mathematical bold small y
    "boldz" => "\x{1D433}",  // mathematical bold small z
    "itA" => "\x{1D434}",  // mathematical italic capital a
    "itB" => "\x{1D435}",  // mathematical italic capital b
    "itC" => "\x{1D436}",  // mathematical italic capital c
    "itD" => "\x{1D437}",  // mathematical italic capital d
    "itE" => "\x{1D438}",  // mathematical italic capital e
    "itF" => "\x{1D439}",  // mathematical italic capital f
    "itG" => "\x{1D43A}",  // mathematical italic capital g
    "itH" => "\x{1D43B}",  // mathematical italic capital h
    "itI" => "\x{1D43C}",  // mathematical italic capital i
    "itJ" => "\x{1D43D}",  // mathematical italic capital j
    "itK" => "\x{1D43E}",  // mathematical italic capital k
    "itL" => "\x{1D43F}",  // mathematical italic capital l
    "itM" => "\x{1D440}",  // mathematical italic capital m
    "itN" => "\x{1D441}",  // mathematical italic capital n
    "itO" => "\x{1D442}",  // mathematical italic capital o
    "itP" => "\x{1D443}",  // mathematical italic capital p
    "itQ" => "\x{1D444}",  // mathematical italic capital q
    "itR" => "\x{1D445}",  // mathematical italic capital r
    "itS" => "\x{1D446}",  // mathematical italic capital s
    "itT" => "\x{1D447}",  // mathematical italic capital t
    "itU" => "\x{1D448}",  // mathematical italic capital u
    "itV" => "\x{1D449}",  // mathematical italic capital v
    "itW" => "\x{1D44A}",  // mathematical italic capital w
    "itX" => "\x{1D44B}",  // mathematical italic capital x
    "itY" => "\x{1D44C}",  // mathematical italic capital y
    "itZ" => "\x{1D44D}",  // mathematical italic capital z
    "ita" => "\x{1D44E}",  // mathematical italic small a
    "itb" => "\x{1D44F}",  // mathematical italic small b
    "itc" => "\x{1D450}",  // mathematical italic small c
    "itd" => "\x{1D451}",  // mathematical italic small d
    "ite" => "\x{1D452}",  // mathematical italic small e
    "itf" => "\x{1D453}",  // mathematical italic small f
    "itg" => "\x{1D454}",  // mathematical italic small g
    "ith" => "\x{210E}",  // mathematical italic small h (planck constant)
    "iti" => "\x{1D456}",  // mathematical italic small i
    "itj" => "\x{1D457}",  // mathematical italic small j
    "itk" => "\x{1D458}",  // mathematical italic small k
    "itl" => "\x{1D459}",  // mathematical italic small l
    "itm" => "\x{1D45A}",  // mathematical italic small m
    "itn" => "\x{1D45B}",  // mathematical italic small n
    "ito" => "\x{1D45C}",  // mathematical italic small o
    "itp" => "\x{1D45D}",  // mathematical italic small p
    "itq" => "\x{1D45E}",  // mathematical italic small q
    "itr" => "\x{1D45F}",  // mathematical italic small r
    "its" => "\x{1D460}",  // mathematical italic small s
    "itt" => "\x{1D461}",  // mathematical italic small t
    "itu" => "\x{1D462}",  // mathematical italic small u
    "itv" => "\x{1D463}",  // mathematical italic small v
    "itw" => "\x{1D464}",  // mathematical italic small w
    "itx" => "\x{1D465}",  // mathematical italic small x
    "ity" => "\x{1D466}",  // mathematical italic small y
    "itz" => "\x{1D467}",  // mathematical italic small z
    "bolditA" => "\x{1D468}",  // mathematical bold italic capital a
    "bolditB" => "\x{1D469}",  // mathematical bold italic capital b
    "bolditC" => "\x{1D46A}",  // mathematical bold italic capital c
    "bolditD" => "\x{1D46B}",  // mathematical bold italic capital d
    "bolditE" => "\x{1D46C}",  // mathematical bold italic capital e
    "bolditF" => "\x{1D46D}",  // mathematical bold italic capital f
    "bolditG" => "\x{1D46E}",  // mathematical bold italic capital g
    "bolditH" => "\x{1D46F}",  // mathematical bold italic capital h
    "bolditI" => "\x{1D470}",  // mathematical bold italic capital i
    "bolditJ" => "\x{1D471}",  // mathematical bold italic capital j
    "bolditK" => "\x{1D472}",  // mathematical bold italic capital k
    "bolditL" => "\x{1D473}",  // mathematical bold italic capital l
    "bolditM" => "\x{1D474}",  // mathematical bold italic capital m
    "bolditN" => "\x{1D475}",  // mathematical bold italic capital n
    "bolditO" => "\x{1D476}",  // mathematical bold italic capital o
    "bolditP" => "\x{1D477}",  // mathematical bold italic capital p
    "bolditQ" => "\x{1D478}",  // mathematical bold italic capital q
    "bolditR" => "\x{1D479}",  // mathematical bold italic capital r
    "bolditS" => "\x{1D47A}",  // mathematical bold italic capital s
    "bolditT" => "\x{1D47B}",  // mathematical bold italic capital t
    "bolditU" => "\x{1D47C}",  // mathematical bold italic capital u
    "bolditV" => "\x{1D47D}",  // mathematical bold italic capital v
    "bolditW" => "\x{1D47E}",  // mathematical bold italic capital w
    "bolditX" => "\x{1D47F}",  // mathematical bold italic capital x
    "bolditY" => "\x{1D480}",  // mathematical bold italic capital y
    "bolditZ" => "\x{1D481}",  // mathematical bold italic capital z
    "boldita" => "\x{1D482}",  // mathematical bold italic small a
    "bolditb" => "\x{1D483}",  // mathematical bold italic small b
    "bolditc" => "\x{1D484}",  // mathematical bold italic small c
    "bolditd" => "\x{1D485}",  // mathematical bold italic small d
    "boldite" => "\x{1D486}",  // mathematical bold italic small e
    "bolditf" => "\x{1D487}",  // mathematical bold italic small f
    "bolditg" => "\x{1D488}",  // mathematical bold italic small g
    "boldith" => "\x{1D489}",  // mathematical bold italic small h
    "bolditi" => "\x{1D48A}",  // mathematical bold italic small i
    "bolditj" => "\x{1D48B}",  // mathematical bold italic small j
    "bolditk" => "\x{1D48C}",  // mathematical bold italic small k
    "bolditl" => "\x{1D48D}",  // mathematical bold italic small l
    "bolditm" => "\x{1D48E}",  // mathematical bold italic small m
    "bolditn" => "\x{1D48F}",  // mathematical bold italic small n
    "boldito" => "\x{1D490}",  // mathematical bold italic small o
    "bolditp" => "\x{1D491}",  // mathematical bold italic small p
    "bolditq" => "\x{1D492}",  // mathematical bold italic small q
    "bolditr" => "\x{1D493}",  // mathematical bold italic small r
    "boldits" => "\x{1D494}",  // mathematical bold italic small s
    "bolditt" => "\x{1D495}",  // mathematical bold italic small t
    "bolditu" => "\x{1D496}",  // mathematical bold italic small u
    "bolditv" => "\x{1D497}",  // mathematical bold italic small v
    "bolditw" => "\x{1D498}",  // mathematical bold italic small w
    "bolditx" => "\x{1D499}",  // mathematical bold italic small x
    "boldity" => "\x{1D49A}",  // mathematical bold italic small y
    "bolditz" => "\x{1D49B}",  // mathematical bold italic small z
    "scrA" => "\x{1D49C}",  // mathematical script capital a
    "scrC" => "\x{1D49E}",  // mathematical script capital c
    "scrD" => "\x{1D49F}",  // mathematical script capital d
    "scrG" => "\x{1D4A2}",  // mathematical script capital g
    "scrJ" => "\x{1D4A5}",  // mathematical script capital j
    "scrK" => "\x{1D4A6}",  // mathematical script capital k
    "scrN" => "\x{1D4A9}",  // mathematical script capital n
    "scrO" => "\x{1D4AA}",  // mathematical script capital o
    "scrP" => "\x{1D4AB}",  // mathematical script capital p
    "scrQ" => "\x{1D4AC}",  // mathematical script capital q
    "scrS" => "\x{1D4AE}",  // mathematical script capital s
    "scrT" => "\x{1D4AF}",  // mathematical script capital t
    "scrU" => "\x{1D4B0}",  // mathematical script capital u
    "scrV" => "\x{1D4B1}",  // mathematical script capital v
    "scrW" => "\x{1D4B2}",  // mathematical script capital w
    "scrX" => "\x{1D4B3}",  // mathematical script capital x
    "scrY" => "\x{1D4B4}",  // mathematical script capital y
    "scrZ" => "\x{1D4B5}",  // mathematical script capital z
    "scra" => "\x{1D4B6}",  // mathematical script small a
    "scrb" => "\x{1D4B7}",  // mathematical script small b
    "scrc" => "\x{1D4B8}",  // mathematical script small c
    "scrd" => "\x{1D4B9}",  // mathematical script small d
    "scrf" => "\x{1D4BB}",  // mathematical script small f
    "scrh" => "\x{1D4BD}",  // mathematical script small h
    "scri" => "\x{1D4BE}",  // mathematical script small i
    "scrj" => "\x{1D4BF}",  // mathematical script small j
    "scrk" => "\x{1D4C0}",  // mathematical script small k
    "scrl" => "\x{1d4c1}",  // mathematical script small l
    "scrm" => "\x{1D4C2}",  // mathematical script small m
    "scrn" => "\x{1D4C3}",  // mathematical script small n
    "scrp" => "\x{1D4C5}",  // mathematical script small p
    "scrq" => "\x{1D4C6}",  // mathematical script small q
    "scrr" => "\x{1D4C7}",  // mathematical script small r
    "scrs" => "\x{1D4C8}",  // mathematical script small s
    "scrt" => "\x{1D4C9}",  // mathematical script small t
    "scru" => "\x{1D4CA}",  // mathematical script small u
    "scrv" => "\x{1D4CB}",  // mathematical script small v
    "scrw" => "\x{1D4CC}",  // mathematical script small w
    "scrx" => "\x{1D4CD}",  // mathematical script small x
    "scry" => "\x{1D4CE}",  // mathematical script small y
    "scrz" => "\x{1D4CF}",  // mathematical script small z
    "boldscrA" => "\x{1D4D0}",  // mathematical bold script capital a
    "boldscrB" => "\x{1D4D1}",  // mathematical bold script capital b
    "boldscrC" => "\x{1D4D2}",  // mathematical bold script capital c
    "boldscrD" => "\x{1D4D3}",  // mathematical bold script capital d
    "boldscrE" => "\x{1D4D4}",  // mathematical bold script capital e
    "boldscrF" => "\x{1D4D5}",  // mathematical bold script capital f
    "boldscrG" => "\x{1D4D6}",  // mathematical bold script capital g
    "boldscrH" => "\x{1D4D7}",  // mathematical bold script capital h
    "boldscrI" => "\x{1D4D8}",  // mathematical bold script capital i
    "boldscrJ" => "\x{1D4D9}",  // mathematical bold script capital j
    "boldscrK" => "\x{1D4DA}",  // mathematical bold script capital k
    "boldscrL" => "\x{1D4DB}",  // mathematical bold script capital l
    "boldscrM" => "\x{1D4DC}",  // mathematical bold script capital m
    "boldscrN" => "\x{1D4DD}",  // mathematical bold script capital n
    "boldscrO" => "\x{1D4DE}",  // mathematical bold script capital o
    "boldscrP" => "\x{1D4DF}",  // mathematical bold script capital p
    "boldscrQ" => "\x{1D4E0}",  // mathematical bold script capital q
    "boldscrR" => "\x{1D4E1}",  // mathematical bold script capital r
    "boldscrS" => "\x{1D4E2}",  // mathematical bold script capital s
    "boldscrT" => "\x{1D4E3}",  // mathematical bold script capital t
    "boldscrU" => "\x{1D4E4}",  // mathematical bold script capital u
    "boldscrV" => "\x{1D4E5}",  // mathematical bold script capital v
    "boldscrW" => "\x{1D4E6}",  // mathematical bold script capital w
    "boldscrX" => "\x{1D4E7}",  // mathematical bold script capital x
    "boldscrY" => "\x{1D4E8}",  // mathematical bold script capital y
    "boldscrZ" => "\x{1D4E9}",  // mathematical bold script capital z
    "boldscra" => "\x{1D4EA}",  // mathematical bold script small a
    "boldscrb" => "\x{1D4EB}",  // mathematical bold script small b
    "boldscrc" => "\x{1D4EC}",  // mathematical bold script small c
    "boldscrd" => "\x{1D4ED}",  // mathematical bold script small d
    "boldscre" => "\x{1D4EE}",  // mathematical bold script small e
    "boldscrf" => "\x{1D4EF}",  // mathematical bold script small f
    "boldscrg" => "\x{1D4F0}",  // mathematical bold script small g
    "boldscrh" => "\x{1D4F1}",  // mathematical bold script small h
    "boldscri" => "\x{1D4F2}",  // mathematical bold script small i
    "boldscrj" => "\x{1D4F3}",  // mathematical bold script small j
    "boldscrk" => "\x{1D4F4}",  // mathematical bold script small k
    "boldscrl" => "\x{1D4F5}",  // mathematical bold script small l
    "boldscrm" => "\x{1D4F6}",  // mathematical bold script small m
    "boldscrn" => "\x{1D4F7}",  // mathematical bold script small n
    "boldscro" => "\x{1D4F8}",  // mathematical bold script small o
    "boldscrp" => "\x{1D4F9}",  // mathematical bold script small p
    "boldscrq" => "\x{1D4FA}",  // mathematical bold script small q
    "boldscrr" => "\x{1D4FB}",  // mathematical bold script small r
    "boldscrs" => "\x{1D4FC}",  // mathematical bold script small s
    "boldscrt" => "\x{1D4FD}",  // mathematical bold script small t
    "boldscru" => "\x{1D4FE}",  // mathematical bold script small u
    "boldscrv" => "\x{1D4FF}",  // mathematical bold script small v
    "boldscrw" => "\x{1D500}",  // mathematical bold script small w
    "boldscrx" => "\x{1D501}",  // mathematical bold script small x
    "boldscry" => "\x{1D502}",  // mathematical bold script small y
    "boldscrz" => "\x{1D503}",  // mathematical bold script small z
    "frakA" => "\x{1D504}",  // mathematical fraktur capital a
    "frakB" => "\x{1D505}",  // mathematical fraktur capital b
    "frakD" => "\x{1D507}",  // mathematical fraktur capital d
    "frakE" => "\x{1D508}",  // mathematical fraktur capital e
    "frakF" => "\x{1D509}",  // mathematical fraktur capital f
    "frakG" => "\x{1D50A}",  // mathematical fraktur capital g
    "frakJ" => "\x{1D50D}",  // mathematical fraktur capital j
    "frakK" => "\x{1D50E}",  // mathematical fraktur capital k
    "frakL" => "\x{1D50F}",  // mathematical fraktur capital l
    "frakM" => "\x{1D510}",  // mathematical fraktur capital m
    "frakN" => "\x{1D511}",  // mathematical fraktur capital n
    "frakO" => "\x{1D512}",  // mathematical fraktur capital o
    "frakP" => "\x{1D513}",  // mathematical fraktur capital p
    "frakQ" => "\x{1D514}",  // mathematical fraktur capital q
    "frakS" => "\x{1D516}",  // mathematical fraktur capital s
    "frakT" => "\x{1D517}",  // mathematical fraktur capital t
    "frakU" => "\x{1D518}",  // mathematical fraktur capital u
    "frakV" => "\x{1D519}",  // mathematical fraktur capital v
    "frakW" => "\x{1D51A}",  // mathematical fraktur capital w
    "frakX" => "\x{1D51B}",  // mathematical fraktur capital x
    "frakY" => "\x{1D51C}",  // mathematical fraktur capital y
    "fraka" => "\x{1D51E}",  // mathematical fraktur small a
    "frakb" => "\x{1D51F}",  // mathematical fraktur small b
    "frakc" => "\x{1D520}",  // mathematical fraktur small c
    "frakd" => "\x{1D521}",  // mathematical fraktur small d
    "frake" => "\x{1D522}",  // mathematical fraktur small e
    "frakf" => "\x{1D523}",  // mathematical fraktur small f
    "frakg" => "\x{1D524}",  // mathematical fraktur small g
    "frakh" => "\x{1D525}",  // mathematical fraktur small h
    "fraki" => "\x{1D526}",  // mathematical fraktur small i
    "frakj" => "\x{1D527}",  // mathematical fraktur small j
    "frakk" => "\x{1D528}",  // mathematical fraktur small k
    "frakl" => "\x{1D529}",  // mathematical fraktur small l
    "frakm" => "\x{1D52A}",  // mathematical fraktur small m
    "frakn" => "\x{1D52B}",  // mathematical fraktur small n
    "frako" => "\x{1D52C}",  // mathematical fraktur small o
    "frakp" => "\x{1D52D}",  // mathematical fraktur small p
    "frakq" => "\x{1D52E}",  // mathematical fraktur small q
    "frakr" => "\x{1D52F}",  // mathematical fraktur small r
    "fraks" => "\x{1D530}",  // mathematical fraktur small s
    "frakt" => "\x{1D531}",  // mathematical fraktur small t
    "fraku" => "\x{1D532}",  // mathematical fraktur small u
    "frakv" => "\x{1D533}",  // mathematical fraktur small v
    "frakw" => "\x{1D534}",  // mathematical fraktur small w
    "frakx" => "\x{1D535}",  // mathematical fraktur small x
    "fraky" => "\x{1D536}",  // mathematical fraktur small y
    "frakz" => "\x{1D537}",  // mathematical fraktur small z
    "bbA" => "\x{1D538}",  // mathematical double-struck capital a
    "bbB" => "\x{1D539}",  // mathematical double-struck capital b
    "bbD" => "\x{1D53B}",  // mathematical double-struck capital d
    "bbE" => "\x{1D53C}",  // mathematical double-struck capital e
    "bbF" => "\x{1D53D}",  // mathematical double-struck capital f
    "bbG" => "\x{1D53E}",  // mathematical double-struck capital g
    "bbI" => "\x{1D540}",  // mathematical double-struck capital i
    "bbJ" => "\x{1D541}",  // mathematical double-struck capital j
    "bbK" => "\x{1D542}",  // mathematical double-struck capital k
    "bbL" => "\x{1D543}",  // mathematical double-struck capital l
    "bbM" => "\x{1D544}",  // mathematical double-struck capital m
    "bbO" => "\x{1D546}",  // mathematical double-struck capital o
    "bbS" => "\x{1D54A}",  // mathematical double-struck capital s
    "bbT" => "\x{1D54B}",  // mathematical double-struck capital t
    "bbU" => "\x{1D54C}",  // mathematical double-struck capital u
    "bbV" => "\x{1D54D}",  // mathematical double-struck capital v
    "bbW" => "\x{1D54E}",  // mathematical double-struck capital w
    "bbX" => "\x{1D54F}",  // mathematical double-struck capital x
    "bbY" => "\x{1D550}",  // mathematical double-struck capital y
    "bba" => "\x{1D552}",  // mathematical double-struck small a
    "bbb" => "\x{1D553}",  // mathematical double-struck small b
    "bbc" => "\x{1D554}",  // mathematical double-struck small c
    "bbd" => "\x{1D555}",  // mathematical double-struck small d
    "bbe" => "\x{1D556}",  // mathematical double-struck small e
    "bbf" => "\x{1D557}",  // mathematical double-struck small f
    "bbg" => "\x{1D558}",  // mathematical double-struck small g
    "bbh" => "\x{1D559}",  // mathematical double-struck small h
    "bbi" => "\x{1D55A}",  // mathematical double-struck small i
    "bbj" => "\x{1D55B}",  // mathematical double-struck small j
    "bbk" => "\x{1D55C}",  // mathematical double-struck small k
    "bbl" => "\x{1D55D}",  // mathematical double-struck small l
    "bbm" => "\x{1D55E}",  // mathematical double-struck small m
    "bbn" => "\x{1D55F}",  // mathematical double-struck small n
    "bbo" => "\x{1D560}",  // mathematical double-struck small o
    "bbp" => "\x{1D561}",  // mathematical double-struck small p
    "bbq" => "\x{1D562}",  // mathematical double-struck small q
    "bbr" => "\x{1D563}",  // mathematical double-struck small r
    "bbs" => "\x{1D564}",  // mathematical double-struck small s
    "bbt" => "\x{1D565}",  // mathematical double-struck small t
    "bbu" => "\x{1D566}",  // mathematical double-struck small u
    "bbv" => "\x{1D567}",  // mathematical double-struck small v
    "bbw" => "\x{1D568}",  // mathematical double-struck small w
    "bbx" => "\x{1D569}",  // mathematical double-struck small x
    "bby" => "\x{1D56A}",  // mathematical double-struck small y
    "bbz" => "\x{1D56B}",  // mathematical double-struck small z
    "boldfrakA" => "\x{1D56C}",  // mathematical bold fraktur capital a
    "boldfrakB" => "\x{1D56D}",  // mathematical bold fraktur capital b
    "boldfrakC" => "\x{1D56E}",  // mathematical bold fraktur capital c
    "boldfrakD" => "\x{1D56F}",  // mathematical bold fraktur capital d
    "boldfrakE" => "\x{1D570}",  // mathematical bold fraktur capital e
    "boldfrakF" => "\x{1D571}",  // mathematical bold fraktur capital f
    "boldfrakG" => "\x{1D572}",  // mathematical bold fraktur capital g
    "boldfrakH" => "\x{1D573}",  // mathematical bold fraktur capital h
    "boldfrakI" => "\x{1D574}",  // mathematical bold fraktur capital i
    "boldfrakJ" => "\x{1D575}",  // mathematical bold fraktur capital j
    "boldfrakK" => "\x{1D576}",  // mathematical bold fraktur capital k
    "boldfrakL" => "\x{1D577}",  // mathematical bold fraktur capital l
    "boldfrakM" => "\x{1D578}",  // mathematical bold fraktur capital m
    "boldfrakN" => "\x{1D579}",  // mathematical bold fraktur capital n
    "boldfrakO" => "\x{1D57A}",  // mathematical bold fraktur capital o
    "boldfrakP" => "\x{1D57B}",  // mathematical bold fraktur capital p
    "boldfrakQ" => "\x{1D57C}",  // mathematical bold fraktur capital q
    "boldfrakR" => "\x{1D57D}",  // mathematical bold fraktur capital r
    "boldfrakS" => "\x{1D57E}",  // mathematical bold fraktur capital s
    "boldfrakT" => "\x{1D57F}",  // mathematical bold fraktur capital t
    "boldfrakU" => "\x{1D580}",  // mathematical bold fraktur capital u
    "boldfrakV" => "\x{1D581}",  // mathematical bold fraktur capital v
    "boldfrakW" => "\x{1D582}",  // mathematical bold fraktur capital w
    "boldfrakX" => "\x{1D583}",  // mathematical bold fraktur capital x
    "boldfrakY" => "\x{1D584}",  // mathematical bold fraktur capital y
    "boldfrakZ" => "\x{1D585}",  // mathematical bold fraktur capital z
    "boldfraka" => "\x{1D586}",  // mathematical bold fraktur small a
    "boldfrakb" => "\x{1D587}",  // mathematical bold fraktur small b
    "boldfrakc" => "\x{1D588}",  // mathematical bold fraktur small c
    "boldfrakd" => "\x{1D589}",  // mathematical bold fraktur small d
    "boldfrake" => "\x{1D58A}",  // mathematical bold fraktur small e
    "boldfrakf" => "\x{1D58B}",  // mathematical bold fraktur small f
    "boldfrakg" => "\x{1D58C}",  // mathematical bold fraktur small g
    "boldfrakh" => "\x{1D58D}",  // mathematical bold fraktur small h
    "boldfraki" => "\x{1D58E}",  // mathematical bold fraktur small i
    "boldfrakj" => "\x{1D58F}",  // mathematical bold fraktur small j
    "boldfrakk" => "\x{1D590}",  // mathematical bold fraktur small k
    "boldfrakl" => "\x{1D591}",  // mathematical bold fraktur small l
    "boldfrakm" => "\x{1D592}",  // mathematical bold fraktur small m
    "boldfrakn" => "\x{1D593}",  // mathematical bold fraktur small n
    "boldfrako" => "\x{1D594}",  // mathematical bold fraktur small o
    "boldfrakp" => "\x{1D595}",  // mathematical bold fraktur small p
    "boldfrakq" => "\x{1D596}",  // mathematical bold fraktur small q
    "boldfrakr" => "\x{1D597}",  // mathematical bold fraktur small r
    "boldfraks" => "\x{1D598}",  // mathematical bold fraktur small s
    "boldfrakt" => "\x{1D599}",  // mathematical bold fraktur small t
    "boldfraku" => "\x{1D59A}",  // mathematical bold fraktur small u
    "boldfrakv" => "\x{1D59B}",  // mathematical bold fraktur small v
    "boldfrakw" => "\x{1D59C}",  // mathematical bold fraktur small w
    "boldfrakx" => "\x{1D59D}",  // mathematical bold fraktur small x
    "boldfraky" => "\x{1D59E}",  // mathematical bold fraktur small y
    "boldfrakz" => "\x{1D59F}",  // mathematical bold fraktur small z
    "sansA" => "\x{1D5A0}",  // mathematical sans-serif capital a
    "sansB" => "\x{1D5A1}",  // mathematical sans-serif capital b
    "sansC" => "\x{1D5A2}",  // mathematical sans-serif capital c
    "sansD" => "\x{1D5A3}",  // mathematical sans-serif capital d
    "sansE" => "\x{1D5A4}",  // mathematical sans-serif capital e
    "sansF" => "\x{1D5A5}",  // mathematical sans-serif capital f
    "sansG" => "\x{1D5A6}",  // mathematical sans-serif capital g
    "sansH" => "\x{1D5A7}",  // mathematical sans-serif capital h
    "sansI" => "\x{1D5A8}",  // mathematical sans-serif capital i
    "sansJ" => "\x{1D5A9}",  // mathematical sans-serif capital j
    "sansK" => "\x{1D5AA}",  // mathematical sans-serif capital k
    "sansL" => "\x{1D5AB}",  // mathematical sans-serif capital l
    "sansM" => "\x{1D5AC}",  // mathematical sans-serif capital m
    "sansN" => "\x{1D5AD}",  // mathematical sans-serif capital n
    "sansO" => "\x{1D5AE}",  // mathematical sans-serif capital o
    "sansP" => "\x{1D5AF}",  // mathematical sans-serif capital p
    "sansQ" => "\x{1D5B0}",  // mathematical sans-serif capital q
    "sansR" => "\x{1D5B1}",  // mathematical sans-serif capital r
    "sansS" => "\x{1D5B2}",  // mathematical sans-serif capital s
    "sansT" => "\x{1D5B3}",  // mathematical sans-serif capital t
    "sansU" => "\x{1D5B4}",  // mathematical sans-serif capital u
    "sansV" => "\x{1D5B5}",  // mathematical sans-serif capital v
    "sansW" => "\x{1D5B6}",  // mathematical sans-serif capital w
    "sansX" => "\x{1D5B7}",  // mathematical sans-serif capital x
    "sansY" => "\x{1D5B8}",  // mathematical sans-serif capital y
    "sansZ" => "\x{1D5B9}",  // mathematical sans-serif capital z
    "sansa" => "\x{1D5BA}",  // mathematical sans-serif small a
    "sansb" => "\x{1D5BB}",  // mathematical sans-serif small b
    "sansc" => "\x{1D5BC}",  // mathematical sans-serif small c
    "sansd" => "\x{1D5BD}",  // mathematical sans-serif small d
    "sanse" => "\x{1D5BE}",  // mathematical sans-serif small e
    "sansf" => "\x{1D5BF}",  // mathematical sans-serif small f
    "sansg" => "\x{1D5C0}",  // mathematical sans-serif small g
    "sansh" => "\x{1D5C1}",  // mathematical sans-serif small h
    "sansi" => "\x{1D5C2}",  // mathematical sans-serif small i
    "sansj" => "\x{1D5C3}",  // mathematical sans-serif small j
    "sansk" => "\x{1D5C4}",  // mathematical sans-serif small k
    "sansl" => "\x{1D5C5}",  // mathematical sans-serif small l
    "sansm" => "\x{1D5C6}",  // mathematical sans-serif small m
    "sansn" => "\x{1D5C7}",  // mathematical sans-serif small n
    "sanso" => "\x{1D5C8}",  // mathematical sans-serif small o
    "sansp" => "\x{1D5C9}",  // mathematical sans-serif small p
    "sansq" => "\x{1D5CA}",  // mathematical sans-serif small q
    "sansr" => "\x{1D5CB}",  // mathematical sans-serif small r
    "sanss" => "\x{1D5CC}",  // mathematical sans-serif small s
    "sanst" => "\x{1D5CD}",  // mathematical sans-serif small t
    "sansu" => "\x{1D5CE}",  // mathematical sans-serif small u
    "sansv" => "\x{1D5CF}",  // mathematical sans-serif small v
    "sansw" => "\x{1D5D0}",  // mathematical sans-serif small w
    "sansx" => "\x{1D5D1}",  // mathematical sans-serif small x
    "sansy" => "\x{1D5D2}",  // mathematical sans-serif small y
    "sansz" => "\x{1D5D3}",  // mathematical sans-serif small z
    "boldsansA" => "\x{1D5D4}",  // mathematical sans-serif bold capital a
    "boldsansB" => "\x{1D5D5}",  // mathematical sans-serif bold capital b
    "boldsansC" => "\x{1D5D6}",  // mathematical sans-serif bold capital c
    "boldsansD" => "\x{1D5D7}",  // mathematical sans-serif bold capital d
    "boldsansE" => "\x{1D5D8}",  // mathematical sans-serif bold capital e
    "boldsansF" => "\x{1D5D9}",  // mathematical sans-serif bold capital f
    "boldsansG" => "\x{1D5DA}",  // mathematical sans-serif bold capital g
    "boldsansH" => "\x{1D5DB}",  // mathematical sans-serif bold capital h
    "boldsansI" => "\x{1D5DC}",  // mathematical sans-serif bold capital i
    "boldsansJ" => "\x{1D5DD}",  // mathematical sans-serif bold capital j
    "boldsansK" => "\x{1D5DE}",  // mathematical sans-serif bold capital k
    "boldsansL" => "\x{1D5DF}",  // mathematical sans-serif bold capital l
    "boldsansM" => "\x{1D5E0}",  // mathematical sans-serif bold capital m
    "boldsansN" => "\x{1D5E1}",  // mathematical sans-serif bold capital n
    "boldsansO" => "\x{1D5E2}",  // mathematical sans-serif bold capital o
    "boldsansP" => "\x{1D5E3}",  // mathematical sans-serif bold capital p
    "boldsansQ" => "\x{1D5E4}",  // mathematical sans-serif bold capital q
    "boldsansR" => "\x{1D5E5}",  // mathematical sans-serif bold capital r
    "boldsansS" => "\x{1D5E6}",  // mathematical sans-serif bold capital s
    "boldsansT" => "\x{1D5E7}",  // mathematical sans-serif bold capital t
    "boldsansU" => "\x{1D5E8}",  // mathematical sans-serif bold capital u
    "boldsansV" => "\x{1D5E9}",  // mathematical sans-serif bold capital v
    "boldsansW" => "\x{1D5EA}",  // mathematical sans-serif bold capital w
    "boldsansX" => "\x{1D5EB}",  // mathematical sans-serif bold capital x
    "boldsansY" => "\x{1D5EC}",  // mathematical sans-serif bold capital y
    "boldsansZ" => "\x{1D5ED}",  // mathematical sans-serif bold capital z
    "boldsansa" => "\x{1D5EE}",  // mathematical sans-serif bold small a
    "boldsansb" => "\x{1D5EF}",  // mathematical sans-serif bold small b
    "boldsansc" => "\x{1D5F0}",  // mathematical sans-serif bold small c
    "boldsansd" => "\x{1D5F1}",  // mathematical sans-serif bold small d
    "boldsanse" => "\x{1D5F2}",  // mathematical sans-serif bold small e
    "boldsansf" => "\x{1D5F3}",  // mathematical sans-serif bold small f
    "boldsansg" => "\x{1D5F4}",  // mathematical sans-serif bold small g
    "boldsansh" => "\x{1D5F5}",  // mathematical sans-serif bold small h
    "boldsansi" => "\x{1D5F6}",  // mathematical sans-serif bold small i
    "boldsansj" => "\x{1D5F7}",  // mathematical sans-serif bold small j
    "boldsansk" => "\x{1D5F8}",  // mathematical sans-serif bold small k
    "boldsansl" => "\x{1D5F9}",  // mathematical sans-serif bold small l
    "boldsansm" => "\x{1D5FA}",  // mathematical sans-serif bold small m
    "boldsansn" => "\x{1D5FB}",  // mathematical sans-serif bold small n
    "boldsanso" => "\x{1D5FC}",  // mathematical sans-serif bold small o
    "boldsansp" => "\x{1D5FD}",  // mathematical sans-serif bold small p
    "boldsansq" => "\x{1D5FE}",  // mathematical sans-serif bold small q
    "boldsansr" => "\x{1D5FF}",  // mathematical sans-serif bold small r
    "boldsanss" => "\x{1D600}",  // mathematical sans-serif bold small s
    "boldsanst" => "\x{1D601}",  // mathematical sans-serif bold small t
    "boldsansu" => "\x{1D602}",  // mathematical sans-serif bold small u
    "boldsansv" => "\x{1D603}",  // mathematical sans-serif bold small v
    "boldsansw" => "\x{1D604}",  // mathematical sans-serif bold small w
    "boldsansx" => "\x{1D605}",  // mathematical sans-serif bold small x
    "boldsansy" => "\x{1D606}",  // mathematical sans-serif bold small y
    "boldsansz" => "\x{1D607}",  // mathematical sans-serif bold small z
#if 0
    italicsans*"A" => "\x{1D608}",  // mathematical sans-serif italic capital a
    italicsans*"B" => "\x{1D609}",  // mathematical sans-serif italic capital b
    italicsans*"C" => "\x{1D60A}",  // mathematical sans-serif italic capital c
    italicsans*"D" => "\x{1D60B}",  // mathematical sans-serif italic capital d
    italicsans*"E" => "\x{1D60C}",  // mathematical sans-serif italic capital e
    italicsans*"F" => "\x{1D60D}",  // mathematical sans-serif italic capital f
    italicsans*"G" => "\x{1D60E}",  // mathematical sans-serif italic capital g
    italicsans*"H" => "\x{1D60F}",  // mathematical sans-serif italic capital h
    italicsans*"I" => "\x{1D610}",  // mathematical sans-serif italic capital i
    italicsans*"J" => "\x{1D611}",  // mathematical sans-serif italic capital j
    italicsans*"K" => "\x{1D612}",  // mathematical sans-serif italic capital k
    italicsans*"L" => "\x{1D613}",  // mathematical sans-serif italic capital l
    italicsans*"M" => "\x{1D614}",  // mathematical sans-serif italic capital m
    italicsans*"N" => "\x{1D615}",  // mathematical sans-serif italic capital n
    italicsans*"O" => "\x{1D616}",  // mathematical sans-serif italic capital o
    italicsans*"P" => "\x{1D617}",  // mathematical sans-serif italic capital p
    italicsans*"Q" => "\x{1D618}",  // mathematical sans-serif italic capital q
    italicsans*"R" => "\x{1D619}",  // mathematical sans-serif italic capital r
    italicsans*"S" => "\x{1D61A}",  // mathematical sans-serif italic capital s
    italicsans*"T" => "\x{1D61B}",  // mathematical sans-serif italic capital t
    italicsans*"U" => "\x{1D61C}",  // mathematical sans-serif italic capital u
    italicsans*"V" => "\x{1D61D}",  // mathematical sans-serif italic capital v
    italicsans*"W" => "\x{1D61E}",  // mathematical sans-serif italic capital w
    italicsans*"X" => "\x{1D61F}",  // mathematical sans-serif italic capital x
    italicsans*"Y" => "\x{1D620}",  // mathematical sans-serif italic capital y
    italicsans*"Z" => "\x{1D621}",  // mathematical sans-serif italic capital z
    italicsans*"a" => "\x{1D622}",  // mathematical sans-serif italic small a
    italicsans*"b" => "\x{1D623}",  // mathematical sans-serif italic small b
    italicsans*"c" => "\x{1D624}",  // mathematical sans-serif italic small c
    italicsans*"d" => "\x{1D625}",  // mathematical sans-serif italic small d
    italicsans*"e" => "\x{1D626}",  // mathematical sans-serif italic small e
    italicsans*"f" => "\x{1D627}",  // mathematical sans-serif italic small f
    italicsans*"g" => "\x{1D628}",  // mathematical sans-serif italic small g
    italicsans*"h" => "\x{1D629}",  // mathematical sans-serif italic small h
    italicsans*"i" => "\x{1D62A}",  // mathematical sans-serif italic small i
    italicsans*"j" => "\x{1D62B}",  // mathematical sans-serif italic small j
    italicsans*"k" => "\x{1D62C}",  // mathematical sans-serif italic small k
    italicsans*"l" => "\x{1D62D}",  // mathematical sans-serif italic small l
    italicsans*"m" => "\x{1D62E}",  // mathematical sans-serif italic small m
    italicsans*"n" => "\x{1D62F}",  // mathematical sans-serif italic small n
    italicsans*"o" => "\x{1D630}",  // mathematical sans-serif italic small o
    italicsans*"p" => "\x{1D631}",  // mathematical sans-serif italic small p
    italicsans*"q" => "\x{1D632}",  // mathematical sans-serif italic small q
    italicsans*"r" => "\x{1D633}",  // mathematical sans-serif italic small r
    italicsans*"s" => "\x{1D634}",  // mathematical sans-serif italic small s
    italicsans*"t" => "\x{1D635}",  // mathematical sans-serif italic small t
    italicsans*"u" => "\x{1D636}",  // mathematical sans-serif italic small u
    italicsans*"v" => "\x{1D637}",  // mathematical sans-serif italic small v
    italicsans*"w" => "\x{1D638}",  // mathematical sans-serif italic small w
    italicsans*"x" => "\x{1D639}",  // mathematical sans-serif italic small x
    italicsans*"y" => "\x{1D63A}",  // mathematical sans-serif italic small y
    italicsans*"z" => "\x{1D63B}",  // mathematical sans-serif italic small z
    bolditalicsans*"A" => "\x{1D63C}",  // mathematical sans-serif bold italic capital a
    bolditalicsans*"B" => "\x{1D63D}",  // mathematical sans-serif bold italic capital b
    bolditalicsans*"C" => "\x{1D63E}",  // mathematical sans-serif bold italic capital c
    bolditalicsans*"D" => "\x{1D63F}",  // mathematical sans-serif bold italic capital d
    bolditalicsans*"E" => "\x{1D640}",  // mathematical sans-serif bold italic capital e
    bolditalicsans*"F" => "\x{1D641}",  // mathematical sans-serif bold italic capital f
    bolditalicsans*"G" => "\x{1D642}",  // mathematical sans-serif bold italic capital g
    bolditalicsans*"H" => "\x{1D643}",  // mathematical sans-serif bold italic capital h
    bolditalicsans*"I" => "\x{1D644}",  // mathematical sans-serif bold italic capital i
    bolditalicsans*"J" => "\x{1D645}",  // mathematical sans-serif bold italic capital j
    bolditalicsans*"K" => "\x{1D646}",  // mathematical sans-serif bold italic capital k
    bolditalicsans*"L" => "\x{1D647}",  // mathematical sans-serif bold italic capital l
    bolditalicsans*"M" => "\x{1D648}",  // mathematical sans-serif bold italic capital m
    bolditalicsans*"N" => "\x{1D649}",  // mathematical sans-serif bold italic capital n
    bolditalicsans*"O" => "\x{1D64A}",  // mathematical sans-serif bold italic capital o
    bolditalicsans*"P" => "\x{1D64B}",  // mathematical sans-serif bold italic capital p
    bolditalicsans*"Q" => "\x{1D64C}",  // mathematical sans-serif bold italic capital q
    bolditalicsans*"R" => "\x{1D64D}",  // mathematical sans-serif bold italic capital r
    bolditalicsans*"S" => "\x{1D64E}",  // mathematical sans-serif bold italic capital s
    bolditalicsans*"T" => "\x{1D64F}",  // mathematical sans-serif bold italic capital t
    bolditalicsans*"U" => "\x{1D650}",  // mathematical sans-serif bold italic capital u
    bolditalicsans*"V" => "\x{1D651}",  // mathematical sans-serif bold italic capital v
    bolditalicsans*"W" => "\x{1D652}",  // mathematical sans-serif bold italic capital w
    bolditalicsans*"X" => "\x{1D653}",  // mathematical sans-serif bold italic capital x
    bolditalicsans*"Y" => "\x{1D654}",  // mathematical sans-serif bold italic capital y
    bolditalicsans*"Z" => "\x{1D655}",  // mathematical sans-serif bold italic capital z
    bolditalicsans*"a" => "\x{1D656}",  // mathematical sans-serif bold italic small a
    bolditalicsans*"b" => "\x{1D657}",  // mathematical sans-serif bold italic small b
    bolditalicsans*"c" => "\x{1D658}",  // mathematical sans-serif bold italic small c
    bolditalicsans*"d" => "\x{1D659}",  // mathematical sans-serif bold italic small d
    bolditalicsans*"e" => "\x{1D65A}",  // mathematical sans-serif bold italic small e
    bolditalicsans*"f" => "\x{1D65B}",  // mathematical sans-serif bold italic small f
    bolditalicsans*"g" => "\x{1D65C}",  // mathematical sans-serif bold italic small g
    bolditalicsans*"h" => "\x{1D65D}",  // mathematical sans-serif bold italic small h
    bolditalicsans*"i" => "\x{1D65E}",  // mathematical sans-serif bold italic small i
    bolditalicsans*"j" => "\x{1D65F}",  // mathematical sans-serif bold italic small j
    bolditalicsans*"k" => "\x{1D660}",  // mathematical sans-serif bold italic small k
    bolditalicsans*"l" => "\x{1D661}",  // mathematical sans-serif bold italic small l
    bolditalicsans*"m" => "\x{1D662}",  // mathematical sans-serif bold italic small m
    bolditalicsans*"n" => "\x{1D663}",  // mathematical sans-serif bold italic small n
    bolditalicsans*"o" => "\x{1D664}",  // mathematical sans-serif bold italic small o
    bolditalicsans*"p" => "\x{1D665}",  // mathematical sans-serif bold italic small p
    bolditalicsans*"q" => "\x{1D666}",  // mathematical sans-serif bold italic small q
    bolditalicsans*"r" => "\x{1D667}",  // mathematical sans-serif bold italic small r
    bolditalicsans*"s" => "\x{1D668}",  // mathematical sans-serif bold italic small s
    bolditalicsans*"t" => "\x{1D669}",  // mathematical sans-serif bold italic small t
    bolditalicsans*"u" => "\x{1D66A}",  // mathematical sans-serif bold italic small u
    bolditalicsans*"v" => "\x{1D66B}",  // mathematical sans-serif bold italic small v
    bolditalicsans*"w" => "\x{1D66C}",  // mathematical sans-serif bold italic small w
    bolditalicsans*"x" => "\x{1D66D}",  // mathematical sans-serif bold italic small x
    bolditalicsans*"y" => "\x{1D66E}",  // mathematical sans-serif bold italic small y
    bolditalicsans*"z" => "\x{1D66F}",  // mathematical sans-serif bold italic small z
    mono*"A" => "\x{1D670}",  // mathematical monospace capital a
    mono*"B" => "\x{1D671}",  // mathematical monospace capital b
    mono*"C" => "\x{1D672}",  // mathematical monospace capital c
    mono*"D" => "\x{1D673}",  // mathematical monospace capital d
    mono*"E" => "\x{1D674}",  // mathematical monospace capital e
    mono*"F" => "\x{1D675}",  // mathematical monospace capital f
    mono*"G" => "\x{1D676}",  // mathematical monospace capital g
    mono*"H" => "\x{1D677}",  // mathematical monospace capital h
    mono*"I" => "\x{1D678}",  // mathematical monospace capital i
    mono*"J" => "\x{1D679}",  // mathematical monospace capital j
    mono*"K" => "\x{1D67A}",  // mathematical monospace capital k
    mono*"L" => "\x{1D67B}",  // mathematical monospace capital l
    mono*"M" => "\x{1D67C}",  // mathematical monospace capital m
    mono*"N" => "\x{1D67D}",  // mathematical monospace capital n
    mono*"O" => "\x{1D67E}",  // mathematical monospace capital o
    mono*"P" => "\x{1D67F}",  // mathematical monospace capital p
    mono*"Q" => "\x{1D680}",  // mathematical monospace capital q
    mono*"R" => "\x{1D681}",  // mathematical monospace capital r
    mono*"S" => "\x{1D682}",  // mathematical monospace capital s
    mono*"T" => "\x{1D683}",  // mathematical monospace capital t
    mono*"U" => "\x{1D684}",  // mathematical monospace capital u
    mono*"V" => "\x{1D685}",  // mathematical monospace capital v
    mono*"W" => "\x{1D686}",  // mathematical monospace capital w
    mono*"X" => "\x{1D687}",  // mathematical monospace capital x
    mono*"Y" => "\x{1D688}",  // mathematical monospace capital y
    mono*"Z" => "\x{1D689}",  // mathematical monospace capital z
    mono*"a" => "\x{1D68A}",  // mathematical monospace small a
    mono*"b" => "\x{1D68B}",  // mathematical monospace small b
    mono*"c" => "\x{1D68C}",  // mathematical monospace small c
    mono*"d" => "\x{1D68D}",  // mathematical monospace small d
    mono*"e" => "\x{1D68E}",  // mathematical monospace small e
    mono*"f" => "\x{1D68F}",  // mathematical monospace small f
    mono*"g" => "\x{1D690}",  // mathematical monospace small g
    mono*"h" => "\x{1D691}",  // mathematical monospace small h
    mono*"i" => "\x{1D692}",  // mathematical monospace small i
    mono*"j" => "\x{1D693}",  // mathematical monospace small j
    mono*"k" => "\x{1D694}",  // mathematical monospace small k
    mono*"l" => "\x{1D695}",  // mathematical monospace small l
    mono*"m" => "\x{1D696}",  // mathematical monospace small m
    mono*"n" => "\x{1D697}",  // mathematical monospace small n
    mono*"o" => "\x{1D698}",  // mathematical monospace small o
    mono*"p" => "\x{1D699}",  // mathematical monospace small p
    mono*"q" => "\x{1D69A}",  // mathematical monospace small q
    mono*"r" => "\x{1D69B}",  // mathematical monospace small r
    mono*"s" => "\x{1D69C}",  // mathematical monospace small s
    mono*"t" => "\x{1D69D}",  // mathematical monospace small t
    mono*"u" => "\x{1D69E}",  // mathematical monospace small u
    mono*"v" => "\x{1D69F}",  // mathematical monospace small v
    mono*"w" => "\x{1D6A0}",  // mathematical monospace small w
    mono*"x" => "\x{1D6A1}",  // mathematical monospace small x
    mono*"y" => "\x{1D6A2}",  // mathematical monospace small y
    mono*"z" => "\x{1D6A3}",  // mathematical monospace small z
#endif
    "itimath" => "\x{1d6a4}",  // mathematical italic small dotless i
    "itjmath" => "\x{1d6a5}",  // mathematical italic small dotless j
    "boldAlpha" => "\x{1D6A8}",  // mathematical bold capital alpha
    "boldBeta" => "\x{1D6A9}",  // mathematical bold capital beta
    "boldGamma" => "\x{1D6AA}",  // mathematical bold capital gamma
    "boldDelta" => "\x{1D6AB}",  // mathematical bold capital delta
    "boldEpsilon" => "\x{1D6AC}",  // mathematical bold capital epsilon
    "boldZeta" => "\x{1D6AD}",  // mathematical bold capital zeta
    "boldEta" => "\x{1D6AE}",  // mathematical bold capital eta
    "boldTheta" => "\x{1D6AF}",  // mathematical bold capital theta
    "boldIota" => "\x{1D6B0}",  // mathematical bold capital iota
    "boldKappa" => "\x{1D6B1}",  // mathematical bold capital kappa
    "boldLambda" => "\x{1D6B2}",  // mathematical bold capital lambda
    "boldMu" => "\x{1D6B3}",  // mathematical bold capital mu
    "boldNu" => "\x{1D6B4}",  // mathematical bold capital nu
    "boldXi" => "\x{1D6B5}",  // mathematical bold capital xi
    "boldOmicron" => "\x{1D6B6}",  // mathematical bold capital omicron
    "boldPi" => "\x{1D6B7}",  // mathematical bold capital pi
    "boldRho" => "\x{1D6B8}",  // mathematical bold capital rho
    "boldvarTheta" => "\x{1D6B9}",  // mathematical bold capital theta symbol
    "boldSigma" => "\x{1D6BA}",  // mathematical bold capital sigma
    "boldTau" => "\x{1D6BB}",  // mathematical bold capital tau
    "boldUpsilon" => "\x{1D6BC}",  // mathematical bold capital upsilon
    "boldPhi" => "\x{1D6BD}",  // mathematical bold capital phi
    "boldChi" => "\x{1D6BE}",  // mathematical bold capital chi
    "boldPsi" => "\x{1D6BF}",  // mathematical bold capital psi
    "boldOmega" => "\x{1D6C0}",  // mathematical bold capital omega
    "boldnabla" => "\x{1D6C1}",  // mathematical bold nabla
    "boldalpha" => "\x{1D6C2}",  // mathematical bold small alpha
    "boldbeta" => "\x{1D6C3}",  // mathematical bold small beta
    "boldgamma" => "\x{1D6C4}",  // mathematical bold small gamma
    "bolddelta" => "\x{1D6C5}",  // mathematical bold small delta
    "boldepsilon" => "\x{1D6C6}",  // mathematical bold small epsilon
    "boldzeta" => "\x{1D6C7}",  // mathematical bold small zeta
    "boldeta" => "\x{1D6C8}",  // mathematical bold small eta
    "boldtheta" => "\x{1D6C9}",  // mathematical bold small theta
    "boldiota" => "\x{1D6CA}",  // mathematical bold small iota
    "boldkappa" => "\x{1D6CB}",  // mathematical bold small kappa
    "boldlambda" => "\x{1D6CC}",  // mathematical bold small lambda
    "boldmu" => "\x{1D6CD}",  // mathematical bold small mu
    "boldnu" => "\x{1D6CE}",  // mathematical bold small nu
    "boldxi" => "\x{1D6CF}",  // mathematical bold small xi
    "boldomicron" => "\x{1D6D0}",  // mathematical bold small omicron
    "boldpi" => "\x{1D6D1}",  // mathematical bold small pi
    "boldrho" => "\x{1D6D2}",  // mathematical bold small rho
    "boldvarsigma" => "\x{1D6D3}",  // mathematical bold small final sigma
    "boldsigma" => "\x{1D6D4}",  // mathematical bold small sigma
    "boldtau" => "\x{1D6D5}",  // mathematical bold small tau
    "boldupsilon" => "\x{1D6D6}",  // mathematical bold small upsilon
    "boldvarphi" => "\x{1D6D7}",  // mathematical bold small phi
    "boldchi" => "\x{1D6D8}",  // mathematical bold small chi
    "boldpsi" => "\x{1D6D9}",  // mathematical bold small psi
    "boldomega" => "\x{1D6DA}",  // mathematical bold small omega
    "boldpartial" => "\x{1D6DB}",  // mathematical bold partial differential
    "boldvarepsilon" => "\x{1D6DC}",  // mathematical bold epsilon symbol
    "boldvartheta" => "\x{1D6DD}",  // mathematical bold theta symbol
    "boldvarkappa" => "\x{1D6DE}",  // mathematical bold kappa symbol
    "boldphi" => "\x{1D6DF}",  // mathematical bold phi symbol
    "boldvarrho" => "\x{1D6E0}",  // mathematical bold rho symbol
    "boldvarpi" => "\x{1D6E1}",  // mathematical bold pi symbol
    "itAlpha" => "\x{1D6E2}",  // mathematical italic capital alpha
    "itBeta" => "\x{1D6E3}",  // mathematical italic capital beta
    "itGamma" => "\x{1D6E4}",  // mathematical italic capital gamma
    "itDelta" => "\x{1D6E5}",  // mathematical italic capital delta
    "itEpsilon" => "\x{1D6E6}",  // mathematical italic capital epsilon
    "itZeta" => "\x{1D6E7}",  // mathematical italic capital zeta
    "itEta" => "\x{1D6E8}",  // mathematical italic capital eta
    "itTheta" => "\x{1D6E9}",  // mathematical italic capital theta
    "itIota" => "\x{1D6EA}",  // mathematical italic capital iota
    "itKappa" => "\x{1D6EB}",  // mathematical italic capital kappa
    "itLambda" => "\x{1D6EC}",  // mathematical italic capital lambda
    "itMu" => "\x{1D6ED}",  // mathematical italic capital mu
    "itNu" => "\x{1D6EE}",  // mathematical italic capital nu
    "itXi" => "\x{1D6EF}",  // mathematical italic capital xi
    "itOmicron" => "\x{1D6F0}",  // mathematical italic capital omicron
    "itPi" => "\x{1D6F1}",  // mathematical italic capital pi
    "itRho" => "\x{1D6F2}",  // mathematical italic capital rho
    "itvarTheta" => "\x{1D6F3}",  // mathematical italic capital theta symbol
    "itSigma" => "\x{1D6F4}",  // mathematical italic capital sigma
    "itTau" => "\x{1D6F5}",  // mathematical italic capital tau
    "itUpsilon" => "\x{1D6F6}",  // mathematical italic capital upsilon
    "itPhi" => "\x{1D6F7}",  // mathematical italic capital phi
    "itChi" => "\x{1D6F8}",  // mathematical italic capital chi
    "itPsi" => "\x{1D6F9}",  // mathematical italic capital psi
    "itOmega" => "\x{1D6FA}",  // mathematical italic capital omega
    "itnabla" => "\x{1D6FB}",  // mathematical italic nabla
    "italpha" => "\x{1D6FC}",  // mathematical italic small alpha
    "itbeta" => "\x{1D6FD}",  // mathematical italic small beta
    "itgamma" => "\x{1D6FE}",  // mathematical italic small gamma
    "itdelta" => "\x{1D6FF}",  // mathematical italic small delta
    "itepsilon" => "\x{1D700}",  // mathematical italic small epsilon
    "itzeta" => "\x{1D701}",  // mathematical italic small zeta
    "iteta" => "\x{1D702}",  // mathematical italic small eta
    "ittheta" => "\x{1D703}",  // mathematical italic small theta
    "itiota" => "\x{1D704}",  // mathematical italic small iota
    "itkappa" => "\x{1D705}",  // mathematical italic small kappa
    "itlambda" => "\x{1D706}",  // mathematical italic small lambda
    "itmu" => "\x{1D707}",  // mathematical italic small mu
    "itnu" => "\x{1D708}",  // mathematical italic small nu
    "itxi" => "\x{1D709}",  // mathematical italic small xi
    "itomicron" => "\x{1D70A}",  // mathematical italic small omicron
    "itpi" => "\x{1D70B}",  // mathematical italic small pi
    "itrho" => "\x{1D70C}",  // mathematical italic small rho
    "itvarsigma" => "\x{1D70D}",  // mathematical italic small final sigma
    "itsigma" => "\x{1D70E}",  // mathematical italic small sigma
    "ittau" => "\x{1D70F}",  // mathematical italic small tau
    "itupsilon" => "\x{1D710}",  // mathematical italic small upsilon
    "itphi" => "\x{1D711}",  // mathematical italic small phi
    "itchi" => "\x{1D712}",  // mathematical italic small chi
    "itpsi" => "\x{1D713}",  // mathematical italic small psi
    "itomega" => "\x{1D714}",  // mathematical italic small omega
    "itpartial" => "\x{1D715}",  // mathematical italic partial differential
    "itvarepsilon" => "\x{1D716}",  // mathematical italic epsilon symbol
    "itvartheta" => "\x{1D717}",  // mathematical italic theta symbol
    "itvarkappa" => "\x{1D718}",  // mathematical italic kappa symbol
    "itvarphi" => "\x{1D719}",  // mathematical italic phi symbol
    "itvarrho" => "\x{1D71A}",  // mathematical italic rho symbol
    "itvarpi" => "\x{1D71B}",  // mathematical italic pi symbol
    "bolditAlpha" => "\x{1D71C}",  // mathematical bold italic capital alpha
    "bolditBeta" => "\x{1D71D}",  // mathematical bold italic capital beta
    "bolditGamma" => "\x{1D71E}",  // mathematical bold italic capital gamma
    "bolditDelta" => "\x{1D71F}",  // mathematical bold italic capital delta
    "bolditEpsilon" => "\x{1D720}",  // mathematical bold italic capital epsilon
    "bolditZeta" => "\x{1D721}",  // mathematical bold italic capital zeta
    "bolditEta" => "\x{1D722}",  // mathematical bold italic capital eta
    "bolditTheta" => "\x{1D723}",  // mathematical bold italic capital theta
    "bolditIota" => "\x{1D724}",  // mathematical bold italic capital iota
    "bolditKappa" => "\x{1D725}",  // mathematical bold italic capital kappa
    "bolditLambda" => "\x{1D726}",  // mathematical bold italic capital lambda
    "bolditMu" => "\x{1D727}",  // mathematical bold italic capital mu
    "bolditNu" => "\x{1D728}",  // mathematical bold italic capital nu
    "bolditXi" => "\x{1D729}",  // mathematical bold italic capital xi
    "bolditOmicron" => "\x{1D72A}",  // mathematical bold italic capital omicron
    "bolditPi" => "\x{1D72B}",  // mathematical bold italic capital pi
    "bolditRho" => "\x{1D72C}",  // mathematical bold italic capital rho
    "bolditvarTheta" => "\x{1D72D}",  // mathematical bold italic capital theta symbol
    "bolditSigma" => "\x{1D72E}",  // mathematical bold italic capital sigma
    "bolditTau" => "\x{1D72F}",  // mathematical bold italic capital tau
    "bolditUpsilon" => "\x{1D730}",  // mathematical bold italic capital upsilon
    "bolditPhi" => "\x{1D731}",  // mathematical bold italic capital phi
    "bolditChi" => "\x{1D732}",  // mathematical bold italic capital chi
    "bolditPsi" => "\x{1D733}",  // mathematical bold italic capital psi
    "bolditOmega" => "\x{1D734}",  // mathematical bold italic capital omega
    "bolditnabla" => "\x{1D735}",  // mathematical bold italic nabla
    "bolditalpha" => "\x{1D736}",  // mathematical bold italic small alpha
    "bolditbeta" => "\x{1D737}",  // mathematical bold italic small beta
    "bolditgamma" => "\x{1D738}",  // mathematical bold italic small gamma
    "bolditdelta" => "\x{1D739}",  // mathematical bold italic small delta
    "bolditepsilon" => "\x{1D73A}",  // mathematical bold italic small epsilon
    "bolditzeta" => "\x{1D73B}",  // mathematical bold italic small zeta
    "bolditeta" => "\x{1D73C}",  // mathematical bold italic small eta
    "boldittheta" => "\x{1D73D}",  // mathematical bold italic small theta
    "bolditiota" => "\x{1D73E}",  // mathematical bold italic small iota
    "bolditkappa" => "\x{1D73F}",  // mathematical bold italic small kappa
    "bolditlambda" => "\x{1D740}",  // mathematical bold italic small lambda
    "bolditmu" => "\x{1D741}",  // mathematical bold italic small mu
    "bolditnu" => "\x{1D742}",  // mathematical bold italic small nu
    "bolditxi" => "\x{1D743}",  // mathematical bold italic small xi
    "bolditomicron" => "\x{1D744}",  // mathematical bold italic small omicron
    "bolditpi" => "\x{1D745}",  // mathematical bold italic small pi
    "bolditrho" => "\x{1D746}",  // mathematical bold italic small rho
    "bolditvarsigma" => "\x{1D747}",  // mathematical bold italic small final sigma
    "bolditsigma" => "\x{1D748}",  // mathematical bold italic small sigma
    "boldittau" => "\x{1D749}",  // mathematical bold italic small tau
    "bolditupsilon" => "\x{1D74A}",  // mathematical bold italic small upsilon
    "bolditphi" => "\x{1D74B}",  // mathematical bold italic small phi
    "bolditchi" => "\x{1D74C}",  // mathematical bold italic small chi
    "bolditpsi" => "\x{1D74D}",  // mathematical bold italic small psi
    "bolditomega" => "\x{1D74E}",  // mathematical bold italic small omega
    "bolditpartial" => "\x{1D74F}",  // mathematical bold italic partial differential
    "bolditvarepsilon" => "\x{1D750}",  // mathematical bold italic epsilon symbol
    "bolditvartheta" => "\x{1D751}",  // mathematical bold italic theta symbol
    "bolditvarkappa" => "\x{1D752}",  // mathematical bold italic kappa symbol
    "bolditvarphi" => "\x{1D753}",  // mathematical bold italic phi symbol
    "bolditvarrho" => "\x{1D754}",  // mathematical bold italic rho symbol
    "bolditvarpi" => "\x{1D755}",  // mathematical bold italic pi symbol
    "boldsansAlpha" => "\x{1D756}",  // mathematical sans-serif bold capital alpha
    "boldsansBeta" => "\x{1D757}",  // mathematical sans-serif bold capital beta
    "boldsansGamma" => "\x{1D758}",  // mathematical sans-serif bold capital gamma
    "boldsansDelta" => "\x{1D759}",  // mathematical sans-serif bold capital delta
    "boldsansEpsilon" => "\x{1D75A}",  // mathematical sans-serif bold capital epsilon
    "boldsansZeta" => "\x{1D75B}",  // mathematical sans-serif bold capital zeta
    "boldsansEta" => "\x{1D75C}",  // mathematical sans-serif bold capital eta
    "boldsansTheta" => "\x{1D75D}",  // mathematical sans-serif bold capital theta
    "boldsansIota" => "\x{1D75E}",  // mathematical sans-serif bold capital iota
    "boldsansKappa" => "\x{1D75F}",  // mathematical sans-serif bold capital kappa
    "boldsansLambda" => "\x{1D760}",  // mathematical sans-serif bold capital lambda
    "boldsansMu" => "\x{1D761}",  // mathematical sans-serif bold capital mu
    "boldsansNu" => "\x{1D762}",  // mathematical sans-serif bold capital nu
    "boldsansXi" => "\x{1D763}",  // mathematical sans-serif bold capital xi
    "boldsansOmicron" => "\x{1D764}",  // mathematical sans-serif bold capital omicron
    "boldsansPi" => "\x{1D765}",  // mathematical sans-serif bold capital pi
    "boldsansRho" => "\x{1D766}",  // mathematical sans-serif bold capital rho
    "boldsansvarTheta" => "\x{1D767}",  // mathematical sans-serif bold capital theta symbol
    "boldsansSigma" => "\x{1D768}",  // mathematical sans-serif bold capital sigma
    "boldsansTau" => "\x{1D769}",  // mathematical sans-serif bold capital tau
    "boldsansUpsilon" => "\x{1D76A}",  // mathematical sans-serif bold capital upsilon
    "boldsansPhi" => "\x{1D76B}",  // mathematical sans-serif bold capital phi
    "boldsansChi" => "\x{1D76C}",  // mathematical sans-serif bold capital chi
    "boldsansPsi" => "\x{1D76D}",  // mathematical sans-serif bold capital psi
    "boldsansOmega" => "\x{1D76E}",  // mathematical sans-serif bold capital omega
    "boldsansnabla" => "\x{1D76F}",  // mathematical sans-serif bold nabla
    "boldsansalpha" => "\x{1D770}",  // mathematical sans-serif bold small alpha
    "boldsansbeta" => "\x{1D771}",  // mathematical sans-serif bold small beta
    "boldsansgamma" => "\x{1D772}",  // mathematical sans-serif bold small gamma
    "boldsansdelta" => "\x{1D773}",  // mathematical sans-serif bold small delta
    "boldsansepsilon" => "\x{1D774}",  // mathematical sans-serif bold small epsilon
    "boldsanszeta" => "\x{1D775}",  // mathematical sans-serif bold small zeta
    "boldsanseta" => "\x{1D776}",  // mathematical sans-serif bold small eta
    "boldsanstheta" => "\x{1D777}",  // mathematical sans-serif bold small theta
    "boldsansiota" => "\x{1D778}",  // mathematical sans-serif bold small iota
    "boldsanskappa" => "\x{1D779}",  // mathematical sans-serif bold small kappa
    "boldsanslambda" => "\x{1D77A}",  // mathematical sans-serif bold small lambda
    "boldsansmu" => "\x{1D77B}",  // mathematical sans-serif bold small mu
    "boldsansnu" => "\x{1D77C}",  // mathematical sans-serif bold small nu
    "boldsansxi" => "\x{1D77D}",  // mathematical sans-serif bold small xi
    "boldsansomicron" => "\x{1D77E}",  // mathematical sans-serif bold small omicron
    "boldsanspi" => "\x{1D77F}",  // mathematical sans-serif bold small pi
    "boldsansrho" => "\x{1D780}",  // mathematical sans-serif bold small rho
    "boldsansvarsigma" => "\x{1D781}",  // mathematical sans-serif bold small final sigma
    "boldsanssigma" => "\x{1D782}",  // mathematical sans-serif bold small sigma
    "boldsanstau" => "\x{1D783}",  // mathematical sans-serif bold small tau
    "boldsansupsilon" => "\x{1D784}",  // mathematical sans-serif bold small upsilon
    "boldsansphi" => "\x{1D785}",  // mathematical sans-serif bold small phi
    "boldsanschi" => "\x{1D786}",  // mathematical sans-serif bold small chi
    "boldsanspsi" => "\x{1D787}",  // mathematical sans-serif bold small psi
    "boldsansomega" => "\x{1D788}",  // mathematical sans-serif bold small omega
    "boldsanspartial" => "\x{1D789}",  // mathematical sans-serif bold partial differential
    "boldsansvarepsilon" => "\x{1D78A}",  // mathematical sans-serif bold epsilon symbol
    "boldsansvartheta" => "\x{1D78B}",  // mathematical sans-serif bold theta symbol
    "boldsansvarkappa" => "\x{1D78C}",  // mathematical sans-serif bold kappa symbol
    "boldsansvarphi" => "\x{1D78D}",  // mathematical sans-serif bold phi symbol
    "boldsansvarrho" => "\x{1D78E}",  // mathematical sans-serif bold rho symbol
    "boldsansvarpi" => "\x{1D78F}",  // mathematical sans-serif bold pi symbol
#if 0
    bolditalicsans*"Alpha" => "\x{1D790}",  // mathematical sans-serif bold italic capital alpha
    bolditalicsans*"Beta" => "\x{1D791}",  // mathematical sans-serif bold italic capital beta
    bolditalicsans*"Gamma" => "\x{1D792}",  // mathematical sans-serif bold italic capital gamma
    bolditalicsans*"Delta" => "\x{1D793}",  // mathematical sans-serif bold italic capital delta
    bolditalicsans*"Epsilon" => "\x{1D794}",  // mathematical sans-serif bold italic capital epsilon
    bolditalicsans*"Zeta" => "\x{1D795}",  // mathematical sans-serif bold italic capital zeta
    bolditalicsans*"Eta" => "\x{1D796}",  // mathematical sans-serif bold italic capital eta
    bolditalicsans*"Theta" => "\x{1D797}",  // mathematical sans-serif bold italic capital theta
    bolditalicsans*"Iota" => "\x{1D798}",  // mathematical sans-serif bold italic capital iota
    bolditalicsans*"Kappa" => "\x{1D799}",  // mathematical sans-serif bold italic capital kappa
    bolditalicsans*"Lambda" => "\x{1D79A}",  // mathematical sans-serif bold italic capital lambda
    bolditalicsans*"Mu" => "\x{1D79B}",  // mathematical sans-serif bold italic capital mu
    bolditalicsans*"Nu" => "\x{1D79C}",  // mathematical sans-serif bold italic capital nu
    bolditalicsans*"Xi" => "\x{1D79D}",  // mathematical sans-serif bold italic capital xi
    bolditalicsans*"Omicron" => "\x{1D79E}",  // mathematical sans-serif bold italic capital omicron
    bolditalicsans*"Pi" => "\x{1D79F}",  // mathematical sans-serif bold italic capital pi
    bolditalicsans*"Rho" => "\x{1D7A0}",  // mathematical sans-serif bold italic capital rho
    bolditalicsans*"varTheta" => "\x{1D7A1}",  // mathematical sans-serif bold italic capital theta symbol
    bolditalicsans*"Sigma" => "\x{1D7A2}",  // mathematical sans-serif bold italic capital sigma
    bolditalicsans*"Tau" => "\x{1D7A3}",  // mathematical sans-serif bold italic capital tau
    bolditalicsans*"Upsilon" => "\x{1D7A4}",  // mathematical sans-serif bold italic capital upsilon
    bolditalicsans*"Phi" => "\x{1D7A5}",  // mathematical sans-serif bold italic capital phi
    bolditalicsans*"Chi" => "\x{1D7A6}",  // mathematical sans-serif bold italic capital chi
    bolditalicsans*"Psi" => "\x{1D7A7}",  // mathematical sans-serif bold italic capital psi
    bolditalicsans*"Omega" => "\x{1D7A8}",  // mathematical sans-serif bold italic capital omega
    bolditalicsans*"nabla" => "\x{1D7A9}",  // mathematical sans-serif bold italic nabla
    bolditalicsans*"alpha" => "\x{1D7AA}",  // mathematical sans-serif bold italic small alpha
    bolditalicsans*"beta" => "\x{1D7AB}",  // mathematical sans-serif bold italic small beta
    bolditalicsans*"gamma" => "\x{1D7AC}",  // mathematical sans-serif bold italic small gamma
    bolditalicsans*"delta" => "\x{1D7AD}",  // mathematical sans-serif bold italic small delta
    bolditalicsans*"epsilon" => "\x{1D7AE}",  // mathematical sans-serif bold italic small epsilon
    bolditalicsans*"zeta" => "\x{1D7AF}",  // mathematical sans-serif bold italic small zeta
    bolditalicsans*"eta" => "\x{1D7B0}",  // mathematical sans-serif bold italic small eta
    bolditalicsans*"theta" => "\x{1D7B1}",  // mathematical sans-serif bold italic small theta
    bolditalicsans*"iota" => "\x{1D7B2}",  // mathematical sans-serif bold italic small iota
    bolditalicsans*"kappa" => "\x{1D7B3}",  // mathematical sans-serif bold italic small kappa
    bolditalicsans*"lambda" => "\x{1D7B4}",  // mathematical sans-serif bold italic small lambda
    bolditalicsans*"mu" => "\x{1D7B5}",  // mathematical sans-serif bold italic small mu
    bolditalicsans*"nu" => "\x{1D7B6}",  // mathematical sans-serif bold italic small nu
    bolditalicsans*"xi" => "\x{1D7B7}",  // mathematical sans-serif bold italic small xi
    bolditalicsans*"omicron" => "\x{1D7B8}",  // mathematical sans-serif bold italic small omicron
    bolditalicsans*"pi" => "\x{1D7B9}",  // mathematical sans-serif bold italic small pi
    bolditalicsans*"rho" => "\x{1D7BA}",  // mathematical sans-serif bold italic small rho
    bolditalicsans*"varsigma" => "\x{1D7BB}",  // mathematical sans-serif bold italic small final sigma
    bolditalicsans*"sigma" => "\x{1D7BC}",  // mathematical sans-serif bold italic small sigma
    bolditalicsans*"tau" => "\x{1D7BD}",  // mathematical sans-serif bold italic small tau
    bolditalicsans*"upsilon" => "\x{1D7BE}",  // mathematical sans-serif bold italic small upsilon
    bolditalicsans*"phi" => "\x{1D7BF}",  // mathematical sans-serif bold italic small phi
    bolditalicsans*"chi" => "\x{1D7C0}",  // mathematical sans-serif bold italic small chi
    bolditalicsans*"psi" => "\x{1D7C1}",  // mathematical sans-serif bold italic small psi
    bolditalicsans*"omega" => "\x{1D7C2}",  // mathematical sans-serif bold italic small omega
    bolditalicsans*"partial" => "\x{1D7C3}",  // mathematical sans-serif bold italic partial differential
    bolditalicsans*"varepsilon" => "\x{1D7C4}",  // mathematical sans-serif bold italic epsilon symbol
    bolditalicsans*"vartheta" => "\x{1D7C5}",  // mathematical sans-serif bold italic theta symbol
    bolditalicsans*"varkappa" => "\x{1D7C6}",  // mathematical sans-serif bold italic kappa symbol
    bolditalicsans*"varphi" => "\x{1D7C7}",  // mathematical sans-serif bold italic phi symbol
    bolditalicsans*"varrho" => "\x{1D7C8}",  // mathematical sans-serif bold italic rho symbol
    bolditalicsans*"varpi" => "\x{1D7C9}",  // mathematical sans-serif bold italic pi symbol
#endif
    "boldDigamma" => "\x{1d7c}\x{61}",  // mathematical bold capital digamma
    "bolddigamma" => "\x{1d7c}\x{62}",  // mathematical bold small digamma
    "boldzero" => "\x{1D7CE}",  // mathematical bold digit 0
    "boldone" => "\x{1D7CF}",  // mathematical bold digit 1
    "boldtwo" => "\x{1D7D0}",  // mathematical bold digit 2
    "boldthree" => "\x{1D7D1}",  // mathematical bold digit 3
    "boldfour" => "\x{1D7D2}",  // mathematical bold digit 4
    "boldfive" => "\x{1D7D3}",  // mathematical bold digit 5
    "boldsix" => "\x{1D7D4}",  // mathematical bold digit 6
    "boldseven" => "\x{1D7D5}",  // mathematical bold digit 7
    "boldeight" => "\x{1D7D6}",  // mathematical bold digit 8
    "boldnine" => "\x{1D7D7}",  // mathematical bold digit 9
    "bbzero" => "\x{1D7D8}",  // mathematical double-struck digit 0
    "bbone" => "\x{1D7D9}",  // mathematical double-struck digit 1
    "bbtwo" => "\x{1D7DA}",  // mathematical double-struck digit 2
    "bbthree" => "\x{1D7DB}",  // mathematical double-struck digit 3
    "bbfour" => "\x{1D7DC}",  // mathematical double-struck digit 4
    "bbfive" => "\x{1D7DD}",  // mathematical double-struck digit 5
    "bbsix" => "\x{1D7DE}",  // mathematical double-struck digit 6
    "bbseven" => "\x{1D7DF}",  // mathematical double-struck digit 7
    "bbeight" => "\x{1D7E0}",  // mathematical double-struck digit 8
    "bbnine" => "\x{1D7E1}",  // mathematical double-struck digit 9
    "sanszero" => "\x{1D7E2}",  // mathematical sans-serif digit 0
    "sansone" => "\x{1D7E3}",  // mathematical sans-serif digit 1
    "sanstwo" => "\x{1D7E4}",  // mathematical sans-serif digit 2
    "sansthree" => "\x{1D7E5}",  // mathematical sans-serif digit 3
    "sansfour" => "\x{1D7E6}",  // mathematical sans-serif digit 4
    "sansfive" => "\x{1D7E7}",  // mathematical sans-serif digit 5
    "sanssix" => "\x{1D7E8}",  // mathematical sans-serif digit 6
    "sansseven" => "\x{1D7E9}",  // mathematical sans-serif digit 7
    "sanseight" => "\x{1D7EA}",  // mathematical sans-serif digit 8
    "sansnine" => "\x{1D7EB}",  // mathematical sans-serif digit 9
    "boldsanszero" => "\x{1D7EC}",  // mathematical sans-serif bold digit 0
    "boldsansone" => "\x{1D7ED}",  // mathematical sans-serif bold digit 1
    "boldsanstwo" => "\x{1D7EE}",  // mathematical sans-serif bold digit 2
    "boldsansthree" => "\x{1D7EF}",  // mathematical sans-serif bold digit 3
    "boldsansfour" => "\x{1D7F0}",  // mathematical sans-serif bold digit 4
    "boldsansfive" => "\x{1D7F1}",  // mathematical sans-serif bold digit 5
    "boldsanssix" => "\x{1D7F2}",  // mathematical sans-serif bold digit 6
    "boldsansseven" => "\x{1D7F3}",  // mathematical sans-serif bold digit 7
    "boldsanseight" => "\x{1D7F4}",  // mathematical sans-serif bold digit 8
    "boldsansnine" => "\x{1D7F5}",  // mathematical sans-serif bold digit 9
#if 0
    mono*"zero" => "\x{1D7F6}",  // mathematical monospace digit 0
    mono*"one" => "\x{1D7F7}",  // mathematical monospace digit 1
    mono*"two" => "\x{1D7F8}",  // mathematical monospace digit 2
    mono*"three" => "\x{1D7F9}",  // mathematical monospace digit 3
    mono*"four" => "\x{1D7FA}",  // mathematical monospace digit 4
    mono*"five" => "\x{1D7FB}",  // mathematical monospace digit 5
    mono*"six" => "\x{1D7FC}",  // mathematical monospace digit 6
    mono*"seven" => "\x{1D7FD}",  // mathematical monospace digit 7
    mono*"eight" => "\x{1D7FE}",  // mathematical monospace digit 8
    mono*"nine" => "\x{1D7FF}",  // mathematical monospace digit 9
#endif

    "triangleright" => "\x{25B7}",  // (large) right triangle, open; z notation range restriction
    "triangleleft" => "\x{25C1}",  // (large) left triangle, open; z notation domain restriction
    "leftouterjoin" => "\x{27D5}",  // left outer join
    "rightouterjoin" => "\x{27D6}",  // right outer join
    "fullouterjoin" => "\x{27D7}",  // full outer join
    "Join" => "\x{2A1D}",  // join
    "join" => "\x{2A1D}",  // join
    "underbar" => "\x{332}",  // combining low line
    "underleftrightarrow" => "\x{34D}",  // underleftrightarrow accent
    "leftwavearrow" => "\x{219C}",  // left arrow-wavy
    "rightwavearrow" => "\x{219D}",  // right arrow-wavy
    "varbarwedge" => "\x{2305}",  // /barwedge b: logical and, bar above [projective (bar over small wedge)]
    "smallblacktriangleright" => "\x{25B8}",  // right triangle, filled
    "smallblacktriangleleft" => "\x{25C2}",  // left triangle, filled
    "leftmoon" => "\x{263E}",  // last quarter moon
    "smalltriangleright" => "\x{25B9}",  // right triangle, open
    "smalltriangleleft" => "\x{25C3}",  // left triangle, open

    "tricolon" => "\x{205D}",  // tricolon

    // fractions
    "1/4" => "\x{BC}", // vulgar fraction one quarter
    "1/2" => "\x{BD}", // vulgar fraction one half
    "3/4" => "\x{BE}", // vulgar fraction three quarters
    "1/7" => "\x{2150}", // vulgar fraction one seventh
    "1/9" => "\x{2151}", // vulgar fraction one ninth
    "1/10" => "\x{2152}", // vulgar fraction one tenth
    "1/3" => "\x{2153}", // vulgar fraction one third
    "2/3" => "\x{2154}", // vulgar fraction two thirds
    "1/5" => "\x{2155}", // vulgar fraction one fifth
    "2/5" => "\x{2156}", // vulgar fraction two fifths
    "3/5" => "\x{2157}", // vulgar fraction three fifths
    "4/5" => "\x{2158}", // vulgar fraction four fifths
    "1/6" => "\x{2159}", // vulgar fraction one sixth
    "5/6" => "\x{215A}", // vulgar fraction five sixths
    "1/8" => "\x{215B}", // vulgar fraction one eigth
    "3/8" => "\x{215C}", // vulgar fraction three eigths
    "5/8" => "\x{215D}", // vulgar fraction five eigths
    "7/8" => "\x{215E}", // vulgar fraction seventh eigths
    "1/" => "\x{215F}", // fraction numerator one
    "0/3" => "\x{2189}", // vulgar fraction zero thirds
    "1/4" => "\x{BC}", // vulgar fraction one quarter
};
static int _julia_list_unicode_names(_str lastid,
                                     int &num_matches,
                                     int max_matches,
                                     bool exact_match,
                                     bool case_sensitive)
{
   doFuzzyMatching := ((_GetCodehelpFlags() & VSCODEHELPFLAG_COMPLETION_NO_FUZZY_MATCHES) == 0);

   //say("_CSSListKeywords("lastid","lastid_prefix","p_mode_name","keyword_class","keyword_name")");
   // look up the lexer definition for the current mode
   //_str lexer_name=p_EmbeddedLexerName;
   //if (lexer_name=="") {
   //   lexer_name=p_lexer_name;
   //}
   // create a temporary view and search for the keywords
   foreach (auto k => auto v in unicode_name_to_char) {
      if (beginsWith(k,lastid)) {
         _julia_insert_context_tag_item(k,
                                   lastid,
                                   num_matches, max_matches,
                                   exact_match, case_sensitive);
      } else if (case_sensitive && doFuzzyMatching && tag_matches_prefix_with_corrections(lastid, k, exact_match, case_sensitive, 1)) {
         _julia_insert_context_tag_item(k,
                                        lastid,
                                        num_matches, max_matches,
                                        exact_match, case_sensitive);
      }
   }
   return(0);
}
int _julia_find_context_tags(_str (&errorArgs)[],_str prefixexp,
                              _str lastid,int lastidstart_offset,
                              int info_flags,typeless otherinfo,
                              bool find_parents,int max_matches,
                              bool exact_match, bool case_sensitive,
                              SETagFilterFlags filter_flags=SE_TAG_FILTER_ANYTHING,
                              SETagContextFlags context_flags=SE_TAG_CONTEXT_ALLOW_LOCALS,
                              VS_TAG_RETURN_TYPE (&visited):[]=null, int depth=0,
                              VS_TAG_RETURN_TYPE &prefix_rt=null)
{
   if (!_haveContextTagging()) {
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   if (prefixexp=='\') {
      tag_return_type_init(prefix_rt);
      errorArgs._makeempty();
      num_matches := 0;
      AutoCompleteAllowWholeWordKeepList(true);
      _julia_list_unicode_names(lastid, num_matches,max_matches, exact_match,case_sensitive);
      return num_matches;
   }
   return _java_find_context_tags(errorArgs,prefixexp,lastid,lastidstart_offset,
                                  info_flags,otherinfo,find_parents,max_matches,
                                  exact_match,case_sensitive,
                                  filter_flags,context_flags,
                                  visited,depth,prefix_rt);
}


int _julia_parse_return_type(_str (&errorArgs)[], typeless tag_files,
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

int _julia_analyze_return_type(_str (&errorArgs)[],typeless tag_files,
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
int _julia_get_type_of_expression(_str (&errorArgs)[], 
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

int _julia_insert_constants_of_type(struct VS_TAG_RETURN_TYPE &rt_expected,
                                     int tree_wid, int tree_index,
                                     _str lastid_prefix="", 
                                     bool exact_match=false, bool case_sensitive=true,
                                     _str param_name="", _str param_default="",
                                     struct VS_TAG_RETURN_TYPE (&visited):[]=null, int depth=0)
{
   return _java_insert_constants_of_type(rt_expected,
                                         tree_wid,tree_index,
                                         lastid_prefix,
                                         exact_match,case_sensitive,
                                         param_name, param_default,
                                         visited, depth);
}

int _julia_match_return_type(struct VS_TAG_RETURN_TYPE &rt_expected,
                             struct VS_TAG_RETURN_TYPE &rt_candidate,
                             _str tag_name,_str type_name,
                             SETagFlags tag_flags,
                             _str file_name, int line_no,
                             _str prefixexp,typeless tag_files,
                             int tree_wid, int tree_index)
{
   return 0;
}

int _julia_fcthelp_get_start(_str (&errorArgs)[],
                              bool OperatorTyped,
                              bool cursorInsideArgumentList,
                              int &FunctionNameOffset,
                              int &ArgumentStartOffset,
                              int &flags,
                              int depth=0)
{
   return(_c_fcthelp_get_start(errorArgs,OperatorTyped,cursorInsideArgumentList,FunctionNameOffset,ArgumentStartOffset,flags,depth));
}

int _julia_fcthelp_get(_str (&errorArgs)[],
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

void _julia_autocomplete_replace_symbol(_str insertWord,_str prefix,int &removeStartCol,int &removeLen,bool onlyInsertWord,struct VS_TAG_BROWSE_INFO symbol) {
   p_col -= length(prefix);
   //say('insertWord='insertWord' prefix='prefix' col='p_col);
   if (!onlyInsertWord && p_col>1 && get_text(1,(typeless)point('S')-1)=='\' && unicode_name_to_char._indexin(insertWord)/* && prefix:==insertWord*/) {
      --p_col;
      _delete_text(length(prefix)+1);
      //removeStartCol=p_col;
      //removeLen=length(prefix)+1;
      _insert_text(unicode_name_to_char:[insertWord]);
      return;
   }
   //removeStartCol=p_col;
   //removeLen=length(prefix);
   _delete_text(length(prefix));
   _insert_text(insertWord);
}

int _julia_get_type_of_prefix(_str (&errorArgs)[], _str prefixexp,
                             struct VS_TAG_RETURN_TYPE &rt, 
                             VS_TAG_RETURN_TYPE (&visited):[]=null, int depth=0,
                             CodeHelpExpressionPrefixFlags prefix_flags=VSCODEHELP_PREFIX_NULL,_str search_class_name='')
{
   if (!_haveContextTagging()) {
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   if (prefixexp=='\') {
      rt.return_type='\';
      return 0;
   }
   //typeless tag_files = tags_filenamea(p_LangId);
   //if (p_LangId == "js") tag_files = tags_filenamea("java");
   tag_push_matches();
#if 0
   cfg:=_clex_find(0,'G');
   if (cfg!=CFG_STRING && cfg!=CFG_COMMENT) {
      // (\\([\^_][a-zA-Z0-9]@|  :d(/(:d|)|)|   \^[+\-=()!]|_[+\-=()]|)|)

      // (\\([\^_][a-zA-Z0-9]@|:d(/(:d|)|)|\^[+\-=()!]|_[+\-=()]|)|)
      status:=search('(\\([\^_][a-zA-Z0-9]@|:d(/(:d|)|)|\^[+\-=()!]|_[+\-=()]|)|)','@r-');
      if (!status && match_length()>0) {
         id:=get_match_text('')
      }


      prefixexp='\';
   }
#endif
   status := _c_get_type_of_prefix(errorArgs, 
                                  prefixexp, rt, 
                                  visited, depth, 
                                  prefix_flags, 
                                  search_class_name);
   //status := _c_get_type_of_prefix_recursive(errorArgs, tag_files, prefixexp, rt, visited, depth, prefix_flags);
   tag_pop_matches();
   return status;
}
static int _julia_get_slash_prefix_info(_str &word,int &start_col) {
   int status;
   //say('word='word);
   extra_chars := "";
   word_chars := _clex_identifier_chars():+_extra_word_chars;
   save_pos(auto p);

   cfg:=_clex_find(0,'G');
   if (cfg!=CFG_STRING && cfg!=CFG_COMMENT) {
      //say('b4 col='p_col);
      word_char_set:='['word_chars']';
      //status:=search('(\\(:d/:d|:d/|:d|[\^_]([+\-=()!]|'word_char_set':1,10|))|)', '@-rh');
      status=search('(\\(:d/:d|:d/|:d|[\^_]([+\-=()!]|'word_char_set':1,10|)|'word_char_set':1,10)|)', '@-rh');
      //status:=search('(\\(:d/:d|:d/|:d)|)', '@-rh');
      //say('status='status' len='match_length()' col='p_col);
      if (!status) {
         if (match_length()==0) {
            restore_pos(p);
         } else {
            word=substr(get_match_text(''),2);
            //say('word='word);
            start_col=p_col+1;

            restore_pos(p);

            return 0;
         }
      }
   }
   return VSCODEHELPRC_CONTEXT_NOT_VALID;
}

int _julia_autocomplete_get_prefix(_str &word,int &start_col,_str &complete_arg,int &start_word_col,AUTO_COMPLETE_RESULTS &AutoCompleteResults,bool forceUpdate,bool isListSymbols)
{
/*
    (\\(:d|:d/:d|:d/|[\^_]([+\-=()!]|))|)
 
  \1/4  --> \x{BC}
  \^0   --> Superscript 0
  \_0   --> Subscript 0
 
"^+" = > "\x{207A}",
"^-" = > "\x{207B}",
"^=" = > "\x{207C}",
"^(" = > "\x{207D}",
"^)" = > "\x{207E}",
"^!" = > "\x{A71D}",

// Subscripts
"_+" = > "\x{208A}",
"_-" = > "\x{208B}",
"_=" = > "\x{208C}",
"_(" = > "\x{208D}",
"_)" = > "\x{208E}",
 
*/

   //status := search('['word_chars']#|$', '@-rh');

   int status;
   //say('word='word);
   status= _julia_get_slash_prefix_info(word,start_col);
   if (!status) {
      AutoCompleteResults.end_col=start_col+length(word);
      auto_complete_minimum := AutoCompleteGetMinimumLength(p_LangId);
      if (!forceUpdate && !isListSymbols && AutoCompleteResults.column - start_col < auto_complete_minimum) {
         return VSCODEHELPRC_CONTEXT_NOT_VALID;
      }
      /*if ((!forceUpdate && !isListSymbols) || (AutoCompleteResults.column - start_col < auto_complete_minimum)) {
         return VSCODEHELPRC_CONTEXT_NOT_VALID;
      } */
      //say('return 0');
      return 0;
   }

   extra_chars := "";
   word_chars := _clex_identifier_chars():+_extra_word_chars;
   save_pos(auto p);

   left();
   ch := get_text();
   restore_pos(p);
   if (!forceUpdate && !isListSymbols &&
       !pos('^['extra_chars:+word_chars']$',ch,1,'re')) {
      //AutoCompleteTerminate();
      //p_window_id = orig_wid;
      //say("AutoCompleteUpdateInfo: ON FIRST CHAR OF IDENTIFIER");
      return VSCODEHELPRC_CONTEXT_NOT_VALID;
   }

   // Verify that the prefix length is long enough
   status = search('['word_chars']#|$', '@-rh');
   if (status < 0 || at_end_of_line()) {
      restore_pos(p);
      return VSCODEHELPRC_CONTEXT_NOT_VALID;
      if (forceUpdate || isListSymbols) {
         start_col = AutoCompleteResults.column;
      } else {
         //AutoCompleteTerminate();
         //p_window_id = orig_wid;
         //say("AutoCompleteUpdateInfo: PREFIX LENGTH TOO SHORT");
         return VSCODEHELPRC_CONTEXT_NOT_VALID;
         //return 0;
      }
   } else {
      start_col = p_col;
      ch = get_text();
   }

   // verify that we landed in the same word we started in
   save_pos(auto start_p);
   status = search('[^'extra_chars:+word_chars']|$', '@rh');
   if (status < 0 || p_col < AutoCompleteResults.column) {
      restore_pos(p);
      return VSCODEHELPRC_CONTEXT_NOT_VALID;
      if (forceUpdate || isListSymbols) {
         start_col = AutoCompleteResults.column;
         AutoCompleteResults.end_col = start_col;
         ch = get_text();
      } else {
         //AutoCompleteTerminate();
         //p_window_id = orig_wid;
         //say("AutoCompleteUpdateInfo: NOT IN WORD ANYMORE");
         return VSCODEHELPRC_CONTEXT_NOT_VALID;
      }
   } else {
      AutoCompleteResults.end_col = p_col;
      restore_pos(start_p);
   }

   if (!forceUpdate && isdigit(ch)) {
      restore_pos(p);
      //AutoCompleteTerminate();
      //p_window_id = orig_wid;
      //say("AutoCompleteUpdateInfo: SITTING ON NUMBER");
      return VSCODEHELPRC_CONTEXT_NOT_VALID;
   }
   if (AutoCompleteResults.column > start_col) {
      word = get_text(AutoCompleteResults.column-start_col);
      //gAutoCompleteResults.prefix = get_text(gAutoCompleteResults.column-start_col);
   } else {
      word='';
      //gAutoCompleteResults.prefix = "";
   }
   restore_pos(p);
   auto_complete_minimum := AutoCompleteGetMinimumLength(p_LangId);
   if (!forceUpdate && !isListSymbols && AutoCompleteResults.column - start_col < auto_complete_minimum) {
      return VSCODEHELPRC_CONTEXT_NOT_VALID;
   }
   //say('start_col='start_col);
   //say('AutoCompleteResults.column='AutoCompleteResults.column);
   //say('out word='word'>');
   //say('auto_complete_minimum='auto_complete_minimum);
   if (length(word)<auto_complete_minimum) {
      return VSCODEHELPRC_CONTEXT_NOT_VALID;
   }
   return 0;
}

#if 0
int _julia_get_expression_info(bool PossibleOperator, VS_TAG_IDEXP_INFO &info,
                              VS_TAG_RETURN_TYPE (&visited):[]=null, int depth=0)
{
   say('h1');
   cfg:=_clex_find(0,'G');
   if (cfg!=CFG_COMMENT && cfg!=CFG_STRING) {
      status:= _julia_get_slash_prefix_info(auto word,auto start_col);
      if (!status) {
         info.lastid='\';
         info.lastidstart_col=start_col;
         info.lastidstart_offset=_text_colc(start_col,'P');
         info.prefixexp='\';
         info.prefixexpstart_offset=info.lastidstart_offset-1;
         info.cursor_col=p_col;
         return 0;
      }
   }
   return _c_get_expression_info(PossibleOperator, info, visited, depth);
}
#endif

bool _julia_custom_tab_action() {
   int SmartTab=_LangGetPropertyInt32(p_LangId,VSLANGPROPNAME_SMART_TAB);
   if (SmartTab != VSSMARTTAB_ALWAYS_REINDENT) {
      cfg:=_clex_find(0,'G');
      if (cfg!=CFG_COMMENT && cfg!=CFG_STRING) {
         status:= _julia_get_slash_prefix_info(auto word,auto start_col);
         if (!status) {
            if (unicode_name_to_char._indexin(word)) {
               p_col=start_col-1;
               _delete_text(length(word)+1);
               //removeStartCol=p_col;
               //removeLen=length(prefix)+1;
               _insert_text(unicode_name_to_char:[word]);
               return true;
            }
            list_symbols();
            return true;
         }
      }
   }
   return false;
}


static _str guessJuliaExePath(_str command = "julia"EXTENSION_EXE)
{
   juliaPath:=_GetCachedExePath(def_julia_exe_path,_julia_cached_exe_path,"julia"EXTENSION_EXE);
   if( file_exists(juliaPath)) {
      // No guessing necessary
      juliaPath = _strip_filename(juliaPath, 'N');
      return juliaPath;
   }

   do {
      command = _replace_envvars2(command);

#if 0
      // first check their GOROOT environment variable
      juliaPath = get_env("GOROOT");
      if (juliaPath != "") {
         _maybe_append_filesep(juliaPath);
         juliaPath :+= "bin" :+ FILESEP :+ "go" :+ command;
         if (!file_exists(juliaPath)) {
            juliaPath = "";
         }
      }
#endif

      // try a plain old path search
      juliaPath = path_search(command, "", 'P');
      if (juliaPath != "") {
         juliaPath = _strip_filename(juliaPath, 'N');
         break;
      }

      juliaPath = _orig_path_search(command);
      if (juliaPath != "") {
         _restore_origenv(true);
         juliaPath = _strip_filename(juliaPath, 'N');
         break;
      }
#if 0
      // maybe check the registry
      if (_isWindows()) {
          juliaPath = GetWindowsGoPath(command);
          if (juliaPath != "") {
             _maybe_append_filesep(juliaPath);
             juliaPath :+= "bin";
             break;
          }
      }
#endif

      // look for gofmt, since there may be other things named go
      juliaPath = path_search("julia", "", "P");
      if (juliaPath != "") {
         juliaPath = _strip_filename(juliaPath, 'N');
         break;
      }
#if 0
      // /usr/local/go is the default package installation path on MacOS
      if (juliaPath=="" && _isUnix() && file_exists("/usr/local/go/bin/gofmt")) {
         juliaPath = "/usr/local/go/bin";
         break;
      }

      // /opt/go is also a reasonable place on Unix
      if (juliaPath=="" && _isUnix() && file_exists("/opt/go/bin/gofmt")) {
         juliaPath = "/opt/go/bin";
         break;
      }

      // check for cygwin version
      if (_isWindows()) {
         juliaPath = _path2cygwin("/bin/gofmt.exe");
         if (juliaPath != "") {
            juliaPath = _cygwin2dospath(juliaPath);
            if (juliaPath != "") {
               juliaPath = _strip_filename(juliaPath, 'N');
               break;
            }
         }
      }
#endif

   } while (false);

   if (juliaPath != "") {
      _maybe_append_filesep(juliaPath);
      _julia_cached_exe_path = juliaPath :+ "julia" :+ EXTENSION_EXE;
   } else {
      // clear it out, it's no good
      _julia_cached_exe_path = "";
   }

   return _julia_cached_exe_path;
}
/**
 * Callback called from _project_command to prepare the 
 * environment for running Julia command-line interpreter. 
 * The value found in def_julia_exe_path takes precedence. If 
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
int  _julia_set_environment(int projectHandle, _str config, _str target,
                               bool quiet, _str error_hint)
{
   return set_julia_environment();
}

int set_julia_environment(_str command="julia"EXTENSION_EXE)
{
   juliaExePath := guessJuliaExePath(command);
   // restore the original environment.  this is done so the
   // path for julia is not appended over and over
   _restore_origenv(false);
   if (juliaExePath == "") {
      // Prompt user for interpreter
      int status = _MDICurrent().textBoxDialog("Julia Executable",
                                      0,
                                      0,
                                      "",
                                      "OK,Cancel:_cancel\tSpecify the path to 'julia"EXTENSION_EXE"'.",  // Button List
                                      "",
                                      "-c "FILENOQUOTES_ARG:+_chr(0)"-bf Julia Executable Path:");
      if( status < 0 ) {
         // Probably COMMAND_CANCELLED_RC
         return status;
      }

      // Save the values entered and mark the configuration as modified
      def_julia_exe_path = _param1;
      _julia_cached_exe_path="";
      _config_modify_flags(CFGMODIFY_DEFVAR);

      juliaExePath = def_julia_exe_path;
   }

   // Set the environment
   juliaExeCommand := juliaExePath;
   if (!_file_eq(_strip_filename(juliaExePath,'PE'), "julia")) {
      _maybe_append(juliaExePath, FILESEP);
      juliaExeCommand = juliaExePath:+command;
   }
   set_env(JULIA_EXE_ENV_VAR, juliaExeCommand);

   juliaDir := _strip_filename(juliaExePath, 'N');
   _maybe_strip_filesep(juliaDir);
   if (juliaDir != "") {

      // restore the original environment.  this is done so the
      // path for julia is not appended over and over
      _restore_origenv(false);

      // PATH
      _str path = _replace_envvars("%PATH%");
      _maybe_prepend(path, PATHSEP);
      path = juliaDir :+ path;
      set("PATH="path);
   }

#if 0
   // lastest version of 'julia' wants GOROOT set
   juliaRoot := _strip_filename(juliaDir, 'N');
   if (juliaRoot != "") {
      set_env("GOROOT", juliaRoot);
   }

   // set the extension for the os
   set_env(GO_OUTPUT_FILE_EXT_ENV_VAR, EXTENSION_EXE);
#endif
   // if this wasn't set, then we didn't find anything
   return (juliaExePath != ""?0:1);
}
int _julia_MaybeBuildTagFile(int &tfindex, bool withRefs=false, bool useThread=false, bool forceRebuild=false)
{
   if (!_haveContextTagging()) {
      return VSRC_FEATURE_REQUIRES_PRO_EDITION;
   }
   // maybe we can recycle tag file(s)
   lang := JULIA_LANGUAGE_ID;
   if (ext_MaybeRecycleTagFile(tfindex, auto tagfilename, lang) && !forceRebuild) {
      return 0;
   }

   // Try to guess where Go is installed
   juliaRoot := guessJuliaExePath("julia":+EXTENSION_EXE);
   if (juliaRoot != "") {
      juliaRoot=absolute(juliaRoot);
      // either   juliaroot/usr/bin/julia OR
      //          juliaroot/bin/julia
      //
      juliaRoot = strip(juliaRoot, 'T', FILESEP);
      juliaRoot = _strip_filename(juliaRoot, 'n');
      if (endsWith(juliaRoot,'usr':+FILESEP)) {
         juliaRoot = strip(juliaRoot, 'T', FILESEP);
         juliaRoot = _strip_filename(juliaRoot, 'n');
      }
   }

   // no go
   if (juliaRoot == "") return 1;

   _maybe_append_filesep(juliaRoot);
   julia_libpath:=juliaRoot:+'share/julia/';
   //std_libs:= _maybe_quote_filename(julia_libpath:+'base/*.jl')' ';
   std_libs:= _maybe_quote_filename(_getSysconfigMaybeFixPath("tagging":+FILESEP:+"builtins":+FILESEP:+'builtins.jl'))' ';
   std_libs:+= _maybe_quote_filename(julia_libpath:+'base/*.jl')' '_maybe_quote_filename(julia_libpath:+'stdlib/*.jl');
   std_libs:+= ' -E sysimg.jl';
   std_libs:+= ' -E **/test/**';
   std_libs:+= ' -E */TOML/benchmark/benchmarks.jl';
   std_libs:+= ' -E */TOML/docs/make.jl';
   std_libs:+= ' -E */nghttp2_jll/src/nghttp2_jll.jl';
   std_libs:+= ' -E */Downloads/.ci/change-uuid.jl';
   std_libs:+= ' -E */Statistics/docs/make.jl';
   std_libs:+= ' -E */Pkg/docs/generate.jl';
   std_libs:+= ' -E */Pkg/docs/make.jl';
   std_libs:+= ' -E */dSFMT_jll/src/dSFMT_jll.jl';
   std_libs:+= ' -E */NetworkOptions/.ci/change-uuid.jl';
   std_libs:+= ' -E */Tar/.ci/change-uuid.jl';
   std_libs:+= ' -E */p7zip_jll/src/p7zip_jll.jl';
   std_libs:+= ' -E */Pkg/ext/HistoricaStdlibGenerator/generate_historical_stdlibs.jl';
   std_libs:+= ' -E */LibCURL/gen/generate.jl';
   

   // Build and Save tag file
   return ext_BuildTagFile(tfindex, tagfilename, lang, 
                           "Julia Libraries", true, 
                           std_libs,
                           ext_builtins_path(lang),
                           withRefs, useThread);
}
