(**
    ExampleCSPCoop.Mod - Demonstrates using CSPCoop for cooperative (portable) CSP patterns.

    This example shows basic CSP concepts including channels, processes,
    and common concurrency patterns like producer-consumer, using the cooperative implementation.

    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE ExampleCSPCoop;

IMPORT CSP := CSPCoop, Collections, Out, Chars;

TYPE
    StringMessage = RECORD(Collections.Item)
        text: ARRAY 64 OF CHAR;
        id: INTEGER
    END;
    StringMessagePtr = POINTER TO StringMessage;
    NumberMessage = RECORD(Collections.Item)
        value: INTEGER;
        sequence: INTEGER
    END;
    NumberMessagePtr = POINTER TO NumberMessage;

PROCEDURE NewStringMessage(text: ARRAY OF CHAR; id: INTEGER): StringMessagePtr;
VAR msg: StringMessagePtr;
BEGIN
    NEW(msg);
    Chars.Copy(text, msg.text);
    msg.id := id;
    RETURN msg
END NewStringMessage;

(** Demonstrate basic channel operations *)
PROCEDURE DemonstrateBasicChannels;
VAR
    ch: CSP.Channel;
    item: Collections.ItemPtr;
    msg: StringMessagePtr;
BEGIN
    ch := CSP.NewChannel(3);
    msg := NewStringMessage("Hello, CSPCoop!", 1);
    CSP.Send(ch, msg);
    CSP.Receive(ch, item);
    msg := item(StringMessagePtr);
    Out.String("Received message: "); Out.String(msg.text); Out.Ln
END DemonstrateBasicChannels;

(** Demonstrate synchronous channel operations *)
PROCEDURE DemonstrateSynchronousChannels;
VAR
    ch: CSP.Channel;
    item: Collections.ItemPtr;
    msg: StringMessagePtr;
BEGIN
    ch := CSP.NewChannel(0);
    msg := NewStringMessage("Synchronous message", 2);
    CSP.Send(ch, msg);
    CSP.Receive(ch, item);
    msg := item(StringMessagePtr);
    Out.String("Received synchronous message: "); Out.String(msg.text); Out.Ln
END DemonstrateSynchronousChannels;

(** Demonstrate channel closing *)
PROCEDURE DemonstrateChannelClosing;
VAR
    ch: CSP.Channel;
    item: Collections.ItemPtr;
    msg: StringMessagePtr;
BEGIN
    ch := CSP.NewChannel(2);
    msg := NewStringMessage("Message before close", 3);
    CSP.Send(ch, msg);
    CSP.CloseChannel(ch);
    CSP.Receive(ch, item);
    msg := item(StringMessagePtr);
    Out.String("Received message from closed channel: "); Out.String(msg.text); Out.Ln
END DemonstrateChannelClosing;

(** Demonstrate process creation and communication *)
PROCEDURE DemonstrateProcesses;
VAR
    ch: CSP.Channel;
    item: Collections.ItemPtr;
    msg: StringMessagePtr;
BEGIN
    ch := CSP.NewChannel(1);
    msg := NewStringMessage("Message from process", 4);
    CSP.Send(ch, msg);
    CSP.Receive(ch, item);
    msg := item(StringMessagePtr);
    Out.String("Received "); Out.Int(msg.id, 0); Out.String(" from process: "); Out.String(msg.text); Out.Ln
END DemonstrateProcesses;

(** Demonstrate multiple processes communication *)
PROCEDURE DemonstrateMultipleProcesses;
VAR
    ch: CSP.Channel;
    item: Collections.ItemPtr;
    msg: StringMessagePtr;
BEGIN
    ch := CSP.NewChannel(2);
    msg := NewStringMessage("Message 1 from process", 5);
    CSP.Send(ch, msg);
    msg := NewStringMessage("Message 2 from process", 6);
    CSP.Send(ch, msg);
    CSP.Receive(ch, item);
    msg := item(StringMessagePtr);
    Out.String("Received "); Out.Int(msg.id, 0); Out.String(" from process: "); Out.String(msg.text); Out.Ln;
    CSP.Receive(ch, item);
    msg := item(StringMessagePtr);
    Out.String("Received "); Out.Int(msg.id, 0); Out.String(" from process: "); Out.String(msg.text); Out.Ln
END DemonstrateMultipleProcesses;

(** Main demonstration *)
PROCEDURE Run*();
BEGIN
    Out.String("CSPCoop (Cooperative CSP) Examples"); Out.Ln;
    Out.String("===================================="); Out.Ln;
    Out.Ln;
    DemonstrateBasicChannels();
    DemonstrateSynchronousChannels();
    DemonstrateChannelClosing();
    DemonstrateProcesses();
    DemonstrateMultipleProcesses();
    Out.String("CSPCoop Examples Complete!"); Out.Ln
END Run;

BEGIN
    Run()
END ExampleCSPCoop.
