unit LA.Net.Connector.Intf;

interface

type
  /// ��������� ������� � �������
  IDCConnector = interface
  ['{54ABD7AB-27A5-42A0-AE14-506242BB01F8}']
    procedure Connect;
    procedure Disconnect;

    function SensorValue(const SID: String): String;
  end;


implementation

end.
