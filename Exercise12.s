            TTL Lab Exercise Ten: Timer Driver Input Timing
;****************************************************************
;This program takes in inputs from the user for their name, the 
;date, and the last name of a TA for the lab section. For each
;of those inputs, the user is timed to see how long it took them
;to enter those inputs. The total time it took them for each input
;is printed to the screen after they hit the enter key to confirm
;the input. 
;Name:  Matthew Rigby
;Date:  11/13/17
;Class:  CMPE-250
;Section:  Lab Section 01, Wednesday's from 5:30PM - 7:30PM
;---------------------------------------------------------------
;Keil Template for KL46
;R. W. Melton
;September 25, 2017
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL46Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;****************************************************************
;EQUates
MAX_STRING	EQU		79		;Variable MAX_STRING is equal to the number 79
LETTERS     EQU     26		;Variable LETTERS is equal to the number 26
	
NVIC_ICPR_UART0_MASK  	EQU 	UART0_IRQ_MASK
UART0_IRQ_PRIORITY 		EQU 	3
NVIC_IPR_UART0_MASK 	EQU		(3 << UART0_PRI_POS)
NVIC_IPR_UART0_PRI_3	EQU		(UART0_IRQ_PRIORITY << UART0_PRI_POS)
NVIC_ISER_UART0_MASK	EQU		UART0_IRQ_MASK
UART0_C2_T_RI           EQU     (UART0_C2_RIE_MASK :OR: UART0_C2_T_R)
UART0_C2_TI_RI 			EQU		(UART0_C2_TIE_MASK :OR: UART0_C2_T_RI)

IN_PTR		EQU		0
OUT_PTR		EQU		4
BUF_STRT	EQU		8
BUF_PAST	EQU		12
BUF_SIZE	EQU		16
NUM_ENQD	EQU		17

Q_BUF_SZ	EQU		4
Q_REC_SZ	EQU		18
	
TR_BUF_SZ   EQU		80
	
	

;For Port D
PTD5_MUX_GPIO   EQU     (1 << PORT_PCR_MUX_SHIFT)
SET_PTD5_GPIO   EQU     (PORT_PCR_ISF_MASK :OR: PTD5_MUX_GPIO)
    
;For Port E
PTE29_MUX_GPIO  EQU     (1 << PORT_PCR_MUX_SHIFT)
SET_PTE29_GPIO  EQU     (PORT_PCR_ISF_MASK :OR: PTE29_MUX_GPIO)
	
POS_RED         EQU  29
POS_GREEN       EQU  5
    
LED_RED_MASK    EQU  (1 << POS_RED)
LED_GREEN_MASK  EQU  (1 << POS_GREEN)
    
LED_PORTD_MASK  EQU  LED_GREEN_MASK
LED_PORTE_MASK  EQU  LED_RED_MASK	
	
	
;SIM_SCGC6_PIT_MASK		
PIT_IRQ_PR1  EQU  0  ;Highest pR1oR1ty
PIT_MCR_EN_FRZ  EQU  PIT_MCR_FRZ_MASK
PIT_LDVAL_10ms  EQU  239999
PIT_TCTRL_CH_IE  EQU  (PIT_TCTRL_TIE_MASK :OR: PIT_TCTRL_TEN_MASK)
	
;---------------------------------------------------------------
;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
;Use provided PORT_PCR_MUX_SELECT_2_MASK
;---------------------------------------------------------------
;Port A
PORT_PCR_SET_PTA1_UART0_RX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTA2_UART0_TX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
;---------------------------------------------------------------
;SIM_SCGC4
;1->10:UART0 clock gate control (enabled)
;Use provided SIM_SCGC4_UART0_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->09:Port A clock gate control (enabled)
;Use provided SIM_SCGC5_PORTA_MASK
;---------------------------------------------------------------
;SIM_SOPT2
;01=27-26:UART0SRC=UART0 clock source select
;         (PLLFLLSEL determines MCGFLLCLK' or MCGPLLCLK/2)
; 1=   16:PLLFLLSEL=PLL/FLL clock select (MCGPLLCLK/2)
SIM_SOPT2_UART0SRC_MCGPLLCLK  EQU  \
                                 (1 << SIM_SOPT2_UART0SRC_SHIFT)
SIM_SOPT2_UART0_MCGPLLCLK_DIV2 EQU \
    (SIM_SOPT2_UART0SRC_MCGPLLCLK :OR: SIM_SOPT2_PLLFLLSEL_MASK)
;---------------------------------------------------------------
;SIM_SOPT5
; 0->   16:UART0 open drain enable (disabled)
; 0->   02:UART0 receive data select (UART0_RX)
;00->01-00:UART0 transmit data select source (UART0_TX)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  EQU  \
                               (SIM_SOPT5_UART0ODE_MASK :OR: \
                                SIM_SOPT5_UART0RXSRC_MASK :OR: \
                                SIM_SOPT5_UART0TXSRC_MASK)
;---------------------------------------------------------------
    ;UART0_BDH
;    0->  7:LIN break detect IE (disabled)
;    0->  6:RxD input active edge IE (disabled)
;    0->  5:Stop bit number select (1)
;00001->4-0:SBR[12:0] (UART0CLK / [9600 * (OSR + 1)]) 
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDH_9600  EQU  0x01
;---------------------------------------------------------------
;UART0_BDL
;0x38->7-0:SBR[7:0] (UART0CLK / [9600 * (OSR + 1)])
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDL_9600  EQU  0x38
;---------------------------------------------------------------
;UART0_C1
;0-->7:LOOPS=loops select (normal)
;0-->6:DOZEEN=doze enable (disabled)
;0-->5:RSRC=receiver source select (internal--no effect LOOPS=0)
;0-->4:M=9- or 8-bit mode select 
;        (1 start, 8 data [lsb first], 1 stop)
;0-->3:WAKE=receiver wakeup method select (idle)
;0-->2:IDLE=idle line type select (idle begins after start bit)
;0-->1:PE=parity enable (disabled)
;0-->0:PT=parity type (even parity--no effect PE=0)
UART0_C1_8N1  EQU  0x00
;---------------------------------------------------------------
;UART0_C2
;0-->7:TIE=transmit IE for TDRE (disabled)
;0-->6:TCIE=transmission complete IE for TC (disabled)
;0-->5:RIE=receiver IE for RDRF (disabled)
;0-->4:ILIE=idle line IE for IDLE (disabled)
;1-->3:TE=transmitter enable (enabled)
;1-->2:RE=receiver enable (enabled)
;0-->1:RWU=receiver wakeup control (normal)
;0-->0:SBK=send break (disabled, normal)
UART0_C2_T_R  EQU  (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
;---------------------------------------------------------------
;UART0_C3
;0-->7:R8T9=9th data bit for receiver (not used M=0)
;           10th data bit for transmitter (not used M10=0)
;0-->6:R9T8=9th data bit for transmitter (not used M=0)
;           10th data bit for receiver (not used M10=0)
;0-->5:TXDIR=UART_TX pin direction in single-wire mode
;            (no effect LOOPS=0)
;0-->4:TXINV=transmit data inversion (not inverted)
;0-->3:ORIE=overrun IE for OR (disabled)
;0-->2:NEIE=noise error IE for NF (disabled)
;0-->1:FEIE=framing error IE for FE (disabled)
;0-->0:PEIE=parity error IE for PF (disabled)
UART0_C3_NO_TXINV  EQU  0x00
;---------------------------------------------------------------
;UART0_C4
;    0-->  7:MAEN1=match address mode enable 1 (disabled)
;    0-->  6:MAEN2=match address mode enable 2 (disabled)
;    0-->  5:M10=10-bit mode select (not selected)
;01111-->4-0:OSR=over sampling ratio (16)
;               = 1 + OSR for 3 <= OSR <= 31
;               = 16 for 0 <= OSR <= 2 (invalid values)
UART0_C4_OSR_16           EQU  0x0F
UART0_C4_NO_MATCH_OSR_16  EQU  UART0_C4_OSR_16
;---------------------------------------------------------------
;UART0_C5
;  0-->  7:TDMAE=transmitter DMA enable (disabled)
;  0-->  6:Reserved; read-only; always 0
;  0-->  5:RDMAE=receiver full DMA enable (disabled)
;000-->4-2:Reserved; read-only; always 0
;  0-->  1:BOTHEDGE=both edge sampling (rising edge only)
;  0-->  0:RESYNCDIS=resynchronization disable (enabled)
UART0_C5_NO_DMA_SSR_SYNC  EQU  0x00
;---------------------------------------------------------------
;UART0_S1
;0-->7:TDRE=transmit data register empty flag; read-only
;0-->6:TC=transmission complete flag; read-only
;0-->5:RDRF=receive data register full flag; read-only
;1-->4:IDLE=idle line flag; write 1 to clear (clear)
;1-->3:OR=receiver overrun flag; write 1 to clear (clear)
;1-->2:NF=noise flag; write 1 to clear (clear)
;1-->1:FE=framing error flag; write 1 to clear (clear)
;1-->0:PF=parity error flag; write 1 to clear (clear)
UART0_S1_CLEAR_FLAGS  EQU  0x1F
;---------------------------------------------------------------
;UART0_S2
;1-->7:LBKDIF=LIN break detect interrupt flag (clear)
;             write 1 to clear
;1-->6:RXEDGIF=RxD pin active edge interrupt flag (clear)
;              write 1 to clear
;0-->5:(reserved); read-only; always 0
;0-->4:RXINV=receive data inversion (disabled)
;0-->3:RWUID=receive wake-up idle detect
;0-->2:BRK13=break character generation length (10)
;0-->1:LBKDE=LIN break detect enable (disabled)
;0-->0:RAF=receiver active flag; read-only
UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS  EQU  0xC0
;---------------------------------------------------------------
;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT Reset_Handler
            EXPORT PutChar
            IMPORT Startup   
Reset_Handler  PROC  {},{}
main
;---------------------------------------------------------------
;Mask interrupts
            CPSID   I
;KL46 system startup with 48-MHz system clock
            BL      Startup
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<
            ;Initialize the UART0_IRQ
			CPSID	I
			BL		Init_UART0_IRQ
			BL		Init_Lights
			CPSIE	I
			
          

       
           

;>>>>>   end main program code <<<<<
;Stay here
            B       .
            ENDP
;>>>>> begin subroutine code <<<<<


Init_Lights		PROC		{R0-R14}
			PUSH		{R0-R2}
			
			;Enable Port D and Port E
            LDR     R0,=SIM_SCGC5
            LDR     R1,=(SIM_SCGC5_PORTD_MASK :OR: SIM_SCGC5_PORTE_MASK)
            LDR     R2,[R0,#0]
            ORRS    R2,R2,R1
            STR     R2,[R0,#0]

            ;Select PORT E Pin 29 for GPIO to red LED
            LDR     R0,=PORTE_BASE
            LDR     R1,=SET_PTE29_GPIO
            STR     R1,[R0,#PORTE_PCR29_OFFSET]
            
            ;Select PORT D Pin 5 for GPIO to green LED
            LDR     R0,=PORTD_BASE
            LDR     R1,=SET_PTD5_GPIO
            STR     R1,[R0,#PORTD_PCR5_OFFSET]
            
            LDR  	R0,=FGPIOD_BASE
            LDR  	R1,=LED_PORTD_MASK
            STR  	R1,[R0,#GPIO_PDDR_OFFSET]
            LDR  	R0,=FGPIOE_BASE
            LDR  	R1,=LED_PORTE_MASK
            STR  	R1,[R0,#GPIO_PDDR_OFFSET]
	
			POP		{R0-R2}
			BX		LR
			ENDP
				

;Subroutine: Toggle Light
;Input: R0: 0 for Red, anything else for Green

Toggle_Light    PROC		{R0-R14}
			PUSH			{R0-R3}
			
			CMP		R0,#0
			BEQ		None
			CMP		R0,#1
			BEQ		Red
			CMP		R0,#2
			BEQ		Green
			CMP		R0,#3
			BEQ		BothLights
			
			
None		;Turn off red LED
			LDR  R0,=FGPIOE_BASE
			LDR  R1,=LED_RED_MASK
			STR  R1,[R0,#GPIO_PSOR_OFFSET]
			
			;Turn off green LED
			LDR  R0,=FGPIOD_BASE
			LDR  R1,=LED_GREEN_MASK
			STR  R1,[R0,#GPIO_PSOR_OFFSET]
			B	 EndLight
		
			
			;Turn on red LED
Red			LDR  R0,=FGPIOE_BASE
            LDR  R1,=LED_RED_MASK
            STR  R1,[R0,#GPIO_PCOR_OFFSET]
			
			;Turn off green LED
			LDR  R0,=FGPIOD_BASE
			LDR  R1,=LED_GREEN_MASK
			STR  R1,[R0,#GPIO_PSOR_OFFSET]
			B	 EndLight
			
			
Green 		;Turn on green LED
			LDR  R0,=FGPIOD_BASE
            LDR  R1,=LED_GREEN_MASK
            STR  R1,[R0,#GPIO_PCOR_OFFSET]
			
			;Turn off red LED
			LDR  R0,=FGPIOE_BASE
			LDR  R1,=LED_RED_MASK
			STR  R1,[R0,#GPIO_PSOR_OFFSET]
			B	 EndLight

Both		;Turn on red LED
			LDR  R0,=FGPIOE_BASE
            LDR  R1,=LED_RED_MASK
            STR  R1,[R0,#GPIO_PCOR_OFFSET]
			
			;Turn on green LED
			LDR  R0,=FGPIOD_BASE
            LDR  R1,=LED_GREEN_MASK
            STR  R1,[R0,#GPIO_PCOR_OFFSET]
			
EndLight	POP  {R0-R3}
			BX	 LR
			ENDP
				
				
;This subroutine prints out a given string to the screen. 
;Input parameters:
;R0 : Address of the string to be printed
;There are no output parameters, other than the printed result to the screen. 
PutStringSB			PROC {R0-R14}, {}

			PUSH	{R0-R3,LR}		            ;Store current values of R2, R3
			MOVS	R2,R0		                ;R2 has address
			
ThisWhile	LDRB	R0,[R2,#0]	                ;Otherwise, load the character
			CMP		R0,#0		                ;If the next char is null...
			BEQ		EndThisLoop	                ;Go the EndThisLoop
			BL		PutChar		                ;Put the next char in the string
			ADDS	R2,R2,#1	                ;Increment the address by 1 byte
			B		ThisWhile	                ;Go to ThisWhile
EndThisLoop			
			POP		{R0-R3,PC}		            ;Restore original values of R3 and R2
			ENDP



;This subroutine prints out a given unsigned word number value to the screen in hexidecimal.
;Input Parameters:
;R0 : Unsigned word value 
;There is no output, only a printed value to the screen. 
PutNumHex		PROC	{R0-R14},{}
;Keep
            PUSH	{R0-R6, LR}		;Saves the values in registers R0-R3
            MOVS	R1,#0		    ;R1 gets the counter
            MOVS	R2,#28		    ;R2 gets the shift amount for number of bits to shift
            MOVS	R4,R0		    ;Move the value of R4 into R0
	
Loop
            CMP		R1,#9		    ;Comparing the value in R1 to 9
            BEQ		EndLoopHere		;If the values are equal, go to EndLoop
            RORS	R4,R4,R2	    ;Otherwise, do a rotating shift
            MOVS	R5,#0x0000000F
            MOVS	R6,R4
            ANDS	R4,R4,R5	    ;Gets the last hex value in the rotated R4 and puts it into R0
            MOVS	R0,R4
            CMP		R0,#9		    ;Compare the value of R0 to 9
            BHI		HigherThanNine	;If the value in R0 > 9, go to HigherThanNine
            ADDS	R0,#0x30	    ;Add the hex value of 0x30 into R0
            ADDS	R1,R1,#1	    ;Increment R1, the counter
            BL		PutChar		    ;Print the character with the ascii value in R0 to the screen 
            MOVS	R4,R6
            BL		Loop		    ;Go to Loop

HigherThanNine
            ADDS	R0,#0x37	    ;Add the hex value of 0x37 into R0 
            ADDS	R1,R1,#1	    ;Increment R1, the counter
            BL		PutChar		    ;Print the character with the ascii value in R0 to the screen 
            MOVS	R4,R6
            BL		Loop		    ;Go to Loop

EndLoopHere
            POP		{R0-R6, PC}		;Restore the value of registers R0-R3
            ENDP

;This subroutine prints out a given word value in decimal to the screen. 
;Input Parameters:
;R0 : Unsigned word value 
;There is no output, only a printed value to the screen. 
PutNumUB	PROC	{R0-R14}, {}
;Keep
            PUSH	{R0-R1, LR}		;Saves the value in R0
            MOVS	R1,#0x000000FF  ;R1 gets the mask for the first byte in the unsigned word value in R0
            ANDS	R0,R0,R1        ;R0 gets the value of it's 2 least significant hex digits 
            BL		PutNumU		    ;Go to the subroutine PutNumU
            POP		{R0-R1, PC}		;Stores the value of R0
            ENDP



;This subroutine prints out the given value to the screen. 
;Input parameters:
;R0 : Length of the value
PutNumU		PROC 	{R0-R14}, {}
	
			PUSH 	{R0-R2, LR}     ;Store the values of R0-R2 and LR
            MOVS    R2,#0           ;Set R2 equal to 0
            CMP     R0,#0           ;Comparing the number size to 0
            BEQ     WhileR2Not0     ;If the size is 0, go to WhileR2Not0
PutNumULoop	MOVS	R1,R0		    ;R1 has the length of the string
			MOVS	R0,#10		    ;R0 gets 10
			BL		DIVU		    ;Divide R1 (the length) by R0 (10) to get a quotient and denominator, 
                                    ;which will be the tens and ones place of the length. R0 get the quotient
                                    ;and R1 gets the remainder.
            PUSH    {R1}            ;Save the value of the remainder
            ADDS    R2,R2,#1        ;Increment R2, the number of things that have been added to the stack 
            CMP     R0,#0           ;Compare the rest of the size of the input to 0
            BNE     PutNumULoop     ;If they are not equal, go to PutNumULoop
                 
WhileR2Not0 CMP     R2,#0           ;Comparing the number of things added to the stack to 0
            BEQ     Ending          ;If they are equal, go to Ending
            POP     {R0}            ;Otherwise, put the next item on the stack into R0
            ADDS    R0,#0x30        ;Convert the number in R0 into the ascii decimal value
            BL      PutChar         ;Print that value to the screen
            SUBS    R2,R2,#1        ;Decrement the number of items that are left to take from the stack 
            B       WhileR2Not0     ;Go to WhileR2Not0
		
Ending
			POP		{R0-R2, PC}     ;Restore the values of R0-R2 and PC
			ENDP
			



GetStringSB			PROC {R0-R14}, {}

			PUSH	{R0-R3,LR}	;Store current values of R2 and R3
			MOVS	R2,R0		;R2 has address
			MOVS	R3,#0		;R3 is counter
            SUBS    R1,R1,#2    ;Leaving space for the null character
            			
While		BL		GetChar		;Get next Char
			CMP		R0,#0x0D	;If R0 is the enter key...
			BEQ		EndLoop		;Go to EndLoop
            CMP     R0,#0x1F	;Comparing R0 to any of the control characters
            BLE     While		;If R0 is any control character other than backspace and enter, got to While
			CMP		R0,#0x7F	;Otherwise, if R0 is the backspace key...
			BEQ		BackS		;Go to BackS
			CMP		R1,R3		;Otherwise, if R3 is the same as the length of the buffer...
			BLT		While		;Go to while
			BL		PutChar		;Prints the character	
			STRB	R0,[R2,R3]	;Store the value in R0 into memory location R2 with offset R3
            ADDS	R3,R3,#1    ;Otherwise, counter increments
			B		While		;Go to while
		
BackS		CMP		R3,#0		;If the length of the string is 0...
			BEQ		While		;Go to while
			SUBS	R3,R3,#1	;Otherwise, counter is decremented
			BL		PutChar		;Shows the backspace on the screen
			B		While		;Go to while
			
EndLoop
			
			MOVS	R0,#0		;R0 gets 0
			STRB	R0,[R2,R3]	;Stores the last memory location of the string with a null value. 
			POP		{R0-R3,PC}
			ENDP



;This subroutine divides two numbers and returns the result of the division, as
;well as the remainder of the division. 
;Input parameters:
;R0 : Denominator of division
;R1 : numerator of division
;Output:
;R1 : gets the remainder
;R0 : gets the divided amount
;APSR C Flag : set if failed division (divide by 0) or cleared if success
DIVU        PROC    {R2-R14},{}
   
			CMP     R0,#0                       ;Checks if the denominator is 0
            BEQ     SetCFlag	                ;If denominator is 0, go to SetCFlag

			PUSH 	{R2-R5}		                ;Saves the value in registers R2-R5
            MOVS    R2,#0                       ;Sets (counter) R2 = 0
			CMP     R1,#0                       ;Checks if the numerator is 0
            BEQ     ClearCFlag
            
DIVULoop    CMP     R1,R0                       ;Compares R1 to R0
            BLO     ClearCFlag                  ;If R1 < R0, go to END
            SUBS    R1,R1,R0                    ;Otherwise, R1 gets R1-R0
            ADDS    R2,R2,#1                    ;R2 gets R2 + 1
            B       DIVULoop                    ;Loop back to DIVULoop
			
ClearCFlag	
			MOVS	R4,R2		                ;Places the value in the division result into R4
			MOVS	R5,R1		                ;Places the value of the remainder into R5
			
            MRS     R0,APSR		                ;The following lines clear the C flag without changing other values
            MOVS    R1,#0x20
            LSLS    R1,R1,#24
            BICS    R0,R0,R1
            MSR     APSR,R0
			
            MOVS    R0,R4                       ;R0 gets the divided amount
                                
			MOVS	R1,R5		                ;R1 get the remainder
            B		EndDIVU2	                ;Go to EndDIVU2
            

SetCFlag       
            MRS     R0,APSR		                ;The following lines set the C flag without changing any other values
            MOVS    R1,#0x20
            LSLS    R1,R1,#24
            ORRS    R0,R0,R1
            MSR     APSR,R0 		
            B 		EndDIVU		                ;Go to EndDIVU

EndDIVU2
            POP 	{R2-R5}		                ;Re-enters the value for registers R2-R5 from before
EndDIVU
            BX  	LR			                ;Return to main program 
            ENDP
                
                
;Matthew Rigby
;Assembly Language Lab 9 Prelab
;Lab Section 1, Wednesdays from 5:30PM - 7:30PM

;This subroutine dequeues a character from the ReceiveQueue and returns it into register R0.
;Input Parameters:
;R2 gets the time it should take for the round to run. 
;Output:
;R0 : Dequeued character into R0
GetChar		PROC		{R0,R2-R14}, {}
	
			PUSH	{R1, LR}			;Save LR value
            
            LDRB    R3,=RunStopWatch
            MOVS    R4,#1
            STRB    R4,[R3,#0]
            LDR     R3,=Count
            ;LDR     R3,[R3,#0]
keepGoing
            LDR     R3,[R3,#0]
            CMP     R3,R2
            BGE     EndWhile
            
			CPSID	I					;Mask other interrupts
			LDR		R1,=ReceiveQueue	;R0 gets the address of the queue ReceiveQueue
			BL		DeQueue				;Dequeue from ReceiveQueue
			CPSIE	I					;Unmask other interrupts
			BCS		keepGoing			;If the carry flag was set, go to keepGoing
EndWhile	
			POP		{R1, PC}			;Restore PC value
			ENDP


;This subroutine dequeues a character from the TransmitQueue and returns it into register R0.
;No input parameters
;Output:
;R0 : Dequeued character into R0
PutChar     PROC    {R1-R14},{}
			PUSH	{R0-R2, LR}			;Save R0-R2 and LR values
keepGoing2
			CPSID	I					;Mask other interrupts
			LDR		R1,=TransmitQueue	;R0 gets the address of the queue TransmitQueue
			BL		EnQueue				
			CPSIE	I					;Unmask other interrupts
			BCS		keepGoing2			;If the carry flag was set, go to keepGoing2
EndingWhile
			MOVS	R1,#UART0_C2_TI_RI	;R1 gets the value of the EQUates UART0_C2_TI_RI
			LDR		R2,=UART0_BASE
			STRB	R1,[R2,#UART0_C2_OFFSET]	;Store the value of UART0_C2_TI_RI into TransmitQueue with offset UART_C2_OFFSET
			POP		{R0-R2, PC}			;Restore R0-R2 and PC values
			ENDP
			

;This is for the ISR that will handle UART0 transmit and receive interrupts: UART0_ISR
;No input parameters
;The output is in the TxQ and RxQ, depending on why the interrupt was called. Characters may be 
;added to the TxQ or RxQ, dequeued from the TxQ, or printed to the screen, depending. 
UART0_ISR	PROC    {R0-R14},{}
			CPSID	I						    ;Mask other interrupts		
			PUSH	{LR}					    ;Push any registers used, except {R0-R3,R12}
			
			LDR		R1,=UART0_C2                ;R1 gets the address of the UART0_C2 (Control register 2 of the UART0)
			LDRB	R1,[R1,#0]                  ;R1 gets the byte value of UART0_C2
			MOVS	R2,#UART0_C2_TIE_MASK       ;R2 gets the mask for the TIE (Transmit Interrupt Enabled) in C2
			ANDS	R2,R2,R1                    ;This ANDS will check if the TIE is a 1 ( there was an interrupt )
			BEQ		CheckRDRF                   ;If the TIE is a 0, go to CheckRDRF
		
			LDR		R1,=UART0_S1                ;Otherwise, R1 gets the address of the UART0_S1 (Status register 1 of the UART0)
			LDRB	R1,[R1,#0]                  ;R1 gets the byte value of UART0_S1
			MOVS	R2,#UART0_S1_TDRE_MASK      ;R2 gets the mask for the TDRE (Transmit Data Register Empty) in S1
			ANDS	R2,R2,R1                    ;This ANDS will check if the TRDE is a 1 (the transmit data buffer is empty)
			BEQ		CheckRDRF					;If the ANDS produced a 0, meaning the transmit data buffer is full, go to CheckRDRF
			
			;Dequeue charcter from TransmitQueue
			LDR		R1,=TransmitQueue           ;Otherwise, R1 gets the address of the variable TransmitQueue (TxQ)
			BL		DeQueue                     ;DeQueue from the TransmitQueue
			BCS		onlyElse                    ;If the carry flag was set from the DeQueue, meaning it failed, go to onlyElse
			LDR		R1,=UART0_BASE              ;Otherwise, R1 gets the address of UART0_BASE
			STRB	R0,[R1,#UART0_D_OFFSET]     ;Store the value of the DeQueued item from TxQ and put it into the Data Register
			B		CheckRDRF                   ;Go to CheckRDRF
			
onlyElse
            LDR     R2,=UART0_BASE              ;R2 gets the address of UART0_BASE
            LDRB    R3,[R2,#UART0_C2_OFFSET]    ;R3 gets the byte value of Control Register 2 in UART0 (C2)
            MOVS    R4,#UART0_C2_TIE_MASK       ;R4 gets the mask of the TIE in C2
            BICS    R3,R3,R4                    ;Clear the TIE in C2
            STRB    R3,[R2,#UART0_C2_OFFSET]    ;Store the byte value of C2 with the cleared TIE bit back into C2
            		
CheckRDRF
            LDR		R1,=UART0_S1                ;R1 gets the address of the UART0_S1 (Status Register 1 of UART0)
			LDRB	R1,[R1,#0]                  ;Load the byte value of S1 into R1
			MOVS	R2,#UART0_S1_RDRF_MASK      ;R2 gets the mask of the RDRF (Receive Data Register Full) in S1
			ANDS	R2,R2,R1                    ;This ANDS checks if the RDRF is full (the RDRF bit is a 1)
			BEQ		EndIfs                      ;If the RDRF bit is a 0, go to EndIfs
			
			LDR		R1,=UART0_BASE              ;Otherwise, the RDRF bit is a 1, so R1 gets the address of the UART0_BASE
			MOVS	R2,#UART0_D_OFFSET          ;R2 gets the value of the offset for the address of the data register
			LDRB	R0,[R1,R2]                  ;Load the value from the data register into R0
			LDR		R1,=ReceiveQueue            ;R1 gets the address of the ReceiveQueue (RxQ)
			BL		EnQueue					    ;Enqueue character into ReceiveQueue

EndIfs
			CPSIE	I						    ;Unmask other interrupts
			POP		{PC}					    ;POP PC
            ENDP

		
	
;This subroutine initializes the IRQ so that the TransmitQueue and ReceiveQueue.
;There are no input parameters.
;There are no output parameters, just the initialization of the UART0_IRQ and the TxQ, RxQ, and queue
;that holds the characters for this program.
Init_UART0_IRQ		PROC		{R0-R14},{}
		
            PUSH	{R0-R3, LR}
            ;Set UART0 IRQ priority
            LDR     R0,=QBufferTransmit         ;R0 gets the address of the QBufferTransmit variable (Buffer for the TxQ)
            LDR     R1,=TransmitQueue           ;R1 gets the address of the TransmitQueue variable (TxQ Record)
            MOVS	R2,#TR_BUF_SZ               ;R2 gets the size of the TxQ
            BL      InitQueue                   ;Initialize the TxQ
            
            LDR     R0,=QBufferReceive          ;R0 gets the address of the QBufferReceive variable (Buffer for the RxQ)
            LDR     R1,=ReceiveQueue            ;R1 gets the address of the ReceiveQueue variable (RxQ Record)
            MOVS	R2,#TR_BUF_SZ               ;R2 gets the size of the RxQ
            BL      InitQueue                   ;Initialize the RxQ
            
            LDR		R0,=SIM_SOPT2
            LDR		R1,=SIM_SOPT2_UART0SRC_MASK
            LDR		R2,[R0,#0]
            BICS	R2,R2,R1
            LDR		R1,=SIM_SOPT2_UART0_MCGPLLCLK_DIV2
            ORRS	R2,R2,R1
            STR		R2,[R0,#0]
            ;Enable external connection for UART0
            LDR		R0,=SIM_SOPT5
            LDR		R1,=SIM_SOPT5_UART0_EXTERN_MASK_CLEAR
            LDR		R2,[R0,#0]
            BICS	R2,R2,R1
            STR		R2,[R0,#0]
            ;Enable clock for UART0 module
            LDR		R0,=SIM_SCGC4
            LDR		R1,=SIM_SCGC4_UART0_MASK
            LDR		R2,[R0,#0]
            ORRS	R2,R2,R1
            STR		R2,[R0,#0]
            ;Enable clock for Port A module		
            LDR		R0,=SIM_SCGC5
            LDR		R1,=SIM_SCGC5_PORTA_MASK
            LDR		R2,[R0,#0]
            ORRS	R2,R2,R1
            STR		R2,[R0,#0]
            ;Connect PORT A Pin 1 (PTA) to UART0 Rx (J1 Pin 02)
            LDR		R0,=PORTA_PCR1
            LDR		R1,=PORT_PCR_SET_PTA1_UART0_RX
            STR		R1,[R0,#0]
            ;Connect PORT A Pin 2 (PTA2) to UART0 Tx (J1 Pin 04)
            LDR		R0,=PORTA_PCR2
            LDR		R1,=PORT_PCR_SET_PTA2_UART0_TX
            STR		R1,[R0,#0]
            ;Disable UART0 receiver and transmitter
            LDR		R0,=UART0_BASE
            MOVS	R1,#UART0_C2_T_RI
            LDRB	R2,[R0,#UART0_C2_OFFSET]
            BICS	R2,R2,R1
            STRB	R2,[R0,#UART0_C2_OFFSET]
                        
            LDR		R0,=UART0_IPR
            LDR		R2,=NVIC_IPR_UART0_PRI_3
            LDR		R3,[R0,#0]
            ORRS	R3,R3,R2
            STR		R3,[R0,#0]
            ;Clear any pending UART0 interrupts
            LDR		R0,=NVIC_ICPR
            LDR		R1,=NVIC_ICPR_UART0_MASK
            STR		R1,[R0,#0]
            ;Unmask UART0 interrupts
            LDR		R0,=NVIC_ISER
            LDR		R1,=NVIC_ISER_UART0_MASK
            STR		R1,[R0,#0]
            
            LDR		R0,=UART0_BASE
            ;Set UART0 for 9600 baud, 8N1 protocol	
            MOVS	R1,#UART0_BDH_9600
            STRB	R1,[R0,#UART0_BDH_OFFSET]
            MOVS	R1,#UART0_BDL_9600
            STRB	R1,[R0,#UART0_BDL_OFFSET]
            MOVS	R1,#UART0_C1_8N1
            STRB	R1,[R0,#UART0_C1_OFFSET]
            MOVS	R1,#UART0_C3_NO_TXINV
            STRB	R1,[R0,#UART0_C3_OFFSET]
            MOVS	R1,#UART0_C4_NO_MATCH_OSR_16
            STRB	R1,[R0,#UART0_C4_OFFSET]
            MOVS	R1,#UART0_C5_NO_DMA_SSR_SYNC
            STRB	R1,[R0,#UART0_C5_OFFSET]
            MOVS	R1,#UART0_S1_CLEAR_FLAGS
            STRB	R1,[R0,#UART0_S1_OFFSET]
            MOVS	R1,#UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS
            STRB	R1,[R0,#UART0_S2_OFFSET]
            ;Enable UART0 reciever and transmitter
            MOVS    R1,#UART0_C2_T_RI
            STRB    R1,[R0,#UART0_C2_OFFSET] 
            POP		{R0-R3, PC}
            ENDP


;This subroutine initializes the PIT so that a clock will be set to count 
;once every 10 ms (.01 seconds). 
Init_PIT_IRQ		PROC	{R0-R14},{}
	
		PUSH	{R0-R3}
		LDR   	R0,=SIM_SCGC6
		LDR   	R1,=SIM_SCGC6_PIT_MASK
		LDR   	R2,[R0,#0];current SIM_SCGC6 value
		ORRS  	R2,R2,R1;only PIT bit set
		STR   	R2,[R0,#0];update SIM_SCGC6
		
		;Disable PIT timer to 0
		LDR		R0,=PIT_CH0_BASE
		LDR		R1,[R0,#0]
		LDR		R2,=PIT_TCTRL_CH_IE
		BICS	R1,R1,R2
		STR		R1,[R0,#0]
	
		;Set PIT IRQ priority to 0
		LDR   	R0,=PIT_IPR
		LDR   	R1,=PIT_IRQ_PR1
		;LDR   R2,=(PIT_IRQ_PR1 << PIT_PR1_POS)
		STR   	R1,[R0,#0]
		;BICS 	R3,R3,R1
		;ORRS  R3,R3,R2
		;STR   	R3,[R0,#0]
		
		;Allows timers to be stopped in debug mode
		LDR   	R0,=PIT_BASE
		LDR   	R1,=PIT_MCR_EN_FRZ
		STR   	R1,[R0,#PIT_MCR_OFFSET]
		
		;Clear PIT Channel 0 interrupt
		LDR   	R0,=PIT_CH0_BASE
		LDR   	R1,=PIT_TFLG_TIF_MASK
		STR   	R1,[R0,#PIT_TFLG_OFFSET]
		
		;Unmask PIT interrupts
		LDR   	R0,=NVIC_ISER
		LDR  	R1,=PIT_IRQ_MASK
		STR  	R1,[R0,#0]
		
		;Enable PIT module
		LDR		R0,=PIT_MCR
		LDR		R1,[R0,#0]
		MOVS	R2,#2_00000010
		BICS	R1,R1,R2
		STR		R1,[R0,#0]
		
		
		;Set PIT timer 0 period for 0.01s
		LDR   	R0,=PIT_CH0_BASE
		LDR  	R1,=PIT_LDVAL_10ms
		STR   	R1,[R0,#PIT_LDVAL_OFFSET]
		
		;Enable PIT timer 0 with interrupt
		LDR		R0,=PIT_CH0_BASE
		MOVS  	R1,#PIT_TCTRL_CH_IE
		STR   	R1,[R0,#PIT_TCTRL_OFFSET]
		
		POP		{R0-R3}
		BX		LR
		ENDP
		
;This is where the interrupt for the PIT_ISR leads to. This section of code handles running and
;incrementing a variable named Count that is incremented once every 10 ms, assuming that the 
;stop watch is running. In either case, where the stopwatch is running or if it isn't, the PIT
;Channel 0 interrupt is cleared so that the program can continue as it was before the interrupt.
PIT_ISR		PROC	{R0-R14}, {}
		
		PUSH	{R0-R1}                  ;Saves the values in registers R0-R1
		LDR   	R0,=RunStopWatch         ;R0 gets the address of the variable RunStopWatch
		LDRB	R0,[R0,#0]               ;R0 gets the value of the variable RunStopWatch
		CMP		R0,#0                    ;Comparing the value of RunStopWatch to 0
		BEQ		ClearInterrupt           ;If RunStopWatch is 0, go to ClearInterrupt
		LDR		R0,=Count                ;Otherwise, R0 gets the address of the variable Count
		LDR		R1,[R0,#0]               ;R1 gets the value of Count
		ADDS	R1,R1,#1                 ;Increment R1 by 1
		STR		R1,[R0,#0]               ;Store the new value of Count into the address of Count
                                         ;Go to ClearInterrupt
ClearInterrupt
		
        ;Clear Pit Channel 0 interrupt 
		LDR   	R0,=PIT_CH0_BASE         
		LDR   	R1,=PIT_TFLG_TIF_MASK
		STR   	R1,[R0,#PIT_TFLG_OFFSET]
        
		POP		{R0-R1}                  ;Restores the values of registers R0-R1
		BX		LR          
		ENDP
		


;No input parameters.
;Prints out a new line to the terminal. 
NewLine		PROC		{R0-R14}, {}
;Keep
        PUSH	{R0, LR}
        MOVS	R0,#0x0A		;Move the value hex A into R0, which is the ascii value for NL, or new line.
        BL		PutChar			;Print the value of the ascii number in R0 to the screen, so a new line is printed. 
        MOVS	R0,#0x0D		;Move the value hex D into R0, which is the ascii value for CR, or carriage return.
        BL		PutChar			;Print the value of the ascii number in R0 to the screen, so the carriage return is printed. 
        POP		{R0, PC}
        ENDP
		
	
GetRandomNumber     PROC       {R1-R14}
    
        PUSH    {R1, LR}
        LDR     R1,=Count
        LDR     R1,[R1,#0]
        MOVS    R0,#4
        BL      DIVU
        MOVS    R0,R1
        POP     {R1, PC}
        ENDP

;This subroutine initializes the queue. It sets the InPointer and OutPointer
;both to point at the beginning of QBuffer. BufferStart is the address at the 
;start of QBuffer. BufferSize is the total size that the queue can hold. Before
;anything is added to the queue, the total size of the queue is 0, so 
;NumberEnqueue is set to equal 0. 
;Input Parameters:
;R0	: Buffer of Queue being initialized
;R1 : Queue being initialized
;R2 : Size of buffer
InitQueue	PROC	{R0-R14}, {}

	PUSH  {R0-R2}
	;LDR   R0,=QBuffer 
	;LDR   R1,=QRecord 
	STR   R0,[R1,#IN_PTR] 
	STR   R0,[R1,#OUT_PTR] 
	STR   R0,[R1,#BUF_STRT] 
	;MOVS  R2,#Q_BUF_SZ 
	ADDS  R0,R0,R2 
	STR   R0,[R1,#BUF_PAST] 
	STRB  R2,[R1,#BUF_SIZE] 
	MOVS  R0,#0 
	STRB  R0,[R1,#NUM_ENQD] 
	POP	  {R0-R2}
	BX		LR
	ENDP
        
;This subroutine removes a character from the queue (FIFO). If there are no characters
;to remove from the queue, the C flag is set. 
;Input Parameters:
;R1: Pointer to QRecord
;Output:
;R0: Character DeQueued
;C (flag of PSR): success(0) or failure(1) of dequeue
;Modify: R0,APSR
;Other registers remain unchanged on return
DeQueue		PROC	{R1 - R14}, {}
;Keep
            PUSH	  {R1-R6}			        ;Save values of registers 1-6
            LDRB	  R4,[R1,#NUM_ENQD]     	;R4 gets the total size of the Queue
            CMP  	  R4,#0				        ;Compare the size of the Queue to 0
            BLE	  	  SetCDeQ			        ;If R4 <= 0, go to SetC
            
            LDR		  R3,[R1,#OUT_PTR]	        ;R3 gets the value the starting address of the Queue plus an offset of the value of OUT_PTR				
            LDRB	  R6,[R3,#0]		        ;R0 gets the value being dequeued
            SUBS  	  R4,R4,#1			        ;Decrement the size of the Queue
            STRB	  R4,[R1,#NUM_ENQD]     	;Store the new size of the Queue
            LDR		  R5,[R1,#BUF_PAST]         ;R5 gets the address value at the address just past the last queue value
            ADDS	  R3,R3,#1			        ;Increment the OutPointer past the queue item
            STR		  R3,[R1,#OUT_PTR]
            CMP		  R3,R5				        ;Compares the OutPointer to the address value of the queue buffer
            BEQ		  AdjustPTRDeQ		        ;If the OutPointer is outside of the queue, go to AdjustPTR
            B		  ClearCDeQ			        ;Else, go to ClearC

AdjustPTRDeQ
            LDR		  R4,[R1,#BUF_STRT]
            STR	      R4,[R1,#OUT_PTR]	        ;Set the address into R3 to the address at the start of the queue
            B	      ClearCDeQ

ClearCDeQ
            MRS		  R0,APSR		            ;The following lines clear the C flag
            MOVS	  R1,#0x20
            LSLS	  R1,R1,#24
            BICS	  R0,R0,R1
            MSR		  APSR,R0
            B		  EndDequeue
	
SetCDeQ
            MRS		  R0,APSR	                ;The following lines set the C flag
            MOVS	  R1,#0x20
            LSLS      R1,R1,#24
            ORRS      R0,R0,R1
            MSR		  APSR,R0
            B		  EndDequeue
	
EndDequeue
            MOVS	R0,R6
            POP		{R1-R6}                 	;Restore values of registers 1-6
            BX		LR
            ENDP
	
;This subroutine adds a character to the queue, so long as there is space left to add it.
;If there is no more space in the queue to add, the C flag is set.
;Input Parameters:
;R0: Character EnQueued
;R1: Pointer to QRecord
;Output:
;C (flag of PSR): success(0) or failure(1) of dequeue
;Modify: APSR
;Other registers remain unchanged on return
EnQueue			PROC	{R1-R14}, {}
            PUSH	{R0-R5}				        ;Save values of registers 1-5
            LDRB	R2,[R1,#BUF_SIZE]	        ;Gets the address where the buffer size is 
            LDRB	R3,[R1,#NUM_ENQD]	        ;Gets the address where the total number of enqueued items is
            CMP		R3,R2				        ;Comparing the buffer size to the total number of enqueued items
            BHS		SetCEnQ				        ;If the number of enqueued items is higher or the same as the size, go to SetC
            
            LDR		R4,[R1,#IN_PTR]		        ;Otherwise, load the address of the in pointer to register R4
            STRB	R0,[R4,#0]			        ;Store the character that was enqueued into the address with the in pointer
            ADDS	R4,R4,#1			        ;Increment the address
            STR		R4,[R1,#IN_PTR]		        ;Store the new incremented address of in pointer into memory at the in pointer address
            ADDS	R3,R3,#1			        ;Increment the total number of enqueued items
            STRB	R3,[R1,#NUM_ENQD]       	;Store the total number of enqueued items into memory
            LDR		R5,[R1,#BUF_PAST]	        ;Load the address of the buffer past into R5
            CMP		R4,R5				        ;Compare the addresses of in pointer and buffer past
            BEQ		AdjustPTREnQ		        ;If they are equal, go to AdjustPTREnQ
            B		ClearCEnQ			        ;Otherwise, go to ClearC
            
AdjustPTREnQ
            LDR		R4,[R1,#BUF_STRT]
            STR	    R4,[R1,#IN_PTR]	            ;Set the address into R4 to the address at the start 
                                                ;of the queue
            B	      ClearCEnQ
	
ClearCEnQ
            MRS		R0,APSR		                ;The following lines clear the C flag
            MOVS	R1,#0x20
            LSLS	R1,R1,#24
            BICS	R0,R0,R1
            MSR		APSR,R0
            B		EndEnQueue
            
SetCEnQ
            MRS		R0,APSR	                    ;The following lines set the C flag
            MOVS	R1,#0x20
            LSLS    R1,R1,#24
            ORRS    R0,R0,R1
            MSR		APSR,R0
            B		EndEnQueue
	
EndEnQueue
            POP		{R0-R5}	                    ;Restore values of registers 1-5
            BX		LR
            ENDP

;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
            IMPORT  HardFault_Handler
__Vectors 

                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    HardFault_Handler  ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendableSrvReq (pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 xfer complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 xfer complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 xfer complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 xfer complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:command complete; read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:I2C1
            DCD    Dummy_Handler      ;26:SPI0 (all IRQ sources)
            DCD    Dummy_Handler      ;27:SPI1 (all IRQ sources)
            DCD	   UART0_ISR		  ;28:UART0 (status; error)
            DCD    Dummy_Handler      ;29:UART1 (status; error)
            DCD    Dummy_Handler      ;30:UART2 (status; error)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:TPM2
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    PIT_ISR		      ;38:PIT (all IRQ sources)
            DCD    Dummy_Handler      ;39:I2S0
            DCD    Dummy_Handler      ;40:USB0
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:Segment LCD
            DCD    Dummy_Handler      ;46:PORTA pin detect
            DCD    Dummy_Handler      ;47:PORTC and PORTD pin detect
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants

            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<

beginningPrompt DCB     0x0D, "Welcome to Color Match!", 0x0A, 0x0D, "Press 'Enter' to start and 'R' for rules.", 0x0A, 0x0D, 0
helpCommands    DCB     0x0D, "RULES:", 0x0A, 0x0D, "LEDSs will light up on the microcontroller once the game begins.", 0x0A, 0x0D, 0
helpCommands2   DCB     0x0D, "If one LED is lit, press 'R' if the red LED is lit and 'G' if the green LED is lit." 0x0A, 0x0D, 0
helpCommands3   DCB     0x0D, "If both are lit, press 'B' and if neither are lit, press 'N'.", 0x0A, 0x0D, 0
helpCommands4   DCB     0x0D, "Wrong answers reduce the value of getting the right answer." 0x0A, 0x0D, 0
helpCommands5   DCB     0x0D, "The further the round, the faster and harder the game gets." 0x0A, 0x0D, 0 
helpCommands6   DCB     0x0D, "The faster the correct answer, the more points you get! Good Luck!", 0x0A, 0x0D, 0

correct         DCB     0x0D, ":   Correct--color was ", 0
wrong           DCB     0x0D, ":   Wrong", 0x0A, 0x0D, 0
outOfTime       DCB     0x0D, ":   Out of time--color was ", 0
red             DCB     "red", 0x0D, 0x0A, 0
green           DCB     "green", 0x0D, 0x0A, 0
both            DCB     "both", 0x0D, 0x0A, 0
neither         DCB     "neither", 0x0D, 0x0A, 0

currentScore    DCB     "Current Score: ", 0
finalScore      DCB     "Final Score: ", 0 

;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<

TransmitQueue       SPACE       Q_REC_SZ    ;The TxQ Record
                    ALIGN
ReceiveQueue        SPACE       Q_REC_SZ    ;The RxQ Record
                    ALIGN   
QBufferTransmit		SPACE		TR_BUF_SZ   ;Buffer for the TxQ
                    ALIGN   
QBufferReceive		SPACE		TR_BUF_SZ   ;Buffer for the RxQ
                    ALIGN
RunStopWatch		SPACE		1           ;Byte value representing a stopwatch
					ALIGN
Count				SPACE		4           ;Count value representing 10 ms for each value
					ALIGN
HoldingAddress		SPACE		MAX_STRING  ;The address to hold the input string for GetString
                    
;>>>>>   end variables here <<<<<
            ALIGN
            END