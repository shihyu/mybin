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
#pragma option(metadata,"autocomplete.e")

#include "slick.sh"
#include "tagsdb.sh"


// prototypes for functions used to perform completions
void _autocomplete_process(_str insertWord,_str prefix,int &removeStartCol,int &removeLen,bool onlyInsertWord,struct VS_TAG_BROWSE_INFO symbol);
void _autocomplete_space(_str insertWord,_str prefix,int &removeStartCol,int &removeLen,bool onlyInsertWord,struct VS_TAG_BROWSE_INFO symbol);
void _autocomplete_expand_alias(_str insertWord,_str prefix,int &removeStartCol,int &removeLen,bool onlyInsertWord,struct VS_TAG_BROWSE_INFO symbol);
void _autocomplete_prev(_str insertWord,_str prefix,int &removeStartCol,int &removeLen,bool onlyInsertWord,struct VS_TAG_BROWSE_INFO symbol);
void _autocomplete_next(_str insertWord,_str prefix,int &removeStartCol,int &removeLen,bool onlyInsertWord,struct VS_TAG_BROWSE_INFO symbol);


///////////////////////////////////////////////////////////////////////////////
_metadata enum_flags AutoCompleteFlags {
   AUTO_COMPLETE_ENABLE                = 0x00000001,   // enable auto complete
   AUTO_COMPLETE_NO_STRICT_CASE        = 0x00000002,   // should auto-complete matching be case-sensitive?
   AUTO_COMPLETE_SUBWORD_MATCHES       = 0x00000004,   // should auto-complete matching use subword pattern matching?
   AUTO_COMPLETE_SUBWORD_NO_GLOBALS    = 0x00000008,   // should auto-complete subword matching include globals?
   AUTO_COMPLETE_SHOW_BULB             = 0x00000010,   // show a light-bulb with the completion
   AUTO_COMPLETE_SHOW_LIST             = 0x00000020,   // show list of matches?
   AUTO_COMPLETE_SHOW_WORD             = 0x00000040,   // show what would be completed
   AUTO_COMPLETE_SHOW_DECL             = 0x00000080,   // show symbol declaration?
   AUTO_COMPLETE_SHOW_COMMENTS         = 0x00000100,   // show symbol comments?
   AUTO_COMPLETE_SHOW_ICONS            = 0x00000200,   // show symbol icons?
   AUTO_COMPLETE_SHOW_CATEGORIES       = 0x00000400,   // show categories or just show flat list?
   AUTO_COMPLETE_SHOW_HISTORY          = 0x00000800,   // show history category (even if not showing other categories)
   AUTO_COMPLETE_SYNTAX                = 0x00001000,   // show when syntax can be expanded
   AUTO_COMPLETE_ALIAS                 = 0x00002000,   // show when an alias can be completed
   AUTO_COMPLETE_SYMBOLS               = 0x00004000,   // show when a symbol can be completed
   AUTO_COMPLETE_KEYWORDS              = 0x00008000,   // show when keywords can be completed
   AUTO_COMPLETE_WORDS                 = 0x00010000,   // show when complete-list prefix matches
   AUTO_COMPLETE_EXTENSION_ARGS        = 0x00020000,   // extension specific argument completion
   AUTO_COMPLETE_LANGUAGE_ARGS         = 0x00020000,   // extension specific argument completion
   AUTO_COMPLETE_UNIQUE                = 0x00100000,   // automatically select unique item?
   AUTO_COMPLETE_TAB_NEXT              = 0x00200000,   // Tab key selects next item. Cycles through choices.
   AUTO_COMPLETE_ENTER_ALWAYS_INSERTS  = 0x00400000,   // Enter key always inserts current item, even if not selected
   AUTO_COMPLETE_TAB_INSERTS_PREFIX    = 0x00800000,   // use tab key to insert unique prefix match?
   AUTO_COMPLETE_ARGUMENTS             = 0x01000000,   // show for argument completion (text boxes)
   AUTO_COMPLETE_NO_INSERT_SELECTED    = 0x02000000,   // Insert the select item
   AUTO_COMPLETE_LOCALS                = 0x04000000,   // show when a local symbol can be completed
   AUTO_COMPLETE_MEMBERS               = 0x08000000,   // show when a class member can be completed
   AUTO_COMPLETE_CURRENT_FILE          = 0x10000000,   // show when a symbol in the current file can be completed
   AUTO_COMPLETE_SHOW_PROTOTYPES       = 0x20000000,   // show function argument prototypes in list
   AUTO_COMPLETE_HISTORY               = 0x40000000,   // show learned auto-complete history

   AUTO_COMPLETE_DEFAULT               = ( AUTO_COMPLETE_ENABLE                |
                                         //AUTO_COMPLETE_CASE_SENSITIVE        |
                                           AUTO_COMPLETE_SUBWORD_MATCHES       |
                                           AUTO_COMPLETE_SUBWORD_NO_GLOBALS    |
                                           AUTO_COMPLETE_SHOW_BULB             |
                                           AUTO_COMPLETE_SHOW_LIST             |
                                           AUTO_COMPLETE_SHOW_WORD             |
                                           AUTO_COMPLETE_SHOW_DECL             |
                                           AUTO_COMPLETE_SHOW_COMMENTS         |
                                           AUTO_COMPLETE_SHOW_ICONS            |
                                           AUTO_COMPLETE_SHOW_CATEGORIES       |
                                           AUTO_COMPLETE_SHOW_HISTORY          |
                                           AUTO_COMPLETE_SYNTAX                |
                                           AUTO_COMPLETE_ALIAS                 |
                                           AUTO_COMPLETE_HISTORY               |
                                           AUTO_COMPLETE_SYMBOLS               |
                                           AUTO_COMPLETE_KEYWORDS              |
                                           AUTO_COMPLETE_WORDS                 |
                                           AUTO_COMPLETE_EXTENSION_ARGS        |
                                           AUTO_COMPLETE_LANGUAGE_ARGS         |
                                         //AUTO_COMPLETE_UNIQUE                |
                                         //AUTO_COMPLETE_TAB_NEXT              |
                                           AUTO_COMPLETE_ENTER_ALWAYS_INSERTS  |
                                           AUTO_COMPLETE_TAB_INSERTS_PREFIX    |
                                           AUTO_COMPLETE_ARGUMENTS             |
                                           AUTO_COMPLETE_NO_INSERT_SELECTED    |
                                           AUTO_COMPLETE_LOCALS                |
                                           AUTO_COMPLETE_MEMBERS               |
                                           AUTO_COMPLETE_CURRENT_FILE          |
                                           AUTO_COMPLETE_SHOW_PROTOTYPES       )
};

enum AutoCompleteSubwordPattern {
   // subword matching specifies to only do prefix matching 
   // (aka, subword matching is turned OFF)
   AUTO_COMPLETE_SUBWORD_MATCH_NONE = 0,   
   // subword matching using stone-skipping with subword boundaries
   AUTO_COMPLETE_SUBWORD_MATCH_STSK_SUBWORD,
   // subword matching using subword acronyms
   AUTO_COMPLETE_SUBWORD_MATCH_STSK_ACRONYM,
   // subword matching using pure stone-skipping
   AUTO_COMPLETE_SUBWORD_MATCH_STSK_PURE,
   // subword matching using simple substring match
   AUTO_COMPLETE_SUBWORD_MATCH_SUBSTRING,
   // subword matching using simple subword prefix match
   AUTO_COMPLETE_SUBWORD_MATCH_SUBWORD,
   // character matching in any order
   AUTO_COMPLETE_SUBWORD_MATCH_CHAR_BITSET,
};


_metadata enum AutoCompletePoundIncludeOptions {
   // do not trigger auto-complete on #include
   AC_POUND_INCLUDE_NONE,
   // list quoted files after typing space
   AC_POUND_INCLUDE_QUOTED_ON_SPACE,
   // list files after typing " or <
   AC_POUND_INCLUDE_ON_QUOTELT,
};

enum AutoCompletePriorities {
   AUTO_COMPLETE_HISTORY_PRIORITY=1,
   AUTO_COMPLETE_SYNTAX_PRIORITY=100,
   AUTO_COMPLETE_KEYWORD_PRIORITY=200,
   AUTO_COMPLETE_ALIAS_PRIORITY=300,
   AUTO_COMPLETE_FIRST_SYMBOL_PRIORITY=400,
   AUTO_COMPLETE_COMPATIBLE_PRIORITY=410,
   AUTO_COMPLETE_LOCALS_PRIORITY=420,
   AUTO_COMPLETE_MEMBERS_PRIORITY=430,
   AUTO_COMPLETE_CURRENT_FILE_PRIORITY=440,
   AUTO_COMPLETE_SYMBOL_PRIORITY=450,
   AUTO_COMPLETE_SUBWORD_PRIORITY=460,
   AUTO_COMPLETE_LAST_SYMBOL_PRIORITY=499,
   AUTO_COMPLETE_WORD_COMPLETION_PRIORITY=500,
   AUTO_COMPLETE_FILES_PRIORITY=600,
   AUTO_COMPLETE_ARGUMENT_PRIORITY=1000,
   AUTO_COMPLETE_ALL_MIXED_PRIORITY=2000,
};

/**
 * This struct represents an auto completion word.
 */
struct AUTO_COMPLETE_INFO {
   // priority of category
   int priorityLevel;
   // Word displayed in list
   _str displayWord;
   // Are function arguments shown for this word?
   bool displayArguments;
   // Text to insert. if this is null, the display word is inserted.
   _str insertWord;
   // comments describing completed word
   _str comments;
   // comment flags for this word
   VSCodeHelpCommentFlags comment_flags;
   // name of command to execute on space (for unique results)
   void (*pfnReplaceWord)(_str insertWord,_str prefix,int &removeStartCol,int &removeLen,bool onlyInsertWord,struct VS_TAG_BROWSE_INFO symbol);
   // tag information if this is a symbol
   struct VS_TAG_BROWSE_INFO symbol;
   // Indicates whether matching is case sensitive, default is true
   bool caseSensitive;
   // Index of bitmap to display in list
   int bitmapIndex;
};

/**
 * This struct represents the environment in which an auto-complete history 
 * entry was created. 
 */
struct AUTO_COMPLETE_HISTORY_INFO {
   _str langId;
   _str lastid_prefix;
   long timeOfCompletion;
   int  numberOfVotes;
   VS_TAG_IDEXP_INFO  idexp_info;
   VS_TAG_RETURN_TYPE prefixexp_rt;
   VS_TAG_RETURN_TYPE context_rt;
   AUTO_COMPLETE_INFO word_info;
};


/**
 * Control the default behavior of alias and other auto-completion options.
 * Bitset of AUTO_COMPLETE_*.  The default is for everything to be enabled
 * except partial symbol expansion and displaying the expansion bar.
 * <p>
 * The actual configurable options are stored per extension in
 * def_autocomplete_[ext].  This is used as a global default setting.
 *
 * @categories Configuration_Variables
 */
AutoCompleteFlags def_auto_complete_options = (AutoCompleteFlags)(-1 & ~(AUTO_COMPLETE_UNIQUE|AUTO_COMPLETE_TAB_NEXT));


/**
 * Add the given auto-completion expansion to the auto-complete history. 
 * The history information tries to encapsulate as much information about 
 * the context in which a completion was performed as possible in order 
 * to devise in what circumstances the same completion can be re-used. 
 * 
 * @param prefix         identifier prefix characters typed (so far)
 * @param langId         current language mode (ID)
 * @param idexp_info     expression information from context
 * @param prefixexp_rt   return type of prefix expression (from {@code idexp_info})
 * @param context_rt     return type of current context (what class we are in)
 * @param word_info      auto-complete word info for item that was expanded
 * 
 * @return 
 * Returns 0 on success, &lt;0 on error. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_add_history(_str prefix, 
                                         _str langId,
                                         VS_TAG_IDEXP_INFO  &idexp_info,
                                         VS_TAG_RETURN_TYPE &prefixexp_rt,
                                         VS_TAG_RETURN_TYPE &context_rt,
                                         AUTO_COMPLETE_INFO &word_info);

/**
 * Match the given identifier prefix against items in our completion history 
 * and verify that the same completion can be re-used. 
 * 
 * @param langId           language mode (ID)
 * @param lastid           current word under cursor being completed, includes text after cursor
 * @param lastid_prefix    current word prefix under cursor, does not include text after cursor
 * @param caseSensitive    case sensitive (true), case-insensitive (false)
 * @param idexp_info       expression info for code surrounding completion (VS_TAG_IDEXP_INFO)
 * @param prefixexp_rt     return type from evaluating the prefix expression from {@code idexp_info} (VS_TAG_RETURN_TYPE)
 * @param context_rt       return type for current context where completion is taking place (VS_TAG_RETURN_TYPE)
 * @param max_matches      maximum number of matches to find
 * @param tag_files        Slick-C array of tag files
 * @param visited          (reference) Slick-C hash table of context tagging results 
 * @param depth            recursive call depth
 * 
 * @return 
 * Returns number of items found, &gt;=0 on success, &lt; 0 on error. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_history(_str langId,
                                         _str lastid,
                                         _str lastid_prefix,
                                         bool caseSensitive,
                                         VS_TAG_IDEXP_INFO  &idexp_info,
                                         VS_TAG_RETURN_TYPE &prefixexp_rt,
                                         VS_TAG_RETURN_TYPE &context_rt,
                                         int max_matches, 
                                         _str (&tag_files)[],
                                         typeless &visited=null, int depth=0);

/**
 * Match the given identifier prefix against items in our completion history, 
 * looking for <em>exact</em> matches.  Verify that the completion can be 
 * re-used, then insert the corresponding symbol information into the match set. 
 * 
 * @param langId           language mode (ID)
 * @param lastid           current word under cursor being completed, includes text after cursor
 * @param lastid_prefix    current word prefix under cursor, does not include text after cursor
 * @param caseSensitive    case sensitive (true), case-insensitive (false)
 * @param idexp_info       expression info for code surrounding completion (VS_TAG_IDEXP_INFO)
 * @param prefixexp_rt     return type from evaluating the prefix expression from {@code idexp_info} (VS_TAG_RETURN_TYPE)
 * @param context_rt       return type for current context where completion is taking place (VS_TAG_RETURN_TYPE)
 * @param max_matches      maximum number of matches to find
 * @param tag_files        Slick-C array of tag files
 * @param visited          (reference) Slick-C hash table of context tagging results 
 * @param depth            recursive call depth
 * 
 * @return 
 * Returns number of items found, &gt;=0 on success, &lt; 0 on error. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_find_history_symbols(_str langId,
                                                  _str lastid,
                                                  _str lastid_prefix,
                                                  bool caseSensitive,
                                                  VS_TAG_IDEXP_INFO  &idexp_info,
                                                  VS_TAG_RETURN_TYPE &prefixexp_rt,
                                                  VS_TAG_RETURN_TYPE &context_rt,
                                                  int max_matches, 
                                                  _str (&tag_files)[],
                                                  typeless &visited=null, int depth=0);

/**
 * Add the given word information to the list of completions found by auto-complete.
 * 
 * @param word_info     auto-complete word info
 * 
 * @return 
 * Returns 0 on success, &lt;0 on error. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_add_word(AUTO_COMPLETE_INFO &word_info);

/**
 * @return 
 * Return the number of words found so far by auto-complete. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_num_words();

/**
 * Clear the list of words found by auto-complete.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern void tag_auto_complete_clear_words();

/**
 * Get the i'th item from the list of auto-complete words.
 * 
 * @param i            index of word to retrieve, starting with 0
 * @param word_info    (output) set to word information for the given word
 * 
 * @return 
 * Returns 0 on success, &lt;0 on error or invalid index. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_word(int i, AUTO_COMPLETE_INFO &word_info);

/**
 * Replace the i'th item from the list of auto-complete words.
 * 
 * @param i            index of word to retrieve, starting with 0
 * @param word_info    new word information for the given word
 * 
 * @return 
 * Returns 0 on success, &lt;0 on error or invalid index. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_set_word(int i, AUTO_COMPLETE_INFO &word_info);

/**
 * @return 
 * Returns the word to be inserted for the i'th item from the list of auto-complete words. 
 * Returns "" if given an invalid index; 
 * 
 * @param i            index of word to retrieve, starting with 0
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern _str tag_auto_complete_get_insert_word(int i);


/**
 * Add an item to the array of auto completions being populated by
 * one of the auto completion callbacks.
 *
 * @param priority         priority for this result category
 * @param insertWord       word/text to insert
 * @param displayWord      word/text to show when list is displayed
 * @param comments         description of word
 * @param symbol           symbol information 
 * @param pfnReplaceWord   pointer to Slick-C function to call to replace word 
 * @param caseSensitive    was the word match case-sensitive 
 * @param bitmapIndex      index of bitmap to show when list is displayed
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_add_result(int priority,
                                        _str displayWord,
                                        _str insertWord,
                                        _str comments,
                                        VS_TAG_BROWSE_INFO &symbol,
                                        void (*pfnReplaceWord)(_str insertWord,_str prefix,int &removeStartCol,int &removeLen,bool onlyInsertWord,struct VS_TAG_BROWSE_INFO symbol)=null,
                                        bool caseSensitive=true,
                                        int bitmapIndex=0);


/**
 * Load all the auto-complete history for the given language mode into the given 
 * Slick-C array of {@link AUTO_COMPLETE_HISTORY_INFO} objects.
 * 
 * @param langId            language mode (ID)
 * @param allHistory        (output) Slick-C array of AUTO_COMPLETE_HISTORY_INFO
 * 
 * @return 
 * @return 0 on success, &lt;0 on error.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_all_history(_str langId, struct AUTO_COMPLETE_HISTORY_INFO (&allHistory)[]);

/**
 * Replace all the auto-complete history for the given language mode with the given 
 * Slick-C array of {@link AUTO_COMPLETE_HISTORY_INFO} objects.
 * 
 * @param langId            language mode (ID)
 * @param allHistory        (input) Slick-C array of AUTO_COMPLETE_HISTORY_INFO
 * 
 * @return 
 * @return 0 on success, &lt;0 on error.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_set_all_history(_str langId, AUTO_COMPLETE_HISTORY_INFO (&allHistory)[]);

/**
 * Run the maintenance thread over the auto-complete history to collate duplicates 
 * and truncate the size of the history down within reasonable size. 
 * 
 * @param langId               language mode (ID)
 * @param default_max_stored   maximum number of history records to keep
 * 
 * @return 0 on success, &lt;0 on error.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_do_history_maintenance(_str langId, int default_max_stored=32000);

/**
 * Match the given identifier prefix against language specific keywords 
 * (defined in the color coding lexer profiling) and add the keywords that 
 * match to the list of completions. 
 * 
 * @param langId           language mode (ID) 
 * @param lexerName        color coding lexer name 
 * @param lastid           current word under cursor being completed, includes text after cursor
 * @param lastid_prefix    current word prefix under cursor, does not include text after cursor 
 * @param prefixexp        prefix expression information (for preprocessing keywords) 
 * @param pic_keyword      bitmap index for keyword bitmap 
 * @param caseSensitive    case sensitive (true), case-insensitive (false) 
 * @param allowFuzzyMatch  allow matches which correct minor typos 
 * @param keywordCase      specifies how to format keywords for completion
 * @param max_matches      maximum number of matches to find
 * 
 * @return 
 * Returns 0 on success, &lt; 0 on error. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_keywords(_str langId,
                                          _str lexerName, 
                                          _str lastid,
                                          _str lastid_prefix,
                                          _str prefixexp,
                                          int pic_keyword,
                                          bool caseSensitive,
                                          bool allowFuzzyMatch,
                                          int keywordCase,
                                          int max_matches);

/**
 * Clear the language-specific keyword cache. 
 * If no language or lexer is specified, it will clear all of them. 
 *  
 * @param langId           language mode (ID)
 * @param lexerName        color coding lexer name 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern void tag_auto_complete_clear_keywords(_str langId="", _str lexerName="");

/**
 * Match the given identifier prefix against symbols.
 * 
 * @note 
 * This function calls the Slick-C function "_Embeddedfind_context_tags()" 
 * exactly once and adds the symbol matches that it finds. 
 *  
 * @param errorArgs             Slick-C array of error information
 * @param forceUpdate           force list to update
 * @param matchAnyWord          match any word (true) or force prefix match (false)
 * @param idexp_info            expression info for code surrounding completion (VS_TAG_IDEXP_INFO)
 * @param prefixexp_rt          return type from evaluating the prefix expression from {@code idexp_info} (VS_TAG_RETURN_TYPE)
 * @param context_rt            return type for current context where completion is taking place (VS_TAG_RETURN_TYPE)
 * @param find_options          context tagging fing tags options (VS_TAG_FIND_TAG_INFO) 
 * @param auto_complete_flags   auto complete option flags (AutoCompleteFlags) 
 * @param codehelp_flags        context tagging option flags (VSCodeHelpFlags) 
 * @param symbol_priority       priority to insert symbol at
 * @param max_matches           maximum number of matches to find
 * @param visited               (reference) Slick-C hash table of context tagging results 
 * @param depth                 recursive call depth
 * 
 * @return 
 * Returns number of items found, &gt;=0 on success, &lt; 0 on error. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_find_symbols(_str (&errorArgs)[],
                                          bool forceUpdate,
                                          bool matchAnyWord,
                                          VS_TAG_IDEXP_INFO  &idexp_info,
                                          VS_TAG_RETURN_TYPE &prefixexp_rt,
                                          VS_TAG_RETURN_TYPE &context_rt,
                                          VS_TAG_FIND_TAGS_INFO &find_options,
                                          AutoCompleteFlags auto_complete_flags,
                                          VSCodeHelpFlags codehelp_flags,
                                          AutoCompletePriorities symbol_priority,
                                          int max_matches, 
                                          typeless &visited=null, int depth=0);


/**
 * Match the given identifier prefix against symbols in the current scope 
 * and add the matches to the list of symbol matches. 
 *  
 * @note 
 * This function delegates to "tag_auto_complete_find_symbols()" up to three times. 
 * Once doing conventional prefix matching, once doing pattern matching 
 * requiring the first character to match, and finally once doing general 
 * pattern matching.
 *  
 * @param errorArgs             (reference) Slick-C array of error information
 * @param forceUpdate           force list to update
 * @param langId                language mode (ID) 
 * @param lastid                current word under cursor being completed, includes text after cursor
 * @param lastid_prefix         current word prefix under cursor, does not include text after cursor
 * @param matchAnyWord          match any word (true) or force prefix match (false)
 * @param exactMatch            expect a prefix match
 * @param caseSensitive         case sensitive (true), case-insensitive (false) 
 * @param filter_flags          symbol filter flags (bitset of SE_TAG_FILTER_*)
 * @param context_flags         context tagging flags (bitset of SE_TAG_CONTEXT_*)
 * @param idexp_info            expression info for code surrounding completion
 * @param prefixexp_rt          return type from evaluating the prefix expression from {@code idexp_info}
 * @param context_rt            return type for current context where completion is taking place 
 * @param auto_complete_flags   auto-complete options (bitset of SE_AUTO_COMPLETE_*) 
 * @param codehelp_flags        context tagging options (bitset of VSCODEHELPFLAG_*) 
 * @param symbol_priority       priority to insert symbol at
 * @param num_symbols           (input/output) number of symbols found so far
 * @param max_symbols           maximum number of symbols to find
 * @param visited               (reference) Slick-C hash table of context tagging results 
 * @param depth                 recursive call depth
 * 
 * @return 
 * Returns 0 on success, &lt; 0 on error. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_symbol_matches(_str (&errorArgs)[],
                                                bool forceUpdate,
                                                bool matchAnyWord,
                                                VS_TAG_IDEXP_INFO  &idexp_info,
                                                VS_TAG_RETURN_TYPE &prefixexp_rt,
                                                VS_TAG_RETURN_TYPE &context_rt,
                                                VS_TAG_FIND_TAGS_INFO &find_options,
                                                AutoCompleteFlags auto_complete_flags,
                                                VSCodeHelpFlags codehelp_flags,
                                                AutoCompletePriorities symbol_priority,
                                                int max_matches, 
                                                typeless &visited=null, int depth=0);

/**
 * Match the given identifier prefix against symbols in the current scope 
 * and add the matches to the list of symbol matches. 
 *  
 * @note 
 * This function delegates to "tag_auto_complete_get_symbol_matches()" up to four times. 
 * Once trying to match symbols against the full identifier under the cursor, 
 * Once trying to match symbol against just the identifier prefix (if not the same), 
 * And then again, doing the same two searches using a case-insenstivie search. 
 * It will then do a final search using "tag_auto_complete_find_symbols()" if 
 * the first attempts did not find anything. 
 *  
 * @param errorArgs             (reference) Slick-C array of error information
 * @param forceUpdate           force list to update
 * @param langId                language mode (ID) 
 * @param lastid                current word under cursor being completed, includes text after cursor
 * @param lastid_prefix         current word prefix under cursor, does not include text after cursor
 * @param matchAnyWord          match any word (true) or force prefix match (false)
 * @param exactMatch            expect a prefix match
 * @param caseSensitive         case sensitive (true), case-insensitive (false) 
 * @param filter_flags          symbol filter flags (bitset of SE_TAG_FILTER_*)
 * @param context_flags         context tagging flags (bitset of SE_TAG_CONTEXT_*)
 * @param idexp_info            expression info for code surrounding completion
 * @param prefixexp_rt          return type from evaluating the prefix expression from {@code idexp_info}
 * @param context_rt            return type for current context where completion is taking place 
 * @param auto_complete_flags   auto-complete options (bitset of SE_AUTO_COMPLETE_*) 
 * @param codehelp_flags        context tagging options (bitset of VSCODEHELPFLAG_*) 
 * @param symbol_priority       priority to insert symbol at
 * @param num_symbols           (input/output) number of symbols found so far
 * @param max_symbols           maximum number of symbols to find
 * @param visited               (reference) Slick-C hash table of context tagging results 
 * @param depth                 recursive call depth
 * 
 * @return 
 * Returns 0 on success, &lt; 0 on error. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_all_symbols(_str (&errorArgs)[],
                                             bool forceUpdate,
                                             bool matchAnyWord,
                                             VS_TAG_IDEXP_INFO  &idexp_info,
                                             VS_TAG_RETURN_TYPE &prefixexp_rt,
                                             VS_TAG_RETURN_TYPE &context_rt,
                                             VS_TAG_FIND_TAGS_INFO &find_options,
                                             AutoCompleteFlags auto_complete_flags,
                                             VSCodeHelpFlags codehelp_flags,
                                             AutoCompletePriorities symbol_priority,
                                             int max_matches, 
                                             typeless &visited=null, int depth=0);


/** 
 * @return 
 * Return {@code true} if the given symbol has already been added in any capacity 
 * to the set of auto-complete results. 
 * 
 * @param symbol_info      symbol to check for
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern bool tag_auto_complete_has_symbol(VS_TAG_BROWSE_INFO &symbol_info);

/**
 * @return 
 * Return {@code true} if the given word has already been added as an auto-complete result. 
 * 
 * @param word              word to check for (the lookup is case-sensitive)
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern bool tag_auto_complete_has_word(_str word);

/**
 * @return 
 * Return {@code true} if an exact match for the word under the cursor was found. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern bool tag_auto_complete_found_exact_match();

/**
 * Indicate that an exact match for the word under the cursor was found.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern void tag_auto_complete_set_found_exact_match(bool yesno=true);

/**
 * @return 
 * Return {@code true} if this is our first try at pattern matching.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern bool tag_auto_complete_first_pattern_match_attempt();

/**
 * Indicate if this is our first try at pattern matching.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern void tag_auto_complete_set_first_pattern_match_attempt(bool yesno=true);

/**
 * Update the tree control containing the list of auto-completion words
 * <p>
 * The completions are separated into categories (folders).
 * Each item in the tree uses it's tree index to refer back
 * to the index of that item in the list of words.
 * 
 * @param tree_wid              tree control window ID
 * @param auto_complete_options auto-complete options flags (bitset of SE_AUTO_COMPLETE_*)
 * @param lastid                the word under the cursor
 * @param word_index            index of the currently selected completion (&lt;0 if none)
 * @param max_prototypes        maximum number of prototypes to display in auto-complete list
 * @param categoryNames         hash table mapping auto-complete category priorities to category names
 * @param depth                 recursive call depth
 * 
 * @return Returns the tree index of the item corresponding to {@code word_index}, otherwise 0.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_update_list(int tree_wid, 
                                         AutoCompleteFlags auto_complete_options,
                                         _str lastid,
                                         int word_index,
                                         int max_prototypes,
                                         _str (&categoryNames):[],
                                         int depth=0);

/** 
 * @return 
 * Calculate the width of the code help tree control, by finding the width 
 * of the longest caption in the list.
 * 
 * @param tree_wid              tree control window ID
 * @param initial_width         initial max width
 * @param border_width          tree control border width
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_max_list_width(int tree_wid,
                                                int initial_width,
                                                int border_width);

/** 
 * @return 
 * Count the number of visible lines in the tree control. 
 * 
 * @param tree_wid              tree control window ID
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_count_visible_lines_in_list(int tree_wid);

/** 
 * @return
 * Return {@code true} if the given identifier prefix in the list of auto-complete results.
 *  
 * @param lastid_prefix    word prefix 
 * @param caseSensitive    expect word match to be case-sensitive 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern bool tag_auto_complete_is_prefix_valid(_str lastid_prefix, bool case_sensitive=true);

/**
 * @return
 * Return the number of unique word completions in the list of results.
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_get_num_unique_words();

/**
 * Search through the list of word completions and find the first completion 
 * that matches the given identifier or identifier prefix. 
 *  
 * Look for the first best match in this order: 
 * <ol>
 * <li>whole word match to {@code lastid}, case-sensitive</li>
 * <li>whole word match to {@code lastid}, case-insensitive</li> 
 * <li>prefix match to {@code lastid}, case-sensitive</li> 
 * <li>prefix match to {@code lastid}, case-insensitive</li> 
 * <li>prefix match to {@code lastid_prefix}, case-sensitive</li> 
 * <li>prefix match to {@code lastid_prefix}, case-insensitive</li> 
 * </ol>
 * 
 * @param lastid                 whole word under cursor 
 * @param lastid_prefix          prefix of word to left of cursor
 * @param forceUpdate            forcing update of auto-complete list?
 * @param selectMatchingItem     should the first match be left selected?
 * @param isListSymbols          invoked as list-symbols (rather than auto-complete)
 * @param strictCaseSensitivity  strict case-sensitivity
 * @param foundExactMatch        (input/output) set to {@code true} of an exact whole word match is found
 * @param depth                  recursive call depth
 *  
 * @return 
 * Return the index of the match that was found or &lt;0 if no match found. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_find_word_to_select(_str lastid,
                                                 _str lastid_prefix,
                                                 bool forceUpdate,
                                                 bool selectMatchingItem,
                                                 bool isListSymbols,
                                                 bool strictCaseSensitivity,
                                                 bool &foundExactMatch,
                                                 int depth=0);

/**
 * Search through the list of word completions for the longest common 
 * prefix match among words that match the symbol under the cursor. 
 * 
 * @param lastid_prefix         prefix of word to left of cursor
 * @param longest_prefix        (output) set to the longest prefix match
 * @param caseSensitive         use case-sensitive string comparisons
 * @param pattern_flags         symbol pattern matching flags
 * @param doPatternMatching     attempt subword pattern matching 
 * @param doFuzzyMatching       attempt fuzzy word matching
 * @param forceSymbolCompletion was symbol completion forced?
 * @param depth                 recursive call depth
 * 
 * @return 
 * Return the index of the match that was found or &lt;0 if no match found. 
 *  
 * @categories Tagging_Functions
 * @since 26.0 
 */
extern int tag_auto_complete_find_longest_prefix_match(_str lastid_prefix, 
                                                       _str & longest_prefix,
                                                       bool caseSensitive,
                                                       SETagContextFlags pattern_flags,
                                                       bool doPatternMatching,
                                                       bool doFuzzyMatching,
                                                       bool forceSymbolCompletion,
                                                       int depth=0);

