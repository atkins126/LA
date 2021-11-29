unit LA.Data.Link.Intf;

interface

type

  /// <summary>
  ///  ���� (�������) � �����������
  ///  ����� ���������� ID - ����� �����������, ����������� ��� ������� ������ �� ����� ������
  ///  ���������� ������ ��������������� ����� SetData
  ///  ����������� ����������� ����������� ����� Notify
  /// </summary>
  IDCLink = interface(IInvokable)
    /// <summary>
    ///   �������� �������������, �������� ����� ������� ��� �������
    /// </summary>
    function GetID: string;
    /// <summary>
    ///   ���������� ����� ������
    /// </summary>
    procedure SetData(const aData: string);
    /// <summary>
    ///   ��������� �����������
    /// </summary>
    procedure Notify;
  end;


implementation

end.
