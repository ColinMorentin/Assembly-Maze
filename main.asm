; ----------------------------------------
; Lab 6 - 
; Version 1.0
; Date: December 1, 2017
; Written By : Colin Morentin
; Lab Hours  : Friday 11:00am - 1:00pm
; For questions regarding this code, contact colin.morentin@gmail.com
; ----------------------------------------
.INCLUDE <m328pdef.inc>

										;pushbutton switch ports
.EQU dff_q		= PD2							;Q output of debounce flip flop						;
.EQU dff_clk	= PD5								;clock of debounce flip-flop

										;states for for Finite State Machien
.EQU S0 		= 0b00							 
.EQU S1 		= 0b01
.EQU S2 		= 0b10
.EQU S3			= 0b11
										;true and false
.EQU true 		= 0xFF							;equates for hex to boolean logic
.EQU false		= 0x00	
	
.DSEG
room:  			.BYTE   1       					;varaible holding room output
dir:   			.BYTE   1						;variable holding dirction output
next_state:		.BYTE	1 						;variable holding the state of the FSM
roomHolder:		.BYTE	1						;variable to temporary hold room output
walk: 			.BYTE	1						;variable to hold the progression of the maze
row:			.BYTE 	1  						;the bear is located at this row address 
col:   			.BYTE 	1  						;the bear is located at this column address
bees:  			.BYTE 	1  						;current number of bees the bear has counted 
nTimes:			.BYTE	1						;number of times bear has taken a specific action
hive:			.BYTE	1						;stores total number of bees

.CSEG
.ORG 0x0000

RST_VECT:
	rjmp reset     								;jump over IVT, plus INCLUDE code

										; -----Interrupt Vector Table (IVT) -----
	.ORG 0x0002 								;0x0002 External Interrupt Request 0
`	jmp INT0_ISR  								;interupt subroutine
		
	.ORG 0x0020								;0x0020 Timer Counter Overflow 						
	jmp TimerOverFlow

	.ORG 0x0050
				  					
	left_table:  .DB  east, north, south, west	;Table for Left Turn
	right_table: .DB  west, south, north, east  ;Table for Right Turn
	turn_table:  .DB  north, west, east, south  ;Table for Turn Around
     


	.ORG 0x0100                						;bypass IVT
	
	.INCLUDE "spi_shield.inc"						;defines boards base functions
	.INCLUDE "testbench.inc"   						;DrawRoom and DrawDirection
	.INCLUDE "pseudo_instr.inc"						;pseudo instructions
	.INCLUDE "maze.inc"
	.INCLUDe "tables.inc"

reset:

	ldi	r16,low(RAMEND)     						;RAMEND address 0x08ff
	out   	SPL,r16             						;stack Pointer Low SPL at i/o address 0x3d
	ldi   	r16,high(RAMEND)
	out   	SPH,r16 	            					;stack Pointer High SPH at i/o address 0x3

	call  	InitShield  	        					;initialize GPIO Ports and SPI communications
	
	clr 	r16								;process to load delay into the timer
	ldi   	r16, 0x0B				;			the delay time must be loaded into two 
	sts	TCNT1H, r16							;different registers
	ldi	r16, 0xDC				
	sts.    TCNT1L, r16

	ldi	r16,(1<<CS11|1<<CS10)						;load the prescaler for timer 1
	sts	TCCR1B, r16

	
	clr.    r17
	ldi     r17,0x05			 				;PRESCALER for timer 0
	out	TCCR0B, r17

	ldi 	r17, 0x64			 				;LOAD DELAY for timer 0
	out	TCNT0,r17
	
	ldi 	r17, 0x01			 				;MASK ENABLE for timer 0
	sts	TIMSK0, r17 
		
	clr   	spiLEDS              
	clr   	spi7SEG              

										;Initialize SRM Variables	
	clr   	r16                  						;initalize all user created variables to 0
	sts   	room, r16
	sts	next_state, r16
	sts 	walk, r16	
	sts	col, r16
	sts	bees, r16
	sts 	ntimes, r16
	sts	hive, r16

	ldi	r16, 0x03
	sts	dir, r16

	ldi 	r16, 0x14
	sts 	row, r16
	

										;Initalize pins for push-buttons 
										;debounce circuit | table 13-1
	sbi   	DDRD, dff_clk  							;flip-flop clock | 1X = output from AVR
	cbi   	DDRD, dff_Q    							;flip-flop Q     | 00 = input to AVR w/o pull-up
	cbi   	PORTD, dff_Q   							;flip-flop Q

	
										; Initialize External Interrupt 0
	cbi 	EIMSK, INT0							;Disable INT0 interrupts (EIMSK I/O Address 0x1D)
	lds 	r17, EICRA							;EICRA Memory Mapped Address 0x69
	cbr 	r17, 0b00000001
	sbr 	r17, 0b00000010
	sts 	EICRA, r17							;ISCO=[10] (falling edge)
	sbi 	EIMSK, INT0
	
	sei									;Global Interrupts Enable	
	
loop:
	
	lds 	r19, next_state	   						;hold the next state of the state machine
							   			;Finite State Machine
	state_S0:
	 			   
	cpi	r19, s0								;determine if it belongs in that state
	brne	state_S1			

										;output decoder
	lds     r24, room     							;code to output the room
	rcall 	DrawRoom
	mov	spi7seg, r24

										;next state decoder
	ldi 	r16, s1
	sts 	next_state, r16
	rjmp	endstate

state_S1:

	cpi	r19, s1								;determine if it is in that state
	brne	state_S2
	
										;output decoder
	lds     r24, room           						;code to output the room.
	rcall   DrawRoom		    				
	sts	roomHolder, r24							;temporary hold the room output

	lds     r24, dir          						;code to output the direction.
	rcall   DrawDirection    				

	lds	r20, roomHolder								
	or	r20,r24								;or the two different values to avoid overwrite
	mov	spi7SEG, r20							;output

										;next state decoder 
	lds	r17, walk							;code to hold the next output						
	tst	r17
	ldi 	r16, S0
	breq	end_S1
	ldi	r16,S2

end_S1:

	sts	next_state, r16
	rjmp	endState

state_S2:

	cpi  	r19, s2
	brne 	state_s3
										;output decoder
	ldi	r22, false
	sts	walk, r22							;stop supressing output


	lds	r24, room
	rcall   DrawRoom		    				
	mov 	spi7seg, r24							;output the data to the 7seg
										;next state decoder
	lds 	r20, dir
	lds	r24, row
	lds	r22, col
	rcall	takeAStep
	sts     col, r22   							;update column after taking a step
	sts     row, r24   							;update row after taking a step
	
	cpi 	r24, 0xFF
	breq 	InForest
	rcall   EnterRoom  							;EnterRoom inputs are outputs from TakeAStep
	mov     r22, r24   							;save bees and room into temporary register r22 
	andi    r22, 0xF0  							;erase the room value while keeping the number of Bees
	swap	r22        							;swap number of bees to the least significant nibble
	sts     bees, r22  							;save number of bees in the room
	cpi 	r22, 0x00
	breq	skipbees
	rcall   CountBees
	ldi	r22, false
	sts	walk, r22	
	rcall   delay
	rcall 	delay
skipbees:
	andi    r24, 0x0F  							;remove the number of bees from the room
	sts     room, r24  							;save the unformatted room (i.e.as a number)
	

	lds     r22, room
	lds     r24, dir
										;rcall ShortWhichWay
	rcall	myWay
takeMeHome:
	sts     dir,r24
	
	lds     r22, bees
	lds 	r24, room
	
	rcall 	ishallway
	tst	r24
	brne	state_3
	ldi 	r16, S1
	rjmp 	end_S2
		
state_3:
	ldi 	r16, S3
	
end_S2:
	sts	next_state, r16
	rjmp 	endState


state_S3:
	ldi 	r25, 0x00
	mov 	spi7seg, r25
	rcall 	isHallway
	tst 	r24
	breq    state2
	ldi 	r16, S0
	rjmp 	end_S3
state2:
	ldi 	r16, S2

end_S3:
	sts	next_state, r16
	rjmp	endState

	
endState:

	Bst   	r19, 0								;blink LED 0
	Bld   	spiLEDS, 0
	Bst   	r19,1
	Bld    	spiLEDS,1
	
	rcall 	delay
	call	writedisplay							;preform all output functions
		
	rjmp   	loop				


InForest:
	
										; Display 0 and turn off LEDs


	
										;all discrete LEDs off
	call  Hex_2_7seg
DangerousGame:
	mov spi7seg, r27
	clr    spiLEDS
	call   WriteDisplay
										;Power

Down:
	ldi    r16, 0x05 
										;When bits SM2..0 are written to 010 (Table 9-1),
	out    SMCR, r16 
										;and SE = 1 in the SMCR register (Section 9.11.1),
	sleep            
										;with SLEEP the MCU enters Powerdown(Section 9.5)
	
	ret
Hex_2_7seg:

	
	ldi ZH, high(Bee_table<<1)
	ldi ZL, low(Bee_table<<1)
	                                                                                                                                                                                            
	lds r27, hive
	cbr r27, 0b11110000;


	add ZL, r27
	lpm r27, Z

	jmp dangerousGame

										;External Interrupt 0 Service Routine
INT0_ISR:

	push    reg_F
	in      reg_F,SREG
	push    r16
	ldi     r16, true
	sts     walk, r16
	pop     r16
	out     SREG,reg_F
	pop     reg_F
	reti 


  
Delay:

	push r16								;preserve I/O registers values

wait:

	in 	r16, TIFR1							;actions to reload the timer 
	bst 	r16, TOV1							;after the delay has been made
	brtc 	wait								;is my timer empty if not continue
	sbi 	TIFR1, TOV1							;reload my timer
	ldi 	r16, 0x0B
	sts 	TCNT1H, r16
	ldi 	r16, 0xDC
	sts 	TCNT1L, r16
	
	pop 	r16								;return original register values
	ret


Pulse:

	cbi   	PORTD, dff_clk						
	sbi	PORTD, dff_clk
	ret


myWay:
	push 	r16
	in 	r15, sreg
	push 	r17

	mov 	r17, r24
	rcall 	leftpaw
	tst 	r24
	breq	noLeftWall
	rjmp 	leftWall

noLeftWall:
	mov	r24, r17
	rcall 	HitWall
	tst 	r24
	breq	noLeftNoHitWall
	rjmp	noLeftHitWall
	
noLeftnoHitWall:
	mov	r24, r17
	rcall	RightPaw
	tst	r24
	brne	incrementN
	mov 	r24, r17
	rjmp 	wayFound
 

incrementN:
	lds 	r16, nTimes
	inc 	r16
	sts	nTimes, r16
	cpi 	r16, 0x03
	breq 	time2TurnLeft
	cpi 	r16, 0x05
	breq	time2TurnLeft
	mov 	r24,r17
	rjmp 	wayFound

time2TurnLeft:
	mov 	r24, r17
	rcall 	TurnLeft
	rjmp 	wayFound

noLeftHitWall:
	mov	r24, r17
	rcall 	RightPaw
	tst 	r24
	breq	time2TurnRight
	rjmp	time2TurnLeft

time2TurnRight:
	mov 	r24, r17
	rcall 	TurnRight
	rjmp 	wayFound

leftWall:
	mov	r24, r17
	rcall	Hitwall
	tst	r24
	breq	leftNoHitWall
	rjmp 	leftHitWall

leftnoHitWall:
	mov	r24, r17
	rcall	RightPaw
	tst 	r24
	breq	time2TurnRight
	mov	r24, r17
	rjmp 	wayFound

leftHitWall:
	mov	r24, r17
	rcall	RightPaw
	tst 	r24
	breq	time2TurnRight
	rjmp 	time2TurnAround

time2TurnAround:
	mov	r24, r17
	rjmp 	TurnAround
IamTurnAround:
	rjmp 	wayFound

wayFound:
	pop 	r17
	out 	sreg, r15
	pop 	r16
	jmp	takeMeHome


CountBees:

	push 	r16
	push 	r15
	in   	reg_F,SREG
	push 	r17
	push 	r18

	ldi 	ZH, high(Bee_table<<1)
	ldi 	ZL, low(Bee_table<<1)
	
	
	lds 	r16, bees
	mov 	r17, r16
	lds	r18, hive
	add	r18,r17
	sts	hive, r18
	
	add 	Zl,r16
	lpm 	r16,Z
	mov 	spi7seg,r16
	call 	writedisplay
	rjmp 	end2  

end2:
	pop 	r18
	pop 	r17
	out 	SREG, reg_F
	pop	 r15
	pop 	r16

	ret
