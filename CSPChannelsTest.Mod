(**
    CSPChannelsTest.Mod - Test suite for CSPChannels module
    
    Tests both buffered and synchronous channel functionality including:
    - Channel creation and resource management
    - Blocking and non-blocking operations
    - Channel closure behavior
    - Synchronous rendezvous semantics
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE CSPChannelsTest;

IMPORT CSPChannels, Collections, Tests;

TYPE
    TestItem = POINTER TO TestItemDesc;
    TestItemDesc = RECORD (Collections.Item)
        value: INTEGER
    END;

VAR ts: Tests.TestSet;

PROCEDURE NewTestItem(value: INTEGER): TestItem;
VAR item: TestItem;
BEGIN
    NEW(item);
    item.value := value;
    RETURN item
END NewTestItem;

PROCEDURE TestBufferedChannelCreation*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: CSPChannels.BufferedChannel;
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

PROCEDURE TestBufferedChannelSynchronous*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: CSPChannels.BufferedChannel;
    item1, item2, item3: TestItem;
    receivedItem: Collections.ItemPtr;
    receivedTestItem: TestItem;
    success: BOOLEAN;
BEGIN
    pass := TRUE;
    
    item1 := NewTestItem(1);
    item2 := NewTestItem(2);
    item3 := NewTestItem(3);
    
    ch := CSPChannels.NewBufferedChannel(2);
    
    (* Test 1: Send to sync buffered channel should fail without receiver *)
    success := CSPChannels.TrySend(ch, item1);
    Tests.ExpectedBool(TRUE, success, "Should send to buffered channel with capacity", pass);
    
    (* Test 2: Should be able to send another item *)
    success := CSPChannels.TrySend(ch, item2);
    Tests.ExpectedBool(TRUE, success, "Should send second item to buffered channel", pass);
    
    (* Test 3: Third send should fail as buffer is full *)
    success := CSPChannels.TrySend(ch, item3);
    Tests.ExpectedBool(FALSE, success, "Should not send to full buffered channel", pass);
    
    (* Test 4: Receive should work *)
    success := CSPChannels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(TRUE, success, "Should receive from buffered channel", pass);
    IF success & (receivedItem # NIL) THEN
        receivedTestItem := receivedItem(TestItem);
        Tests.ExpectedInt(1, receivedTestItem.value, "Should receive first item", pass)
    END;
    
    (* Test 5: Should be able to receive second item *)
    success := CSPChannels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(TRUE, success, "Should receive second item", pass);
    IF success & (receivedItem # NIL) THEN
        receivedTestItem := receivedItem(TestItem);
        Tests.ExpectedInt(2, receivedTestItem.value, "Should receive second item", pass)
    END;
    
    (* Test 6: Sync channel should fail without receiver *)
    ch := CSPChannels.NewBufferedChannel(0);
    success := CSPChannels.TrySend(ch, item1);
    Tests.ExpectedBool(FALSE, success, "Should not send to sync buffered channel without receiver", pass);
    success := CSPChannels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(FALSE, success, "Should not receive from sync buffered channel without sender", pass);
    
    RETURN pass
END TestBufferedChannelSynchronous;

PROCEDURE TestBufferedChannelMemoryManagement*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: CSPChannels.BufferedChannel;
BEGIN
    pass := TRUE;
    
    ch := CSPChannels.NewBufferedChannel(5);
    Tests.ExpectedBool(FALSE, ch = NIL, "Buffered channel should be created", pass);
    CSPChannels.FreeBufferedChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Buffered channel should be NIL after FreeBufferedChannel", pass);
    
    RETURN pass
END TestBufferedChannelMemoryManagement;

PROCEDURE TestClosedBufferedChannel*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: CSPChannels.BufferedChannel;
    item: TestItem;
    receivedItem: Collections.ItemPtr;
    success: BOOLEAN;
BEGIN
    pass := TRUE;
    
    item := NewTestItem(42);
    ch := CSPChannels.NewBufferedChannel(1);
    
    (* Send an item before closing *)
    success := CSPChannels.TrySend(ch, item);
    CSPChannels.CloseBufferedChannel(ch);
    
    (* Should not be able to send to closed channel *)
    success := CSPChannels.TrySend(ch, item);
    Tests.ExpectedBool(FALSE, success, "Should not send to closed buffered channel", pass);
    (* Should be able to receive buffered message from closed channel *)
    success := CSPChannels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(TRUE, success, "Should receive buffered message from closed buffered channel", pass);
    (* Should not receive from empty closed channel *)
    success := CSPChannels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty closed buffered channel", pass);
    
    RETURN pass
END TestClosedBufferedChannel;

PROCEDURE TestSyncChannelCreation*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: CSPChannels.SyncChannel;
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
VAR pass: BOOLEAN;
    ch: CSPChannels.SyncChannel;
    item: TestItem;
    receivedItem: Collections.ItemPtr;
    success: BOOLEAN;
BEGIN
    pass := TRUE;
    
    item := NewTestItem(99);
    ch := CSPChannels.NewSyncChannel();
    
    (* Test 1: Non-blocking operations should fail when no partner ready *)
    success := CSPChannels.TrySyncSend(ch, item);
    Tests.ExpectedBool(FALSE, success, "Should not send without receiver ready", pass);
    
    success := CSPChannels.TrySyncReceive(ch, receivedItem);
    Tests.ExpectedBool(FALSE, success, "Should not receive without sender ready", pass);
    
    (* Test 2: Verify sync channel state after failed operations *)
    Tests.ExpectedBool(FALSE, CSPChannels.IsSyncClosed(ch), "Sync channel should remain open", pass);
    
    (* Test 3: Verify sync channel closure behavior *)
    CSPChannels.CloseSyncChannel(ch);
    Tests.ExpectedBool(TRUE, CSPChannels.IsSyncClosed(ch), "Sync channel should be closed", pass);
    
    (* Test 4: Operations should fail on closed sync channel *)
    success := CSPChannels.TrySyncSend(ch, item);
    Tests.ExpectedBool(FALSE, success, "Should not send to closed sync channel", pass);
    
    success := CSPChannels.TrySyncReceive(ch, receivedItem);
    Tests.ExpectedBool(FALSE, success, "Should not receive from closed sync channel", pass);
    
    CSPChannels.FreeSyncChannel(ch);
    
    RETURN pass
END TestSyncChannelNonBlocking;

BEGIN
    Tests.Init(ts, "CSPChannels Tests");
    Tests.Add(ts, TestBufferedChannelCreation);
    Tests.Add(ts, TestBufferedChannelSynchronous);
    Tests.Add(ts, TestBufferedChannelMemoryManagement);
    Tests.Add(ts, TestClosedBufferedChannel);
    Tests.Add(ts, TestSyncChannelCreation);
    Tests.Add(ts, TestSyncChannelNonBlocking);
    ASSERT(Tests.Run(ts));

END CSPChannelsTest.