{*******************************************************}
{                                                       }
{                       Log4Pascal                      }
{        https://github.com/martinusso/log4pascal       }
{                                                       }
{             This software is open source,             }
{       licensed under the The MIT License (MIT).       }
{                                                       }
{*******************************************************}

unit Log4Pascal;

interface

type
  TLogTypes = (ltTrace, ltDebug, ltInfo, ltWarning, ltError, ltFatal);

  { TLogger }

  TLogger = class
  private
    FDirectoryFileRotationHistory: String;
    FFileName: string;
    FKeepQuantity: Word;
    FIsInit: Boolean;
    FOutFile: TextFile;
    FMaxLogSizeInBytes: LongInt;
    FQuietMode: Boolean;
    FQuietTypes: set of TLogTypes;
    FUseLogRotation: Boolean;
    procedure Initialize;
    procedure CreateFoldersIfNecessary;
    function RotateLogFiles: Word;
    procedure Finalize;

    // TODO: Make it in Thread, and write asynchronously.
    //       That manner it will not impact in the system performance
    procedure Write(const Msg: string);
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;

    property FileName: string read FFileName;
    property KeepQuantity: Word read FKeepQuantity write FKeepQuantity;
    property UseLogRotation: Boolean read FUseLogRotation write FUseLogRotation;
    property MaxLogSizeInBytes: Longint read FMaxLogSizeInBytes write FMaxLogSizeInBytes;
    property DirectoryFileRotationHistory: String read FDirectoryFileRotationHistory write FDirectoryFileRotationHistory;

    procedure SetQuietMode;
    procedure DisableTraceLog;
    procedure DisableDebugLog;
    procedure DisableInfoLog;
    procedure DisableWarningLog;
    procedure DisableErrorLog;
    procedure DisableFatalLog;

    procedure SetNoisyMode;
    procedure EnableTraceLog;
    procedure EnableDebugLog;
    procedure EnableInfoLog;
    procedure EnableWarningLog;
    procedure EnableErrorLog;
    procedure EnableFatalLog;

    procedure Clear;

    procedure Trace(const Msg: string);
    procedure Debug(const Msg: string);
    procedure Info(const Msg: string);
    procedure Warning(const Msg: string);
    procedure Error(const Msg: string);
    procedure Fatal(const Msg: string);
  end;

var
  Logger: TLogger;

implementation

uses
  Forms,
  SysUtils,
  Windows,
  LConvEncoding;

const
  FORMAT_LOG = '%s %s';
  PREFIX_TRACE = '[TRACE]';
  PREFIX_DEBUG = '[DEBUG]';
  PREFIX_INFO  = '[INFO ]';
  PREFIX_WARN  = '[WARN ]';
  PREFIX_ERROR = '[ERROR]';
  PREFIX_FATAL = '[FATAL]';

{ TLogger }

procedure TLogger.Clear;
begin
  if not FileExists(FFileName) then
    Exit;

  if FIsInit then
    CloseFile(FOutFile);

  SysUtils.DeleteFile(FFileName);

  FIsInit := False;
end;

constructor TLogger.Create(const FileName: string);
var
  FullApplicationPath: string;
begin
  FFileName := FileName;
  FIsInit := False;
  Self.SetNoisyMode;
  FQuietTypes := [];

  FullApplicationPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  FDirectoryFileRotationHistory := IncludeTrailingPathDelimiter(FullApplicationPath + 'LogHistory');
  FKeepQuantity := 10;
  FMaxLogSizeInBytes := 10485760;
  FUseLogRotation := True;

end;
 
procedure TLogger.CreateFoldersIfNecessary;
var
  FilePath: string;
  FullApplicationPath: string;
begin
  FilePath := ExtractFilePath(FFileName);

  if Pos(':', FilePath) > 0 then
    ForceDirectories(FilePath)
  else
  begin
    FullApplicationPath := ExtractFilePath(Application.ExeName);
    ForceDirectories(IncludeTrailingPathDelimiter(FullApplicationPath) + FilePath);
  end;
end;

function TLogger.RotateLogFiles: Word;

  function _getFileSize(aFilePath: String): Int64;
  var F : File Of byte;
  begin
    Assign (F, aFilePath);
    Reset (F);
    Result := FileSize(F);
    Close (F);
  end;

  function _getRotationFileName(id: Integer): String;
  var
    FileName, FileExtension: String;
  begin
    FileName := ExtractFileName(FFileName);
    FileExtension := ExtractFileExt(FFileName);
    delete(FileName, length(FileExtension), length(FileName) - length(FileExtension)+1);
    Result := Format('%s%s_%s%s',
           [FDirectoryFileRotationHistory,
            FileName,
            IntToStr(id),
            FileExtension]);
  end;

var
  i: Integer;
  RotationFileName: String;
begin
  Result := 0;

  if (FMaxLogSizeInBytes > 0) and
     (FKeepQuantity > 0) and
     (_getFileSize(FFileName) > FMaxLogSizeInBytes) then
  begin

    try
      ForceDirectories(FDirectoryFileRotationHistory);

      i := FKeepQuantity;
      while (i >= 0) do
      begin
        RotationFileName := _getRotationFileName(i);
        if FileExists(RotationFileName) then
        begin
          if (i = FKeepQuantity) then
             if not DeleteFile(PChar(RotationFileName)) then
                break;

          if RenameFile(RotationFileName, _getRotationFileName(i+1)) then
            inc(Result);
        end;

        dec(i);
      end;

      if RenameFile(FFileName, _getRotationFileName(0)) then
         inc(Result);

    finally
      // indicate that not was possibled, or not necessary to renema the log files
      // so, is necessary to open file to continue with the log write
      if (Result = 0) then
        AssignFile(FOutFile, FFileName);
    end;
  end;
end;


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

destructor TLogger.Destroy;
begin
  Self.Finalize;
  inherited;
end;
 
procedure TLogger.DisableDebugLog;
begin
  Include(FQuietTypes, ltDebug);
end;

procedure TLogger.DisableErrorLog;
begin
  Include(FQuietTypes, ltError);
end;

procedure TLogger.DisableFatalLog;
begin
  Include(FQuietTypes, ltFatal);
end;

procedure TLogger.DisableInfoLog;
begin
  Include(FQuietTypes, ltInfo);
end;

procedure TLogger.DisableTraceLog;
begin
  Include(FQuietTypes, ltTrace);
end;

procedure TLogger.DisableWarningLog;
begin
  Include(FQuietTypes, ltWarning);
end;

procedure TLogger.EnableDebugLog;
begin
  Exclude(FQuietTypes, ltDebug);
end;

procedure TLogger.EnableErrorLog;
begin
  Exclude(FQuietTypes, ltError);
end;

procedure TLogger.EnableFatalLog;
begin
  Exclude(FQuietTypes, ltFatal);
end;

procedure TLogger.EnableInfoLog;
begin
  Exclude(FQuietTypes, ltInfo);
end;

procedure TLogger.EnableTraceLog;
begin
  Exclude(FQuietTypes, ltTrace);
end;

procedure TLogger.EnableWarningLog;
begin
  Exclude(FQuietTypes, ltWarning);
end;

procedure TLogger.Error(const Msg: string);
begin
  if not (ltError in FQuietTypes) then
    Self.Write(Format(FORMAT_LOG, [PREFIX_ERROR, Msg]));
end;

procedure TLogger.Fatal(const Msg: string);
begin
  if not (ltFatal in FQuietTypes) then
    Self.Write(Format(FORMAT_LOG, [PREFIX_FATAL, Msg]));
end;

procedure TLogger.Finalize;
begin
  if (FIsInit and (not FQuietMode)) then
    CloseFile(FOutFile);

  FIsInit := False;
end;
 
procedure TLogger.Initialize;
begin
  if FIsInit then
    CloseFile(FOutFile);

  if not FQuietMode then
  begin
    Self.CreateFoldersIfNecessary;
    
    AssignFile(FOutFile, FFileName);

    if not FileExists(FFileName) then
      Rewrite(FOutFile)
    else
    begin
      if (RotateLogFiles() > 0) then
      begin
        AssignFile(FOutFile, FFileName);
        Rewrite(FOutFile);
      end
      else
        Append(FOutFile);
    end;
  end;

  FIsInit := True;
end;
 
procedure TLogger.Info(const Msg: string);
begin
  if not (ltInfo in FQuietTypes) then
    Self.Write(Format(FORMAT_LOG, [PREFIX_INFO, Msg]));
end;
 
procedure TLogger.SetNoisyMode;
begin
  FQuietMode := False;
end;
 
procedure TLogger.SetQuietMode;
begin
  FQuietMode := True;
end;
 
procedure TLogger.Trace(const Msg: string);
begin
  if not (ltTrace in FQuietTypes) then
    Self.Write(Format(FORMAT_LOG, [PREFIX_TRACE, Msg]));
end;

procedure TLogger.Warning(const Msg: string);
begin
  if not (ltWarning in FQuietTypes) then
    Self.Write(Format(FORMAT_LOG, [PREFIX_WARN, Msg]));
end;
 
procedure TLogger.Write(const Msg: string);
const
  FORMAT_DATETIME_DEFAULT = 'yyyymmdd hh:nn:ss';
begin
  if FQuietMode then
    Exit;

  Self.Initialize;
  try
    if FIsInit then
      Writeln(FOutFile, Format('%s %s ', [FormatDateTime(FORMAT_DATETIME_DEFAULT, Now), Msg]));
  finally
    Self.Finalize;
  end;
end;


initialization
  Logger := TLogger.Create('Log.txt');

finalization
  Logger.Free;

end.
