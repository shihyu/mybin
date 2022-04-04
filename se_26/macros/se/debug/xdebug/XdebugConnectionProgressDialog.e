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
#require "se/net/IServerConnection.e"
#require "se/net/ServerConnectionObserverDialog.e"
#import "main.e"
#endregion


namespace se.debug.xdebug;

using se.net.IServerConnection;
using se.net.ServerConnectionObserverDialog;


class XdebugConnectionProgressDialog : ServerConnectionObserverDialog {

   /**
    * Constructor.
    */
   XdebugConnectionProgressDialog() {
   }

   /**
    * Destructor.
    */
   ~XdebugConnectionProgressDialog() {
   }

   private void onStatusListen(IServerConnection* server) {
      int timeout = server->getTimeout();
      int elapsed = server->getElapsedTime();
      remain := 0;
      if( timeout < 0 ) {
         // Infinite
         remain = elapsed;
      } else {
         remain = timeout - elapsed;
      }
      if( remain < 0 ) {
         remain = 0;
      }
      // Seconds please
      remain = remain intdiv 1000;
      // The actual host:port we are listening on
      _str host = server->getHost(true);
      _str port = server->getPort(true);
      printMessage(nls("Waiting for Xdebug connection on %s:%s...%s seconds",host,port,remain));
   }

   private void onStatusPending(IServerConnection* server) {
      printMessage("Xdebug connection pending");
   }

   private void onStatusError(IServerConnection* server) {
      int error_rc = server->getError();
      msg :=  "Error waiting for Xdebug connection: ":+get_message(error_rc);
      printCriticalMessage(msg);
      _message_box(msg,"",MB_OK|MB_ICONEXCLAMATION);
   }

};
