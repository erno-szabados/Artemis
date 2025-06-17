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
    Returns TRUE if channel was successfully closed, FALSE on error *)
PROCEDURE Close*(ch: BufferedChannel) : BOOLEAN;
VAR success: BOOLEAN; lockResult, unlockResult: INTEGER;
BEGIN
    success := FALSE;
    IF (ch # NIL) & (ch.mutex # NIL) THEN
        lockResult := artPThread.Lock(ch.mutex);
        IF lockResult = artPThread.Ok THEN
            ch.state := CLOSED;
            (* Wake up any waiting receivers - ignore broadcast failures as they're recoverable *)
            lockResult := artPThread.Broadcast(ch.recvCond);
            (* Wake up any waiting senders - ignore broadcast failures as they're recoverable *)
            lockResult := artPThread.Broadcast(ch.sendCond);
            success := TRUE;
            
            unlockResult := artPThread.Unlock(ch.mutex);
            (* Note: We preserve success even if unlock fails, as the close operation *)
            (* itself succeeded. Unlock failure indicates a system problem. *)
        ELSIF (lockResult = artPThread.OwnerDead) OR (lockResult = artPThread.NotRecoverable) THEN
            (* Fatal mutex errors - cannot proceed, but also cannot recover *)
            success := FALSE
        ELSE
            (* Other lock failures (deadlock, invalid handle, etc.) *)
            success := FALSE
        END
    END;
    RETURN success
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

(** Non-blocking send - returns TRUE if message was sent, FALSE if buffer full or error *)
PROCEDURE TrySend*(ch: BufferedChannel; item: Collections.ItemPtr): BOOLEAN;
VAR success: BOOLEAN; tryLockResult, unlockResult: INTEGER;
BEGIN
    success := FALSE;
    IF (ch # NIL) & (item # NIL) & (ch.mutex # NIL) THEN
        tryLockResult := artPThread.TryLock(ch.mutex);
        IF tryLockResult = artPThread.Ok THEN
            IF (ch.state = OPEN) & (Queue.Count(ch.buffer) < ch.capacity) THEN
                Queue.Enqueue(ch.buffer, item);
                (* Signal failure doesn't prevent successful send - ignore result *)
                tryLockResult := artPThread.Signal(ch.recvCond);
                success := TRUE
            END;
            unlockResult := artPThread.Unlock(ch.mutex);
            (* Preserve success state even if unlock fails *)
        ELSIF tryLockResult = artPThread.Busy THEN
            (* Mutex busy - this is expected for non-blocking operation *)
            success := FALSE
        ELSE
            (* Other failures (invalid handle, owner dead, etc.) *)
            success := FALSE
        END
    END;
    RETURN success
END TrySend;

(** Non-blocking receive - returns TRUE if message received, FALSE if buffer empty or error *)
PROCEDURE TryReceive*(ch: BufferedChannel; VAR item: Collections.ItemPtr): BOOLEAN;
VAR success: BOOLEAN; tryLockResult, unlockResult: INTEGER;
BEGIN
    success := FALSE;
    item := NIL;
    (* You can receive from a closed channel as long as there is data in it *)
    IF (ch # NIL) & (ch.mutex # NIL) THEN
        tryLockResult := artPThread.TryLock(ch.mutex);
        IF tryLockResult = artPThread.Ok THEN
            IF Queue.Count(ch.buffer) > 0 THEN
                Queue.Dequeue(ch.buffer, item);
                (* Signal failure doesn't prevent successful receive - ignore result *)
                tryLockResult := artPThread.Signal(ch.sendCond);
                success := TRUE
            END;
            unlockResult := artPThread.Unlock(ch.mutex);
            (* Preserve success state even if unlock fails *)
        ELSIF tryLockResult = artPThread.Busy THEN
            (* Mutex busy - this is expected for non-blocking operation *)
            success := FALSE
        ELSE
            (* Other failures (invalid handle, owner dead, etc.) *)
            success := FALSE
        END
    END;
    RETURN success
END TryReceive;

(** Blocking send - waits until message can be sent or buffered channel is closed 
    Returns TRUE if message was successfully sent, FALSE on failure or channel closed *)
PROCEDURE Send*(ch: BufferedChannel; item: Collections.ItemPtr) : BOOLEAN;
VAR done, success, canProceed, haveMutex: BOOLEAN; lockResult, waitResult, unlockResult: INTEGER;
BEGIN
    success := FALSE;
    done := FALSE;
    haveMutex := FALSE;
    canProceed := (item # NIL) & (ch # NIL);
    
    IF canProceed & (ch.mutex # NIL) THEN
        lockResult := artPThread.Lock(ch.mutex);
        IF lockResult = artPThread.Ok THEN
            haveMutex := TRUE;
            canProceed := ch.state = OPEN
        ELSIF (lockResult = artPThread.OwnerDead) OR (lockResult = artPThread.NotRecoverable) THEN
            (* Fatal mutex errors - cannot proceed safely *)
            canProceed := FALSE
        ELSE
            (* Other lock failures (deadlock, invalid handle, etc.) *)
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
            (* Signal receivers - failure is recoverable, operation still succeeded *)
            waitResult := artPThread.Signal(ch.recvCond);
            success := TRUE;
            done := TRUE
        ELSE
            (* Buffer full - wait for space to become available *)
            waitResult := artPThread.Wait(ch.sendCond, ch.mutex);
            IF waitResult = artPThread.Ok THEN
                (* Successful wait - continue loop to re-check conditions *)
                (* Note: Spurious wakeups are handled by re-evaluating loop conditions *)
            ELSIF (waitResult = artPThread.OwnerDead) OR (waitResult = artPThread.NotRecoverable) THEN
                (* Fatal mutex state errors - cannot continue safely *)
                canProceed := FALSE;
                (* Note: haveMutex remains TRUE as we still need to attempt unlock *)
                (* even though the mutex may be in an inconsistent state *)
            ELSIF waitResult = artPThread.NotOwner THEN
                (* Programming error - should not happen if implementation is correct *)
                canProceed := FALSE
            ELSE
                (* Other wait failures - may be recoverable, continue waiting *)
                (* This handles interruptions and other transient errors *)
            END
        END
    END;
    
    (* Always attempt unlock if we acquired the mutex *)
    IF haveMutex THEN
        unlockResult := artPThread.Unlock(ch.mutex);
        (* Note: Even if unlock fails, we preserve the success state of the send operation *)
        (* Unlock failure indicates a serious system problem but doesn't invalidate *)
        (* a successful message send that already occurred *)
    END;
    
    RETURN success
END Send;

(** Blocking receive - waits until message available or buffered channel closed and empty 
    Returns TRUE if message was successfully received, FALSE on failure or channel closed and empty *)
PROCEDURE Receive*(ch: BufferedChannel; VAR item: Collections.ItemPtr) : BOOLEAN;
VAR done, success, canProceed, haveMutex: BOOLEAN; lockResult, waitResult, unlockResult: INTEGER;
BEGIN
    success := FALSE;
    done := FALSE;
    item := NIL;
    haveMutex := FALSE;
    (* You can receive from a closed channel as long as there is data in it *)
    canProceed := (ch # NIL);
    
    IF canProceed & (ch.mutex # NIL) THEN
        lockResult := artPThread.Lock(ch.mutex);
        IF lockResult = artPThread.Ok THEN
            haveMutex := TRUE
        ELSIF (lockResult = artPThread.OwnerDead) OR (lockResult = artPThread.NotRecoverable) THEN
            (* Fatal mutex errors - cannot proceed safely *)
            canProceed := FALSE
        ELSE
            (* Other lock failures (deadlock, invalid handle, etc.) *)
            canProceed := FALSE
        END
    END;
    
    WHILE canProceed & ~done DO
        IF Queue.Count(ch.buffer) > 0 THEN
            (* Buffer has data - receive the message *)
            Queue.Dequeue(ch.buffer, item);
            (* Signal senders - failure is recoverable, operation still succeeded *)
            waitResult := artPThread.Signal(ch.sendCond);
            success := TRUE;
            done := TRUE
        ELSIF ch.state = CLOSED THEN
            (* Channel closed and buffer empty - exit without receiving *)
            done := TRUE
        ELSE
            (* Buffer empty and channel open - wait for data *)
            waitResult := artPThread.Wait(ch.recvCond, ch.mutex);
            IF waitResult = artPThread.Ok THEN
                (* Successful wait - continue loop to re-check conditions *)
                (* Note: Spurious wakeups are handled by re-evaluating loop conditions *)
            ELSIF (waitResult = artPThread.OwnerDead) OR (waitResult = artPThread.NotRecoverable) THEN
                (* Fatal mutex state errors - cannot continue safely *)
                canProceed := FALSE;
                (* Note: haveMutex remains TRUE as we still need to attempt unlock *)
                (* even though the mutex may be in an inconsistent state *)
            ELSIF waitResult = artPThread.NotOwner THEN
                (* Programming error - should not happen if implementation is correct *)
                canProceed := FALSE
            ELSE
                (* Other wait failures - may be recoverable, continue waiting *)
                (* This handles interruptions and other transient errors *)
            END
        END
    END;
    
    (* Always attempt unlock if we acquired the mutex *)
    IF haveMutex THEN
        unlockResult := artPThread.Unlock(ch.mutex);
        (* Note: Even if unlock fails, we preserve the success state of the receive operation *)
        (* Unlock failure indicates a serious system problem but doesn't invalidate *)
        (* a successful message receive that already occurred *)
    END;
    
    RETURN success
END Receive;

END BufferedChannels.
