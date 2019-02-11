.section .text

//Set Clock, latch, and data lines
.globl InitSNES
InitSNES:
	push	{lr}
	mov	r0, #9		//Target pin 9, Latch line
	mov	r1, #1		//Set line to write
	bl	Init_GPIO

	mov	r0, #10		//Target pin 10, Date line
	mov	r1, #0		//Set line to read
	bl	Init_GPIO

	mov	r0, #11		//Target pin 11, Clock line
	mov	r1, #1		//Set line to write
	bl	Init_GPIO

	mov	r0, #1		
	bl	Write_Clock	//Set clock signal to true
	pop	{lr}
	mov	pc, lr		//Return from subroutine

.globl Init_GPIO
Init_GPIO:
	push	{r4, r5}	//Store r4 and r5 for subroutine use
	cmp	r0, #9		//Check if in GPFSEL 0 or 1
	ldrle	r2, =0x20200000	//Load GPFSEL0 location
	ldrgt	r2, =0x20200004	//Load GPFSEL1 location
	ldr	r3, [r2]	//Copy GPFSEL into r3
	mov	r4, #7		//Set r4 to 111
	subgt	r0, #10		//If not in GPFSEL0, get LSD
	mov	r5, #3		//Set r5 to #3
	mul	r0, r5		//Multiply LSD of pin by #3
	lsl	r4, r0		//Create bit mask for specified pin
	bic	r3, r4		//Clear bits for pin
	mov	r4, r1		//Set r4 to function code
	lsl	r4, r0		//Allign code to pin location
	orr	r3, r4		//Set pin using function code
	str	r3, [r2]	//Store value back to GPFSEL
	pop	{r4, r5}	//Retrive stored r4 and r5
	mov	pc, lr		//Return from subroutine	
	


//Writes to GPIO latch line
//Takes r0 as bit to be writen
.globl Write_Latch
Write_Latch:
	ldr	r1, =0x20200000	//Base GPIO reg
	mov	r2, #1
	lsl	r2, #9		//Align bit to pin #9
	cmp	r0, #0		//value to write
	streq	r2, [r1, #40]	//Set pin #9 as 0
	strne	r2, [r1, #28]	//Set pin #9 as 1
	mov	pc, lr		//Return from subroutine	
	
//Writes to GPIO Clock line
//Takes r0 as bit to be writen
.globl Write_Clock
Write_Clock:
	ldr	r1, =0x20200000	//Base GPIO reg
	mov	r2, #1		
	lsl	r2, #11		//Align bit to pin #11
	cmp	r0, #0		//value to write
	streq	r2, [r1, #40]	//Set pin #11 as 0
	strne	r2, [r1, #28]	//Set pin #11 as 1
	mov	pc, lr		//Return from subroutine

//Reads bit from GPIO data line
//Returns bit in r0
.globl Read_Data
Read_Data:
	ldr	r2, =0x20200000	//Base GPIO reg
	ldr	r1, [r2, #52]	//GPLEV0
	mov	r3, #1
	lsl	r3, #10		//Align bit to pin #10
	and	r1, r3		//Mask all but pin #10
	cmp	r1, #0		//Check if value is 0
	moveq	r0, #0		//Set r0 to value found
	movne	r0, #1		//Set r0 to value found
	mov	pc, lr		//Return from subroutine	
	

//Waits for an interval of time
//Takes r0 as period of time to pass in microseconds
.globl Wait
Wait:
	ldr	r1, =0x20003004	//Address of CLO
	ldr	r2, [r1]	//read CLO
	add	r2, r0		//Add delay time to clock time
	
	waitLoop:
		ldr	r3, [r1]	//Check current clock time
		cmp	r2, r3		//Compare delay time to current
		bhi	waitLoop	//Wait if current < delay

	mov	pc, lr		//Return from subroutine	
	
	


//Reads input buttons from controller and
//Returns code for buttons in register r0
.globl Read_SNES
Read_SNES:
	push	{r4, r5, r6, lr}//Store r4, r5, r6, lr for subroutine use

	mov	r0, #1		
	bl	Write_Clock	//Set clock signal to true

	mov	r0, #1		
	bl	Write_Latch	//Set lach line to true
	mov	r0, #12
	bl	Wait		//Wait 12 microseconds
	mov	r0, #0		
	bl	Write_Latch	//Set lach line to false

	mov	r4, #0xf  	//r4 = 1111
	lsl	r4, #12		//r4 = 1111000000000000

	mov	r5, #0		//Reset readLoop counter
	readLoop:
		mov	r0, #6
		bl	Wait		//Wait 6 microseconds
	
		mov	r0, #0		
		bl	Write_Clock	//Set clock signal to false
		mov	r0, #6
		bl	Wait		//Wait 6 microseconds

		bl	Read_Data	//Get input

		lsl	r0, r5		//Shift input data by the iteration
		orr	r4, r0		//Save state of button
		add	r5, #1		//Increment loop counter

		mov	r0, #1		
		bl	Write_Clock	//Set clock signal to true

		cmp	r5, #13		//If not all inputs have been read,
		ble	readLoop	//read next input

	mov	r0, r4		//Move input to return register

	pop	{r4, r5, r6, lr}
	mov	pc, lr		//Return from subroutine





