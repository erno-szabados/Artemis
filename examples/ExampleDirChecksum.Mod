(**
    ExampleDirChecksum.Mod -VAR
    dir: ARRAY MaxNameLen OF CHAR;
    res: INTEGER;
    ok: BOOLEAN;
    fileJobChan, resultChan: Channels.BufferedChannel;
    fileCount: INTEGER;
    worker1, worker2: CSPThreads.Thread;tory checksumming tool example
    Demonstrates: Threads, BufferedChannels, artDirent, CRC32, extArgs, Files, Out
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE ExampleDirChecksum;

IMPORT Out, extArgs, artDirent, Channels := BufferedChannels, Chars, Collections, Files, CRC32, Threads, artPThread;

CONST
    UsageMsg = "Usage: ExampleDirChecksum <directory>";
    MaxNameLen = 256;
    FileJobBufSize = 2;   (* Reduced to force contention *)
    ResultBufSize = 2;    (* Reduced to force contention *)
    NumWorkers = 2;
    ReadBufSize = 4096;

TYPE
    FileJob = POINTER TO FileJobDesc;
    FileJobDesc = RECORD (Collections.Item)
        name: ARRAY MaxNameLen OF CHAR
    END;

    FileResult = POINTER TO FileResultDesc;
    FileResultDesc = RECORD (Collections.Item)
        name: ARRAY MaxNameLen OF CHAR;
        success: BOOLEAN;
        checksum: INTEGER
    END;

VAR
    dir: ARRAY MaxNameLen OF CHAR;
    res: INTEGER;
    fileJobChan, resultChan: Channels.BufferedChannel;
    worker1, worker2, collector : Threads.Thread;
    debugMode: BOOLEAN;
    ok: BOOLEAN;  (* Local to main procedure only *)
    (* The allocator in obnc is probably not thread-safe - we try to play nice here. *)
    printMutex : artPThread.Mutex;

(* Thread-safe debug logging *)
PROCEDURE DebugLog(msg: ARRAY OF CHAR);
VAR ok: BOOLEAN;
BEGIN
    IF debugMode THEN
        (* ok := artPThread.Lock(printMutex); *)
        (* Out.String("[DEBUG] "); Out.String(msg); Out.Ln; *)
        (* ok := artPThread.Unlock(printMutex) *)
    END
END DebugLog;

PROCEDURE PrintResult(result : FileResult);
VAR ok: BOOLEAN;
BEGIN
    ok := artPThread.Ok = artPThread.Lock(printMutex);
    Out.String("[INFO] "); 
        Out.String(result.name);
        Out.String(" ");
        IF result.success THEN
            Out.Hex(result.checksum)
        ELSE
            Out.String("?")
        END;
        Out.Ln;
    ok := artPThread.Ok = artPThread.Unlock(printMutex)
END PrintResult;


PROCEDURE WorkerThread();
VAR
    jobItem: Collections.ItemPtr;
    job: FileJob;
    result: FileResult;
    file: Files.File;
    rider: Files.Rider;
    buffer: ARRAY ReadBufSize OF BYTE;
    bytesRead, i: INTEGER;
    calc: CRC32.Calculator;
    jobsProcessed: INTEGER;
    ok : BOOLEAN;
BEGIN
    jobsProcessed := 0;
    REPEAT
        ok := Channels.Receive(fileJobChan, jobItem);
        IF jobItem # NIL THEN
            IF jobItem IS FileJob THEN
                job := jobItem(FileJob);
                NEW(result);
                result.name[0] := 0X;
                Chars.Append(job.name, result.name);
                
                file := Files.Old(job.name);
                IF file # NIL THEN
                    Files.Set(rider, file, 0);
                    calc := CRC32.NewCalculator();
                    CRC32.Init(calc);
                    
                    WHILE ~rider.eof DO
                        Files.ReadBytes(rider, buffer, ReadBufSize);
                        bytesRead := ReadBufSize - rider.res;
                        FOR i := 0 TO bytesRead - 1 DO
                            CRC32.UpdateByte(calc, buffer[i])
                        END
                    END;
                    
                    result.success := TRUE;
                    result.checksum := CRC32.Finalize(calc);
                    Files.Close(file)
                ELSE
                    result.success := FALSE;
                    result.checksum := 0
                END;
                
                ok := Channels.Send(resultChan, result);
                jobsProcessed := jobsProcessed + 1
            ELSE
                IF debugMode THEN
                    DebugLog("[W2] Received non-FileJob item!");
                END
            END
        END
    UNTIL jobItem = NIL;
    IF debugMode THEN
        DebugLog("[W] Finished, processed jobs.");
    END
END WorkerThread;

PROCEDURE ScanDirectory(path: ARRAY OF CHAR; chan: Channels.BufferedChannel);
VAR
    scanner: artDirent.DirScanner;
    name: ARRAY MaxNameLen OF CHAR;
    isDir: BOOLEAN;
    job: FileJob;
    ok: BOOLEAN;
    fileCount: INTEGER;
BEGIN
    fileCount := 0;
    scanner := artDirent.OpenScanner(path);
    IF scanner # NIL THEN
        ok := artDirent.NextEntry(scanner, name, isDir);
        WHILE ok DO
            IF ~isDir THEN
                NEW(job);
                job.name[0] := 0X;
                Chars.Append(name, job.name);
                ok := Channels.Send(chan, job);
                fileCount := fileCount + 1
            END;
            ok := artDirent.NextEntry(scanner, name, isDir)
        END;
        artDirent.CloseScanner(scanner)
    ELSE
        (* DebugLog("Failed to open directory: "); *)
    END
END ScanDirectory;

(* Add this procedure to monitor channel states *)
PROCEDURE CheckChannelStates();
VAR ok: BOOLEAN;
BEGIN
    ok := artPThread.Ok = artPThread.Lock(printMutex);
    Out.String("[CHAN] fileJobChan closed: ");
    IF Channels.IsClosed(fileJobChan) THEN
        Out.String("YES")
    ELSE
        Out.String("NO")
    END;
    Out.String(", resultChan closed: ");
    IF Channels.IsClosed(resultChan) THEN
        Out.String("YES")
    ELSE
        Out.String("NO")
    END;
    Out.Ln;
    ok := artPThread.Ok = artPThread.Unlock(printMutex)
END CheckChannelStates;

PROCEDURE ResultCollectorThread();
VAR
    resultItem: Collections.ItemPtr;
    result: FileResult;
    count: INTEGER;
    ok: BOOLEAN;
BEGIN
    count := 0;
    REPEAT
        ok := Channels.Receive(resultChan, resultItem);
        IF resultItem # NIL THEN
            IF resultItem IS FileResult THEN
                result := resultItem(FileResult);
                PrintResult(result);
                count := count + 1
            ELSE
                DebugLog("Error: Received non-FileResult item in resultChan");
            END
        END
    UNTIL resultItem = NIL;
    DebugLog("Collected results"); 
END ResultCollectorThread;

BEGIN

    IF extArgs.count < 1 THEN
        Out.String(UsageMsg); Out.Ln
    ELSE
        extArgs.Get(0, dir, res);
        (* DebugLog("Scanning directory..."); *)
        
        (* Enable debug mode for stress testing *)
        debugMode := TRUE;
        printMutex := artPThread.NewMutex();
        
        (* DebugLog("Initializing channels..."); *)
        
        (* Set up channels with small buffers to force contention *)
        fileJobChan := Channels.NewChannel(FileJobBufSize);
        resultChan := Channels.NewChannel(ResultBufSize);
        
        (* DebugLog("Channels created successfully"); *)
        
        (* Start worker threads AND result collector BEFORE queuing jobs *)
        (* DebugLog("Starting worker threads..."); Out.Ln; *)
        worker1 := Threads.NewThread(WorkerThread);
        worker2 := Threads.NewThread(WorkerThread);
        
        (* DebugLog("Starting result collector thread..."); *)
        collector := Threads.NewThread(ResultCollectorThread);
        
        (* Now scan directory and queue jobs *)
        (* DebugLog("Scanning files..."); *)
        ScanDirectory(dir, fileJobChan);
        (* DebugLog("Found files"); *)
        
        (* Close job channel to signal workers to finish *)
        ok := Channels.Close(fileJobChan);
        
        (* Wait for workers to complete *)
        (* DebugLog("Waiting for workers to complete..."); *)
        (* CheckChannelStates(); *)

        ok := Threads.JoinThread(worker1);
        (* DebugLog("Worker 1 joined"); *)
        ok := Threads.JoinThread(worker2);
        (* DebugLog("Worker 2 joined"); *)
        
        (* Close result channel to signal collector to finish *)
        ok := Channels.Close(resultChan);
        (* CheckChannelStates(); *)

        (* Wait for collector to finish *)
        (* DebugLog("Waiting for result collector to complete...");  *)
        ok := Threads.JoinThread(collector);
        (* DebugLog("Collector joined"); *)

        (* DebugLog("Processing complete."); *)
    END
END ExampleDirChecksum.
