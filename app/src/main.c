/*
 * Copyright (c) 2016 Intel Corporation
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/drivers/dac.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#define SLEEP_TIME_MS 10000
/* 1000 msec = 1 sec */

/* The devicetree node identifier for the "led0" alias. */
#define LED0_NODE DT_ALIAS(led0)

/*
 * A build error on this line means your board is unsupported.
 * See the sample documentation for information on how to fix this.
 */
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

#define PPS_TIMESTAMP_LO ((volatile uint32_t *)0x13000)
#define PPS_TIMESTAMP_HI ((volatile uint32_t *)0x13004)
#define PPS_FLAGS ((volatile uint32_t *)0x13008)
#define PPS_PPS_COUNT ((volatile uint32_t *)0x1300c)
#define PPS_TARGET_HZ 10000000LL // 10 MHz
#define PPS_TARGET_MAX_DELTA_HZ 1000LL
#define PLL_MULTIPLIER 10

unsigned int pps_count = 60;

static uint64_t pps_get64(volatile uint32_t *addr) {
  uint32_t th1, th2, tl;
  uint64_t ts;

  /* addr is low word; addr+1 is high */

  do {
    th1 = *(addr + 1);
    tl = *addr;
    th2 = *(addr + 1);
  } while (th1 != th2);

  ts = ((uint64_t)th1 << 32) | tl;

  return ts;
}

uint64_t pps_get_tcxo_timestamp(void) { return pps_get64(PPS_TIMESTAMP_LO); }

uint32_t pps_get_pps_flags(void) { return *PPS_FLAGS; }
uint32_t pps_get_pps_timestamp(void) { return *PPS_PPS_COUNT; }

#define PPS_FLAG_TIMSTAMP_VALID 0x1

void test_mcp4725_dac(void) {
  // Try DAC driver first (now that I2C is properly configured)
  const struct device *dac_dev = DEVICE_DT_GET(DT_NODELABEL(mcp4725_dac));

  // Generate a stepping DAC output pattern
  static uint16_t dac_value = 0;
  static uint8_t step_count = 0;

  // Create different voltage levels for easy scope observation
  // 0V, 0.825V, 1.65V, 2.475V, 3.3V (assuming 3.3V Vdd)
  uint16_t voltage_steps[] = {0, 1024, 2048, 3072, 4095}; // 12-bit values

  // Use predefined steps for first 5 cycles, then ramp
  if (step_count < 5) {
    dac_value = voltage_steps[step_count];
    step_count++;
  } else {
    // Continuous ramp from 0 to 4095
    dac_value += 256;  // Increment by 256 for visible steps
    if (dac_value > 4095) {
      dac_value = 0;
      step_count = 0;  // Reset to step pattern
    }
  }

  if (device_is_ready(dac_dev)) {
    // Use Zephyr DAC API
    struct dac_channel_cfg dac_cfg = {
      .channel_id = 0,
      .resolution = 12,
    };

    int ret = dac_channel_setup(dac_dev, &dac_cfg);
    if (ret < 0) {
      printf("DAC channel setup failed: %d\n", ret);
      return;
    }

    ret = dac_write_value(dac_dev, 0, dac_value);
    if (ret == 0) {
      uint32_t voltage_mv = (dac_value * 3300) / 4095;
      printf("DAC: value=%d, voltage=%d.%03dV\n",
             dac_value, voltage_mv / 1000, voltage_mv % 1000);
    } else {
      printf("DAC write failed: %d (value=%d)\n", ret, dac_value);
    }
  } else {
    // Fall back to direct I2C communication
    const struct device *i2c_dev = DEVICE_DT_GET(DT_NODELABEL(i2c0));

    if (!device_is_ready(i2c_dev)) {
      printf("I2C device not ready\n");
      return;
    }

    // MCP4725 Fast Mode command format
    uint8_t tx_data[2];
    tx_data[0] = (dac_value >> 8) & 0x0F;  // Upper 4 bits
    tx_data[1] = dac_value & 0xFF;         // Lower 8 bits

    struct i2c_msg msgs[] = {
      {
        .buf = tx_data,
        .len = 2,
        .flags = I2C_MSG_WRITE | I2C_MSG_STOP,
      }
    };

    int ret = i2c_transfer(i2c_dev, msgs, 1, 0x60);
    if (ret == 0) {
      uint32_t voltage_mv = (dac_value * 3300) / 4095;
      printf("DAC (direct I2C): value=%d, voltage=%d.%03dV\n",
             dac_value, voltage_mv / 1000, voltage_mv % 1000);
    } else {
      printf("DAC I2C write failed: %d (value=%d)\n", ret, dac_value);
    }
  }
}

void process_pps() {
  // Read conunters from fpga
  uint64_t pps_timestamp = pps_get_pps_timestamp();
  uint32_t pps_flags = pps_get_pps_flags();
  uint64_t tcxo_timestamp = pps_get_tcxo_timestamp();

  // These are the counts from the last ppm pulse
  static uint64_t last_tcxo_timestamp = 0;
  static uint64_t last_ppm_timestamp = 0;

  if (last_ppm_timestamp == pps_timestamp) {
    return;
  }
  printf("PPS timestamp: %llu flags: %" PRIu32 " tcxp: %" PRIu64 "\n",
         pps_timestamp, pps_flags, tcxo_timestamp);

  // These are the counts from where we started to meassure
  static uint64_t last_tcxo_reset_timestamp = 0;
  static uint64_t last_ppm_reset_timestamp = 0;

  uint64_t tcxo_ticks = tcxo_timestamp - last_tcxo_timestamp;
  uint64_t pps_ticks = pps_timestamp - last_ppm_timestamp;

  // Ticks since we started to meassure
  uint64_t delta_tcxo_ticks = tcxo_timestamp - last_tcxo_reset_timestamp;
  uint64_t delta_pps_ticks = pps_timestamp - last_ppm_reset_timestamp;

  /* Some checks are needed to avoid convergence problems.  One can
   * get junk readings from the GPS when it is aquiring a fix.  Also,
   * it can miss pulses if reception is not good.
   * Also, trying to go faster than clk_pps results in overflow in
   * The adjust function.  It's a good idea to process only observed periods
   * that are plausible.
   */

  unsigned char valid_signal = 1;
  /* reject periods that are not plausible */
  if ((tcxo_ticks <
       ((PPS_TARGET_HZ - PPS_TARGET_MAX_DELTA_HZ) * PLL_MULTIPLIER)) ||
      (tcxo_ticks >=
       ((PPS_TARGET_HZ + PPS_TARGET_MAX_DELTA_HZ) * PLL_MULTIPLIER))) {
    valid_signal = 0;
  }

  if (true) {

    // Observed period of all our meassurements
    uint64_t observed_period =
        (delta_tcxo_ticks * 1000) / (delta_pps_ticks * PLL_MULTIPLIER);
    uint32_t whole_part = observed_period / 1000000000;
    uint32_t fractional_part = observed_period % 1000000000;

    printf("TICKS/PPS: %" PRIu64 ", TCXO: %" PRIu64 ", PPS: %" PRIu64,
           tcxo_ticks / pps_ticks, delta_tcxo_ticks, delta_pps_ticks);
    printf(", FREQ: %" PRIu32 ".%" PRIu32 " MHz, status: %s", whole_part,
           fractional_part, (valid_signal == 1) ? "valid" : "invalid");
    printf("\n");
  }
  last_tcxo_timestamp = tcxo_timestamp;
  last_ppm_timestamp = pps_timestamp;

  // After 10 pulses we will reset the counter.
  if (delta_pps_ticks >= pps_count || !valid_signal) {
    last_tcxo_reset_timestamp = tcxo_timestamp;
    last_ppm_reset_timestamp = pps_timestamp;
  }
}

int main(void) {
  printf("Hello World! %s\n", CONFIG_BOARD);
  //LOG_LEVEL_SET(LOG_LEVEL_DBG);

  int ret;
  bool led_state = true;

  if (!gpio_is_ready_dt(&led)) {
    return 0;
  }

  ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);
  if (ret < 0) {
    return 0;
  }

  // Check device initialization status
  const struct device *i2c_dev = DEVICE_DT_GET(DT_NODELABEL(i2c0));
  const struct device *dac_dev = DEVICE_DT_GET(DT_NODELABEL(mcp4725_dac));

  printf("I2C ready: %s, DAC ready: %s\n",
         device_is_ready(i2c_dev) ? "yes" : "no",
         device_is_ready(dac_dev) ? "yes" : "no");

  static int cycle_count = 0;

  while (1) {
    ret = gpio_pin_toggle_dt(&led);
    if (ret < 0) {
      return 0;
    }

    led_state = !led_state;

    // Update DAC output every cycle
    cycle_count++;
    printf("\n=== Cycle %d ===\n", cycle_count);
    test_mcp4725_dac();

    // Uncomment to enable PPS processing
    // process_pps();

    // Sleep for 2 seconds to see changes clearly
    k_msleep(2000);
  }
  return 0;
}
