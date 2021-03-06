;*************************  memmove32.asm  ***********************************
; Author:           Agner Fog
; Date created:     2008-07-18
; Last modified:    2008-07-18
; Description:
; Faster version of the standard memmove function:
; void * A_memmove(void *dest, const void *src, size_t count);
; Moves 'count' bytes from 'src' to 'dest'. src and dest may overlap.
;
; Overriding standard function memmove:
; The alias ?OVR_memmove is changed to _memmove in the object file if
; it is desired to override the standard library function memmove.
;
; Position-independent code is generated if POSITIONINDEPENDENT is defined.
;
; Optimization:
; Uses XMM registers to copy 16 bytes at a time, aligned.
; If source and destination are misaligned relative to each other
; then the code will combine parts of every two consecutive 16-bytes 
; blocks from the source into one 16-bytes register which is written 
; to the destination, aligned.
; This method is 2 - 6 times faster than the implementations in the
; standard C libraries (MS, Gnu) when src or dest are misaligned.
; When src and dest are aligned by 16 (relative to each other) then this
; function is only slightly faster than the best standard libraries.
; CPU dispatching included for 386, SSE2 and Suppl-SSE3 instruction sets.
;
; Copyright (c) 2008 GNU General Public License www.gnu.org/licenses/gpl.html
;******************************************************************************
.686
.xmm
.model flat

public _A_memmove                      ; Function A_memmove
public ?OVR_memmove                    ; ?OVR removed if standard function memmove overridden

; Imported from memcpy32.asm:
extern _CacheBypassLimit: dword        ; Bypass cache if count > _CacheBypassLimit
extern $memcpyEntry2: near             ; Function entry from memmove

; Imported from instrset32.asm
extern _InstructionSet: near           ; Instruction set for CPU dispatcher

; Define return from this function
RETURNM MACRO
IFDEF   POSITIONINDEPENDENT
        pop     ebx
ENDIF
        pop     edi
        pop     esi
        mov     eax, [esp+4]           ; Return value = dest
        ret
ENDM

; Macro for arbitrary instruction with position-independent reference
PICREFERENCE MACRO TARGET, REFPOINT, BYTE1, BYTE2, BYTE3
; Make position-independent instrution of the form
; add eax, [ebx+TARGET-REFPOINT]
; where ebx contains the address of REFPOINT
; BYTE1, BYTE2, BYTE3 are the first 2 or 3 bytes of the instruction
; add eax, [ebx+????]
; (as obtained from an assembly listing) including opcode byte, 
; mod/reg/rm byte and possibly sib byte, but not including the 4-bytes 
; offset which is generated by this macro.
; Any instruction and any registers can be coded into BYTE1, BYTE2, BYTE3.

local p0, p1, p2
; Insert byte codes except last one
p0:
   db  BYTE1
IFNB  <BYTE3>      ; if BYTE3 not blank
   db  BYTE2
ENDIF   
p1:   
; Make bogus CALL instruction for making self-relative reference.
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


.code

; extern "C" void * A_memmove(void * dest, const void * src, size_t count);
; Function entry:
_A_memmove PROC   NEAR
?OVR_memmove LABEL NEAR
        push    esi
        push    edi
        mov     edi, [esp+12]          ; dest
        mov     esi, [esp+16]          ; src
        mov     ecx, [esp+20]          ; count
        
        ; Check if dest overlaps src
        mov     eax, edi
        sub     eax, esi
        cmp     eax, ecx
        ; We can avoid testing for dest < src by using unsigned compare:
        ; Must move backwards if unsigned(dest-src) < count
        jae     $memcpyEntry2          ; Jump to memcpy if we can move forwards
        
        ; Cannot use memcpy. Must move backwards because of overlap between src and dest
        
IFNDEF  POSITIONINDEPENDENT
        jmp     [memmoveDispatch]      ; Go to appropriate version, depending on instruction set
RP      equ     0                      ; RP = 0 if not position-independent

ELSE    ; Position-independent code

        push    ebx
        call    get_thunk_ebx          ; get reference point for position-independent code
RP:                                    ; reference point ebx = offset RP
A020:                                  ; Go here after CPU dispatching

; Make the following instruction with address relative to RP:
; cmp [ebx-RP+memmoveCPUVersion], 1
PICREFERENCE memmoveCPUVersion, RP, 83H, 0BBH
        db      1                      ; Last byte of cmp instruction
        
        jb      memmoveCPUDispatch     ; First time: memcpyCPUVersion = 0, go to dispatcher
        je      memmove386             ; memcpyCPUVersion = 1, go to 80386 version

ENDIF        
        
memmoveSSE2: ; SSE2 and later versions begin here
        
        cmp     ecx, 40H
        jae     B100                    ; Use simpler code if count < 64
        
        ; count < 64. Move 32-16-8-4-2-1 bytes
        test    ecx, 20H
        jz      A100
        ; move 32 bytes
        ; movq is faster than movdqu on current processors,
        ; movdqu may be faster on future processors
        sub     ecx, 20H
        movq    xmm0, qword ptr [esi+ecx+18H]
        movq    xmm1, qword ptr [esi+ecx+10H]
        movq    xmm2, qword ptr [esi+ecx+8]
        movq    xmm3, qword ptr [esi+ecx]
        movq    qword ptr [edi+ecx+18H], xmm0
        movq    qword ptr [edi+ecx+10H], xmm1
        movq    qword ptr [edi+ecx+8], xmm2
        movq    qword ptr [edi+ecx], xmm3
A100:   test    ecx, 10H
        jz      A200
        ; move 16 bytes
        sub     ecx, 10H
        movq    xmm0, qword ptr [esi+ecx+8]
        movq    xmm1, qword ptr [esi+ecx]
        movq    qword ptr [edi+ecx+8], xmm0
        movq    qword ptr [edi+ecx], xmm1
A200:   test    ecx, 8
        jz      A300
        ; move 8 bytes
        sub     ecx, 8
        movq    xmm0, qword ptr [esi+ecx]
        movq    qword ptr [edi+ecx], xmm0
A300:   test    ecx, 4
        jz      A400
        ; move 4 bytes
        sub     ecx, 4
        mov     eax, [esi+ecx]
        mov     [edi+ecx], eax
        jz      A900                     ; early out if count divisible by 4
A400:   test    ecx, 2
        jz      A500
        ; move 2 bytes
        sub     ecx, 2
        movzx   eax, word ptr [esi+ecx]
        mov     [edi+ecx], ax
A500:   test    ecx, 1
        jz      A900
        ; move 1 byte
        movzx   eax, byte ptr [esi]
        mov     [edi], al
A900:   ; finished
        RETURNM
        
B100:   ; count >= 64
        ; Note: this part will not always work if count < 64
        ; Calculate size of last block after last regular boundary of dest
        lea     edx, [edi+ecx]         ; end of dext
        and     edx, 0FH
        jz      B300                   ; Skip if end of dest aligned by 16
        
        ; edx = size of last partial block, 1 - 15 bytes
        test    edx, 8
        jz      B200
        ; move 8 bytes
        sub     ecx, 8
        movq    xmm0, qword ptr [esi+ecx]
        movq    qword ptr [edi+ecx], xmm0
B200:   test    edx, 4
        jz      B210
        ; move 4 bytes
        sub     ecx, 4
        mov     eax, [esi+ecx]
        mov     [edi+ecx], eax
B210:   test    edx, 2
        jz      B220
        ; move 2 bytes
        sub     ecx, 2
        movzx   eax, word ptr [esi+ecx]
        mov     [edi+ecx], ax
B220:   test    edx, 1
        jz      B300
        ; move 1 byte
        dec     ecx
        movzx   eax, byte ptr [esi+ecx]
        mov     [edi+ecx], al
        
B300:   ; Now end of dest is aligned by 16. Any partial block has been moved        
        ; Find alignment of end of src modulo 16 at this point:
        lea     eax, [esi+ecx]
        and     eax, 0FH
        
        ; Set up for loop moving 32 bytes per iteration:
        mov     edx, ecx               ; Save count
        and     ecx, -20H              ; Round down to nearest multiple of 32
        sub     edx, ecx               ; Remaining data after loop
        sub     esi, eax               ; Nearest preceding aligned block of src
        ; Add the same to esi and edi as we have subtracted from ecx
        add     esi, edx
        add     edi, edx
        
IFNDEF  POSITIONINDEPENDENT
        ; Check if count very big
        cmp     ecx, [_CacheBypassLimit]
        ja      B400                   ; Use non-temporal store if count > _CacheBypassLimit
        
        ; Dispatch to different codes depending on src alignment
        jmp     MAlignmentDispatch[eax*4]

B400:   ; Dispatch to different codes depending on src alignment
        jmp     MAlignmentDispatchNT[eax*4]

ELSE    ; Position-independent code

        ; Check if count very big
        ; Make the following instruction with address relative to RP:
        ; cmp     ecx, [ebx-RP+_CacheBypassLimit]
        PICREFERENCE _CacheBypassLimit, RP, 3BH, 8BH
        ja      B400                   ; Use non-temporal store if count > _CacheBypassLimit
        
        ; Dispatch to different codes depending on src alignment
        ; MAlignmentDispatch table contains addresses relative to RP
        ; Add table entry to ebx=RP to get jump address.

        ; Make the following instruction with address relative to RP:
        ; add ebx,[ebx-RP+MAlignmentDispatch+eax*4]
        PICREFERENCE MAlignmentDispatch, RP, 03H, 9CH, 83H
        jmp     ebx
        
B400:   ; Same with MAlignmentDispatchNT:        
        PICREFERENCE MAlignmentDispatchNT, RP, 03H, 9CH, 83H
        jmp     ebx        
ENDIF

align   16
C100:   ; Code for aligned src. SSE2 or later instruction set
        ; The nice case, src and dest have same alignment.

        ; Loop. ecx has positive index from the beginning, counting down to zero
        sub     ecx, 20H
        movaps  xmm0, [esi+ecx+10H]
        movaps  xmm1, [esi+ecx]
        movaps  [edi+ecx+10H], xmm0
        movaps  [edi+ecx], xmm1
        jnz     C100
        
        ; Move the remaining edx bytes (0 - 31):
        ; move 16-8-4-2-1 bytes, aligned
        test    edx, edx
        jz      C500                   ; Early out if no more data
        test    edx, 10H
        jz      C200
        ; move 16 bytes
        sub     ecx, 10H
        movaps  xmm0, [esi+ecx]
        movaps  [edi+ecx], xmm0
C200:   ; Other branches come in here
        test    edx, edx
        jz      C500                   ; Early out if no more data
        test    edx, 8
        jz      C210        
        ; move 8 bytes
        sub     ecx, 8 
        movq    xmm0, qword ptr [esi+ecx]
        movq    qword ptr [edi+ecx], xmm0
C210:   test    edx, 4
        jz      C220        
        ; move 4 bytes
        sub     ecx, 4        
        mov     eax, [esi+ecx]
        mov     [edi+ecx], eax
        jz      C500                   ; Early out if count divisible by 4
C220:   test    edx, 2
        jz      C230        
        ; move 2 bytes
        sub     ecx, 2
        movzx   eax, word ptr [esi+ecx]
        mov     [edi+ecx], ax
C230:   test    edx, 1
        jz      C500        
        ; move 1 byte
        dec     ecx
        movzx   eax, byte ptr [esi+ecx]
        mov     [edi+ecx], al
C500:   ; finished     
        RETURNM
        
; Code for each src alignment, SSE2 instruction set:
; Make separate code for each alignment u because the shift instructions
; have the shift count as a constant:

MOVE_REVERSE_UNALIGNED_SSE2 MACRO u, nt
; Move ecx + edx bytes of data
; Source is misaligned. (src-dest) modulo 16 = u
; nt = 1 if non-temporal store desired
; eax = u
; esi = src - u = nearest preceding 16-bytes boundary
; edi = dest (aligned)
; ecx = count rounded down to nearest divisible by 32
; edx = remaining bytes to move after loop
LOCAL L1, L2
        movdqa  xmm0, [esi+ecx]        ; Read from nearest following 16B boundary        
L1:     ; Loop. ecx has positive index from the beginning, counting down to zero
        sub     ecx, 20H
        movdqa  xmm1, [esi+ecx+10H]    ; Read next two blocks aligned
        movdqa  xmm2, [esi+ecx]
        movdqa  xmm3, xmm1             ; Copy because used twice
        pslldq  xmm0, 16-u             ; shift left
        psrldq  xmm1, u                ; shift right
        por     xmm0, xmm1             ; combine blocks
        IF nt eq 0
        movdqa  [edi+ecx+10H], xmm0    ; Save aligned
        ELSE
        movntdq [edi+ecx+10H], xmm0    ; Save aligned
        ENDIF
        movdqa  xmm0, xmm2             ; Save for next iteration
        pslldq  xmm3, 16-u             ; shift left
        psrldq  xmm2, u                ; shift right
        por     xmm3, xmm2             ; combine blocks
        IF nt eq 0
        movdqa  [edi+ecx], xmm3        ; Save aligned
        ELSE
        movntdq [edi+ecx], xmm3        ; Save aligned
        ENDIF
        jnz     L1
                
        ; Move edx remaining bytes
        test    edx, 10H
        jz      L2
        ; One more 16-bytes block to move
        sub     ecx, 10H
        movdqa  xmm1, [esi+ecx]
        pslldq  xmm0, 16-u             ; shift left
        psrldq  xmm1, u                ; shift right
        por     xmm0, xmm1             ; combine blocks
        IF nt eq 0
        movdqa  [edi+ecx], xmm0        ; Save aligned
        ELSE
        movntdq [edi+ecx], xmm0        ; Save aligned
        ENDIF        
L2:     ; Get src pointer back to misaligned state
        add     esi, eax
        ; Move remaining 0 - 15 bytes, unaligned
        jmp     C200
ENDM       

MOVE_REVERSE_UNALIGNED_SSE2_4 MACRO nt
; Special case: u = 4
LOCAL L1, L2
        movdqa  xmm0, [esi+ecx]        ; Read from nearest following 16B boundary
L1:     ; Loop. ecx has positive index from the beginning, counting down to zero
        sub     ecx, 20H
        movdqa  xmm1, [esi+ecx+10H]    ; Read next two blocks aligned
        movdqa  xmm2, [esi+ecx]
        movdqa  xmm3, xmm0
        movdqa  xmm0, xmm2        
        movss   xmm2, xmm1
        pshufd  xmm2, xmm2, 00111001B  ; Rotate right
        movss   xmm1, xmm3
        pshufd  xmm1, xmm1, 00111001B  ; Rotate right
        IF nt eq 0
        movdqa  [edi+ecx+10H], xmm1    ; Save aligned
        movdqa  [edi+ecx], xmm2        ; Save aligned
        ELSE
        movntdq [edi+ecx+10H], xmm1    ; Non-temporal save
        movntdq [edi+ecx], xmm2        ; Non-temporal save
        ENDIF
        jnz     L1
                
        ; Move edx remaining bytes
        test    edx, 10H
        jz      L2
        ; One more 16-bytes block to move
        sub     ecx, 10H
        movdqa  xmm1, [esi+ecx]
        movss   xmm1, xmm0
        pshufd  xmm1, xmm1, 00111001B  ; Rotate right
        IF nt eq 0
        movdqa  [edi+ecx], xmm1        ; Save aligned
        ELSE
        movntdq [edi+ecx], xmm1        ; Non-temporal save
        ENDIF        
L2:     ; Get src pointer back to misaligned state
        add     esi, eax
        ; Move remaining 0 - 15 bytes, unaligned
        jmp     C200
ENDM       

MOVE_REVERSE_UNALIGNED_SSE2_8 MACRO nt
; Special case: u = 8
LOCAL L1, L2
        movdqa  xmm0, [esi+ecx]        ; Read from nearest following 16B boundary
        shufps  xmm0, xmm0, 01001110B  ; Rotate
L1:     ; Loop. ecx has positive index from the beginning, counting down to zero
        sub     ecx, 20H
        movdqa  xmm1, [esi+ecx+10H]    ; Read next two blocks aligned
        shufps  xmm1, xmm1, 01001110B  ; Rotate
        movsd   xmm0, xmm1
        IF nt eq 0
        movdqa  [edi+ecx+10H], xmm0    ; Save aligned
        ELSE
        movntdq [edi+ecx+10H], xmm0    ; Non-temporal save
        ENDIF
        movdqa  xmm0, [esi+ecx]
        shufps  xmm0, xmm0, 01001110B  ; Rotate
        movsd   xmm1, xmm0
        IF nt eq 0
        movdqa  [edi+ecx], xmm1        ; Save aligned
        ELSE
        movntdq [edi+ecx], xmm1        ; Non-temporal save
        ENDIF
        jnz     L1
                
        ; Move edx remaining bytes
        test    edx, 10H
        jz      L2
        ; One more 16-bytes block to move
        sub     ecx, 10H
        movdqa  xmm1, [esi+ecx]
        shufps  xmm1, xmm1, 01001110B  ; Rotate 
        movsd   xmm0, xmm1
        IF nt eq 0
        movdqa  [edi+ecx], xmm0        ; Save aligned
        ELSE
        movntdq [edi+ecx], xmm0        ; Non-temporal save
        ENDIF        
L2:     ; Get src pointer back to misaligned state
        add     esi, eax
        ; Move remaining 0 - 15 bytes, unaligned
        jmp     C200
ENDM       

MOVE_REVERSE_UNALIGNED_SSE2_12 MACRO nt
; Special case: u = 12
LOCAL L1, L2
        movdqa  xmm0, [esi+ecx]        ; Read from nearest following 16B boundary
        pshufd  xmm0, xmm0, 10010011B  ; Rotate right
L1:     ; Loop. ecx has positive index from the beginning, counting down to zero
        sub     ecx, 20H
        movdqa  xmm1, [esi+ecx+10H]    ; Read next two blocks aligned
        pshufd  xmm1, xmm1, 10010011B  ; Rotate left
        movss   xmm0, xmm1
        IF nt eq 0
        movdqa  [edi+ecx+10H], xmm0    ; Save aligned
        ELSE
        movntdq [edi+ecx+10H], xmm0    ; Non-temporal save
        ENDIF
        movdqa  xmm0, [esi+ecx]
        pshufd  xmm0, xmm0, 10010011B  ; Rotate left
        movss   xmm1, xmm0
        IF nt eq 0
        movdqa  [edi+ecx], xmm1        ; Save aligned
        ELSE
        movntdq [edi+ecx], xmm1        ; Non-temporal save
        ENDIF
        jnz     L1
                
        ; Move edx remaining bytes
        test    edx, 10H
        jz      L2
        ; One more 16-bytes block to move
        sub     ecx, 10H
        movdqa  xmm1, [esi+ecx]
        pshufd  xmm1, xmm1, 10010011B  ; Rotate left
        movss   xmm0, xmm1
        IF nt eq 0
        movdqa  [edi+ecx], xmm0        ; Save aligned
        ELSE
        movntdq [edi+ecx], xmm0        ; Non-temporal save
        ENDIF        
L2:     ; Get src pointer back to misaligned state
        add     esi, eax
        ; Move remaining 0 - 15 bytes, unaligned
        jmp     C200
ENDM       

; Code for each src alignment, Suppl.SSE3 instruction set:
; Code for unaligned src, Suppl.SSE3 instruction set.
; Make separate code for each alignment u because the palignr instruction
; has the shift count as a constant:

MOVE_REVERSE_UNALIGNED_SSSE3 MACRO u
; Move ecx + edx bytes of data
; Source is misaligned. (src-dest) modulo 16 = u
; eax = u
; esi = src - u = nearest preceding 16-bytes boundary
; edi = dest (aligned)
; ecx = - (count rounded down to nearest divisible by 32)
; edx = remaining bytes to move after loop
LOCAL L1, L2
        movdqa  xmm0, [esi+ecx]        ; Read from nearest following 16B boundary
        
L1:     ; Loop. ecx has positive index from the beginning, counting down to zero
        sub     ecx, 20H
        movdqa  xmm1, [esi+ecx+10H]    ; Read next two blocks        
        palignr xmm0, xmm1, u          ; Combine parts into aligned block
        movdqa  [edi+ecx+10H], xmm0    ; Save aligned
        movdqa  xmm0, [esi+ecx]
        palignr xmm1, xmm0, u          ; Combine parts into aligned block
        movdqa  [edi+ecx], xmm1        ; Save aligned
        jnz     L1
        
        ; Set up for edx remaining bytes
        test    edx, 10H
        jz      L2
        ; One more 16-bytes block to move
        sub     ecx, 10H
        movdqa  xmm1, [esi+ecx]        ; Read next two blocks        
        palignr xmm0, xmm1, u          ; Combine parts into aligned block
        movdqa  [edi+ecx], xmm0        ; Save aligned
        
L2:     ; Get src pointer back to misaligned state
        add     esi, eax
        ; Move remaining 0 - 15 bytes
        jmp     C200
ENDM        

; Make 15 instances of SSE2 macro for each value of the alignment u.
; These are pointed to by the jump table MAlignmentDispatchSSE2 below
; (aligns and dummy instructions are inserted manually to minimize the 
;  number of 16-bytes boundaries inside loops)

D104:   MOVE_REVERSE_UNALIGNED_SSE2_4    0
mov eax,eax
mov eax,eax
D108:   MOVE_REVERSE_UNALIGNED_SSE2_8    0
D10C:   MOVE_REVERSE_UNALIGNED_SSE2_12   0

align 16
nop
align 8
lea eax,[eax+1]
D101:   MOVE_REVERSE_UNALIGNED_SSE2 1,   0
mov eax,eax
D102:   MOVE_REVERSE_UNALIGNED_SSE2 2,   0
mov eax,eax
D103:   MOVE_REVERSE_UNALIGNED_SSE2 3,   0
mov eax,eax
D105:   MOVE_REVERSE_UNALIGNED_SSE2 5,   0
mov eax,eax
D106:   MOVE_REVERSE_UNALIGNED_SSE2 6,   0
mov eax,eax
D107:   MOVE_REVERSE_UNALIGNED_SSE2 7,   0
mov eax,eax
D109:   MOVE_REVERSE_UNALIGNED_SSE2 9,   0
mov eax,eax
D10A:   MOVE_REVERSE_UNALIGNED_SSE2 0AH, 0
mov eax,eax
D10B:   MOVE_REVERSE_UNALIGNED_SSE2 0BH, 0
mov eax,eax
D10D:   MOVE_REVERSE_UNALIGNED_SSE2 0DH, 0
mov eax,eax
D10E:   MOVE_REVERSE_UNALIGNED_SSE2 0EH, 0
mov eax,eax
D10F:   MOVE_REVERSE_UNALIGNED_SSE2 0FH, 0

; Make 15 instances of Sup.SSE3 macro for each value of the alignment u.
; These are pointed to by the jump table MAlignmentDispatchSupSSE3 below

mov eax,eax
E101:   MOVE_REVERSE_UNALIGNED_SSSE3 1
mov eax,eax
E102:   MOVE_REVERSE_UNALIGNED_SSSE3 2
mov eax,eax
E103:   MOVE_REVERSE_UNALIGNED_SSSE3 3
mov eax,eax
E104:   MOVE_REVERSE_UNALIGNED_SSSE3 4
mov eax,eax
E105:   MOVE_REVERSE_UNALIGNED_SSSE3 5
mov eax,eax
E106:   MOVE_REVERSE_UNALIGNED_SSSE3 6
mov eax,eax
E107:   MOVE_REVERSE_UNALIGNED_SSSE3 7
mov eax,eax
E108:   MOVE_REVERSE_UNALIGNED_SSSE3 8
mov eax,eax
E109:   MOVE_REVERSE_UNALIGNED_SSSE3 9
mov eax,eax
E10A:   MOVE_REVERSE_UNALIGNED_SSSE3 0AH
mov eax,eax
E10B:   MOVE_REVERSE_UNALIGNED_SSSE3 0BH
mov eax,eax
E10C:   MOVE_REVERSE_UNALIGNED_SSSE3 0CH
mov eax,eax
E10D:   MOVE_REVERSE_UNALIGNED_SSSE3 0DH
mov eax,eax
E10E:   MOVE_REVERSE_UNALIGNED_SSSE3 0EH
mov eax,eax
E10F:   MOVE_REVERSE_UNALIGNED_SSSE3 0FH

        
F100:   ; Non-temporal move, src and dest have same alignment.
        ; Loop. ecx has positive index from the beginning, counting down to zero
        sub     ecx, 20H
        movaps  xmm0, [esi+ecx+10H]
        movaps  xmm1, [esi+ecx]
        movntps [edi+ecx+10H], xmm0
        movntps [edi+ecx], xmm1
        jnz     F100
        
        ; Move the remaining edx bytes (0 - 31):
        ; move 16-8-4-2-1 bytes, aligned
        test    edx, 10H
        jz      C200
        ; move 16 bytes
        sub     ecx, 10H
        movaps  xmm0, [esi+ecx]
        movntps  [edi+ecx], xmm0
        ; move the remaining 0 - 15 bytes
        jmp     C200

; Non-temporal move, src and dest have different alignment.
; Make 15 instances of SSE2 macro for each value of the alignment u.
; These are pointed to by the jump table MAlignmentDispatchNT below

F101:   MOVE_REVERSE_UNALIGNED_SSE2 1,   1
F102:   MOVE_REVERSE_UNALIGNED_SSE2 2,   1
F103:   MOVE_REVERSE_UNALIGNED_SSE2 3,   1
F104:   MOVE_REVERSE_UNALIGNED_SSE2_4    1
F105:   MOVE_REVERSE_UNALIGNED_SSE2 5,   1
F106:   MOVE_REVERSE_UNALIGNED_SSE2 6,   1
F107:   MOVE_REVERSE_UNALIGNED_SSE2 7,   1
F108:   MOVE_REVERSE_UNALIGNED_SSE2_8    1
F109:   MOVE_REVERSE_UNALIGNED_SSE2 9,   1
F10A:   MOVE_REVERSE_UNALIGNED_SSE2 0AH, 1
F10B:   MOVE_REVERSE_UNALIGNED_SSE2 0BH, 1
F10C:   MOVE_REVERSE_UNALIGNED_SSE2_12   1
F10D:   MOVE_REVERSE_UNALIGNED_SSE2 0DH, 1
F10E:   MOVE_REVERSE_UNALIGNED_SSE2 0EH, 1
F10F:   MOVE_REVERSE_UNALIGNED_SSE2 0FH, 1

IFDEF   POSITIONINDEPENDENT
get_thunk_ebx: ; load caller address into ebx for position-independent code
        mov ebx, [esp]
        ret
ENDIF

; 80386 version used when SSE2 not supported:
memmove386:
; edi = dest
; esi = src
; ecx = count
        std                            ; Move backwards
        lea     edi, [edi+ecx-1]       ; Point to last byte of dest
        lea     esi, [esi+ecx-1]       ; Point to last byte of src
        cmp     ecx, 8
        jb      G500
G100:   test    edi, 3                 ; Test if unaligned
        jz      G200
        movsb
        dec     ecx
        jmp     G100                   ; Repeat while edi unaligned
        
G200:   ; edi is aligned now. Move 4 bytes at a time
        sub     edi, 3                 ; Point to last dword of dest
        sub     esi, 3                 ; Point to last dword of src
        mov     edx, ecx
        shr     ecx, 2
        rep     movsd                  ; move 4 bytes at a time
        mov     ecx, edx
        and     ecx, 3
        add     edi, 3                 ; Point to last byte of dest
        add     esi, 3                 ; Point to last byte of src        
        rep     movsb                  ; move remaining 0-3 bytes
        cld
        RETURNM
        
G500:   ; count < 8. Move one byte at a time
        rep     movsb                  ; move count bytes
        cld
        RETURNM


; CPU dispatching for memmove. This is executed only once
memmoveCPUDispatch:
IFNDEF   POSITIONINDEPENDENT
        pushad
        call    _InstructionSet
        ; Point to generic version of memmove
        mov     [memmoveDispatch], offset memmove386
        cmp     eax, 4                 ; check SSE2
        jb      M100
        ; SSE2 supported
        ; Point to SSE2 and later version of memmove
        mov     [memmoveDispatch], offset memmoveSSE2
        cmp     eax, 6                 ; check Suppl-SSE3
        jb      M100
        ; Suppl-SSE3 supported
        ; Replace SSE2 alignment dispatch table with Suppl-SSE3 version        
        mov     esi, offset MAlignmentDispatchSupSSE3
        mov     edi, offset MAlignmentDispatchSSE2
        mov     ecx, 16
        cld
        rep     movsd
M100:   popad
        ; Continue in appropriate version of memmove
        jmp     [memmoveDispatch]

ELSE    ; Position-independent version
        pushad
        call    _InstructionSet
        
; Make the following instruction with address relative to RP:
; lea edx, [ebx-RP+memmoveCPUVersion]
PICREFERENCE memmoveCPUVersion, RP, 8DH, 93H
; Now edx points to memmoveCPUVersion. Use edx as reference to data segment

        mov     byte ptr [edx], 1      ; Indicate generic version
        cmp     eax, 4                 ; check SSE2
        jb      M100
        ; SSE2 supported
        mov     byte ptr [edx], 2      ; Indicate SSE2 or later version
        cmp     eax, 6                 ; check Suppl-SSE3
        jb      M100
        ; Suppl-SSE3 supported
        ; Replace alignment dispatch table with Suppl-SSE3 version        
        lea     esi, [edx][MAlignmentDispatchSupSSE3-memmoveCPUVersion]
        lea     edi, [edx][MAlignmentDispatchSSE2-memmoveCPUVersion]
        mov     ecx, 16
        cld
        rep     movsd
M100:   popad
        jmp     A020                   ; Go back and dispatch
        
ENDIF


; Data segment must be included in function namespace
.data

; Jump tables for alignments 0 - 15:
; The CPU dispatcher replaces MAlignmentDispatchSSE2 with 
; MAlignmentDispatchSupSSE3 if Suppl-SSE3 is supported
; RP = reference point if position-independent code, otherwise RP = 0

MAlignmentDispatch label dword
MAlignmentDispatchSSE2 label dword
DD C100-RP, D101-RP, D102-RP, D103-RP, D104-RP, D105-RP, D106-RP, D107-RP
DD D108-RP, D109-RP, D10A-RP, D10B-RP, D10C-RP, D10D-RP, D10E-RP, D10F-RP

MAlignmentDispatchSupSSE3 label dword
DD C100-RP, E101-RP, E102-RP, E103-RP, E104-RP, E105-RP, E106-RP, E107-RP
DD E108-RP, E109-RP, E10A-RP, E10B-RP, E10C-RP, E10D-RP, E10E-RP, E10F-RP

MAlignmentDispatchNT label dword
DD F100-RP, F101-RP, F102-RP, F103-RP, F104-RP, F105-RP, F106-RP, F107-RP
DD F108-RP, F109-RP, F10A-RP, F10B-RP, F10C-RP, F10D-RP, F10E-RP, F10F-RP

IFNDEF  POSITIONINDEPENDENT
; Pointer to appropriate version.
; This initially points to memmoveCPUDispatch. memmoveCPUDispatch will
; change this to the appropriate version of memmove, so that
; memmoveCPUDispatch is only executed once:
memmoveDispatch DD memmoveCPUDispatch
ELSE
; CPU version: 0=unknown, 1=80386, 2=SSE2 or later
memmoveCPUVersion DD 0
ENDIF


.code

_A_memmove ENDP                        ; End of function namespace

END
