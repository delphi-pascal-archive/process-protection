unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,registry;

type
  TForm1 = class(TForm)
    Button2: TButton;
    ListBox1: TListBox;
    procedure Button2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
  private
  public
  hDriver: THandle;
  TrId: Cardinal;
  access: Boolean;
  PrtCode: cardinal;
 end;

type
PUnicodeString = ^TUnicodeString;
  TUnicodeString = packed record
    Length: Word;
    MaximumLength: Word;
    Buffer: PWideChar;
end;

var
  Form1: TForm1;

const
 PROTECT_OK = $00FE;
 PROTECT_ERROR = $011F;
 DrvReg = '\registry\machine\system\CurrentControlSet\Services\';

procedure RtlInitUnicodeString(DestinationString: PUnicodeString;
                               SourceString: PWideChar);
                                stdcall; external 'ntdll.dll';
function ZwLoadDriver(DriverServiceName: PUnicodeString): cardinal;
                  stdcall;external 'ntdll.dll';

function ZwUnloadDriver(DriverServiceName: PUnicodeString): cardinal;
                  stdcall;external 'ntdll.dll';

implementation

{$R *.dfm}

const
 DrvName = 'MPPrtct';

var
f: boolean = false;

function EnablePrivilegeEx(Process: dword; lpPrivilegeName: PChar):Boolean;
var
  hToken: dword;
  NameValue: Int64;
  tkp: TOKEN_PRIVILEGES;
  ReturnLength: dword;
begin
  Result:=false;
  OpenProcessToken(Process, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken);
  if not LookupPrivilegeValue(nil, lpPrivilegeName, NameValue) then
    begin
     CloseHandle(hToken);
     exit;
    end;
  tkp.PrivilegeCount := 1;
  tkp.Privileges[0].Luid := NameValue;
  tkp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
  AdjustTokenPrivileges(hToken, false, tkp, SizeOf(TOKEN_PRIVILEGES), tkp, ReturnLength);
  if GetLastError() <> ERROR_SUCCESS then
     begin
      CloseHandle(hToken);
      exit;
     end;
  Result:=true;
  CloseHandle(hToken);
end;

function InstallDriver(drName, drPath: PChar): boolean;
var
 Key, Key2: HKEY;
 dType: dword;
 Err: dword;
 NtPath: array[0..MAX_PATH] of Char;
begin
 Result := false;
 dType := 1;
 Err := RegOpenKeyA(HKEY_LOCAL_MACHINE, 'system\CurrentControlSet\Services', Key);
 if Err = ERROR_SUCCESS then
   begin
    Err := RegCreateKeyA(Key, drName, Key2);
    if Err <> ERROR_SUCCESS then Err := RegOpenKeyA(Key, drName, Key2);
    if Err = ERROR_SUCCESS then
      begin
       lstrcpy(NtPath, PChar('\??\' + drPath));
       RegSetValueExA(Key2, 'ImagePath', 0, REG_SZ, @NtPath, lstrlen(NtPath));
       RegSetValueExA(Key2, 'Type', 0, REG_DWORD, @dType, SizeOf(dword));
       RegCloseKey(Key2);
       Result := true;
      end;
    RegCloseKey(Key);
   end;
end;

function UninstallDriver(drName: PChar): boolean;
var
 Key: HKEY;
begin
  Result := false;
  if RegOpenKeyA(HKEY_LOCAL_MACHINE, 'system\CurrentControlSet\Services', Key) = ERROR_SUCCESS then
    begin
      RegDeleteKey(Key, PChar(drName+'\Enum'));
      RegDeleteKey(Key, PChar(drName+'\Security'));
      Result := RegDeleteKey(Key, drName) = ERROR_SUCCESS;
      RegCloseKey(Key);
    end;
end;

function LoadDriver(dName: PChar): boolean;
var
 Image: TUnicodeString;
 Buff: array [0..MAX_PATH] of WideChar;
begin
  StringToWideChar(DrvReg + dName, Buff, MAX_PATH);
  RtlInitUnicodeString(@Image, Buff);
  Result := ZwLoadDriver(@Image) = 0;
end;

function UnloadDriver(dName: PChar): boolean;
var
 Image: TUnicodeString;
 Buff: array [0..MAX_PATH] of WideChar;
begin
  StringToWideChar(DrvReg + dName, Buff, MAX_PATH);
  RtlInitUnicodeString(@Image, Buff);
  Result := ZwUnloadDriver(@Image) = 0;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
if access = false then
Begin
access := True;
DeviceIoControl(hDriver, Cardinal(4), nil, 0, nil, 0, TrId, nil);

if UnloadDriver(DrvName) then
ListBox1.Items.Add('Защита успешно отключена!')
else
ListBox1.Items.Add('Ошибка отключения защиты!');
{
if UninstallDriver(DrvName) then
  ListBox1.Items.Add('Драйвер успешно удален!')
  else
  ListBox1.Items.Add('Ошибка удаления драйвера!');
}
Button2.Caption := 'Выход';
end
else
Begin
access := True;
DeviceIoControl(hDriver, Cardinal(4), nil, 0, nil, 0, TrId, nil);
UnloadDriver(DrvName);
Close;
End;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
Action := CaFree;
if access = false then
Action := CaNone;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
if f = false then
Begin
f := True;
access := False;
if PrtCode = PROTECT_OK then
Begin
  ListBox1.Items.Add('Драйвер успешно инициализирован!');
  ListBox1.Items.Add('Теперь можете попробовать завершить процесс с PID: '+
  IntToStr(GetCurrentProcessId));
  
End
else
Begin  
  access := True;
  ListBox1.Items.Add('Ошибка инициализации драйвера!');
  Button2.Caption := 'Выход';
End;
End;
end;

end.

initialization
 EnablePrivilegeEx(Process, 'SeLoadDriverPrivilege');
