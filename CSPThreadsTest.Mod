(**
    CSPThreadsTest.Mod - Tests for CSPThreads (threaded, concurrent CSP)
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE CSPThreadsTest;

IMPORT CSPThreads, Collections, Tests, artPThread;

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

PROCEDURE TestChannelCreation*(): BOOLEAN;
VAR 
    ch: CSPThreads.Channel;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPThreads.NewChannel(0);
    Tests.ExpectedBool(FALSE, CSPThreads.IsClosed(ch), "New channel should be open", pass);
    ch := CSPThreads.NewChannel(5);
    Tests.ExpectedBool(FALSE, CSPThreads.IsClosed(ch), "New buffered channel should be open", pass);
    CSPThreads.CloseChannel(ch);
    Tests.ExpectedBool(TRUE, CSPThreads.IsClosed(ch), "Closed channel should report closed", pass);
    RETURN pass
END TestChannelCreation;

PROCEDURE TestNonBlockingOperations*(): BOOLEAN;
VAR 
    ch: CSPThreads.Channel;
    msg1, msg2: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPThreads.NewChannel(2);
    msg1 := NewMessage(42);
    msg2 := NewMessage(84);
    success := CSPThreads.TrySend(ch, msg1);
    Tests.ExpectedBool(TRUE, success, "Should send to empty buffer", pass);
    success := CSPThreads.TrySend(ch, msg2);
    Tests.ExpectedBool(TRUE, success, "Should send to buffer with space", pass);
    success := CSPThreads.TrySend(ch, NewMessage(126));
    Tests.ExpectedBool(FALSE, success, "Should not send to full buffer", pass);
    success := CSPThreads.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive from buffer", pass);
    Tests.ExpectedInt(42, result(TestMessagePtr).value, "Should receive first message", pass);
    success := CSPThreads.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive second message", pass);
    Tests.ExpectedInt(84, result(TestMessagePtr).value, "Should receive second message value", pass);
    success := CSPThreads.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty buffer", pass);
    RETURN pass
END TestNonBlockingOperations;

PROCEDURE TestSynchronousChannel*(): BOOLEAN;
VAR 
    ch: CSPThreads.Channel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPThreads.NewChannel(0);
    msg := NewMessage(123);
    success := CSPThreads.TrySend(ch, msg);
    Tests.ExpectedBool(FALSE, success, "Should not send to sync channel without receiver", pass);
    success := CSPThreads.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from sync channel without sender", pass);
    RETURN pass
END TestSynchronousChannel;

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

PROCEDURE TestClosedChannel*(): BOOLEAN;
VAR 
    ch: CSPThreads.Channel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPThreads.NewChannel(1);
    msg := NewMessage(999);
    success := CSPThreads.TrySend(ch, msg);
    Tests.ExpectedBool(TRUE, success, "Should send before closing", pass);
    CSPThreads.CloseChannel(ch);
    success := CSPThreads.TrySend(ch, NewMessage(888));
    Tests.ExpectedBool(FALSE, success, "Should not send to closed channel", pass);
    success := CSPThreads.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive buffered message from closed channel", pass);
    Tests.ExpectedInt(999, result(TestMessagePtr).value, "Should receive correct value", pass);
    success := CSPThreads.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty closed channel", pass);
    RETURN pass
END TestClosedChannel;

PROCEDURE TestChannelDestruction*(): BOOLEAN;
VAR ch: CSPThreads.Channel; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPThreads.NewChannel(2);
    Tests.ExpectedBool(FALSE, ch = NIL, "Channel should be created", pass);
    CSPThreads.FreeChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Channel should be NIL after FreeChannel", pass);
    RETURN pass
END TestChannelDestruction;

PROCEDURE TestSyncChannelCreation*(): BOOLEAN;
VAR 
    ch: CSPThreads.SyncChannel;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPThreads.NewSyncChannel();
    Tests.ExpectedBool(FALSE, CSPThreads.IsSyncClosed(ch), "New sync channel should be open", pass);
    CSPThreads.CloseSyncChannel(ch);
    Tests.ExpectedBool(TRUE, CSPThreads.IsSyncClosed(ch), "Closed sync channel should report closed", pass);
    CSPThreads.FreeSyncChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Sync channel should be NIL after free", pass);
    RETURN pass
END TestSyncChannelCreation;

PROCEDURE TestSyncChannelNonBlocking*(): BOOLEAN;
VAR 
    ch: CSPThreads.SyncChannel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPThreads.NewSyncChannel();
    msg := NewMessage(777);
    
    (* No receiver ready - should fail *)
    success := CSPThreads.TrySyncSend(ch, msg);
    Tests.ExpectedBool(FALSE, success, "Should not send without receiver ready", pass);
    
    (* No sender ready - should fail *)
    success := CSPThreads.TrySyncReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive without sender ready", pass);
    
    CSPThreads.FreeSyncChannel(ch);
    RETURN pass
END TestSyncChannelNonBlocking;

BEGIN
    Tests.Init(ts, "CSPThreads Tests");
    Tests.Add(ts, TestChannelCreation);
    Tests.Add(ts, TestNonBlockingOperations);
    Tests.Add(ts, TestSynchronousChannel);
    Tests.Add(ts, TestThreadCreation);
    Tests.Add(ts, TestThreadOperations);
    Tests.Add(ts, TestClosedChannel);
    Tests.Add(ts, TestChannelDestruction);
    Tests.Add(ts, TestSyncChannelCreation);
    Tests.Add(ts, TestSyncChannelNonBlocking);
    ASSERT(Tests.Run(ts));
END CSPThreadsTest.
