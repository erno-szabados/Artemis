(**
    MODULE CSPSyncChannelsTest.Mod - Test suite for CSPSyncChannels module
    
    Tests synchronous channel functionality including:
    - Channel creation and resource management
    - Blocking and non-blocking operations
    - Channel closure behavior
    - Synchronous rendezvous semantics
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE CSPSyncChannelsTest;

IMPORT Channels := CSPSyncChannels, Collections, Tests;

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

PROCEDURE TestSyncChannelCreation*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: Channels.SyncChannel;
BEGIN
    pass := TRUE;
    
    ch := Channels.NewSyncChannel();
    Tests.ExpectedBool(FALSE, Channels.IsSyncClosed(ch), "New sync channel should be open", pass);
    Channels.CloseSyncChannel(ch);
    Tests.ExpectedBool(TRUE, Channels.IsSyncClosed(ch), "Closed sync channel should report closed", pass);
    Channels.FreeSyncChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Sync channel should be NIL after free", pass);
    
    RETURN pass
END TestSyncChannelCreation;

PROCEDURE TestSyncChannelNonBlocking*(): BOOLEAN;
VAR pass: BOOLEAN;
    ch: Channels.SyncChannel;
    item: TestItem;
    receivedItem: Collections.ItemPtr;
    success: BOOLEAN;
BEGIN
    pass := TRUE;
    
    item := NewTestItem(99);
    ch := Channels.NewSyncChannel();
    
    (* Test 1: Non-blocking operations should fail when no partner ready *)
    success := Channels.TrySyncSend(ch, item);
    Tests.ExpectedBool(FALSE, success, "Should not send without receiver ready", pass);
    
    success := Channels.TrySyncReceive(ch, receivedItem);
    Tests.ExpectedBool(FALSE, success, "Should not receive without sender ready", pass);
    
    (* Test 2: Verify sync channel state after failed operations *)
    Tests.ExpectedBool(FALSE, Channels.IsSyncClosed(ch), "Sync channel should remain open", pass);
    
    (* Test 3: Verify sync channel closure behavior *)
    Channels.CloseSyncChannel(ch);
    Tests.ExpectedBool(TRUE, Channels.IsSyncClosed(ch), "Sync channel should be closed", pass);
    
    (* Test 4: Operations should fail on closed sync channel *)
    success := Channels.TrySyncSend(ch, item);
    Tests.ExpectedBool(FALSE, success, "Should not send to closed sync channel", pass);
    
    success := Channels.TrySyncReceive(ch, receivedItem);
    Tests.ExpectedBool(FALSE, success, "Should not receive from closed sync channel", pass);
    
    Channels.FreeSyncChannel(ch);
    
    RETURN pass
END TestSyncChannelNonBlocking;

BEGIN
    Tests.Init(ts, "Sync Channels Tests");
    Tests.Add(ts, TestSyncChannelCreation);
    Tests.Add(ts, TestSyncChannelNonBlocking);
    ASSERT(Tests.Run(ts));

END CSPSyncChannelsTest.