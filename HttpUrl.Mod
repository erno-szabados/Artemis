(** 
  HttpUrl - URL parsing and manipulation module 

  Copyright (C) 2025 Artemis Project Contributors

  Released under The 3-Clause BSD License.

  This module provides functionality to parse URLs, serialize them back to strings,
  and manipulate query parameters. It uses the DStrings module for string handling
  and the HttpUrlTokenizer for tokenizing URL components. 
  
  Limitations:
  - Does not support percent-encoding (e.g., "%20" for spaces).
  - Does not handle Unicode characters in URLs.
  *)
MODULE HttpUrl;

IMPORT DStrings, HttpUrlTokenizer, extConvert;

TYPE
 (* URL descriptor, with scheme, host, port, path, query and frag. *)
  Url* = POINTER TO UrlDesc;
  UrlDesc* = RECORD
    scheme*: DStrings.String;      (* “http”, “https” *)
    host*:   DStrings.String;      (* domain or IP *)
    port*:   INTEGER;              (* 0 = default port *)
    path*:   DStrings.String;     (* “/foo/bar” *)
    query*:  DStrings.String;     (* “a=1&b=2” *)
    frag*:   DStrings.String     (* “section1” *)
  END;

(* Internal: Dump token information *)
(* PROCEDURE DumpToken(token: HttpUrlTokenizer.Token);
VAR 
  buf : ARRAY 256 OF CHAR;
  truncated: INTEGER;
BEGIN
  Out.String("Token type: ");
  Out.Int(token.type, 0);
  Out.String(" value: [");
  DStrings.ToChars(token.value, buf, truncated);
  Out.String(buf);
  Out.String("]");
  Out.Ln();
END DumpToken; *)

(* Internal: Convert DStrings.String to integer using extConvert. *)
PROCEDURE StringToInt(s: DStrings.String): INTEGER;
VAR i, res, result: INTEGER; chars: ARRAY 32 OF CHAR; done: BOOLEAN;
BEGIN
  DStrings.ToChars(s, chars, res);
  extConvert.StringToInt(chars, i, done);
  IF done THEN
    result := i
  ELSE
    result := 0
  END;
  RETURN result
END StringToInt;

(* Parses a DStrings.String to a Url descriptor. Returns TRUE on success. *)
PROCEDURE ParseDString*(input: DStrings.String; VAR u: Url): BOOLEAN;
VAR
    result: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
    newUrl: Url;
    queryParts: DStrings.String;
    pathParts: DStrings.String;
    expectingValue: BOOLEAN;
    lastKey: DStrings.String;
BEGIN
    result := FALSE;
    NEW(newUrl);
    DStrings.Init("", newUrl.scheme);
    DStrings.Init("", newUrl.host);
    newUrl.port := 0;
    DStrings.Init("", newUrl.path);
    DStrings.Init("", newUrl.query);
    DStrings.Init("", newUrl.frag);
    HttpUrlTokenizer.Init(tokenizer, input);
    expectingValue := FALSE;
    DStrings.Init("", lastKey);
    WHILE ~HttpUrlTokenizer.AtEof(tokenizer) DO
        HttpUrlTokenizer.NextToken(tokenizer, token);
        IF token.type = HttpUrlTokenizer.ErrorToken THEN
            result := FALSE
        ELSIF token.type = HttpUrlTokenizer.EofToken THEN
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.SchemeToken THEN
            DStrings.Copy(token.value, newUrl.scheme);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.SlashSlashToken THEN
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.HostToken THEN
            DStrings.Copy(token.value, newUrl.host);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.PortToken THEN
            newUrl.port := StringToInt(token.value);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.PathToken THEN
            DStrings.Copy(token.value, newUrl.path);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QueryStartToken THEN
            DStrings.Init("", queryParts);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QueryKeyToken THEN
            DStrings.Append(token.value, queryParts);
            DStrings.Copy(token.value, lastKey);
            expectingValue := TRUE;
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QueryEqualsToken THEN
            DStrings.CopyChars("=", pathParts);
            DStrings.Append(pathParts, queryParts);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QueryValueToken THEN
            DStrings.Append(token.value, queryParts);
            expectingValue := FALSE;
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QuerySeparatorToken THEN
            DStrings.CopyChars("&", pathParts);
            DStrings.Append(pathParts, queryParts);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.FragmentStartToken THEN
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.FragmentToken THEN
            DStrings.Copy(token.value, newUrl.frag);
            result := TRUE
        ELSE
            result := FALSE
        END
    END;
    IF expectingValue & (DStrings.Length(lastKey) > 0) THEN
        IF DStrings.Length(queryParts) > 0 THEN
            DStrings.CopyChars("&", pathParts);
            DStrings.Append(pathParts, queryParts)
        END;
        DStrings.Copy(lastKey, pathParts);
        DStrings.Append(pathParts, queryParts)
    END;
    IF DStrings.Length(queryParts) > 0 THEN
        DStrings.Copy(queryParts, newUrl.query)
    END;
    IF result THEN
        u := newUrl
    END;
    RETURN result
END ParseDString;

(** Parses the raw string to an URL descriptor. Returns TRUE on success. *)
PROCEDURE Parse*(raw: ARRAY OF CHAR; VAR u: Url): BOOLEAN;
VAR
    input: DStrings.String;
    result: BOOLEAN;
BEGIN
    DStrings.Init(raw, input);
    result := ParseDString(input, u);
    RETURN result
END Parse;


(** Reserialize the URL. On success: out contains serialized URL, returns TRUE *)
PROCEDURE ToDString*(u: Url; VAR out: DStrings.String) : BOOLEAN;
VAR
  result: BOOLEAN;
  rider: DStrings.Rider;
BEGIN
  result := FALSE;
  DStrings.Init("", out);
  DStrings.Set(rider, out, DStrings.Length(out));

  
  IF DStrings.Length(u.scheme) > 0 THEN
    DStrings.WriteDString(rider, u.scheme);
    DStrings.WriteString(rider, "://")
  END;

  IF DStrings.Length(u.host) > 0 THEN
    DStrings.WriteDString(rider, u.host);
    result := TRUE
  END;

  IF u.port # 0 THEN
    DStrings.WriteChar(rider, ":");
    DStrings.WriteInt(rider, u.port)
  END;

  IF DStrings.Length(u.path) > 0 THEN
    DStrings.WriteDString(rider, u.path)
  END;

  IF DStrings.Length(u.query) > 0 THEN
    DStrings.WriteChar(rider, "?");
    DStrings.WriteDString(rider, u.query)
  END;

  IF DStrings.Length(u.frag) > 0 THEN
    DStrings.WriteChar(rider, "#");
    DStrings.WriteDString(rider, u.frag)
  END;

  RETURN result
END ToDString;

(* Internal: Extract next key-value pair from query string. Returns TRUE if a pair was found, FALSE if at end. Advances rider. *)
PROCEDURE NextQueryParam(VAR rider: DStrings.Rider; VAR key, value: DStrings.String): BOOLEAN;
VAR
  inKey, found: BOOLEAN;
  ch: CHAR;
  keyRider, valueRider: DStrings.Rider;
BEGIN
  found := FALSE;
  DStrings.Init("", key);
  DStrings.Init("", value);
  DStrings.Set(keyRider, key, 0);
  DStrings.Set(valueRider, value, 0);
  inKey := TRUE;
  WHILE ~rider.eot & ~found DO
    ch := DStrings.Get(rider);
    IF (ch = "=") & inKey THEN
      inKey := FALSE
    ELSIF (ch = "&") THEN
      found := TRUE
    ELSE
      IF inKey THEN
        DStrings.WriteChar(keyRider, ch)
      ELSE
        DStrings.WriteChar(valueRider, ch)
      END
    END
  END;
  (* If we stopped because of "&" or end, found a param if key is not empty *)
  RETURN DStrings.Length(key) > 0
END NextQueryParam;

(** Returns TRUE if the key was found, FALSE otherwise. Param value returned in value *)
PROCEDURE GetParam*(u: Url; keyC: ARRAY OF CHAR; VAR value: DStrings.String) : BOOLEAN;
VAR
  result: BOOLEAN;
  qRider: DStrings.Rider;
  currentKey, currentValue, key: DStrings.String;
BEGIN
  result := FALSE;
  DStrings.Init("", value);
  IF (u = NIL) OR (DStrings.Length(u.query) = 0) THEN
    result := FALSE
  ELSE
    DStrings.Init(keyC, key);
    DStrings.Set(qRider, u.query, 0);
    WHILE NextQueryParam(qRider, currentKey, currentValue) DO
      IF DStrings.Equal(currentKey, key) THEN
        DStrings.Copy(currentValue, value);
        result := TRUE
      END
    END
  END;
  RETURN result
END GetParam;

(** Sets the value of a query parameter. If the key does not exist, it is created. 
   Returns TRUE on success. *)
PROCEDURE SetParam*(u: Url; key, value: ARRAY OF CHAR) : BOOLEAN;
VAR
  result, found, first: BOOLEAN;
  qRider: DStrings.Rider;
  currentKey, currentValue, keyStr, valueStr, newQuery, temp: DStrings.String;
BEGIN
  result := FALSE;
  found := FALSE;
  first := TRUE;
  DStrings.Init(key, keyStr);
  DStrings.Init(value, valueStr);
  DStrings.Init("", newQuery);
  IF (u # NIL) THEN
    IF DStrings.Length(u.query) > 0 THEN
      DStrings.Set(qRider, u.query, 0);
      WHILE NextQueryParam(qRider, currentKey, currentValue) DO
        IF DStrings.Equal(currentKey, keyStr) THEN
          (* Replace value for this key *)
          IF ~first THEN
            DStrings.CopyChars("&", temp);
            DStrings.Append(temp, newQuery)
          END;
          DStrings.CopyChars("", temp);
          DStrings.Append(keyStr, temp);
          DStrings.CopyChars("=", temp);
          DStrings.Append(temp, newQuery);
          DStrings.Append(valueStr, newQuery);
          found := TRUE
        ELSE
          IF ~first THEN
            DStrings.CopyChars("&", temp);
            DStrings.Append(temp, newQuery)
          END;
          DStrings.Append(currentKey, newQuery);
          DStrings.CopyChars("=", temp);
          DStrings.Append(temp, newQuery);
          DStrings.Append(currentValue, newQuery)
        END;
        first := FALSE
      END
    END;
    IF ~found THEN
      IF DStrings.Length(newQuery) > 0 THEN
        DStrings.CopyChars("&", temp);
        DStrings.Append(temp, newQuery)
      END;
      DStrings.Append(keyStr, newQuery);
      DStrings.CopyChars("=", temp);
      DStrings.Append(temp, newQuery);
      DStrings.Append(valueStr, newQuery)
    END;
    DStrings.Copy(newQuery, u.query);
    result := TRUE
  END;
  RETURN result
END SetParam;

END HttpUrl.