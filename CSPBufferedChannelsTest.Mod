(**
    CSPBufferedChannelsTest.Mod - Test suite for CSPBufferedChannels module
    
    Tests both buffered  channel functionality including:
    - Channel creation and resource management
    - Blocking and non-blocking operations
    - Channel closure behavior
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE CSPBufferedChannelsTest;

IMPORT Channels := CSPBufferedChannels, Collections, Tests;

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
    ch: Channels.BufferedChannel;
BEGIN
    pass := TRUE;
    
    ch := Channels.NewBufferedChannel(0);
    Tests.ExpectedBool(FALSE, Channels.IsBufferedClosed(ch), "New buffered channel should be open", pass);
    ch := Channels.NewBufferedChannel(5);
    Tests.ExpectedBool(FALSE, Channels.IsBufferedClosed(ch), "New buffered channel should be open", pass);
    Channels.CloseBufferedChannel(ch);
    Tests.ExpectedBool(TRUE, Channels.IsBufferedClosed(ch), "Closed buffered channel should report closed", pass);
    
    RETURN pass
END TestBufferedChannelCreation;

PROCEDURE TestBufferedChannelSynchronous*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: Channels.BufferedChannel;
    item1, item2, item3: TestItem;
    receivedItem: Collections.ItemPtr;
    receivedTestItem: TestItem;
    success: BOOLEAN;
BEGIN
    pass := TRUE;
    
    item1 := NewTestItem(1);
    item2 := NewTestItem(2);
    item3 := NewTestItem(3);
    
    ch := Channels.NewBufferedChannel(2);
    
    (* Test 1: Send to sync buffered channel should fail without receiver *)
    success := Channels.TrySend(ch, item1);
    Tests.ExpectedBool(TRUE, success, "Should send to buffered channel with capacity", pass);
    
    (* Test 2: Should be able to send another item *)
    success := Channels.TrySend(ch, item2);
    Tests.ExpectedBool(TRUE, success, "Should send second item to buffered channel", pass);
    
    (* Test 3: Third send should fail as buffer is full *)
    success := Channels.TrySend(ch, item3);
    Tests.ExpectedBool(FALSE, success, "Should not send to full buffered channel", pass);
    
    (* Test 4: Receive should work *)
    success := Channels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(TRUE, success, "Should receive from buffered channel", pass);
    IF success & (receivedItem # NIL) THEN
        receivedTestItem := receivedItem(TestItem);
        Tests.ExpectedInt(1, receivedTestItem.value, "Should receive first item", pass)
    END;
    
    (* Test 5: Should be able to receive second item *)
    success := Channels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(TRUE, success, "Should receive second item", pass);
    IF success & (receivedItem # NIL) THEN
        receivedTestItem := receivedItem(TestItem);
        Tests.ExpectedInt(2, receivedTestItem.value, "Should receive second item", pass)
    END;
    
    (* Test 6: Sync channel should fail without receiver *)
    ch := Channels.NewBufferedChannel(0);
    success := Channels.TrySend(ch, item1);
    Tests.ExpectedBool(FALSE, success, "Should not send to sync buffered channel without receiver", pass);
    success := Channels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(FALSE, success, "Should not receive from sync buffered channel without sender", pass);
    
    RETURN pass
END TestBufferedChannelSynchronous;

PROCEDURE TestBufferedChannelMemoryManagement*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: Channels.BufferedChannel;
BEGIN
    pass := TRUE;
    
    ch := Channels.NewBufferedChannel(5);
    Tests.ExpectedBool(FALSE, ch = NIL, "Buffered channel should be created", pass);
    Channels.FreeBufferedChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Buffered channel should be NIL after FreeBufferedChannel", pass);
    
    RETURN pass
END TestBufferedChannelMemoryManagement;

PROCEDURE TestClosedBufferedChannel*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: Channels.BufferedChannel;
    item: TestItem;
    receivedItem: Collections.ItemPtr;
    success: BOOLEAN;
BEGIN
    pass := TRUE;
    
    item := NewTestItem(42);
    ch := Channels.NewBufferedChannel(1);
    
    (* Send an item before closing *)
    success := Channels.TrySend(ch, item);
    Channels.CloseBufferedChannel(ch);
    
    (* Should not be able to send to closed channel *)
    success := Channels.TrySend(ch, item);
    Tests.ExpectedBool(FALSE, success, "Should not send to closed buffered channel", pass);
    (* Should be able to receive buffered message from closed channel *)
    success := Channels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(TRUE, success, "Should receive buffered message from closed buffered channel", pass);
    (* Should not receive from empty closed channel *)
    success := Channels.TryReceive(ch, receivedItem);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty closed buffered channel", pass);
    
    RETURN pass
END TestClosedBufferedChannel;

BEGIN
    Tests.Init(ts, "Buffered Channels Tests");
    Tests.Add(ts, TestBufferedChannelCreation);
    Tests.Add(ts, TestBufferedChannelSynchronous);
    Tests.Add(ts, TestBufferedChannelMemoryManagement);
    Tests.Add(ts, TestClosedBufferedChannel);
    ASSERT(Tests.Run(ts));

END CSPBufferedChannelsTest.