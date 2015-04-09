; ----------------------------- MOTHER32.ASM -----------------------------
; Mother-of-All random number generator by Agner Fog 1998 - 2008
; 32-bit mode version for 80x86 and compatible microprocessors
;
;  This is a multiply-with-carry type of random number generator
;  invented by George Marsaglia.  The algorithm is:             
;  S = 2111111111*X[n-4] + 1492*X[n-3] + 1776*X[n-2] + 5115*X[n-1] + C
;  X[n] = S modulo 2^32
;  C = floor(S / 2^32) 
;
; C++ prototypes:
;
; Thread-safe versions:
; extern "C" void         MotRandomInit(void * Pthis, int seed);      // Initialization
; extern "C" int          MotIRandom(void * Pthis, int min, int max); // Get integer random number in desired interval
; extern "C" double       MotRandom(void * Pthis);                    // Get floating point random number
; extern "C" unsigned int MotBRandom(void * Pthis);                   // Output random bits
;
; Single-threaded static link versions
; extern "C" void         MotherRandomInit(int seed);      // Initialization
; extern "C" int          MotherIRandom(int min, int max); // Get integer random number in desired interval
; extern "C" double       MotherRandom();                  // Get floating point random number
; extern "C" unsigned int MotherBRandom();                 // Output random bits
;
; Single-threaded dynamic link versions
; extern "C" void         __stdcall MotherRandomInitD(int seed);      // Initialization
; extern "C" int          __stdcall MotherIRandomD(int min, int max); // Get integer random number in desired interval
; extern "C" double       __stdcall MotherRandomD();                  // Get floating point random number
; extern "C" unsigned int __stdcall MotherBRandomD();                 // Output random bits
;
; © 1998 - 2008 Agner Fog. 
; See asmlib-instructions.pdf for license conditions
; ----------------------------------------------------------------------

.686
.xmm
.model flat

extern _InstructionSet: near

; structure definition and constants:
INCLUDE randomah.asi

IFNDEF POSITIONINDEPENDENT
.DATA
; Data for single instance of random number generator
MotherInstance CRandomMotherA <>
ENDIF


.CODE    ; code segment

; extern "C" unsigned int MotherBRandom(void * Pthis); // Output random bits

_MotBRandom PROC NEAR
        mov     ecx, [esp+4]                ; Pthis
        assume  ecx: ptr CRandomMotherA
MotBRandom_reg label near                   ; Alternative entry for Pthis in ecx
;public  MotBRandom_reg
        
        ; CPU dispatch:
        cmp     [ecx].Instset, 4
        jb      MotBRandomGeneric

; SSE2 version        
        ; ecx = Pthis
        movdqa  xmm1, xmmword ptr [ecx].M3  ; load M3,M2,M1,M0
        mov     eax,  [ecx].M0              ; Retrieve previous random number
        movdqa  xmm2, xmm1                  ; copy
        movdqa  xmm3, xmmword ptr [ecx].MF3 ; factors
        psrlq   xmm2, 32                    ; move M2,M0 down
        movq    qword ptr [ecx].M4, xmm1    ; M4=M3, M3=M2
        movhps  qword ptr [ecx].M2, xmm1    ; M2=M1, M1=M0
        pmuludq xmm1, xmm3                  ; M3*MF3, M1*MF1
        psrlq   xmm3, 32                    ; move MF2,MF0 down
        pmuludq xmm2, xmm3                  ; M2*MF2, M0*MF0
        paddq   xmm1, xmm2                  ; P2+P3, P0+P1
        movhlps xmm2, xmm1                  ; Get high qword
        paddq   xmm1, xmm2                  ; P0+P1+P2+P3
        paddq   xmm1, qword ptr [ecx].MC    ; +carry
        movq    qword ptr [ecx].M0, xmm1    ; Store new M0 and carry
        ; convert to double precision float
        psllq   xmm1, 32                    ; Discard carry bits
        psrlq   xmm1, 12                    ; Get bits into mantissa position
        por     xmm1, xmmword ptr [ecx].one ; Add exponent bits to get number in interval [1,2)
        movq    [ecx].RanP1, xmm1           ; Store floating point number
        ret
        
        
; Generic version for old processors
MotBRandomGeneric label near                ; Generic version for old processors
        ; ecx = Pthis
        push    esi
        push    edi
        ; recall previous random number
        push    [ecx].m0
        ; prepare new random number
        mov     eax, [ecx].mf3
        mul     [ecx].m3                    ; x[n-4]
        mov     esi,eax
        mov     eax, [ecx].m2               ; x[n-3]
        mov     edi,edx
        mov     [ecx].m3,eax
        mul     [ecx].mf2
        add     esi,eax
        mov     eax, [ecx].m1               ; x[n-2]
        adc     edi,edx
        mov     [ecx].m2,eax
        mul     [ecx].mf1
        add     esi,eax
        mov     eax,[ecx].m0                ; x[n-1]
        adc     edi,edx
        mov     [ecx].m1,eax
        mul     [ecx].mf0
        add     eax,esi
        adc     edx,edi
        add     eax,[ecx].mc
        adc     edx,0
        ; store next random number and carry
        mov     [ecx].m0,eax
        mov     [ecx].mc,edx
        ; convert to float in case next call needs a float
        mov     edx, eax
        shr     eax, 12
        or      eax, 3ff00000h
        shl     edx, 20
        mov     dword ptr [ecx].RanP1+4, eax
        mov     dword ptr [ecx].RanP1, edx
        ; retrieve previous random number
        pop     eax
        pop     edi
        pop     esi
        ret
_MotBRandom ENDP

        
; extern "C" double MotRandom(void * Pthis);  // Get floating point random number
_MotRandom PROC NEAR

        mov     ecx, [esp+4]                ; Pthis
        assume  ecx: ptr CRandomMotherA

        ; get previously prepared random number
        fld     [ecx].RanP1
        fsub    [ecx].one

        ; make new random number ready for next time
        call    MotBRandom_reg              ; random bits
        ret
_MotRandom ENDP


; extern "C" int MotIRandom(void * Pthis, int min, int max); // Get integer random number in desired interval
_MotIRandom PROC NEAR                       ; make random integer in desired interval

        mov     ecx, [esp+4]                ; Pthis
        call    MotBRandom_reg              ; make random number
        mov     edx, [esp+12]               ; max
        mov     ecx, [esp+8]                ; min
        sub     edx, ecx
        js      short rerror                ; max < min
        inc     edx                         ; max - min + 1
        mul     edx                         ; multiply random number by interval and truncate
        lea     eax, [edx+ecx]              ; add min
        ret                                 ; ret 8 if not _cdecl calling

rerror: mov     eax, 80000000h              ; error exit   
        ret                                 ; ret 8 if not _cdecl calling
_MotIRandom ENDP


; extern "C" void MotRandomInit(void * Pthis, int seed);  // Initialization
_MotRandomInit PROC NEAR

        ; clear my buffer
        push    edi
        mov     edi, [esp+8]                ; Pthis
        mov     ecx, (type CRandomMotherA) / 4
        xor     eax, eax
        cld
        rep     stosd
        
        ; insert constants
        mov     ecx, [esp+8]                ; Pthis
        assume  ecx: ptr CRandomMotherA
        mov     dword ptr [ecx].one + 4, 3FF00000H  ; high dword of 1.0       
        mov     [ecx].MF0, 5115             ; factors
        mov     [ecx].MF1, 1776
        mov     [ecx].MF2, 1492
        mov     [ecx].MF3, 2111111111
        
        ; get instruction set
        push    ecx
        call    _InstructionSet
        pop     ecx
        mov     [ecx].Instset, eax
        
        ; initialize from seed
        mov     eax, [esp+12]               ; seed        
        ; make random numbers and put them into buffer
        imul    eax, 29943829
        dec     eax
        mov     [ecx].M0, eax
        imul    eax, 29943829
        dec     eax
        mov     [ecx].M1, eax
        imul    eax, 29943829
        dec     eax
        mov     [ecx].M2, eax
        imul    eax, 29943829
        dec     eax
        mov     [ecx].M3, eax
        imul    eax, 29943829
        dec     eax
        mov     [ecx].MC, eax

        ; randomize some more
        mov     edi, 20                     ; loop counter
r90:    call    MotBRandom_reg
        dec     edi
        jnz     r90
        pop     edi
        ret     0                           ; ret 4 if not _cdecl calling
_MotRandomInit ENDP


IFNDEF POSITIONINDEPENDENT
; ------------------------------------------------------------------
; Single-threaded static link versions
; ------------------------------------------------------------------

; extern "C" void MotherRandomInit(int seed); // Initialization
_MotherRandomInit PROC NEAR
        push    [esp+4]                ; seed
        push    offset MotherInstance
        call    _MotRandomInit
        pop     ecx
        pop     ecx
        ret
_MotherRandomInit ENDP


; extern "C" double MotherRandom(); // Get floating point random number
_MotherRandom PROC NEAR
        mov     ecx, offset MotherInstance
        assume  ecx: ptr CRandomMotherA
        fld     [ecx].RanP1
        fsub    [ecx].one
        call    MotBRandom_reg         ; random bits
        ret
_MotherRandom ENDP


; extern "C" int MotherIRandom(int min, int max); // Get integer random number in desired interval
_MotherIRandom PROC   NEAR             ; make random integer in desired interval
        mov     ecx, offset MotherInstance
        call    MotBRandom_reg         ; make random number
        mov     edx, [esp+8]           ; max
        mov     ecx, [esp+4]           ; min
        sub     edx, ecx
        js      RR100                  ; max < min
        inc     edx                    ; max - min + 1
        mul     edx                    ; multiply random number by interval and truncate
        lea     eax, [edx+ecx]         ; add min
        ret                            ; ret 8 if not _cdecl calling
        
RR100:  mov     eax, 80000000H         ; error exit   
        ret                            ; ret 8 if not _cdecl calling
_MotherIRandom ENDP


; extern "C" unsigned int MotherBRandom(); // Output random bits
_MotherBRandom PROC NEAR
        mov     ecx, offset MotherInstance
        jmp     MotBRandom_reg
_MotherBRandom ENDP
       

; ------------------------------------------------------------------
; Single-threaded dynamic link versions
; ------------------------------------------------------------------

; extern "C" void __stdcall MotherRandomInitD(int seed); // Initialization
_MotherRandomInitD@4 PROC NEAR
        push    [esp+4]                ; seed
        push    offset MotherInstance
        call    _MotRandomInit
        pop     ecx
        pop     ecx
        ret     4
_MotherRandomInitD@4 ENDP


; extern "C" double __stdcall MotherRandomD(); // Get floating point random number
_MotherRandomD@0 PROC NEAR
        mov     ecx, offset MotherInstance
        assume  ecx: ptr CRandomMotherA
        fld     [ecx].RanP1
        fsub    [ecx].one
        call    MotBRandom_reg         ; random bits
        ret
_MotherRandomD@0 ENDP


; extern "C" int __stdcall MotherIRandomD(int min, int max); // Get integer random number in desired interval
_MotherIRandomD@8 PROC NEAR            ; make random integer in desired interval
        mov     ecx, offset MotherInstance
        call    MotBRandom_reg         ; make random number
        mov     edx, [esp+8]           ; max
        mov     ecx, [esp+4]           ; min
        sub     edx, ecx
        js      RR200                  ; max < min
        inc     edx                    ; max - min + 1
        mul     edx                    ; multiply random number by interval and truncate
        lea     eax, [edx+ecx]         ; add min
        ret     8

RR200:  mov     eax, 80000000h         ; error exit   
        ret     8
_MotherIRandomD@8 ENDP


; extern "C" unsigned int __stdcall MotherBRandomD(); // Output random bits
_MotherBRandomD@0 PROC NEAR
        mov     ecx, offset MotherInstance
        jmp     MotBRandom_reg
_MotherBRandomD@0 ENDP       

ENDIF ; not POSITIONINDEPENDENT

END
