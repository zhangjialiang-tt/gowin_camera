/*
 ******************************************************************************************
 * @file      GOWIN_M1_it.h
 * @author    GowinSemicoductor
 * @device    Gowin_EMPU_M1
 * @brief     Main Interrupt Service Routines.
 *            This file provides template for all exceptions handler and
 *            peripherals interrupt service routine.
 ******************************************************************************************
 */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef GOWIN_M1_IT_H
#define GOWIN_M1_IT_H

#ifdef __cplusplus
	extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/

typedef struct ST_API
{
    void    (* interrupt    )(void);
    void    (*usb_rx_interrupt)(void);
}ST_API_T;

extern ST_API_T st_api;
void IrqGpio15Init(void);

#ifdef __cplusplus
}
#endif

#endif /* GOWIN_M1_IT_H */
