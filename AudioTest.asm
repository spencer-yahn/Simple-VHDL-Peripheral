; AudioTest.asm
; This assembly program will utilize the AudioMonitor.vhd peripheral. It will use the peripheral
; to record snap data from two players, and read from the peripheral to get the corresponding letter
; data for each player. If the letters from both players match, a score will be incremented and displayed.
; Group 1 
; ECE 2031 L10 
; 4/14/23

ORG 0

	Reset:					; Initial reset that happens only once: the start of the first round
	LOADI	0
	STORE	Score			; Initialize the score to 0 at start
	
ResetRound:					; Jump here to start a new round of the game
	LOADI 	0				; Reseting variables to 0 at start of new round
	STORE	ValA			; Set player 1's score to 0
	STORE	ValB			; Set player 2's score to 0
	STORE	ValAS			; Set the shifted version of player 1's score to 0
	
; Start of Player 1's part of the game

Wait:						; Waiting for player 1 to turn up SW4
	IN		Switches		; Reading from switches, will get 16 if SW4 is up
    ADDI 	-16				; Subtracting 16 from the Switch output, AC will be 0 if SW4 was up
    JZERO 	Record1			; If AC is 0, jump to Record1
    JUMP	Wait			; If not, go back to wait and check if SW4 is up
    
Record1: 					; Clears old data from Hex0, writes to peripheral to start it
	LOADI	0
	OUT		Hex0
	OUT 	OP				; Starts the peripheral, peripheral will start detecting snaps
	
Record2:					; As long as SW4 is up, the peripheral will keep collecting data
    LOADI	1
    OUT 	LEDs			; LED0 will be on to indicate that the peripheral is recording data
    IN 		Switches		; Read from switches, if SW4 is up AC will be 16.
    JZERO	Show			; If all switches are down, AC will be 0, and control jumps to Show
    JUMP	Record2			; If not, go back to Record2 to continue collecting data
    
   
Show:						; Read data from peripheral, output it onto Hex0
	LOADI	0
    OUT		LEDs			; Indicate recording is done, turns LED0 off
	IN		OP				; Take player 1's letter data from peripheral
	STORE	ValA			; Store letter data into ValA
	SHIFT	8				; Shift the 2 letters 8 bits to the left
							; so that player 1's letters occupy the left two 7-segment displays in Hex0
	STORE	ValAS			; Store shifted player 1 data in ValAS
    OUT		Hex0			; Output shifted player 1 data on Hex0
    JUMP	WaitB			; Jump to WaitB
	
; Start of Player 2's part of the game

WaitB:						; Waiting for player 2 to turn up SW4
	IN		Switches		; Reading from switches, will get 16 if SW4 is up
    ADDI 	-16				; Subtracting 16 from the Switch output, AC will be 0 if SW4 was up
    JZERO 	RecordB1		; If AC is 0, jump to RecordB1
    JUMP	WaitB			; If not, go back to waitB and check if SW4 is up
    
RecordB1: 					; Writes to peripheral to start it
	OUT 	OP				; Starts the peripheral: peripheral will start detecting snaps

RecordB2:					; As long as SW4 is up, the peripheral will keep collecting data
    LOADI	1
    OUT 	LEDs			; LED0 will be on to indicate that the peripheral is recording data
    IN 		Switches		; Read from switches, if SW4 is up AC will be 16.
    JZERO	ShowB			; If all switches are down, AC will be 0, and control jumps to ShowB
    JUMP	RecordB2		; If not, go back to RecordB2 to continue collecting data
    
ShowB:						; Read data from peripheral, output it onto Hex0
	LOADI	0
    OUT		LEDs			; Indicate recording is done, turns LED0 off
	IN		OP				; Take player 2's letter data from peripheral
	STORE	ValB			; Store letter data into ValB
	OR 		ValAS			; Bitwise OR with ValB and ValAS (ValA shifted left 8 bits)
							; We do this to create 1 16-bit result where the most significant 8 bits
							; (from ValAS) correspond to the 2 letters put in by player 1,
							; and the least significant 8 bits (from ValB) correspond to the 2 letters 
							; put in by player 2
    OUT		Hex0			; Output this combined output to Hex0
    JUMP	Ignore7+		; Jump to Ignore7+
	
Ignore7+:					; Resets the round if any player snaps more than 6 times
							; Our peripheral outputs 7 for any snap count greater than 6
	LOAD	ValA			; Loads ValA, player 1's letters
	AND	 	FirstLtr		; Bitwise AND masks ValA to get only the first letter
	ADDI    -112			; 0x70 in decimal, checks if first letter was 7
	JZERO	ResetRound		; Jumps to ResetRound if AC is 0
	LOAD	ValA			; Loads ValA, player 1's letters
	AND	 	SecondLtr		; Bitwise AND masks ValA to get only the second letter
	ADDI    -7				; 0x07 in decimal, checks if second letter was 7
	JZERO	ResetRound		; Jumps to ResetRound if AC is 0
	
	LOAD	ValB			; Loads ValA, player 2's letters
	AND	 	FirstLtr		; Bitwise AND masks ValB to get only the first letter
	ADDI    -112			; 0x70 in decimal, checks if first letter was 7
	JZERO	ResetRound		; Jumps to ResetRound if AC is 0
	LOAD	ValB			; Loads ValB, player 2's letters
	AND	 	SecondLtr		; Bitwise AND masks ValB to get only the second letter
	ADDI    -7				; 0x07 in decimal, checks if second letter was 7
	JZERO	ResetRound		; Jumps to ResetRound if AC is 0
	
Compare:					; Compare the letters from player 1 and player 2
	LOAD	ValA			; Loads ValA (from player 1) into AC
	SUB		ValB			; Subtracts ValB from ValA
	JZERO	Matched			; If ValA = ValB, then jump to Matched
	JUMP	ResetRound		; If ValA /= ValB, jump to ResetRound
	
Matched:					; If player 1 and player 2's letters matched, increase score
	LOAD	Score			; Load the current score value
	ADDI	1				; Increment score by 1
	STORE	Score			; Store the incremented score back to score
	OUT		Hex1			; Update Hex1 with the incremented score
	JUMP	ResetRound		; Jump to ResetRound after updating score
    
    
    
    

; Variables
ValA:		DW	0				; Player 1's letter data from the peripheral
ValAS:		DW	0				; ValA shifted left by 8 bits
ValB:		DW	0				; Player 2's letter data from the peripheral
Score:		DW	0				; Score variable
FirstLtr: 	DW	240				; 0xF0, used to get only the first letter from a player
SecondLtr:	DW	15				; 0x0F, used to get onlt the second letter from a player


; IO address constants
Switches:  EQU 000
LEDs:      EQU 001
Timer:     EQU 002
Hex0:      EQU 004
Hex1:      EQU 005
OP:		   EQU &H50			; OP = Our Peripheral