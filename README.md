# Log4Pascal-Simple

Log4pascal-Simple is an Open Source project that aims to produce a simple logging unit for ObjectPascal (Lazarus, Delphi, etc), with log rotation files.

Log4Pascal is NOT based on the Log4J package from the Apache Software Foundation. Well, just the name.

This software if based on https://github.com/martinusso/log4pascal project.

## How to use

Just add the unit `Log4Pascal.pas` to your project.
  - ``Project -> Add to Project`` and then locate and choose the file.

### Log file

The log file is defined in the unit Log4Pascal, so if you want to change, modify the following line:

```delphi
initialization
  Logger := TLogger.Create('app.log');
```

Or, comment and initialize it manually.

### Features

- Enable/Disable Log Rotatition files
  - `Logger.UseLogRotation := False`;
  - File log will append a number at the end of the file name, like: `mylog_0.log`, `mylog_1.log`, `mylog_2.log` ...
- Change Log file max site (MaxLogSizeInBytes)
  - `Logger.MaxLogSizeInBytes := 1048576; // Default 1Mb = 1.048.576 bytes`;
- Change log files that will be keept
  - `Logger.KeepQuantity := 10; // Default 10 files`;
- Change directory to file rotation history (Directory to keep the old log files)
  - `Logger.DirectoryFileRotationHistory := IncludeTrailingPathDelimiter(FullApplicationPath + 'LogHistory'); `;
  - Default is the path `LogHistory` directory under `.exe` file
    
  
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

Using Lazarus (Free Pascal) there were 1 errors compiling module: `Identifier not found "DebugHook"` :: **This is solved in this project (Removed).**

To maintein the code, just uncomment the following lines in the `Debug()` Method:
```Delphi
procedure TLogger.Debug(const Msg: string);
//function IsDebuggerPresent(): integer stdcall; external 'kernel32.dll';
begin
  {$WARN SYMBOL_PLATFORM OFF}
  //if IsDebuggerPresent > 0 then
//    Exit;
  {$WARN SYMBOL_PLATFORM ON}

  if not (ltDebug in FQuietTypes) then
    Self.Write(Format(FORMAT_LOG, [PREFIX_DEBUG, Msg]));
end;  
```

## License

This software is open source, licensed under the The MIT License (MIT). See [LICENSE](https://github.com/martinusso/log4pascal/blob/master/LICENSE) for details.
