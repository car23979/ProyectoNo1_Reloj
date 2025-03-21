/*
 Proyecto1.asm

 Created: 05/03/2025 01:37:21 p. m.
 Author : David Carranza

 Descripción: 
 */
//Encabezado
.equ	VALOR_T1 = 0x0000
//.equ	VALOR_T1 = 0xFF50
.equ	VALOR_T0 = 0x00
//.equ	VALOR_T1 = 0x1B1E
//.equ	VALOR_T0 = 0xB2
.def	ACCION = R21
.cseg									// Codigo en la flash

.org	0x0000							// Donde inicia el programa
	JMP	START							// Tiene que saltar para no ejecutar otros

.org	PCI0addr						// Dirección donde esta el vector interrupción PORTB
	JMP	ISR_PCINT0

.org	OVF1addr						// Dirección del vector para timer1
	JMP	TIMER1_OVERFLOW

.org	OVF0addr						// Dirección del vector para timer0
	JMP	TIMER0_OVF


//.def CONTADOR = R19  // Variable para el contador

// Inicio del programa
TABLITA: .DB 0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90
DIAS_POR_MES: .DB 32, 29, 32, 31, 32, 31, 32, 32, 31, 32, 31, 32
MESES:		.DB	0x31, 0x28, 0x31, 0x30, 0x31, 0x30, 0x31, 0x31, 0x30, 0x31, 0x30, 0x31

START: 
	// Configurar el SP en 0x03FF (al final de la SRAM) 
	LDI		R16, LOW(RAMEND)			// Carga los bits bajos (0x0FF)
	OUT		SPL, R16					// Configura spl = 0xFF -> r16
	LDI		R16, HIGH(RAMEND)			// Carga los bits altos (0x03)
	OUT		SPH, R16					// Configura sph = 0x03) -> r16

SETUP:

	// Deshabilitar interrupciones globales
	CLI	
// ------------------------------------Configuración del TIMER0----------------------------------
	// Utilizando oscilador a 1MHz - Permitir? parpadeo cada 500 ms
	// Se configura prescaler principal
	LDI		R16, (1 << CLKPCE)			// Se selecciona el bit del CLK (bit 7) 
	STS		CLKPR, R16					// Se habilitar cambio para el prescaler
	LDI		R16, 0b00000100				// En la tabla se ubica qu? bits deben encender
	STS		CLKPR, R16					// Se configura prescaler a 16 para 1MHz
	
	CALL	INIT_TMR0

	LDI		R16, (1 << TOIE0)			// Habilita interrupci?n por desborde del TIMER0
	STS		TIMSK0, R16										
	
// ------------------------------------Configuración del TIMER1----------------------------------

	CALL	INIT_TMR1

// Habilitar interrupci?n por desborde del TIMER1
	LDI		R16, (1 << TOIE1)			// Habilita interrupci?n por desborde del TIMER1
	STS		TIMSK1, R16					

// ------------------------------------Configuraci?n de los puertos----------------------------------
	//	PORTD, PORTC y PB5 como salida 
	LDI		R16, 0xFF
	OUT		DDRD, R16					// Setear puerto D como salida (1 -> no recibe)
	OUT		DDRC, R16					// Setear puerto C como salida 
	LDI		R16, 0x00					// Se apagan las salidas
	OUT		PORTD, R16
	OUT		PORTC, R16
	
	// Configurar PB como entradas con pull ups habilitados
	LDI		R16, (0 << PB1) | (0 << PB2) | (0 << PB4)	// Se configura PB1, PB2 y PB4 como entradas y PB5/PB3/PB1 como salida (0010 1010)
	OUT		DDRB, R16
	LDI		R16, (1 << PB0) | (1 << PB3) | (1 << PB5)	// Se configura PB1, PB2 y PB4 como entradas y PB5/PB3/PB1 como salida (0010 1010)
	OUT		DDRB, R16
	LDI		R16, (1 << PB1) | (1 << PB2) | (1 << PB4)
	OUT		PORTB, R16					// Habilitar pull-ups 
	CBI		PORTB, PB0					// Se le carga valor de 0 a PB0 (Salida apagada) 
	CBI		PORTB, PB3					// Se le carga valor de 0 a PB3 (Salida apagada)
	CBI		PORTB, PB5					// Se le carga valor de 0 a PB5 (Salida apagada)

// ------------------------------------Configuraci?n de interrupci?n para botones----------------------------------
	LDI		R16, (1 << PCINT1) | (1 << PCINT2) | (1 << PCINT4)	// Se seleccionan los bits de la m?scara (5)
	STS		PCMSK0, R16								// Bits habilitados (PB0, PB1, PB2, PB3 y PB4) por m?scara		

	LDI		R16, (1 << PCIE0)						// Habilita las interrupciones Pin-Change en PORTB
	STS		PCICR, R16								// "Avisa" al registros PCICR que se habilitan en PORTB
													// Da "permiso" "habilita"

//---------------------------------------------INICIALIZAR DISPLAY-------------------------------------------------
	CALL	INIT_DIS7
	
//---------------------------------------------------REGISTROS-----------------------------------------------------
	CLR		R4										// Registro para valores de Z
	CLR		R5										// Registro para unidades minutos alarma /
	CLR		R3										// Registro para decenas minutos alarma /
	CLR		R12										// Registro para unidades horas alarma /
	CLR		R13										// Registro para decenas horas alarma /
		  //R16 - MULTIUSOS GENERAL 
	LDI		R17, 0x00								// Registro para contador de MODOS /
	LDI		R18, 0xFF								// Registro para guardar estado de botones
	LDI		R19, 0x00								// Registro para contador de unidades /(minutos) display
	LDI		R20, 0x00								// Accion para timer /
	LDI		R21, 0x00								// Registro para boton de accion /
	LDI		R22, 0x00								// Registro para contador de decenas /(minutos)
	LDI		R23, 0x00								// Registro para contador de unidades /(horas)
	LDI		R24, 0x00								// Registro para contador de desbordamientos
	LDI		R25, 0x00								// Registro para contador de decenas / (horas)
	LDI		R26, 0x01								// Registro para contador de unidades /(d?as)
	LDI		R27, 0x00								// Registro para contador de decenas /(d?as)
	LDI		R28, 0x01								// Registro para contador de unidades /(meses)
	LDI		R29, 0x00								// Registro para contador de decenas /(meses)
	SEI												// Se habilitan interrupciones globales


MAIN:
    RJMP    MAIN

// MODIFICACIONES NUEVAS

CONFIGURAR_BOTONES:
    // Configurar PORTC como entrada
    LDI     R16, (1 << PC4) | (1 << PC5)
    OUT     DDRC, R16

	// Habilitar pull-ups internos en PC0-PC3
    LDI     R16, (1 << PC0) | (1 << PC1) | (1 << PC2) | (1 << PC3)
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
	SBIC	R16, 3			// Si el boton 4 esta presionado
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
	LDS		R16, TEMP_HORA_ADDR
	MOV		HORA, R16
	LDS		R16, TEMP_MINUTO_ADDR
	MOV		MINUTO, R16
	RJMP	FIN_CONFIRMAR



VERIFICAR_FECHA:
	CPI		MODE, 2
	BRNE	VERIFICAR_ALARMA

	// Si estamos en modo de configuración de fecha (mode=2)
	LDS		R16, TEMP_DIA_ADDR
	MOV		DIA, R16
	LDS		R16, TEMP_MES_ADDR
	MOV		MES, R16
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
	STS		TEMP_HORA_ALARMA_ADDR, R16
	RET




TIMER0_ISR:
    PUSH    R16
	PUSH	R17
	PUSH	R18
    IN      R16, SREG
    PUSH    R16
	
	// Apagar todos los displays
	LDI		R16, 0x00
	OUT		PORTB, R16
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

FIN_ISR:
    CALL    ACTUALIZAR_DISPLAY
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI

ACTUALIZAR_DISPLAY:
    // Código para actualizar el display
    RET

