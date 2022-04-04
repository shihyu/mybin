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
#pragma option(pedantic, on)
#region Imports
#require "sc/net/ISocketCommon.e"
#endregion

namespace sc.net;

enum XLAT_FLAGS {
   XLATFLAG_NONE  = 0x0,
   XLATFLAG_DOS   = 0x1,
   XLATFLAG_UNIX  = 0x2,
   XLATFLAG_LOCAL = 0x4
};


/**
 * BETA
 *
 * Client socket interface.
 */
interface IClientSocket : ISocketCommon {

   /**
    * Return timeout (in milliseconds) for connections and 
    * receiving data. 
    * 
    * @return Timeout in milliseconds.
    */
   int getTimeout();

   /**
    * Set timeout (in milliseconds) for connections and receiving 
    * data. 
    * 
    * @param timeout  Timeout in milliseconds.
    */
   void setTimeout(int timeout);

   /**
    * Connect to the given host at the given port, and use the
    * specified timeout value. 
    *
    * @param host     The name of the host to connect to ("" 
    *                 implies local host).
    * @param port     The port to attach at. 
    * @param timeout  Number of milliseconds to wait for a 
    *                 connection. Set to 0 to use
    *                 implementation-defined default timeout.
    *                 Defaults to 0.
    *
    * @return 0 on success, <0 on error. 
    */
   int connect(_str host, _str port, int timeout=0);

   /** 
    * Test if this client socket is connected. 
    *
    * @return true if socket is connected. 
    */
   bool isConnected();

   /**
    * Send the given data over the client socket.
    *
    * @param data  Data to send. 
    * @param len   Number of bytes to send. Set to -1 to send all 
    *              bytes. Defaults to -1.
    *
    * @return 0 on success, <0 on error.
    *
    * @see sendBlob
    */
   int send(_str data, int len=-1);

   /**
    * Send data from internal "blob" over the client socket. 
    * Writing starts from the current blob offset. The current blob 
    * offset is not changed. 
    * 
    * <p>
    *
    * A blob is an internal binary buffer for reading and writing
    * arbitrary data. It is especially useful for data that may 
    * contain ascii null (0) bytes which Slick-C does not handle. 
    * Use the Slick-C _Blob* api to get, set, and manipulate 
    * specific types of data. 
    *
    * @param hblob  Handle to blob returned by _BlobAlloc.
    * @param len    Number of bytes to send from blob. Set to -1 to 
    *               send all bytes. Defaults to -1.
    *
    * @return 0 on success, <0 on error.
    *
    * @see send
    */
   int sendBlob(int hblob, int len=-1);

   /**
    * Receive data over the client socket.
    *
    * @param data     (out) String to receive data. 
    * @param peek     Set to true to peek the data without reading 
    *                 it off the socket. Defaults to false.
    * @param timeout  Milliseconds to wait for data. Set to 0 to 
    *                 use implementation-defined default timeout
    *                 for this socket. Defaults to 0.
    *
    * @return 0 on success, <0 on error.
    */
   int receive(_str& data, bool peek=false, int timeout=0);

   /**
    * If there is data pending on the client socket, then receive 
    * the data. Use this method when you do not want to wait on the
    * socket. 
    *
    * @param data  (out) String to receive data. 
    *
    * @return 0 on success, <0 on error, SOCK_NO_MORE_DATA_RC if no 
    *         data is pending on socket.
    */
   int receive_if_pending(_str& data);

   /**
    * Receive data over the client socket and store in a file.
    *
    * @param filename   Name of file in which to store received 
    *                   data.
    * @param xlatFlags  Newline translation flags. This determines 
    *                   how newlines will be translated before
    *                   being written to file. A value of 0
    *                   indicates no translation. Defaults to 0.
    *                   The following flags are available:
    *                    
    *                   <dt>XLATFLAG_DOS</dt><dd>Translate all
    *                   newlines to \r\n</dd>
    *                   <dt>XLATFLAG_UNIX</dt><dd>Translate all
    *                   newlines to \n</dd>
    *                   <dt>XLATFLAG_LOCAL</dt><dd>Translate all
    *                   newlines to the local newline (i.e. \r\n
    *                   for DOS or \n for UNIX)<dd>
    * @param timeout    Milliseconds to wait for data. Set to 0 to 
    *                   use implementation-defined default timeout
    *                   for this client socket. Defaults to 0.
    *
    * @return 0 on success, <0 on error.
    *
    * @see receive
    * @see receieveToBlob
    */
   int receiveToFile(_str filename, XLAT_FLAGS xlatFlags=XLATFLAG_NONE, int timeout=0);

   /**
    * Receive data over the client socket and store in a blob. This
    * method is useful when the data you receive may contain ascii 
    * null (0) bytes which prevent you from using receive. Use the 
    * Slick-C _Blob* api to manipulate data in the blob after 
    * calling this function. 
    *
    * @param hblob    Handle to blob.
    * @param peek     Set to true to peek the data without reading 
    *                 it off the socket. Defaults to false.
    * @param timeout  Milliseconds to wait for data. Set to 0 to 
    *                 use implementation-defined default timeout
    *                 for this client connection. Defaults to 0.
    *
    * @return 0 on success, <0 on error.
    *
    * @see receive
    * @see receieveToFile
    */
   int receiveToBlob(int hblob, bool peek=false, int timeout=0);

   /**
    * Poll for data on the client socket. Data is left on socket. 
    * Returns immediately. 
    *
    * @return True if there is data waiting on the socket.
    */
   bool poll();

   /**
    * Return the remote endpoint IP address that this client socket
    * is connected to. 
    *
    * @return Remote endpoint IP address as string, null if socket 
    *         is not connected.
    */
   _str getRemoteIpAddress();

   /**
    * Return the remote endpoint port that this client socket is 
    * connected to. 
    *
    * @return >0 port, 0 if socket is not connected.
    */
   int getRemotePort();

};
