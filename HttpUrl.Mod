MODULE HttpUrl;

IMPORT DStrings;  (* for dynamic path/query/fragment storage *)

TYPE
  Url* = POINTER TO UrlDesc;
  UrlDesc* = RECORD
    scheme*: ARRAY 8 OF CHAR;      (* “http”, “https” *)
    host*:   ARRAY 256 OF CHAR;    (* domain or IP *)
    port*:   INTEGER;              (* 0 = default port *)
    path*:   DStrings.String;     (* “/foo/bar” *)
    query*:  DStrings.String;     (* “a=1&b=2” *)
    frag*:   DStrings.String     (* “section1” *)
  END;

(* Internal helpers, not exported *)
PROCEDURE decodePercent(VAR s: DStrings.String);
BEGIN
    (* TODO *)
END decodePercent;  

(* Parses the string to an URL descriptor. Returns TRUE on success. *)
PROCEDURE Parse*(raw: ARRAY OF CHAR; VAR u: Url): BOOLEAN;
BEGIN
    RETURN FALSE
END Parse;

(* Reserialize the URL. On success: u ≠ NIL, u→… fields populated, returns TRUE *)
PROCEDURE ToString*(u: Url; VAR out: DStrings.String) : BOOLEAN;
BEGIN
  RETURN FALSE
END ToString;

(* Returns TRUE if the key was found, FALSE otherwise. *)
PROCEDURE GetParam*(u: Url; key: ARRAY OF CHAR; VAR value: DStrings.String) : BOOLEAN;
BEGIN
  RETURN FALSE
END GetParam;

(* Sets the value of a query parameter. If the key does not exist, it is created. 
   Returns TRUE on success. *)
PROCEDURE SetParam*(u: Url; key, value: ARRAY OF CHAR) : BOOLEAN;
BEGIN
  RETURN FALSE
END SetParam;

END HttpUrl.