(**
  HttpHeader - HTTP header parsing and manipulation module

  Copyright (C) 2025 Artemis Project Contributors

  Released under The 3-Clause BSD License.

  This module provides functionality to parse, store, manipulate, and serialize HTTP headers.
  It uses the DStrings module for string handling and the Dictionary module for key-value storage.
  Header field names are handled case-insensitively by normalizing to uppercase.
*)
MODULE HttpHeader;

IMPORT DStrings, Dictionary, Collections, Chars;

CONST
  MaxKeyLength = 256; (* Maximum length for header keys *)


TYPE
  Header* = POINTER TO HeaderDesc;
  HeaderDesc = RECORD
    fields: Dictionary.Dictionary
  END;
(*
  Helper state for header serialization, holding the output rider.
*)
  WriteHeaderState = RECORD (Dictionary.DictVisitorState)
    rider: DStrings.Rider
  END;

(**
  Initializes a new, empty HTTP header structure.
*)
PROCEDURE Init*(VAR h: Header);
BEGIN
  NEW(h);
  h.fields := Dictionary.NewStringDict()
END Init;

(*
  Helper procedure to write a single header field as "Key: Value\r\n" for serialization.
  Uses the output rider from the visitor state.
*)
PROCEDURE WriteHeader(key: ARRAY OF CHAR; value: Collections.ItemPtr; VAR state: Collections.VisitorState): BOOLEAN;
VAR
  val: DStrings.String;
BEGIN
  IF value IS DStrings.String THEN
    val := value(DStrings.String);
    DStrings.WriteString(state(WriteHeaderState).rider, key);
    DStrings.WriteString(state(WriteHeaderState).rider, ": ");
    DStrings.WriteDString(state(WriteHeaderState).rider, val);
    DStrings.WriteChar(state(WriteHeaderState).rider, Chars.CR);
    DStrings.WriteChar(state(WriteHeaderState).rider, Chars.LF)
  END;
  RETURN TRUE
END WriteHeader;

(***
  Serializes the header fields into a string suitable for sending over HTTP.
  Returns TRUE on success.
*)
PROCEDURE ToString*(h: Header; VAR out: DStrings.String): BOOLEAN;
VAR
  result: BOOLEAN;
  state: WriteHeaderState;
BEGIN
  result := FALSE;
  DStrings.Init("", out);
  DStrings.Set(state.rider, out, 0);
  Dictionary.ForeachString(h.fields, WriteHeader, state);
  result := TRUE;
  RETURN result
END ToString;

(**
  Retrieves the value for a given header key (case-insensitive). Returns TRUE if found.
*)
PROCEDURE Get*(h: Header; key: ARRAY OF CHAR; VAR value: DStrings.String): BOOLEAN;
VAR
  result: BOOLEAN;
  normKey: DStrings.String;
  keyBuf: ARRAY MaxKeyLength OF CHAR;
  item: Collections.ItemPtr;
  found: BOOLEAN;
  res: INTEGER;
BEGIN
  result := FALSE;
  IF h # NIL THEN
    DStrings.Init(key, normKey);
    DStrings.Init("", value);
    DStrings.Cap(normKey); (* Normalize to uppercase for case-insensitive lookup *)
    DStrings.ToChars(normKey, keyBuf, res);
    found := Dictionary.GetString(h.fields, keyBuf, item);
    IF found & (item IS DStrings.String) THEN
      DStrings.Copy(item(DStrings.String), value);
      result := TRUE
    END
  END;
  RETURN result
END Get;

(*
  Internal: Sets or updates a header field using DStrings.String parameters (case-insensitive). Returns TRUE on success.
*)
PROCEDURE SetDString(h: Header; key, value: DStrings.String): BOOLEAN;
VAR
  result: BOOLEAN;
  normKey: DStrings.String;
  keyBuf: ARRAY MaxKeyLength OF CHAR;
  res: INTEGER;
  valueCopy: DStrings.String;
BEGIN
  result := FALSE;
  IF h # NIL THEN
    DStrings.Copy(key, normKey);
    DStrings.Cap(normKey); (* Normalize to uppercase for case-insensitive storage *)
    DStrings.ToChars(normKey, keyBuf, res);
    DStrings.Copy(value, valueCopy); (* Always store a new copy to avoid shared buffer issues *)
    Dictionary.PutString(h.fields, keyBuf, valueCopy);
    result := TRUE
  END;
  RETURN result
END SetDString;

(**
  Sets or updates a header field (case-insensitive). Returns TRUE on success.
*)
PROCEDURE Set*(h: Header; key, value: ARRAY OF CHAR): BOOLEAN;
VAR
  keyStr, valStr: DStrings.String;
  result: BOOLEAN;
BEGIN
  DStrings.Init(key, keyStr);
  DStrings.Init(value, valStr);
  result := SetDString(h, keyStr, valStr);
  RETURN result
END Set;

(**
  Removes a header field (case-insensitive). Returns TRUE if removed.
*)
PROCEDURE Remove*(h: Header; key: ARRAY OF CHAR): BOOLEAN;
VAR
  result: BOOLEAN;
  normKey: DStrings.String;
  keyBuf: ARRAY MaxKeyLength OF CHAR;
  res: INTEGER;
  removed: BOOLEAN;
BEGIN
  result := FALSE;
  IF h # NIL THEN
    DStrings.Init(key, normKey);
    DStrings.Cap(normKey); (* Normalize to uppercase for case-insensitive removal *)
    DStrings.ToChars(normKey, keyBuf, res);
    removed := Dictionary.RemoveString(h.fields, keyBuf);
    IF removed THEN
      result := TRUE
    END
  END;
  RETURN result
END Remove;

(* Internal: Reads a line from the reader into a DStrings.String, sets lineLen. Handles CR/LF. *)
PROCEDURE ReadLineString(VAR reader: DStrings.Rider; VAR line: DStrings.String; VAR lineLen: INTEGER);
VAR c: CHAR; outRider: DStrings.Rider; done: BOOLEAN;
BEGIN
  DStrings.Clear(line);
  DStrings.Set(outRider, line, 0);
  done := FALSE;
  c := DStrings.Get(reader);
  WHILE (c # 0X) & (c # Chars.LF) & ~done DO
    IF c # Chars.CR THEN
      DStrings.Put(outRider, c);
      c := DStrings.Get(reader)
    ELSE
      (* If CR, check for CRLF and stop, else skip CR *)
      c := DStrings.Get(reader);
      IF (c = 0X) OR (c = Chars.LF) THEN
        done := TRUE
      END
    END
  END;
  lineLen := DStrings.Length(line)
END ReadLineString;

(* Internal: Splits a DStrings.String line at first colon, trims key and value, sets valid. *)
PROCEDURE SplitHeaderLineString(line: DStrings.String; VAR key, value: DStrings.String; VAR valid: BOOLEAN);
VAR colonPos, len: INTEGER; colon: DStrings.String;
BEGIN
  valid := FALSE;
  len := DStrings.Length(line);
  DStrings.Init("", key); DStrings.Init("", value); DStrings.Init(":", colon);
  colonPos := DStrings.Pos(colon, line, 0);
  IF (colonPos > 0) & (colonPos < len) THEN
    DStrings.Extract(line, 0, colonPos, key);
    DStrings.Extract(line, colonPos+1, len-colonPos-1, value);
    DStrings.TrimSpace(key);
    DStrings.TrimSpace(value);
    valid := TRUE
  END
END SplitHeaderLineString;

(**
  Parses raw HTTP header text into the header structure. Returns TRUE on success.
  Handles line splitting, key/value separation, whitespace trimming, and case normalization.
*)
PROCEDURE Parse*(raw: ARRAY OF CHAR; VAR h: Header): BOOLEAN;
VAR
  result: BOOLEAN;
  input: DStrings.String;
  reader: DStrings.Rider;
  line, key, value: DStrings.String;
  lineLen: INTEGER;
  valid, success: BOOLEAN;
  keyBuf, valueBuf: DStrings.String;
BEGIN
  result := FALSE;
  IF h # NIL THEN
    DStrings.Init(raw, input);
    DStrings.Set(reader, input, 0);
    DStrings.Init("", line); DStrings.Init("", key); DStrings.Init("", value);
    success := TRUE;
    WHILE (DStrings.Peek(reader) # 0X) & success DO
      ReadLineString(reader, line, lineLen);
      IF lineLen > 0 THEN
        SplitHeaderLineString(line, key, value, valid);
        IF valid THEN
          DStrings.Clear(keyBuf); DStrings.Clear(valueBuf);
          DStrings.Copy(key, keyBuf);
          DStrings.Copy(value, valueBuf);
          (* Normalize key to uppercase for case-insensitive storage *)
          success := SetDString(h, keyBuf, valueBuf)
        END
      END
    END;
    IF success THEN
      result := TRUE
    END
  END;
  RETURN result
END Parse;

(**
  Iterates over all header fields, calling the provided visitor procedure.
*)
PROCEDURE Foreach*(h: Header; visit: Dictionary.StringKeyVisitProc; VAR state: Dictionary.DictVisitorState);
BEGIN
  Dictionary.ForeachString(h.fields, visit, state)
END Foreach;

END HttpHeader.
