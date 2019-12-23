unit LA.DC.CustomConnector;
{*******************************************************}
{                                                       }
{     Copyright (c) 2019-2020 by Alex A. Lagodny        }
{                                                       }
{*******************************************************}


interface

uses
  System.Classes, System.SysUtils;

const
  cDefConnectTimeout = 2000;
  cDefReadTimeout = 60000;

  cDefCompressionLevel = 4;
  cDefEncrypt = False;

  cDefPort = 5555;

type
  // ��� ���������� �� �������� ������ ���������
  EDCNotInhibitException = class(Exception);

  EDCConnectorException = class(EDCNotInhibitException);
  EDCConnectorCommandException = class(EDCConnectorException);
  EDCConnectorUnknownAnswerException = class(EDCConnectorException);
  EDCConnectorOperationCanceledException = class(EDCConnectorException);

  /// ����� ����������� � ������� �����������
  ///  ��� ���������� ��������� ��������� ��������� ������������� � ��������
  TDCCustomConnector = class(TComponent)
  private
    FAddress: string;
    FUserName: string;
    FPassword: string;
    FDescription: string;
    FReadTimeOut: Integer;
    FConnectTimeOut: Integer;
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
    procedure DoChangeProp; virtual;

    procedure DoConnect; virtual; abstract;
    procedure DoDisconnect; virtual; abstract;
  public
    procedure Connect; virtual; abstract;
    procedure Disconnect; virtual; abstract;
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

{ TDCCustomConnector }



procedure TDCCustomConnector.DoChangeProp;
begin
  if Connected then
    Disconnect;
end;

procedure TDCCustomConnector.SetAddress(const Value: string);
begin
  if Address <> Value then
  begin
    FAddress := Value;
    DoChangeProp;
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
  FDescription := Value;
end;

procedure TDCCustomConnector.SetPassword(const Value: string);
begin
  if Password <> Value then
  begin
    FPassword := Value;
    DoChangeProp;
  end;
end;

procedure TDCCustomConnector.SetUserName(const Value: string);
begin
  if UserName <> Value then
  begin
    FUserName := Value;
    DoChangeProp;
  end;
end;

end.
