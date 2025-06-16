(**
    ExampleDirChecksum.Mod -VAR
    dir: ARRAY MaxNameLen OF CHAR;
    res: INTEGER;
    ok: BOOLEAN;
    fileJobChan, resultChan: Channels.BufferedChannel;
    fileCount: INTEGER;
    worker1, worker2: CSPThreads.Thread;tory checksumming tool example
    Demonstrates: CSPThreads, CSPBufferedChannels, artDirent, CRC32, extArgs, Files, Out
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE ExampleDirChecksum;

IMPORT Out, extArgs, artDirent, Channels := CSPBufferedChannels, Chars, Collections, Files, CRC32, CSPThreads;

CONST
    UsageMsg = "Usage: ExampleDirChecksum <directory>";
    MaxNameLen = 256;
    FileJobBufSize = 16;
    ResultBufSize = 16;
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
    fileCount: INTEGER;
    worker1, worker2 : CSPThreads.Thread;
    ok : BOOLEAN;

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
    hasJob: BOOLEAN;
BEGIN
    REPEAT
        hasJob := Channels.TryReceive(fileJobChan, jobItem);
        IF hasJob & (jobItem # NIL) THEN
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
            
            Channels.Send(resultChan, result)
        END
    UNTIL ~hasJob & Channels.IsClosed(fileJobChan)
END WorkerThread;

PROCEDURE ScanDirectory(path: ARRAY OF CHAR; chan: Channels.BufferedChannel);
VAR
    scanner: artDirent.DirScanner;
    name: ARRAY MaxNameLen OF CHAR;
    isDir: BOOLEAN;
    job: FileJob;
    ok: BOOLEAN;
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
                Channels.Send(chan, job);
                Out.String("Queued file: "); Out.String(name); Out.Ln;
                fileCount := fileCount + 1
            END;
            ok := artDirent.NextEntry(scanner, name, isDir)
        END;
        artDirent.CloseScanner(scanner)
    ELSE
        Out.String("Failed to open directory: "); Out.String(path); Out.Ln
    END
END ScanDirectory;

PROCEDURE PrintResults(resChan: Channels.BufferedChannel; expectedCount: INTEGER);
VAR
    resultItem: Collections.ItemPtr;
    result: FileResult;
    count: INTEGER;
    hasResult: BOOLEAN;
BEGIN
    count := 0;
    WHILE count < expectedCount DO
        hasResult := Channels.TryReceive(resChan, resultItem);
        IF hasResult & (resultItem # NIL) THEN
            result := resultItem(FileResult);
            Out.String(result.name);
            Out.String(" ");
            IF result.success THEN
                Out.Hex(result.checksum)
            ELSE
                Out.String("?")
            END;
            Out.Ln;
            count := count + 1
        END
        (* Small delay to avoid busy waiting *)
    END
END PrintResults;

BEGIN
    IF extArgs.count < 1 THEN
        Out.String(UsageMsg); Out.Ln
    ELSE
        extArgs.Get(0, dir, res);
        Out.String("Scanning directory: "); Out.String(dir); Out.Ln;
        
        (* Set up channels *)
        fileJobChan := Channels.NewChannel(FileJobBufSize);
        resultChan := Channels.NewChannel(ResultBufSize);
        
        (* Scan directory and queue jobs first *)
        Out.String("Scanning files..."); Out.Ln;
        ScanDirectory(dir, fileJobChan);
        Out.String("Found "); Out.Int(fileCount, 0); Out.String(" files"); Out.Ln;
        
        (* Start worker threads *)
        Out.String("Starting "); Out.Int(NumWorkers, 0); Out.String(" worker threads..."); Out.Ln;
        worker1 := CSPThreads.NewThread(WorkerThread);
        worker2 := CSPThreads.NewThread(WorkerThread);
        
        (* Close job channel to signal workers to finish *)
        Channels.Close(fileJobChan);
        
        (* Wait for workers to complete *)
        Out.String("Waiting for workers to complete..."); Out.Ln;
        ok := CSPThreads.JoinThread(worker1);
        ok := CSPThreads.JoinThread(worker2);
        
        (* Collect and print results *)
        Out.String("Collecting results..."); Out.Ln;
        PrintResults(resultChan, fileCount);
        
        Out.String("Processing complete."); Out.Ln
    END
END ExampleDirChecksum.
