(**
    CSPChannels.Mod - Thread-safe channels for CSP-style communication
    
    Provides:
    - Thread-safe buffered channels with blocking/non-blocking operations
    - Thread-safe synchronous channels for rendezvous communication
    - Clean CSP-style communication primitives
    
    This module implements two distinct channel types:
    
    BUFFERED CHANNELS:
    - Fixed-capacity buffer with FIFO semantics
    - Non-blocking operations (TrySend/TryReceive) for immediate checks
    - Blocking operations (Send/Receive) for guaranteed delivery
    - Graceful closure with buffer draining
    
    SYNCHRONOUS CHANNELS:
    - True CSP rendezvous semantics
    - Direct sender-to-receiver handoff with no buffering
    - Both parties must be ready simultaneously
    - Ideal for tightly coordinated communication patterns
    
    Both channel types are fully thread-safe and use efficient mutex/condition
    variable synchronization for optimal performance under contention.
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE CSPChannels;

IMPORT Collections, Queue, artPThread;

CONST
    OPEN* = 0;
    CLOSED* = 1;

TYPE
    (** Thread-safe buffered channel for message passing between threads *)
    BufferedChannel* = POINTER TO BufferedChannelDesc;
    BufferedChannelDesc = RECORD
        buffer: Queue.Queue;
        capacity: INTEGER;
        state: INTEGER;
        mutex: artPThread.Mutex;
        sendCond: artPThread.CondVar;
        recvCond: artPThread.CondVar
    END;

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

(*
   Buffered Channel Operations
   
   Buffered channels provide asynchronous communication with a fixed-size
   buffer. Senders can proceed immediately if buffer space is available,
   and receivers can get messages without waiting for senders.
*)

(** Free buffered channel resources - call when done with channel *)
PROCEDURE FreeBufferedChannel*(VAR ch: BufferedChannel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED;
        IF ch.buffer # NIL THEN 
            Queue.Free(ch.buffer)  (* Free the queue completely *)
        END;
        IF ch.mutex # NIL THEN artPThread.FreeMutex(ch.mutex) END;
        IF ch.sendCond # NIL THEN artPThread.FreeCondVar(ch.sendCond) END;
        IF ch.recvCond # NIL THEN artPThread.FreeCondVar(ch.recvCond) END;
        ch := NIL
    END
END FreeBufferedChannel;

(** Create a new thread-safe buffered channel with specified buffer capacity *)
PROCEDURE NewBufferedChannel*(capacity: INTEGER): BufferedChannel;
VAR ch: BufferedChannel;
BEGIN
    ch := NIL;
    IF capacity >= 0 THEN
        NEW(ch);
        ch.buffer := Queue.New();
        ch.capacity := capacity;
        ch.state := OPEN;
        ch.mutex := artPThread.NewMutex();
        ch.sendCond := artPThread.NewCondVar();
        ch.recvCond := artPThread.NewCondVar();
        
        (* Check if all resources were allocated successfully *)
        IF (ch.buffer = NIL) OR (ch.mutex = NIL) OR (ch.sendCond = NIL) OR (ch.recvCond = NIL) THEN
            FreeBufferedChannel(ch)
        END
    END;
    RETURN ch
END NewBufferedChannel;

(** Close a buffered channel - no more sends allowed, receives drain remaining messages *)
PROCEDURE CloseBufferedChannel*(ch: BufferedChannel);
VAR ok: BOOLEAN;
BEGIN
    IF ch # NIL THEN
        ok := artPThread.Lock(ch.mutex);
        IF ok THEN
            ch.state := CLOSED;
            (* Wake up any waiting receivers *)
            ok := artPThread.Broadcast(ch.recvCond);
            (* Wake up any waiting senders *)
            ok := artPThread.Broadcast(ch.sendCond);
            ok := artPThread.Unlock(ch.mutex)
        END
    END
END CloseBufferedChannel;

(** Check if buffered channel is closed *)
PROCEDURE IsBufferedClosed*(ch: BufferedChannel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsBufferedClosed;

(** Non-blocking send - returns TRUE if message was sent, FALSE if buffer full or error *)
PROCEDURE TrySend*(ch: BufferedChannel; item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN
        ok := artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF (ch.state = OPEN) & (Queue.Count(ch.buffer) < ch.capacity) THEN
                Queue.Enqueue(ch.buffer, item);
                ok := artPThread.Signal(ch.recvCond);
                (* Signal failure doesn't prevent successful send *)
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
            (* Unlock failure is critical - we cannot continue safely *)
        END
    END;
    RETURN result
END TrySend;

(** Non-blocking receive - returns TRUE if message received, FALSE if buffer empty or error *)
PROCEDURE TryReceive*(ch: BufferedChannel; VAR item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    item := NIL;
    IF ch # NIL THEN
        ok := artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF Queue.Count(ch.buffer) > 0 THEN
                Queue.Dequeue(ch.buffer, item);
                ok := artPThread.Signal(ch.sendCond);
                (* Signal failure doesn't prevent successful receive *)
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
            (* Unlock failure is critical - we cannot continue safely *)
        END
    END;
    RETURN result
END TryReceive;

(** Blocking send - waits until message can be sent or buffered channel is closed *)
PROCEDURE Send*(ch: BufferedChannel; item: Collections.ItemPtr);
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
        ELSIF Queue.Count(ch.buffer) < ch.capacity THEN
            Queue.Enqueue(ch.buffer, item);
            ok := artPThread.Signal(ch.recvCond);
            done := TRUE
        ELSE
            (* Wait automatically unlocks mutex, waits, then re-locks on wake *)
            ok := artPThread.Wait(ch.sendCond, ch.mutex);
            IF ~ok THEN 
                done := TRUE;
                canProceed := FALSE
            END
        END
    END;
    
    IF canProceed THEN
        ok := artPThread.Unlock(ch.mutex)
    END
END Send;

(** Blocking receive - waits until message available or buffered channel closed and empty *)
PROCEDURE Receive*(ch: BufferedChannel; VAR item: Collections.ItemPtr);
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
        IF Queue.Count(ch.buffer) > 0 THEN
            Queue.Dequeue(ch.buffer, item);
            ok := artPThread.Signal(ch.sendCond);
            done := TRUE
        ELSIF ch.state = CLOSED THEN
            done := TRUE
        ELSE
            (* Wait automatically unlocks mutex, waits, then re-locks on wake *)
            ok := artPThread.Wait(ch.recvCond, ch.mutex);
            IF ~ok THEN 
                done := TRUE;
                canProceed := FALSE
            END
        END
    END;
    
    IF canProceed THEN
        ok := artPThread.Unlock(ch.mutex)
    END
END Receive;

(** 
   Synchronous Channel Operations
   
   True CSP-style synchronous communication with rendezvous semantics.
   Sender and receiver block until both are ready, then handoff occurs directly.
 *)

(** Free synchronous channel resources *)
PROCEDURE FreeSyncChannel*(VAR ch: SyncChannel);
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
END FreeSyncChannel;

(** Close a synchronous channel - no more operations allowed *)
PROCEDURE CloseSyncChannel*(ch: SyncChannel);
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
END CloseSyncChannel;

(** Create a new synchronous channel for rendezvous communication *)
PROCEDURE NewSyncChannel*(): SyncChannel;
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
        FreeSyncChannel(ch)
    END;
    RETURN ch
END NewSyncChannel;

(** Check if synchronous channel is closed *)
PROCEDURE IsSyncClosed*(ch: SyncChannel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsSyncClosed;

(** Non-blocking synchronous send - returns TRUE only if receiver ready *)
PROCEDURE TrySyncSend*(ch: SyncChannel; item: Collections.ItemPtr): BOOLEAN;
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
END TrySyncSend;

(** Non-blocking synchronous receive - returns TRUE only if sender ready *)
PROCEDURE TrySyncReceive*(ch: SyncChannel; VAR item: Collections.ItemPtr): BOOLEAN;
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
END TrySyncReceive;

(** Blocking synchronous send - waits for receiver rendezvous *)
PROCEDURE SyncSend*(ch: SyncChannel; item: Collections.ItemPtr);
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
END SyncSend;

(** Blocking synchronous receive - waits for sender rendezvous *)
PROCEDURE SyncReceive*(ch: SyncChannel; VAR item: Collections.ItemPtr);
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
END SyncReceive;

END CSPChannels.
