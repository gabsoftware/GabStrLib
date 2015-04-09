; ----------------------------- ALIBD.ASM ---------------------------
; DLL entry function for ALIBD32.DLL

.386
.model flat,stdcall

.code

DllEntry proc hInstance:DWORD, reason:DWORD, reserved1:DWORD
        mov     eax, 1
        ret
DllEntry endp

END  DllEntry
