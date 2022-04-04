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
#import "se/lang/api/LanguageSettings.e"
#import "alias.e"
#import "autobracket.e"
#import "c.e"
#import "pmatch.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "surround.e"
#import "slickc.e"
#import "cutil.e"
#import "adaptiveformatting.e"
#import "codehelp.e"
#import "css.e"
#endregion
using se.lang.api.LanguageSettings;

_command void json_mode() name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_ICON)
{
   _SetEditorLanguage('json');
}
_command void terraform_mode() name_info(','VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY|VSARG2_ICON)
{
   _SetEditorLanguage('terraform');
}
static SYNTAX_EXPANSION_INFO json_space_words:[];
static SYNTAX_EXPANSION_INFO terraform_space_words:[];

static int json_expand_space() {
   orig_word := cur_word(auto startCol);
   if (orig_word != '') {
      SYNTAX_EXPANSION_INFO space_words:[];

      if (_LanguageInheritsFrom('terraform')) {
         space_words=terraform_space_words;
      } else {
         space_words=json_space_words;
      }
      word:=min_abbrev2(orig_word, space_words, "",
                       auto aliasfilename, true, false);
      if (!maybe_auto_expand_alias(orig_word, word, aliasfilename, auto expandResult)) {
         // if the function returned 0, that means it handled the space bar
         // however, we need to return whether the expansion was successful
         return expandResult;
      }
   }
   return 1;
}
_command void json_space() name_info(','VSARG2_MULTI_CURSOR|VSARG2_CMDLINE|VSARG2_REQUIRES_EDITORCTL|VSARG2_LASTKEY)
{
   if (command_state()) {
      call_root_key(' ');
   }
   typeless orig_values;
   int embedded_status=_EmbeddedStart(orig_values);
   if (embedded_status==1) {
      call_key(last_event(), "\1", "L");
      _EmbeddedEnd(orig_values);
      return; // Processing done for this key
   }
   if ( command_state() || !doExpandSpace(p_LangId) || p_SyntaxIndent<0 ||
      _in_comment() ||
         json_expand_space() ) {
      if ( command_state() ) {
         call_root_key(' ');
      } else {
         keyin(' ');
      }
   } else if (_argument=='') {
      _undo('S');
   }
}


static int _json_enter_col() {
   orig_linenum:=p_line;
   orig_col:=p_col;

   rv := 0;
   save_pos(auto pp);
   save_search(auto s1, auto s2, auto s3, auto s4, auto s5);
   if ( p_col > 1 ) {
      left();
   } else {
      if ( !up()) _end_line();
   }


   nesting := 1;
   scanning := true;
   status := search('[()[\]{}]', '-<rh@xcs');
   while (scanning) {
      if (status != 0) {
         break;
      }
      ch := get_text();
      switch (ch) {
      case '(':
      case '{':
      case '[':
         nesting--;
         if (nesting <= 0) {
            scanning=false;
            /* 
               handle ( [ and { the same
                 { <ENTER>
                 { a:b, <ENTER>
                 {
                    a:b,
                    <ENTER>
             
            */
            save_pos(auto paren_pos);
            _first_non_blank();
            paren_fnb_col:=p_col;
            paren_linenum:=p_line;
            restore_pos(paren_pos);
            right();
            status=_clex_skip_blanks('h');
            if (status) {
               rv=paren_fnb_col+p_SyntaxIndent;
               continue;
            }
            if (p_line<orig_linenum || (p_line==orig_linenum && p_col<orig_col)) {
               /*if (p_line==paren_line) {
                  // align with indent of first parameter
                  rv=p_col;
               } */
               // align with indent of first parameter
               rv=p_col;
               continue;
            }
            rv=paren_fnb_col+p_SyntaxIndent;
            continue;

         }
         break;

      case ')':
      case ']':
      case '}':
         nesting++;
         break;
      }
      status=repeat_search();
   }
   restore_search(s1, s2, s3, s4, s5);
   restore_pos(pp);
   if (!rv) {
      _first_non_blank();
      rv=p_col;
      restore_pos(pp);
   }

   return rv;
}
static void _json_find_leading_context() {
   save_search(auto s1, auto s2, auto s3, auto s4, auto s5);
   nesting := 1;
   scanning := true;
   status := search('{}', '-<rh@xcs');
   while (scanning) {
      if (status) {
         top();
         break;
      }
      ch := get_text();
      switch (ch) {
      case '(':
      case '{':
      case '[':
         nesting--;
         if (nesting <= 0) {
            scanning=false;
            continue;
         }
         break;

      case ')':
      case ']':
      case '}':
         nesting++;
         break;
      }
      status=repeat_search();
   }
   restore_search(s1, s2, s3, s4, s5);
}

static int calc_nextline_indent()
{
   save_pos(auto pp);
   rv:=_json_enter_col();
   restore_pos(pp);
   return rv-1;
}

static bool _json_expand_enter() {
   line_splits := _will_split_insert_line();
   long rb_pos;

   if (_in_string() && !_in_mlstring()) {
      delim := "";
      int string_col = _inString(delim,false);
      if (//_GetCommentEditingFlags(VS_COMMENT_EDITING_FLAG_SPLIT_STRINGS) &&
          string_col && p_col > string_col && line_splits) {
         //indent_on_enter(0,string_col);
         return true;
      }
   }

   if (line_splits && (_in_comment() || _in_mlstring())) {
      return true;
   }

   if (_will_split_insert_line() 
       && should_expand_cuddling_braces(p_LangId) 
       && inside_cuddled_braces(rb_pos)) {
      save_pos(auto pp);
      _GoToROffset(rb_pos);
      delete_char();
      indent_on_enter(p_SyntaxIndent, calc_nextline_indent()+1);
      json_endbrace();
      restore_pos(pp);
      indent_on_enter(p_SyntaxIndent, calc_nextline_indent()+1);
   } else {
      indent_on_enter(p_SyntaxIndent, calc_nextline_indent()+1);
   }
   return false;
}
_command void json_enter(_str synthetic='') name_info(','VSARG2_MULTI_CURSOR|VSARG2_CMDLINE|VSARG2_ICON|VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY)
{
   if (synthetic!='') {
      indent_on_enter(p_SyntaxIndent, calc_nextline_indent()+1);
      return;
   }
   generic_enter_handler(_json_expand_enter,true);
}

bool _json_supports_syntax_indent(bool return_true_if_uses_syntax_indent_property=true) {
   return true;
}

bool _terraform_supports_syntax_indent(bool return_true_if_uses_syntax_indent_property=true) {
   return true;
}

int json_smartpaste(bool char_cbtype,int first_col,int Noflines,bool allow_col_1=false)
{
   typeless comment_col='';
   //If pasted stuff starts with comment and indent is different than code,
   // do nothing.
   // Find first non-blank line
   first_line := "";
   save_pos(auto p4);
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
   comment_col=p_col;
   if (j>1) {
      restore_pos(p4);
   }

   // Look for first piece of code not in a comment
   typeless status=_clex_skip_blanks('m');
   /*
      The first part of the if expression was commented out because it messed
      up smarttab for the case below:
      foo() {
         if(i<j) {
            while(i<j) {
      <Cursor in column 1>
            }
         }
      }

   */

   // IF //(no code found /*AND pasting comment */AND comment does not start in column 1) OR
   //   (code found AND pasting comment AND code col different than comment indent)
   //  OR  first non-blank code of pasted stuff is preprocessing
   //  OR first non-blank pasted line starts with non-blank AND
   //     (not pasting character selection OR copied text from column 1)
   if ( // (status /*&& comment_col!='' */&& comment_col<=1)
        (!status && comment_col!='' && p_col!=comment_col)
       //|| (!status && get_text()=='#')
       //|| ((substr(first_line,1,1)!='' && _LanguageInheritsFrom('js') && _LanguageInheritsFrom('typescript')) && (!char_cbtype ||first_col<=1))
       ) {
      return(0);
   }
   updateAdaptiveFormattingSettings(AFF_SYNTAX_INDENT | AFF_BEGIN_END_STYLE | AFF_INDENT_CASE);
   int syntax_indent=p_SyntaxIndent;

   typeless enter_col=0;
   col := 0;

   //say("smartpaste cur_word="cur_word(word_start));
   pasting_open_block := false;
   if (!status && get_text()=='}') {
      // IF pasting stuff contains code AND first char of code }
      ++p_col;
      enter_col=_json_endbrace_col();
      if (!enter_col) {
         enter_col='';
      }
      _begin_select();up();
   } else {
      /*if (!status) {
         if (get_text()=='{') {
            pasting_open_block=true;
         }
      } */
      _begin_select();up();
      _end_line();
      _skip_pp=1;
      enter_col=_json_enter_col(/*pasting_open_block*/);
      _skip_pp='';
      status=0;
   }
   //IF no code found/want to give up OR ... OR want to give up
   should_allow_col1 := true; /*allow_col_1 || pasting_open_block || 
      _LanguageInheritsFrom('js') || _LanguageInheritsFrom('typescript') || 
      _LanguageInheritsFrom('powershell');*/
   if (status || enter_col=='' || (enter_col==1 && !should_allow_col1)) {
      return(0);
   }
   return(enter_col);
}

int terraform_smartpaste(bool char_cbtype,int first_col,int Noflines,bool allow_col_1=false)
{
   return json_smartpaste(char_cbtype,first_col,Noflines);
}

static int _json_endbrace_col() {
   save_pos(auto p);
   left();
   status:=find_matching_paren(true);
   if (status) {
      restore_pos(p);
      return 0;
   }
   _first_non_blank();
   fnb_col:=p_col;
   restore_pos(p);
   return fnb_col;

}

static void reindent_closing_delim(_str startDelim, _str endDelim)
{
   if (_in_string() || _in_mlstring() || _in_comment()) {
      call_root_key(endDelim);
      return;
   }
   keyin(endDelim);
   get_line(auto line);
   if (line==endDelim) {
      col:=_json_endbrace_col();
      if (!col) {
         return;
      }
      replace_line(indent_string(col-1):+endDelim);
      p_col=col+1;
   }
   _undo('S');
}

_command void json_endbrace() name_info(','VSARG2_MULTI_CURSOR|VSARG2_CMDLINE|VSARG2_ICON|VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY)
{
   reindent_closing_delim('{', '}');
}


_command void json_endbracket() name_info(','VSARG2_MULTI_CURSOR|VSARG2_CMDLINE|VSARG2_ICON|VSARG2_REQUIRES_EDITORCTL|VSARG2_READ_ONLY)
{
   reindent_closing_delim('[', ']');
}

void _json_snippet_find_leading_context(long selstart, long selend) {
   _GoToROffset(selstart);
   _json_find_leading_context();
}

static int json_expand_begin()
{
   rv := -1;

   if (line_is_blank()) {
      replace_line(indent_string(calc_nextline_indent()));
      end_line();
   } 

   expand := LanguageSettings.getAutoBracketEnabled(p_LangId, AUTO_BRACKET_BRACE);
   insertBlankLine := LanguageSettings.getInsertBlankLineBetweenBeginEnd(p_LangId);

   if (expand) {
      int placement = get_autobrace_placement(p_LangId);

      rv = 0;
      lbo := _QROffset();
      keyin('{');
      if (placement == AUTOBRACE_PLACE_SAMELINE) {
         rbo := _QROffset();
         keyin('}');
         AutoBracketForBraces(p_LangId, lbo, rbo);
         _GoToROffset(rbo);
      } else {
         cur := _QROffset();
         json_enter('n');
         json_endbrace();
         _GoToROffset(cur);
         if (placement == AUTOBRACE_PLACE_AFTERBLANK) {
            json_enter('n');
         }
      }
   }

   return 0;
}

_command void json_begin() name_info(','VSARG2_MULTI_CURSOR|VSARG2_CMDLINE|VSARG2_ICON|VSARG2_REQUIRES_EDITORCTL)
{
   if (_in_string() || _in_mlstring() || _in_comment()) {
      call_root_key('{');
      return;
   }
   if (json_expand_begin()) {
      call_root_key('{');
   }
}

int _json_delete_char(_str force_wrap="") {
   return _css_delete_char(force_wrap);
}
/*int _json_rubout_char(_str force_wrap="") {
   return _css_rubout_char(force_wrap);
} */
 
int _terraform_delete_char(_str force_wrap="") {
   return _css_delete_char(force_wrap);
}
/*int _terraform_rubout_char(_str force_wrap="") {
   return _css_rubout_char(force_wrap);
} */

