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
Go50cm:
	LOAD    FSlow       ; Very slow forward movement
	OUT     LVELCMD     ; commmand motors
	OUT     RVELCMD
	IN      LVEL        ; read left velocity
	STORE   Temp        ; save it
	IN      RVEL        ; read right velocity
	ADD     Temp        ; add to left velocity
	SHIFT   -1          ; divide by 2 (average)
	OUT     SSEG1       ; display it (just as an FYI)
	IN      XPOS        ; get current X position
	SUB     HalfMeter   ; check the distance
	JNEG    Go50cm        ; not there yet; keep checking
	; at this point we're past 0.5m
	LOAD    Zero
	OUT     LVELCMD     ; stop
	OUT     RVELCMD
	JUMP    WaitForUser ; repeat

	
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
ORG     &H100
Fwd:	OUT     LVELCMD     ; commmand motors
		OUT     RVELCMD
ORG     &H110
Bwd:   	OUT     LVELCMD     ; commmand motors
		OUT     RVELCMD
ORG     &H120
Left:	LOAD	FSLOW
		OUT		LVELCMD
		LOAD	FFAST
		OUT		RVELCMD
ORG		&H130
Right:	LOAD	FSLOW
		OUT		RVELCMD
		LOAD	FFAST
		OUT		LVELCMD
ORG		&H140; LWF
Motor1: OUT		RVELCMD
ORG		&H150;RWF
Motor2:	OUT		LVELCMD
ORG		&H160
Speed1:	LOAD FSLOW
ORG		&H170
Speed2:	LOAD FFAST
ORG		&H180
Stop:	STORE 	ZERO
		OUT		LVELCMD
		OUT		RVELCMD
; 190 = RWB
; 200 = LWB
	
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
FSlow:    DW 30         ; 30 is about the lowest value that will move at all
RSlow:    DW -30
FFast:    DW 100        ; 100 is a fair clip (127 is max)
RFast:    DW -100
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
MinBatt:  DW 110        ; 11V - minimum safe battery voltage
I2CWCmd:  DW &H1190     ; write one byte, read one byte, addr 0x90
I2CRCmd:  DW &H0190     ; write nothing, read one byte, addr 0x90

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
