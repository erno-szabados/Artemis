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

PROCEDURE TestProcessCreation*(): BOOLEAN;
VAR 
    proc: CSPThreads.Process;
    sched: CSPThreads.Scheduler;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    proc := CSPThreads.NewProcess(NIL);
    Tests.ExpectedBool(proc # NIL, TRUE, "Should create process", pass);
    sched := CSPThreads.NewScheduler();
    Tests.ExpectedBool(sched # NIL, TRUE, "Should create scheduler", pass);
    CSPThreads.AddProcess(sched, proc);
    RETURN pass
END TestProcessCreation;

PROCEDURE SimpleProcess();
BEGIN
END SimpleProcess;

PROCEDURE TestProcessExecution*(): BOOLEAN;
VAR 
    proc: CSPThreads.Process;
    sched: CSPThreads.Scheduler;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    sched := CSPThreads.NewScheduler();
    proc := CSPThreads.NewProcess(SimpleProcess);
    CSPThreads.AddProcess(sched, proc);
    CSPThreads.Run(sched);
    Tests.ExpectedBool(TRUE, TRUE, "Process execution completed", pass);
    RETURN pass
END TestProcessExecution;

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

PROCEDURE JoinableProcess();
BEGIN
    artPThread.Sleep(100)
END JoinableProcess;

PROCEDURE TestProcessJoin*(): BOOLEAN;
VAR
    proc: CSPThreads.Process;
    ok, pass: BOOLEAN;
BEGIN
    pass := TRUE;
    proc := CSPThreads.NewProcess(JoinableProcess);
    ok := CSPThreads.JoinProcess(proc);
    Tests.ExpectedBool(TRUE, ok, "JoinProcess should succeed", pass);
    ok := CSPThreads.JoinProcess(proc);
    Tests.ExpectedBool(FALSE, ok, "JoinProcess should fail on already joined process", pass);
    RETURN pass
END TestProcessJoin;

BEGIN
    Tests.Init(ts, "CSPThreads Tests");
    Tests.Add(ts, TestChannelCreation);
    Tests.Add(ts, TestNonBlockingOperations);
    Tests.Add(ts, TestSynchronousChannel);
    Tests.Add(ts, TestProcessCreation);
    Tests.Add(ts, TestProcessExecution);
    Tests.Add(ts, TestClosedChannel);
    Tests.Add(ts, TestChannelDestruction);
    Tests.Add(ts, TestProcessJoin);
    ASSERT(Tests.Run(ts));
END CSPThreadsTest.
