.section    .init
.globl     _start

_start:
    b       main
    
.section .text

main:
	bl	InstallIntTable			// Test code

   	mov     sp, #0x8000
	
	bl	EnableJTAG
	bl	InitFrameBuffer
	bl	InitSNES
	bl	startScreen

haltLoop:
	b		haltLoop


