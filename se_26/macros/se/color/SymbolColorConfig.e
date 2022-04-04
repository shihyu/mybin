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
#include "search.sh"
#include "slick.sh"
#include "tagsdb.sh"
#include "xml.sh"
#require "se/color/SymbolColorRuleBase.e"
#import "se/color/ColorInfo.e"
#import "se/color/ColorScheme.e"
#import "se/color/DefaultColorsConfig.e"
#import "se/color/SymbolColorRule.e"
#import "se/color/SymbolColorAnalyzer.e"
#import "se/options/OptionsConfigTree.e"
#import "clipbd.e"
#import "color.e"
#import "ini.e"
#import "listbox.e"
#import "optionsxml.e"
#import "picture.e"
#import "main.e"
#import "math.e"
#import "mprompt.e"
#import "seltree.e"
#import "stdcmds.e"
#import "stdprocs.e"
#import "treeview.e"
#import "cfg.e"
#import "files.e"
#endregion


using se.color.ColorScheme;
using se.color.SymbolColorRuleBase;

/**
 * This is the name of the always empty scheme.
 */
static const SYMBOL_COLOR_NONE = "(None)";
/**
 * Caption for symbol kind represent a symbol which is not found or 
 * other context tagging error. 
 */
static const SYMBOL_COLOR_NOT_FOUND = "*SYMBOL NOT FOUND*";

/**
 * The SymbolColorConfig class is used to manage the data necessary 
 * for customizing the symbol coloring rule base(s).  It works closely 
 * with the Symbol Coloring options dialog. 
 */
class SymbolColorConfig {
   /**
    * This is the symbol color profile (rule base) which is 
    * currently being edited in the Symbol Coloring options dialog.
    */
   private SymbolColorRuleBase m_currentProfile;
   /**
    * This is the symbol color profile (rule base) which is 
    * currently being edited in the Symbol Coloring options dialog.
    */
   private SymbolColorRuleBase m_origProfile;

   /**
    * Has the current symbol coloring profile stored in 
    * m_currentProfile changed or has the currently selected 
    * profile changed. Call profileChanged() to check if just the
    * profile settings changed. 
    */
   private bool m_modified = false;

   /**
    * Temporarily ignore what might appear to be symbol coloring modifications. 
    */
   private bool m_ignoreModifications = false;
   SymbolColorConfig() {
      m_modified=false;
      m_ignoreModifications=false;
   }
   SymbolColorRuleBase* loadProfile(_str profileName,int optionLevel=0) {
      m_currentProfile.loadProfile(profileName,optionLevel);
      m_origProfile=m_currentProfile;
      return &m_currentProfile;
   }
   SymbolColorRuleBase *getCurrentProfile() {
      return &m_currentProfile;
   }
   static bool hasBuiltinProfile(_str profileName) {
      if (profileName == CONFIG_AUTOMATIC) return true;
      return _plugin_has_builtin_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,profileName);
   }

   /**
    * @return 
    * Return 'true' if the scheme with the given name was added as a system scheme, 
    * but has been modified from its original form by the user. 
    *  
    * @param name    symbol color scheme name 
    */
   static bool isModifiedBuiltinProfile(_str profileName) {
      return _plugin_is_modified_builtin_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,profileName);
   }
   void setModified(bool modified) {
      m_modified=modified;
   }
   bool isModified() {
      return m_modified;
   }
   bool profileChanged() {
      return m_currentProfile!=m_origProfile;
   }
   /**
    * Temporarily ignore any modfications being made to the symbol coloring. 
    * This should be used when loading color schemes, to prevent callbacks 
    * that are populating the form from triggering modify callbacks when 
    * on_change() events are generated. 
    *  
    * @param onoff   'true' to ignore modifications, false otherwise. 
    *  
    * @return Returns the original state of ignoring modifications (true/false). 
    */
   void setIgnoreChanges(bool onoff) {
      m_ignoreModifications = onoff;
   }
   /**
    * @return 
    * Return 'true' if we are ignoring modifications temporilary. 
    */
   bool ignoreChanges() {
      return m_ignoreModifications;
   }
};

///////////////////////////////////////////////////////////////////////////
// Switch to the global namespace
//
namespace default;

using se.color.SymbolColorAnalyzer;
using se.color.SymbolColorRuleBase;

/**
 * Reset the symbol coloring scheme to defaults. 
 * This function is no longer necessary, but left in for 
 * debugging or emergency purposes. 
 */
_command void reset_symbol_color_scheme() name_info(','VSARG2_REQUIRES_PRO_EDITION)
{
   def_symbol_color_profile=CONFIG_AUTOMATIC;
   _config_modify_flags(CFGMODIFY_DEFVAR);

   // Reinitialize symbol analyzers
   SymbolColorAnalyzer.initAllSymbolAnalyzers();
}

/**
 * This is for the first time user, so that the symbol coloring object 
 * gets initialized. 
 */
void _UpgradeSymbolColoringScheme(_str old_config_version) 
{
   index:=find_index('def_symbol_color_scheme',VAR_TYPE);
   if (index) {
      value:=_get_var(index);
      if (value!=null && value._varformat()==VF_OBJECT && value._length()>=1 && value[0]._varformat()==VF_LSTR && value[0]!='') {
         parse value[0] with auto profileName ' (modified)';
         if (profileName!='' && _plugin_has_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,profileName)) {
            def_symbol_color_profile=profileName;
            if (def_symbol_color_profile == "Undefined Only") {
               def_symbol_color_profile == "Unidentified Symbols Only";
            }
            // one-time exchange of "All symbols - " symbol coloring schemes for "All Symbols"
            parse old_config_version with auto major '.' .;
            if (isinteger(major) && (int)major <= 25) {
               if (beginsWith(def_symbol_color_profile, "All symbols -")) {
                  def_symbol_color_profile == "All symbols";
               }
               if (beginsWith(def_symbol_color_profile, "Classes and Types -")) {
                  def_symbol_color_profile == "Classes and Types";
               }
            }
            _config_modify_flags(CFGMODIFY_DEFVAR);
         }
      }
   }
   if (def_symbol_color_profile=='') {
      reset_symbol_color_scheme();
   }
}

/**
 * This function is used to migrate symbol coloring from version 14.0.0 
 * forward to subsequent versions of SlickEdit which will have Symbol Coloring 
 * disabled by default.  It will prompt the user whether they want to continue 
 * using symbol coloring or disable it.  It will also let them turn unknown 
 * symbol coloring on or off. 
 * 
 * @param old_config_version   Version of SlickEdit that configuration was 
 *                             migrated from.  Only matters if it is 14.0.0. 
 */
void _MigrateV14SymbolColoringOptions(_str old_config_version)
{
   // not migrating setting from 14.0.0, then forget about this step
   if (old_config_version != "14.0.0") {
      return;
   }

   // long-winded description of what this dialog is for
   explanation := "":+
                  "<b>Symbol Coloring</b> allows you to define rules to assign ":+
                  "colors to specific symbol types, like variables, class names ":+
                  "or functions. Each rule assigns a foreground and background ":+
                  "color based on the symbol's type ":+
                  "(e.g. Function, Parameter, Local variable) and a list of ":+
                  "attributes (e.g. Abstract, Public Scope, Const). ":+
                  "<p>":+
                  "Future versions of SlickEdit will have ":+
                  "<u>Symbol Coloring turned off by default</u>. ":+
                  "This feature was turned on by default in SlickEdit 2009. ":+
                  "<p>":+
                  "In addition, the option to highlight unidentified symbols will ":+
                  "also be turned off by default in future versions.  Check the ":+
                  "option below if you want to continue to highlight unidentified ":+
                  "symbols.":+
                  "";
   status := textBoxDialog("Confirm Symbol Coloring Options", 0, 6500,
                           "Symbol Coloring Options",
                           "Continue to use Symbol Coloring,Disable Symbol Coloring\t-html "explanation,
                           "",
                           "-CHECKBOX Highlight unidentified symbols:0" );

   // The idiot just hit cancel, their symbol coloring will now be disabled
   // unless they had explicitely enabled it themselves.
   if (status == COMMAND_CANCELLED_RC) {
      return;
   }

   // check results of dialog
   showUnknownSymbols    := (_param1==0)? SYMBOL_COLOR_SHOW_NO_ERRORS:0;
   disableSymbolColoring := (status ==2)? SYMBOL_COLOR_DISABLED:0;

   // collect all the language ID's into an array of strings
   _str languageIDs[];
   _GetAllLangIds(languageIDs);

   // for each language set up within SlickEdit
   // new user-defined languages will have symbol coloring
   // turned off by default. 
   foreach (auto langId in languageIDs) {

      // not a valid language ID
      if (langId=="") continue;
      if (!_QSymbolColoringSupported(langId)) {
         continue;
      }

      // if the options aren't explicitly set, use the V14.0.0 defaults
      options := _GetSymbolColoringOptions(langId);
      index := find_index("def-symbolcoloring-"langId, MISC_TYPE);
      if (!index) {
         options = SYMBOL_COLOR_BOLD_DEFINITIONS;
      }

      // do not highlight unidentified symbols 
      options |= showUnknownSymbols;

      // disable symbol coloring if they are disabling it
      // and it wasn't already explicitely disabled.
      if (!(options & SYMBOL_COLOR_DISABLED)) {
         options |= disableSymbolColoring;
      }

      // only set the symbol coloring options if they differ from
      // the v14.0.1 interpretation of the defaults.
      if (options != _GetSymbolColoringOptions(langId)) {
         _SetSymbolColoringOptions(langId, options);
      }
   }
}

/**
 * This hash table maps tag attribute flags to their message 
 * index codes so that we can find the localized strings describing 
 * the tag attributes. 
 */
static int gTagAttributeMap:[] = {
   SE_TAG_FLAG_VIRTUAL      => VS_TAG_FLAG_VIRTUAL_RC,
   SE_TAG_FLAG_STATIC       => VS_TAG_FLAG_STATIC_RC,
   SE_TAG_FLAG_PROTECTED    => VS_TAG_FLAG_PROTECTED_RC,
   SE_TAG_FLAG_PRIVATE      => VS_TAG_FLAG_PRIVATE_RC,
   SE_TAG_FLAG_CONST        => VS_TAG_FLAG_CONST_RC,
   SE_TAG_FLAG_FINAL        => VS_TAG_FLAG_FINAL_RC,
   SE_TAG_FLAG_ABSTRACT     => VS_TAG_FLAG_ABSTRACT_RC,
   SE_TAG_FLAG_INLINE       => VS_TAG_FLAG_INLINE_RC,
   SE_TAG_FLAG_OPERATOR     => VS_TAG_FLAG_OPERATOR_RC,
   SE_TAG_FLAG_CONSTRUCTOR  => VS_TAG_FLAG_CONSTRUCTOR_RC,
   SE_TAG_FLAG_VOLATILE     => VS_TAG_FLAG_VOLATILE_RC,
   SE_TAG_FLAG_TEMPLATE     => VS_TAG_FLAG_TEMPLATE_RC,
   SE_TAG_FLAG_INCLASS      => VS_TAG_FLAG_INCLASS_RC,
   SE_TAG_FLAG_DESTRUCTOR   => VS_TAG_FLAG_DESTRUCTOR_RC,
   SE_TAG_FLAG_SYNCHRONIZED => VS_TAG_FLAG_SYNCHRONIZED_RC,
   SE_TAG_FLAG_TRANSIENT    => VS_TAG_FLAG_TRANSIENT_RC,
   SE_TAG_FLAG_NATIVE       => VS_TAG_FLAG_NATIVE_RC,
   SE_TAG_FLAG_MACRO        => VS_TAG_FLAG_MACRO_RC,
   SE_TAG_FLAG_EXTERN       => VS_TAG_FLAG_EXTERN_RC,
   SE_TAG_FLAG_MAYBE_VAR    => VS_TAG_FLAG_MAYBE_VAR_RC,
   SE_TAG_FLAG_ANONYMOUS    => VS_TAG_FLAG_ANONYMOUS_RC,
   SE_TAG_FLAG_MUTABLE      => VS_TAG_FLAG_MUTABLE_RC,
   SE_TAG_FLAG_EXTERN_MACRO => VS_TAG_FLAG_EXTERN_MACRO_RC,
   SE_TAG_FLAG_LINKAGE      => VS_TAG_FLAG_LINKAGE_RC,
   SE_TAG_FLAG_PARTIAL      => VS_TAG_FLAG_PARTIAL_RC,
   SE_TAG_FLAG_IGNORE       => VS_TAG_FLAG_IGNORE_RC,
   SE_TAG_FLAG_FORWARD      => VS_TAG_FLAG_FORWARD_RC,
   SE_TAG_FLAG_OPAQUE       => VS_TAG_FLAG_OPAQUE_RC,
   SE_TAG_FLAG_IMPLICIT     => VS_TAG_FLAG_IMPLICIT_RC,
   SE_TAG_FLAG_UNIQ_PUBLIC  => VS_TAG_FLAG_PUBLIC_RC,
   SE_TAG_FLAG_UNIQ_PACKAGE => VS_TAG_FLAG_PACKAGE_RC,
   SE_TAG_FLAG_OVERRIDE     => VS_TAG_FLAG_OVERRIDE_RC,
   SE_TAG_FLAG_SHADOW       => VS_TAG_FLAG_SHADOW_RC,
   SE_TAG_FLAG_INTERNAL     => VS_TAG_FLAG_INTERNAL_RC,
   SE_TAG_FLAG_CONSTEXPR    => VS_TAG_FLAG_CONSTEXPR_RC,
   SE_TAG_FLAG_CONSTEVAL    => VS_TAG_FLAG_CONSTEVAL_RC,
   SE_TAG_FLAG_CONSTINIT    => VS_TAG_FLAG_CONSTINIT_RC,
   SE_TAG_FLAG_EXPORT       => VS_TAG_FLAG_EXPORT_RC,
   SE_TAG_FLAG_IN_CONTEXT   => VS_TAG_FLAG_IN_CONTEXT_RC,
   SE_TAG_FLAG_NESTED_LOCAL => VS_TAG_FLAG_NESTED_LOCAL_RC,
   SE_TAG_FLAG_ASYNCHRONOUS => VS_TAG_FLAG_ASYNCHRONOUS_RC,
   SE_TAG_FLAG_FACTORY      => VS_TAG_FLAG_FACTORY_RC,
   SE_TAG_FLAG_LATE         => VS_TAG_FLAG_LATE_RC,
};


///////////////////////////////////////////////////////////////////////////
// The following code is used to implement the Symbol Coloring
// configuration dialog.
///////////////////////////////////////////////////////////////////////////

//static se.color.SymbolColorRuleBase gdialog_rule_base;
//static se.color.SymbolColorRuleBase gdialog_rule_base_orig;
//static bool gignore_changes;
//static bool gmodified;

defeventtab _symbol_color_form;


/**
 * Get the SymbolColorConfig class instance, which is stored in 
 * the p_user of the schemes control. 
 * 
 * @return se.color.SymbolColorConfig* 
 */
static SymbolColorConfig *getSymbolColorConfig()
{
   if (ctl_scheme.p_user instanceof SymbolColorConfig) {
      return &ctl_scheme.p_user;
   }
   return null;
}

/**
 * Get the SymbolColorRuleBase class instance being edited. 
 * It is obtained thought the master SymbolColorConfig object. 
 * 
 * @return se.color.SymbolColorRuleBase* 
 */
static se.color.SymbolColorRuleBase *getSymbolColorRuleBase()
{
   scc := getSymbolColorConfig();
   if (scc == null) return null;

   return scc->getCurrentProfile();

}
/**
 * Get the current SymbolColorRule being edited. 
 * It is obtained by looking at the rule name currently 
 * selected in the symbol coloring configuration dialog. 
 * 
 * @return se.color.SymbolColorRule* 
 */
static se.color.SymbolColorRule *getSymbolColorRule()
{
   rb := getSymbolColorRuleBase();
   if (rb == null) return null;

   index := ctl_rules._TreeCurIndex();
   if (index <= TREE_ROOT_INDEX) return null;

   caption := ctl_rules._TreeGetCaption(index);
   parse caption with auto ruleName "\t" . ;
   return rb->getRuleByName(ruleName);
}

/**
 * Return the current color profile being used with this symbol color profile
 */
static _str getColorProfileName()
{
   if (ctl_compatibility.p_user == null || ctl_compatibility.p_user == "") {
      return ColorScheme.realProfileName(def_color_scheme);
   }
   return ColorScheme.realProfileName(ctl_compatibility.p_user);
}

/**
 * Insert all default color names and rule names for the current rule 
 * base into the parent rule combo box. 
 *  
 * @param rb   Symbol coloring scheme (rule base) 
 */
static void loadParentRuleList(se.color.SymbolColorRuleBase *rb)
{
   ctl_parent_color._lbclear();
   ctl_parent_color._lbadd_item("--"get_message(VSRC_CFG_WINDOW_TEXT)"--");
   ctl_parent_color._lbadd_item("--"get_message(VSRC_CFG_FUNCTION)"--");
   ctl_parent_color._lbadd_item("--"get_message(VSRC_CFG_KEYWORD)"--");
   ctl_parent_color._lbadd_item("--"get_message(VSRC_CFG_PREPROCESSOR)"--");
   ctl_parent_color._lbadd_item("--"get_message(VSRC_CFG_LIBRARY_SYMBOL)"--");
   ctl_parent_color._lbadd_item("--"get_message(VSRC_CFG_USER_DEFINED_SYMBOL)"--");
   ctl_parent_color._lbadd_item("--"get_message(VSRC_CFG_HIGHLIGHT)"--");
   ctl_parent_color._lbadd_item("--"get_message(VSRC_CFG_SYMBOL_HIGHLIGHT)"--");

   // Theme colors designated for symbol coloring.
   for (cfg := CFG_FIRST_SYMBOL_COLOR; cfg < CFG_LAST_SYMBOL_COLOR; cfg++) {
      if (cfg < CFG_SYMBOL_COLOR_PALETTE_00) {
         msg_code := VSRC_CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND - 2*(cfg-CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND);
         ctl_parent_color._lbadd_item("--"get_message(msg_code)"--");
      } else {
         msg_code := VSRC_CFG_SYMBOL_COLOR_PALETTE_00 - 2*(cfg-CFG_SYMBOL_COLOR_PALETTE_00);
         ctl_parent_color._lbadd_item("--"get_message(msg_code)"--");
      }
   }

   // custom colors defined in this scheme
   foreach (auto i in rb->getNumRules()) {
      se.color.SymbolColorRule *rule = rb->getRule(i-1);
      if (rule == null) continue;
      ctl_parent_color._lbadd_item(rule->m_ruleName);
   }

}

/**
 * Load all the information about the scheme with the given name into 
 * the symbol coloring configuration dialog.  Generally speaking, this 
 * function fills in the tree control containing the list of rules. 
 *  
 * @param name    Symbol coloring scheme name 
 */
static void loadScheme() {
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();

   // find the selected rule base by name
   origIgnore := scc->ignoreChanges();
   scc->setIgnoreChanges(false);

   // set up the list of compatible color schemes
   compatibleCaption := ctl_compatibility_label.p_caption;
   parse compatibleCaption with auto compatibleLabel ":" auto compatibleList;
   compatibleList = rb->getCompatibleColorProfiles();
   if (compatibleList == "") compatibleList = se.color.SYMBOL_COLOR_COMPATIBLE_ALL;
   ctl_compatibility_label.p_caption = compatibleLabel ": " compatibleList;
   
   // set up the parent rule list with the default colors
   // and this scheme's rule names 
   ctl_parent_color.loadParentRuleList(rb);

   // load all the individual symbol color rules
   ctl_rules._TreeBeginUpdate(TREE_ROOT_INDEX);
   ctl_rules._TreeDelete(TREE_ROOT_INDEX,'c');
   foreach (auto i in rb->getNumRules()) {
      se.color.SymbolColorRule *rule = rb->getRule(i-1);
      if (rule == null) continue;
      treeIndex := ctl_rules._TreeAddItem(TREE_ROOT_INDEX, rule->m_ruleName, TREE_ADD_AS_CHILD, 0, 0, -1, 0);
      loadRuleIntoTreeNode(rule, treeIndex);
   }
   ctl_rules._TreeEndUpdate(TREE_ROOT_INDEX);

   // save the scheme
   scc->setIgnoreChanges(origIgnore);
   scc->setModified(false);

   // finally, load the first rule
   ctl_rules._TreeTop();
   ctl_rules._TreeRefresh();
   rule := getSymbolColorRule();
   loadRule(rule);
}

/**
 * Refresh all the information about the currently selected rule
 * in the list of rule names and descriptions.
 */
static void updateCurrentRuleInTree()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;

   rule := getSymbolColorRule();
   if (rule == null) return;
   index := ctl_rules._TreeCurIndex();
   loadRuleIntoTreeNode(rule, index);
   ctl_rules.p_redraw=true;

   rb := scc->getCurrentProfile();
   scc->setModified(true);
   ctl_reset_scheme.p_enabled = SymbolColorConfig.hasBuiltinProfile(rb->m_name);
}

/**
 * Update all the rules in the list of rule names and descriptions.
 * This needs to be called when a rule which other rules derive from 
 * changes color or font attributes. 
 */
static void updateAllRulesInTree()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;

   rb := scc->getCurrentProfile();

   treeIndex := ctl_rules._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   while (treeIndex > 0) {
      caption := ctl_rules._TreeGetCaption(treeIndex);
      parse caption with caption "\t" . ;
      rule := rb->getRuleByName(caption);
      if (rule != null) {
         loadRuleIntoTreeNode(rule, treeIndex);
      }
      treeIndex = ctl_rules._TreeGetNextSiblingIndex(treeIndex);
   }
}

/**
 * Load the given rule into the list of rules at the given tree index.
 *  
 * @param rule    Symbol coloring rule 
 * @param index   tree index
 */
static void loadRuleIntoTreeNode(se.color.SymbolColorRule *rule, int index)
{
   rb := getSymbolColorRuleBase();
   if (rb==null) return;

   name := rule->m_ruleName;

   regex := "";
   if (rule->m_classRegex != null && rule->m_classRegex != "") {
      regex = "Class=\"":+rule->m_classRegex"\"";
   }
   if (rule->m_nameRegex != null && rule->m_nameRegex != "") {
      if (regex != "") {
         regex :+= ", ";
      }
      regex :+= "Name=\"":+rule->m_nameRegex"\"";
   }
   if (regex != "") {
      regex = ", ":+regex;
   }

   // need table to fill in attributes
   _str attrsOn[];
   _str attrsOff[];
   foreach (auto tagFlag => auto rc_code in gTagAttributeMap) {
      if ((rule->m_attributeFlagsOn & tagFlag) == tagFlag) {
         attrsOn[attrsOn._length()] = get_message(rc_code);
      } else if ((rule->m_attributeFlagsOff & tagFlag) == tagFlag) {
         attrsOff[attrsOff._length()] = get_message(rc_code);
      }
   }

   // calculate what to show for the list of types, try to show
   // all symbols except if there are a large number of types
   tagTypeArray := rule->getTagTypes();
   kinds := join(tagTypeArray, ", ");
   if (tagTypeArray._length() > 20) {
      numTagTypes := ctl_types._TreeGetNumChildren(TREE_ROOT_INDEX);
      if (tagTypeArray._length() >= numTagTypes - 20) {
         kinds = "All symbol types EXCEPT ";
         _str exceptTagTypeArray[];
         type_index := ctl_types._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
         while (type_index > 0) {
            type_name := ctl_types._TreeGetUserInfo(type_index);
            if (!rule->hasTagType(type_name) && type_name != "UNKNOWN") {
               exceptTagTypeArray :+= type_name;
            }
            type_index = ctl_types._TreeGetNextSiblingIndex(type_index);
         }
         kinds = "All symbol types";
         if ( exceptTagTypeArray._length() > 0 ) {
            kinds :+= " EXCEPT ";
            kinds :+= join(tagTypeArray, ", ");
         }
      }
   }

   attrs := "";
   if (attrsOn._length() > 0) {
      attrs :+= ": ";
      attrs :+= join(attrsOn, ", ");
   }
   if (attrsOff._length() > 0) {
      attrs :+= (attrs != "")? ",":":";
      attrs :+= " EXCLUDE ";
      attrs :+= join(attrsOff, ", ");
   }
   
   colorProfileName := getColorProfileName();
   ctl_rules._TreeSetCaption(index, name"\t"kinds:+regex:+attrs);

   if (rule->m_colorInfo != null) {
      font_flags := rule->m_colorInfo.getFontFlags(rb);
      font_flags &= ~(F_INHERIT_BG_COLOR|F_INHERIT_FG_COLOR|F_INHERIT_STYLE|F_INHERIT_COLOR_ADD_STYLE);
      ctl_rules._TreeSetColor(index, 1, 
                              rule->m_colorInfo.getForegroundColor(rb, colorProfileName),
                              rule->m_colorInfo.getBackgroundColor(rb, colorProfileName),
                              font_flags);
   }
}

/**
 * Change the text in the color selection box depending on whether
 * it is currently enabled or not.  Display slashes when it is
 * disabled, and a message saying to click here when it is enabled.
 */
static void enableColorControl()
{
   inherit := (p_prev.p_value != 0);
   orig_width := p_width;
   p_forecolor = 0x606060;
   if (inherit) {
      p_caption = "/////////////////////////////";
   } else {
      p_caption = "Click to change color...";
   }
   p_width = orig_width; 
}

/**
 * Load the given rule into the Symbol coloring dialog. 
 *  
 * @param rule    Symbol coloring rule 
 */
static void loadRule(se.color.SymbolColorRule *rule)
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   // if they gave us a null rule, disable everything, otherwise enable form
   if (rule == null) {
      enableEntireRuleForm(false);
      return;
   }
   if (ctl_rule_name.p_enabled == false) {
      enableEntireRuleForm(true);
   }

   // disable all on_change callbacks
   origIgnore := scc->ignoreChanges();
   scc->setIgnoreChanges(true);

   // fill in the rule name an dregular expression options
   ctl_rule_name.p_text = rule->m_ruleName;
   ctl_regex_type.p_text = getRegexCaption(rule->m_regexOptions);
   ctl_regex_type._lbfind_and_select_item(rule->m_regexOptions);
   ctl_class_re.p_text  = rule->m_classRegex? rule->m_classRegex:"";
   ctl_name_re.p_text   = rule->m_nameRegex?  rule->m_nameRegex:"";
   
   // fill in the parent rule, it may be a default color
   parentRuleName := rule->m_colorInfo.m_parentName;
   if (parentRuleName == null) {
      ctl_parent_color.p_text = "Window Text";
   } else {
      switch(parentRuleName) {
      case "":
      case CFG_WINDOW_TEXT:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_WINDOW_TEXT)"--");
         break;
      case CFG_FUNCTION:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_FUNCTION)"--");
         break;
      case CFG_KEYWORD:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_KEYWORD)"--");
         break;
      case CFG_PPKEYWORD:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_PREPROCESSOR)"--");
         break;
      case CFG_LIBRARY_SYMBOL:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_LIBRARY_SYMBOL)"--");
         break;
      case CFG_USER_DEFINED:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_USER_DEFINED_SYMBOL)"--");
         break;
      case CFG_HILIGHT:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_HIGHLIGHT)"--");
         break;
      case CFG_SYMBOL_HIGHLIGHT:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_SYMBOL_HIGHLIGHT)"--");
         break;
      case CFG_REF_HIGHLIGHT_0:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_REF_HIGHLIGHT_0)"--");
         break;
      case CFG_REF_HIGHLIGHT_1:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_REF_HIGHLIGHT_1)"--");
         break;
      case CFG_REF_HIGHLIGHT_2:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_REF_HIGHLIGHT_2)"--");
         break;
      case CFG_REF_HIGHLIGHT_3:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_REF_HIGHLIGHT_3)"--");
         break;
      case CFG_REF_HIGHLIGHT_4:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_REF_HIGHLIGHT_4)"--");
         break;
      case CFG_REF_HIGHLIGHT_5:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_REF_HIGHLIGHT_5)"--");
         break;
      case CFG_REF_HIGHLIGHT_6:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_REF_HIGHLIGHT_6)"--");
         break;
      case CFG_REF_HIGHLIGHT_7:
         ctl_parent_color.p_text = ("--"get_message(VSRC_CFG_REF_HIGHLIGHT_7)"--");
         break;
      default:
         if (isinteger(parentRuleName) && (int)parentRuleName >= CFG_FIRST_SYMBOL_COLOR && (int)parentRuleName <= CFG_LAST_SYMBOL_COLOR) {
            cfg := (int)parentRuleName;
            if (cfg < CFG_SYMBOL_COLOR_PALETTE_00) {
               msg_code := VSRC_CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND - 2*(cfg-CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND);
               ctl_parent_color.p_text = ("--"get_message(msg_code)"--");
            } else {
               msg_code := VSRC_CFG_SYMBOL_COLOR_PALETTE_00 - 2*(cfg-CFG_SYMBOL_COLOR_PALETTE_00);
               ctl_parent_color.p_text = ("--"get_message(msg_code)"--");
            }
         } else {
            ctl_parent_color.p_text = parentRuleName;
         }
         break;
      }
   }

   // fill in the color information
   colorProfileName := getColorProfileName();
   rb := scc->getCurrentProfile();
   fontFlags := rule->m_colorInfo.getFontFlags(rb, colorProfileName);
   ctl_foreground_color.p_backcolor = rule->m_colorInfo.getForegroundColor(rb, colorProfileName);
   ctl_background_color.p_backcolor = rule->m_colorInfo.getBackgroundColor(rb, colorProfileName);
   ctl_foreground_inherit.p_value = (fontFlags & F_INHERIT_FG_COLOR)? 1:0;  
   ctl_background_inherit.p_value = (fontFlags & F_INHERIT_BG_COLOR)? 1:0;
   ctl_foreground_color.enableColorControl();
   ctl_background_color.enableColorControl();

   // fill in the font information
   ctl_font_inherit.p_value = (fontFlags & F_INHERIT_STYLE)? 1:0;
   ctl_italic.p_value = (fontFlags & F_ITALIC)? 1:0;  
   ctl_bold.p_value = (fontFlags & F_BOLD)? 1:0;  
   ctl_underline.p_value = (fontFlags & F_UNDERLINE)? 1:0;  
   ctl_normal.p_value = (fontFlags & (F_ITALIC|F_BOLD|F_UNDERLINE))? 0:1;
   ctl_italic.p_enabled = (ctl_font_inherit.p_value == 0);
   ctl_bold.p_enabled = (ctl_font_inherit.p_value == 0);
   ctl_underline.p_enabled = (ctl_font_inherit.p_value == 0);
   ctl_normal.p_enabled = (ctl_font_inherit.p_value == 0);
   
   // fill in the sample color display
   ctl_sample.p_forecolor = ctl_foreground_color.p_backcolor;  
   ctl_sample.p_backcolor = ctl_background_color.p_backcolor;
   ctl_sample.p_font_bold = (fontFlags & F_BOLD) != 0;
   ctl_sample.p_font_italic = (fontFlags & F_ITALIC) != 0;
   ctl_sample.p_font_underline = (fontFlags & F_UNDERLINE) != 0;

   // fill in tag types
   index := ctl_types._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   while (index > 0) {
      type_name := ctl_types._TreeGetUserInfo(index);
      state := rule->hasTagType(type_name)? TCB_CHECKED:TCB_UNCHECKED;
      ctl_types._TreeSetCheckState(index, state);
      index = ctl_types._TreeGetNextSiblingIndex(index);
   }
 
   // fill in tag attributes   
   index = ctl_attributes._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   while (index > 0) {
      state := TCB_PARTIALLYCHECKED;
      tag_flag := ctl_attributes._TreeGetUserInfo(index);
      if ((rule->m_attributeFlagsOn & tag_flag) == tag_flag) {
         state = TCB_CHECKED;
      } else if ((rule->m_attributeFlagsOff & tag_flag) == tag_flag) {
         state = TCB_UNCHECKED;
      }
      ctl_attributes._TreeSetCheckState(index, state);
      index = ctl_attributes._TreeGetNextSiblingIndex(index);
   }

   // done, back to business as usual 
   scc->setIgnoreChanges(origIgnore);
}

/**
 * Load the symbol coloring scheme names into a combo box 
 *  
 * @param scc                 symbol coloring configuration manager object 
 * @param colorProfileName    only load schemes compatible with this master scheme 
 * @param includeAutomatic    include "Automatic" color profile 
 * @param includeOnlyBuiltin  only include built-in symbol color profiles 
 */
void _lbaddSymbolColoringSchemeNames(_str colorProfileName="", bool includeAutomatic=false, bool includeOnlyBuiltin=false)
{
   // load all the scheme names into the combo box, putting
   // user defined schemes at the top of the list.
   parse colorProfileName with colorProfileName "(modified)";
   colorProfileName = strip(colorProfileName);

   _str profileNames[];
   SymbolColorRuleBase.listProfiles(profileNames);
   name := "";
   _lbclear();
   if (includeAutomatic) {
      _lbadd_item(CONFIG_AUTOMATIC, 60, _pic_lbvs);
   }

   foreach (name in profileNames) {
      if (SymbolColorConfig.hasBuiltinProfile(name)) {
         _lbadd_item(name,60,_pic_lbvs);
      } else if (!includeOnlyBuiltin) {
         _lbadd_item(name,60,_pic_lbuser);
      }
   }


   p_picture = _pic_lbvs;
   p_pic_space_y = 60;
   p_pic_point_scale = 8;
}

void _symbol_color_form.on_create()
{
   // The symbol color configuration dialog manager object goes
   // in the p_user of 'ctl_scheme'
   ctl_scheme.p_user = null;
   SymbolColorConfig scc;

   // load all the scheme names into the combo box, putting
   // user defined schemes at the top of the list.
   ctl_scheme._lbaddSymbolColoringSchemeNames(includeAutomatic: true);

   // determine the current scheme, select none if we do not have one
   currentProfileName := SymbolColorRuleBase.getDefaultSymbolColorProfile();
   if (def_symbol_color_profile == "" || def_symbol_color_profile == CONFIG_AUTOMATIC) {
      ctl_scheme.p_text = CONFIG_AUTOMATIC;
   } else {
      ctl_scheme.p_text = currentProfileName;
   }
   rb:=scc.loadProfile(currentProfileName);
   ctl_scheme.p_user = scc;

   // determine the current color profile
   editorProfileName  := ColorScheme.getDefaultProfile();
   if (!_no_child_windows()) editorProfileName = _mdi.p_child.p_WindowColorProfile;
   ctl_compatibility.p_user = editorProfileName;

   // enable and disable buttons based on whether this scheme is 
   // a user/system scheme
   updateButtons();

   // set up the list of compatible color schemes
   compatibleCaption := ctl_compatibility_label.p_caption;
   parse compatibleCaption with auto compatibleLabel ":" auto compatibleList;
   compatibleList = rb->getCompatibleColorProfiles();
   if (compatibleList == "") compatibleList = se.color.SYMBOL_COLOR_COMPATIBLE_ALL;
   ctl_compatibility_label.p_caption = compatibleLabel ": " compatibleList; 
   
   // set up the symbol rule list tree control
   columnWidth := ctl_rules.p_width intdiv 3;
   ctl_rules._TreeSetColButtonInfo(0, columnWidth, TREE_BUTTON_DYNAMIC_WIDTH, -1, "Rule name"); 
   ctl_rules._TreeSetColButtonInfo(1, columnWidth*2, TREE_BUTTON_WRAP, -1, "Symbol declaration");
   ctl_rules._TreeSizeColumnToContents(0);
   ctl_rules._TreeAdjustLastColButtonWidth(); 

   // adjust size of browse button for parent color
   sizeBrowseButtonToTextBox(ctl_parent_color.p_window_id, 
                             ctl_color_browse.p_window_id, 0, 
                             ctl_sample.p_x_extent);

   // insert all of the standard tag types, as well as the special
   // item for symbol not found
   tree_index := 0;
   ctl_types._TreeBeginUpdate(TREE_ROOT_INDEX);
   for (i:=SE_TAG_TYPE_FIRSTID; i<=SE_TAG_TYPE_MAXIMUM; i++) {
      tag_get_type(i, auto type_name);
      if (tag_tree_type_is_statement(type_name)) continue;
      if (type_name == '') continue;
      if (type_name == "tag" || type_name == "taguse") continue;
      if (type_name == "unknown" || type_name == "miscellaneous" || type_name == "container") continue;
      description := tag_type_get_description(i);
      if (description == null || description == '') description = type_name;
      tree_index = ctl_types._TreeAddItem(TREE_ROOT_INDEX, description, TREE_ADD_AS_CHILD,
                                          0, 0, TREE_NODE_LEAF, 0, type_name);
      ctl_types._TreeSetCheckable(tree_index, 1, 0);
   }
   tree_index = ctl_types._TreeAddItem(TREE_ROOT_INDEX, SYMBOL_COLOR_NOT_FOUND, TREE_ADD_AS_CHILD,
                                        0, 0, TREE_NODE_LEAF, 0, "UNKNOWN");
   ctl_types._TreeSetCheckable(tree_index, 1, 0);
   ctl_types._TreeEndUpdate(TREE_ROOT_INDEX);
   ctl_types._TreeSortCaption(TREE_ROOT_INDEX);

   // insert all the the symbol tag attributes
   ctl_attributes._TreeBeginUpdate(TREE_ROOT_INDEX);
   foreach (auto tag_flag => auto rc_code in gTagAttributeMap) {
      attr_description := get_message(rc_code);
      if (attr_description == null || attr_description=='') continue;
      tree_index = ctl_attributes._TreeAddItem(TREE_ROOT_INDEX, 
                                               attr_description, TREE_ADD_AS_CHILD,
                                               0, 0, TREE_NODE_LEAF, 0, tag_flag);
      ctl_attributes._TreeSetCheckable(tree_index, 1, 1);
   }
   ctl_attributes._TreeEndUpdate(TREE_ROOT_INDEX);
   ctl_attributes._TreeSortCaption(TREE_ROOT_INDEX);

   // load regular expression types
   //ctl_regex_type._lbadd_item(RE_TYPE_UNIX_STRING);
   //ctl_regex_type._lbadd_item(RE_TYPE_BRIEF_STRING);
   ctl_regex_type._lbadd_item(RE_TYPE_SLICKEDIT_STRING);
   ctl_regex_type._lbadd_item(RE_TYPE_PERL_STRING);
   ctl_regex_type._lbadd_item(RE_TYPE_VIM_STRING);
   ctl_regex_type._lbadd_item(RE_TYPE_WILDCARD_STRING);
   ctl_regex_type._lbadd_item(RE_TYPE_NONE);
   ctl_regex_type.p_enabled = true;
   ctl_regex_type._lbfind_and_select_item(RE_TYPE_NONE);
   ctl_sample._use_edit_font();

   // finally, load the current symbol coloring scheme into the form 
   loadScheme();

   // check if there is a rule we should pre-select, corresponding to the
   // current symbol under the cursor.
   if (!_no_child_windows()) {
      se.color.SymbolColorAnalyzer *analyzer = _mdi.p_child._GetBufferInfoHtPtr("SymbolColorAnalyzer");
      if (analyzer != null) {
         orig_wid := p_window_id;
         p_window_id = _mdi.p_child;
         currentRule := analyzer->getSymbolColorUnderCursor();
         p_window_id = orig_wid;
         if (currentRule != null) {
            
            treeIndex := ctl_rules._TreeSearch(TREE_ROOT_INDEX, currentRule->m_ruleName, '', null, 0);
            if (treeIndex < 0) {
               // try just a prefix search
               treeIndex = ctl_rules._TreeSearch(TREE_ROOT_INDEX, currentRule->m_ruleName, "P", null, 0);
            }

            if (treeIndex > 0) {
               ctl_rules._TreeSetCurIndex(treeIndex);
            }
         }
      }
   }

}

/**
 * Cleanup
 */
void _symbol_color_form.on_destroy()
{
   // destroy the config object
   p_user = null;
}

/**
 * Handle form resizing.  Stretches out the rule list
 * vertically.  Stretches out kinds and attributes horizontally. 
 * Other items remain in the same relative positions. 
 */
void _symbol_color_form.on_resize()
{
   // if the minimum width has not been set, it will return 0
   if (!_minimum_width()) {
      min_rules_height := ctl_color_frame.p_height;
      _set_minimum_size(ctl_save_scheme_as.p_width*6, min_rules_height*2);
   }

   // total size
   width  := _dx2lx(p_xyscale_mode,p_active_form.p_client_width);
   height := _dy2ly(p_xyscale_mode,p_active_form.p_client_height);

   // calculate the horizontal and vertical adjustments
   adjust_x := (width - ctl_rename_scheme.p_width - ctl_rules.p_x) - ctl_rename_scheme.p_x;
   adjust_y := (height - ctl_regex_frame.p_height - ctl_scheme.p_y) - ctl_regex_frame.p_y;

   // adjust the scheme buttons
   ctl_rename_scheme.p_x += adjust_x; 
   ctl_delete_scheme.p_x += adjust_x;
   ctl_reset_scheme.p_x += adjust_x;
   ctl_save_scheme_as.p_x += adjust_x;
   ctl_scheme.p_width += adjust_x;
   ctl_compatibility_label.p_width += adjust_x;
   ctl_compatibility.p_x += adjust_x;
   ctl_scheme_divider.p_width += adjust_x;
   ctl_compatibility.p_y = ctl_rename_scheme.p_y_extent + max(0, (ctl_scheme_divider.p_y - ctl_rename_scheme.p_y_extent - ctl_compatibility.p_height + _dy2ly(SM_TWIP,1)));

   // adjust the rules table and buttons
   orig_tree_width := ctl_rules.p_width;
   ctl_rules.p_width += adjust_x;
   ctl_rules.p_height += adjust_y;
   ctl_rules._TreeSizeColumnToContents(0);
   ctl_rules._TreeAdjustLastColButtonWidth(); 

   // adjust the frame positions
   ctl_rule_frame.p_y += adjust_y;
   ctl_regex_frame.p_y += adjust_y;
   ctl_color_frame.p_y += adjust_y;
   ctl_type_frame.p_y = ctl_attr_frame.p_y = ctl_rule_frame.p_y;

   // adjust the frame positions to make room to widen rule name,
   // color and font attributes frame
   fifth_x     := (adjust_x intdiv 5);
   ctl_type_frame.p_x += fifth_x;
   ctl_attr_frame.p_x += fifth_x;
   ctl_regex_frame.p_x += fifth_x;

   // adjust width of rule name
   ctl_rule_frame.p_width += fifth_x;
   ctl_rule_name.p_width  += fifth_x;

   // adjust the width of the color and font attriutes
   ctl_color_frame.p_width += fifth_x;
   ctl_parent_color.p_width += fifth_x;
   ctl_color_browse.p_x += fifth_x;
   ctl_sample.p_width += fifth_x;
   ctl_font_inherit.p_x += fifth_x;
   ctl_normal.p_x += fifth_x;
   ctl_bold.p_x += fifth_x;
   ctl_italic.p_x += fifth_x;
   ctl_underline.p_x += fifth_x;
   ctl_font_divider.p_x += fifth_x;
   ctl_foreground_color.p_width += fifth_x;
   ctl_foreground_inherit.p_x += fifth_x;
   ctl_background_color.p_width += fifth_x;
   ctl_background_inherit.p_x += fifth_x;

   // adjust the symbol type frame size
   two_fifth_x := (2*adjust_x intdiv 5);
   ctl_type_frame.p_width += two_fifth_x;
   ctl_attr_frame.p_width = ctl_type_frame.p_width;
   ctl_attr_frame.p_x += two_fifth_x;
   ctl_types.p_width += two_fifth_x;
   ctl_attributes.p_width = ctl_types.p_width;

   // adjust the regular expression frame
   four_fifth_x := (4*adjust_x intdiv 5);
   ctl_regex_frame.p_width += four_fifth_x;
   ctl_regex_type.p_width += four_fifth_x;
   ctl_class_re.p_width += four_fifth_x;
   ctl_name_re.p_width += four_fifth_x;

   rightAlign := ctl_scheme_divider.p_x_extent;
   alignUpDownListButtons(ctl_rules.p_window_id, rightAlign, 
                          ctl_insert_rule.p_window_id,
                          ctl_up_rule.p_window_id, 
                          ctl_down_rule.p_window_id, 
                          ctl_delete_rule.p_window_id);
}

/**
 * Callback for handling the [OK] or [Apply] buttons on the
 * master configuration dialog when the symbol coloring
 * properties are modified and need to be recalculated.
 */
void _symbol_color_form_apply()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();
   def_symbol_color_profile = rb->m_name;
   _config_modify_flags(CFGMODIFY_DEFVAR);

   // automatically save the current scheme
   rb->saveProfile();

   SymbolColorAnalyzer.initAllSymbolAnalyzers();
   scc->setModified(false);
}

/**
 * Callback to check if the symbol coloring has been modified 
 * since it was first loaded into the dialog. 
 *  
 * @return 'true' if the coloring had been modified.
 */
bool _symbol_color_form_is_modified()
{
   scc := getSymbolColorConfig();
   if (scc == null) return false;
   return scc->isModified();
}

#if 0
/**
 * Callback to restore the symbol coloring options back to their 
 * original state for the given scheme name. 
 *  
 * @param scheme_name   symbol coloring scheme name 
 */
void _symbol_color_form_restore_state(_str scheme_name)
{
   rb := scc->getScheme(scheme_name);
   if (rb == null) return;

   scc->setCurrentScheme(*rb);
   scc->setModified(false);
   ctl_scheme.p_text = rb->m_name;
}   
#endif

/**
 * Callback to export the symbol coloring options.
 * 
 * @param path             path where user symbol coloring schemes should be 
 *                         copied
 * @param currentScheme    the current scheme
 * 
 * @return                 any errors from the export
 */
_str _symbol_color_form_export_settings(_str &path, _str &currentScheme)
{
   error := '';
   _plugin_export_profiles(path,VSCFGPACKAGE_SYMBOLCOLORING_PROFILES);
   // save our current scheme
   currentScheme = def_symbol_color_profile;
   return error;
}

void _convert_symbolcoloring_xml(_str symbolcoloring_xml_file='') {
   do_recycle := false;
   if (symbolcoloring_xml_file=='') {
      symbolcoloring_xml_file = _ConfigPath() :+ "SymbolColoring.xml";
      do_recycle=true;
   }
   if (!file_exists(symbolcoloring_xml_file)) {
      return;
   }
   // Convert to the new .cfg.xml languages settings
   module := "convert_symbolcoloring_xml.ex";
   filename := _macro_path_search(_strip_filename(substr(module,1,length(module)-1), "P"));
   //_message_box('filename='filename);
   if (filename=='') {
      module='convert_symbolcoloring_xml.e';
      filename = _macro_path_search(_strip_filename(substr(module,1,length(module)), "P"));
      //_message_box('h2 filename='filename);
      if (filename=='') {
         filename='convert_symbolcoloring_xml';
      }
   }
   shell(_maybe_quote_filename(filename)' '_maybe_quote_filename(symbolcoloring_xml_file));
   if (do_recycle) {
      recycle_file(_ConfigPath():+'SymbolColoring.xml');
   }
}
/**
 * Callback to import the symbol coloring options from a previous export.
 * 
 * @param path                      file where schemes can be found
 * @param currentScheme             name of the current color scheme
 * 
 * @return                          any errors from the import
 */
_str _symbol_color_form_import_settings(_str file, _str currentScheme)
{
   error := '';

   if (file!='') {
      if (endsWith(file,VSCFGFILEEXT_CFGXML,false,_fpos_case)) {
         error=_plugin_import_profiles(file,VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,2);
      } else {
         _convert_symbolcoloring_xml(file);
      }
   }
   if (_plugin_has_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,currentScheme)) {
      def_symbol_color_profile = currentScheme;
      _config_modify_flags(CFGMODIFY_DEFVAR);
      SymbolColorAnalyzer.initAllSymbolAnalyzers();
   }
   return error;
}

/**
 * Enable or disable the symbol coloring form controls for editing 
 * the current rule. 
 *  
 * @param onoff   'true' to enable, 'false' to disable 
 */
static void enableEntireRuleForm(bool onoff)
{
   ctl_attributes.p_enabled=onoff;
   ctl_background_inherit.p_enabled=onoff;
   ctl_background_label.p_enabled=onoff;
   ctl_bold.p_enabled=onoff;
   ctl_class_re.p_enabled=onoff;
   ctl_class_re_label.p_enabled=onoff;
   ctl_color_frame.p_enabled=onoff;
   ctl_delete_rule.p_enabled=onoff;
   ctl_down_rule.p_enabled=onoff;
   ctl_font_inherit.p_enabled=onoff;
   ctl_foreground_inherit.p_enabled=onoff;
   ctl_foreground_label.p_enabled=onoff;
   ctl_italic.p_enabled=onoff;
   ctl_name_re.p_enabled=onoff;
   ctl_name_re_label.p_enabled=onoff;
   ctl_normal.p_enabled=onoff;
   ctl_parent_color.p_enabled=onoff;
   ctl_parent_label.p_enabled=onoff;
   ctl_regex_frame.p_enabled=onoff;
   ctl_regex_type.p_enabled=onoff;
   ctl_rule_frame.p_enabled=onoff;
   ctl_rule_name.p_enabled=onoff;
   ctl_sample.p_enabled=onoff;
   ctl_type_frame.p_enabled=onoff;
   ctl_attr_frame.p_enabled=onoff;
   ctl_types.p_enabled=onoff;
   ctl_underline.p_enabled=onoff;
   ctl_use_label.p_enabled=onoff;
   ctl_up_rule.p_enabled=onoff;

}

/**
 * Handle actions that occur in the rule list, such as when the 
 * user selects a different node. 
 *  
 * @param reason     type of event 
 * @param index      current tree index
 */
void ctl_rules.on_change(int reason,int index)
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;

   if (_TreeGetNumChildren(TREE_ROOT_INDEX) == 0) {
      enableEntireRuleForm(false);
      return;
   }

   switch (reason) {
   case CHANGE_CLINE:
   case CHANGE_SELECTED:
      if (ctl_rule_frame.p_enabled==false) {
         enableEntireRuleForm(true);
      }
      
      loadRule(getSymbolColorRule());
      break;
   }

}

/**
 * Handle deleting the currently selected rule.
 */
void ctl_delete_rule.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();

   index := ctl_rules._TreeCurIndex();
   if (index <= 0) return;

   ruleCaption := ctl_rules._TreeGetCaption(index);
   parse ruleCaption with auto ruleName "\t" . ;
   rb->removeRuleByName(ruleName);
   scc->setModified(true);
   ctl_reset_scheme.p_enabled = (SymbolColorConfig.hasBuiltinProfile(rb->m_name));

   ctl_rules._TreeDelete(index);
   loadRule(getSymbolColorRule());
}
void ctl_rules.DEL()
{
   call_event(ctl_delete_rule,LBUTTON_UP,'w');
}

/**
 * Handle moving the current rule down one step.
 */
void ctl_down_rule.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();

   index := ctl_rules._TreeCurIndex();
   if (index <= 0) return;

   nextIndex := ctl_rules._TreeGetNextIndex(index);
   if (nextIndex <= 0) return;

   ruleCaption1 := ctl_rules._TreeGetCaption(index);
   parse ruleCaption1 with auto ruleName1 "\t" . ;
   ruleCaption2 := ctl_rules._TreeGetCaption(nextIndex);
   parse ruleCaption2 with auto ruleName2 "\t" . ;

   rb->swapRules(ruleName1, ruleName2);
   scc->setModified(true);
   ctl_reset_scheme.p_enabled = (SymbolColorConfig.hasBuiltinProfile(rb->m_name));
   ctl_rules._TreeMoveDown(index);
}

/**
 * Handle moving the current rule up one step.
 */
void ctl_up_rule.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();
   index := ctl_rules._TreeCurIndex();
   if (index <= 0) return;

   prevIndex := ctl_rules._TreeGetPrevIndex(index);
   if (prevIndex <= 0) return;

   ruleCaption1 := ctl_rules._TreeGetCaption(prevIndex);
   parse ruleCaption1 with auto ruleName1 "\t" . ;
   ruleCaption2 := ctl_rules._TreeGetCaption(index);
   parse ruleCaption2 with auto ruleName2 "\t" . ;

   rb->swapRules(ruleName1, ruleName2);
   scc->setModified(true);
   ctl_reset_scheme.p_enabled = (SymbolColorConfig.hasBuiltinProfile(rb->m_name));
   ctl_rules._TreeMoveDown(prevIndex);
   ctl_rules._TreeDown();
   ctl_rules._TreeUp();
}

/**
 * Handle inserting a new symbol coloring rule. 
 * Inserts the rule and places focus on the rule name for editing. 
 */
void ctl_insert_rule.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();
   if (rb == null) return;
   colorProfileName := getColorProfileName();

   // find the first unused symbol color from the symbol color palette
   se.color.ColorInfo color;
   color.getColor(CFG_WINDOW_TEXT);
   bool rgb_colors_used:[];
   bool symbol_colors_used:[];
   num_rules := rb->getNumRules();
   for (i := 0; i<num_rules; i++) {
      rule_i := rb->getRule(i);
      if (rule_i == null) continue;
      color_i := rule_i->m_colorInfo.getParentColorIndex();
      if (color_i > 0) {
         symbol_colors_used:[color_i] = true;
      }
      rgb_i := rule_i->m_colorInfo.getForegroundColor(rb, colorProfileName);
      rgb_colors_used:[rgb_i] = true;
   }
   for (i = CFG_SYMBOL_COLOR_PALETTE_00; i<CFG_SYMBOL_COLOR_PALETTE_63; i++ ) {
      if (symbol_colors_used._indexin(i)) {
         continue;
      }
      se.color.ColorInfo color_i;
      color_i.getColor(i);
      if (!rgb_colors_used._indexin(color_i.getForegroundColor(rb, colorProfileName))) {
         color.getColor(i);
         color.m_parentName = i;
         color.m_fontFlags = F_INHERIT_ALL;
         break;
      }
   }

   // now make up a rule name for the new symbol color
   se.color.SymbolColorRule rule;
   newName := "User Defined Rule";
   for (i=1;;++i) {
      newName='User':+i;
      if(rb->getRuleIndex(newName)<0) {
         break;
      }
   }
   rule.m_ruleName = newName;
   rule.m_colorInfo = color;

   position := ctl_rules._TreeCurLineNumber();
   rb->addRule(rule,0 /* append to beginning*/);

   treeIndex := ctl_rules._TreeCurIndex();
   // Let's add this as the first child so user settings override subsequent rules.
   first_child:=ctl_rules._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
   if (first_child>0) {
      treeIndex = ctl_rules._TreeAddItem(first_child, rule.m_ruleName, TREE_ADD_BEFORE, 0, 0, -1, 0);
   } else {
      treeIndex = ctl_rules._TreeAddItem(TREE_ROOT_INDEX, rule.m_ruleName, TREE_ADD_AS_CHILD, 0, 0, -1, 0);
   }
   /*if (ctl_rules._TreeGetNumChildren(TREE_ROOT_INDEX)==0) {
      treeIndex = ctl_rules._TreeAddItem(TREE_ROOT_INDEX, rule.m_ruleName, TREE_ADD_AS_CHILD, 0, 0, -1, 0);
   } else {
      treeIndex = ctl_rules._TreeAddItem(treeIndex, rule.m_ruleName, TREE_ADD_AFTER, 0, 0, -1, 0);
   } */
   ctl_rules._TreeSetCurIndex(treeIndex);
   loadRule(&rule);
   loadRuleIntoTreeNode(&rule, treeIndex);
   ctl_rule_name._set_focus();

   scc->setModified(true);
   ctl_reset_scheme.p_enabled = (SymbolColorConfig.hasBuiltinProfile(rb->m_name));
}

static _str color_picker_cb(int reason, typeless user_data, typeless info=null)
{
   _nocheck _control ctl_tree;
   switch (reason) {
   case SL_ONINITFIRST:
      tree_index := ctl_tree._TreeGetFirstChildIndex(TREE_ROOT_INDEX);
      while ( tree_index > 0 ) {
         cfg := ctl_tree._TreeGetUserInfo(tree_index);
         parse _default_color(cfg) with auto fg_color ' ' auto bg_color ' ' . ;
         ctl_tree._TreeSetRowColor(tree_index, (int)fg_color, (int)bg_color, 0);
         tree_index = ctl_tree._TreeGetNextSiblingIndex(tree_index);
      }
      break;
   }
   return '';
}

void ctl_color_browse.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();
   if (rb == null) return;

   _str ids[];
   _str names[];

   // insert basic built-in colors
   ids :+= CFG_WINDOW_TEXT;
   names :+= "--"get_message(VSRC_CFG_WINDOW_TEXT)"--";
   ids :+= CFG_FUNCTION;
   names :+= "--"get_message(VSRC_CFG_FUNCTION)"--";
   ids :+= CFG_KEYWORD;
   names :+= "--"get_message(VSRC_CFG_KEYWORD)"--";
   ids :+= CFG_PPKEYWORD;
   names :+= "--"get_message(VSRC_CFG_PREPROCESSOR)"--";
   ids :+= CFG_LIBRARY_SYMBOL;
   names :+= "--"get_message(VSRC_CFG_LIBRARY_SYMBOL)"--";
   ids :+= CFG_USER_DEFINED;
   names :+= "--"get_message(VSRC_CFG_USER_DEFINED_SYMBOL)"--";
   ids :+= CFG_HILIGHT;
   names :+= "--"get_message(VSRC_CFG_HIGHLIGHT)"--";
   ids :+= CFG_SYMBOL_HIGHLIGHT;
   names :+= "--"get_message(VSRC_CFG_SYMBOL_HIGHLIGHT)"--";

   // Theme colors designated for symbol coloring.
   for (cfg := CFG_FIRST_SYMBOL_COLOR; cfg < CFG_LAST_SYMBOL_COLOR; cfg++) {
      if (cfg < CFG_SYMBOL_COLOR_PALETTE_00) {
         msg_code := VSRC_CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND - 2*(cfg-CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND);
         ids :+= cfg;
         names :+=  "--"get_message(msg_code)"--";
      } else {
         msg_code := VSRC_CFG_SYMBOL_COLOR_PALETTE_00 - 2*(cfg-CFG_SYMBOL_COLOR_PALETTE_00);
         ids :+= cfg;
         names :+=  "--"get_message(msg_code)"--";
      }
   }

   // find which symbol colors are used and unused
   colorProfileName := getColorProfileName();
   se.color.ColorInfo color;
   color.getColor(CFG_WINDOW_TEXT);
   bool rgb_colors_used:[];
   bool symbol_colors_used:[];
   num_rules := rb->getNumRules();
   for (i := 0; i<num_rules; i++) {
      rule_i := rb->getRule(i);
      if (rule_i == null) continue;
      color_i := rule_i->m_colorInfo.getParentColorIndex();
      if (color_i > 0) {
         symbol_colors_used:[color_i] = true;
      }
      rgb_i := rule_i->m_colorInfo.getForegroundColor(rb, colorProfileName);
      rgb_colors_used:[rgb_i] = true;
   }

   // create an array for which items to check off
   for (i = 0; i<ids._length(); i++) {
      if (symbol_colors_used._indexin(ids[i])) {
         names[i] = "In use\t"names[i];
         continue;
      } else {
         se.color.ColorInfo color_i;
         color_i.getColor(i);
         if (rgb_colors_used._indexin(color_i.getForegroundColor(rb, colorProfileName))) {
            names[i] = "In use\t"names[i];
            continue;
         }
      }
      names[i] = "Available\t"names[i];
   }

   // now pop up a dialog to select which parent rule to use
   result := select_tree(names, ids, 
                         callback: color_picker_cb, 
                         caption: "Select a built-in color to use",
                         SL_COLWIDTH|SL_DESELECTALL,
                         "Used,Color Element");
   if (result == COMMAND_CANCELLED_RC || result == "") {
      return;
   }

   foreach (i => cfg in ids) {
      if (cfg == result) {
         ctl_parent_color._cbset_text(names[i]);
         ctl_parent_color.call_event(CHANGE_CLINE,1,ctl_parent_color,ON_CHANGE,'');
         break;
      }
   }
}

/**
 * Prompt the user for a new symbol color scheme name, this is done both 
 * for saving the current scheme and renaming the scheme. 
 *  
 * @param scc              symbol coloring configuration manager object
 * @param origProfileName   original scheme name (being renamed or saved) 
 * @param allowSameName    allow them to use the same name (to save a user scheme) 
 * 
 * @return '' if they cancelled, otherwise returns the new scheme name 
 */
static _str getSymbolcolorProfileName(_str origProfileName)
{
   // prompt the user for a new scheme name
   loop {
      status := textBoxDialog("Enter Profile Name", 0, 0, 
                              "New Symbol Color Profile dialog", 
                              "", "", " Profile name:":+origProfileName);
      if (status < 0) {
         break;
      }
      newProfileName := _param1;
      if (newProfileName == "") {
         break;
      }

      // verify that the new name does not duplicate an existing name
      if (newProfileName != CONFIG_AUTOMATIC && !_plugin_has_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,newProfileName)) {
         return newProfileName;
      }

      _message_box("There is already a profile named \""newProfileName".\"");
      continue;
   }

   // command cancelled due to error
   return "";
}

/**
 * Handle switching schemes.  If the current scheme is modified from it's 
 * saved settings, prompt the user before switching schemes. 
 *  
 * @param reason  event type
 */
void ctl_scheme.on_change(int reason)
{
   if (reason == CHANGE_CLINE) {

      scc := getSymbolColorConfig();
      if (scc == null) return;
      if (scc->ignoreChanges()) return;
      rb := scc->getCurrentProfile();
     
      // prompt about saving the former scheme
      if (scc->profileChanged()) {
         buttons := "&Save Changes,&Discard Changes,Cancel:_cancel\t-html The current profile has been modified.  Would you like to save your changes?";

         status := textBoxDialog('SlickEdit Options',
                                 0,
                                 0,
                                 'Modified Color Profile',
                                 buttons);
         if (status == 1) {            // Save - the first button
            rb->saveProfile();
            scc->setModified(false);
         } else if (status == 2) {     // Discard Changes - the second button
            //loadScheme();
         } else {                      // Cancel our cancellation
            ctl_scheme.p_text = rb->m_name;
            return;
         }
      }
      orig_profile_name:=rb->m_name;

      // warn them if the selected scheme is not compatible with the
      // current color scheme
      profileName := strip(p_text);
      profileName = SymbolColorRuleBase.getDefaultSymbolColorProfile(profileName);
      scc->loadProfile(profileName);
      rb = scc->getCurrentProfile();
      window_color_profile_name := ColorScheme.realProfileName(def_color_scheme);
      parse window_color_profile_name with auto colorProfileName '(' . ;
      if (rb != null && !rb->isCompatibleWithColorProfile(strip(colorProfileName))) {
         result := _message_box(get_message(VSRC_CFG_COLOR_SCHEME_INCOMPATIBLE),'',MB_YESNO|MB_ICONQUESTION);
         if ( result == IDNO ) {
            ctl_scheme.p_text = orig_profile_name;
            return; //exit, no change
         }
      }

      loadScheme();
      scc->setModified(true);

      // enable and disable buttons based on whether this scheme is 
      // a user/system scheme
      updateButtons();
   }
}

static void updateButtons()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();

   ctl_delete_scheme.p_enabled = ctl_rename_scheme.p_enabled = !SymbolColorConfig.hasBuiltinProfile(rb->m_name);
   ctl_reset_scheme.p_enabled = SymbolColorConfig.isModifiedBuiltinProfile(rb->m_name);
}

/**
 * Delete the current scheme.  Do not allow them to delete system schemes.
 */
void ctl_delete_scheme.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (ctl_scheme.p_text == CONFIG_AUTOMATIC) return;
   rb := scc->getCurrentProfile();

   if (_plugin_has_builtin_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,rb->m_name)) {
      // This button is supposed to be disabled
      //_message_box(get_message(VSRC_CFG_CANNOT_REMOVE_SYSTEM_SCHEMES));
      return;
   }
   mbrc := _message_box("Are you sure you want to delete the profile '"rb->m_name"'?  This action can not be undone.", "Confirm Profile Delete", MB_YESNO | MB_ICONEXCLAMATION);
   if (mbrc!=IDYES) {
      return;
   }
   _plugin_delete_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,rb->m_name);

   ctl_scheme._lbdelete_item();

   colorProfileName := getColorProfileName();
   defaultProfileName := rb->initDefaultRuleBase(colorProfileName);
   ctl_scheme._cbset_text(defaultProfileName);
   scc->loadProfile(defaultProfileName);

   loadScheme();
   updateButtons();

   // set modified again, to note that the current selection has changed
   scc->setModified(true);
}

/**
 * Resets the current scheme back to its installed configuration.  Only allowed 
 * on System schemes that have been modified. 
 */
void ctl_reset_scheme.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();

   name := rb->m_name;
   if (name == CONFIG_AUTOMATIC) {
      name = SymbolColorRuleBase.getDefaultSymbolColorProfile(name);
   }
   scc->loadProfile(name,1/* Load the built-in profile */);

   loadScheme();

   ctl_reset_scheme.p_enabled = false;
   scc->setModified(true);
}

/**
 * Save the current scheme under a new name as a user-defined scheme.
 */
void ctl_save_scheme_as.lbutton_up()
{
   if (save_changes_first()) {
      return;
   }
   copyCurrentProfile();
   updateButtons();
}

static void copyCurrentProfile()
{
   // get the configuration object
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();

   // prompt the user for a new scheme name
   origProfileName := rb->m_name;
   if (origProfileName == CONFIG_AUTOMATIC) {
      origProfileName = SymbolColorRuleBase.getDefaultSymbolColorProfile(origProfileName);
   }

   newProfileName := getSymbolcolorProfileName(origProfileName);
   if (newProfileName == "") return;

   rb->m_name = newProfileName;
   rb->saveProfile();
   scc->setModified(false);
   if (newProfileName != origProfileName) {
      ctl_scheme._lbbottom();
      ctl_scheme._lbadd_item(newProfileName,60,_pic_lbuser);
      ctl_scheme._lbsort('i');
      scc->setIgnoreChanges(true);
      ctl_scheme.p_text = newProfileName;
      scc->setIgnoreChanges(false);
      loadScheme();
   }

   // set modified again, to note that the current selection has changed
   scc->setModified(true);
}
static bool save_changes_first() {
   scc := getSymbolColorConfig();
   if (scc == null) return true;
   
   if (scc->profileChanged()) {
      buttons := "&Save Changes,&Discard Changes,Cancel:_cancel\t-html The current symbol coloring profile has been modified.  Would you like to save your changes?";

      status := textBoxDialog('SlickEdit Options',
                              0,
                              0,
                              'Modified Symbol Coloring Profile',
                              buttons);
      if (status == 1) {            // Save - the first button
         rb := scc->getCurrentProfile();
         rb->saveProfile();
         scc->setModified(false);
      } else if (status == 2) {     // Discard Changes - the second button
         //loadScheme(rb->m_name);
      } else {                      // Cancel our cancellation
         return true;
      }
   }
   return false;
}

/**
 * Rename the current scheme.  Do not allow them to rename system 
 * default schemes. 
 */
void ctl_rename_scheme.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();

   // only allow them to rename user schemes
   origProfileName := rb->m_name;
   if ((SymbolColorConfig.hasBuiltinProfile(rb->m_name))) {
      // This button is supposed to be disabled.
      //_message_box(get_message(VSRC_CFG_CANNOT_FIND_USER_SCHEME, origProfileName));
      return;
   }
   if (save_changes_first()) {
      return;
   }

   // prompt the user for a new scheme name
   newProfileName  := getSymbolcolorProfileName(origProfileName);
   if (newProfileName == "") return;

   rb->m_name = newProfileName; 
   rb->saveProfile();
   _plugin_delete_profile(VSCFGPACKAGE_SYMBOLCOLORING_PROFILES,origProfileName);
   ctl_scheme._lbset_item(newProfileName);
   ctl_scheme.p_text = newProfileName;

   
   // set modified again, to note that the current selection has changed
   scc->setModified(true);
   updateButtons();
}

/**
 * Rename the current scheme.  Do not allow them to rename system 
 * default schemes. 
 */
void ctl_compatibility.lbutton_up()
{
   // get the configuration object
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();

   orig_wid := p_window_id;
   // find all the user defined color schemes
   typeless i;
   profileName := "";
   _str colorProfileNames[];
   _plugin_list_profiles(VSCFGPACKAGE_COLOR_PROFILES, colorProfileNames);
   colorProfileNames._insertel(se.color.SYMBOL_COLOR_COMPATIBLE_LIGHT, 0);
   colorProfileNames._insertel(se.color.SYMBOL_COLOR_COMPATIBLE_DARK,  0);
   origCompatibleSchemes := "," :+ rb->getCompatibleColorProfiles() :+ ",";

   // build a list of which ones are compatible
   _str profileNameIndexes[];
   bool selectedProfileNames[];
   selectedProfileNames[colorProfileNames._length()-1] = false;
   for (i = 0; i < colorProfileNames._length(); ++i) {
      profileName = colorProfileNames[i];
      profileNameIndexes[i] = i;
      if (pos(","profileName",", origCompatibleSchemes)) {
         selectedProfileNames[i] = true;
      } else {
         selectedProfileNames[i] = rb->isCompatibleWithColorProfile(profileName);
      }
   }

   // prompt them to select which ones are compatible
   result := '';
   do {
      result = select_tree(colorProfileNames, 
                                profileNameIndexes, null, null, 
                                selectedProfileNames, null, null,
                                "Compatible Color Profiles",
                                SL_CHECKLIST|SL_SELECTALL|SL_INVERT, 
                                null, null, true,
                                "Compatible Color Profiles dialog box");
      if (result == '') {
         _message_box("If no color profiles are marked as compatible, you will not be ":+
                      "able to use this symbol coloring profile.  Please select at least ":+
                      "one compatible color profile.", "Compatible Color Profile");
      }

   } while (result == '');

   p_window_id = orig_wid;

   if (result == null || result == COMMAND_CANCELLED_RC) {
      return;
   }

   // go through the list and see if they checked dark or light
   _str compatibleProfiles[];
   haveDarkBackgrounds := false;
   haveLightBackgrounds := false;
   orig_result := result;
   while (result != "") {
      parse result with i "\n" result;
      if (!isinteger(i)) continue;
      selectedScheme := colorProfileNames[(int)i];
      if (selectedScheme == se.color.SYMBOL_COLOR_COMPATIBLE_DARK) {
         haveDarkBackgrounds = true;
         compatibleProfiles :+= selectedScheme;
      } else if (selectedScheme == se.color.SYMBOL_COLOR_COMPATIBLE_LIGHT) {
         haveLightBackgrounds = true;
         compatibleProfiles :+= selectedScheme;
      }
   }
   result = orig_result;

   // pull the information back in
   while (result != "") {
      parse result with i "\n" result;
      if (!isinteger(i)) continue;
      selectedScheme := colorProfileNames[(int)i];
      if (selectedScheme == se.color.SYMBOL_COLOR_COMPATIBLE_DARK) continue;
      if (selectedScheme == se.color.SYMBOL_COLOR_COMPATIBLE_LIGHT) continue;
      if (haveDarkBackgrounds && ColorScheme.isDarkColorProfile(selectedScheme)) {
         continue;
      }
      if (haveLightBackgrounds && !ColorScheme.isDarkColorProfile(selectedScheme)) {
         continue;
      }
      compatibleProfiles :+= selectedScheme;
   }

   // we selected all, so just set it to blank
   if (compatibleProfiles._length() == colorProfileNames._length()) {
      compatibleProfiles._makeempty();
   }

   rb = getSymbolColorRuleBase();
   rb->setCompatibleColorProfiles(compatibleProfiles);

   // set up the list of compatible color schemes
   compatibleCaption := ctl_compatibility_label.p_caption;
   parse compatibleCaption with auto compatibleLabel ":" auto compatibleList;
   compatibleList = rb->getCompatibleColorProfiles();
   if (compatibleList == "") compatibleList = se.color.SYMBOL_COLOR_COMPATIBLE_ALL;
   ctl_compatibility_label.p_caption = compatibleLabel ": " compatibleList;
   scc->setModified(true);
   ctl_reset_scheme.p_enabled = (SymbolColorConfig.hasBuiltinProfile(rb->m_name));

   // this may renamed the scheme to (modified) if it is a system scheme
   updateCurrentRuleInTree();
}

/**
 * Handle when the user toggles tag attribute flags on/off/don't care 
 * in the tree control containing all the tag attributes. 
 *  
 * @param reason     event type  
 * @param index      current tree index
 */
void ctl_attributes.on_change(int reason,int index)
{
   //say("HERE, reason="reason" index="index);
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;
   rule := getSymbolColorRule();
   if (rule == null) return;
   showChildren := 0;

   switch (reason) {
   case CHANGE_CHECK_TOGGLED:
      showChildren = _TreeGetCheckState(index);
      tree_flag := (SETagFlags)_TreeGetUserInfo(index);
      if (showChildren == TCB_PARTIALLYCHECKED) {
         rule->m_attributeFlagsOn &= ~tree_flag;
         rule->m_attributeFlagsOff &= ~tree_flag;
      } else if (showChildren == TCB_CHECKED) {
         rule->m_attributeFlagsOn |= tree_flag;
         rule->m_attributeFlagsOff &= ~tree_flag;
      } else if (showChildren == TCB_UNCHECKED) {
         rule->m_attributeFlagsOn &= ~tree_flag;
         rule->m_attributeFlagsOff |= tree_flag;
      }
      updateCurrentRuleInTree();
      break;
   }
}

/**
 * Handle when the user toggles tag types on/off/don't care 
 * in the tree control containing all the different kinds of symbols. 
 *  
 * @param reason     event type  
 * @param index      current tree index
 */
void ctl_types.on_change(int reason,int index)
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;
   rb := scc->getCurrentProfile();
   rule := getSymbolColorRule();
   if (rule == null) return;

   switch (reason) {
   case CHANGE_CHECK_TOGGLED:
      // need table to fill in types
      _str typeList[];
      index = _TreeGetFirstChildIndex(TREE_ROOT_INDEX);
      while (index > 0) {
         showChildren := _TreeGetCheckState(index);
         if (showChildren > 0) {
            typeList[typeList._length()] = _TreeGetUserInfo(index);
         }
         index = _TreeGetNextSiblingIndex(index);
      }
      rule->setTagTypeArray(typeList,rb->m_name);
      scc->setModified(true);
      ctl_reset_scheme.p_enabled = (SymbolColorConfig.hasBuiltinProfile(rb->m_name));
      updateCurrentRuleInTree();
      break;
   }
}

/**
 * Handle changes to the currently selected symbol coloring rule name. 
 * Rule name changes are processed in the lost-focus event so that 
 * editing rules requires less processing and to minimize the number 
 * of renames. 
 */
void ctl_rule_name.on_lost_focus()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();
   rule := getSymbolColorRule();
   if (rule == null) return;

   origRuleName := rule->m_ruleName;
   changed_name := false;
   if (rb->getRuleIndex(p_text)<0 && substr(p_text,1,2)!='__') {
      rule->m_ruleName = p_text;
      rb->renameRuleParents(origRuleName, p_text);
      changed_name=true;
   }
    
   index := ctl_rules._TreeCurIndex();
   loadRuleIntoTreeNode(rule, index);

   if (changed_name) {
      scc->setModified(true);
      ctl_reset_scheme.p_enabled = (SymbolColorConfig.hasBuiltinProfile(rb->m_name));
   }
   updateAllRulesInTree();
   loadParentRuleList(rb);
   updateCurrentRuleInTree();
}

static void _SymbolColoringReloadColors()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   rb := scc->getCurrentProfile();
   rule := getSymbolColorRule();
   if (rule == null) return;

   // get the name of the symbol coloring scheme they are working on
   name := rb->m_name;
   if (name == CONFIG_AUTOMATIC) {
      name = SymbolColorRuleBase.getDefaultSymbolColorProfile(name);
   }

   loadScheme();
   scc->setModified(false);
   updateCurrentRuleInTree();
   updateAllRulesInTree();
}

void _color_profile_modified_symbol_coloring()
{
   wid:=_find_formobj('_symbol_color_form','N');
   if (wid != 0) {
      wid._SymbolColoringReloadColors();
   }
}

/**
 * If the user hits "enter" after typing in a rule name, we should 
 * not dismiss the dialog, just transfer control to the rule list.
 */
void ctl_rule_name.enter()
{
   ctl_rules._set_focus();
}

/**
 * @return Return the search option (needed by {@link pos()} for the
 * selected regular expression.  (Unix='r', Brief='b', SlickEdit='r', 
 * and Wildcards='&').
 */
static _str getRegexSearchOption(_str caption)
{
   // TBF:  names should come from the message file
   switch (caption) {
   //case RE_TYPE_UNIX_STRING:        return 'u';
   //case RE_TYPE_BRIEF_STRING:       return 'b';
   case RE_TYPE_SLICKEDIT_STRING:   return 'r';
   case RE_TYPE_PERL_STRING:        return 'l';
   case RE_TYPE_VIM_STRING:         return '~';
   case RE_TYPE_WILDCARD_STRING:    return '&';
   case RE_TYPE_NONE:               return '';
   }
   return '';
}

/**
 * Return the caption corresponding to the given regular expression 
 * search option. 
 *  
 * @param searchOption     Regular expression search option, as 
 *                         required by pos() or search(). 
 * 
 * @return String describing this regular expression search option.
 */
static _str getRegexCaption(_str searchOption)
{
   // TBF:  names should come from the message file
   switch (searchOption) {
   case 'u':  return RE_TYPE_PERL_STRING; // RE_TYPE_UNIX_STRING; converted to Perl
   case 'b':  return RE_TYPE_PERL_STRING; // RE_TYPE_BRIEF_STRING; converted to Perl
   case 'r':  return RE_TYPE_SLICKEDIT_STRING;
   case 'l':  return RE_TYPE_PERL_STRING;
   case '~':  return RE_TYPE_VIM_STRING;
   case '&':  return RE_TYPE_WILDCARD_STRING;
   case '':   return RE_TYPE_NONE;
   }
   return RE_TYPE_NONE;
}

/**
 * Handle when the user changes the regular expression type. 
 */
void ctl_regex_type.on_change(int reason)
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;
   rule := getSymbolColorRule();
   if (rule == null) return;
   rule->m_regexOptions = getRegexSearchOption(p_text);
   updateCurrentRuleInTree();
}

/**
 * Handle when the user changes the class name regular expression.
 */
void ctl_class_re.on_change()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;
   rule := getSymbolColorRule();
   if (rule == null) return;
   rule->m_classRegex = p_text;
   updateCurrentRuleInTree();
}

/**
 * Handle when the user changes the symbol name regular expression.
 */
void ctl_name_re.on_change()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;
   rule := getSymbolColorRule();
   if (rule == null) return;
   rule->m_nameRegex = p_text;
   updateCurrentRuleInTree();
}

/** 
 * Handle when the user changes the color or rule which the current 
 * rule should inherit color settings from. 
 */
void ctl_parent_color.on_change(int reason)
{
   if (reason == CHANGE_CLINE) {
      rule := getSymbolColorRule();
      if (rule == null) return;
      rb := getSymbolColorRuleBase();
      if (rb == null) return;
      
      item := p_text;
      if (_first_char(item) == '-' && _last_char(item) == '-') {
         if ( p_text == "--"get_message(VSRC_CFG_WINDOW_TEXT)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_WINDOW_TEXT;
         } else if ( p_text == "--"get_message(VSRC_CFG_FUNCTION)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_FUNCTION;
         } else if ( p_text == "--"get_message(VSRC_CFG_KEYWORD)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_KEYWORD;
         } else if ( p_text == "--"get_message(VSRC_CFG_PREPROCESSOR)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_PPKEYWORD;
         } else if ( p_text == "--"get_message(VSRC_CFG_LIBRARY_SYMBOL)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_LIBRARY_SYMBOL;
         } else if ( p_text == "--"get_message(VSRC_CFG_USER_DEFINED_SYMBOL)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_USER_DEFINED;
         } else if ( p_text == "--"get_message(VSRC_CFG_HIGHLIGHT)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_HILIGHT;
         } else if ( p_text == "--"get_message(VSRC_CFG_SYMBOL_HIGHLIGHT)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_SYMBOL_HIGHLIGHT;
         } else if ( p_text == "--"get_message(VSRC_CFG_REF_HIGHLIGHT_0)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_REF_HIGHLIGHT_0;
         } else if ( p_text == "--"get_message(VSRC_CFG_REF_HIGHLIGHT_1)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_REF_HIGHLIGHT_1;
         } else if ( p_text == "--"get_message(VSRC_CFG_REF_HIGHLIGHT_2)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_REF_HIGHLIGHT_2;
         } else if ( p_text == "--"get_message(VSRC_CFG_REF_HIGHLIGHT_3)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_REF_HIGHLIGHT_3;
         } else if ( p_text == "--"get_message(VSRC_CFG_REF_HIGHLIGHT_4)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_REF_HIGHLIGHT_4;
         } else if ( p_text == "--"get_message(VSRC_CFG_REF_HIGHLIGHT_5)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_REF_HIGHLIGHT_5;
         } else if ( p_text == "--"get_message(VSRC_CFG_REF_HIGHLIGHT_6)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_REF_HIGHLIGHT_6;
         } else if ( p_text == "--"get_message(VSRC_CFG_REF_HIGHLIGHT_7)"--" ) {
            rule->m_colorInfo.m_parentName = CFG_REF_HIGHLIGHT_7;
         } else {
            for (cfg := CFG_FIRST_SYMBOL_COLOR; cfg <= CFG_LAST_SYMBOL_COLOR; cfg++) {
               if (cfg < CFG_SYMBOL_COLOR_PALETTE_00) {
                  // Theme colors designated for symbol coloring.
                  msg_code := VSRC_CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND - 2*(cfg-CFG_SYMBOL_COLOR_SYMBOL_NOT_FOUND);
                  if ( p_text == "--"get_message(msg_code)"--" ) {
                     rule->m_colorInfo.m_parentName = cfg;
                     break;
                  }
               } else {
                  // Extended symbol coloring pallette colors designated or symbol coloring.
                  msg_code := VSRC_CFG_SYMBOL_COLOR_PALETTE_00 - 2*(cfg-CFG_SYMBOL_COLOR_PALETTE_00);
                  if ( p_text == "--"get_message(msg_code)"--" ) {
                     rule->m_colorInfo.m_parentName = cfg;
                     break;
                  }
               }
            }
         }
      } else {
         rule->m_colorInfo.m_parentName = p_text;
      }

      colorProfileName := getColorProfileName();
      updateCurrentRuleInTree();
      updateAllRulesInTree();
      fontFlags := rule->m_colorInfo.getFontFlags(rb, colorProfileName);
      ctl_bold.p_value = (fontFlags & F_BOLD)? 1:0;
      ctl_italic.p_value = (fontFlags & F_ITALIC)? 1:0;
      ctl_underline.p_value = (fontFlags & F_UNDERLINE)? 1:0;
      ctl_normal.p_value = (ctl_bold.p_value==0 && ctl_italic.p_value==0 && ctl_underline.p_value==0)? 1:0;

      ctl_sample.p_font_bold = (ctl_bold.p_value != 0);
      ctl_sample.p_font_italic = (ctl_italic.p_value != 0);
      ctl_sample.p_font_underline = (ctl_underline.p_value != 0);

      ctl_foreground_color.p_backcolor = rule->m_colorInfo.getForegroundColor(rb, colorProfileName);
      ctl_background_color.p_backcolor = rule->m_colorInfo.getBackgroundColor(rb, colorProfileName);
      ctl_sample.p_forecolor = rule->m_colorInfo.getForegroundColor(rb, colorProfileName);
      ctl_sample.p_backcolor = rule->m_colorInfo.getBackgroundColor(rb, colorProfileName);
   }
}

/**
 * Handle changes in font settings.  This event handler is also used by
 * by the Inherit Font, Bold, Italic, and Underline radio buttons
 */
void ctl_normal.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;

   rb := scc->getCurrentProfile();
   rule := getSymbolColorRule();
   if (rule == null) return;

   font_flag := 0;
   switch (p_name) {
   case "ctl_normal":       font_flag = 0x0; break;
   case "ctl_bold":         font_flag = F_BOLD; break;
   case "ctl_italic":       font_flag = F_ITALIC; break; 
   case "ctl_underline":    font_flag = F_UNDERLINE; break;
   case "ctl_font_inherit": font_flag = F_INHERIT_STYLE; break;
   }

   inheritColorFlags := (ctl_background_inherit.p_value? F_INHERIT_BG_COLOR:0) |
                        (ctl_foreground_inherit.p_value? F_INHERIT_FG_COLOR:0) |
                        (ctl_font_inherit.p_value? F_INHERIT_STYLE:0);
   if (p_value) {
      rule->m_colorInfo.m_fontFlags = font_flag|inheritColorFlags;
   } else {
      rule->m_colorInfo.m_fontFlags &= ~font_flag;
   }

   if (font_flag == 0 && p_value) {
      rule->m_colorInfo.m_fontFlags &= ~(F_BOLD|F_ITALIC|F_UNDERLINE);
   } else if (font_flag == F_INHERIT_STYLE) {
      rule->m_colorInfo.m_fontFlags &= ~(F_BOLD|F_ITALIC|F_UNDERLINE);
      ctl_bold.p_enabled = (p_value == 0);
      ctl_italic.p_enabled = (p_value == 0);
      ctl_underline.p_enabled = (p_value == 0);
      ctl_normal.p_enabled = (p_value == 0);

      colorProfileName := getColorProfileName();
      fontFlags := rule->m_colorInfo.getFontFlags(rb, colorProfileName);
      ctl_bold.p_value = (fontFlags & F_BOLD)? 1:0;
      ctl_italic.p_value = (fontFlags & F_ITALIC)? 1:0;
      ctl_underline.p_value = (fontFlags & F_UNDERLINE)? 1:0;
      ctl_normal.p_value = (ctl_bold.p_value==0 && ctl_italic.p_value==0 && ctl_underline.p_value==0)? 1:0;
   }

   ctl_sample.p_font_underline = (ctl_underline.p_value != 0);
   ctl_sample.p_font_italic = (ctl_italic.p_value != 0);
   ctl_sample.p_font_bold = (ctl_bold.p_value != 0);
   updateCurrentRuleInTree();
   updateAllRulesInTree();
}

/**
 * Handle changes in foreground or background color inheritance.
 */
void ctl_foreground_inherit.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;

   p_next.enableColorControl();

   colorProfileName := getColorProfileName();
   rb := scc->getCurrentProfile();
   rule := getSymbolColorRule();
   if (rule == null) return;

   if (p_name == "ctl_background_inherit") {
      orig_bg := rule->m_colorInfo.getBackgroundColor(rb, colorProfileName);
      if (p_value) {
         rule->m_colorInfo.m_fontFlags |= F_INHERIT_BG_COLOR;
      } else {
         rule->m_colorInfo.m_background = orig_bg;
         rule->m_colorInfo.m_fontFlags &= ~F_INHERIT_BG_COLOR;
      }
   } else {
      orig_fg := rule->m_colorInfo.getForegroundColor(rb, colorProfileName);
      if (p_value) {
         rule->m_colorInfo.m_fontFlags |= F_INHERIT_FG_COLOR;
      } else {
         rule->m_colorInfo.m_foreground = orig_fg;
         rule->m_colorInfo.m_fontFlags &= ~F_INHERIT_FG_COLOR;
      }
   }

   ctl_foreground_color.p_backcolor = rule->m_colorInfo.getForegroundColor(rb, colorProfileName);
   ctl_background_color.p_backcolor = rule->m_colorInfo.getBackgroundColor(rb, colorProfileName);
   ctl_sample.p_forecolor = rule->m_colorInfo.getForegroundColor(rb, colorProfileName);
   ctl_sample.p_backcolor = rule->m_colorInfo.getBackgroundColor(rb, colorProfileName);
   updateCurrentRuleInTree();
   updateAllRulesInTree();
}

/**
 * Handle changes in the foreground or background color setting. 
 */
void ctl_foreground_color.lbutton_up()
{
   scc := getSymbolColorConfig();
   if (scc == null) return;
   if (scc->ignoreChanges()) return;

   if (p_prev.p_value) {
      rule := getSymbolColorRule();
      if (rule == null) return;
      cfg := rule->m_colorInfo.getParentColorIndex();
      if (cfg > 0) {
         mbrc := _message_box("Warning:  Using a built-in color. Edit default color profile setting?\n\n":+
                              "Uncheck 'Inherit'to customize this color just for Symbol Coloring.", 
                              "Edit Built-in Color", MB_YESNO|MB_ICONEXCLAMATION);
         if (mbrc!=IDYES) {
            return;
         }
         color := ctl_foreground_color.p_backcolor;
         new_color := show_color_picker(color);
         if (new_color == '' || new_color == COMMAND_CANCELLED_RC || new_color == color) {
            return;
         }

         // modify the color remotely in the colors dialog
         orig_wid := p_window_id;
         wid:=_find_formobj('_color_form','N');
         if (!wid) config('Colors', 'N', cfg);
         if (wid!=0) {
            if (p_name == "ctl_foreground_color") {
               wid._ColorFormSetForegroundColor(cfg, new_color);
               config('Symbol Coloring', 'N');
            } else {
               wid._ColorFormSetBackgroundColor(cfg, new_color);
               config('Symbol Coloring', 'N');
            }
         }

         // update controls
         p_window_id = orig_wid;
         if (p_name == "ctl_foreground_color") {
            rule->m_colorInfo.m_foreground = new_color;
            ctl_foreground_color.p_backcolor = new_color;
            ctl_sample.p_forecolor = new_color;
         } else {
            rule->m_colorInfo.m_background = new_color;
            ctl_background_color.p_backcolor = new_color;
            ctl_sample.p_backcolor = new_color;
         }

         // update everything else
         updateCurrentRuleInTree();
         updateAllRulesInTree();
      }
      return;
   }
   color := p_backcolor;
   if ((int)color < 0 || (color & 0x80000000) ||
       (int)color == VSDEFAULT_FOREGROUND_COLOR || 
       (int)color == VSDEFAULT_BACKGROUND_COLOR) {
      color = 0x0;
   }
   color = show_color_picker(color);
   if (color == COMMAND_CANCELLED_RC) return;

   p_backcolor = color;

   rule := getSymbolColorRule();
   if (rule == null) return;

   rb := scc->getCurrentProfile();
   if (p_name == "ctl_foreground_color") {
      rule->m_colorInfo.m_foreground = color;
   } else {
      rule->m_colorInfo.m_background = color;
   }

   colorProfileName := getColorProfileName();
   ctl_sample.p_backcolor = rule->m_colorInfo.getBackgroundColor(rb, colorProfileName);
   ctl_sample.p_forecolor = rule->m_colorInfo.getForegroundColor(rb, colorProfileName);
   updateCurrentRuleInTree();
   updateAllRulesInTree();
}

/**
 * If they added a tag file, we should recalculate symbol colors.
 */
void _TagFileAddRemove_symbol_color(_str file_name, _str options)
{
   SymbolColorAnalyzer.resetAllSymbolAnalyzers();
}

void _TagFileRefresh_symbol_color()
{
   SymbolColorAnalyzer.resetAllSymbolAnalyzers();
}
