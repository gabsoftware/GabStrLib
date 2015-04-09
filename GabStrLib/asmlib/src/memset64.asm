;*************************  memset64.asm  *************************************
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
; Optimization:
; Uses XMM registers to set 16 bytes at a time, aligned.
;
; The latest version of this file is available at:
; www.agner.org/optimize/asmexamples.zip
; Copyright (c) 2008 GNU General Public License www.gnu.org/licenses/gpl.html
;******************************************************************************

public A_memset                        ; Function memset
public ?OVR_memset                     ; ?OVR removed if standard function memset overridden

; Imported from memcpy32.asm:
extern CacheBypassLimit: qword         ; Bypass cache if count > CacheBypassLimit

.code

; extern "C" void * memset(void * dest, int c, size_t count);
; Function entry:
A_memset PROC
?OVR_memset LABEL NEAR

IFDEF   WINDOWS
Rdest   equ     <rcx>                  ; dest
        movzx   eax, dl                ; c
        mov     rdx, r8                ; count
Rcount  equ     <rdx>                  ; count
Rdest2  equ     <r9>                   ; copy of dest
Rcount2 equ     <r8>                   ; copy of count

ELSE    ; Unix
Rdest   equ     <rdi>                  ; dest
        movzx   eax, sil               ; c
Rcount  equ     <rdx>                  ; count
Rdest2  equ     <rcx>                  ; copy of dest
Rcount2 equ     <rsi>                  ; copy of count
        mov     Rcount2, Rcount        ; copy count
ENDIF

        imul    eax, 01010101H         ; Broadcast c into all bytes of eax
        ; (multiplication is slow on Pentium 4, but faster on later processors)
        mov     Rdest2, Rdest          ; save dest
        cmp     Rcount, 16
        ja      M100
        
        lea     r10, MemsetJTab
        jmp     qword ptr [r10+Rcount*8]
        
; Separate code for each count from 0 to 16:
M16:    mov     [Rdest+12], eax
M12:    mov     [Rdest+8],  eax
M08:    mov     [Rdest+4],  eax
M04:    mov     [Rdest],    eax
M00:    mov     rax, Rdest2            ; return dest
        ret

M15:    mov     [Rdest+11], eax
M11:    mov     [Rdest+7],  eax
M07:    mov     [Rdest+3],  eax
M03:    mov     [Rdest+1],  ax
M01:    mov     [Rdest],    al
        mov     rax, Rdest2            ; return dest
        ret
       
M14:    mov     [Rdest+10], eax
M10:    mov     [Rdest+6],  eax
M06:    mov     [Rdest+2],  eax
M02:    mov     [Rdest],    ax
        mov     rax, Rdest2            ; return dest
        ret

M13:    mov     [Rdest+9],  eax
M09:    mov     [Rdest+5],  eax
M05:    mov     [Rdest+1],  eax
        mov     [Rdest],    al
        mov     rax, Rdest2            ; return dest
        ret
        

M100:   ; count > 16. Use SSE2 instruction set
        movd    xmm0, eax
        pshufd  xmm0, xmm0, 0          ; Broadcast c into all bytes of xmm0
        
        ; Store the first unaligned part.
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the subsequent regular part, than to make possibly mispredicted
        ; branches depending on the size of the first part.
        movq    qword ptr [Rdest],   xmm0
        movq    qword ptr [Rdest+8], xmm0
        
        ; Check if count very big
        cmp     Rcount, [CacheBypassLimit]
        ja      M500                   ; Use non-temporal store if count > $NonTempMoveLimit
        
        ; Point to end of regular part:
        ; Round down dest+count to nearest preceding 16-bytes boundary
        lea     Rcount, [Rdest+Rcount-1]
        and     Rcount, -10H
        
        ; Point to start of regular part:
        ; Round up dest to next 16-bytes boundary
        add     Rdest, 10H
        and     Rdest, -10H
        
        ; -(size of regular part)
        sub     Rdest, Rcount
        jnl     M300                   ; Jump if not negative
        
M200:   ; Loop through regular part
        ; Rcount = end of regular part
        ; Rdest = negative index from the end, counting up to zero
        movdqa  [Rcount+Rdest], xmm0
        add     Rdest, 10H
        jnz     M200
        
M300:   ; Do the last irregular part
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the preceding regular part, than to make possibly mispredicted
        ; branches depending on the size of the last part.
        mov     rax, Rdest2                          ; dest
        movq    qword ptr [rax+Rcount2-10H], xmm0
        movq    qword ptr [rax+Rcount2-8], xmm0
        ret
   
M500:   ; Use non-temporal moves, same code as above:
        ; End of regular part:
        ; Round down dest+count to nearest preceding 16-bytes boundary
        lea     Rcount, [Rdest+Rcount-1]
        and     Rcount, -10H
        
        ; Start of regular part:
        ; Round up dest to next 16-bytes boundary
        add     Rdest, 10H
        and     Rdest, -10H
        
        ; -(size of regular part)
        sub     Rdest, Rcount
        jnl     M700                   ; Jump if not negative
        
M600:   ; Loop through regular part
        ; Rcount = end of regular part
        ; Rdest = negative index from the end, counting up to zero
        movdqu  [Rcount+Rdest], xmm0
        add     Rdest, 10H
        jnz     M600
        
M700:   ; Do the last irregular part
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the preceding regular part, than to make possibly mispredicted
        ; branches depending on the size of the last part.
        mov     rax, Rdest2            ; dest
        movq    qword ptr [rax+Rcount2-10H], xmm0
        movq    qword ptr [rax+Rcount2-8], xmm0
        ret
        
   
.data
; Jump table for count from 0 to 16:
MemsetJTab DQ M00, M01, M02, M03, M04, M05, M06, M07
           DQ M08, M09, M10, M11, M12, M13, M14, M15, M16

.code

A_memset endp

END
