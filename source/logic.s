.globl gameStart
.globl InstallIntTable
.globl startScreen
.globl gameState
.globl mmGameState
.globl ControllerCheck

.section .text

////////////////////////////Test code below here/////////////////////////
	//Enable CLOCK IRQ line
	ldr	r0, =0x218
	ldr	r1, [r0]	//Get current IRQ state
	mov	r2, #1
	orr	r1, r2		//Enable ARM timer IRQ
	str	r1, [r0]	//Save IRQ state back

	//Enable CLOCK IRQ lines on Interrupt Controller
	ldr	r0, =0x2000B210	// Enable IRQs 1
	mov	r1, #0x00000002	// C1
	str	r1, [r0]


	// Enable IRQ
	mrs	r0, cpsr
	bic	r0, #0x80
	msr	cpsr_c, r0


///////////////////////////////Test code ends/////////////////////////////


startScreen:
	push	{lr}

	mov	r0, #300
	mov	r1, #200
	ldr	r2, =titleImageSize
	bl	Draw

	// Add Arrow
	mov	r0, #360
	ldr	r1, =390
	ldr	r2, =arrow
	bl	Draw
	
	ldr	r0, =400
	ldr	r1, =330
	ldr	r2, =titleName
	bl	DrawMessage

	ldr	r0, =400
	ldr	r1, =400
	ldr	r2, =titleStart
	bl	DrawMessage

	ldr	r0, =400
	ldr	r1, =430
	ldr	r2, =titleQuit
	bl	DrawMessage

getStartMenuInput:
	bl	ControllerCheck
	b	getStartMenuInput

End:





haltLoop$:
	b		haltLoop$


//////////////////////////////////////////////////////////
//Checks until input is provided
ControllerCheck:
	push	{r4-r6, lr}
	ldr	r4, =0xffff
	mov	r6, #0

getButtonLoop:	
	bl	Read_SNES	//Get button code, returned in r0
	cmp	r0, r4		//Check if no buttons are pushed
	beq	noButton
	b	getButtonLoop
	
noButton:
	bl	Read_SNES	//Get button code, returned in r0
	cmp	r0, r4
	beq	noButton
	b	gotButton	//Otherwise check for button again

gotButton:
	bl 	InputDetected
//	bl	bomb		//Uncomment to test interupt bomb
	pop	{r4-r6, lr}
	mov	pc, lr









/////////////////////////Test code below here/////////////////////////

hang:
	b		hang



InstallIntTable:
	ldr		r0, =IntTable
	mov		r1, #0x00000000

	// load the first 8 words and store at the 0 address
	ldmia	r0!, {r2-r9}
	stmia	r1!, {r2-r9}

	// load the second 8 words and store at the next address
	ldmia	r0!, {r2-r9}
	stmia	r1!, {r2-r9}

	// switch to IRQ mode and set stack pointer
	mov		r0, #0xD2
	msr		cpsr_c, r0
	mov		sp, #0x8000

	// switch back to Supervisor mode, set the stack pointer
	mov		r0, #0xD3
	msr		cpsr_c, r0
	mov		sp, #0x8000000

	bx		lr	




irq:
	push	{r0-r12, lr}

	// test if there is an interrupt pending in IRQ Pending 2
	ldr		r0, =0x7E00B204		//IRQ pending 1 register
	ldr		r1, [r0]
	tst		r1, #0x80		// bit 8
	beq		irqEnd

	// test that Clock IRQ line caused the interrupt
	ldr		r0, =0x7E00B204		// IRQ Pending 1 register
	ldr		r1, [r0]
	tst		r1, #0x00000002		//C1
	beq		irqEnd

	// test if CS register has interupt
	ldr		r0, =0x7E003000		//CS register
	ldr		r1, [r0]
	tst		r1, #0x00000002		//C1
	beq		irqEnd


	// Make an arrow (test code)
	mov	r0, #10
	mov	r1, #10
	ldr	r2, =arrow
	bl	Draw


	// clear bit 10 in the event detect register
	ldr		r0, =0x7E003000
	mov		r1, #0x2
	str		r1, [r0]
	
irqEnd:
	pop		{r0-r12, lr}
	subs	pc, lr, #4



///////////////////////Test code ends//////////////////////////////////
//////////////////////////////Test Bomb///////////////////////////////
bomb:
	ldr	r0, =0x7E003004	//CLO (clock low 32bits)
	ldr	r1, [r0]	//Get current time
	ldr	r2, =1000000	//1 Seconds
	add	r1, r2		//Add 1 seconds to current time
	ldr	r0, =0x7E003010	//C1 
	str	r1, [r0]	//Store desired time to C1
	mov	pc, lr

///////////////////////Test code ends//////////////////////////////////



////////////////////////////////////////////////////////////
/////////////////////Parse oppertation//////////////////////
////////////////////////////////////////////////////////////

//Pass in r0:button code
InputDetected:
	push	{r4, lr}

	ldr	r1, =gameState	//Get game state
	ldrh	r4, [r1]
	cmp	r4, #0
	bleq	mainMenuControl	
	cmp	r4, #1
	bleq	mainGameControl
	cmp	r4, #2
	bleq	PauseMenuControl	

	pop	{r4, lr}
	mov	pc, lr		//Return from subroutine

/////////////////////////////////////////////////////////////
//Take r0 as button code
mainMenuControl:
	push	{r4, r5, r6, lr}	//Store return location

	mov	r4, r0		//r4 = Button code
	mov	r5, #1		
	lsl	r5, #4		//r5 is mask for up (button UP)
	
//Check button Up
	and	r6, r5, r4	//Mask all bits but UP bit
	cmp	r6, #0
	bleq	mmUp		//Check action for main menu up

	lsl	r5, #1

//Check button Down
	and	r6, r5, r4	//Mask all bits but Down bit
	cmp	r6, #0
	bleq	mmDown		//Check action for main menu down (mirror of up?)

	lsl	r5, #3


//Check button A
	and	r6, r5, r4	//Mask all bits but A bit
	cmp	r6, #0
	bleq	mmA

	pop	{r4, r5, r6, lr}
	mov	pc, lr		//Return from subroutine

/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////
//Take r0 as button code
mainGameControl:
	push	{r4, r5, r6, lr}	//Store return location

	mov	r4, r0		//r4 = Button code

	ldr	r0, =bomberMan	//Character info
	ldr	r1, =bomberman	//Image 
	mov	r3, #0		//Move flag
	mov	r5, #1		//Start mask
	lsl	r5, #3		//r5 is mask for START (button START)
	
//Check button Start 
	and	r6, r5, r4
	cmp	r6, #0
	ldreq	r6, =gameState
	moveq	r5, #2
	streq	r5, [r6]
	bleq	gamePause

	lsl	r5, #1

//Check button Up
	and	r6, r5, r4	//Mask all bits but UP bit
	cmp	r6, #0
	moveq	r2, #0		//Set direction up
	moveq	r3, #1		//Set move flag true

	lsl	r5, #1

//Check button Down
	and	r6, r5, r4	//Mask all bits but Down bit
	cmp	r6, #0
	moveq	r2, #1		//Set direction down
	moveq	r3, #1		//Set move flag true

	lsl	r5, #1

//Check button Left
	and	r6, r5, r4	//Mask all bits but Left bit
	cmp	r6, #0
	moveq	r2, #2		//Set direction left
	moveq	r3, #1		//Set move flag true

	lsl	r5, #1

//Check button Right
	and	r6, r5, r4	//Mask all bits but Right bit
	cmp	r6, #0
	moveq	r2, #3		//Set direction right
	moveq	r3, #1		//Set move flag true

	cmp	r3, #0		//Check if no movement was done
	blne	Move		//Move if "no movement" is false

	lsl	r5, #1

//Check button A
	and	r6, r5, r4	//Mask all bits but A bit
	cmp	r6, #0
//	bleq	mmA

	pop	{r4, r5, r6, lr}
	mov	pc, lr		//Return from subroutine

//Check button Start 
/////////////////////////Main menu (mm) controls/////////////////////////////


mmUp:
	push	{r4, lr}

	ldr	r4, =mmGameState
	ldrh	r1, [r4]
	cmp	r1, #0		//If already next to start
	popeq	{r4, lr}
	moveq	pc, lr		//Return from subroutine

//Erase arrow next to quit
	mov	r0, #360
	ldr	r1, =423
	ldr	r2, =blackFill
	bl	Draw

//Draw arrow next to start
	mov	r0, #360
	ldr	r1, =392
	ldr	r2, =arrow
	bl	Draw

	mov	r1, #0
	strh	r1, [r4]	//Change main menu state to quit

	pop	{r4, lr}
	mov	pc, lr		//Return from subroutine

///////////////////////////////
mmDown:
	push	{r4, lr}
	ldr	r4, =mmGameState
	ldrh	r1, [r4]
	cmp	r1, #1		//If already next to Quit
	popeq	{r4, lr}
	moveq	pc, lr		//Return from subroutine

//Erase arrow next to Start
	mov	r0, #360
	ldr	r1, =392
	ldr	r2, =blackFill
	bl	Draw

//Draw arrow next to Quit
	mov	r0, #360
	ldr	r1, =423
	ldr	r2, =arrow
	bl	Draw

	mov	r1, #1
	strh	r1, [r4]	//Change main menu state to quit

	pop	{r4, lr}
	mov	pc, lr		//Return from subroutine

mmA:
	ldr	r0, =mmGameState
	ldrh	r1, [r0]
	cmp	r1, #1		//If next to Start

	beq	quit

	ldr	r0, =gameState	
	mov	r1, #1
	str	r1, [r0]	//Update game state to main game (#1)

	pop	{r4, lr}
	b	gameStart

//////////////////////////////////////////////////////////////////
PauseMenuControl:
	push	{r4, r5, r6, lr}	//Store return location

	mov	r4, r0		//r4 = Button code
	mov	r5, #1		
	lsl	r5, #4		//r5 is mask for up (button UP)
	
//Check button Up
	and	r6, r5, r4	//Mask all bits but UP bit
	cmp	r6, #0
	bleq	pmUp		//Check action for main menu up

	lsl	r5, #1

//Check button Down
	and	r6, r5, r4	//Mask all bits but Down bit
	cmp	r6, #0
	bleq	pmDown		//Check action for main menu down (mirror of up?)

	lsl	r5, #3


//Check button A
	and	r6, r5, r4	//Mask all bits but A bit
	cmp	r6, #0
	bleq	pmA

	pop	{r4, r5, r6, lr}
	mov	pc, lr		//Return from subroutine
///////////////////////////////////////////////////////////////////////////
pmUp:
	push	{r4, lr}

	mov	r0, #10
	mov	r1, #10
	ldr	r2, =greenFill
	bl	Draw
	
	ldr	r4, =pmGameState
	ldrh	r1, [r4]
	cmp	r1, #0		//If already next to restart
	popeq	{r4, lr}
	moveq	pc, lr		//Return from subroutine

//Erase arrow next to quit
	mov	r0, #340
	ldr	r1, =380
	ldr	r2, =blackFill
	bl	Draw

//Draw arrow next to start
	mov	r0, #340
	ldr	r1, =300
	ldr	r2, =arrow
	bl	Draw

	mov	r1, #0
	strh	r1, [r4]	//Change main menu state to quit

	pop	{r4, lr}
	mov	pc, lr		//Return from subroutine

///////////////////////////////
pmDown:
	push	{r4, lr}
	ldr	r4, =pmGameState
	ldrh	r1, [r4]
	cmp	r1, #1		//If already next to Quit
	popeq	{r4, lr}
	moveq	pc, lr		//Return from subroutine

//Erase arrow next to Retart
	mov	r0, #340
	ldr	r1, =300
	ldr	r2, =blackFill
	bl	Draw

//Draw arrow next to Quit
	mov	r0, #340
	ldr	r1, =380
	ldr	r2, =arrow
	bl	Draw

	mov	r1, #1
	strh	r1, [r4]	//Change main menu state to quit

	pop	{r4, lr}
	mov	pc, lr		//Return from subroutine

pmA:
	ldr	r0, =pmGameState
	ldrh	r1, [r0]
	cmp	r1, #1		//If next to Quit

	beq	quit

	ldr	r0, =gameState	
	mov	r1, #1
	str	r1, [r0]	//Update game state to main game (#1)

	bl	newGame

	pop	{r4, lr}
	

newGame:
	push {r4, r5, lr}
	
	mov	r0, #1
	mov	r1, #1
	mov	r2, #3
	mov	r3, #0
	ldr	r4, =bomberMan
	
	strb	r0, [r4], #1
	strb	r1, [r4], #1
	strb	r2, [r4], #1
	strb	r3, [r4], #1

	ldr	r0, =gameGrid
	ldr	r1, =gameGrid1
	mov	r3, #0
	ldr	r5, =399
loop:
	ldrb	r4, [r1], #1
	add	r3, #1	
	strb	r4, [r0], #1	
	cmp	r3, r5
	bgt	loop
	
	pop 	{r4, lr}
	b	gameStart
////////////////////////////////////////////////////////////////////////////
//////////////////////////////Movement controls/////////////////////////////
////////////////////////////////////////////////////////////////////////////

// Takes r0:character , r1:sprite , r2:direction(0:up 1:down :2:left 3:right)
Move:
	push	{r4-r10, lr}

	mov	r8, r1		//Store sprite
	mov	r9, r2		//Store direction
	mov	r10, #21	//mul register

	ldrb	r4, [r0], #1	//Get X location of character
	ldrb	r5, [r0]	//Get Y location of character

	mov	r6, r4		//Tracks new X location
	mov	r7, r5		//Tracks new Y location

//Check if valid move
	cmp	r9, #0		//If up
	subeq	r7, #1		//Y of one above
	
	cmp	r9, #1		//If down
	addeq	r7, #1		//Y of one below

	cmp	r9, #2		//If Left
	subeq	r6, #1		//X of one left

	cmp	r9, #3		//If Right
	addeq	r6, #1		//X of one right

	
	mul	r3, r7, r10	//r3 = Y*21 (1D shift)		
	add	r3, r6		//r3 = Y(Converted to 1D) + X  


//1,2,4 = bad
	ldr	r1, =gameGrid
	ldrb	r0, [r1, r3]	//Load what is at location of direction
	cmp	r0, #1		//Location is a Hard Wall
	beq	endMove		
	cmp	r0, #2		//Location is a Soft Wall
	beq	endMove
	cmp	r0, #4		//Location is a Bomb
	beq	endMove		//(Can be optimized)

	ldr	r2, =bomberMan

	strb	r6, [r2]	//Store new X to bomberMan
	strb	r7, [r2, #1]	//Store new Y to bomberMan


	mov	r2, #3		//Bomberman


	strb	r2, [r1, r3]	//Store bomberman to new location in gameGrid
	mul	r3, r5, r10	//r3 = Y*21 (1D shift)		
	add	r3, r4		//r3 = Y(Converted to 1D) + X
   

	mov	r2, #0


	strb	r2, [r1, r3]	//Set current location to empty


	//X should be at 176 + (32*locationX)
	//Y should be at 48 + (32*locationY)

	mov	r10, #32	//Mul constant

//Erase old
	mov	r0, r4		//Get old X location
	mul	r0, r10		//Convert to pixle shift
	mov	r1, r5		//Get old Y location
	mul	r1, r10		//Convert to pixle shift

	add	r0, #176	//Shift X to align with game grid
	add	r1, #48		//Shift Y to align with game grid
	ldr	r2, =greenFill
	bl	Draw
	
//Draw new
	mov	r0, r6		//Get new X location
	mul	r0, r10		//Convert to pixle shift
	mov	r1, r7		//Get new Y location
	mul	r1, r10		//Convert to pixle shift

	add	r0, #176	//Shift X to align with game grid
	add	r1, #48		//Shift Y to align with game grid
	ldr	r2, =bomberman		//Get new sprite
	bl	Draw

endMove:
	pop	{r4-r10, lr}
	mov	pc, lr		//Return from subroutine

























//menu stuff before gameStart


gameStart:
	push {lr}
	ldr r0, =score	//set score to 0
	mov r1, #0
	str r1, [r0]
	push {lr}
	ldr r0, =lives	//set lives to 3
	mov r1, #3
	str r1, [r0]
drawStart:
	ldr	r0, =270
	ldr	r1, =25
	ldr	r2, =stringScore
	bl	DrawMessage
	ldr	r0, =690
	ldr	r1, =25
	ldr	r2, =stringLives
	bl	DrawMessage
	b	drawScreen



gamePause:
	push	{lr}
	
	mov	r0, #300
	mov	r1, #200
	ldr	r2, =PauseScreen
	bl	Draw

	ldr	r0, =340
	ldr	r1, =300
	ldr	r2, =arrow
	bl	Draw
	
	pop	{lr}
	mov	pc, lr
quit:

	pop 	{lr}
	mov	pc, lr
.section .data
////////////////////////////////////////////////////////////
//////////////////Test code for interupt////////////////////
////////////////////////////////////////////////////////////

IntTable:
	// Interrupt Vector Table (16 words)
	ldr		pc, reset_handler
	ldr		pc, undefined_handler
	ldr		pc, swi_handler
	ldr		pc, prefetch_handler
	ldr		pc, data_handler
	ldr		pc, unused_handler
	ldr		pc, irq_handler
	ldr		pc, fiq_handler

reset_handler:		.word InstallIntTable
undefined_handler:	.word hang
swi_handler:		.word hang
prefetch_handler:	.word hang
data_handler:		.word hang
unused_handler:		.word hang
irq_handler:		.word irq
fiq_handler:		.word hang

score:			.int 0 //initial score
lives:			.int 0 //players lives




.align 1

gameGrid:
//0:floor , 1:HardWall ,  2:SoftWall , 3:Bomberman , 4:Bomb
.byte	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte	1,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

gameGrid1:
//0:floor , 1:HardWall ,  2:SoftWall , 3:Bomberman , 4:Bomb
.byte	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte	1,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1
.byte	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
.byte	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1



.align 2
//Characters
bomberMan:
//(#attribute) 0:locationX , 1:locationY , 2:health , 3:score
.byte	1,1,3,0





//0:Main menu , 1:Game screen , 2:Ingame menue
gameState:
	.hword	0

//In main menu  0:Start geme , 1:Quit Game
mmGameState:
	.hword	0
pmGameState:
	.hword	0
