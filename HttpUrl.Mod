MODULE HttpUrl;

IMPORT Chars, DStrings, HttpUrlTokenizer;  (* for dynamic path/query/fragment storage *)

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


(* Internal: Convert string to integer *)
PROCEDURE StringToInt(s: ARRAY OF CHAR): INTEGER;
VAR result, i: INTEGER; ch: CHAR;
BEGIN
    result := 0;
    i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO
        ch := s[i];
        IF (ch >= "0") & (ch <= "9") THEN
            result := result * 10 + (ORD(ch) - ORD("0"))
        END;
        INC(i)
    END;
    RETURN result
END StringToInt;

(* Parses the string to an URL descriptor. Returns TRUE on success. *)
PROCEDURE Parse*(raw: ARRAY OF CHAR; VAR u: Url): BOOLEAN;
VAR
    result: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
    newUrl: Url;
    queryParts: DStrings.String;
    pathParts: DStrings.String;
    fragParts: DStrings.String;
    expectingValue: BOOLEAN;
    lastKey: ARRAY 256 OF CHAR;
BEGIN
    result := FALSE;
    
    (* Initialize new URL structure *)
    NEW(newUrl);
    newUrl.scheme[0] := 0X;
    newUrl.host[0] := 0X;
    newUrl.port := 0;
    DStrings.Init("", newUrl.path);
    DStrings.Init("", newUrl.query);
    DStrings.Init("", newUrl.frag);
    
    (* Initialize tokenizer *)
    HttpUrlTokenizer.Init(tokenizer, raw);
    
    (* Parse tokens in order: [scheme:][//]host[:port][/path][?query][#fragment] *)
    expectingValue := FALSE;
    lastKey[0] := 0X;
    
    WHILE ~HttpUrlTokenizer.AtEof(tokenizer) DO
        HttpUrlTokenizer.NextToken(tokenizer, token);
        
        IF token.type = HttpUrlTokenizer.ErrorToken THEN
            (* Parsing error occurred *)
            result := FALSE
        ELSIF token.type = HttpUrlTokenizer.EofToken THEN
            (* End of input *)
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.SchemeToken THEN
            (* Copy scheme *)
            Chars.Copy(token.value, newUrl.scheme);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.SlashSlashToken THEN
            (* Skip "//" - it's just a separator *)
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.HostToken THEN
            (* Copy host *)
            Chars.Copy(token.value, newUrl.host);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.PortToken THEN
            (* Convert port string to integer *)
            newUrl.port := StringToInt(token.value);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.PathToken THEN
            (* Store path *)
            DStrings.CopyChars(token.value, newUrl.path);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QueryStartToken THEN
            (* Initialize query string building *)
            DStrings.Init("", queryParts);
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QueryKeyToken THEN
            IF expectingValue THEN
                (* This is actually a query value - build key=value pair *)
                IF DStrings.Length(queryParts) > 0 THEN
                    DStrings.CopyChars("&", pathParts);
                    DStrings.Append(pathParts, queryParts)
                END;
                DStrings.CopyChars(lastKey, pathParts);
                DStrings.Append(pathParts, queryParts);
                DStrings.CopyChars("=", pathParts);
                DStrings.Append(pathParts, queryParts);
                DStrings.CopyChars(token.value, pathParts);
                DStrings.Append(pathParts, queryParts);
                expectingValue := FALSE
            ELSE
                (* This is a query key *)
                Chars.Copy(token.value, lastKey);
                expectingValue := TRUE
            END;
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QueryEqualsToken THEN
            (* Continue - next token should be value *)
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.QuerySeparatorToken THEN
            (* Reset for next key-value pair *)
            expectingValue := FALSE;
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.FragmentStartToken THEN
            (* Skip "#" - it's just a separator *)
            result := TRUE
        ELSIF token.type = HttpUrlTokenizer.FragmentToken THEN
            (* Store fragment *)
            DStrings.CopyChars(token.value, newUrl.frag);
            result := TRUE
        ELSE
            (* Unknown token type *)
            result := FALSE
        END
    END;
    
    (* If we had a pending key without value, add it *)
    IF expectingValue & (lastKey[0] # 0X) THEN
        IF DStrings.Length(queryParts) > 0 THEN
            DStrings.CopyChars("&", pathParts);
            DStrings.Append(pathParts, queryParts)
        END;
        DStrings.CopyChars(lastKey, pathParts);
        DStrings.Append(pathParts, queryParts)
    END;
    
    (* Assign final query string *)
    IF DStrings.Length(queryParts) > 0 THEN
        DStrings.Copy(queryParts, newUrl.query)
    END;
    
    (* Only assign result if parsing was successful *)
    IF result THEN
        u := newUrl
    END;
    
    RETURN result
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