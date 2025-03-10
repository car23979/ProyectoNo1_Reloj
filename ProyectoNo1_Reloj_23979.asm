/*
 Proyecto1.asm

 Created: 05/03/2025 01:37:21 p. m.
 Author : David Carranza

 Descripción: 
 */
.include "M328PDEF.inc"

// Definición de registros
.DEF    DISPLAY = R21
.DEF    DECENAS = R23
.DEF    UNIDADES = R24
.DEF    CONTADOR_D = R25

.ORG    0x0000
    RJMP    INICIO  // Vector Reset

.ORG    PCI1addr
    RJMP    PCINT_ISR  // Vector de interrupción PCINT1
.ORG    0x0020
    RJMP    TIMER_ISR

.cseg
.def CONTADOR = R19  // Variable para el contador

// Configuración del Stack
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16
/*
// Inicio del programa
INICIO:
    // Configurar Prescaler
    LDI     R16, (1 << CLKPCE)
    STS     CLKPR, R16  // Habilitar cambio de PRESCALER
    LDI     R16, 0b00000100
    STS     CLKPR, R16  // Prescaler a 16 (F_cpu = 1MHz)

    // Inicializar Timer0
    CALL    INICIALIZAR_TIMER



    LDI     R16, 0x00
    OUT     PORTB, R16
    OUT     PORTD, R16

    // Deshabilitar serial (apaga LEDs adicionales)
    LDI     R16, 0x00
    STS     UCSR0B, R16

    // Iniciar el display en 0s
    LDI     DISPLAY, 0x00
    CALL    ACTUALIZAR_DISPLAY
    LDI     CONTADOR_D, 0x00

    // Configurar interrupciones
    LDI     R16, (1 << PCIE1)  // Habilitar PCIE1
    STS     PCICR, R16
    LDI     R16, (1 << PCINT8) | (1 << PCINT9)  // Habilitar PC0 y PC1
    STS     PCMSK1, R16

    LDI     R16, (1 << TOIE0)  // Habilitar interrupción Timer0
    STS     TIMSK0, R16

    SEI  // Habilitar interrupciones globales

    LDI     R17, 0x00  // Inicializar contador

BUCLE_PRINCIPAL:
    RJMP    BUCLE_PRINCIPAL

// SUBRUTINAS


NO_RESET:
    OUT     PORTB, CONTADOR
    RET

DECREMENTAR_CONTADOR:
    CPI     CONTADOR, 0x00  // Verificar si el contador es 0
    BRNE    DECREMENTAR_NORMAL  // Si no es 0, decrementar normalmente
    LDI     CONTADOR, 0x10  // Si es 0, establecer el contador en 16 (0x10)
DECREMENTAR_NORMAL:
    DEC     CONTADOR        // Decrementar el contador
    OUT     PORTB, CONTADOR // Actualizar el puerto B con el nuevo valor
    RET

INICIALIZAR_TIMER:
    LDI     R16, (1 << CS01) | (1 << CS00)
    OUT     TCCR0B, R16  // Prescaler a 64
    LDI     R16, 100
    OUT     TCNT0, R16  // Valor inicial
    RET

ACTUALIZAR_DISPLAY:
    // Mostrar unidades
    SBI     PORTB, 1  // Encender bit 4
    CBI     PORTB, 2  // Apagar bit 5
    LDI     ZH, HIGH(TABLA << 1)
    LDI     ZL, LOW(TABLA << 1)
    ADD     ZL, UNIDADES
    LPM     R23, Z
    OUT     PORTD, R23
    CALL    RETARDO

    // Mostrar decenas
    CBI     PORTB, 1  // Apagar bit 4
    SBI     PORTB, 2  // Encender bit 5
    LDI     ZH, HIGH(TABLA << 1)
    LDI     ZL, LOW(TABLA << 1)
    ADD     ZL, CONTADOR_D
    LPM     R23, Z
    OUT     PORTD, R23
    CALL    RETARDO

	// Mostrar unidades
    SBI     PORTB, 3  // Encender bit 4
    CBI     PORTB, 4  // Apagar bit 5
    LDI     ZH, HIGH(TABLA << 1)
    LDI     ZL, LOW(TABLA << 1)
    ADD     ZL, UNIDADES
    LPM     R23, Z
    OUT     PORTD, R23
    CALL    RETARDO

    // Mostrar decenas
    CBI     PORTB, 3  // Apagar bit 4
    SBI     PORTB, 4  // Encender bit 5
    LDI     ZH, HIGH(TABLA << 1)
    LDI     ZL, LOW(TABLA << 1)
    ADD     ZL, CONTADOR_D
    LPM     R23, Z
    OUT     PORTD, R23
    CALL    RETARDO

    RET

ACTUALIZAR_DECENAS:
    CLR     UNIDADES
    INC     CONTADOR_D
    RET

RETARDO:
    LDI     R18, 0xFF
RETARDO_1:
    DEC     R18
    CPI     R18, 0
    BRNE    RETARDO_1
    LDI     R18, 0xFF
RETARDO_2:
    DEC     R18
    CPI     R18, 0
    BRNE    RETARDO_2
    LDI     R18, 0xFF
RETARDO_3:
    DEC     R18
    CPI     R18, 0
    BRNE    RETARDO_3
    RET

// RUTINAS DE INTERRUPCIÓN
PCINT_ISR:
    IN      R18, PINC  // Leer estado de los pines
    SBRS    R18, 0  // Si PC0 está alto, incrementar
    CALL    INCREMENTAR_CONTADOR
    SBRS    R18, 1  // Si PC1 está alto, decrementar
    CALL    DECREMENTAR_CONTADOR
    RETI

*/

// MODIFICACIONES NUEVAS

CONFIGURAR_BOTONES:
	//CONFIGURACIÓN DE PUERTOS

    // Configurar PORTC como entrada
    LDI     R16, 0x00
    OUT     DDRC, R16

	// Habilitar pull-ups internos en PC0-PC3
    LDI     R16, 0x0F
    OUT     PORTC, R16

	// Habilitar interrupciones de cambio de pin (PCINT1 para PORTC)
	LDI		R16, (1 << PCIE1)
	STS		PCICR, R16

	// Habilitar interrupciones solo en PC0-PC3 (PCINT8-PCINT11)
	LDI		R16, (1 << PCINT8) | (1 << PCINT9) | (1 << PCINT10) | (1 << PCINT11)
	STS		PCMSK1, R16

	RET

BOTON_ISR:
	
	PUSH	R16
	IN		R16, SREG
	PUSH	R16

	// Leer estados de los botones en PORTC
	IN		R16, PINC

	// Botón1 (PC0) cambio de modo
	SBIC	R16, PC0
	RJMP	CAMBIAR_MODO

	// Botón2 (PC1) incrementar
	SBIC	R16, PC1
	RJMP	INCREMENTAR_VALOR

	// Botón3 (PC2) decrementar
	SBIC	R16, PC2
	RJMP	DECREMENTAR_VALOR

	// Botón4 (PC3) Confirmar
	SBIC	R16, PC3
	RJMP	CONFIRMAR

	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI

CAMBIAR_MODO:
	INC		MODE
	CPI		MODE, 4		// Si el modo llega a 4, reiniciar a 0 	
	BRNE	FIN_CAMBIAR
	CLR		MODE

FIN_CAMBIAR
	RET

INCREMENTAR_VALOR:


INC_HORA:
    INC     HORA
    CPI     HORA, 24  // Si llega a 24, reiniciar 0
    BRNE    FIN_INC
    CLR		HORA

CONFIGURAR_PUERTOS:
    // Configurar PORTB como salida para selección de displays
    LDI     R16, 0xFF		// 0b00001111 (PB0-PB3 como salidas)
    OUT     DDRB, R16
    
	// Configurar PORD como salida para segmentos de displays
	LDI		R16, 0xFE		// 0b11111110 (PD1-PD7 como salidas, PD0 reservado para buzzer)
	OUT     DDRD, R16

	RET

TIMER0_ISR:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16

	// Incrementar índice del display actual

    INC     DISPLAY_INDEX  // Incrementar contador de interrupciones
    CPI     DISPLAY_INDEX, 4  // Si llega a 4, reiniciar a 0
    BRNE    CONTINUAR
    CLR     DISPLAY_INDEX  // Reiniciar contador

CONTINUAR:
	// Apagar todos los displays
	LDI		R16, 0x00
	OUT		PORTB, R16

	// Selección de displays correspondientes
	LDI		ZL, LOW(DIGITO_DISPLAY << 1)
	LDI		ZH, HIGH(DIGITO_DISPLAY << 1)
	ADD		ZL, DISPLAY_INDEX
	LPM		R16, Z
	OUT		PORTB, R16

	// Obtener número correspondiente 
	LDI		ZL, LOW(TABLA_DISPLAY << 1)
	LDI		ZH, HIGH(TABLA_DISPLAY << 1)
	LD		R16, Z
	OUT		PORTD, R16	// Enviar al display

	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
/*
    INC     UNIDADES  // Incrementar unidades
    CPI     UNIDADES, 10
    BRNE    FIN_ISR  // Si no es 10, salir
    CALL    ACTUALIZAR_DECENAS
    CPI     CONTADOR_D, 6
    BRNE    FIN_ISR
    CLR     CONTADOR_D  // Reiniciar decenas
	*/

FIN_ISR:
    CALL    ACTUALIZAR_DISPLAY
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI

// Tabla de segmentos (ánodo común)
TABLA_DISPLAY:
    .DB 0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90