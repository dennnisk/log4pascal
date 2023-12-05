{*******************************************************}
{                                                       }
{                   Log4Pascal-Simple                   }
{    https://github.com/dennnisk/log4pascal-simple      }
{                                                       }
{             This software is open source,             }
{       licensed under the The MIT License (MIT).       }
{                                                       }
{  Font Base: https://github.com/martinusso/log4pascal  }
{                                                       }
{*******************************************************}

unit Log4Pascal;

interface

{$mode objfpc}{$H+}
uses
  {$ifdef unix}
  cthreads,
  cmem, // the c memory manager is on some systems much faster for multi-threading
  {$endif}
  sysutils, classes, Forms, Windows, LConvEncoding, Math;


type
  TLogTypes = (ltTrace, ltDebug, ltInfo, ltWarning, ltError, ltFatal);


  { TLogWriter }

  TLogWriter = class
  private
    FMaxLogSizeInBytes: LongInt;
    FKeepQuantity: Word;
    FFileName: String;
    FFullFileName: String;
    FDirectoryFileRotationHistory: String;
    FFullApplicationPath: String;
    FUseLogRotation: Boolean;
    FS: TFileStream;
    procedure CreateFoldersIfNecessary(const AFileName: String);
    function RotateLogFiles(): Word;
    procedure initFileStream(AppendIfExists, ArquivoExiste: Boolean);
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;

    function WriteToTXT(const ABinaryString: AnsiString;
      const AppendIfExists: Boolean = true; const AddLineBreak: Boolean = true;
      const ForceDirectory: Boolean = true): Boolean;

    property FileName: string read FFileName;
    property KeepQuantity: Word read FKeepQuantity write FKeepQuantity;
    property UseLogRotation: Boolean read FUseLogRotation write FUseLogRotation;
    property MaxLogSizeInBytes: Longint read FMaxLogSizeInBytes write FMaxLogSizeInBytes;
    property DirectoryFileRotationHistory: String read FDirectoryFileRotationHistory write FDirectoryFileRotationHistory;

    procedure writeErrorOnLogTempFile(aErroMsg: String);

  end;

  { TThreadLogWriter }

  TThreadLogWriter = class(TThread)
  private
    fTermineted: Boolean;
    fStringList: TStringList;
    fLogWriter: TLogWriter;
    fCriticalSection : TRTLCriticalSection;
  protected
    procedure Execute; override;
    procedure Terminate;
  public
    Constructor Create(logWriter : TLogWriter);
    destructor Destroy; override;
    procedure addLog(AString: String);
  end;


  { TLogger }
  TLogger = class
  private
    FFullApplicationPath: String;
    FDirectoryFileRotationHistory: String;
    FFileName: string;
    FKeepQuantity: Word;
    FIsInit: Boolean;
    FOutFile: TextFile;
    FMaxLogSizeInBytes: LongInt;
    FQuietMode: Boolean;
    FQuietTypes: set of TLogTypes;
    FUseLogRotation: Boolean;
    FLogWriter: TLogWriter;
    FThreadLogWriter: TThreadLogWriter;

    procedure Initialize;
    procedure CreateFoldersIfNecessary;
    procedure Finalize;

    // TODO: Make it in Thread, and write asynchronously.
    //       That manner it will not impact in the system performance
    procedure Write(const Msg: string);

  public
    constructor Create(const FileName: string; AUseThread: Boolean = True);
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
  Logger4Pascal: TLogger;

implementation

const
  FORMAT_LOG = '%s %s';
  PREFIX_TRACE = '[TRACE]';
  PREFIX_DEBUG = '[DEBUG]';
  PREFIX_INFO  = '[INFO ]';
  PREFIX_WARN  = '[WARN ]';
  PREFIX_ERROR = '[ERROR]';
  PREFIX_FATAL = '[FATAL]';

{ TLogWriter }

function TLogWriter.RotateLogFiles(): Word;

  function _getFileSize(aFilePath: String): Int64;
  var F : File Of byte;
  begin
    // Need to read the size of the file from the open one, or, open it to read.
    if (Assigned(FS)) then
    begin
       Result := FS.Size;
    end
    else
    begin
      Assign (F, aFilePath);
      Reset (F);
      Result := FileSize(F);
      Close (F);
    end;
  end;

  function _getRotationFileName(id: Integer; extraFileName: string = ''): String;
  var
    FileName, FileExtension: String;
  begin
    FileName := ExtractFileName(FFileName);
    FileExtension := ExtractFileExt(FFileName);
    FileName := StringReplace(FileName, FileExtension, '', []);
    Result := Format('%s%s_%s%s%s',
           [FDirectoryFileRotationHistory,
            FileName,
            IntToStr(id),
            extraFileName,
            FileExtension]);
  end;

var
  i: Integer;
  RotationFileName: String;
begin
  Result := 0;

  try
    if (FMaxLogSizeInBytes > 0) and
       (FKeepQuantity > 0) and
       (_getFileSize(FFileName) > FMaxLogSizeInBytes) then
    begin
      ForceDirectories(FDirectoryFileRotationHistory);

      // Remove the last file rotation, if can`t rotate, just rename it..
      RotationFileName := _getRotationFileName(FKeepQuantity);
      if FileExists(RotationFileName) then
      begin
         if not DeleteFile(PChar(RotationFileName)) then
         begin
           RenameFile(RotationFileName, _getRotationFileName(999, '_deleteBlocked_' + FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', now)));
         end;
      end;

      i := FKeepQuantity;
      while (i >= 0) do
      begin
        RotationFileName := _getRotationFileName(i);
        if FileExists(RotationFileName) then
        begin
          if RenameFile(RotationFileName, _getRotationFileName(i+1)) then
            inc(Result);
        end;

        dec(i);
      end;

      FS.Free;
      FS := nil;

      RotationFileName := _getRotationFileName(0);
      if MoveFile(PChar(FFileName), PChar(RotationFileName)) then
         inc(Result);

      initFileStream(true, false);

    end;
  except
    on e: Exception do
    begin
      writeErrorOnLogTempFile(e.Message + #13#10 + e.ToString);
    end;
  end;
end;

procedure TLogWriter.initFileStream(AppendIfExists, ArquivoExiste: Boolean);
begin
  //
  try
    FS := TFileStream.Create(FFullFileName,
          IfThen(AppendIfExists and ArquivoExiste,
                     Integer(fmOpenReadWrite), Integer(fmCreate)) or fmShareDenyWrite);
  except
    on e: Exception do
    begin
      writeErrorOnLogTempFile(e.Message + #13#10 + e.ToString);
    end;
  end;
end;

constructor TLogWriter.Create(const FileName: string);
begin
  FFileName := FileName;
  FFullApplicationPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  FFullFileName := FFullApplicationPath + FFileName;
  FDirectoryFileRotationHistory := IncludeTrailingPathDelimiter(FFullApplicationPath + 'LogHistory');
  FKeepQuantity := 10;
  FMaxLogSizeInBytes := 5242880;  // 1Mb = 1.048.576 bytes || 5Mb = 5.242.880 bytes
  FUseLogRotation := True;
end;

destructor TLogWriter.Destroy;
begin
  FS.Free;
  inherited Destroy;
end;


procedure TLogWriter.CreateFoldersIfNecessary(const AFileName: String);
var
  FilePath: string;
  FullApplicationPath: string;
begin
  FilePath := ExtractFilePath(AFileName);

  if Pos(':', FilePath) > 0 then
    ForceDirectories(FilePath)
  else
  begin
    FullApplicationPath := ExtractFilePath(Application.ExeName);
    ForceDirectories(IncludeTrailingPathDelimiter(FullApplicationPath) + FilePath);
  end;
end;

function TLogWriter.WriteToTXT(const ABinaryString: AnsiString;
  const AppendIfExists: Boolean; const AddLineBreak: Boolean;
  const ForceDirectory: Boolean): Boolean;
var
  //FS: TFileStream;
  LineBreak: AnsiString;
  VDirectory: String;
  ArquivoExiste: Boolean;
begin
  Result := False;
  try
    if FFullFileName = EmptyStr then
      Exit;

    ArquivoExiste := FileExists(FFullFileName);

    if ArquivoExiste then
    begin
      if not (Length(ABinaryString) = 0) then
        RotateLogFiles();
    end
    else
    begin
      if ForceDirectory then
      begin
        VDirectory := ExtractFileDir(FFullFileName);
        if (EmptyStr = VDirectory) and (not DirectoryExists(VDirectory)) then
          ForceDirectories(VDirectory);
      end;
    end;

    if (not Assigned(FS)) then
       initFileStream(AppendIfExists, ArquivoExiste);

    try
      FS.Seek(0, soEnd);  // vai para EOF
      FS.Write(Pointer(ABinaryString)^,Length(ABinaryString));

      if AddLineBreak then
      begin
        LineBreak := sLineBreak;
        FS.Write(Pointer(LineBreak)^,Length(LineBreak));
      end;
    finally
      //FS.Free;
    end;

    Result := True;
  except
    on e: Exception do
    begin
      writeErrorOnLogTempFile(e.Message + #13#10 + e.ToString);
    end;
    // Just do Nothing
  end;
end;

procedure TLogWriter.writeErrorOnLogTempFile(aErroMsg: String);
var
  guid: TGuid;
  AuxStrList: TStringList;
begin
  if CreateGUID(guid) = 0 then
  begin
    AuxStrList := TStringList.Create;
    ForceDirectories(IncludeTrailingPathDelimiter(FFullApplicationPath) + 'logFileLocked');
    AuxStrList.Add('------- ERROR '+FormatDateTime('yyyy/mm/dd hh:nn:ss.zzz', now)+' -------');
    AuxStrList.Add(aErroMsg);
    AuxStrList.SaveToFile(IncludeTrailingPathDelimiter(FFullApplicationPath) + 'logFileLocked\' + FormatDateTime('yy-mm-dd_hhnnss', now) + GUIDToString(guid));
    AuxStrList.Free;
  end;
end;


{ TThreadLogWriter }

procedure TThreadLogWriter.Execute;
var
  AuxStrList: TStringList;

  procedure _writeLogToDisk();

  var
    i: Integer;
    GravouLogs: Boolean;
  begin
    AuxStrList.Clear;

    // Copia o texto para gravar em disco e libera a lista para novas adicoes
    EnterCriticalSection(fCriticalSection);
    Try
      AuxStrList.Text := fStringList.Text;
      fStringList.Clear;
    Finally
      LeaveCriticalSection(fCriticalSection);
    end;

    // Força gravar em disco no arquivo configurado, ou, no arquivo quebra galho...
    GravouLogs := True;
    try
      //for i:=0 to AuxStrList.Count-1 do
      GravouLogs := ((GravouLogs = True) and (fLogWriter.WriteToTXT(AuxStrList.Text) = true));

      if (not GravouLogs) then
        fLogWriter.writeErrorOnLogTempFile('Erro sem identificação.');

    except
      // Em caso de falha, para não perder o LOG, cria um arquivo separado com o Log
      on e: Exception do
      begin
        fLogWriter.writeErrorOnLogTempFile(e.Message);
      end;
    end;
  end;

begin

  AuxStrList := TStringList.Create;

  while ((not Application.Terminated) and (not fTermineted)) do
  begin
    sleep(100);

    if (fStringList.Count > 0) then
      _writeLogToDisk();
  end;

  AuxStrList.Free;
end;

procedure TThreadLogWriter.Terminate;
begin
  //
  fTermineted := true;
end;

constructor TThreadLogWriter.Create(logWriter: TLogWriter);
begin
  inherited Create(false);

  fTermineted := false;
  fLogWriter := logWriter;
  InitCriticalSection(fCriticalSection);
  fStringList := TStringList.Create;
end;

destructor TThreadLogWriter.Destroy;
begin
  DoneCriticalSection(fCriticalSection);
  fStringList.Free;
  inherited Destroy;
end;

procedure TThreadLogWriter.addLog(AString: String);
begin
  EnterCriticalSection(fCriticalSection);
  Try
    fStringList.Add(AString);
  Finally
    LeaveCriticalSection(fCriticalSection);
  end;
end;

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

constructor TLogger.Create(const FileName: string; AUseThread: Boolean);
begin
  FFileName := FileName;
  FIsInit := False;
  Self.SetNoisyMode;
  FQuietTypes := [];

  FFullApplicationPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  FDirectoryFileRotationHistory := IncludeTrailingPathDelimiter(FFullApplicationPath + 'LogHistory');
  FKeepQuantity := 10;
  FMaxLogSizeInBytes := 1048576;  // 1Mb = 1.048.576 bytes
  FUseLogRotation := True;

  FLogWriter := TLogWriter.Create(FileName);
  if (AUseThread) then
  begin
    FThreadLogWriter := TThreadLogWriter.Create(FLogWriter);
//    FThreadLogWriter.FreeOnTerminate := True;
    FThreadLogWriter.Start;
  end;

  CreateFoldersIfNecessary;
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

procedure TLogger.Debug(const Msg: string);
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

  FThreadLogWriter.Terminate;

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
  Exit;
{
  if (FIsInit and (not FQuietMode)) then
    CloseFile(FOutFile);

  FIsInit := False;
  }
end;
 
procedure TLogger.Initialize;
begin
  exit;
{
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
  }
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
  FORMAT_DATETIME_DEFAULT = 'yyyy/mm/dd hh:nn:ss';
begin
  if FQuietMode then
    Exit;

  if Assigned(FThreadLogWriter) then
  begin
    FThreadLogWriter.addLog(Format('%s %s ', [FormatDateTime(FORMAT_DATETIME_DEFAULT, Now), Msg]));
  end
  else
    FLogWriter.WriteToTXT(Format('%s %s ', [FormatDateTime(FORMAT_DATETIME_DEFAULT, Now), Msg]));
end;


initialization
  Logger4Pascal := TLogger.Create('app.log');

finalization
  Logger4Pascal.Free;

end.
