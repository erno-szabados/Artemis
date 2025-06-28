(** HttpResponse.Mod - HTTP response parsing and representation module

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)

MODULE HttpResponse;

IMPORT DStrings, HttpHeader, Chars;

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

(** Parses a raw HTTP response (ARRAY OF CHAR) into a HttpResponse. Returns TRUE on success. *)
PROCEDURE Parse*(raw: ARRAY OF CHAR; VAR resp: HttpResponse): BOOLEAN;
BEGIN
  (* Implementation to be added *)
  RETURN FALSE
END Parse;

(** Returns the status code. *)
PROCEDURE GetStatus*(resp: HttpResponse): INTEGER;
BEGIN
  RETURN resp.statusCode
END GetStatus;

(** Gets the reason phrase. *)
PROCEDURE GetReason*(resp: HttpResponse; VAR reason: DStrings.String);
BEGIN
  DStrings.Copy(resp.reason, reason)
END GetReason;

(** Gets the HTTP version. *)
PROCEDURE GetVersion*(resp: HttpResponse; VAR version: DStrings.String);
BEGIN
  DStrings.Copy(resp.version, version)
END GetVersion;

(** Gets the value of a header field (case-insensitive). Returns TRUE if found. *)
PROCEDURE GetHeader*(resp: HttpResponse; key: ARRAY OF CHAR; VAR value: DStrings.String): BOOLEAN;
BEGIN
  RETURN HttpHeader.Get(resp.headers, key, value)
END GetHeader;

(** Gets the response body. *)
PROCEDURE GetBody*(resp: HttpResponse; VAR body: DStrings.String);
BEGIN
  DStrings.Copy(resp.body, body)
END GetBody;

(** Returns TRUE if the response was parsed without error. *)
PROCEDURE IsOk*(resp: HttpResponse): BOOLEAN;
BEGIN
  RETURN resp.error = Ok
END IsOk;

END HttpResponse.
