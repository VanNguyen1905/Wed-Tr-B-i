# EDU GAME HUB FREE v1.4 - FIX FIRESTORE API 403

Mo VS Code > Terminal (PowerShell) tai thu muc D:\EduGameHub-Free\EduGameHub.

Kiem tra ma nguon:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TEST-LOCAL.ps1
```

Tiep tuc tren project Spark da co:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SETUP-FREE.ps1 -ProjectId "edugamehub-free-41819"
```

Sau khi setup thanh cong:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TEST-ONLINE.ps1
```

Khong xoa .edugame-setup.json. Khong yeu cau Cloud Billing. Chi ho tro game HTML 1 file.
