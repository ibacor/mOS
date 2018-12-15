%include    "pm.inc"

;======================================
PageDirBase0    equ 200000h ;2M
PageTblBase0    equ 201000h ;2M+4K
PageDirBase1    equ 210000h ;2M+64K
PageTblBase1    equ 211000h ;2M+64K+4K

LinearAddrDemo  equ 00401000h
ProcFoo         equ 00401000h
ProcBar         equ 00501000h

ProcPagingDemo  equ 00301000h
;======================================

org   07c00h
      jmp   LABEL_BEGIN

[SECTION .gdt]
;GDT
;                               Base       Limit    Attr
LABEL_GDT:          Descriptor  0,             0,  0        ;empty
LABEL_DESC_NORMAL:  Descriptor  0,        0ffffh,  DA_DRW   ;NORMAL DESCRIPTOR
LABEL_DESC_FLAT_C:  Descriptor  0,       0fffffh,  DA_CR | DA_32 | DA_LIMIT_4K
LABEL_DESC_FLAT_RW: Descriptor  0,       0fffffh,  DA_DRW | DA_LIMIT_4K 
LABEL_DESC_CODE32:  Descriptor  0,SegCode32Len-1,  DA_CR | DA_32  ;
LABEL_DESC_CODE16:  Descriptor  0,        0ffffh,  DA_C
LABEL_DESC_DATA:    Descriptor  0,     DataLen-1,  DA_DRW
LABEL_DESC_STACK:   Descriptor  0,    TopOfStack,  DA_DRWA | DA_32
LABEL_DESC_VIDEO:   Descriptor 0B800h,    0ffffh,  DA_DRW
;GDT end

GdtLen      equ     $ - LABEL_GDT
GdtPtr      dw      GdtLen - 1
            dd      0

;GDT selector
SelectorNormal      equ     LABEL_DESC_NORMAL - LABEL_GDT
SelectorFlatC       equ     LABEL_DESC_FLAT_C - LABEL_GDT
SelectorFlatRW      equ     LABEL_DESC_FLAT_RW- LABEL_GDT
SelectorCode32      equ     LABEL_DESC_CODE32 - LABEL_GDT
SelectorCode16      equ     LABEL_DESC_CODE16 - LABEL_GDT
SelectorData        equ     LABEL_DESC_DATA   - LABEL_GDT
SelectorStack       equ     LABEL_DESC_STACK  - LABEL_GDT
SelectorVideo       equ     LABEL_DESC_VIDEO  - LABEL_GDT
;end of [SECTION .gdt]

[SECTION .data1]    ;data segment
ALIGN   32
[BITS   32]
LABEL_DATA:
; STRING
_szPMMessage:       db  "In Protect Mode now. ^-^", 0Ah, 0Ah, 0
_szMemChkTitle:     db  "BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0
_szRAMSize:         db  "RAM size:", 0
_szReturn:          db  0Ah, 0
; 变量
_wSPValueInRealMode   dw  0
_dwMCRNumber:       dd  0
_dwDispPos:         dd  (80 * 6 + 0) * 2
_dwMemSize:         dd  0
_ARDStruct:
    _dwBaseAddrLow: dd  0
    _dwBaseAddrHigh: dd 0
    _dwLengthLow:   dd  0
    _dwLengthHigh:  dd  0
    _dwType:        dd  0
_PageTableNumber:   dd  0
_SavedIDTR:         dd  0
                    dd  0
_SavedIMREG:        db  0
_MemChkBuf: times 256 db 0

; 保护模式下使用这些符号
szPMMessage     equ _szPMMessage    - $$
szMemChkTitle   equ _szMemChkTitle  - $$
szRAMSize       equ _szRAMSize      - $$
szReturn        equ _szReturn       - $$
dwDispPos       equ _dwDispPos      - $$
dwMemSize       equ _dwMemSize      - $$
dwMCRNumber     equ _dwMCRNumber    - $$
ARDStruct       equ _ARDStruct      - $$
  dwBaseAddrLow equ _dwBaseAddrLow  - $$
  dwBaseAddrHigh equ _dwBaseAddrHigh- $$
  dwLengthLow   equ _dwLengthLow    - $$
  dwLengthHigh  equ _dwLengthHigh   - $$
  dwType        equ _dwType         - $$
MemChkBuf       equ _MemChkBuf      - $$
SavedIDTR       equ _SavedIDTR      - $$
SavedIMREG      equ _SavedIMREG     - $$
PageTableNumber equ _PageTableNumber- $$

DataLen         equ $ - LABEL_DATA
; END OF [SECTION .data1]

;IDT
[SECTION .idt]
ALIGN   32
[BITS   32]
LABEL_IDT:
; 门                        目标选择子,            偏移, DCount, 属性
%rep 32
        Gate    SelectorCode32, SpuriousHandler,      0, DA_386IGate
%endrep
.020h:      Gate    SelectorCode32,    ClockHandler,      0, DA_386IGate
%rep 95
        Gate    SelectorCode32, SpuriousHandler,      0, DA_386IGate
%endrep
.080h:      Gate    SelectorCode32,  UserIntHandler,      0, DA_386IGate

IdtLen      equ $ - LABEL_IDT
IdtPtr      dw  IdtLen - 1  ; 段界限
            dd  0           ; 基地址
; END of [SECTION .idt]


; global stack segment
[SECTION .gs]
ALIGN   32
[BITS   32]
LABEL_STACK:
    times   512 db 0

TopOfStack  equ $ - LABEL_STACK - 1
; END OF [SECTION .gs]


[SECTION .s16]
[BITS   16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100h

    mov [LABEL_GO_BACK_TO_REAL+3], ax
    mov [_wSPValueInRealMode], sp

    ; 得到内存数
    mov ebx, 0
    mov di, _MemChkBuf
.loop:
    mov eax, 0E820h
    mov ecx, 20
    mov edx, 0534D415h
    int 15h
    jc  LABEL_MEM_CHK_FAIL
    add di, 20
    inc dword [_dwMCRNumber]
    cmp ebx, 0
    jne .loop
    jmp LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAIL:
    mov dword [_dwMCRNumber], 0
LABEL_MEM_CHK_OK:
    

    ; initial 16bit code segment descriptor
    mov ax, cs
    movzx eax, ax
    shl eax, 4
    add eax, LABEL_DESC_CODE16
    mov word [LABEL_DESC_CODE16 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE16 + 4], al
    mov byte [LABEL_DESC_CODE16 + 7], ah

    ; initial 32bit code segment descriptor
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    ; initial data segment descriptor
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_DATA
    mov word [LABEL_DESC_DATA + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_DATA + 4], al
    mov byte [LABEL_DESC_DATA + 7], ah

    ; initial stack segment descriptor
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_STACK
    mov word [LABEL_DESC_STACK + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_STACK + 4], al
    mov byte [LABEL_DESC_STACK + 7], ah

    ; ready to load GDTR
    xor eax,eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT
    mov dword [GdtPtr + 2], eax

    ; ready to load IDTR
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_IDT
    mov dword [IdtPtr + 2],eax

    ; 保存 IDTR
    sidt [_SavedIDTR]

    ; 保存中断屏蔽寄存器(IMREG)值
    in al, 21h
    mov [_SavedIMREG], al

    ;load GDTR
    lgdt [GdtPtr]

    ;close interupt
    ;cli

    ; 加载 IDTR
    lidt [IdtPtr]

    ;open A20
    in al, 92h
    or al, 00000010b
    out 92h,al

    ;ready to switch to protect mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ;jump to protect mode
    jmp dword SelectorCode32:0

    ; from protect mode to real mode jump here
 LABEL_REAL_ENTRY:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, [_wSPValueInRealMode]

    lidt [_SavedIDTR]

    mov al, [_SavedIMREG]
    out 21h, al

    in al, 92h
    and al, 11111101b
    out 92h, al

    ; close interupt
    sti

    ; return to DOS
    mov ax, 4c00h
    int 21h
;END OF [SECTION .s16]

[SECTION .s32]  ;from real mode
[BITS   32]

LABEL_SEG_CODE32:
    mov ax, SelectorData
    mov ds, ax      ;dataSegment selector
    mov es, ax
    mov ax, SelectorVideo
    mov gs, ax
    
    mov ax, SelectorStack
    mov ss, ax
    mov esp,TopOfStack

    call Init8259A

    int 080h
    sti
    jmp $

    ; show a string
    push szPMMessage
    call DispStr
    add esp, 4
    
    push szMemChkTitle
    call DispStr
    add esp, 4

    call DispMemSize

    call PagingDemo

    call SetRealmode8259A

    ;end
    jmp SelectorCode16:0

;Init 8259A---------------------------------
Init8259A:
    mov al, 011h
    out 020h, al
    call io_delay
    
    out 0A0h, al
    call io_delay

    mov al, 020h
    out 021h, al
    call io_delay

    mov al, 028h
    out 021h, al
    call io_delay

    mov al, 004h
    out 021h, al
    call io_delay

    mov al, 002h
    out 0A1h, al
    call io_delay

    mov al, 001h
    out 021h, al
    call io_delay

    out 0A1h, al
    call io_delay

    mov al, 11111110b
    out 021h, al
    call io_delay
    
    mov al, 11111111b
    out 0A1h, al
    call io_delay
    
    ret
; Init 8259A---------------------------------

; SetRealmode 8259A
SetRealmode8259A:
    mov ax, SelectorData
    mov fs, ax

    mov al, 017h
    out 020h, al
    call io_delay

    mov al, 008h
    out 021h, al
    call io_delay

    mov al, 001h
    out 021h, al
    call io_delay

    ;恢复中断屏蔽寄存器(IMREG)的原值
    mov al, [fs:SavedIMREG]
    out 021h, al
    call io_delay
;--------------------------------------------

io_delay:
    nop
    nop
    nop
    nop
    ret

; int handler--------------------------------
_ClockHandler:
ClockHandler    equ _ClockHandler - $$
    inc byte [gs:((80 * 0 + 70) * 2)]
    mov al, 20h
    out 20h, al
    iretd

_UserIntHandler:
UserIntHandler  equ _UserIntHandler - $$
    mov ah, 0Ch
    mov al, 'I'
    mov [gs:((80 * 0 + 70) * 2)], ax
    iretd

_SpuriousHandler:
SpuriousHandler:    equ _SpuriousHandler - $$
    mov ah, 0Ch
    mov al, '!'
    mov [gs:((80 * 0 + 75) * 2)], ax
    jmp $
    iretd
;-------------------------------------------

;启动分页机制-------------------------------
SetupPaging:
    ;根据内存大小计算应初始化多少PDE以及多少页表
    xor edx, edx
    mov eax, [dwMemSize]
    mov ebx, 400000 ;4M
    div ebx
    mov ecx, eax
    test edx, edx
    jz  .no_remainder
    inc ecx
.no_remainder:
    mov [PageTableNumber],ecx

    ; 为简化处理, 所有线性地址对应相等的物理地址. 并且不考虑内存空

    ; 首先初始化页目录
    mov ax, SelectorFlatRW
    mov es, ax
    mov  edi, PageDirBase0
    xor eax, eax
    mov eax, PageTblBase0 | PG_P |PG_USU |PG_RWW
.1:
    stosd
    add eax, 4096
    loop .1

    ;再初始化所有页表
    mov eax, [PageTableNumber]
    mov ebx, 1024
    mul ebx
    mov ecx, eax
    mov edi, PageTblBase0
    xor eax, eax
    mov eax, PG_P | PG_USU | PG_RWW
.2:
    stosd
    add eax, 4096
    loop .2

    mov eax, PageDirBase0
    mov cr3, eax
    mov eax, cr0
    or  eax, 80000000h
    mov cr0, eax
    jmp short .3
.3:
    nop

    ret
;--------------------------------------------

; 测试分页机制 ------------------------------
PagingDemo:
    mov ax, cs
    mov ds, ax
    mov ax, SelectorFlatRW

    push LenFoo
    push OffsetFoo
    push ProcFoo
    call MemCpy
    add esp, 12

    push LenBar
    push OffsetBar
    push ProcBar
    call MemCpy
    add esp, 12

    push LenPagingDemoAll
    push OffsetPagingDemoProc
    push ProcPagingDemo
    call MemCpy
    add esp, 12

    mov ax, SelectorData
    mov ds, ax
    mov es, ax

    call SetupPaging

    call SelectorFlatC:ProcPagingDemo
    call PSwitch
    call SelectorFlatC:ProcPagingDemo

    ret
;-------------------------------------------

; 切换页表----------------------------------
PSwitch:
    ; 初始化页目录
    mov ax,SelectorFlatRW
    mov es, ax
    mov edi, PageDirBase1
    xor eax, eax
    mov eax, PageTblBase1 | PG_P | PG_USU |PG_RWW
    mov ecx, [PageTableNumber]
.1:
    stosd
    add eax, 4096
    loop .1

    ; 再初始化所有页表
    mov eax, [PageTableNumber]
    mov ebx, 1024
    mul ebx
    mov ecx, eax
    mov edi, PageTblBase1
    xor eax, eax
    mov eax, PG_P | PG_USU | PG_RWW
.2:
    stosd
    add eax, 4096
    loop .2

    ; 在此假设内存是大于 8M 的
    mov eax, LinearAddrDemo
    shr eax, 22
    mov ebx, 4096
    mul ebx
    mov ecx, eax
    mov eax, LinearAddrDemo
    shr eax, 12
    and eax, 03FFh
    mov ebx, 4
    mul ebx
    add eax, ecx
    add eax, PageTblBase1
    mov dword [es:eax], ProcBar | PG_P | PG_USU | PG_RWW

    mov eax, PageDirBase1
    mov cr3, eax
    jmp short .3
.3:
    nop

    ret
;--------------------------------------------

;PagingDemoProc------------------------------
PagingDemoProc:
OffsetPagingDemoProc    equ PagingDemoProc - $$
    mov eax, LinearAddrDemo
    call eax
    retf
;--------------------------------------------
LenPagingDemoAll    equ $ - PagingDemoProc
;--------------------------------------------

;foo-----------------------------------------
foo:
OffsetFoo   equ foo - $$
    mov ah, 0Ch
    mov al, 'F'
    mov [gs:((80 * 17 + 0) * 2)], ax
    mov al, 'o'
    mov [gs:((80 * 17 + 1) * 2)], ax
    mov [gs:((80 * 17 + 2) * 2)], ax
    ret
LenFoo equ  $ - foo
;-------------------------------------------

;bar---------------------------------------
bar:
OffsetBar   equ bar - $$
    mov ah, 0Ch
    mov al, 'B'
    mov [gs:((80 * 18 + 0) * 2)], ax
    mov al, 'a'
    mov [gs:((80 * 18 + 1) * 2)], ax
    mov al, 'r'
    mov [gs:((80 * 18 + 2) * 2)], ax
    ret
LenBar  equ $-bar
;------------------------------------------

;显示内存信息 -----------------------------
DispMemSize:
    push esi
    push edi
    push ecx

    mov esi, MemChkBuf
    mov ecx, [dwMCRNumber]
.loop:
    mov edx, 5
    mov edi, ARDStruct
.1:
    push dword [esi]
    call DispInt
    pop eax
    stosd
    add esi, 4
    dec edx
    cmp edx, 0
    jnz .1
    call DispReturn
    cmp dword [dwType], 1
    jne .2
    mov eax, [dwBaseAddrLow]
    add eax, [dwLengthLow]
    cmp eax, [dwMemSize]
    jb  .2
    mov [dwMemSize], eax
.2:
    loop .loop

    call DispReturn
    push szRAMSize
    call DispStr
    add esp, 4

    push dword [dwMemSize]
    call DispInt
    add esp, 4

    pop ecx
    pop edi
    pop esi
    ret
;-------------------------------------------

%include    "lib.inc"

SegCode32Len    equ $-LABEL_SEG_CODE32
;END OF [SECTION .32]


; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
[SECTION .s16code]
ALIGN   32
[BITS   16]
LABEL_SEG_CODE16:
    ;jump to real mode
    mov ax, SelectorNormal
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov eax, cr0
    and al, 11111110b
    mov cr0, eax

LABEL_GO_BACK_TO_REAL:
    jmp 0:LABEL_REAL_ENTRY

Code16Len   equ $ - LABEL_SEG_CODE16
; END OF [SECTION .s16code]
