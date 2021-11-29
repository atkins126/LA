unit LA.Data.Updater.Intf;

interface

type
  /// <summary>
  ///  ������, �� ������� ����� ���������
  ///  � ���� ����� ������������/����������� � �� ����� ��������, ��� ���-�� ����������
  ///  aLink - ��� ����������� ������, ������� ������������ ��������� IDCObserverLink,
  ///  ��������� � ������ ����������� � ����� ��� ��������� �����������
  ///  (�������� � ���� ������ �� �����������)
  /// </summary>
  IDCObservable<T> = interface(IInvokable)
    procedure Attach(const aLink: T);
    procedure Detach(const aLink: T);
    procedure Notify;
  end;

implementation

end.
