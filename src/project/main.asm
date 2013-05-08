/*
 * main.asm
 *
 *  Created: 28/04/2013
 *   Author: Jorge Arraez
 *			 Juan Herrero
 */ 
 
.def temp = r16

.equ intervalo_max = 500 // Numero maximo de ciclos que pasan desde el evento anterior a partir del cual reiniciamos la cuenta
.equ top_timer = 0xFF

.include <m2560def.inc>

//Segmento de c?digo
.cseg

.org 0x00 // Reset
Reset:	rjmp Inicio

.org ICP3addr //Interrupcion cuando hay un cambio de flanco segun se configure en TCCR3B
	rjmp  capturar_tiempo //saltamos al subrutina temporizador

.org INT_VECTORS_SIZE

// -----------------------------------------------------------------------------------

Inicio:
cli //Deshabilitamos interrupciones

// Incializo stack pointer
ldi temp, high(RAMEND)
out SPH, temp
ldi temp, low(RAMEND)
out SPL, temp

// Habilitamos la mascara de interrupcion para el timer 3 de 16 bits
lds r16, TIMSK3
sbr r16, (1<<ICIE3)
sts TIMSK3, r16

// Configuramos el timer 3 de 16 bits como rising edge y sin prescaler
	// TCCR3B
	// Bit 7 ? ICNCn: Input Capture Noise Canceler
		// 1 Enable || 0 Disablegmail
	// Bit 6 ? ICESn: Input Capture Edge Select
		// 1 Rising || 0 Falling
	// Bit 4:3 ? WGMn3:2: Waveform Generation Mode
	// Bit 2:0 ? CSn2:0: Clock Select
		// Eleccion del prescaler
		/*	0 0 0 No clock source. (Timer/Counter stopped)
			0 0 1 clkI/O/1 (No prescaling
			0 1 0 clkI/O/8 (From prescaler)
			0 1 1 clkI/O/64 (From prescaler)
			1 0 0 clkI/O/256 (From prescaler)
			1 0 1 clkI/O/1024 (From prescaler)*/
lds r16, TCCR3B
sbr r16, (1<<ICNC3) + (1<<ICES3) +  (1<<WGM33) + (1<<WGM32) + (1<<CS30)
sts TCCR3B,r16

	// TCCR3A
	// Bit 1:0 ? WGMn1:0: Waveform Generation Mode
			// WGMn 1 1 0 0 CTC ICRn
lds r16, TCCR3A
cbr r16, 0b0000011
sts TCCR3A, r16

// Inicializamos la variable CUENTA
	// ldi R16, 0b00000010
	// sts CUENTA, r16
// Inicializamos el puntero X
ldi R27, high(VARIABLE)
ldi R26, low(VARIABLE)

pop r16
sei // habilitamos interrupciones

// -----------------------------------------------------------------------------------

Ppal:
rjmp Ppal

// -----------------------------------------------------------------------------------

capturar_tiempo:
//IN r18,SREG
//PUSH r18
push r17
push r16
push r18
push r27
push r28

// 
// Cargamos los valores del input capture timer en el registro y los guardamos en memoria
lds r16, ICR3L
lds r17, ICR3H
st X+,r16
st X+,r17
// Reiniciamos el valor de ICR al valor TOP que queramos
ldi r16, top_timer
ldi r17, 0xFF
sts ICR3H, r16
sts ICR3L, r17
// Cambio el flanco con el que salta la interrupcion
ldi r16, 0b01000000
lds r17, TCCR3B
eor r16,r17
sts TCCR3B,r16

pop r17
pop r16
pop r18
pop r27
pop r28

reti

// -----------------------------------------------------------------------------------

.dseg

CUENTA: .byte 1
VARIABLE: .byte 1

