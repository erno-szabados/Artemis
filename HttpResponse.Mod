(** HttpResponse.Mod - HTTP response parsing and representation module

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)

MODULE HttpResponse;

IMPORT DStrings, HttpHeader, Chars, extConvert, Out;

CONST
  Ok* = 0;
  ParseError* = 1;
  Incomplete* = 2;
  Unsupported* = 3;

TYPE
  HttpResponse* = POINTER TO HttpResponseDesc;
  HttpResponseDesc* = RECORD
    version*: DStrings.String;      (* e.g., "HTTP/1.1" *)
    statusCode*: INTEGER;           (* e.g., 200 *)
    reason*: DStrings.String;       (* e.g., "OK" *)
    headers*: HttpHeader.Header;    (* parsed headers *)
    body*: DStrings.String;         (* response body *)
    error*: INTEGER                 (* 0 = OK, nonzero = parse error *)
  END;

(* Internal: Reads a line from the rider into 'line', handling CR, LF, or CRLF. Returns TRUE if a line was read. *)
PROCEDURE ReadLine(VAR reader: DStrings.Rider; VAR line: DStrings.String; VAR result: BOOLEAN);
VAR ch: CHAR; outRider: DStrings.Rider;
BEGIN
  DStrings.Init("", line);
  DStrings.Set(outRider, line, 0);
  result := FALSE;
  WHILE ~reader.eot & ~result DO
    ch := DStrings.Get(reader);
    IF (ch = Chars.CR) OR (ch = Chars.LF) THEN
      IF (ch = Chars.CR) & ~reader.eot & (DStrings.Peek(reader) = Chars.LF) THEN
        ch := DStrings.Get(reader) (* consume LF after CR *)
      END;
      result := TRUE
    ELSE
      DStrings.WriteChar(outRider, ch)
    END
  END;
  IF DStrings.Length(line) > 0 THEN result := TRUE END
END ReadLine;

(* Internal: Splits a status line into version, status, reason. Returns TRUE on success. *)
PROCEDURE SplitStatusLine(line: DStrings.String; VAR version, status, reason: DStrings.String; VAR result: BOOLEAN);
VAR len, spacePos1, spacePos2: INTEGER;
    statusStr, s: DStrings.String;
BEGIN
  result := FALSE;
  DStrings.Init("", version); DStrings.Init("", status); DStrings.Init("", reason); DStrings.Init("", statusStr);
  len := DStrings.Length(line);
  DStrings.Init(" ", s); (* Temporary string for status extraction *)
  spacePos1 := DStrings.Pos(s, line, 0);
  IF (spacePos1 >= 0) & (spacePos1 < len-1) THEN
    spacePos2 := DStrings.Pos(s, line, spacePos1+1);
    IF (spacePos2 < 0) OR (spacePos2 >= len) THEN spacePos2 := len END;
    DStrings.Extract(line, 0, spacePos1, version);
    DStrings.Extract(line, spacePos1+1, spacePos2-spacePos1-1, statusStr);
    IF spacePos2 < len THEN
      DStrings.Extract(line, spacePos2+1, len-spacePos2-1, reason)
    ELSE
      DStrings.Init("", reason)
    END;
    DStrings.Copy(statusStr, status);
    result := TRUE
  END
END SplitStatusLine;

(* Internal: Converts a status string to integer. Returns TRUE if valid. *)
PROCEDURE ParseStatusCode(status: DStrings.String; VAR code: INTEGER; VAR result: BOOLEAN);
VAR buf: ARRAY 16 OF CHAR; done: BOOLEAN; res: INTEGER;
BEGIN
  code := 0;
  result := FALSE;
  DStrings.ToChars(status, buf, res);
  extConvert.StringToInt(buf, code, done);
  IF done THEN result := TRUE END
END ParseStatusCode;

(* Internal: Reads the status line from the response, splits into version, status, reason. Returns TRUE on success. *)
PROCEDURE ReadStatusLine(VAR reader: DStrings.Rider; VAR version, status, reason: DStrings.String; VAR code: INTEGER; VAR result: BOOLEAN);
VAR
  line: DStrings.String;
  lineOk, splitOk, codeOk: BOOLEAN;
  statusStr: DStrings.String;
BEGIN
  DStrings.Init("", line); DStrings.Init("", statusStr);
  lineOk := FALSE; splitOk := FALSE; codeOk := FALSE;
  ReadLine(reader, line, lineOk);
  IF lineOk THEN
    SplitStatusLine(line, version, status, reason, splitOk);
    IF splitOk THEN
      ParseStatusCode(status, code, codeOk)
    END
  END;
  result := lineOk & splitOk & codeOk
END ReadStatusLine;

(* Internal: Reads header lines from the reader into headerBlock until an empty line. *)
PROCEDURE ReadHeaderBlock(VAR reader: DStrings.Rider; VAR headerBlock: DStrings.String);
VAR
  headerLine: DStrings.String;
  headerLinesOk, inHeaders: BOOLEAN;
  headerBlockRider: DStrings.Rider;
BEGIN
  DStrings.Init("", headerBlock);
  DStrings.Set(headerBlockRider, headerBlock, 0);
  inHeaders := TRUE;
  WHILE inHeaders DO
    DStrings.Init("", headerLine);
    ReadLine(reader, headerLine, headerLinesOk);
    IF ~headerLinesOk THEN
      inHeaders := FALSE
    ELSIF DStrings.Length(headerLine) = 0 THEN
      inHeaders := FALSE
    ELSE
      DStrings.WriteDString(headerBlockRider, headerLine);
      DStrings.WriteChar(headerBlockRider, Chars.CR);
      DStrings.WriteChar(headerBlockRider, Chars.LF)
    END
  END
END ReadHeaderBlock;

(** Parses a raw HTTP response (ARRAY OF CHAR) into a HttpResponse. Returns TRUE on success. *)
PROCEDURE Parse*(raw: ARRAY OF CHAR; VAR resp: HttpResponse): BOOLEAN;
VAR
  ok, statusOk, headerParseOk: BOOLEAN;
  input, versionStr, statusStr, reasonStr, headerBlock: DStrings.String;
  reader: DStrings.Rider;
  code: INTEGER;
  buf: ARRAY 256 OF CHAR;
  res: INTEGER;
BEGIN
  ok := FALSE;
  IF resp # NIL THEN
    DStrings.Init(raw, input);
    DStrings.Set(reader, input, 0);
    DStrings.Init("", versionStr); DStrings.Init("", statusStr); DStrings.Init("", reasonStr);
    code := 0;
    ReadStatusLine(reader, versionStr, statusStr, reasonStr, code, statusOk);
    IF statusOk THEN
      DStrings.Copy(versionStr, resp.version);
      resp.statusCode := code;
      DStrings.Copy(reasonStr, resp.reason);
      ReadHeaderBlock(reader, headerBlock);
      DStrings.ToChars(headerBlock, buf, res);
      Out.String("[DEBUG] Header block: "); Out.String(buf); Out.Ln();
      IF DStrings.Length(headerBlock) = 0 THEN
        resp.headers := NIL;
        headerParseOk := TRUE
      ELSE
        HttpHeader.Init(resp.headers);
        headerParseOk := HttpHeader.ParseDString(headerBlock, resp.headers)
      END;
      IF headerParseOk THEN
        resp.error := Ok;
        ok := TRUE;
        (* Extract body: read the rest of the input after headers *)
        DStrings.Init("", resp.body);
        DStrings.ReadDString(reader, resp.body);
      ELSE
        resp.error := ParseError;
        ok := FALSE
      END;
      DStrings.Init("", resp.body)
    ELSE
      resp.error := ParseError;
      ok := FALSE
    END
  ELSE
    ok := FALSE
  END;
  RETURN ok
END Parse;



(** Returns the status code. *)
PROCEDURE GetStatus*(resp: HttpResponse): INTEGER;
VAR result: INTEGER;
BEGIN
  IF resp # NIL THEN
    result := resp.statusCode
  ELSE
    result := 0
  END;
  RETURN result
END GetStatus;

(** Gets the reason phrase. *)
PROCEDURE GetReason*(resp: HttpResponse; VAR reason: DStrings.String);
BEGIN
  IF resp # NIL THEN
    DStrings.Copy(resp.reason, reason)
  ELSE
    DStrings.Init("", reason)
  END
END GetReason;

(** Gets the HTTP version. *)
PROCEDURE GetVersion*(resp: HttpResponse; VAR version: DStrings.String);
BEGIN
  IF resp # NIL THEN
    DStrings.Copy(resp.version, version)
  ELSE
    DStrings.Init("", version)
  END
END GetVersion;

(** Gets the value of a header field (case-insensitive). Returns TRUE if found. *)
PROCEDURE GetHeader*(resp: HttpResponse; key: ARRAY OF CHAR; VAR value: DStrings.String): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  IF resp # NIL THEN
    result := HttpHeader.Get(resp.headers, key, value)
  ELSE
    DStrings.Init("", value);
    result := FALSE
  END;
  RETURN result
END GetHeader;

(** Gets the response body. *)
PROCEDURE GetBody*(resp: HttpResponse; VAR body: DStrings.String);
BEGIN
  IF resp # NIL THEN
    DStrings.Copy(resp.body, body)
  ELSE
    DStrings.Init("", body)
  END
END GetBody;

(** Returns TRUE if the response was parsed without error. *)
PROCEDURE IsOk*(resp: HttpResponse): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  IF resp # NIL THEN
    result := resp.error = Ok
  ELSE
    result := FALSE
  END;
  RETURN result
END IsOk;

(* Initializes a HttpResponse descriptor to safe defaults. *)
PROCEDURE Init*(VAR resp: HttpResponse);
BEGIN
  IF resp = NIL THEN
    NEW(resp)
  END;
  DStrings.Init("", resp.version);
  resp.statusCode := 0;
  DStrings.Init("", resp.reason);
  resp.headers := NIL;
  DStrings.Init("", resp.body);
  resp.error := ParseError
END Init;

END HttpResponse.
