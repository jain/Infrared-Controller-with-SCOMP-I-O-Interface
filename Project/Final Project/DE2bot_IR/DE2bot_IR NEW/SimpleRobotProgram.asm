; SimpleRobotProgram.asm
; Created by Kevin Johnson
; (no copyright applied; edit freely, no attribution necessary)
; This program:
; 1) performs some basic robot initialization
; 2) waits for the user to enable the motors and press KEY3
; 3) moves forward ~0.5m and stops
; 4) repeats 2-4

	ORG     &H000		;Begin program at x000
Init:
	; Always a good idea to make sure the robot
	; stops in the event of a reset.
	LOAD    Zero
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	OUT     SONAREN     ; Disable sonar

	CALL    SetupI2C    ; Configure the I2C
	CALL    BattCheck   ; Get battery voltage (and end if too low).
	OUT     SSEG2       ; Display batt voltage on SS

Main:
	LOAD    Zero
	ADDI    &H17        ; reminder to toggle SW17
	OUT     SSEG1
WaitForUser:
	IN      XIO         ; contains KEYs and SAFETY
	AND     StartMask   ; mask with 0x10100 : KEY3 and SAFETY
	XOR     Mask4       ; KEY3 is active low; invert SAFETY to match
	JPOS    WaitForUser ; one of those is not ready, so try again
	OUT     RESETODO    ; reset odometry in case wheels have moved
	
Run:
	IN		IR		; Read in value stored in IR
	ADDI	-160	; Add -160 to it
	JZERO	Fwd		; if value in AC is 0 now, jump to Fwd
	IN		IR		; Read in value stored in IR
	ADDI	-176	; Add -176 to it
	JZERO	Right	; if value in AC is 0 now, jump to Right
	IN		IR		; Read in value stored in IR
	ADDI	-224	; Add -224 to it
	JZERO	Left	; if value in AC is 0 now, jump to Left
	IN		IR		; Read in value stored in IR
	ADDI	-240	; Add -240 to it
	JZERO	Bwd		; if value in AC is 0 now, jump to Bwd
	IN		IR		; Read in value stored in IR
	ADDI	-112	; Add -112 to it
	JZERO	Speed1	; if value in AC is 0 now, jump to Speed1
	IN		IR		; Read in value stored in IR
	ADDI	-56		; Add -56 to it
	JZERO	Speed2	; if value in AC is 0 now, jump to Speed2
	IN		IR		; Read in value stored in IR
	ADDI	-192	; Add -92 to it
	JZERO	RightSlow	; if value in AC is 0 now, jump to RightSlow
	IN		IR		; Read in value stored in IR
	ADDI	-64		; Add -64 to it
	JZERO	LeftSlow	; if value in AC is 0 now, jump to LeftSlow
	JUMP	STOP	; if IR value is any other random signal jump to STOP
; If the battery is too low, we want to make
; sure that the user realizes it...
DeadBatt:
	OUT     BEEPON      ; start beep sound
	CALL    GetBattLvl  ; get the battery level
	OUT     SSEG1       ; display it everywhere
	OUT     SSEG2
	OUT     LCD
	LOAD    Zero
	ADDI    -1          ; 0xFFFF
	OUT     LEDS        ; all LEDs on
	OUT     GLEDS
	CALL    Wait1       ; 1 second
	OUT     BEEPOFF     ; stop beeping
	LOAD    Zero
	OUT     LEDS        ; LEDs off
	OUT     GLEDS
	CALL    Wait1       ; 1 second
	JUMP    DeadBatt    ; repeat forever

; This subroutine will get the battery voltage,
; and stop program execution if it is too low.
BattCheck:
	CALL    GetBattLvl 
	SUB     MinBatt
	JNEG    DeadBatt
	ADD     MinBatt     ; get original value back
	RETURN
	
; Subroutine to configure the I2C for reading batt voltage
; Only needs to be done once after each reset.
SetupI2C:
	LOAD    I2CWCmd     ; 0x1190 (write 1B, read 1B, addr 0x90)
	OUT     I2C_CMD     ; to I2C_CMD register
	LOAD    Zero        ; 0x0000 (A/D port 0, no increment)
	OUT     I2C_DATA    ; to I2C_DATA register
	OUT     I2C_RDY     ; start the communication
	CALL    BlockI2C    ; wait for it to finish
	RETURN
	
; Subroutine to read the A/D (battery voltage)
; Assumes that SetupI2C has been run
GetBattLvl:
	LOAD    I2CRCmd     ; 0x0190 (write 0B, read 1B, addr 0x90)
	OUT     I2C_CMD     ; to I2C_CMD
	OUT     I2C_RDY     ; start the communication
	CALL    BlockI2C    ; wait for it to finish
	IN      I2C_DATA    ; get the returned data
	RETURN

; Subroutine to block until I2C device is idle
BlockI2C:
	IN      I2C_RDY;   ; Read busy signal
	JPOS    BlockI2C    ; If not 0, try again
	RETURN              ; Else return

; Subroutine to wait (block) for 1s
Wait1:
	OUT     TIMER
Wloop:
	IN      TIMER
	ADDI    -10
	JNEG    Wloop
	RETURN
ORG     &H100				; Subroutine Address
Fwd:	LOAD	SPEED		; load speed to AC
		OUT     LVELCMD		; Output AC value to left Motor
		OUT     RVELCMD		; Output AC value to right Motor
		LOAD	ONE			; load 1 to AC
		OUT		SSEG1		; output to seven segment display for debugging purposes
		JUMP	RUN			; Jump back to Run and decode IR again
ORG     &H110				; Subroutine Address
Bwd:   	LOAD	ZERO		; load 0 to AC
		SUB		SPEED		; subtract speed value to obtain its additive inverse
		OUT     LVELCMD		; Output AC value to left Motor
		OUT     RVELCMD		; Output AC value to right Motor
		LOAD	two			; load 2 to AC
		OUT		SSEG1		; output to seven segment display for debugging purposes
		JUMP	RUN			; Jump back to Run and decode IR again
ORG     &H120				; Subroutine Address
Left:	LOAD	TSLOW		; load turn slow value to AC
		OUT		LVELCMD		; Output AC value to left Motor
		LOAD	FSLOW		; load slow speed
		OUT		RVELCMD		; Output AC value to right Motor
		LOAD	three		; load 3 to AC
		OUT		SSEG1		; output to seven segment display for debugging purposes
		JUMP	RUN			; Jump back to Run and decode IR again
ORG		&H130				; Subroutine Address
Right:	LOAD	TSLOW		; load turn slow value to AC
		OUT		RVELCMD		; Output AC value to right Motor
		LOAD	FSLOW		; load slow speed
		OUT		LVELCMD		; Output AC value to left Motor
		JUMP	RUN			; Jump back to Run and decode IR again
ORG		&H140				; Subroutine Address
LeftSlow:	LOAD	TFSlow	; load turnforward slow value
		OUT		LVELCMD		; Output AC value to left Motor
		LOAD	TFSlow		; load turnforward slow value
		OUT		RVELCMD		; Output AC value to right Motor
		LOAD	four		; load 4 to AC
		OUT		SSEG1		; output to seven segment display for debugging purposes
		JUMP	RUN			; Jump back to Run and decode IR again
ORG		&H150				; Subroutine Address
RightSlow:	LOAD	TFSlow 	; load turnforward slow value
		OUT		RVELCMD		; Output AC value to right Motor
		LOAD	TFSlow		; load turnforward slow value
		OUT		LVELCMD		; Output AC value to left Motor
		LOAD	three		; load 3
		OUT		SSEG1		; output to seven segment display for debugging purposes
		JUMP	RUN			; Jump back to Run and decode IR again
ORG		&H160				; Subroutine Address
Speed1:	LOAD FSLOW			; load slow speed value
		STORE	SPEED		; set the speed to the slow value
		JUMP	RUN			; Jump back to Run and decode IR again
ORG		&H170				; Subroutine Address
Speed2:	LOAD FFAST			; load fast speed value	
		STORE	SPEED		; set the speed to the fast value
		JUMP	RUN			; Jump back to Run and decode IR again
ORG		&H180				; Subroutine Address
Stop:	LOAD 	ZERO		; load 0 to AC
		OUT     LVELCMD     ; commmand motors
		OUT     RVELCMD		; Output AC value to left Motor
		LOAD	seven		; load 7 to AC
		OUT		sseg1		; output to seven segment display for debugging purposes
		JUMP	RUN			; Jump back to Run and decode IR again
Store XPOs
JUMP	Auto
Auto: LOAD    FFast       ; Very slow forward movement
	OUT     LVELCMD     ; commmand motors
	OUT     RVELCMD
	IN      LVEL        ; read left velocity
	STORE   Temp        ; save it
	IN      RVEL        ; read right velocity
	ADD     Temp        ; add to left velocity
	SHIFT   -1          ; divide by 2 (average)
	OUT     SSEG1       ; display it (just as an FYI)
	IN      XPOS        ; get current X position
	SUB     OneHalf   ; check the distance
	JNEG   	Auto    ; not there yet; keep checking
	; at this point we're past 0.5m
	LOAD    Zero
	OUT     LVELCMD     ; stop
	OUT     RVELCMD
	JUMP	STOP
; This is a good place to put variables
Temp:     DW 0


; Having some constants can be very useful
Zero:     DW 0
One:      DW 1
Two:      DW 2
Three:    DW 3
Four:     DW 4
Five:     DW 5
Six:      DW 6
Seven:    DW 7
Eight:    DW 8
Nine:     DW 9
Ten:      DW 10
FSlow:    DW 60         ; slow speed variable set to 60
TSlow:    DW -45		; fast turn back wheel spin speed variable set to -45
TFSlow:    DW 30        ; slow turn forward wheel spin speed variable set to 30
TBSlow:    DW -30		; slow turn back wheel spin speed variable set to -30
FFast:    DW 127        ; fast speed variable set to 127
Mask0:    DW &B00000001
Mask1:    DW &B00000010
Mask2:    DW &B00000100
Mask3:    DW &B00001000
Mask4:    DW &B00010000
Mask5:    DW &B00100000
Mask6:    DW &B01000000
Mask7:    DW &B10000000
StartMask: DW &B10100
EnSonars: DW &B11111111
OneMeter: DW 476        ; one meter in 2.1mm units
HalfMeter: DW 238       ; half meter in 2.1mm units
OneHalf: DW 714       ; half meter in 2.1mm units
MinBatt:  DW 110        ; 11V - minimum safe battery voltage
I2CWCmd:  DW &H1190     ; write one byte, read one byte, addr 0x90
I2CRCmd:  DW &H0190     ; write nothing, read one byte, addr 0x90
Speed:	DW	0			; initial speed value is set to 0
Command:  DW &H180
Sixteen:	DW	&H000F
isRun:		DW	0

; IO address space map
SWITCHES: EQU &H00  ; slide switches
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz
XIO:      EQU &H03  ; pushbuttons and some misc. inputs
SSEG1:    EQU &H04  ; seven-segment display (4-digits only)
SSEG2:    EQU &H05  ; seven-segment display (4-digits only)
LCD:      EQU &H06  ; primitive 4-digit LCD display
GLEDS:    EQU &H07  ; Green LEDs (and Red LED16+17)
BEEPON:   EQU &H0A  ; Turn the beep on
BEEPOFF:  EQU &H0B  ; Turn the beep off
LPOS:     EQU &H80  ; left wheel encoder position (read only)
LVEL:     EQU &H82  ; current left wheel velocity (read only)
LVELCMD:  EQU &H83  ; left wheel velocity command (write only)
RPOS:     EQU &H88  ; same values for right wheel...
RVEL:     EQU &H8A  ; ...
RVELCMD:  EQU &H8B  ; ...
I2C_CMD:  EQU &H90  ; I2C module's CMD register,
I2C_DATA: EQU &H91  ; ... DATA register,
I2C_RDY:  EQU &H92  ; ... and BUSY register
SONAR:    EQU &HA0  ; base address for more than 16 registers....
DIST0:    EQU &HA8  ; the eight sonar distance readings
DIST1:    EQU &HA9  ; ...
DIST2:    EQU &HAA  ; ...
DIST3:    EQU &HAB  ; ...
DIST4:    EQU &HAC  ; ...
DIST5:    EQU &HAD  ; ...
DIST6:    EQU &HAE  ; ...
DIST7:    EQU &HAF  ; ...
SONAREN:  EQU &HB2  ; register to control which sonars are enabled
XPOS:     EQU &HC0  ; Current X-position (read only)
YPOS:     EQU &HC1  ; Y-position
THETA:    EQU &HC2  ; Current rotational position of robot (0-701)
RESETODO: EQU &HC3  ; reset odometry to 0
IR:		  EQU &H09  ; IR loader