BaseOfLoader    equ 09000h  ;LOADER.BIN position
OffsetOfLoader  equ 0100h

BaseOfLoaderPhyAddr equ BaseOfLoader*10h

BaseOfKernelFile    equ 08000h  ;KERNEL.BIN position
OffsetOfKernelFile  equ 0h

BaseOfKernelFilePhyAddr equ BaseOfKernelFile * 10h
KernelEntryPointPhyAddr equ 030400h

PageDirBase equ 200000h ;2M
PageTblBase equ 201000h ;2M + 4K
