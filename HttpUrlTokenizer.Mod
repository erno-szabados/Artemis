(** HttpUrlTokenizer.Mod - Character-based tokenizer for HTTP URLs.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)

MODULE HttpUrlTokenizer;

IMPORT Chars;

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

    MaxTokenLength* = 256;
    MaxUrlLength* = 1024;

TYPE
    Token* = RECORD
        type*: INTEGER;
        value*: ARRAY MaxTokenLength OF CHAR;
        pos*: INTEGER;        (* position in input *)
        error*: INTEGER
    END;

    Tokenizer* = POINTER TO TokenizerDesc;
    TokenizerDesc = RECORD
        input: ARRAY MaxUrlLength OF CHAR;  (* URL buffer *)
        length: INTEGER;
        index: INTEGER;
        currentChar: CHAR;
        atEof: BOOLEAN;
        error: INTEGER
    END;
    IsValidProc = PROCEDURE(ch: CHAR): BOOLEAN;

(* Internal: advance to next character *)
PROCEDURE ReadChar(tokenizer: Tokenizer);
BEGIN
    IF ~tokenizer.atEof THEN
        INC(tokenizer.index);
        IF tokenizer.index >= tokenizer.length THEN
            tokenizer.atEof := TRUE;
            tokenizer.currentChar := 0X
        ELSE
            tokenizer.currentChar := tokenizer.input[tokenizer.index]
        END
    END
END ReadChar;

(** Initialize tokenizer with raw URL string *)
PROCEDURE Init*(VAR tokenizer: Tokenizer; raw: ARRAY OF CHAR);
VAR
    result: Tokenizer;
    i: INTEGER;
BEGIN
    NEW(result);
    (* copy raw into internal buffer *)
    i := 0;
    WHILE (i < LEN(raw)) & (raw[i] # 0X) & (i < MaxUrlLength - 1) DO
        result.input[i] := raw[i];
        INC(i)
    END;
    result.input[i] := 0X;
    result.length := i;
    result.index := 0;
    result.atEof := FALSE;
    result.error := NoError;
    result.currentChar := result.input[0];
    tokenizer := result
END Init;

(* Internal: Read characters while predicate is true *)
PROCEDURE ReadWhile(tokenizer: Tokenizer; isValid: IsValidProc; VAR value: ARRAY OF CHAR);
VAR pos: INTEGER;
BEGIN
    pos := 0;
    WHILE ~tokenizer.atEof & isValid(tokenizer.currentChar) & (pos < LEN(value) - 1) DO
        value[pos] := tokenizer.currentChar;
        INC(pos);
        ReadChar(tokenizer)
    END;
    value[pos] := 0X
END ReadWhile;

(* Internal: Read until one of the delimiter characters *)
PROCEDURE ReadUntil(tokenizer: Tokenizer; delims: ARRAY OF CHAR; VAR value: ARRAY OF CHAR);
VAR pos, i: INTEGER; found: BOOLEAN;
BEGIN
    pos := 0;
    found := FALSE;
    WHILE ~tokenizer.atEof & (pos < LEN(value) - 1) & ~found DO
        i := 0;
        WHILE (i < LEN(delims)) & (delims[i] # 0X) & ~found DO
            IF tokenizer.currentChar = delims[i] THEN
                found := TRUE
            END;
            INC(i)
        END;
        IF ~found THEN
            value[pos] := tokenizer.currentChar;
            INC(pos);
            ReadChar(tokenizer)
        END
    END;
    value[pos] := 0X
END ReadUntil;

(* Internal: Check if character is valid for scheme *)
PROCEDURE IsSchemeChar(ch: CHAR): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := Chars.IsAlphaNum(ch) OR (ch = "+") OR (ch = "-") OR (ch = ".");
    RETURN result
END IsSchemeChar;

(* Internal: Read remaining characters to end *)
PROCEDURE ReadToEnd(tokenizer: Tokenizer; VAR value: ARRAY OF CHAR);
VAR pos: INTEGER;
BEGIN
    pos := 0;
    WHILE ~tokenizer.atEof & (pos < LEN(value) - 1) DO
        value[pos] := tokenizer.currentChar;
        INC(pos);
        ReadChar(tokenizer)
    END;
    value[pos] := 0X
END ReadToEnd;

(* Internal: Read path including initial slash *)
PROCEDURE ReadPath(tokenizer: Tokenizer; VAR value: ARRAY OF CHAR);
VAR pos: INTEGER; delims: ARRAY 8 OF CHAR; found: BOOLEAN; i: INTEGER;
BEGIN
    pos := 0;
    value[pos] := "/";  (* Include the initial slash *)
    INC(pos);
    ReadChar(tokenizer);  (* Skip the initial slash *)
    
    delims := "?#";
    found := FALSE;
    WHILE ~tokenizer.atEof & (pos < LEN(value) - 1) & ~found DO
        i := 0;
        WHILE (i < LEN(delims)) & (delims[i] # 0X) & ~found DO
            IF tokenizer.currentChar = delims[i] THEN
                found := TRUE
            END;
            INC(i)
        END;
        IF ~found THEN
            value[pos] := tokenizer.currentChar;
            INC(pos);
            ReadChar(tokenizer)
        END
    END;
    value[pos] := 0X
END ReadPath;

(** Get next token from URL input *)
PROCEDURE NextToken*(tokenizer: Tokenizer; VAR token: Token);
VAR delims: ARRAY 8 OF CHAR;
BEGIN
    token.error := NoError;
    token.pos := tokenizer.index;
    token.value[0] := 0X;

    IF tokenizer.atEof THEN
        token.type := EofToken
    ELSIF tokenizer.currentChar = "/" THEN
        (* Check for "//" *)
        IF (tokenizer.index + 1 < tokenizer.length) & (tokenizer.input[tokenizer.index + 1] = "/") THEN
            token.type := SlashSlashToken;
            token.value[0] := "/";
            token.value[1] := "/";
            token.value[2] := 0X;
            ReadChar(tokenizer);
            ReadChar(tokenizer)
        ELSE
            (* Single slash - start of path *)
            token.type := PathToken;
            ReadPath(tokenizer, token.value)
        END
    ELSIF tokenizer.currentChar = ":" THEN
        (* Could be end of scheme or start of port *)
        ReadChar(tokenizer);
        IF ~tokenizer.atEof & Chars.IsDigit(tokenizer.currentChar) THEN
            token.type := PortToken;
            ReadWhile(tokenizer, Chars.IsDigit, token.value)
        ELSE
            (* Just a colon separator *)
            token.type := ErrorToken;
            token.error := SyntaxError
        END
    ELSIF tokenizer.currentChar = "?" THEN
        token.type := QueryStartToken;
        token.value[0] := "?";
        token.value[1] := 0X;
        ReadChar(tokenizer)
    ELSIF tokenizer.currentChar = "#" THEN
        token.type := FragmentStartToken;
        token.value[0] := "#";
        token.value[1] := 0X;
        ReadChar(tokenizer);
        IF ~tokenizer.atEof THEN
            token.type := FragmentToken;
            ReadToEnd(tokenizer, token.value)
        END
    ELSIF tokenizer.currentChar = "=" THEN
        token.type := QueryEqualsToken;
        token.value[0] := "=";
        token.value[1] := 0X;
        ReadChar(tokenizer)
    ELSIF tokenizer.currentChar = "&" THEN
        token.type := QuerySeparatorToken;
        token.value[0] := "&";
        token.value[1] := 0X;
        ReadChar(tokenizer)
    ELSIF Chars.IsAlpha(tokenizer.currentChar) THEN
        (* Could be scheme or host *)
        ReadWhile(tokenizer, IsSchemeChar, token.value);
        IF ~tokenizer.atEof & (tokenizer.currentChar = ":") THEN
            token.type := SchemeToken
        ELSE
            (* Treat as host if no colon found *)
            token.type := HostToken
            (* ReadUntil will overwrite token.value, but that's what we want *)
        END
    ELSIF Chars.IsDigit(tokenizer.currentChar) OR (tokenizer.currentChar = "[") THEN
        (* IP address or IPv6 *)
        token.type := HostToken;
        delims := ":/?#";
        ReadUntil(tokenizer, delims, token.value)
    ELSE
        (* Query key/value or unrecognized *)
        delims := "=&#";
        ReadUntil(tokenizer, delims, token.value);
        IF token.value[0] # 0X THEN
            token.type := QueryKeyToken
        ELSE
            token.type := ErrorToken;
            token.error := SyntaxError
        END
    END
END NextToken;

(** Check if tokenizer has reached end of input *)
PROCEDURE AtEof*(tokenizer: Tokenizer): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := tokenizer.atEof;
    RETURN result
END AtEof;

(** Get current position in input *)
PROCEDURE GetPos*(tokenizer: Tokenizer): INTEGER;
VAR result: INTEGER;
BEGIN
    result := tokenizer.index;
    RETURN result
END GetPos;

(** Get current error state *)
PROCEDURE GetError*(tokenizer: Tokenizer): INTEGER;
VAR result: INTEGER;
BEGIN
    result := tokenizer.error;
    RETURN result
END GetError;

END HttpUrlTokenizer.
