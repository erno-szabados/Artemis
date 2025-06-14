(**
    CSPSyncChannels.Mod - Thread-safe channels for CSP-style communication
    
    Provides:
    - Thread-safe synchronous channels for rendezvous communication
    - Clean CSP-style communication primitives
    
    This module implements SYNCHRONOUS CHANNELS:
    - True CSP rendezvous semantics
    - Direct sender-to-receiver handoff with no buffering
    - Both parties must be ready simultaneously
    - Ideal for tightly coordinated communication patterns
    
    Channels are intended to be thread-safe.
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE CSPSyncChannels;

IMPORT Collections, artPThread;

CONST
    OPEN* = 0;
    CLOSED* = 1;

TYPE
    (** Thread-safe synchronous channel for rendezvous communication *)
    SyncChannel* = POINTER TO SyncChannelDesc;
    SyncChannelDesc = RECORD
        state: INTEGER;
        mutex: artPThread.Mutex;
        sendCond: artPThread.CondVar;
        recvCond: artPThread.CondVar;
        (* Rendezvous state *)
        pendingItem: Collections.ItemPtr;  (* Item waiting for handoff *)
        senderWaiting: BOOLEAN;            (* TRUE if sender is blocked *)
        receiverWaiting: BOOLEAN           (* TRUE if receiver is blocked *)
    END;

(** 
   Synchronous Channel Operations
   
   True CSP-style synchronous communication with rendezvous semantics.
   Sender and receiver block until both are ready, then handoff occurs directly.
 *)

(** Free synchronous channel resources *)
PROCEDURE Free*(VAR ch: SyncChannel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED;
        ch.pendingItem := NIL;
        ch.senderWaiting := FALSE;
        ch.receiverWaiting := FALSE;
        IF ch.mutex # NIL THEN artPThread.FreeMutex(ch.mutex) END;
        IF ch.sendCond # NIL THEN artPThread.FreeCondVar(ch.sendCond) END;
        IF ch.recvCond # NIL THEN artPThread.FreeCondVar(ch.recvCond) END;
        ch := NIL
    END
END Free;

(** Close a synchronous channel - no more operations allowed *)
PROCEDURE Close*(ch: SyncChannel);
VAR ok: BOOLEAN;
BEGIN
    IF ch # NIL THEN
        ok := artPThread.Lock(ch.mutex);
        IF ok THEN
            ch.state := CLOSED;
            (* Wake up any waiting threads *)
            ok := artPThread.Broadcast(ch.sendCond);
            ok := artPThread.Broadcast(ch.recvCond);
            ok := artPThread.Unlock(ch.mutex)
        END
    END
END Close;

(** Create a new synchronous channel for rendezvous communication *)
PROCEDURE New*(): SyncChannel;
VAR ch: SyncChannel;
BEGIN
    ch := NIL;
    NEW(ch);
    ch.state := OPEN;
    ch.mutex := artPThread.NewMutex();
    ch.sendCond := artPThread.NewCondVar();
    ch.recvCond := artPThread.NewCondVar();
    ch.pendingItem := NIL;
    ch.senderWaiting := FALSE;
    ch.receiverWaiting := FALSE;
    
    (* Check if all resources were allocated successfully *)
    IF (ch.mutex = NIL) OR (ch.sendCond = NIL) OR (ch.recvCond = NIL) THEN
        Free(ch)
    END;
    RETURN ch
END New;

(** Check if synchronous channel is closed *)
PROCEDURE IsClosed*(ch: SyncChannel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsClosed;

(** Non-blocking synchronous send - returns TRUE only if receiver ready *)
PROCEDURE TrySend*(ch: SyncChannel; item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN
        ok := artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF (ch.state = OPEN) & ch.receiverWaiting & ~ch.senderWaiting THEN
                (* Direct handoff to waiting receiver *)
                ch.pendingItem := item;
                ch.senderWaiting := FALSE;
                ch.receiverWaiting := FALSE;
                ok := artPThread.Signal(ch.recvCond);
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
        END
    END;
    RETURN result
END TrySend;

(** Non-blocking synchronous receive - returns TRUE only if sender ready *)
PROCEDURE TryReceive*(ch: SyncChannel; VAR item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    item := NIL;
    IF ch # NIL THEN
        ok := artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF (ch.state = OPEN) & ch.senderWaiting & ~ch.receiverWaiting THEN
                (* Direct handoff from waiting sender *)
                item := ch.pendingItem;
                ch.pendingItem := NIL;
                ch.senderWaiting := FALSE;
                ch.receiverWaiting := FALSE;
                ok := artPThread.Signal(ch.sendCond);
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
        END
    END;
    RETURN result
END TryReceive;

(** Blocking synchronous send - waits for receiver rendezvous *)
PROCEDURE Send*(ch: SyncChannel; item: Collections.ItemPtr);
VAR done, ok, canProceed: BOOLEAN;
BEGIN
    done := FALSE;
    canProceed := (ch # NIL) & (ch.state = OPEN);
    
    IF canProceed THEN
        ok := artPThread.Lock(ch.mutex);
        canProceed := ok
    END;
    
    WHILE canProceed & ~done DO
        IF ch.state # OPEN THEN
            done := TRUE
        ELSIF ch.receiverWaiting & ~ch.senderWaiting THEN
            (* Receiver is waiting - direct handoff *)
            ch.pendingItem := item;
            ch.senderWaiting := FALSE;
            ch.receiverWaiting := FALSE;
            ok := artPThread.Signal(ch.recvCond);
            done := TRUE
        ELSE
            (* No receiver ready - wait for one *)
            ch.senderWaiting := TRUE;
            ch.pendingItem := item;
            ok := artPThread.Wait(ch.sendCond, ch.mutex);
            IF ~ok THEN 
                ch.senderWaiting := FALSE;
                ch.pendingItem := NIL;
                done := TRUE;
                canProceed := FALSE
            ELSIF ~ch.receiverWaiting THEN
                (* Woke up but no receiver - someone else got it *)
                ch.senderWaiting := FALSE;
                ch.pendingItem := NIL;
                done := TRUE
            END
        END
    END;
    
    IF canProceed THEN
        ok := artPThread.Unlock(ch.mutex)
    END
END Send;

(** Blocking synchronous receive - waits for sender rendezvous *)
PROCEDURE Receive*(ch: SyncChannel; VAR item: Collections.ItemPtr);
VAR done, ok, canProceed: BOOLEAN;
BEGIN
    done := FALSE;
    item := NIL;
    canProceed := ch # NIL;
    
    IF canProceed THEN
        ok := artPThread.Lock(ch.mutex);
        canProceed := ok
    END;
    
    WHILE canProceed & ~done DO
        IF ch.state = CLOSED THEN
            done := TRUE
        ELSIF ch.senderWaiting & ~ch.receiverWaiting THEN
            (* Sender is waiting - direct handoff *)
            item := ch.pendingItem;
            ch.pendingItem := NIL;
            ch.senderWaiting := FALSE;
            ch.receiverWaiting := FALSE;
            ok := artPThread.Signal(ch.sendCond);
            done := TRUE
        ELSE
            (* No sender ready - wait for one *)
            ch.receiverWaiting := TRUE;
            ok := artPThread.Wait(ch.recvCond, ch.mutex);
            IF ~ok THEN 
                ch.receiverWaiting := FALSE;
                done := TRUE;
                canProceed := FALSE
            ELSIF ~ch.senderWaiting THEN
                (* Woke up but no sender - someone else got it *)
                ch.receiverWaiting := FALSE;
                done := TRUE
            END
        END
    END;
    
    IF canProceed THEN
        ok := artPThread.Unlock(ch.mutex)
    END
END Receive;

END CSPSyncChannels.
