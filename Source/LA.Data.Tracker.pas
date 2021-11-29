unit LA.Data.Tracker;

interface

uses
  System.Classes;

type

  /// <summary>
  ///   ������ - ����� ���� ����������� ��� �����������, �� �������� � ��������
  /// </summary>
  TDCTracker = class(TComponent)
  private
    FSID: string;
    FData: string;
    procedure SetSID(const Value: string);
  public
    procedure SetData(const aData: string);
  published
    property SID: string read FSID write SetSID;
  end;


implementation

{ TDCTracker }

procedure TDCTracker.SetData(const aData: string);
begin
  FData := aData;
end;

procedure TDCTracker.SetSID(const Value: string);
begin
  FSID := Value;
end;


end.
