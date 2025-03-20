/*
 Proyecto1.asm

 Created: 05/03/2025 01:37:21 p. m.
 Author : David Carranza

 Descripción: 
 */
.include "M328PDEF.inc"

// Constantes
.equ	TEMP_HORA_ALARMA_ADDR	= 0x0104	// Dirección en SRAM para la hora de la alarma
.equ	TEMP_MIN_ALARMA_ADDR	= 0x0105	// Dirección en SRAM para los minutos de la alarma
.equ	TEMP_HORA_ADDR			= 0x0106
.equ	TEMP_MINUTO_ADDR		= 0x0107
.equ	TEMP_DIA_ADDR			= 0x0108
.equ	TEMP_MES_ADDR			= 0x0109 

// Definición de registros
.def	MODE = R20			// Modo de operación
.def	COUNTER = R21		// Contador auxiliar para parpadeo
.def	DISPLAY_INDEX = R22	// Indice para multiplexación
.def	HORA	= R16		// Contador de horas
.def    MINUTO	= R17		// Contador de minutos
.def    SEGUNDO	= R18		// Contador de segundos
.def    BLINK_COUNTER = R19	// Contador para parpadeo de los dos puntos
.def	TEMP	= R23		// Registro temporal para cálculos intermedios
// Definición para configuración de fecha
.def	DIA	= R24			// Día actual
.def	MES = R25			// Mes actual
// Definición Alarma
.def	HORA_ALARMA	= R26	// Configura hora para alarma
.def	MIN_ALARMA	= R27	// Configura minutos para alarma
.def	BUZZER_FLAG	= R28	// Indica si el buzzer está activo

.cseg

.ORG    0x0000
    RJMP    INICIO  // Vector Reset

.ORG    0x0020
    RJMP    TIMER1_ISR  // Vector de interrupción PCINT1

.ORG    0x0030
    RJMP    TIMER0_ISR

.ORG	PCI1addr
	RJMP	BOTON_ISR


//.def CONTADOR = R19  // Variable para el contador

// Inicio del programa
INICIO:
	CALL	CONFIGURAR_PILA
	CALL	CONFIGURAR_RELOJ
	CALL	CONFIGURAR_PUERTOS
	CALL	CONFIGURAR_TIMERS

	SEI		// Habilita interrupciones globales
	RJMP	MAIN

// Configuración del Stack
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16



    // Configurar Prescaler
    LDI     R16, (1 << CLKPCE)
    STS     CLKPR, R16  // Habilitar cambio de PRESCALER
    LDI     R16, 0b00000100
    STS     CLKPR, R16  // Prescaler a 16 (F_cpu = 1MHz)
/*
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

	// Si el buzzer está activo, el boton 4 lo apaga
	TST		BUZZER_FLAG			// Verificar si la alarma está encendida
	BREQ	CONTINUAR_BOTONES	// Si buzzer_flag=0, continuar con botones
	SBIC	R16, PC3			// Si el boton 4 esta presionado
	RJMP	APAGAR_BUZZER		// Ir a la subrutina de apagado

CONTINUAR_BOTONES:
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

APAGAR_BUZZER:
	CBI		PORTD, 7		// Apagar buzzer en PD7
	CLR		BUZZER_FLAG		// Indicar que el buzzer ya no esta sonando
	RJMP	FIN_BOTON_ISR

FIN_BOTON_ISR:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI

CONFIRMAR:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16

	// Verificar modo de reloj
	CPI		MODE, 1
	BRNE	VERIFICAR_FECHA

	// Si estamos en modo configuración de hora (mode=1)
	MOV		HORA, TEMP_HORA
	MOV		MINUTO, TEMP_MINUTO
	RJMP	FIN_CONFIRMAR



VERIFICAR_FECHA:
	CPI		MODE, 2
	BRNE	VERIFICAR_ALARMA

	// Si estamos en modo de configuración de fecha (mode=2)
	MOV		DIA, TEMP_DIA
	MOV		MES, TEMP_MES
	RJMP	FIN_CONFIRMAR

VERIFICAR_ALARMA:
	CPI		MODE, 3
	BRNE	FIN_CONFIRMAR

	// Si estamos en modo de configuración de alarma (mode=3)
	LDS		R16, TEMP_HORA_ALARMA_ADDR
	MOV		HORA_ALARMA, R16
	LDS		R16, TEMP_MIN_ALARMA_ADDR
	MOV		MIN_ALARMA, R16

FIN_CONFIRMAR:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RET

CAMBIAR_MODO:
	INC		MODE
	CPI		MODE, 4		// Si el modo llega a 4, reiniciar a 0 	
	BRNE	CONTINUAR_MODO
	CLR		MODE

CONTINUAR_MODO:
	// Apagar todos los Leds de modo antes de encender el correcto
	CBI		PORTC, 4	// Apagar LED de modo hora (A4)
	CBI		PORTC, 5	// Apagar LED de modo fecha (A5)

	// Encender los LEDs según el modo actual
	CPI		MODE, 1
	BRNE	MODO_FECHA
	SBI		PORTC, 4	// Encender LED de modo hora
	RJMP	FIN_CAMBIAR

MODO_FECHA:
	CPI		MODE, 2
	BRNE	MODO_ALARMA
	SBI		PORTC, 5	// Encender LED modo fecha
	RJMP	FIN_CAMBIAR

MODO_ALARMA:
	CPI		MODE, 3
	BRNE	FIN_CAMBIAR
	SBI		PORTC, 4	// Encender ambos LEDs para Modo Alarma
	SBI		PORTC, 5

FIN_CAMBIAR:
	RET

INCREMENTAR_VALOR:
	CPI		MODE, 1		// Si estamos en modo Hora
	BREQ	INC_HORA	
	CPI		MODE, 2		// Si estamos en modo Fecha
	BREQ	INC_DIA
	CPI		MODE, 3		// Si estamos en modo Alarma
	BREQ	INC_HORA_ALARMA
	RET

INC_HORA:
    INC     HORA
    CPI     HORA, 24  // Si llega a 24, reiniciar 0
    BRNE    FIN_INC
    CLR		HORA

FIN_INC:
	RET

INC_DIA:	
	// Cuando llegue a 1, se va a reiniciar día maximo y va a ir al mes anterior mes
	PUSH	R16
	PUSH	R26
	PUSH	R30
	PUSH	R31

	// Cambiar indice (1-12) a (0-11)
	MOV		R26, MES
	DEC		R26		// R26 va ser el indice de (0-11)
	
	// Cargar DIAS_MAX en Z
	LDI		R30, LOW(DIAS_MAX)
	LDI		R31, HIGH(DIAS_MAX)
	
	// Sumar al indice para acceder al valor correcto
	ADD		R30, R26	// R30 apunta a DIAS_MAX
	
	// Cargar el valor maximo de días
	LD		R16, Z

	// Comparar día maximo con lo maximo permitido
	CP		DIA, R16
	BRLT	CONTINUAR_INC

	// Si DIA es igual al maximo se reinicia 1 y avanza Mes
	LDI		DIA, 1
	INC		MES
	CPI		MES, 13
	BRNE	FIN_INC_DIA
	LDI		MES, 1		// Si Mes es 13, reiniciar en 1 (Enero)
	
	RJMP	FIN_INC_DIA

CONTINUAR_INC:
	INC		DIA		// Incremento de día

FIN_INC_DIA:
	POP		R31
	POP		R30
	POP		R26
	POP		R16
	RET

INC_HORA_ALARMA:
	LDS		R16, TEMP_HORA_ALARMA_ADDR
	INC		R16
	CPI		R16, 24		// Si llega a 24, reiniciar 0
	BRNE	FIN_INC_ALARMA
	CLR		R16

FIN_INC_ALARMA:
	STS		TEMP_HORA_ALARMA_ADDR, R16
	RET


DECREMENTAR_VALOR:
	CPI		MODE, 1		// Si estamos en modo Hora
	BREQ	DEC_HORA	
	CPI		MODE, 2		// Si estamos en modo Fecha
	BREQ	DEC_DIA
	CPI		MODE, 3		// Si estamos en modo Alarma
	BREQ	DEC_HORA_ALARMA
	RET

DEC_HORA:
	DEC		HORA
	CPI		HORA, 23	// Si llega a 0, reiniciar 23
	BRNE	FIN_DEC
	CLR		HORA

FIN_DEC:
	RET

DEC_DIA:	
	PUSH	R16
	PUSH	R26
	PUSH	R30
	PUSH	R31
	
	// Verificar si el día es mayor a 1
	CPI		DIA, 1
	BRNE	CONTINUAR_DEC

	// Si el día es 1 retroceder al mes anterior
	DEC		MES
	CPI		MES, 0
	BRNE	CONTINUAR_DEC2
	LDI		MES, 12		// Si el mes era 1, va cambiar a diciembre (12)

CONTINUAR_DEC2:
	// Cambiar indice (1-12) a (0-11)
	MOV		R26, MES
	DEC		R26		// R26 va ser el indice de (0-11)
	 
	// Cargar DIAS_MAX en Z
	LDI		R30, LOW(DIAS_MAX)
	LDI		R31, HIGH(DIAS_MAX)
	
	// Sumar al indice para acceder al valor correcto
	ADD		R30, R26	// R30 apunta a DIAS_MAX
	
	// Cargar el valor maximo de días
	LD		R16, Z
	MOV		DIA, R16	// Establecer día en el maximo del mes anterior
	RJMP	FIN_DEC_DIA

CONTINUAR_DEC:
	DEC		DIA		// Decremento de días

FIN_DEC_DIA:
	POP		R31
	POP		R30
	POP		R26
	POP		R16
	RET

DEC_HORA_ALARMA:
	LDS		R16, TEMP_HORA_ALARMA_ADDR
	CPI		R16, 0
	BRNE	NORMAL_DEC_ALARMA
	LDI		R16, 23		// Si está en 0, reiniciar a 23
	RJMP	FIN_DEC_ALARMA

NORMAL_DEC_ALARMA:
	DEC		R16

FIN_DEC_ALARMA:
	STS		TEMP_HORA_ALARMA_ADDR
	RET


CONFIGURAR_PUERTOS:
    // Configurar PORTB como salida para selección de displays
    LDI     R16, 0xFF		// 0b00001111 (PB0-PB3 como salidas)
    OUT     DDRB, R16
    
	// Configurar PORD como salida para segmentos de displays
	LDI		R16, 0xFF		// 0b1111111 (PD0-PD6 como salidas, PD7 reservado para buzzer)
	OUT     DDRD, R16

	RET

TIMER0_ISR:
    PUSH    R16
	PUSH	R17
	PUSH	R18
    IN      R16, SREG
    PUSH    R16

	// Incrementar índice del display actual

    INC     DISPLAY_INDEX  // Incrementar contador de interrupciones
    CPI     DISPLAY_INDEX, 4  // Si llega a 4, reiniciar a 0
    BRNE    CONTINUAR
    CLR     DISPLAY_INDEX  // Reiniciar contador

TIMER1_ISR:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16

	INC		BLINK_COUNTER
	CPI		BLINK_COUNTER, 50		// 50 * 10 ms = 500 ms
	BRNE	CONTINUAR_ISR
	CLR		BLINK_COUNTER			// Reiniciar contador
	IN		R16, PORTB
	EOR		R16, (1 << PB4)			// Alternar LED de los dos puntos
	OUT		PORTB, R16

CONTINUAR_ISR:
	// Incrementar el contador de segudos
	INC		SEGUNDO
	CPI		SEGUNDO, 60
	BRNE	FIN_ISR

	CLR		SEGUNDO
	INC		MINUTO
	CPI		MINUTO,	60
	BRNE	FIN_ISR

	CLR		MINUTO
	INC		HORA
	CPI		HORA, 24
	BRNE	FIN_ISR
	CLR		HORA

	// Comparar hora actual con la alarma
	CP		HORA, HORA_ALARMA
	BRNE	FIN_ISR
	CP		MINUTO, MIN_ALARMA
	BRNE	FIN_ISR

	// Si hora = hora_alarma y minuto = min_alarma activar buzzer
	SBI		PORTD, 7		// Activar buzzer en PD7
	LDI		BUZZER_FLAG, 1	// Indicar que el buzzer esta sonando


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

	// Determinar que número mostrar en el display actual
	CPI		DISPLAY_INDEX, 0
	BRNE	CHECAR_2
	MOV		R18, HORA		// Primer digito
	RJMP	CARGAR_NUMERO

CHECAR_2:
	CPI		DISPLAY_INDEX, 1
	BRNE	CHECAR_3
	MOV		R18, HORA		// Segundo digito
	RJMP	CARGAR_NUMERO

CHECAR_3:
	CPI		DISPLAY_INDEX, 2
	BRNE	CHECAR_4
	MOV		R18, MINUTO		// Tercer digito
	RJMP	CARGAR_NUMERO

CHECAR_4:
	MOV		R18, MINUTO		// Cuarto digito

CARGAR_NUMERO:
	ANDI	R18, 0x0F		// Asegurar que se un digito de 0-9
	ADD		ZL, R18			// Apuntar al número de la tabla
	LPM		R16, Z			// Cargar patrón de 7 segmentos en R16

	// PD7 no se ve afectado
	LDI		R17, 0x7F
	AND		R16, R17	// Apagar sin afectar los segmentos
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

// Tabla de Meses
DIAS_MAX:
	.DB 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31	// Enero - Diciembre

