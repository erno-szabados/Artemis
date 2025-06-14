(**
    CSPThreadsTest.Mod - Tests for CSPThreads (threaded, concurrent CSP)
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE CSPThreadsTest;

IMPORT CSPThreads, CSPChannels, Collections, Tests, artPThread;

TYPE
    TestMessage = RECORD (Collections.Item)
        value: INTEGER
    END;
    TestMessagePtr = POINTER TO TestMessage;

VAR
    ts: Tests.TestSet;

PROCEDURE NewMessage(val: INTEGER): TestMessagePtr;
VAR msg: TestMessagePtr;
BEGIN
    NEW(msg);
    msg.value := val;
    RETURN msg
END NewMessage;

PROCEDURE TestBufferedChannelCreation*(): BOOLEAN;
VAR 
    ch: CSPChannels.BufferedChannel;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPChannels.NewBufferedChannel(0);
    Tests.ExpectedBool(FALSE, CSPChannels.IsBufferedClosed(ch), "New buffered channel should be open", pass);
    ch := CSPChannels.NewBufferedChannel(5);
    Tests.ExpectedBool(FALSE, CSPChannels.IsBufferedClosed(ch), "New buffered channel should be open", pass);
    CSPChannels.CloseBufferedChannel(ch);
    Tests.ExpectedBool(TRUE, CSPChannels.IsBufferedClosed(ch), "Closed buffered channel should report closed", pass);
    RETURN pass
END TestBufferedChannelCreation;

PROCEDURE TestNonBlockingOperations*(): BOOLEAN;
VAR 
    ch: CSPChannels.BufferedChannel;
    msg1, msg2: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPChannels.NewBufferedChannel(2);
    msg1 := NewMessage(42);
    msg2 := NewMessage(84);
    success := CSPChannels.TrySend(ch, msg1);
    Tests.ExpectedBool(TRUE, success, "Should send to empty buffer", pass);
    success := CSPChannels.TrySend(ch, msg2);
    Tests.ExpectedBool(TRUE, success, "Should send to buffer with space", pass);
    success := CSPChannels.TrySend(ch, NewMessage(126));
    Tests.ExpectedBool(FALSE, success, "Should not send to full buffer", pass);
    success := CSPChannels.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive from buffer", pass);
    Tests.ExpectedInt(42, result(TestMessagePtr).value, "Should receive first message", pass);
    success := CSPChannels.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive second message", pass);
    Tests.ExpectedInt(84, result(TestMessagePtr).value, "Should receive second message value", pass);
    success := CSPChannels.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty buffer", pass);
    RETURN pass
END TestNonBlockingOperations;

PROCEDURE TestBufferedChannel*(): BOOLEAN;
VAR 
    ch: CSPChannels.BufferedChannel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPChannels.NewBufferedChannel(0);
    msg := NewMessage(123);
    success := CSPChannels.TrySend(ch, msg);
    Tests.ExpectedBool(FALSE, success, "Should not send to buffered channel without receiver", pass);
    success := CSPChannels.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from buffered channel without sender", pass);
    RETURN pass
END TestBufferedChannel;

PROCEDURE TestThreadCreation*(): BOOLEAN;
VAR 
    thread: CSPThreads.Thread;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    thread := CSPThreads.NewThread(NIL);
    Tests.ExpectedBool(FALSE, thread # NIL, "Should not create thread with NIL procedure", pass);
    RETURN pass
END TestThreadCreation;

PROCEDURE SimpleThread();
BEGIN
    (* Simple thread that just returns *)
    artPThread.Sleep(1000);
END SimpleThread;

PROCEDURE TestThreadOperations*(): BOOLEAN;
VAR
    thread, thread2: CSPThreads.Thread;
    ok, pass: BOOLEAN;
BEGIN
    pass := TRUE;
    
    (* Test thread creation *)
    thread := CSPThreads.NewThread(SimpleThread);
    Tests.ExpectedBool(thread # NIL, TRUE, "Should create thread", pass);

    thread2 := CSPThreads.NewThread(SimpleThread);
    Tests.ExpectedBool(thread2 # NIL, TRUE, "Should create thread", pass);
    
    (* Test thread join *)
    ok := CSPThreads.JoinThread(thread);
    Tests.ExpectedBool(TRUE, ok, "Should join thread successfully", pass);
    
    (* Test thread join *)
    ok := CSPThreads.JoinThread(thread2);
    Tests.ExpectedBool(TRUE, ok, "Should join thread2 successfully", pass);

    (* Test join on NIL thread *)
    ok := CSPThreads.JoinThread(NIL);
    Tests.ExpectedBool(FALSE, ok, "JoinThread should fail on NIL thread", pass);
    
    RETURN pass
END TestThreadOperations;

PROCEDURE TestClosedBufferedChannel*(): BOOLEAN;
VAR 
    ch: CSPChannels.BufferedChannel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPChannels.NewBufferedChannel(1);
    msg := NewMessage(999);
    success := CSPChannels.TrySend(ch, msg);
    Tests.ExpectedBool(TRUE, success, "Should send before closing", pass);
    CSPChannels.CloseBufferedChannel(ch);
    success := CSPChannels.TrySend(ch, NewMessage(888));
    Tests.ExpectedBool(FALSE, success, "Should not send to closed buffered channel", pass);
    success := CSPChannels.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive buffered message from closed buffered channel", pass);
    Tests.ExpectedInt(999, result(TestMessagePtr).value, "Should receive correct value", pass);
    success := CSPChannels.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty closed buffered channel", pass);
    RETURN pass
END TestClosedBufferedChannel;

PROCEDURE TestChannelDestruction*(): BOOLEAN;
VAR ch: CSPChannels.BufferedChannel; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPChannels.NewBufferedChannel(2);
    Tests.ExpectedBool(FALSE, ch = NIL, "Buffered channel should be created", pass);
    CSPChannels.FreeBufferedChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Buffered channel should be NIL after FreeBufferedChannel", pass);
    RETURN pass
END TestChannelDestruction;

PROCEDURE TestSyncChannelCreation*(): BOOLEAN;
VAR 
    ch: CSPChannels.SyncChannel;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPChannels.NewSyncChannel();
    Tests.ExpectedBool(FALSE, CSPChannels.IsSyncClosed(ch), "New sync channel should be open", pass);
    CSPChannels.CloseSyncChannel(ch);
    Tests.ExpectedBool(TRUE, CSPChannels.IsSyncClosed(ch), "Closed sync channel should report closed", pass);
    CSPChannels.FreeSyncChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Sync channel should be NIL after free", pass);
    RETURN pass
END TestSyncChannelCreation;

PROCEDURE TestSyncChannelNonBlocking*(): BOOLEAN;
VAR 
    ch: CSPChannels.SyncChannel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPChannels.NewSyncChannel();
    msg := NewMessage(777);
    
    (* No receiver ready - should fail *)
    success := CSPChannels.TrySyncSend(ch, msg);
    Tests.ExpectedBool(FALSE, success, "Should not send without receiver ready", pass);
    
    (* No sender ready - should fail *)
    success := CSPChannels.TrySyncReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive without sender ready", pass);
    
    CSPChannels.FreeSyncChannel(ch);
    RETURN pass
END TestSyncChannelNonBlocking;

PROCEDURE TestSyncChannelRendezvous*(): BOOLEAN;
VAR 
    ch: CSPChannels.SyncChannel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPChannels.NewSyncChannel();
    msg := NewMessage(888);
    
    (* Verify that blocking operations would block without counterpart *)
    (* We can't easily test blocking directly in a simple test, but we can *)
    (* verify the non-blocking operations behave correctly *)
    
    (* Test 1: No operations succeed without counterpart *)
    success := CSPChannels.TrySyncSend(ch, msg);
    Tests.ExpectedBool(FALSE, success, "Sync send should fail without receiver", pass);
    
    success := CSPChannels.TrySyncReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Sync receive should fail without sender", pass);
    
    (* Test 2: Verify sync channel state after failed operations *)
    Tests.ExpectedBool(FALSE, CSPChannels.IsSyncClosed(ch), "Sync channel should remain open", pass);
    
    (* Test 3: Verify sync channel closure behavior *)
    CSPChannels.CloseSyncChannel(ch);
    Tests.ExpectedBool(TRUE, CSPChannels.IsSyncClosed(ch), "Sync channel should be closed", pass);
    
    success := CSPChannels.TrySyncSend(ch, msg);
    Tests.ExpectedBool(FALSE, success, "Should not send to closed sync channel", pass);
    
    success := CSPChannels.TrySyncReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from closed sync channel", pass);
    
    CSPChannels.FreeSyncChannel(ch);
    RETURN pass
END TestSyncChannelRendezvous;

BEGIN
    Tests.Init(ts, "CSPThreads Tests");
    Tests.Add(ts, TestBufferedChannelCreation);
    Tests.Add(ts, TestNonBlockingOperations);
    Tests.Add(ts, TestBufferedChannel);
    Tests.Add(ts, TestThreadCreation);
    Tests.Add(ts, TestThreadOperations);
    Tests.Add(ts, TestClosedBufferedChannel);
    Tests.Add(ts, TestChannelDestruction);
    Tests.Add(ts, TestSyncChannelCreation);
    Tests.Add(ts, TestSyncChannelNonBlocking);
    Tests.Add(ts, TestSyncChannelRendezvous);
    ASSERT(Tests.Run(ts));
END CSPThreadsTest.
