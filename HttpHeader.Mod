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

(**
  Parses raw HTTP header text into the header structure. Returns TRUE on success.
  Handles line splitting, key/value separation, whitespace trimming, and case normalization.
*)
PROCEDURE Parse*(raw: ARRAY OF CHAR; VAR h: Header): BOOLEAN;
VAR
  result: BOOLEAN;
BEGIN
  result := FALSE;
  (* TODO: Implement header parsing *)
  RETURN result
END Parse;

(*
  Helper procedure to write a single header field as "Key: Value\r\n" for serialization.
  Uses the output rider from the visitor state.
*)
PROCEDURE WriteHeader(key: ARRAY OF CHAR; value: Collections.ItemPtr; VAR state: Collections.VisitorState): BOOLEAN;
VAR
  val: DStrings.String;
  ws: WriteHeaderState;
BEGIN
  ws := state(WriteHeaderState);
  IF value IS DStrings.String THEN
    val := value(DStrings.String);
    DStrings.WriteString(ws.rider, key);
    DStrings.WriteString(ws.rider, ": ");
    DStrings.WriteDString(ws.rider, val);
    DStrings.WriteChar(ws.rider, Chars.CR);
    DStrings.WriteChar(ws.rider, Chars.LF)
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

(**
  Sets or updates a header field (case-insensitive). Returns TRUE on success.
*)
PROCEDURE Set*(h: Header; key, value: ARRAY OF CHAR): BOOLEAN;
VAR
  result: BOOLEAN;
  normKey, val: DStrings.String;
  keyBuf: ARRAY MaxKeyLength OF CHAR;
  res: INTEGER;
BEGIN
  result := FALSE;
  IF h # NIL THEN
    DStrings.Init(key, normKey);
    DStrings.Cap(normKey); (* Normalize to uppercase for case-insensitive storage *)
    DStrings.ToChars(normKey, keyBuf, res);
    DStrings.Init(value, val);
    Dictionary.PutString(h.fields, keyBuf, val);
    result := TRUE
  END;
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

(**
  Iterates over all header fields, calling the provided visitor procedure.
*)
PROCEDURE Foreach*(h: Header; visit: Dictionary.StringKeyVisitProc; VAR state: Dictionary.DictVisitorState);
BEGIN
  Dictionary.ForeachString(h.fields, visit, state)
END Foreach;

END HttpHeader.
