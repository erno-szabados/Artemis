(** HttpRequest.Mod - HTTP request construction and serialization module

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)

MODULE HttpRequest;

IMPORT DStrings, HttpHeader, Chars;

TYPE
  HttpRequest* = POINTER TO HttpRequestDesc;
  HttpRequestDesc* = RECORD
    method*: DStrings.String;      (* e.g., "GET", "POST" *)
    url*:    DStrings.String;      (* path and query, e.g., "/foo?bar=1" *)
    headers*: HttpHeader.Header;   (* HTTP headers *)
    body*:   DStrings.String      (* request body, may be empty *)
  END;

(** Initializes a new HTTP request with the given method and url/path. *)
PROCEDURE Init*(method, url: ARRAY OF CHAR; VAR req: HttpRequest);
VAR result: HttpRequest;
BEGIN
  NEW(result);
  DStrings.Init(method, result.method);
  DStrings.Init(url, result.url);
  HttpHeader.Init(result.headers);
  DStrings.Init("", result.body);
  req := result
END Init;

(** Sets a header field (case-insensitive). Accepts ARRAY OF CHAR for ergonomics. *)
PROCEDURE SetHeader*(req: HttpRequest; key, value: ARRAY OF CHAR): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  result := FALSE;
  IF req # NIL THEN
    result := HttpHeader.Set(req.headers, key, value)
  END;
  RETURN result
END SetHeader;

(** Sets the request body from an ARRAY OF CHAR. *)
PROCEDURE SetBody*(req: HttpRequest; body: ARRAY OF CHAR): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  result := FALSE;
  IF req # NIL THEN
    DStrings.Init(body, req.body);
    result := TRUE
  END;
  RETURN result
END SetBody;

(** Sets the request body from a DStrings.String. *)
PROCEDURE SetBodyDString*(req: HttpRequest; body: DStrings.String): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  result := FALSE;
  IF req # NIL THEN
    DStrings.Copy(body, req.body);
    result := TRUE
  END;
  RETURN result
END SetBodyDString;

(** Serializes the request into a DStrings.String for sending. *)
PROCEDURE ToString*(req: HttpRequest; VAR out: DStrings.String): BOOLEAN;
VAR
  result: BOOLEAN;
  rider: DStrings.Rider;
  headerStr: DStrings.String;
BEGIN
  result := FALSE;
  IF req # NIL THEN
    DStrings.Init("", out);
    DStrings.Set(rider, out, 0);

    (* Write request line *)
    DStrings.WriteDString(rider, req.method);
    DStrings.WriteChar(rider, " ");
    DStrings.WriteDString(rider, req.url);
    DStrings.WriteString(rider, " HTTP/1.1");
    DStrings.WriteChar(rider, Chars.CR);
    DStrings.WriteChar(rider, Chars.LF);

    (* Write headers *)
    DStrings.Init("", headerStr);
    IF HttpHeader.ToString(req.headers, headerStr) THEN
      DStrings.WriteDString(rider, headerStr)
    END;
    DStrings.WriteChar(rider, Chars.CR);
    DStrings.WriteChar(rider, Chars.LF);

    (* Write body if present *)
    IF DStrings.Length(req.body) > 0 THEN
      DStrings.WriteDString(rider, req.body)
    END;

    result := TRUE
  END;
  RETURN result
END ToString;

(** Gets the value of a header field (case-insensitive). Returns TRUE if found. *)
PROCEDURE GetHeader*(req: HttpRequest; key: ARRAY OF CHAR; VAR value: DStrings.String): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  result := FALSE;
  IF req # NIL THEN
    result := HttpHeader.Get(req.headers, key, value)
  END;
  RETURN result
END GetHeader;

(** Gets the request method as a DStrings.String. *)
PROCEDURE GetMethod*(req: HttpRequest; VAR method: DStrings.String);
BEGIN
  IF req # NIL THEN
    DStrings.Copy(req.method, method)
  END
END GetMethod;

(** Gets the request URL/path as a DStrings.String. *)
PROCEDURE GetUrl*(req: HttpRequest; VAR url: DStrings.String);
BEGIN
  IF req # NIL THEN
    DStrings.Copy(req.url, url)
  END
END GetUrl;

(** Gets the request body as a DStrings.String. *)
PROCEDURE GetBody*(req: HttpRequest; VAR body: DStrings.String);
BEGIN
  IF req # NIL THEN
    DStrings.Copy(req.body, body)
  END
END GetBody;

END HttpRequest.
