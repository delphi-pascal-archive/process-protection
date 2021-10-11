program control;

uses
  Windows, Forms, sysutils,
  Unit1 in 'Unit1.pas' {Form1};

{$R *.res}

const
 DrvName = 'MPPrtct';
var
 hDriver: THandle;
 TrId: Cardinal;
 R: cardinal;
const
 PROTECT_OK = $00FE;
 PROTECT_ERROR = $011F;


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

Procedure Start;
Begin
R := PROTECT_ERROR;
InstallDriver(DrvName, pchar(ExtractFilePath(Application.ExeName)+'mdrvpr.sys'));

if LoadDriver(DrvName) = false then
R := PROTECT_ERROR
else
R := PROTECT_OK;



 hDriver := CreateFile('\\.\LsApProt', GENERIC_ALL, 0,
                       nil, OPEN_EXISTING, 0, 0);
if hDriver = INVALID_HANDLE_VALUE then
 begin
  R := PROTECT_ERROR
 end
 else
 Begin
 if DeviceIoControl(hDriver, GetCurrentProcessId(), nil, 0, nil, 0, TrId, nil) then
  R := PROTECT_OK
  else
  R := PROTECT_ERROR;
 End;
End; 

begin
  Start;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  form1.access := False;
  Form1.PrtCode := R;
  Form1.hDriver := hDriver;
  Application.Run;
end.
