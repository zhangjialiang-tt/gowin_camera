/*
 * system_video.h
 *
 *  Created on: 2022年6月17日
 *      Author: chain
 */

#ifndef LIB_SYSTEM_VIDEO_H_
#define LIB_SYSTEM_VIDEO_H_

#define     SENSOR_VIDEO_FREQENCY           50
#define     SENSOR_VIDEO_X_VALID            640
#define     SENSOR_VIDEO_Y_VALID            512
#define     SENSOR_VIDEO_FRAME_SIZE         (SENSOR_VIDEO_X_VALID * SENSOR_VIDEO_Y_VALID * 2)
#define     SENSOR_VIDEO_PAO_DIAN           (SENSOR_VIDEO_X_VALID * SENSOR_VIDEO_Y_VALID / 100)


// #define     GG_Y16
#define     GG_Y16_1
// #define     GG_DELTB

//TAG 开启测试模式
// #define VIDEO_TEST_MODE_ENABLE

#ifdef      VIDEO_TEST_MODE_ENABLE
    // #define VIDEO_TEST_MODE_AUTO_SWITCH_ENABLE
#endif

#endif /* LIB_SYSTEM_VIDEO_H_ */
