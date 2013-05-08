/*
 * main.asm
 *
 *  Created: 28/04/2013
 *   Author: Jorge Arraez
 *			 Juan Herrero
 */ 
 
.def temp = r16

.equ top_timer_high = 0xFF // Numero maximo de ciclos que pasan desde el evento anterior a partir del cual reiniciamos la cuenta

.include <m2560def.inc>

//Segmento de codigo
.cseg

.org 0x00 // Reset
Reset:	rjmp Inicio

.org ICP3addr //Interrupcion cuando hay un cambio de flanco segun se configure en TCCR3B
	rjmp guardar_bit //saltamos al subrutina temporizador

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

// Inicializamos el puntero X
ldi r27, high(VARIABLE)
ldi r26, low(VARIABLE)

pop r16
sei // habilitamos interrupciones

// -----------------------------------------------------------------------------------

Ppal:
rjmp Ppal

// -----------------------------------------------------------------------------------
// Esta funcion guarda los intervalos entre cada cambio de pin del sensor 
// Cuando se termina de recibir un bit (lee blanco) lo procesa y lo guarda en el último bit de BYTE
// TODO --> Falta por anadir la condicion de desborde de tiempo o de procesamiento de byte

guardar_bit:
//IN r18,SREG
//PUSH r18
push r17
push r16
push r18
push r27
push r28

/*// Cargamos los valores del input capture timer en el registro y los guardamos en memoria
lds r16, ICR3L
lds r17, ICR3H
st X+,r16
st X+,r17*/


// Si he leo blanco proceso bit, si leo negro espero a proxima interrupcion
in r16, PINE
andi r16, 0b10000000 
lds r16, ICR3H // Leo el valor del Input Capture
breq es_negro // si el pin vale 0 (lee negro)

es_blanco: // Guardo el tiempo en T2 y procesor si el bit es 1 o 0
sts T2, r16
lds r17, T1
add r17, r16
ror r17
clc
sub r17, r16
brcs bit_es_1 // Saltamos si |r16| > |r17| --> Bit 1
bit_es_0: // En caso contrario el bit es 0
lds r16, BYTE
andi r16, 0b11111110
sts BYTE, r16
rjmp fin_guardar_bit

bit_es_1:
lds r16, BYTE
ori r16, 0b00000001
sts BYTE,r16
rjmp fin_guardar_bit

es_negro: // Guardo el tiempo en T1
sts T1, r16

fin_guardar_bit:
// Reiniciamos el valor de ICR al valor TOP que hayamos escogido
ldi r16, top_timer_high
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
T1: .byte 1 // Guarda el ultimo intervalo negro
T2: .byte 1	// Guarda el ultimo intervalo blanco
BYTE .byte 1 // Guarda en su ultimo bit el ultimo bit procesado 
			 // y en el resto guarda los anteriores bits procesados para formar el byte
STARJETA: .byte 1
VARIABLE: .byte 1

