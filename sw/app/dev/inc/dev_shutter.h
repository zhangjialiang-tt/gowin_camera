
#ifndef __DEV_SHUTTER_H__
#define __DEV_SHUTTER_H__

#define DEV_SHUTTER_TIME    			60/*快门驱动时间 ms*/
#define SHUTTER_A   					0
#define SHUTTER_B   					1
typedef struct ST_DEV_SHUTTER
{
    void    (* shutter 		)(char);
}ST_DEV_SHUTTER_T;

extern ST_DEV_SHUTTER_T st_dev_shutter;


#endif /* LIB_DEV_SHUTTER_H_ */
