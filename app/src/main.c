#include <zephyr/devicetree.h>
#include <zephyr/drivers/led.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(main);

static const struct device *leds = DEVICE_DT_GET(DT_NODELABEL(npm1300_leds));

int main(void) {
  LOG_INF("Stating up the app....");

  while (1) {
    led_on(leds, 2U);
    k_sleep(K_MSEC(500));
    LOG_INF("led is off");
    led_off(leds, 2U);
    k_sleep(K_MSEC(500));
    LOG_INF("led is on");
  }

  return 0;
}