{*******************************************************}
{                                                       }
{       LA DC Components                                }
{                                                       }
{       Copyright (C) 2021 LA                           }
{                                                       }
{*******************************************************}

unit LA.DC.CustomConnector;

interface

uses
  System.Classes, System.SysUtils;
  //SynCrossPlatformJSON;
const
  cDefConnectTimeout = 2000;
  cDefReadTimeout = 60000;

  cDefCompressionLevel = 4;
  cDefEncrypt = False;

  cDefPort = 5555;

type
  /// ��������� ������� � �������
  IDCConnector = interface
  ['{54ABD7AB-27A5-42A0-AE14-506242BB01F8}']
    procedure Connect;
    procedure Disconnect;

    function SensorValue(const SID: String): String;

  end;

  // ��� ���������� �� �������� ������ ���������
  EDCNotInhibitException = class(Exception);

  EDCConnectorException = class(EDCNotInhibitException);
  EDCConnectorBadAddress = class(EDCConnectorException);
  EDCConnectorCommandException = class(EDCConnectorException);
  EDCConnectorUnknownAnswerException = class(EDCConnectorException);
  EDCConnectorOperationCanceledException = class(EDCConnectorException);

  /// ����� ����������� � ������� �����������
  ///  ��� ���������� ��������� ��������� ��������� ������������� � ��������
  TDCCustomConnector = class(TComponent, IDCConnector)
  private
    FAddress: string;
    FUserName: string;
    FPassword: string;
    FDescription: string;
    FOnConnect: TNotifyEvent;
    FOnDisconnect: TNotifyEvent;
    procedure SetAddress(const Value: string);
    procedure SetPassword(const Value: string);
    procedure SetUserName(const Value: string);
    procedure SetDescription(const Value: string);
  protected
    function GetEncrypt: boolean; virtual; abstract;
    function GetCompressionLevel: Integer; virtual; abstract;
    function GetConnectTimeOut: Integer; virtual; abstract;
    function GetReadTimeOut: Integer; virtual; abstract;

    procedure SetEncrypt(const Value: boolean); virtual; abstract;
    procedure SetCompressionLevel(const Value: Integer); virtual; abstract;
    procedure SetReadTimeOut(const Value: Integer); virtual; abstract;
    procedure SetConnectTimeOut(const Value: Integer); virtual; abstract;

    function GetConnected: Boolean; virtual; abstract;
    procedure SetConnected(const Value: Boolean); virtual;

    // ���������� ��� ��������� ����������
    procedure DoPropChanged; virtual;

    /// �������� ������������ �� ���������� ������
    ///  ���� ����������� ���������� �������� ����������
    procedure TryConnectTo(const aHost: string; const aPort: Integer); virtual; abstract;

    /// ���������� ��� ��������� ��������
    ///  ���� ����������� ���������� �������� ���������� (�� ���������� ��������)
    procedure TryConnect; virtual;

    /// ��������� ����������� ����� ������� ������� �������
    ///  ���� ����������� ���, �� �������� ������������
    procedure CheckConnection; virtual;


    procedure DoConnect; virtual; abstract;
    procedure DoDisconnect; virtual; abstract;
  public
    procedure Connect; virtual; abstract;
    procedure Disconnect; virtual; abstract;

    function SensorValue(const SID: String): String; virtual; abstract;
//    function GroupSensorValueByID(const IDs: TIDArr): TValArr;


  published
    /// ��������� ����������� � ������� Host:Port
    ///  ����� ����� � ������� (;) ����� �������� ������������� ������: host1:port1;host2:port2;host3:port3
    property Address: string read FAddress write SetAddress;

    // �������� �����������, ��
    property ConnectTimeOut: Integer read GetConnectTimeOut write SetConnectTimeOut default cDefConnectTimeout;
    // �������� ������� �� �������, ��
    property ReadTimeOut: Integer read GetReadTimeOut write SetReadTimeOut default cDefReadTimeout;

    // ������� ������ (0 - ��� ������ ... 9 - ������������ ������)
    property CompressionLevel: Integer read GetCompressionLevel write SetCompressionLevel default cDefCompressionLevel;
    // ����������
    property Encrypt: boolean read GetEncrypt write SetEncrypt default cDefEncrypt;

    // ��� ������������
    property UserName: string read FUserName write SetUserName;
    // ������
    property Password: string read FPassword write SetPassword;

    // ��������� �����������
    property Connected: Boolean read GetConnected write SetConnected;

    /// ��� ������������� �������
    property Description: string read FDescription write SetDescription;

    /// �������
    property OnConnect: TNotifyEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TNotifyEvent read FOnDisconnect write FOnDisconnect;
  end;

implementation

resourcestring
  sResAddressIsEmpty = 'Address is empty. The format of Address should be: host1:port1;host2:port2 etc';
  sResAddressIsBadFmt = 'Check Address (%s). The format of Address should be: host1:port1;host2:port2 etc';


{ TDCCustomConnector }
procedure TDCCustomConnector.CheckConnection;
begin
  if not Connected then
    DoConnect;
end;

procedure TDCCustomConnector.DoPropChanged;
begin
  if Connected then
    Disconnect;
end;

procedure TDCCustomConnector.SetAddress(const Value: string);
begin
  if Address <> Value then
  begin
    FAddress := Value;
    DoPropChanged;
  end;
end;

procedure TDCCustomConnector.SetConnected(const Value: Boolean);
begin
  if Value <> Connected then
  begin
    if Value then
      Connect
    else
      Disconnect;
  end;
end;

procedure TDCCustomConnector.SetDescription(const Value: string);
begin
  if Description <> Value then
  begin
    FDescription := Value;
    DoPropChanged;
  end;
end;

procedure TDCCustomConnector.SetPassword(const Value: string);
begin
  if Password <> Value then
  begin
    FPassword := Value;
    DoPropChanged;
  end;
end;

procedure TDCCustomConnector.SetUserName(const Value: string);
begin
  if UserName <> Value then
  begin
    FUserName := Value;
    DoPropChanged;
  end;
end;

procedure TDCCustomConnector.TryConnect;
var
  aAddressList, aParams: TStringList;
  i: Integer;
begin
  if Address = '' then
    raise EDCConnectorBadAddress.Create(sResAddressIsEmpty);

  aAddressList := TStringList.Create;
  aParams := TStringList.Create;
  try
    aAddressList.LineBreak := ';';
    aParams.LineBreak := ':';
    aAddressList.Text := Address;
    for i := 0 to aAddressList.Count - 1 do
    begin
      aParams.Text := aAddressList[i];
      if aParams.Count = 2 then
      begin
        try
          TryConnectTo(aParams[0], StrToInt(aParams[1]));
          /// ����������� ������ �������
          ///  ���������� �������� ��������� ����������� � ������ ������ ��� ����� �������� ���������������
          if i <> 0 then
          begin
            aAddressList.Move(i, 0);
            FAddress := aAddressList.Text;
          end;
          /// ������
          Exit;
        except
          on Exception do
          begin
            /// ���� �� ����� �� ���������� �������� � ��� � �� ������ ������������,
            ///  �� ��������� ��������� ����������, ����� ���������� �������
            if i = aAddressList.Count - 1 then
              raise
          end;
        end;
      end
      else
        raise EDCConnectorBadAddress.CreateFmt(sResAddressIsBadFmt, [Address]);
    end;


  finally
    aParams.Free;
    aAddressList.Free;
  end;
end;

end.
