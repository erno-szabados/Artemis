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
  buf: ARRAY MaxBufferSize OF CHAR;
  msgLen, truncated, sent, result : INTEGER;
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
        DStrings.ToChars(stream.outBuf, buf, truncated);
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

(* Reads data from the socket into the internal buffer.
   Not exported: used by higher-level helpers.
   Returns the status of the operation (Ok, WouldBlock, etc).
*)
PROCEDURE ReadDString(stream: SocketDStream; VAR bytesRead: INTEGER): INTEGER;
VAR
  buf: ARRAY MaxBufferSize OF CHAR;
  received, result: INTEGER;
BEGIN
  bytesRead := 0;
  result := artSocket.Ok;
  IF (stream # NIL) & (stream.socket # NIL) THEN
    result := artSocket.Receive(stream.socket, buf, LEN(buf), received);
    IF (result = artSocket.Ok) OR (result = artSocket.WouldBlock) THEN
      IF received > 0 THEN
        DStrings.WriteString(stream.inRider, buf);
        bytesRead := received;
      END
    END
  ELSE
    result := artSocket.NotConnected
  END;
  RETURN result
END ReadDString;

(** 
  Reads from the socket until the delimiter pattern (array of CHAR) is found or no more data is available.
  The delimiter is included in the result if found.
  found = TRUE if the delimiter was found, FALSE otherwise.
  Returns the status of the operation (Ok, WouldBlock, etc).
*)
(* Helper: check if delimiter is present in buffer, return position or -1 *)
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

(* Helper: extract and delete up to and including delimiter *)
PROCEDURE ExtractUpToAndIncluding(stream: SocketDStream; pos, delimLen: INTEGER; VAR dstr: DStrings.String);
VAR extractLen: INTEGER;
BEGIN
  extractLen := pos + delimLen;
  DStrings.Extract(stream.inBuf, 0, extractLen, dstr);
  DStrings.Delete(stream.inBuf, 0, extractLen);
  DStrings.Set(stream.inRider, stream.inBuf, 0)
END ExtractUpToAndIncluding;

(* Helper: drain buffer to dstr and clear *)
PROCEDURE DrainBuffer(stream: SocketDStream; VAR dstr: DStrings.String);
BEGIN
  DStrings.Copy(stream.inBuf, dstr);
  DStrings.Init("", stream.inBuf);
  DStrings.Set(stream.inRider, stream.inBuf, 0)
END DrainBuffer;

(** Read from the stream socket until the delimiter is found or an error occurs. *)
PROCEDURE ReadUntil*(stream: SocketDStream; delim: ARRAY OF CHAR; VAR dstr: DStrings.String; VAR found: BOOLEAN): INTEGER;
VAR
  status: INTEGER;
  bytesRead, len, pos: INTEGER;
  delimStr: DStrings.String;
  done: BOOLEAN;
BEGIN
  found := FALSE;
  DStrings.Init("", dstr);
  status := artSocket.Ok;
  DStrings.Init(delim, delimStr);
  done := FALSE;
  IF stream = NIL THEN
    status := artSocket.NotConnected;
    found := FALSE;
    DStrings.Init("", dstr);
    done := TRUE
  END;
  IF ~done THEN
    WHILE ~done DO
      len := DStrings.Length(stream.inBuf);
      IF HasDelimiterInBuffer(stream, delimStr, pos) THEN
        ExtractUpToAndIncluding(stream, pos, LEN(delim), dstr);
        found := TRUE;
        status := artSocket.Ok;
        done := TRUE
      ELSE
        status := ReadDString(stream, bytesRead);
        IF (status # artSocket.Ok) & (status # artSocket.WouldBlock) THEN
          done := TRUE
        ELSIF bytesRead = 0 THEN
          IF len > 0 THEN
            DrainBuffer(stream, dstr)
          END;
          done := TRUE
        END
      END
    END
  END;
  RETURN status
END ReadUntil;

(** 
  Reads exactly n bytes from the socket (or as many as are available).
  bytesRead = number of bytes actually read.
  Returns the status of the operation (Ok, WouldBlock, etc).
*)
(* Helper: extract and delete up to n bytes from buffer *)
PROCEDURE ExtractNBytes(stream: SocketDStream; n: INTEGER; VAR dstr: DStrings.String);
BEGIN
  DStrings.Extract(stream.inBuf, 0, n, dstr);
  DStrings.Delete(stream.inBuf, 0, n);
  DStrings.Set(stream.inRider, stream.inBuf, 0)
END ExtractNBytes;

PROCEDURE ReadNBytes*(stream: SocketDStream; n: INTEGER; VAR dstr: DStrings.String; VAR bytesRead: INTEGER): INTEGER;
VAR
  status: INTEGER;
  len, toCopy: INTEGER;
  done: BOOLEAN;
BEGIN
  bytesRead := 0;
  DStrings.Init("", dstr);
  status := artSocket.Ok;
  done := FALSE;
  IF stream = NIL THEN
    DStrings.Init("", dstr);
    bytesRead := 0;
    status := artSocket.NotConnected;
    done := TRUE
  END;
  IF ~done THEN
    WHILE ~done DO
      len := DStrings.Length(stream.inBuf);
      IF len >= n THEN
        ExtractNBytes(stream, n, dstr);
        bytesRead := n;
        status := artSocket.Ok;
        done := TRUE
      ELSE
        IF len > 0 THEN
          DrainBuffer(stream, dstr);
          bytesRead := len;
        END;
        status := ReadDString(stream, toCopy);
        IF (status # artSocket.Ok) & (status # artSocket.WouldBlock) THEN
          done := TRUE
        ELSIF toCopy = 0 THEN
          done := TRUE
        END
      END
    END
  END;
  RETURN status
END ReadNBytes;

END SocketDStream.
