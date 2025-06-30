(** SocketDStream.Mod - Buffered, sequential socket I/O using DStrings and Riders

  Copyright (C) 2025 Artemis Project Contributors
  Released under The 3-Clause BSD License.

  This module provides a DString-based, rider-friendly abstraction for nonblocking socket I/O.
  It is not a Java-style stream, but an idiomatic Oberon-07 approach for sequential socket data.
  
  Usage:
    IMPORT SocketDStream;
    SocketDStream.WriteDString(...);

    (* Or, for brevity: *)
    IMPORT SocketDStream AS SDStream;
    SDStream.WriteDString(...);

  The API is designed for use with DStrings and Riders, and manages partial
  sends/receives and nonblocking socket state internally.
*)
MODULE SocketDStream;

IMPORT artSocket, DStrings;

TYPE
  SocketDStream* = POINTER TO SocketDStreamDesc;
  SocketDStreamDesc* = RECORD
    socket: artSocket.Socket;
    inBuf, outBuf: DStrings.String;
    inRider, outRider: DStrings.Rider
    (* Additional state for partial I/O, etc. *)
  END;

(** Initializes a new SocketDStream for the given socket. *)
PROCEDURE Init*(socket: artSocket.Socket; VAR stream: SocketDStream);
BEGIN
  IF stream = NIL THEN
    NEW(stream);
  END;
  stream.socket := socket;
  DStrings.Init("", stream.inBuf);
  DStrings.Init("", stream.outBuf);
  DStrings.Set(stream.inRider, stream.inBuf, 0);
  DStrings.Set(stream.outRider, stream.outBuf, 0)
END Init;

(** Write data from outBuf using outRider to the socket. bytesLeft -> remaining unsent data. Returns the status of the operation (Ok, WouldBlock, etc). *)
PROCEDURE WriteDString*(stream: SocketDStream; VAR bytesLeft: INTEGER): INTEGER;
VAR
  buf: ARRAY 1024 OF CHAR;
  outLen, toSend, sent, status, result: INTEGER;
BEGIN
  bytesLeft := 0;
  result := artSocket.Ok;
  IF (stream # NIL) & (stream.socket # NIL) THEN
    outLen := DStrings.Length(stream.outBuf);
    IF outLen > 0 THEN
      (* Copy from outBuf (using outRider) to buf for sending *)
      DStrings.ToChars(stream.outBuf, buf, toSend);
      status := artSocket.Send(stream.socket, buf, toSend, sent);
      IF (status = artSocket.Ok) OR (status = artSocket.WouldBlock) THEN
        IF sent > 0 THEN
          (* Advance outRider and remove sent data from outBuf *)
          DStrings.Delete(stream.outBuf, 0, sent);
          DStrings.Set(stream.outRider, stream.outBuf, 0);
        END;
        bytesLeft := DStrings.Length(stream.outBuf);
        result := status
      ELSE
        result := status
      END
    ELSE
      bytesLeft := 0;
      result := artSocket.Ok
    END
  ELSE
    result := artSocket.NotConnected
  END;
  RETURN result
END WriteDString;

(** Read data from the socket into inBuf using inRider. bytesLeft -> remaining unread data. Returns the status of the operation (Ok, WouldBlock, etc). *)
PROCEDURE ReadDString*(stream: SocketDStream; VAR bytesLeft: INTEGER): INTEGER;
VAR
  buf: ARRAY 1024 OF CHAR;
  received, status, inLen, result: INTEGER;
BEGIN
  bytesLeft := 0;
  result := artSocket.Ok;
  IF (stream # NIL) & (stream.socket # NIL) THEN
    status := artSocket.Receive(stream.socket, buf, LEN(buf), received);
    IF (status = artSocket.Ok) OR (status = artSocket.WouldBlock) THEN
      IF received > 0 THEN
        (* Write received data into inBuf using inRider *)
        DStrings.WriteString(stream.inRider, buf);
      END;
      inLen := DStrings.Length(stream.inBuf);
      bytesLeft := inLen;
      result := status
    ELSE
      result := status
    END
  ELSE
    result := artSocket.NotConnected
  END;
  RETURN result
END ReadDString;

END SocketDStream.
