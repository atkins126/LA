unit LA.DC.TCPConnector;

interface

uses
  System.Classes, System.SyncObjs, System.SysUtils,
  IdGlobal, IdTCPClient, IdException,
  LA.DC.CustomConnector, LA.DC.TCPIntercept;

type
  TDCTCPConnector = class(TDCCustomConnector)
  private
    FLock: TCriticalSection;
    FClient: TIdTCPClient;
    FIntercept: TDCTCPIntercept;

    FEncrypt: boolean;
    FCompressionLevel: Integer;

    FServerFS: TFormatSettings;

    FServerVer: Integer;
    FServerEnableMessage: Boolean;
    FServerSupportingProtocols: string;
    FServerOffsetFromUTC: TDateTime;

    FServerSettingsIsLoaded: Boolean;

    FLanguage: string;
    FProtocolVersion: Integer;
    FEnableMessage: Boolean;
    FClientOffsetFromUTC: TDateTime;


    function LockClient(const aMessage: string = ''): TIdTCPClient;
    procedure UnLockClient(const aMessage: string = '');

    function GenerateCryptKey(const aCharCount: Integer): RawByteString;

    procedure UpdateEncrypted(const aLock: Boolean);
    procedure UpdateComressionLevel(const aLock: Boolean);

    procedure ClearIncomingData;

    procedure SendCommand(aCommand: string);
    procedure SendCommandFmt(aCommand: string; const Args: array of TVarRec);

    function ReadLn: string;


    procedure DoCommand(aCommand: string);
    procedure DoCommandFmt(aCommand: string; const Args: array of TVarRec);
    procedure CheckCommandResult;

    // ��������� ������ TCP
    function ProcessTCPException(e: EIdException): Boolean;

    procedure GetServerSettings;
    procedure SetConnectionParams;

    procedure SetEnableMessage(const Value: Boolean);
    procedure SetLanguage(const Value: string);
    procedure SetProtocolVersion(const Value: Integer);

  protected
    function GetEncrypt: boolean; override;
    function GetCompressionLevel: Integer; override;
    function GetConnectTimeOut: Integer; override;
    function GetReadTimeOut: Integer; override;

    procedure SetEncrypt(const Value: boolean); override;
    procedure SetCompressionLevel(const Value: Integer); override;
    procedure SetReadTimeOut(const Value: Integer); override;
    procedure SetConnectTimeOut(const Value: Integer); override;

    procedure TryConnect; virtual;
    procedure Authorize(const aUser, aPassword: string); virtual;

    property Intercept: TDCTCPIntercept read FIntercept;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property ServerFS: TFormatSettings read FServerFS;
    property ServerVer: Integer read FServerVer;
    property ServerOffsetFromUTC: TDateTime read FServerOffsetFromUTC;
    property ClientOffsetFromUTC: TDateTime read FClientOffsetFromUTC;

  published
    /// ������ ���������
    property ProtocolVersion: Integer read FProtocolVersion write SetProtocolVersion default 30;
    /// ������ ����� ���������� ��������� ����� ��� �����������
    property EnableMessage: Boolean read FEnableMessage write SetEnableMessage default True;
    /// ����, �� ������� ������ ����� ����� �������������� ��������� (������ � �.�.)
    property Language: string read FLanguage write SetLanguage;

  end;

implementation

uses
  flcStdTypes, flcCipherRSA,
  LA.DC.StrUtils, LA.DC.SystemUtils,
  LA.DC.Log;

const
  sOk = 'ok';       // not localize
  sError = 'error'; // not localize
  sNoCommandHandler = 'no command handler'; // not localize

  sUnknownAnswer = 'Unknown answer : %s';
  sBadParamCount = '�������� ������������ ���������� ���������� %d �� %d.';



{ TDCTCPConnector }

procedure TDCTCPConnector.Authorize(const aUser, aPassword: string);
begin
  DoCommandFmt('Login %s;%s;1', [aUser, TDCStrUtils.StrToHex(aPassword, '')]);
  ReadLn; // ���������� �����������
end;

procedure TDCTCPConnector.CheckCommandResult;
var
  aStatus: string;
begin
  aStatus := ReadLn;
  if aStatus = sError then
    raise EDCConnectorCommandException.Create(ReadLn)
  else if aStatus <> sOk then
    raise EDCConnectorUnknownAnswerException.Create('������������ ����� �� �������');
end;

procedure TDCTCPConnector.ClearIncomingData;
begin
  while not FClient.IOHandler.InputBufferIsEmpty do
  begin
    FClient.IOHandler.InputBuffer.Clear;
    FClient.IOHandler.CheckForDataOnSource(1);
  end;
end;

constructor TDCTCPConnector.Create(AOwner: TComponent);
begin
  inherited;

  FLock := TCriticalSection.Create;
  FIntercept := TDCTCPIntercept.Create(nil);

  FClient := TIdTCPClient.Create(nil);
  FClient.ConnectTimeout := cDefConnectTimeout;
  FClient.ReadTimeout := cDefReadTimeout;
  FClient.Host := '';
  FClient.Port := cDefPort;

  FClient.Intercept := FIntercept;
end;

destructor TDCTCPConnector.Destroy;
begin
  FClient.Free;
  FIntercept.Free;
  FLock.Free;
  inherited;
end;

procedure TDCTCPConnector.DoCommand(aCommand: string);
begin
  SendCommand(aCommand);
  CheckCommandResult;
end;

procedure TDCTCPConnector.DoCommandFmt(aCommand: string; const Args: array of TVarRec);
begin
  SendCommandFmt(aCommand, Args);
  CheckCommandResult;
end;

function TDCTCPConnector.GenerateCryptKey(const aCharCount: Integer): RawByteString;
var
  i: integer;
begin
  Randomize;

  Result := '';
  for i := 1 to aCharCount do
    Result := Result + ByteChar(Random(256));
end;

function TDCTCPConnector.GetCompressionLevel: Integer;
begin
  Result := FCompressionLevel;
end;

function TDCTCPConnector.GetConnectTimeOut: Integer;
begin
  Result := FClient.ConnectTimeout;
end;

function TDCTCPConnector.GetEncrypt: boolean;
begin
  Result := FEncrypt;
end;

function TDCTCPConnector.GetReadTimeOut: Integer;
begin
  Result := FClient.ReadTimeout;
end;

procedure TDCTCPConnector.GetServerSettings;
var
  aCount: Integer;
  s: TStrings;
  i: Integer;
begin
  try
	  DoCommand('GetServerSettings');
	  aCount := StrToInt(ReadLn);

	  s := TStringList.Create;
	  try
	    for i := 1 to aCount do
        s.Add(ReadLn);

      with FServerFS do
      begin
        ThousandSeparator := s.Values['ThousandSeparator'][low(string)];
        DecimalSeparator := s.Values['DecimalSeparator'][low(string)];
        TimeSeparator := s.Values['TimeSeparator'][low(string)];
        ListSeparator := s.Values['ListSeparator'][low(string)];

        CurrencyString := s.Values['CurrencyString'];
        ShortDateFormat := s.Values['ShortDateFormat'];
        LongDateFormat := s.Values['LongDateFormat'];
        TimeAMString := s.Values['TimeAMString'];
        TimePMString := s.Values['TimePMString'];
        ShortTimeFormat := s.Values['ShortTimeFormat'];
        LongTimeFormat := s.Values['LongTimeFormat'];

        DateSeparator := s.Values['DateSeparator'][low(string)];
      end;

      FServerSettingsIsLoaded := True;

	    FServerVer := StrToInt(s.Values['ServerVer']);
	    FServerEnableMessage := StrToBool(s.Values['EnableMessage']);
	    FServerSupportingProtocols := s.Values['SupportingProtocols'];
      FServerOffsetFromUTC := StrToTimeDef(s.Values['OffsetFromUTC'], ClientOffsetFromUTC);
	  finally
	    s.Free;
	  end;

  except
    on e: EIdException do
      if ProcessTCPException(e) then
        raise;
  end;
end;

function TDCTCPConnector.LockClient(const aMessage: string): TIdTCPClient;
begin
  //OPCLog.WriteToLogFmt('%d: LockClient %s', [GetCurrentThreadId, aMessage]);
  FLock.Enter;
  Result := FClient;
  //OPCLog.WriteToLogFmt('%d: LockClient OK. %s', [GetCurrentThreadId, aMessage]);
end;

function TDCTCPConnector.ProcessTCPException(e: EIdException): Boolean;
begin
  Result := True;
  TDCLog.WriteToLog(e.Message);
  DoDisconnect;
end;

function TDCTCPConnector.ReadLn: string;
begin
  Result := FClient.IOHandler.ReadLn;
end;

procedure TDCTCPConnector.SendCommand(aCommand: string);
begin
  ClearIncomingData;
  FClient.IOHandler.WriteLn(aCommand);
end;

procedure TDCTCPConnector.SendCommandFmt(aCommand: string; const Args: array of TVarRec);
begin
  SendCommand(Format(aCommand, Args));
end;

procedure TDCTCPConnector.SetCompressionLevel(const Value: Integer);
begin
  if CompressionLevel <> Value then
  begin
    FCompressionLevel := Value;
    DoPropChanged;
    //UpdateComressionLevel(True);
  end;
end;

procedure TDCTCPConnector.SetConnectionParams;
const
  cStringEncoding = '';  //'UTF8';
  { TODO : ���������, ������ �� �������� �������� ������ �������������, ���� ����� UTF8 }
  //cStringEncoding = 'UTF8';
begin
  try
	  DoCommandFmt('SetConnectionParams '+
	    'ProtocolVersion=%d;'+
	    //'CompressionLevel=%d;'+
	    'EnableMessage=%d;'+
	    'Description=%s;'+
	    'SystemLogin=%s;'+
	    'HostName=%s;'+
	    'MaxLineLength=%d;'+
      'Language=%s;'+
      'StringEncoding=%s',
	    [ ProtocolVersion,
	      //CompressionLevel,
	      Ord(EnableMessage),
	      Description,
	      TDCSystemUtils.GetLocalUserName,
	      TDCSystemUtils.GetComputerName,
	      FClient.IOHandler.MaxLineLength,
        Language,
        cStringEncoding
	      ]
	    );

      if (ServerVer >= 3) and (cStringEncoding = 'UTF8') then
        FClient.IOHandler.DefStringEncoding := IndyTextEncoding_UTF8;
  except
    on e: EIdException do
      if ProcessTCPException(e) then
        raise;
  end;
end;

procedure TDCTCPConnector.SetConnectTimeOut(const Value: Integer);
begin
  if ConnectTimeOut <> Value then
  begin
    FClient.ConnectTimeout := Value;
    DoPropChanged;
  end;
end;

procedure TDCTCPConnector.SetEnableMessage(const Value: Boolean);
begin
  if EnableMessage <> Value then
  begin
    FEnableMessage := Value;
    DoPropChanged;
  end;
end;

procedure TDCTCPConnector.SetEncrypt(const Value: boolean);
begin
  if Encrypt <> Value then
  begin
    FEncrypt := Value;
    DoPropChanged;
    //UpdateEncrypted(True);
  end;
end;


procedure TDCTCPConnector.SetLanguage(const Value: string);
begin
  if Language <> Value then
  begin
    FLanguage := Value;
    DoPropChanged;
  end;
end;

procedure TDCTCPConnector.SetProtocolVersion(const Value: Integer);
begin
  if ProtocolVersion <> Value then
  begin
    FProtocolVersion := Value;
    DoPropChanged;
  end;
end;

procedure TDCTCPConnector.SetReadTimeOut(const Value: Integer);
begin
  if ReadTimeOut <> Value then
  begin
    FClient.ReadTimeOut := Value;
    DoPropChanged;
  end;

end;

procedure TDCTCPConnector.TryConnect;
begin
  Intercept.CryptKey := '';
  Intercept.CompressionLevel := 0;

//  inherited TryConnect;

  GetServerSettings;
  SetConnectionParams;

  if Encrypt then
    UpdateEncrypted(False);
  if CompressionLevel > 0 then
    UpdateComressionLevel(False);

  if UserName <> '' then
  begin
    try
      Authorize(UserName, Password);
    except
      on e: EIdException do
        if ProcessTCPException(e) then
          raise;
      on e: Exception do
        ;
    end;
  end;
end;

procedure TDCTCPConnector.UnLockClient(const aMessage: string);
begin
  //OPCLog.WriteToLogFmt('%d: UnLockClient %s', [GetCurrentThreadId, aMessage]);
  FLock.Leave;
  //OPCLog.WriteToLogFmt('%d: UnLockClient OK. %s', [GetCurrentThreadId, aMessage]);
end;

procedure TDCTCPConnector.UpdateComressionLevel(const aLock: Boolean);
begin
  if Connected then
  begin
    if aLock then
      LockClient('UpdateComressionLevel');
    try
      try
	      DoCommandFmt('SetConnectionParams CompressionLevel=%d', [CompressionLevel]);
      except
        on e: EIdException do
          if ProcessTCPException(e) then
            raise;
      end;
    finally
      if aLock then
        UnLockClient('UpdateComressionLevel');
    end;
  end;

  FIntercept.CompressionLevel := CompressionLevel;
end;

procedure TDCTCPConnector.UpdateEncrypted(const aLock: Boolean);
var
  aCode: RawByteString;
  aCryptKey: RawByteString;
  aModulus, aExponent: string;
  aPub: TRSAPublicKey;
begin
  if Encrypt then
    aCryptKey := GenerateCryptKey(16)
  else
    aCryptKey := '';

  if Connected then
  begin
    if aLock then
      LockClient('UpdateEncrypted');

    try
      try
        // ����� ������ RSA
        DoCommand('GetPublicKey2');
        aModulus := ReadLn;
        aExponent := ReadLn;

        RSAPublicKeyInit(aPub);
        RSAPublicKeyAssignHex(aPub, 256, aModulus, aExponent);
        aCode := RSAEncryptStr(rsaetPKCS1, aPub, aCryptKey);
        RSAPublicKeyFinalise(aPub);

        DoCommandFmt('SetCryptKey2 %s', [TDCStrUtils.StrToHex(aCode, '')]);
      except
        on e: EIdException do
          if ProcessTCPException(e) then
            raise;
      end;
    finally
      if aLock then
        UnLockClient('UpdateEncrypted');
    end;
  end;
  FIntercept.CryptKey := aCryptKey;
end;

end.
