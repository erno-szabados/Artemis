(** HttpUrlTokenizer.Mod - Character-based tokenizer for HTTP URLs.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)

MODULE HttpUrlTokenizer;

IMPORT Chars, DStrings;

CONST
    (* Token types *)
    EofToken* = 0;
    SchemeToken* = 1;
    SlashSlashToken* = 2;
    HostToken* = 3;
    PortToken* = 4;
    PathToken* = 5;
    QueryStartToken* = 6;
    QueryKeyToken* = 7;
    QueryEqualsToken* = 8;
    QueryValueToken* = 9;
    QuerySeparatorToken* = 10;
    FragmentStartToken* = 11;
    FragmentToken* = 12;
    ErrorToken* = 13;

    (* Error codes *)
    NoError* = 0;
    SyntaxError* = 1;

    (* Tokenizer states *)
    StateScheme = 0;
    StateAuthority = 1;
    StatePath = 2;
    StateQuery = 3;
    StateQueryKey = 4;
    StateQueryValue = 5;
    StateFragment = 6;
    StateEof = 7;

TYPE
    Token* = RECORD
        type*: INTEGER;
        value*: DStrings.String;
        rider*: DStrings.Rider;
        error*: INTEGER
    END;

    Tokenizer* = POINTER TO TokenizerDesc;
    TokenizerDesc = RECORD
        str: DStrings.String;
        rider: DStrings.Rider;
        error: INTEGER;
        state: INTEGER
    END;
    IsValidProc = PROCEDURE(ch: CHAR): BOOLEAN;

(** Initialize tokenizer with raw URL string *)
PROCEDURE Init*(VAR tokenizer: Tokenizer; raw: ARRAY OF CHAR);
VAR result: Tokenizer;
BEGIN
    NEW(result);
    DStrings.Init(raw, result.str);
    DStrings.Set(result.rider, result.str, 0);
    result.error := NoError;
    result.state := StateScheme;
    tokenizer := result
END Init;

(** TRUE if tokenizer has reached end of input *)
PROCEDURE AtEof*(tokenizer: Tokenizer): BOOLEAN;
BEGIN
    RETURN tokenizer.rider.eot
END AtEof;

(* Internal: Read while predicate is true *)
PROCEDURE ReadWhile(tokenizer: Tokenizer; isValid: IsValidProc; VAR value: DStrings.String);
VAR start, len: INTEGER; ch: CHAR;
BEGIN
    start := tokenizer.rider.pos;
    ch := DStrings.Peek(tokenizer.rider);
    WHILE ~tokenizer.rider.eot & isValid(ch) DO
        ch := DStrings.Get(tokenizer.rider);
        ch := DStrings.Peek(tokenizer.rider)
    END;
    len := tokenizer.rider.pos - start;
    IF len > 0 THEN
        DStrings.Extract(tokenizer.str, start, len, value)
    ELSE
        DStrings.Clear(value)
    END
END ReadWhile;


(* Internal: Read until one of the delimiter characters *)
PROCEDURE ReadUntil(tokenizer: Tokenizer; delims: ARRAY OF CHAR; VAR value: DStrings.String);
VAR start, len, i: INTEGER; ch: CHAR; found: BOOLEAN;
BEGIN
    start := tokenizer.rider.pos;
    found := FALSE;
    ch := DStrings.Peek(tokenizer.rider);
    WHILE ~tokenizer.rider.eot & ~found DO
        i := 0;
        WHILE (i < LEN(delims)) & (delims[i] # 0X) & ~found DO
            IF ch = delims[i] THEN
                found := TRUE
            END;
            INC(i)
        END;
        IF ~found THEN
            ch := DStrings.Get(tokenizer.rider);
            ch := DStrings.Peek(tokenizer.rider)
        END
    END;
    len := tokenizer.rider.pos - start;
    IF len > 0 THEN
        DStrings.Extract(tokenizer.str, start, len, value)
    ELSE
        DStrings.Clear(value)
    END
END ReadUntil;

(* Internal: Check if character is valid for scheme *)
PROCEDURE IsSchemeChar(ch: CHAR): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := Chars.IsAlphaNum(ch) OR (ch = "+") OR (ch = "-") OR (ch = ".");
    RETURN result
END IsSchemeChar;

(* Internal: Read scheme token and advance past ':' *)
PROCEDURE ReadSchemeToken(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    ReadWhile(tokenizer, IsSchemeChar, token.value);
    ch := DStrings.Peek(tokenizer.rider);
    IF ~AtEof(tokenizer) & (ch = ":") THEN
        token.type := SchemeToken;
        ch := DStrings.Get(tokenizer.rider)  (* Advance past ':' *)
    ELSE
        token.type := HostToken
    END
END ReadSchemeToken;

(* Internal: Read slash-slash token and advance past both slashes *)
PROCEDURE ReadSlashSlashToken(tokenizer: Tokenizer; VAR token: Token);
VAR ch1, ch2: CHAR;
BEGIN
    ch1 := DStrings.Peek(tokenizer.rider);
    IF ~tokenizer.rider.eot THEN ch1 := DStrings.Get(tokenizer.rider) END;
    ch2 := DStrings.Peek(tokenizer.rider);
    IF (ch1 = "/") & (ch2 = "/") THEN
        ch2 := DStrings.Get(tokenizer.rider); (* advance past second slash *)
        token.type := SlashSlashToken;
        DStrings.CopyChars("//", token.value)
    ELSE
        (* Not actually a double slash, treat as path or error *)
        token.type := PathToken;
        DStrings.CopyChars("/", token.value)
    END
END ReadSlashSlashToken;

(* Internal: Read host token up to ':', '/', '?', or '#' *)
PROCEDURE ReadHostToken(tokenizer: Tokenizer; VAR token: Token);
VAR delims: ARRAY 8 OF CHAR;
BEGIN
    token.type := HostToken;
    delims := ":/?#";
    ReadUntil(tokenizer, delims, token.value)
END ReadHostToken;

(* Internal: Read port token and advance past ':' *)
PROCEDURE ReadPortToken(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    ch := DStrings.Peek(tokenizer.rider);
    IF ch = ":" THEN
        ch := DStrings.Get(tokenizer.rider)
    END;
    token.type := PortToken;
    ReadWhile(tokenizer, Chars.IsDigit, token.value)
END ReadPortToken;

(* Internal: Read path token *)
PROCEDURE ReadPathToken(tokenizer: Tokenizer; VAR token: Token);
VAR start, len: INTEGER; ch: CHAR; found: BOOLEAN;
BEGIN
    token.type := PathToken;
    start := tokenizer.rider.pos;
    ch := DStrings.Get(tokenizer.rider);  (* Skip the initial slash *)
    found := FALSE;
    ch := DStrings.Peek(tokenizer.rider);
    WHILE ~tokenizer.rider.eot & ~found DO
        IF (ch = "?") OR (ch = "#") THEN
            found := TRUE
        ELSE
            ch := DStrings.Get(tokenizer.rider);
            ch := DStrings.Peek(tokenizer.rider)
        END
    END;
    len := tokenizer.rider.pos - start;
    IF len > 0 THEN
        DStrings.Extract(tokenizer.str, start, len, token.value)
    ELSE
        DStrings.Clear(token.value)
    END
END ReadPathToken;

(* Internal: Read query start token and advance past '?' *)
PROCEDURE ReadQueryStartToken(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    token.type := QueryStartToken;
    DStrings.CopyChars("?", token.value);
    ch := DStrings.Get(tokenizer.rider)  (* Advance past '?' *)
END ReadQueryStartToken;

(* Internal: Read query key token *)
PROCEDURE ReadQueryKeyToken(tokenizer: Tokenizer; VAR token: Token);
VAR delims: ARRAY 8 OF CHAR;
BEGIN
    token.type := QueryKeyToken;
    delims := "=&#";
    ReadUntil(tokenizer, delims, token.value)
END ReadQueryKeyToken;

(* Internal: Read query equals token and advance past '=' *)
PROCEDURE ReadQueryEqualsToken(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    token.type := QueryEqualsToken;
    DStrings.CopyChars("=", token.value);
    ch := DStrings.Get(tokenizer.rider)  (* Advance past '=' *)
END ReadQueryEqualsToken;

(* Internal: Read query value token *)
PROCEDURE ReadQueryValueToken(tokenizer: Tokenizer; VAR token: Token);
VAR delims: ARRAY 8 OF CHAR;
BEGIN
    token.type := QueryValueToken;
    delims := "&#";
    ReadUntil(tokenizer, delims, token.value)
END ReadQueryValueToken;

(* Internal: Read query separator token and advance past '&' *)
PROCEDURE ReadQuerySeparatorToken(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    token.type := QuerySeparatorToken;
    DStrings.CopyChars("&", token.value);
    ch := DStrings.Get(tokenizer.rider)  (* Advance past '&' *)
END ReadQuerySeparatorToken;

(* Internal: Read fragment start token and advance past '#' *)
PROCEDURE ReadFragmentStartToken(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    token.type := FragmentStartToken;
    DStrings.CopyChars("#", token.value);
    ch := DStrings.Get(tokenizer.rider)  (* Advance past '#' *)
END ReadFragmentStartToken;

(* Internal: Read fragment token *)
PROCEDURE ReadFragmentToken(tokenizer: Tokenizer; VAR token: Token);
VAR start, len: INTEGER; ch : CHAR;
BEGIN
    token.type := FragmentToken;
    start := tokenizer.rider.pos;
    WHILE ~tokenizer.rider.eot DO
        ch := DStrings.Get(tokenizer.rider)
    END;
    len := tokenizer.rider.pos - start;
    IF len > 0 THEN
        DStrings.Extract(tokenizer.str, start, len, token.value)
    ELSE
        DStrings.Clear(token.value)
    END
END ReadFragmentToken;

(* Internal: Peek at next character without advancing position *)
PROCEDURE PeekNext(tokenizer: Tokenizer): CHAR;
VAR tempRider: DStrings.Rider; ch: CHAR;
BEGIN
    tempRider := tokenizer.rider;
    ch := DStrings.Get(tempRider);
    ch := DStrings.Peek(tempRider);
    RETURN ch
END PeekNext;

(* Internal: Handle StateScheme state *)
PROCEDURE HandleStateScheme(tokenizer: Tokenizer; VAR token: Token);
VAR ch, next: CHAR;
BEGIN
    next := PeekNext(tokenizer);
    ch := DStrings.Peek(tokenizer.rider);
    IF Chars.IsAlpha(ch) THEN
        ReadSchemeToken(tokenizer, token);
        tokenizer.state := StateAuthority
    ELSIF (ch = "/") & (next = "/") THEN
        ReadSlashSlashToken(tokenizer, token);
        tokenizer.state := StateAuthority
    ELSIF ch = "/" THEN
        ReadPathToken(tokenizer, token);
        tokenizer.state := StatePath
    ELSE
        token.type := ErrorToken;
        tokenizer.error := SyntaxError;
        tokenizer.state := StateEof
    END
END HandleStateScheme;

(* Internal: Handle StateAuthority state *)
PROCEDURE HandleStateAuthority(tokenizer: Tokenizer; VAR token: Token);
VAR ch, next: CHAR;
BEGIN
    next := PeekNext(tokenizer);
    ch := DStrings.Peek(tokenizer.rider);
    IF (ch = "/") & (next = "/") THEN
        ReadSlashSlashToken(tokenizer, token);
        tokenizer.state := StateAuthority
    ELSIF ch = "/" THEN
        ReadPathToken(tokenizer, token);
        tokenizer.state := StatePath
    ELSIF ch = ":" THEN
        ReadPortToken(tokenizer, token);
        tokenizer.state := StateAuthority
    ELSIF ch = "?" THEN
        ReadQueryStartToken(tokenizer, token);
        tokenizer.state := StateQuery
    ELSIF ch = "#" THEN
        ReadFragmentStartToken(tokenizer, token);
        tokenizer.state := StateFragment
    ELSE
        ReadHostToken(tokenizer, token);
        ch := DStrings.Peek(tokenizer.rider);
        IF ch = ":" THEN
            tokenizer.state := StateAuthority
        ELSIF ch = "/" THEN
            tokenizer.state := StatePath
        ELSIF ch = "?" THEN
            tokenizer.state := StateQuery
        ELSIF ch = "#" THEN
            tokenizer.state := StateFragment
        ELSE
            tokenizer.state := StateEof
        END
    END
END HandleStateAuthority;

(* Internal: Handle StatePath state *)
PROCEDURE HandleStatePath(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    ch := DStrings.Peek(tokenizer.rider);
    IF ch = "?" THEN
        ReadQueryStartToken(tokenizer, token);
        tokenizer.state := StateQuery
    ELSIF ch = "#" THEN
        ReadFragmentStartToken(tokenizer, token);
        tokenizer.state := StateFragment
    ELSE
        ReadPathToken(tokenizer, token);
        ch := DStrings.Peek(tokenizer.rider);
        IF ch = "?" THEN
            tokenizer.state := StateQuery
        ELSIF ch = "#" THEN
            tokenizer.state := StateFragment
        ELSE
            tokenizer.state := StateEof
        END
    END
END HandleStatePath;

(* Internal: Handle StateQuery state *)
PROCEDURE HandleStateQuery(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    ch := DStrings.Peek(tokenizer.rider);
    IF ch = "#" THEN
        ReadFragmentStartToken(tokenizer, token);
        tokenizer.state := StateFragment
    ELSIF ch = "&" THEN
        ReadQuerySeparatorToken(tokenizer, token);
        tokenizer.state := StateQueryKey
    ELSIF ch = "=" THEN
        ReadQueryEqualsToken(tokenizer, token);
        tokenizer.state := StateQueryValue
    ELSE
        ReadQueryKeyToken(tokenizer, token);
        tokenizer.state := StateQueryKey
    END
END HandleStateQuery;

(* Internal: Handle StateQueryKey state *)
PROCEDURE HandleStateQueryKey(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    ch := DStrings.Peek(tokenizer.rider);
    IF ch = "=" THEN
        ReadQueryEqualsToken(tokenizer, token);
        tokenizer.state := StateQueryValue
    ELSIF ch = "&" THEN
        ReadQuerySeparatorToken(tokenizer, token);
        tokenizer.state := StateQueryKey
    ELSIF ch = "#" THEN
        ReadFragmentStartToken(tokenizer, token);
        tokenizer.state := StateFragment
    ELSE
        ReadQueryKeyToken(tokenizer, token);
        tokenizer.state := StateQueryKey
    END
END HandleStateQueryKey;

(* Internal: Handle StateQueryValue state *)
PROCEDURE HandleStateQueryValue(tokenizer: Tokenizer; VAR token: Token);
VAR ch: CHAR;
BEGIN
    ch := DStrings.Peek(tokenizer.rider);
    IF ch = "&" THEN
        ReadQuerySeparatorToken(tokenizer, token);
        tokenizer.state := StateQueryKey
    ELSIF ch = "#" THEN
        ReadFragmentStartToken(tokenizer, token);
        tokenizer.state := StateFragment
    ELSE
        ReadQueryValueToken(tokenizer, token);
        tokenizer.state := StateQueryValue
    END
END HandleStateQueryValue;

(* Internal: Handle StateFragment state *)
PROCEDURE HandleStateFragment(tokenizer: Tokenizer; VAR token: Token);
BEGIN
    ReadFragmentToken(tokenizer, token);
    tokenizer.state := StateEof
END HandleStateFragment;

(* Internal: Handle StateEof state *)
PROCEDURE HandleStateEof(tokenizer: Tokenizer; VAR token: Token);
BEGIN
    token.type := EofToken
END HandleStateEof;

(* Update NextToken to use and update tokenizer.state for stateful parsing *)
PROCEDURE NextToken*(tokenizer: Tokenizer; VAR token: Token);
BEGIN
    token.error := NoError;
    DStrings.Init("", token.value);
    IF AtEof(tokenizer) THEN
        token.type := EofToken;
        tokenizer.state := StateEof
    ELSE
        CASE tokenizer.state OF
            StateScheme:      HandleStateScheme(tokenizer, token)
            | StateAuthority: HandleStateAuthority(tokenizer, token)
            | StatePath:      HandleStatePath(tokenizer, token)
            | StateQuery:     HandleStateQuery(tokenizer, token)
            | StateQueryKey:  HandleStateQueryKey(tokenizer, token)
            | StateQueryValue:HandleStateQueryValue(tokenizer, token)
            | StateFragment:  HandleStateFragment(tokenizer, token)
            | StateEof:       HandleStateEof(tokenizer, token)
        END
    END
END NextToken;

(** Get current position in input *)
PROCEDURE GetPos*(tokenizer: Tokenizer): INTEGER;
BEGIN
    RETURN tokenizer.rider.pos
END GetPos;

(** Get current error state *)
PROCEDURE GetError*(tokenizer: Tokenizer): INTEGER;
BEGIN
    RETURN tokenizer.error
END GetError;

END HttpUrlTokenizer.
