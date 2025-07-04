(** SocketDStream.Mod 

  Copyright (C) 2025 Artemis Project Contributors
  Released under The 3-Clause BSD License.

  Buffered, sequential socket I/O using DStrings and Riders.
  The API manages partial sends/receives and nonblocking socket state internally.

  Usage:
    IMPORT SocketDStream;
    SocketDStream.WriteDString(...);

    (* Or, for brevity: *)
    IMPORT SDStream := SocketDStream;
    SDStream.WriteDString(...);
*)
MODULE SocketDStream;

IMPORT artSocket, DStrings, Log, Chars;

CONST 
  (* Maximum buffer size for sending/receiving data *)
  MaxBufferSize* = 1024;

TYPE
  SocketDStream* = POINTER TO SocketDStreamDesc;
  SocketDStreamDesc* = RECORD
    socket: artSocket.Socket;
    logger: Log.Logger;
    (* Outbuf is the data to be sent, outrider is the associated rider *)
    (* Inbuf is the data received from the socket, inrider is the associated rider *)
    inBuf*, outBuf*: DStrings.String;
    inRider*, outRider*: DStrings.Rider
  END;

PROCEDURE LogInfoWithData(logger: Log.Logger; label: ARRAY OF CHAR; data: ARRAY OF CHAR);
VAR msg: ARRAY 512 OF CHAR;
BEGIN
  Chars.Copy(label, msg);
  Chars.Append(data, msg);
  Log.Info(logger, msg)
END LogInfoWithData;

(** Initializes a new SocketDStream for the given socket. *)
PROCEDURE Init*(socket: artSocket.Socket; VAR stream: SocketDStream);
BEGIN
  IF stream = NIL THEN
    NEW(stream);
  END;
  stream.logger := Log.New(Log.DEBUG, Log.CONSOLE, "");
  stream.socket := socket;
  DStrings.Init("", stream.inBuf);
  DStrings.Init("", stream.outBuf);
  DStrings.Set(stream.inRider, stream.inBuf, 0);
  DStrings.Set(stream.outRider, stream.outBuf, 0);
  Log.Debug(stream.logger, "SocketDstream initialized.");
END Init;

(** 
  Sends the given DString over the nonblocking socket. Handles buffering and partial sends. 

  You should call SendDString repeatedly as long as it returns WouldBlock or Ok, until all data is sent,
  because we consume data from the stream buffer with each call. 

  sstr -> source DString to send. If the stream buffer is empty, we fill it with the new data from sstr.
  bytesLeft -> remaining unsent data. bytesLeft is always calculated from the current length of 
  the stream buffer after each send, because the buffer is dynamic and can be modified 
  (e.g., partial sends, deletions, appends). 

  Returns the status of the operation (Ok, WouldBlock, etc).
 *)
PROCEDURE SendDString*(stream: SocketDStream; sstr: DStrings.String; VAR bytesLeft: INTEGER): INTEGER;
VAR
  logBuf: ARRAY 256 OF CHAR; (* For debugging purposes *)
  buf: ARRAY MaxBufferSize OF BYTE;
  msgLen, sent, result : INTEGER;
  ok: BOOLEAN;
  done: BOOLEAN;
BEGIN
  done := FALSE;
  IF stream = NIL THEN
    bytesLeft := 0;
    result := artSocket.NotConnected;
    done := TRUE
  END;
  IF ~done THEN
    bytesLeft := 0;
    result := artSocket.UnknownError;
    IF (stream # NIL) & (stream.socket # NIL) THEN
      (* If there is no pending data, copy new data into outBuf *)
      IF DStrings.Length(stream.outBuf) = 0 THEN
        Log.Debug(stream.logger, "Copying data to stream buffer");
        DStrings.Copy(sstr, stream.outBuf);
        DStrings.Set(stream.outRider, stream.outBuf, 0);
      END;
      msgLen := DStrings.Length(stream.outBuf);
      IF msgLen > 0 THEN
        Log.Debug(stream.logger, "Sending data over socket");
        DStrings.ReadBytes(stream.outRider, buf, msgLen);
        result := artSocket.Send(stream.socket, buf, msgLen, sent);
        Chars.IntToString(result, logBuf, ok);
        LogInfoWithData(stream.logger, "Result: ", logBuf);
        (* If the send was successful or would block, we update the rider and buffer *)
        IF (result = artSocket.Ok) OR (result = artSocket.WouldBlock) THEN
          IF sent > 0 THEN
            (* Consume the sent data and update the rider *)
            Log.Debug(stream.logger, "Draining sent data from stream buffer");
            DStrings.Delete(stream.outBuf, 0, sent);
            DStrings.Set(stream.outRider, stream.outBuf, 0);
          END;
          bytesLeft := DStrings.Length(stream.outBuf);
        END
      ELSE
        bytesLeft := 0;
        result := artSocket.Ok
      END
    ELSE
      result := artSocket.NotConnected
    END
  END;
  RETURN result
END SendDString;

(**
  Reads data from the nonblocking socket in a nonblocking way until 
  - the specified delimiter is found OR
  - the socket would block OR
  - the socket is closed  OR
  - any other socket error occurs.

  Call again if artSocket.WouldBlock is returned, as this indicates a partial read.
  The delimiter (if found) is included in dstr. 
  The caller must check 'found' to determine if the delimiter was found.
  If 'found' is FALSE, dstr may contain partial data 
  (if the socket closed or would block occurred before the delimiter).
  
  @param stream - initialized stream descriptor
  @param delim - the delimiter to terminate the read
  @param dstr - the data read, including the delimiter
  @param found - TRUE if delimiter was found, FALSE otherwise.

  @return the status of the socket read. 
*)
PROCEDURE ReadUntil*(stream: SocketDStream; delim: ARRAY OF CHAR; VAR dstr: DStrings.String; VAR found: BOOLEAN): INTEGER;
VAR
  status, pos, received: INTEGER;
  delimStr: DStrings.String;
  buf: ARRAY MaxBufferSize OF BYTE;
  done: BOOLEAN;

  (* 
    Check if delimiter is present in the stream buffer and return its position (if found).

    @param stream - stream descriptor containing the stream buffer.
    @param delimStr - the delimiter we look for.
    @param pos position of first delimiter character in stream buffer or -1 if not found.

    @return TRUE if delimiter found in stream buffer, FALSE otherwise.
  *)
  PROCEDURE HasDelimiterInBuffer(stream: SocketDStream; delimStr: DStrings.String; VAR pos: INTEGER): BOOLEAN;
  VAR
    found: BOOLEAN;
    bufLen: INTEGER;
  BEGIN
    pos := -1;
    bufLen := DStrings.Length(stream.inBuf);
    IF (DStrings.Length(delimStr) > 0) & (bufLen > 0) THEN
      pos := DStrings.Pos(delimStr, stream.inBuf, 0);
    END;
    found := (pos # -1);
    RETURN found
  END HasDelimiterInBuffer;

  (* 
    Copy and delete data up to and including delimiter from the stream buffer into dstr.
    Reset the stream inbuf rider after the data is extracted to the start of the data left in the buffer.

    @param stream - stream descriptor containing the input rider and buffer.
    @param pos - position of delimiter in the stream buffer.
    @param delimLen - length of the delimiter.
    @param dstr - received data including the delimiter.
  *)
  PROCEDURE ExtractUpToAndIncluding(stream: SocketDStream; pos, delimLen: INTEGER; VAR dstr: DStrings.String);
  VAR extractLen: INTEGER;
  BEGIN
    extractLen := pos + delimLen;
    DStrings.Extract(stream.inBuf, 0, extractLen, dstr);
    DStrings.Delete(stream.inBuf, 0, extractLen);
    (* Position the rider to the remaining data for the next read. *)
    DStrings.Set(stream.inRider, stream.inBuf, 0)
  END ExtractUpToAndIncluding;

  (* 
    Drain (copy) the whole stream buffer to dstr, reset the stream buffer and the input rider. 
    
    @param stream - stream descriptor
    @param dstr - target string containing the data from the stream buffer.
   *)
  PROCEDURE DrainBuffer(stream: SocketDStream; VAR dstr: DStrings.String);
  BEGIN
    DStrings.Copy(stream.inBuf, dstr);
    DStrings.Init("", stream.inBuf);
    DStrings.Set(stream.inRider, stream.inBuf, 0)
  END DrainBuffer;

BEGIN
  (* Initialize state *)
  found := FALSE;
  done := FALSE;
  status := artSocket.UnknownError;
  DStrings.Init("", dstr);
  DStrings.Init(delim, delimStr);

  (* Validate args *)
  IF (stream = NIL) OR (dstr = NIL) OR (stream.socket = NIL) THEN
    Log.Error(stream.logger, "SocketDStream.ReadUntil(): Invalid arguments.");
    done := TRUE
  END;

  (* Read data from a valid stream socket *)
  WHILE ~done DO
    (* Keep reading *)
    status := artSocket.Receive(stream.socket, buf, LEN(buf), received);
    IF (status = artSocket.Ok) & (received > 0) THEN
      Log.Debug(stream.logger, "Received data from socket, buffering");
      DStrings.WriteBytes(stream.inRider, buf, received);
    ELSE
      (* If wouldBlock is returned, there was no data to copy. *)
      (* Socket status (error, wouldBlock or EOF) will be returned. *)
      done := TRUE
    END;
    
    (* Either data from the recent read or we still have unprocessed data in the buffer. *)
    IF HasDelimiterInBuffer(stream, delimStr, pos) THEN
        Log.Debug(stream.logger, "Delimiter found.");
        ExtractUpToAndIncluding(stream, pos, LEN(delim), dstr);
        (* Clear the input buffer *)
        DStrings.Init("", stream.inBuf);
        DStrings.Set(stream.inRider, stream.inBuf, 0);
        found := TRUE;
        done := TRUE;
    ELSIF DStrings.Length(stream.inBuf) > 0 THEN
      (* No delimiter, append the buffered data to dstr, done remains unchanged. *)
      Log.Debug(stream.logger, "No delimiter found, appending data to dstr");
      DrainBuffer(stream, dstr);
    END
  END
  RETURN status
END ReadUntil;

END SocketDStream.
