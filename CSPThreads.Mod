(**
    CSPThreads.Mod - Thread-safe channels and threading utilities for Oberon-07
    
    Provides:
    - Thread-safe buffered channels with blocking/non-blocking operations
    - Basic thread creation and management using PThreads
    - Clean CSP-style communication primitives
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE CSPThreads;

IMPORT Collections, Queue, artPThread, SYSTEM;

CONST
    OPEN* = 0;
    CLOSED* = 1;

TYPE
    (** Thread-safe channel for message passing between threads *)
    Channel* = POINTER TO ChannelDesc;
    ChannelDesc = RECORD
        buffer: Queue.Queue;
        capacity: INTEGER;
        state: INTEGER;
        mutex: artPThread.Mutex;
        sendCond: artPThread.CondVar;
        recvCond: artPThread.CondVar
    END;

    (** Thread procedure signature *)
    ThreadProc* = PROCEDURE;
    
    (** Thread handle for managing OS threads *)
    Thread* = POINTER TO ThreadDesc;
    ThreadDesc = RECORD
        proc: ThreadProc;
        thread: artPThread.Thread
    END;

(** Thread trampoline - bridges C thread creation to Oberon procedures *)
PROCEDURE ThreadTrampoline(context: INTEGER): INTEGER;
VAR proc: ThreadProc;
BEGIN
    proc := SYSTEM.VAL(ThreadProc, context);
    IF proc # NIL THEN proc() END;
    RETURN 0
END ThreadTrampoline;

(** Create a new thread-safe channel with specified buffer capacity *)
PROCEDURE NewChannel*(capacity: INTEGER): Channel;
VAR ch: Channel;
BEGIN
    NEW(ch);
    ch.buffer := Queue.New();
    ch.capacity := capacity;
    ch.state := OPEN;
    ch.mutex := artPThread.NewMutex();
    ch.sendCond := artPThread.NewCondVar();
    ch.recvCond := artPThread.NewCondVar();
    RETURN ch
END NewChannel;

(** Free channel resources - call when done with channel *)
PROCEDURE FreeChannel*(VAR ch: Channel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED;
        IF ch.buffer # NIL THEN Queue.Clear(ch.buffer) END;
        IF ch.mutex # NIL THEN artPThread.FreeMutex(ch.mutex) END;
        IF ch.sendCond # NIL THEN artPThread.FreeCondVar(ch.sendCond) END;
        IF ch.recvCond # NIL THEN artPThread.FreeCondVar(ch.recvCond) END;
        ch := NIL
    END
END FreeChannel;

(** Close a channel - no more sends allowed, receives drain remaining messages *)
PROCEDURE CloseChannel*(ch: Channel);
BEGIN
    IF ch # NIL THEN
        IF artPThread.Lock(ch.mutex) THEN
            ch.state := CLOSED;
            (* Wake up any waiting receivers *)
            IF artPThread.Broadcast(ch.recvCond) THEN END;
            IF artPThread.Unlock(ch.mutex) THEN END
        END
    END
END CloseChannel;

(** Check if channel is closed *)
PROCEDURE IsClosed*(ch: Channel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsClosed;

(** Non-blocking send - returns TRUE if message was sent, FALSE if buffer full *)
PROCEDURE TrySend*(ch: Channel; item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN
        IF artPThread.TryLock(ch.mutex) THEN
            IF (ch.state = OPEN) & (Queue.Count(ch.buffer) < ch.capacity) THEN
                Queue.Enqueue(ch.buffer, item);
                ok := artPThread.Signal(ch.recvCond);
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
        END
    END;
    RETURN result
END TrySend;

(** Non-blocking receive - returns TRUE if message received, FALSE if buffer empty *)
PROCEDURE TryReceive*(ch: Channel; VAR item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    item := NIL;
    IF ch # NIL THEN
        IF artPThread.TryLock(ch.mutex) THEN
            IF Queue.Count(ch.buffer) > 0 THEN
                Queue.Dequeue(ch.buffer, item);
                ok := artPThread.Signal(ch.sendCond);
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
        END
    END;
    RETURN result
END TryReceive;

(** Blocking send - waits until message can be sent or channel is closed *)
PROCEDURE Send*(ch: Channel; item: Collections.ItemPtr);
VAR done, ok: BOOLEAN;
BEGIN
    done := FALSE;
    IF (ch = NIL) OR (ch.state # OPEN) THEN done := TRUE END;
    WHILE ~done DO
        IF artPThread.Lock(ch.mutex) THEN
            IF ch.state # OPEN THEN
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSIF Queue.Count(ch.buffer) < ch.capacity THEN
                Queue.Enqueue(ch.buffer, item);
                ok := artPThread.Signal(ch.recvCond);
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSE
                ok := artPThread.Wait(ch.sendCond, ch.mutex);
                ok := artPThread.Unlock(ch.mutex)
            END
        END
    END
END Send;

(** Blocking receive - waits until message available or channel closed and empty *)
PROCEDURE Receive*(ch: Channel; VAR item: Collections.ItemPtr);
VAR done, ok: BOOLEAN;
BEGIN
    done := FALSE;
    item := NIL;
    IF ch = NIL THEN done := TRUE END;
    WHILE ~done DO
        IF artPThread.Lock(ch.mutex) THEN
            IF Queue.Count(ch.buffer) > 0 THEN
                Queue.Dequeue(ch.buffer, item);
                ok := artPThread.Signal(ch.sendCond);
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSIF ch.state = CLOSED THEN
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSE
                ok := artPThread.Wait(ch.recvCond, ch.mutex);
                ok := artPThread.Unlock(ch.mutex)
            END
        END
    END
END Receive;

(** Create and start a new thread *)
PROCEDURE NewThread*(proc: ThreadProc): Thread;
VAR t: Thread;
BEGIN
    NEW(t);
    t.proc := proc;
    t.thread := NIL;
    IF proc # NIL THEN
        t.thread := artPThread.NewThread(ThreadTrampoline, SYSTEM.VAL(INTEGER, proc))
    END;
    RETURN t
END NewThread;

(** Wait for thread to complete *)
PROCEDURE JoinThread*(thread: Thread): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
    ok := FALSE;
    IF (thread # NIL) & (thread.thread # NIL) THEN
        ok := artPThread.Join(thread.thread);
        (* Don't set thread.thread to NIL - let artPThread handle the state *)
    END;
    RETURN ok
END JoinThread;

PROCEDURE Init*();
END Init;

BEGIN
    Init();
END CSPThreads.
