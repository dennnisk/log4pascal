# Log4Pascal

Log4pascal is an Open Source project that aims to produce a simple logging unit for ObjectPascal (Delphi, FreePascal).

Log4Pascal is NOT based on the Log4J package from the Apache Software Foundation. Well, just the name.

## How to use

Just add the unit `Log4Pascal.pas` to project.
  - ``Project -> Add to Project`` and then locate and choose the file.

### Log file

The log file is defined in the unit Log4Pascal, so if you want to change, modify the following line:

```delphi
initialization
  Logger := TLogger.Create('Log.txt');
```

### Features

- Disable Logging.
  - `SetQuietMode();`
- Enable Logging. By default, logging is enabled.
  - `SetNoisyMode();`
- Enable or disable specific logs
  - `EnableTraceLog();` `EnableDebugLog();` `EnableInfoLog();` `EnableWarningLog();` `EnableErrorLog();` `EnableFatalLog();`
  - `DisableTraceLog();` `DisableDebugLog();` `DisableInfoLog();` `DisableWarningLog();` `DisableErrorLog();` `DisableFatalLog();`
- Clean up existing log file
  - `Clear();`
- Enable/Disable Log Rotatition files
  - `Logger.UseLogRotation := False`;
- Change Log file max site (MaxLogSizeInBytes)
  - `Logger.MaxLogSizeInBytes := 1048576; // Default 1Mb = 1.048.576 bytes`;
- Change log files that will be keept
  - `Logger.KeepQuantity := 10; // Default 10 files`;
- Change directory to file rotation history (Directory to keep the old log files)
  - `Logger.DirectoryFileRotationHistory := IncludeTrailingPathDelimiter(FullApplicationPath + 'LogHistory'); `;
  
##### Logs

```delphi
Logger.Trace('Trace message log');
Logger.Debug('Debug message log');
Logger.Info('Normal message log');
Logger.Warning('Warning message log');
Logger.Error('Error message log');
Logger.Fatal('Fatal message log');
```

###### Output

```txt
2023/05/30 15:00:26 [TRACE] Trace message log 
2023/05/30 15:00:26 [DEBUG] Debug message log
2023/05/30 15:00:26 [INFO ] Normal message log 
2023/05/30 15:00:26 [WARN ] Warning message log 
2023/05/30 15:00:26 [ERROR] Error message log 
2023/05/30 15:00:26 [FATAL] Fatal message log 
```

## Known bugs

### Free Pascal
Using Lazarus (Free Pascal) there were 1 errors compiling module:
`Identifier not found "DebugHook"`

So if you want to use the Log4Pascal in Free Pascal, you must delete (or replace) the following line found in Log4Pascal unit:
```Delphi
if DebugHook = 0 then Exit;
```

## License

This software is open source, licensed under the The MIT License (MIT). See [LICENSE](https://github.com/martinusso/log4pascal/blob/master/LICENSE) for details.
