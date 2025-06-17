(**
    BufferedChannels.Mod - Thread-safe buffered channels for concurrent communication
    
    Provides:
    - Thread-safe buffered channels with blocking/non-blocking operations
    - Clean CSP-style communication primitives
    
    This module implements BUFFERED CHANNELS:
    - Fixed-capacity buffer with FIFO semantics
    - Non-blocking operations (TrySend/TryReceive) for immediate checks
    - Blocking operations (Send/Receive) for guaranteed delivery
    - Graceful closure with buffer draining
 
    Channels are intended to be thread-safe.
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE BufferedChannels;

IMPORT Collections, Queue, artPThread;

CONST
    OPEN* = 0;
    CLOSED* = 1;
    (* There is no ERROR state, as setting it would typically occur after threading errors,
       meaning the state could not be locked reliably, and would be prone to race conditions.
       We just acknowledge that the system can fail if the underlying pthread calls fail. *)

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
(*
   Buffered Channel Operations
   
   Buffered channels provide asynchronous communication with a fixed-size
   buffer. Senders can proceed immediately if buffer space is available,
   and receivers can get messages without waiting for senders.
*)

(** Free buffered channel resources - call when done with channel *)
PROCEDURE Free*(VAR ch: BufferedChannel);
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
END Free;

(** Create a new thread-safe buffered channel with specified buffer capacity
    Note: 0 capacity buffered channels are not allowed because they would break 
    CSP semantics. Use a CSPSyncChannel instead.
 *)
PROCEDURE NewChannel*(capacity: INTEGER): BufferedChannel;
VAR ch: BufferedChannel;
BEGIN
    ch := NIL;
    (* Capacity must be > 0 for buffered channels. Use CSPSyncChannel for synchronous communication. *)
    IF capacity > 0 THEN
        NEW(ch);
        ch.buffer := Queue.New();
        ch.capacity := capacity;
        ch.state := OPEN;
        ch.mutex := artPThread.NewMutex();
        ch.sendCond := artPThread.NewCondVar();
        ch.recvCond := artPThread.NewCondVar();
        
        (* Check if all resources were allocated successfully *)
        IF (ch.buffer = NIL) OR (ch.mutex = NIL) OR (ch.sendCond = NIL) OR (ch.recvCond = NIL) THEN
            Free(ch)
        END
    END;
    RETURN ch
END NewChannel;

(** Close a buffered channel - no more sends allowed, receives drain remaining messages 
  If Unlock fails, the error is ignored, as Close does not return a result.  
 *)
PROCEDURE Close*(ch: BufferedChannel);
VAR ok: BOOLEAN;
BEGIN
    IF (ch # NIL) & (ch.mutex # NIL) THEN
        ok := artPThread.Ok = artPThread.Lock(ch.mutex);
        IF ok THEN
            ch.state := CLOSED;
            (* Wake up any waiting receivers *)
            ok := artPThread.Ok = artPThread.Broadcast(ch.recvCond);
            (* Wake up any waiting senders *)
            ok := artPThread.Ok = artPThread.Broadcast(ch.sendCond);
            ok := artPThread.Ok = artPThread.Unlock(ch.mutex);
            IF ~ok THEN
                (* Unlock failure is critical - we cannot continue safely *)
            END
        ELSE
            (* Lock failure *)
        END
    END
END Close;

(** Lock free check to test if buffered channel is closed. 
    This may be stale, but subsequent operations will expose the state change.
    The behavior is consistent with CSP semantics. *)
PROCEDURE IsClosed*(ch: BufferedChannel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsClosed;

(** Non-blocking send - returns TRUE if message was sent, FALSE if buffer full or error*)
PROCEDURE TrySend*(ch: BufferedChannel; item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    IF (ch # NIL) & (item # NIL) & (ch.mutex # NIL) THEN
        ok := artPThread.Ok = artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF (ch.state = OPEN) & (Queue.Count(ch.buffer) < ch.capacity) THEN
                Queue.Enqueue(ch.buffer, item);
                ok := artPThread.Ok = artPThread.Signal(ch.recvCond);
                (* Signal failure doesn't prevent successful send *)
                result := TRUE
            END;
            ok := artPThread.Ok = artPThread.Unlock(ch.mutex);
            IF ~ok THEN
                (* Unlock failure is critical - we cannot continue safely *)
                result := FALSE
            END
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
    (* You can receive from a closed channel as long as there is data in it 
    - hence no state check here.*)
    IF (ch # NIL) & (ch.mutex # NIL) THEN
        ok := artPThread.Ok = artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF Queue.Count(ch.buffer) > 0 THEN
                Queue.Dequeue(ch.buffer, item);
                ok := artPThread.Ok = artPThread.Signal(ch.sendCond);
                (* Signal failure doesn't prevent successful receive *)
                result := TRUE
            END;
            ok := artPThread.Ok = artPThread.Unlock(ch.mutex);
            IF ~ok THEN
                (* Unlock failure is critical - we cannot continue safely *)
                result := FALSE
            END
        END
    END;
    RETURN result
END TryReceive;

(** Blocking send - waits until message can be sent or buffered channel is closed *)
PROCEDURE Send*(ch: BufferedChannel; item: Collections.ItemPtr);
VAR done, ok, canProceed, haveMutex: BOOLEAN;
BEGIN
    done := FALSE;
    haveMutex := FALSE;
    canProceed := (item # NIL) & (ch # NIL);
    
    IF canProceed & (ch.mutex # NIL) THEN
        ok := artPThread.Ok = artPThread.Lock(ch.mutex);
        haveMutex := ok;
        IF ok THEN
            canProceed := ch.state = OPEN;
        ELSE
            canProceed := FALSE
        END
    END;
    
    WHILE canProceed & ~done DO
        IF ch.state # OPEN THEN
            (* Channel closed - exit without sending *)
            done := TRUE
        ELSIF Queue.Count(ch.buffer) < ch.capacity THEN
            (* Buffer has space - send the message *)
            Queue.Enqueue(ch.buffer, item);
            ok := artPThread.Ok = artPThread.Signal(ch.recvCond);
            (* Signal failure is recoverable - ignore *)
            done := TRUE
        ELSE
            (* Buffer full - wait for space to become available *)
            (* Note: Wait may fail due to signals (EINTR) or other recoverable errors.
               We continue waiting unless we detect a fatal error pattern. *)
            ok := artPThread.Ok = artPThread.Wait(ch.sendCond, ch.mutex);
            (* After wait, re-check all conditions in next loop iteration.
               Even if wait failed due to signal interruption, we should retry
               as this is a blocking operation. Only exit on channel closure. *)
        END
    END;
    
    (* Always unlock if we have the mutex, regardless of how we got here *)
    IF haveMutex THEN
        ok := artPThread.Ok = artPThread.Unlock(ch.mutex);
        (* Unlock failure is critical but we have no way to report it *)
    END
END Send;

(** Blocking receive - waits until message available or buffered channel closed and empty *)
PROCEDURE Receive*(ch: BufferedChannel; VAR item: Collections.ItemPtr);
VAR done, ok, canProceed, haveMutex: BOOLEAN;
BEGIN
    done := FALSE;
    item := NIL;
    haveMutex := FALSE;
    (* You can receive from a closed channel as long as there is data in it 
    - hence no state check here.*)
    canProceed := (ch # NIL);
    
    IF canProceed & (ch.mutex # NIL) THEN
        ok := artPThread.Ok = artPThread.Lock(ch.mutex);
        haveMutex := ok;
        canProceed := ok
    END;
    
    WHILE canProceed & ~done DO
        IF Queue.Count(ch.buffer) > 0 THEN
            (* Buffer has data - receive the message *)
            Queue.Dequeue(ch.buffer, item);
            ok := artPThread.Ok = artPThread.Signal(ch.sendCond);
            (* Signal failure is recoverable - ignore *)
            done := TRUE
        ELSIF ch.state = CLOSED THEN
            (* Channel closed and buffer empty - exit without receiving *)
            done := TRUE
        ELSE
            (* Buffer empty and channel open - wait for data *)
            (* Note: Wait may fail due to signals (EINTR) or other recoverable errors.
               We continue waiting unless the channel is closed. Wait automatically 
               unlocks mutex, waits, then re-locks on wake. *)
            ok := artPThread.Ok = artPThread.Wait(ch.recvCond, ch.mutex);
            (* After wait, re-check all conditions in next loop iteration.
               Even if wait failed due to signal interruption, we should retry
               as this is a blocking operation. Only exit on channel closure. *)
        END
    END;
    
    (* Always unlock if we have the mutex, regardless of how we got here *)
    IF haveMutex THEN
        ok := artPThread.Ok = artPThread.Unlock(ch.mutex);
        (* Unlock failure is critical but we have no way to report it *)
    END
END Receive;

END BufferedChannels.
