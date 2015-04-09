;*************************  memcpy64.asm  ************************************
; Author:           Agner Fog
; Date created:     2008-07-19
; Last modified:    2008-07-19
; Description:
; Faster version of the standard memcpy function:
; void * A_memcpy(void * dest, const void * src, size_t count);
; Copies 'count' bytes from 'src' to 'dest'
;
; Overriding standard function memcpy:
; The alias ?OVR_memcpy is changed to memcpy in the object file if
; it is desired to override the standard library function memcpy.
;
; Calling conventions: 
; Stack alignment is not required. No shadow space or red zone used.
; Called internally from strcpy and strcat without stack aligned.
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
; CPU dispatching included for SSE2 and Suppl-SSE3 instruction sets.
;
; Future extensions:
; Implementations for the AMD SSE5 and Intel AVX instruction sets are 
; illustrated in www.agner.org/optimize/asmexamples.zip
;
; Copyright (c) 2008 GNU General Public License www.gnu.org/licenses/gpl.html
;******************************************************************************

public A_memcpy                        ; Function A_memcpy
public ?OVR_memcpy                     ; ?OVR removed if standard function memcpy overridden
public $memcpyEntry2                   ; Entry from memmove
public CacheBypassLimit                ; Bypass cache if count > _CacheBypassLimit


; Imported from instrset64.asm
extern InstructionSet: near            ; Instruction set for CPU dispatcher

; Define return from this function
RETURNM MACRO
IFDEF   WINDOWS
        pop     rdi
        pop     rsi
ENDIF
        mov     rax, r9                ; Return value = dest
        ret
ENDM


.code

; extern "C" void * A_memcpy(void * dest, const void * src, size_t count);
; Function entry:
A_memcpy PROC
?OVR_memcpy LABEL NEAR
IFDEF   WINDOWS
        push    rsi
        push    rdi
        mov     rdi, rcx               ; dest
        mov     r9,  rcx               ; dest
        mov     rsi, rdx               ; src
        mov     rcx, r8                ; count
ELSE    ; Unix
        mov     rcx, rdx               ; count
        mov     r9,  rdi               ; dest
ENDIF
$memcpyEntry2   label near             ; Entry from memmove

        cmp     rcx, 40H
        jae     B100                   ; Use simpler code if count < 64
        
        ; count < 64. Move 32-16-8-4-2-1 bytes
        add     rsi, rcx               ; end of src
        add     rdi, rcx               ; end of dest
        neg     rcx                    ; negative index from the end
        cmp     ecx, -20H
        jg      A100        
        ; move 32 bytes
        ; mov is faster than movdqu on current processors (2008),
        ; movdqu may be faster on future processors
        mov     rax, [rsi+rcx]
        mov     rdx, [rsi+rcx+8]
        mov     [rdi+rcx], rax
        mov     [rdi+rcx+8], rdx
        mov     rax, qword ptr [rsi+rcx+10H]
        mov     rdx, qword ptr [rsi+rcx+18H]
        mov     qword ptr [rdi+rcx+10H], rax
        mov     qword ptr [rdi+rcx+18H], rdx
        add     rcx, 20H
A100:   cmp     ecx, -10H        
        jg      A200
        ; move 16 bytes
        mov     rax, [rsi+rcx]
        mov     rdx, [rsi+rcx+8]
        mov     [rdi+rcx], rax
        mov     [rdi+rcx+8], rdx
        add     rcx, 10H
A200:   cmp     ecx, -8        
        jg      A300
        ; move 8 bytes
        mov     rax, qword ptr [rsi+rcx]
        mov     qword ptr [rdi+rcx], rax
        add     rcx, 8
A300:   cmp     ecx, -4        
        jg      A400
        ; move 4 bytes
        mov     eax, [rsi+rcx]
        mov     [rdi+rcx], eax
        add     rcx, 4
        jz      A900                     ; early out if count divisible by 4
A400:   cmp     ecx, -2        
        jg      A500
        ; move 2 bytes
        movzx   eax, word ptr [rsi+rcx]
        mov     [rdi+rcx], ax
        add     rcx, 2
A500:   cmp     ecx, -1
        jg      A900        
        ; move 1 byte
        movzx   eax, byte ptr [rsi+rcx]
        mov     [rdi+rcx], al
A900:   ; finished
        RETURNM        
        
B100:   ; count >= 64
        ; Note: this part will not always work if count < 64
        ; Calculate size of first block up to first regular boundary of dest
        mov     edx, edi
        neg     edx
        and     edx, 0FH
        jz      B300                    ; Skip if dest aligned by 16
        
        ; rdx = size of first partial block, 1 - 15 bytes
        add     rsi, rdx
        add     rdi, rdx
        sub     rcx, rdx
        neg     rdx
        cmp     edx, -8
        jg      B200
        ; move 8 bytes
        mov     rax, [rsi+rdx]
        mov     [rdi+rdx], rax
        add     rdx, 8
B200:   cmp     edx, -4        
        jg      B210
        ; move 4 bytes
        mov     eax, [rsi+rdx]
        mov     [rdi+rdx], eax
        add     rdx, 4
B210:   cmp     edx, -2        
        jg      B220
        ; move 2 bytes
        movzx   eax, word ptr [rsi+rdx]
        mov     [rdi+rdx], ax
        add     rdx, 2
B220:   cmp     edx, -1
        jg      B300
        ; move 1 byte
        movzx   eax, byte ptr [rsi+rdx]
        mov     [rdi+rdx], al
        
B300:   ; Now dest is aligned by 16. Any partial block has been moved        
        ; Find alignment of src modulo 16 at this point:
        mov     eax, esi
        and     eax, 0FH
        
        ; Set up for loop moving 32 bytes per iteration:
        mov     edx, ecx               ; Save count (lower 32 bits)
        and     rcx, -20H              ; Round down count to nearest multiple of 32
        add     rsi, rcx               ; Point to the end
        add     rdi, rcx               ; Point to the end
        sub     edx, ecx               ; Remaining data after loop (0-31)
        sub     rsi, rax               ; Nearest preceding aligned block of src

        ; Check if count very big
        cmp     rcx, [CacheBypassLimit]
        ja      B400                   ; Use non-temporal store if count > CacheBypassLimit
        neg     rcx                    ; Negative index from the end
        
        ; Dispatch to different codes depending on src alignment
        lea     r8, AlignmentDispatch
        jmp     qword ptr [r8+rax*8]

B400:   neg     rcx
        ; Dispatch to different codes depending on src alignment
        lea     r8, AlignmentDispatchNT
        jmp     qword ptr [r8+rax*8]
        

align   16
C100:   ; Code for aligned src.
        ; The nice case, src and dest have same alignment.

        ; Loop. rcx has negative index from the end, counting up to zero
        movaps  xmm0, [rsi+rcx]
        movaps  xmm1, [rsi+rcx+10H]
        movaps  [rdi+rcx], xmm0
        movaps  [rdi+rcx+10H], xmm1
        add     rcx, 20H
        jnz     C100
        
        ; Move the remaining edx bytes (0 - 31):
        add     rsi, rdx
        add     rdi, rdx
        neg     rdx
        jz      C500                   ; Skip if no more data
        ; move 16-8-4-2-1 bytes, aligned
        cmp     edx, -10H
        jg      C200
        ; move 16 bytes
        movaps  xmm0, [rsi+rdx]
        movaps  [rdi+rdx], xmm0
        add     rdx, 10H
C200:   cmp     edx, -8
        jg      C210        
        ; move 8 bytes
        mov     rax, [rsi+rdx]
        mov     [rdi+rdx], rax
        add     rdx, 8 
        jz      C500                   ; Early skip if count divisible by 8       
C210:   cmp     edx, -4
        jg      C220        
        ; move 4 bytes
        mov     eax, [rsi+rdx]
        mov     [rdi+rdx], eax
        add     rdx, 4        
C220:   cmp     edx, -2
        jg      C230        
        ; move 2 bytes
        movzx   eax, word ptr [rsi+rdx]
        mov     [rdi+rdx], ax
        add     rdx, 2
C230:   cmp     edx, -1
        jg      C500        
        ; move 1 byte
        movzx   eax, byte ptr [rsi+rdx]
        mov     [rdi+rdx], al
C500:   ; finished     
        RETURNM
        
       
; Code for each src alignment, SSE2 instruction set:
; Make separate code for each alignment u because the shift instructions
; have the shift count as a constant:

MOVE_UNALIGNED_SSE2 MACRO u, nt
; Move rcx + rdx bytes of data
; Source is misaligned. (src-dest) modulo 16 = u
; nt = 1 if non-temporal store desired
; eax = u
; rsi = src - u = nearest preceding 16-bytes boundary
; rdi = dest (aligned)
; rcx = - (count rounded down to nearest divisible by 32)
; edx = remaining bytes to move after loop
LOCAL L1, L2
        movdqa  xmm0, [rsi+rcx]        ; Read from nearest preceding 16B boundary
L1:    ; Loop. rcx has negative index from the end, counting up to zero
        movdqa  xmm1, [rsi+rcx+10H]    ; Read next two blocks aligned
        movdqa  xmm2, [rsi+rcx+20H]
        movdqa  xmm3, xmm1             ; Copy because used twice
        psrldq  xmm0, u                ; shift right
        pslldq  xmm1, 16-u             ; shift left
        por     xmm0, xmm1             ; combine blocks
        IF nt eq 0
        movdqa  [rdi+rcx], xmm0        ; Save aligned
        ELSE
        movntdq [rdi+rcx], xmm0        ; non-temporal save
        ENDIF
        movdqa  xmm0, xmm2             ; Save for next iteration
        psrldq  xmm3, u                ; shift right
        pslldq  xmm2, 16-u             ; shift left
        por     xmm3, xmm2             ; combine blocks
        IF nt eq 0
        movdqa  [rdi+rcx+10H], xmm3    ; Save aligned
        ELSE
        movntdq [rdi+rcx+10H], xmm3    ; non-temporal save
        ENDIF
        add     rcx, 20H               ; Loop through negative values up to zero
        jnz     L1
        
        ; Set up for edx remaining bytes
        add     rsi, rdx
        add     rdi, rdx
        neg     rdx
        cmp     edx, -10H
        jg      L2
        ; One more 16-bytes block to move
        movdqa  xmm1, [rsi+rdx+10H]
        psrldq  xmm0, u                ; shift right
        pslldq  xmm1, 16-u             ; shift left
        por     xmm0, xmm1             ; combine blocks
        IF nt eq 0
        movdqa  [rdi+rdx], xmm0        ; Save aligned
        ELSE
        movntdq [rdi+rdx], xmm0        ; non-temporal save
        ENDIF        
        add     rdx, 10H        
L2:     ; Get src pointer back to misaligned state
        add     rsi, rax
        ; Move remaining 0 - 15 bytes, unaligned
        jmp     C200
ENDM

MOVE_UNALIGNED_SSE2_4 MACRO nt
; Special case for u = 4
LOCAL L1, L2
        movaps  xmm0, [rsi+rcx]        ; Read from nearest preceding 16B boundary
L1:     ; Loop. rcx has negative index from the end, counting up to zero
        movaps  xmm1, [rsi+rcx+10H]    ; Read next two blocks aligned
        movss   xmm0, xmm1             ; Moves 4 bytes, leaves remaining bytes unchanged
        pshufd  xmm0, xmm0, 00111001B  ; Rotate
        IF nt eq 0
        movdqa  [rdi+rcx], xmm0        ; Save aligned
        ELSE
        movntdq [rdi+rcx], xmm0        ; Non-temporal save
        ENDIF
        movaps  xmm0, [rsi+rcx+20H]
        movss   xmm1, xmm0
        pshufd  xmm1, xmm1, 00111001B
        IF nt eq 0
        movdqa  [rdi+rcx+10H], xmm1    ; Save aligned
        ELSE
        movntdq [rdi+rcx+10H], xmm1    ; Non-temporal save
        ENDIF
        add     rcx, 20H               ; Loop through negative values up to zero
        jnz     L1        
        ; Set up for edx remaining bytes
        add     rsi, rdx
        add     rdi, rdx
        neg     rdx
        cmp     edx, -10H
        jg      L2
        ; One more 16-bytes block to move
        movaps  xmm1, [rsi+rdx+10H]    ; Read next two blocks aligned
        movss   xmm0, xmm1
        pshufd  xmm0, xmm0, 00111001B
        IF nt eq 0
        movdqa  [rdi+rdx], xmm0        ; Save aligned
        ELSE
        movntdq [rdi+rdx], xmm0        ; Non-temporal save
        ENDIF
        add     rdx, 10H        
L2:     ; Get src pointer back to misaligned state
        add     rsi, rax
        ; Move remaining 0 - 15 bytes, unaligned
        jmp     C200
ENDM 

MOVE_UNALIGNED_SSE2_8 MACRO nt
; Special case for u = 8
LOCAL L1, L2
        movaps  xmm0, [rsi+rcx]        ; Read from nearest preceding 16B boundary
L1:     ; Loop. rcx has negative index from the end, counting up to zero
        movaps  xmm1, [rsi+rcx+10H]    ; Read next two blocks aligned
        movsd   xmm0, xmm1             ; Moves 8 bytes, leaves remaining bytes unchanged
        shufps  xmm0, xmm0, 01001110B  ; Rotate
        IF nt eq 0
        movdqa  [rdi+rcx], xmm0        ; Save aligned
        ELSE
        movntdq [rdi+rcx], xmm0        ; Non-temporal save
        ENDIF
        movaps  xmm0, [rsi+rcx+20H]
        movsd   xmm1, xmm0
        shufps  xmm1, xmm1, 01001110B
        IF nt eq 0
        movdqa  [rdi+rcx+10H], xmm1    ; Save aligned
        ELSE
        movntdq [rdi+rcx+10H], xmm1    ; Non-temporal save
        ENDIF
        add     rcx, 20H               ; Loop through negative values up to zero
        jnz     L1        
        ; Set up for edx remaining bytes
        add     rsi, rdx
        add     rdi, rdx
        neg     rdx
        cmp     edx, -10H
        jg      L2
        ; One more 16-bytes block to move
        movaps  xmm1, [rsi+rdx+10H]    ; Read next two blocks aligned
        movsd   xmm0, xmm1
        shufps  xmm0, xmm0, 01001110B
        IF nt eq 0
        movdqa  [rdi+rdx], xmm0        ; Save aligned
        ELSE
        movntdq [rdi+rdx], xmm0        ; Non-temporal save
        ENDIF
        add     rdx, 10H        
L2:     ; Get src pointer back to misaligned state
        add     rsi, rax
        ; Move remaining 0 - 15 bytes, unaligned
        jmp     C200
ENDM 

MOVE_UNALIGNED_SSE2_12 MACRO nt
; Special case for u = 12
LOCAL L1, L2
        movaps  xmm0, [rsi+rcx]        ; Read from nearest preceding 16B boundary
        pshufd  xmm0, xmm0, 10010011B
L1:     ; Loop. rcx has negative index from the end, counting up to zero
        movaps  xmm1, [rsi+rcx+10H]    ; Read next two blocks aligned
        movaps  xmm2, [rsi+rcx+20H]
        pshufd  xmm1, xmm1, 10010011B
        pshufd  xmm2, xmm2, 10010011B
        movaps  xmm3, xmm2
        movss   xmm2, xmm1             ; Moves 4 bytes, leaves remaining bytes unchanged
        movss   xmm1, xmm0             ; Moves 4 bytes, leaves remaining bytes unchanged       
        IF nt eq 0
        movdqa  [rdi+rcx], xmm1        ; Save aligned
        movdqa  [rdi+rcx+10H], xmm2    ; Save aligned
        ELSE
        movntdq [rdi+rcx], xmm1        ; Non-temporal save
        movntdq [rdi+rcx+10H], xmm2    ; Non-temporal save
        ENDIF
        movaps  xmm0, xmm3             ; Save for next iteration        
        add     rcx, 20H               ; Loop through negative values up to zero
        jnz     L1        
        ; Set up for edx remaining bytes
        add     rsi, rdx
        add     rdi, rdx
        neg     rdx
        cmp     edx, -10H
        jg      L2
        ; One more 16-bytes block to move
        movaps  xmm1, [rsi+rdx+10H]    ; Read next two blocks aligned
        pshufd  xmm1, xmm1, 10010011B
        movss   xmm1, xmm0             ; Moves 4 bytes, leaves remaining bytes unchanged       
        IF nt eq 0
        movdqa  [rdi+rdx], xmm1        ; Save aligned
        ELSE
        movntdq [rdi+rdx], xmm1        ; Non-temporal save
        ENDIF
        add     rdx, 10H        
L2:     ; Get src pointer back to misaligned state
        add     rsi, rax
        ; Move remaining 0 - 15 bytes, unaligned
        jmp     C200
ENDM 

; Code for each src alignment, Suppl.SSE3 instruction set:
; Make separate code for each alignment u because the palignr instruction
; has the shift count as a constant:

MOVE_UNALIGNED_SSSE3 MACRO u
; Move rcx + rdx bytes of data
; Source is misaligned. (src-dest) modulo 16 = u
; eax = u
; rsi = src - u = nearest preceding 16-bytes boundary
; rdi = dest (aligned)
; rcx = - (count rounded down to nearest divisible by 32)
; edx = remaining bytes to move after loop
LOCAL L1, L2
        movdqa  xmm0, [rsi+rcx]        ; Read from nearest preceding 16B boundary
        
L1:     ; Loop. rcx has negative index from the end, counting up to zero
        movdqa  xmm2, [rsi+rcx+10H]    ; Read next two blocks
        movdqa  xmm3, [rsi+rcx+20H]
        movdqa  xmm1, xmm0             ; Save xmm0
        movdqa  xmm0, xmm3             ; Save for next iteration
        palignr xmm3, xmm2, u          ; Combine parts into aligned block
        palignr xmm2, xmm1, u          ; Combine parts into aligned block
        movdqa  [rdi+rcx], xmm2        ; Save aligned
        movdqa  [rdi+rcx+10H], xmm3    ; Save aligned
        add     rcx, 20H
        jnz     L1
        
        ; Set up for edx remaining bytes
        add     rsi, rdx
        add     rdi, rdx
        neg     rdx
        cmp     edx, -10H
        jg      L2
        ; One more 16-bytes block to move
        movdqa  xmm2, [rsi+rdx+10H]
        palignr xmm2, xmm0, u
        movdqa  [rdi+rdx], xmm2
        add     rdx, 10H        
L2:     ; Get src pointer back to misaligned state
        add     rsi, rax
        ; Move remaining 0 - 15 bytes
        jmp     C200
ENDM        

; Make 15 instances of SSE2 macro for each value of the alignment u.
; These are pointed to by the jump table AlignmentDispatchSSE2 below
; (alignments are inserted manually to minimize the number of 16-bytes
;  boundaries inside loops)

D101:   MOVE_UNALIGNED_SSE2 1,   0
D102:   MOVE_UNALIGNED_SSE2 2,   0
D103:   MOVE_UNALIGNED_SSE2 3,   0
D104:   MOVE_UNALIGNED_SSE2_4    0
D105:   MOVE_UNALIGNED_SSE2 5,   0
D106:   MOVE_UNALIGNED_SSE2 6,   0
D107:   MOVE_UNALIGNED_SSE2 7,   0
align   4
D108:   MOVE_UNALIGNED_SSE2_8    0
D109:   MOVE_UNALIGNED_SSE2 9,   0
D10A:   MOVE_UNALIGNED_SSE2 0AH, 0
D10B:   MOVE_UNALIGNED_SSE2 0BH, 0
D10C:   MOVE_UNALIGNED_SSE2_12   0
align   8
D10D:   MOVE_UNALIGNED_SSE2 0DH, 0
D10E:   MOVE_UNALIGNED_SSE2 0EH, 0
D10F:   MOVE_UNALIGNED_SSE2 0FH, 0
        
; Make 15 instances of Suppl-SSE3 macro for each value of the alignment u.
; These are pointed to by the jump table AlignmentDispatchSupSSE3 below

align   8
E101:   MOVE_UNALIGNED_SSSE3 1
E102:   MOVE_UNALIGNED_SSSE3 2
E103:   MOVE_UNALIGNED_SSSE3 3
E104:   MOVE_UNALIGNED_SSSE3 4
E105:   MOVE_UNALIGNED_SSSE3 5
E106:   MOVE_UNALIGNED_SSSE3 6
E107:   MOVE_UNALIGNED_SSSE3 7
E108:   MOVE_UNALIGNED_SSSE3 8
E109:   MOVE_UNALIGNED_SSSE3 9
E10A:   MOVE_UNALIGNED_SSSE3 0AH
E10B:   MOVE_UNALIGNED_SSSE3 0BH
align 8
E10C:   MOVE_UNALIGNED_SSSE3 0CH
E10D:   MOVE_UNALIGNED_SSSE3 0DH
E10E:   MOVE_UNALIGNED_SSSE3 0EH
E10F:   MOVE_UNALIGNED_SSSE3 0FH

; Codes for non-temporal move. Aligned case first

F100:   ; Non-temporal move, src and dest have same alignment.
        ; Loop. rcx has negative index from the end, counting up to zero
        movaps  xmm0, [rsi+rcx]        ; Read
        movaps  xmm1, [rsi+rcx+10H]
        movntps [rdi+rcx], xmm0        ; Write non-temporal (bypass cache)
        movntps [rdi+rcx+10H], xmm1
        add     rcx, 20H
        jnz     F100                   ; Loop through negative rcx up to zero
                
        ; Move the remaining edx bytes (0 - 31):
        add     rsi, rdx
        add     rdi, rdx
        neg     rdx
        jz      C500                   ; Skip if no more data
        ; Check if we can more one more 16-bytes block
        cmp     edx, -10H
        jg      C200
        ; move 16 bytes, aligned
        movaps  xmm0, [rsi+rdx]
        movntps [rdi+rdx], xmm0
        add     rdx, 10H
        ; move the remaining 0 - 15 bytes
        jmp     C200

; Make 15 instances of MOVE_UNALIGNED_SSE2 macro for each value of 
; the alignment u.
; These are pointed to by the jump table AlignmentDispatchNT below

F101:   MOVE_UNALIGNED_SSE2 1,   1
F102:   MOVE_UNALIGNED_SSE2 2,   1
F103:   MOVE_UNALIGNED_SSE2 3,   1
F104:   MOVE_UNALIGNED_SSE2_4    1
F105:   MOVE_UNALIGNED_SSE2 5,   1
F106:   MOVE_UNALIGNED_SSE2 6,   1
F107:   MOVE_UNALIGNED_SSE2 7,   1
F108:   MOVE_UNALIGNED_SSE2_8    1
F109:   MOVE_UNALIGNED_SSE2 9,   1
F10A:   MOVE_UNALIGNED_SSE2 0AH, 1
F10B:   MOVE_UNALIGNED_SSE2 0BH, 1
F10C:   MOVE_UNALIGNED_SSE2_12   1
F10D:   MOVE_UNALIGNED_SSE2 0DH, 1
F10E:   MOVE_UNALIGNED_SSE2 0EH, 1
F10F:   MOVE_UNALIGNED_SSE2 0FH, 1

        
Q100:   ; CPU dispatcher, check for Suppl-SSE3 instruction set
        ; This part is executed only once, optimized for size
        push    rax
        push    rbx
        push    rcx
        push    rdx
        push    rsi
        push    rdi
        mov     eax, 1
        cpuid                          ; Get feature flags
        lea     rsi, AlignmentDispatchSSE2
        bt      ecx, 9                 ; Test bit for SupSSE3
        jnc     Q200
        lea     rsi, AlignmentDispatchSupSSE3
Q200:   ; Insert appropriate table
        mov     rdi, r8
        mov     ecx, 16
        rep     movsq
        pop     rdi
        pop     rsi
        pop     rdx
        pop     rcx
        pop     rbx
        pop     rax
        ; Jump according to the replaced table
        jmp     qword ptr [r8+rax*8]


; Data segment must be included in function namespace
.data

; Jump tables for alignments 0 - 15:
; The CPU dispatcher replaces AlignmentDispatch with 
; AlignmentDispatchSSE2 or AlignmentDispatchSupSSE3 if Suppl-SSE3 
; is supported.

AlignmentDispatch label qword
DQ Q100, Q100, Q100, Q100, Q100, Q100, Q100, Q100
DQ Q100, Q100, Q100, Q100, Q100, Q100, Q100, Q100

; Code pointer for each alignment for SSE2 instruction set
AlignmentDispatchSSE2 label qword
DQ C100, D101, D102, D103, D104, D105, D106, D107
DQ D108, D109, D10A, D10B, D10C, D10D, D10E, D10F

; Code pointer for each alignment for Suppl-SSE3 instruction set
AlignmentDispatchSupSSE3 label qword
DQ C100, E101, E102, E103, E104, E105, E106, E107
DQ E108, E109, E10A, E10B, E10C, E10D, E10E, E10F

; Code pointer for each alignment for non-temporal store
AlignmentDispatchNT label qword
DQ F100, F101, F102, F103, F104, F105, F106, F107
DQ F108, F109, F10A, F10B, F10C, F10D, F10E, F10F

; Bypass cache by using non-temporal moves if count > CacheBypassLimit
; The optimal value of _CacheBypassLimit is difficult to estimate, but
; a reasonable value is half the size of the largest cache:
CacheBypassLimit DQ 400000H              ; 400000H = 4 Megabytes

.code
A_memcpy ENDP                          ; End of function namespace

END
