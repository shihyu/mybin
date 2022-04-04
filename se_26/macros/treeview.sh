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
#pragma option(metadata,"treeview.e")

enum TreeCheckVal {
   TCB_UNCHECKED,
   TCB_CHECKED,
   TCB_PARTIALLYCHECKED
};

enum TreeViewEditorState {
   TREEVIEWEEDITOR_ERROR =   1,
   TREEVIEWEEDITOR_CLOSING = 2,
};

enum TreeSortOrder {
   TREEVIEW_ASCENDINGORDER,
   TREEVIEW_DESCENDINGORDER
};

/**
 * Send a specific keyboard command to a tree control. 
 * The supported commands are below:
 *  
 * @param command 
 * <ul> 
 * <li>pagedown 
 * <li>pageup
 * <li>up
 * <li>down
 * <li>s-up
 * <li>s-down
 * <li>home
 * <li>end
 * <li>c-home
 * <li>c-end
 * <li>s-home
 * <li>s-end
 * <li>c-s-home
 * <li>c-s-end 
 * <li>c-a 
 * <li>enter 
 * <li>right 
 * </ul> 
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeCommand(_str command);

/**
 * Reset any data cached for tree controls. 
 * For example, the tree caches images for overlayed bitmap 
 * combinations.  This function will force those bitmaps to
 * be recalculated, for example, if new sizes or styles were
 * loaded. 
 * 
 * This function does not have to be called on a tree view
 * instance.
 *
 * @categories Tree_View_Methods
 */
extern void _TreeResetCache();

/**
 * Gets the index of the next selected item in the tree view
 *
 * @param ff Set to 1 to find the first item
 * @param info used internally
 *
 * @return Next selected tree control index,  <0 if there are no
 *         more selected items.
 *
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int  _TreeGetNextSelectedIndex(int ff,int &info);

/**
 * Gets the index of the next checked item in the tree view
 *
 * @param ff Set to 1 to find the first item
 * @param info used internally
 *
 * @return Next checked tree control index,  <0 if there are no
 *         more checked items.
 *
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int  _TreeGetNextCheckedIndex(int ff,int &info);

/**
 * Gets the index of the previous checked item in the tree view
 *
 * @param ff Set to 1 to find the last item
 * @param info used internally.  SHARED WITH _TreeGetNextCheckedIndex
 *
 * @return Prev checked tree control index,  <0 if there are no
 *         more checked items.
 *
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int  _TreeGetPrevCheckedIndex(int fl,int &info);

extern int _TreeUncheckAll();

/**
 * @return number of items selected in the tree
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int  _TreeGetNumSelectedItems();

/**
 * Select the line specified by the given index.
 *
 *
 * @param index            index of line to select
 * @param deselectAll      true to deselect all currently 
 *                         selected nodes before selecting new
 *                         one
 *
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 **/
extern void _TreeSelectLine(int index,bool deselectAll=false);

/**
 * Deselect the node specifeid by <B>ItemIndex</B>
 *
 * @param index Node to deselect
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeDeselectLine(int);

/**
 * Find out if the node specified by <B>ItemIndex</B> is
 * selected
 *
 * @param index item to check
 *
 * @return int non-zero if true
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int  _TreeIsSelected(int);

/**
 * Deselect all items in the tree
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeDeselectAll();

/**
 * Select all items in the tree
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeSelectAll();

/**
 * Invert the selection in the tree
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeInvertSelection();

/**
 * Sizes the specified column to the amount of space necessary
 * for its contents
 *
 * @param col column of item to size (0 is the leftmost, -1 to resize all columns) 
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeSizeColumnToContents(int col);

/**
 * Set combo box data for all items in a given column
 *
 * @param index column of item to set data for (0 is the
 *                 leftmost)
 * @param comboBoxLines Lines to be filled in when combo box is
 *                      dropped
 * @param comboBoxStyle One of the PSCBO_* styles.  Defaults to
 *                      PSCBO_NOEDIT
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeSetComboDataCol(int col,STRARRAY comboBoxLines,...);

/**
 * Get combo box data for all items in a given column
 *
 * @param col column of item to set data for (0 is the leftmost)
 * @param comboBoxLines Lines to be filled in when combo box is
 *                      dropped
 * @param comboBoxStyle One of the PSCBO_* styles.  Defaults to
 *                      PSCBO_NOEDIT
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeGetComboDataCol(int col ,STRARRAY comboBoxLines,...);

/**
 * Set combo box data for a given node and column
 *
 * @param index index of item to set data for
 * @param col column of item to set data for (0 is the
 *                 leftmost)
 * @param comboBoxLines Lines to be filled in when combo box is
 *                      dropped
 * @param comboBoxStyle One of the PSCBO_* styles.  Defaults to
 *                      PSCBO_NOEDIT
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeSetComboDataNodeCol(int index,int col,STRARRAY comboBoxLines,...);

/**
 * Get combo box data for a given node and column
 *
 * @param index index of item to set data for
 * @param col column of item to set data for (0 is the
 *                 leftmost)
 * @param comboBoxLines Filled in with times from combo box
 * @param comboBoxStyle One of the PSCBO_* styles.
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeGetComboDataNodeCol(int index,int col,STRARRAY comboBoxLines,...);

/**
 * Edit the treenode specified by <B>ItemIndex</B>
 *
 * @param index tree node to edit
 * @param colIndex column index to edit, defaults to 0
 *                 (leftmost)
 *
 * @return int 0 if successful
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeEditNode(int index,...);

/**
 *
 * @param col Column to get or set width of
 * @param newWidth New width for column <b>col</b>.  Use -1
 *                 (default) to not set
 *
 * @return int width of <B>col</B>
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeColWidth(int col,...);

/**
 * Set whether or not a tree node is checkable
 *
 * @param index Handle to tree node to set checkable
 * @param checkable 1 for checkable, 0 for non-checkable
 * @param isTriState 1 for tri-state, 0 for 2-state.  NOTE: for
 *                   tri-state checkbox in the treeview, the
 *                   third (TCB_PARTIALLYCHECKED )state can only
 *                   be set programatically.
 * @param checkedState Initial state of check box, one the
 *                     following members of the TreeCheckVal
 *                     enum:
 *                        * TCB_UNCHECKED
 *                        * TCB_CHECKED
 *                        * TCB_PARTIALLYCHECKED
 * @param col Column of tree node to set checkable
 *                 (defaults to 0)
 *
 * @return int 0 if successful
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeSetCheckable(int index,int checkable,int isTriState,.../*int checkedState=TCB_UNCHECKED,int col=0*/);

/**
 * Set the check state of a tree node
 *
 * @param index Handle to tree node to set check state for
 * @param checkedState State of check box, one the following
 *                     members of the TreeCheckVal enum:
 *                        * TCB_UNCHECKED
 *                        * TCB_CHECKED
 *                        * TCB_PARTIALLYCHECKED
 * @param col Column of tree node to set checkable
 *                 (defaults to 0)
 *
 * @return int 0 if successful
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeSetCheckState(int index,int checkedState,...);

/**
 * Get the check state of a tree node
 *
 * @param ItemIndex Handle to tree node to get check state for
 * @param ColIndex Column of tree node to set checkable
 *                 (defaults to 0)
 *
 * @return int State of check box, one the following members of
 *         the TreeCheckVal enum:
 *            * TCB_UNCHECKED
 *            * TCB_CHECKED
 *            * TCB_PARTIALLYCHECKED
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetCheckState(int iHandle,...);
/**
 * Commit data in the editor (text/combo box) currently 
 * displayed in the tree to the tree.
 *  
 * @param index index of tree node with editor
 * @param col column of tree node with editor 
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 * @return int 0 if succesful
 */
extern int _TreeCommitEditorData(int index,int col);
/**
 * Close the editor (text/combo box) currently displayed in the 
 * tree. 
 *  
 * @param index index of tree node with editor
 * @param col column of tree node with editor
 * @param commitData if not 0, save the data in the editor to 
 *                   the tree.
 * 
 * @return int 0 if succesful, otherwise INVALID_ARGUMENT_RC
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeCloseEditor(int index,int col,int commitData);
/**
 * Set edit style for a node
 * 
 * @param index index of node to change edit style for 
 * @param col column of node to change edit style for
 * @param flags combination of the following: 
 * <UL>
 *  <LI>TREE_EDIT_TEXTBOX            // must be used exclusively</LI>
 *  <LI>TREE_EDIT_COMBOBOX           // must be used exclusively</LI>
 *  <LI>TREE_EDIT_EDITABLE_COMBOBOX  //must be used exclusively</LI>
 *  <LI>TREE_EDIT_BUTTON             // Can be used in combination with one of the other styles</LI>
 * </UL>
 */
extern void _TreeSetNodeEditStyle(int index,int col,int flags);

/** 
 * Get the node edit style for the specified node and column 
 *  
 * @param index index of node to get edit style for
 * @param col column to get edit style for
 * 
 * @return int a combination of TREE_EDIT_* flags if <B>col</B> 
 *         is valid, or -1 if it is not
 */
extern int _TreeGetNodeEditStyle(int index,int col);

/** 
 * Get the col edit style for the specified column 
 *  
 * @param index index of node to get edit style for
 * @param col column to get edit style for
 * 
 * @return int a combination of TREE_EDIT_* flags if <B>col</B> 
 *         is valid, or -1 if it is not
 */
extern int _TreeGetColEditStyle(int col);

/**
 * Set edit style for a column
 * 
 * @param col column of node to change edit style for
 * @param flags combination of the following: 
 * <UL>
 *  <LI>TREE_EDIT_TEXTBOX            // must be used exclusively</LI>
 *  <LI>TREE_EDIT_COMBOBOX           // must be used exclusively</LI>
 *  <LI>TREE_EDIT_EDITABLE_COMBOBOX  // must be used exclusively</LI>
 *  <LI>TREE_EDIT_BUTTON             // Can be used in combination with one of the other styles</LI>
 * </UL>
 */
extern void _TreeSetColEditStyle(int col,int flags);

/** 
 * Set the state of the editor (text/combo box) currently shown 
 * by the tree 
 * 
 * @param iState a constant from TreeViewEditorState 
 *               (TREEVIEWEEDITOR_ERROR or
 *               TREEVIEWEEDITOR_CLOSING)
 */
extern void _TreeSetEditorState(int iState);

/** 
 * Get the state of the editor (text/combo box) currently shown 
 * by the tree 
 * 
 * @return int A member of TreeViewEditorState, or 0 if no state 
 *         has been set.
 */
extern int _TreeGetEditorState();

/**
 * @return int Width of the longest line in the tree (in twips)
 */
extern int _TreeFindLongestLine();

/**
 * @return Returns {@code true} if the given index is a valid index in the current tree.
 * 
 * @param ItemIndex  tree node index to test 
 * 
 * @see _TreeSetCurIndex
 *
 * @appliesTo Tree_View
 *
 * @categories Tree_View_Methods
 */
extern int _TreeIndexIsValid(int ItemIndex);

/**
 * Retrieves the line number associated with the given tree
 * index.
 *
 * @param index          tree index
 *
 * @return int             line number
 *
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetLineNumber(int index);

/** 
 * Set the type of a treenode of a tree to a date so that the 
 * dates will be sorted properly and displayed according to the 
 * OS's settings. Do not set the caption if you use this. 
 *  
 * @param index       tree node index
 * @param col         tree column
 * @param year        year
 * @param month       month 1-12
 * @param day         day 1-31
 * @param hour        (optional) 0-23
 * @param minute      (optional) 0-59
 * @param second      (optional) 0-59
 * @param millisecond (optional) 0-999 
 * @param maybeShowMS (optional, default {@code true}) if locale time format specifies to
 *                    to show milliseconds, then do so, otherwise, allow it to be omitted.
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeSetDateTime(int index,int column,int year,int month,int day,...);
/**
 * For a treenode with a date set using {@link _TreeSetDateTime}, return 
 * a formatted date string. 
 * 
 * @param index       tree node index
 * @param column      tree column
 * @param date        (output) set to formatted dates
 * @param format      format string
 *                    <dl compact>
 *                    <dt>{@literal 'L'}</dt>
 *                    <dd>Returns time in the current local format. 
 *                        Under Windows, this uses the regional settings "Time style." 
 *                        For other platforms, the format is settable
 *                        under "Appearance -&gt; General -&gt; Time display style.".</dd>
 *                    <dt>{@literal 'S'}</dt>
 *                    <dd>Returns date and time in the current locale short format. 
 *                        Under Windows, this uses the regional settings "Short date style".
 *                        and "Time style."  For other platforms, the format is settable
 *                        under "Appearance -&gt; General -&gt; Date display style." and
 *                        under "Appearance -&gt; General -&gt; Time display style."</dd>
 *                    <dt>{@literal 'F'}</dt>
 *                    <dd>Return time in the format {@code YYYYMMDDhhmmssfff}
 *                        where <i>YYYY</i> is the year, <i>MM</i> is the month, 
 *                        <i>DD</i> is the day, <i>hh</i> is an hour between 0 and 23, 
 *                        <i>mm</i> is the minutes between 0 and 59, <i>ss</i> is the 
 *                        seconds between 0 and 59, and <i>fff</i> is the fractional 
 *                        second, in milliseconds. This value is always in
 *                        UTC/GMT.</dd> 
 *                    <dt>{@literal 'I'}</dt>
 *                    <dd>Returns the date and time in the ISO 8601 format with milliseconds
 *                        {@code yyyy-MM-ddTHH:mm:ss}</dd>
 *                    <dt>{@code format}</dt>
 *                    <dd>Format a string according to the given format specifier, 
 *                        which may include:
 *                        <UL>
 *                        <LI>YYYY -- 4 digit year
 *                        <LI>YY -- 2 digit year
 *                        <LI>MM -- 2 digit month
 *                        <LI>XM -- 1-2 digit month
 *                        <LI>month -- English name of month, lower case
 *                        <LI>Month -- English name of month, capitalized
 *                        <LI>MONTH -- English name of month, upper case
 *                        <LI>mon -- English name of month, lower case, three letters
 *                        <LI>Mon -- English name of month, capitalized, three letters
 *                        <LI>MON -- English name of month, upper case, three letters
 *                        <LI>DD -- 2 digit day of month
 *                        <LI>XD -- 1-2 digit day of month
 *                        <LI>weekday -- English name of day of week, lower case
 *                        <LI>Weekday -- English name of day of week, capitalized
 *                        <LI>WEEKDAY -- English name of day of week, upper case
 *                        <LI>day -- English name of day of week, lower case, three letters
 *                        <LI>Day -- English name of day of week, capitalized, three letters
 *                        <LI>DAY -- English name of day of week, upper case, three letters
 *                        <LI>HH -- 2 digit 24-hour clock hours
 *                        <LI>XH -- 1-2 digit 24-hour clock hours
 *                        <LI>hh -- 2 digit 12-hour clock hours
 *                        <LI>xh -- 1-2 digit 12-hour clock hours
 *                        <LI>PM -- 12-hour clock hours AM/PM
 *                        <LI>mm -- minutes
 *                        <LI>ss -- seconds
 *                        <LI>mmm -- milliseconds
 *                        <LI>uuuuuu -- microseconds
 *                        </UL>
 *                    </dd>
 *                    </dl> 
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeGetDateTimeStr(int index,int column,_str &date,_str format='L');

/**
 * Set the item specified by <B>index</B> and <B>column</B> to 
 * switch state value (will set the item to a switch if 
 * necessary) 
 *  
 * @param index tree node index
 * @param col  tree column
 * @param value Value to set switch to
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern void _TreeSetSwitchState(int index,int column,bool value);

/**
 * Get the value of the switch item specified by <B>index</B> 
 * and <B>column</B>.  If this was not a switch, it will return 
 * -1. 
 *  
 * @param index tree node index
 * @param col  tree column
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetSwitchState(int index,int column);

/** 
 * @return 
 * Returns the height of the treeview's hearder in pixels.
 * Returns 0 if there is not one, and &lt; 0 on error.
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetHeaderHeight();

/** 
 * @return 
 * Returns the width of the treeview's border in pixels.
 * Returns 0 if there is not one, and &lt; 0 on error.
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetBorderWidth();

/** 
 * @return 
 * Returns the width of the treeview's vertical scrollbar in pixels (if visible).
 * Returns 0 if there is not one, and &lt; 0 on error.
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetVScrollBarWidth();

/** 
 * @return 
 * Returns the height of the treeview's horizontal scrollbar in pixels (if visible).
 * Returns 0 if there is not one, and &lt; 0 on error.
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetHScrollBarHeight();

/** 
 * @return 
 * Returns the width of the treeview's icons in pixels.
 * Returns 0 if there is not one, and &lt; 0 on error.
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetIconWidth();

/** 
 * @return 
 * Returns the height of the treeview's icons in pixels.
 * Returns 0 if there is not one, and &lt; 0 on error.
 *  
 * @appliesTo Tree_View
 * @categories Tree_View_Methods
 */
extern int _TreeGetIconHeight();

/** 
 * Sizes the last column to the width of the tree. 
 */
extern void _TreeSizeLastColumnToTreeWidth();

/**
 * Retrieves a tree's current sort column.
 *
 * @return Current sort column
 *
 * @appliesTo Tree_View
 *
 * @categories Tree_View_Methods
 *
 */
extern void _TreeGetSortCol(int& sortCol,TreeSortOrder &sortOrder);
extern void _TreeSetHeaderClickable(int Clickable,int ShowSortIndicator=0);

struct TREE_COL_BUTTON_INFO{
   int width;
   int flags;
   _str caption;
};

