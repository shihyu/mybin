////////////////////////////////////////////////////////////////////////////////////
// Copyright 2019 SlickEdit Inc. 
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
#ifndef MAVEN_SH
#define MAVEN_SH
#pragma option(metadata,"maven.e")

// A single dependency. De-facto standard for versions of 
// since the Maven repository got big.
struct MavenDependency
{
   _str groupId; // ie: org.codehaus.plexus
   _str artifactId; // ie: plexus-utils.  Name of the jar without the version, usually.
   _str version; 
};

enum JarPreference {
   PREFER_SRC, PREFER_BINARY
};

// Used by the generic dependency selection dialog, see user_select_external_dependencies().
struct SelectableDep
{
   // This should be the same as the directory path in the N attribute for F in
   // <Files> for the external dependency project.
   _str full_name;   
   // Dependency name, without version number.
   _str dep_name;    
   // version number.
   _str ver; 
   // comment or short desc, if any;
   _str desc;

   // Ignored by user_select_dependencies, but used to communicate back to the
   // caller which dependencies the user selected.
   bool selected;
};

#define JAR_DEPENDENCY_FILE_TYPE "Dependency"
#endif


