(** SocketDStream.Mod 

  Copyright (C) 2025 Artemis Project Contributors
  Released under The 3-Clause BSD License.

  Buffered, sequential socket I/O using DStrings and Riders 
  on top of the nonblocking artSocket implementation.

  The API manages partial sends/receives and nonblocking socket state internally.

  Usage:
    IMPORT DStrings, SDStream := SocketDStream;

    (* Declare and initialize the DStrings.String data *)
    VAR 
      data : DStrings.String;
      mySocket : artSocket.Socket;
    
    BEGIN
      mySocket := artSocket.NewSocket();
      (* ... Socket setup ... *)
      DStrings.Init("Hello, world!", data);
      SDStream.Init(mySocket, myStream);
      SDStream.WriteDString(myStream, data);
      (* ... rest of the code ... *)
*)
MODULE SocketDStream;

IMPORT artSocket, DStrings, Log;

CONST 
  (* Maximum buffer size for sending/receiving data *)
  MaxBufferSize* = 1024;

TYPE
  SocketDStream* = POINTER TO SocketDStreamDesc;
  SocketDStreamDesc* = RECORD
    socket: artSocket.Socket;
    logger: Log.Logger;
    (** Input/output buffers *)
    inBuf*, outBuf*: DStrings.String;
    (** Riders to show where are we at the buffers. *)
    inRider*, outRider*: DStrings.Rider
  END;

(** 
  Initializes a new SocketDStream using the given socket.
  Initialize and reset the buffers and the associated riders.

  @param socket - an initialized artSocket.
  @param stream - the socket stream to initialize.
 *)
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
  Log.Debug(stream.logger, "SocketDstream initialized");
END Init;

(** 
  Sends the given DString over the nonblocking socket. Handles buffering and partial sends. 

  You should call SendDString repeatedly as long as it returns WouldBlock or Ok, until all data is sent,
  because we consume data from the stream buffer with each call. 

  @param sstr - source DString to send. If the stream buffer is empty, we fill it with the new data from sstr.
  @param bytesLeft - remaining unsent data. bytesLeft is always calculated from the current length of 
         the stream buffer after each send, because the buffer is dynamic and can be modified 
         (e.g., partial sends, deletions, appends). 

  @return the status of the operation (Ok, WouldBlock, etc).
 *)
PROCEDURE SendDString*(stream: SocketDStream; sstr: DStrings.String; VAR bytesLeft: INTEGER): INTEGER;
VAR
  msgLen, sent, result : INTEGER;
  done: BOOLEAN;

  (* 
    Fill the stream output buffer with data from sstr, and reset the rider to the beginning of the buffer.
    
    @param sstr - data to fill the buffer.
    @param stream - stream with the buffer. 
   *)
  PROCEDURE FillBuffer(sstr : DStrings.String; VAR stream: SocketDStream);
  BEGIN
    Log.Debug(stream.logger, "Copying data to stream buffer");
    DStrings.Copy(sstr, stream.outBuf);
    DStrings.Set(stream.outRider, stream.outBuf, 0);
  END FillBuffer;

  (* 
    Transmit the buffer contents over the stream socket. May perform a partial transfer if it would block.
     
    @param stream - stream descriptor
    @param msgLen - length of data in buffer
    @parma sent - number of bytes transmitted

    @return the socket send status result. *)
  PROCEDURE Transmit(stream : SocketDStream; msgLen : INTEGER; VAR sent: INTEGER) : INTEGER;
  VAR  
    buf: ARRAY MaxBufferSize OF BYTE;
  BEGIN
    Log.Debug(stream.logger, "Transmit data over socket");
    DStrings.ReadBytes(stream.outRider, buf, msgLen);
    RETURN artSocket.Send(stream.socket, buf, msgLen, sent)
  END Transmit;

  (* 
    Consume the sent data and update the rider to the start of the remaining data.

    @param stream - stream descriptor.
    @param sent - number of bytes to remove.
    *)
  PROCEDURE DrainBuffer(VAR stream : SocketDStream; sent : INTEGER);
  BEGIN
    Log.Debug(stream.logger, "Draining sent data from stream buffer");
    DStrings.Delete(stream.outBuf, 0, sent);
    DStrings.Set(stream.outRider, stream.outBuf, 0);
  END DrainBuffer;

BEGIN
  (* Initialize *)
  done := FALSE;
  result := artSocket.UnknownError;
  bytesLeft := 0;

  (* Validate arguments *)
  IF (stream = NIL) OR (stream.socket = NIL) OR (sstr = NIL) THEN
    done := TRUE
  END;

  IF ~done THEN
    (* If there is no pending data, copy new data into outBuf *)
    IF DStrings.Length(stream.outBuf) = 0 THEN
      FillBuffer(sstr, stream)
    END;

    msgLen := DStrings.Length(stream.outBuf);
    IF msgLen > 0 THEN
      result := Transmit(stream, msgLen, sent);
      
      (* If the send was successful or would block, we update the rider and buffer *)
      IF (result = artSocket.Ok) OR (result = artSocket.WouldBlock) THEN
        IF sent > 0 THEN
          DrainBuffer(stream, sent)
        END;
        bytesLeft := DStrings.Length(stream.outBuf);
      END
    ELSE
      (* No data left to send. *)
      bytesLeft := 0;
      result := artSocket.Ok
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

  TODO - add a maxBytes argument to limit the read. -1 no limit, else don't read more than  maxBytes.

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
    Check if delimiter is present in the stream buffer and return the length of content to be extracted (if found).

    @param stream - stream descriptor containing the stream buffer.
    @param delimStr - the delimiter we look for.
    @param pos position of first delimiter character in stream buffer or the length of the stream buffer if not found.

    @return TRUE if delimiter found in stream buffer, FALSE otherwise.
  *)
  PROCEDURE FindDelimitedSubString(stream: SocketDStream; delimStr: DStrings.String; VAR pos: INTEGER): BOOLEAN;
  VAR
    found: BOOLEAN;
    bufLen, delimLen: INTEGER;
  BEGIN
    pos := -1;
    bufLen := DStrings.Length(stream.inBuf);
    delimLen := DStrings.Length(delimStr);
    
    IF (delimLen > 0) & (bufLen > 0) THEN
      pos := DStrings.Pos(delimStr, stream.inBuf, 0);
    END;

    found := (pos # -1);
    IF found THEN
      pos := pos + delimLen
    ELSE
      (* We can use extract if we set to length of pos *)
      pos := bufLen
    END;
    RETURN found
  END FindDelimitedSubString;

  (* 
    Copy and delete data up to and including delimiter from the stream buffer into dstr.
    Reset the stream inbuf rider after the data is extracted to the start of the data left in the buffer.

    @param stream - stream descriptor containing the input rider and buffer.
    @param extractLen - position of delimiter in the stream buffer.
    @param dstr - received data including the delimiter.
  *)
  PROCEDURE DrainBuffer(stream: SocketDStream; extractLen: INTEGER; VAR dstr: DStrings.String);
  BEGIN
    DStrings.Extract(stream.inBuf, 0, extractLen, dstr);
    DStrings.Delete(stream.inBuf, 0, extractLen);
    (* Position the rider to the remaining data for the next read. *)
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
    done := TRUE
  END;

  (* Read data from a valid stream socket *)
  WHILE ~done DO
    (* Keep reading *)
    status := artSocket.Receive(stream.socket, buf, LEN(buf), received);
    IF (status = artSocket.Ok) THEN
      IF (received = 0) THEN
        Log.Debug(stream.logger, "Client closed the socket.");
        status := artSocket.Closed;
        done := TRUE
      ELSIF (received > 0) THEN 
        Log.Debug(stream.logger, "Received data from socket, buffering");
        DStrings.WriteBytes(stream.inRider, buf, received)
      END
    ELSE
      (* If wouldBlock is returned, there was no data to copy. *)
      (* Socket status (error, wouldBlock or EOF) will be returned. *)
      done := TRUE
    END;
    
    (* Either data from the recent read or we still have unprocessed data in the buffer. *)
    IF FindDelimitedSubString(stream, delimStr, pos) THEN
        Log.Debug(stream.logger, "Delimiter found");
        DrainBuffer(stream, pos, dstr);
        (* Clear the input buffer *)
        DStrings.Init("", stream.inBuf);
        DStrings.Set(stream.inRider, stream.inBuf, 0);
        found := TRUE;
        done := TRUE;
    ELSIF DStrings.Length(stream.inBuf) > 0 THEN
      (* No delimiter, append the buffered data to dstr, done remains unchanged. *)
      Log.Debug(stream.logger, "No delimiter found, appending data to dstr");
      DrainBuffer(stream, pos, dstr);
    END
  END
  RETURN status
END ReadUntil;

END SocketDStream.
