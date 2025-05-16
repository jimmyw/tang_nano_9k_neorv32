/*
 * Copyright (c) 2016 Intel Corporation
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/kernel.h>

/* 1000 msec = 1 sec */
#define SLEEP_TIME_MS 10

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

  int ret;
  bool led_state = true;

  if (!gpio_is_ready_dt(&led)) {
    return 0;
  }

  ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);
  if (ret < 0) {
    return 0;
  }

  while (1) {
    ret = gpio_pin_toggle_dt(&led);
    if (ret < 0) {
      return 0;
    }

    led_state = !led_state;
    // printf("LED state: %s\n", led_state ? "ON" : "OFF");
    // printf("PPS timestamp: %llu ", pps_get_tcxo_timestamp());
    // printf("PPS count: %u\n", pps_get_pps());
    process_pps();
    k_msleep(SLEEP_TIME_MS);
  }
  return 0;
}
