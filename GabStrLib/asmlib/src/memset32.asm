;*************************  memset32.asm  *************************************
; Author:           Agner Fog
; Date created:     2008-07-19
; Last modified:    2008-07-19
; Description:
; Faster version of the standard memset function:
; void * A_memset(void * dest, int c, size_t count);
; Sets 'count' bytes from 'dest' to the 8-bit value 'c'
;
; Overriding standard function memset:
; The alias ?OVR_memset is changed to _memset in the object file if
; it is desired to override the standard library function memset.
;
; Position-independent code is generated if POSITIONINDEPENDENT is defined.
;
; Optimization:
; Uses XMM registers to set 16 bytes at a time, aligned.
;
; The latest version of this file is available at:
; www.agner.org/optimize/asmexamples.zip
; Copyright (c) 2008 GNU General Public License www.gnu.org/licenses/gpl.html
;******************************************************************************
.686
.xmm
.model flat

public _A_memset                       ; Function memset
public ?OVR_memset                     ; ?OVR removed if standard function memset overridden

; Imported from memcpy32.asm:
extern _CacheBypassLimit: dword        ; Bypass cache if count > _CacheBypassLimit

; Imported from instrset32.asm
extern _InstructionSet: near           ; Instruction set for CPU dispatcher


IFDEF   POSITIONINDEPENDENT

; Macro for arbitrary instruction with position-independent reference
PICREFERENCE MACRO TARGET, REFPOINT, BYTE1, BYTE2, BYTE3
; Make position-independent instrution of the form
; add eax, [ebx+TARGET-REFPOINT]
; where ebx contains the address of REFPOINT
; BYTE1, BYTE2, BYTE3 are the first 2 or 3 bytes of the instruction
; add eax, [ebx+????]
; (as obtained from an assembly listing) including opcode byte, 
; mod/reg/rm byte and possibly sib byte, but ; not including the 4-bytes 
; offset which is generated by this macro.
; Any instruction and any registers can be coded into BYTE1, BYTE2, BYTE3
local p0, p1, p2
; Insert byte codes except last one
p0:
   db  BYTE1
IFNB  <BYTE3>      ; if BYTE3 not blank
   db  BYTE2
ENDIF   
p1:   
; Make bogus CALL instruction for making self-relative reference
; This is the only way the assembler can make a self-relative reference
   call near ptr TARGET + (p2-REFPOINT) 
p2:
; back-patch CALL instruction to change it to the desired instruction
; by replacing CALL opcode by the last byte of desired instruction
   org p1
IFNB  <BYTE3>      ; if BYTE3 not blank
   db  BYTE3
ELSE
   db  BYTE2
ENDIF
   org p2          ; Back to end of instruction
ENDM 

ENDIF


.code

; extern "C" void * memset(void * dest, int c, size_t count);
; Function entry:
_A_memset PROC    NEAR
?OVR_memset LABEL NEAR
        mov     edx, [esp+4]           ; dest
        movzx   eax, byte ptr [esp+8]  ; c
        mov     ecx, [esp+12]          ; count
        imul    eax, 01010101H         ; Broadcast c into all bytes of eax
        ; (multiplication is slow on Pentium 4, but faster on later processors)
        cmp     ecx, 16
        ja      M100
        
        ; count <= 16
        
IFNDEF  POSITIONINDEPENDENT

        jmp     MemsetJTab[ecx*4]
        
; Separate code for each count from 0 to 16:
M16:    mov     [edx+12], eax
M12:    mov     [edx+8],  eax
M08:    mov     [edx+4],  eax
M04:    mov     [edx],    eax
M00:    mov     eax, [esp+4]           ; dest
        ret

M15:    mov     [edx+11], eax
M11:    mov     [edx+7],  eax
M07:    mov     [edx+3],  eax
M03:    mov     [edx+1],  ax
M01:    mov     [edx],    al
        mov     eax, [esp+4]           ; dest
        ret
       
M14:    mov     [edx+10], eax
M10:    mov     [edx+6],  eax
M06:    mov     [edx+2],  eax
M02:    mov     [edx],    ax
        mov     eax, [esp+4]           ; dest
        ret

M13:    mov     [edx+9],  eax
M09:    mov     [edx+5],  eax
M05:    mov     [edx+1],  eax
        mov     [edx],    al
        mov     eax, [esp+4]           ; dest
        ret
        
ELSE    ; position-independent code. Too complicated to use jump table

        ; ecx = count, from 0 to 16:
        add     edx, ecx               ; end of dest
        neg     ecx                    ; negative index from the end
        jz      A500
        cmp     ecx, -16
        jng     A600
A100:   cmp     ecx, -8
        jg      A200
        ; set 8 bytes
        mov     [edx+ecx], eax
        mov     [edx+ecx+4], eax
        add     ecx, 8
A200:   cmp     ecx, -4
        jg      A300
        ; set 4 bytes
        mov     [edx+ecx], eax
        add     ecx, 4
A300:   cmp     ecx, -2
        jg      A400
        ; set 2 bytes
        mov     [edx+ecx], ax
        add     ecx, 2
A400:   cmp     ecx, -1
        jg      A500
        ; set 1 byte
        mov     [edx+ecx], al
A500:   ret

A600:   ; set 16 bytes
        mov     [edx+ecx], eax
        mov     [edx+ecx+4], eax
        mov     [edx+ecx+8], eax
        mov     [edx+ecx+12], eax
        ret

ENDIF
        
align   16
M100:   ; count > 16. 
IFNDEF  POSITIONINDEPENDENT
        jmp     [memsetDispatch]       ; Go to appropriate version, depending on instruction set

ELSE    ; Position-independent code

        push    ebx
        call    get_thunk_ebx          ; get reference point for position-independent code
RP:                                    ; reference point eax = offset RP
A020:                                  ; Go here after CPU dispatching

        ; Make the following instruction with address relative to RP:
        ; cmp [ebx-RP+memsetCPUVersion], 1
        PICREFERENCE memsetCPUVersion, RP, 83H, 0BBH
        db      1                      ; Last byte of cmp instruction
        
        jb      memsetCPUDispatch      ; First time: memsetCPUVersion = 0, go to dispatcher
        je      memset386              ; memsetCPUVersion = 1, go to 80386 version

ENDIF

memsetSSE2:  ; SSE2 version. Use xmm register
        movd    xmm0, eax
        pshufd  xmm0, xmm0, 0          ; Broadcast c into all bytes of xmm0
        
        ; Store the first unaligned part.
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the subsequent regular part, than to make possibly mispredicted
        ; branches depending on the size of the first part.
        movq    qword ptr [edx],   xmm0
        movq    qword ptr [edx+8], xmm0
        
        ; Check if count very big
IFNDEF  POSITIONINDEPENDENT

        cmp     ecx, [_CacheBypassLimit]
        
ELSE    ; position-independent code

        ; Generate instruction cmp ecx,[ebx-RP+_CacheBypassLimit]
        PICREFERENCE _CacheBypassLimit, RP, 3BH, 8BH
        
ENDIF

        ja      M500                   ; Use non-temporal store if count > $NonTempMoveLimit
        
        ; Point to end of regular part:
        ; Round down dest+count to nearest preceding 16-bytes boundary
        lea     ecx, [edx+ecx-1]
        and     ecx, -10H
        
        ; Point to start of regular part:
        ; Round up dest to next 16-bytes boundary
        add     edx, 10H
        and     edx, -10H
        
        ; -(size of regular part)
        sub     edx, ecx
        jnl     M300                   ; Jump if not negative
        
M200:   ; Loop through regular part
        ; ecx = end of regular part
        ; edx = negative index from the end, counting up to zero
        movdqa  [ecx+edx], xmm0
        add     edx, 10H
        jnz     M200
        
M300:   ; Do the last irregular part
IFDEF   POSITIONINDEPENDENT
        pop     ebx
ENDIF
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the preceding regular part, than to make possibly mispredicted
        ; branches depending on the size of the last part.
        mov     eax, [esp+4]           ; dest
        mov     ecx, [esp+12]          ; count
        movq    qword ptr [eax+ecx-10H], xmm0
        movq    qword ptr [eax+ecx-8], xmm0
        ret
   
M500:   ; Use non-temporal moves, same code as above:
        ; End of regular part:
        ; Round down dest+count to nearest preceding 16-bytes boundary
        lea     ecx, [edx+ecx-1]
        and     ecx, -10H
        
        ; Start of regular part:
        ; Round up dest to next 16-bytes boundary
        add     edx, 10H
        and     edx, -10H
        
        ; -(size of regular part)
        sub     edx, ecx
        jnl     M700                   ; Jump if not negative
        
M600:   ; Loop through regular part
        ; ecx = end of regular part
        ; edx = negative index from the end, counting up to zero
        movdqu  [ecx+edx], xmm0
        add     edx, 10H
        jnz     M600
        
M700:   ; Do the last irregular part
IFDEF   POSITIONINDEPENDENT
        pop     ebx
ENDIF
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the preceding regular part, than to make possibly mispredicted
        ; branches depending on the size of the last part.
        mov     eax, [esp+4]           ; dest
        mov     ecx, [esp+12]          ; count
        movq    qword ptr [eax+ecx-10H], xmm0
        movq    qword ptr [eax+ecx-8], xmm0
        ret
     
        
; 80386 version, ecx > 16
memset386:        
        push    edi
        mov     edi, edx
N200:   test    edi, 3
        jz      N300
        ; unaligned
N210:   mov     [edi], al              ; store 1 byte until edi aligned
        inc     edi
        dec     ecx
        test    edi, 3
        jnz     N210
N300:   ; aligned
        mov     edx, ecx
        shr     ecx, 2
        cld
        rep     stosd                  ; store 4 bytes at a time
        mov     ecx, edx
        and     ecx, 3
        rep     stosb                  ; store any remaining bytes
        pop     edi
IFDEF   POSITIONINDEPENDENT
        pop     ebx
ENDIF
        ret
        
        
; CPU dispatching for memset. This is executed only once
memsetCPUDispatch:
IFNDEF   POSITIONINDEPENDENT
        pushad
        call    _InstructionSet
        ; Point to generic version of memset
        mov     [memsetDispatch], offset memset386
        cmp     eax, 4                 ; check SSE2
        jb      Q100
        ; SSE2 supported
        ; Point to SSE2 version of memset
        mov     [memsetDispatch], offset memsetSSE2
Q100:   popad
        ; Continue in appropriate version of memset
        jmp     [memsetDispatch]

ELSE    ; Position-independent version
        pushad
        
        ; Make the following instruction with address relative to RP:
        ; lea esi, [ebx-RP+memsetCPUVersion]
        PICREFERENCE memsetCPUVersion, RP, 8DH, 0B3H
        ; Now esi points to memsetCPUVersion.

        call    _InstructionSet        

        mov     byte ptr [esi], 1      ; Indicate generic version
        cmp     eax, 4                 ; check SSE2
        jb      Q100
        ; SSE2 supported
        mov     byte ptr [esi], 2      ; Indicate SSE2 or later version
Q100:   popad
        jmp     A020                   ; Go back and dispatch
        
get_thunk_ebx: ; load caller address into ebx for position-independent code
        mov ebx, [esp]
        ret
        
ENDIF

.data

IFNDEF  POSITIONINDEPENDENT

; Jump table for count from 0 to 16:
MemsetJTab DD M00, M01, M02, M03, M04, M05, M06, M07
           DD M08, M09, M10, M11, M12, M13, M14, M15, M16

; Pointer to appropriate version.
; This initially points to memsetCPUDispatch. memsetCPUDispatch will
; change this to the appropriate version of memset, so that
; memsetCPUDispatch is only executed once:
memsetDispatch DD memsetCPUDispatch

ELSE    ; position-independent

; CPU version: 0=unknown, 1=80386, 2=SSE2
memsetCPUVersion DD 0

ENDIF

.code

_A_memset endp

END
