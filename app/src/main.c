#include <errno.h>
#include <string.h>
#include <zephyr/console/console.h>
#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/led.h>
#include <zephyr/drivers/uart.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(main);

static const struct device *leds = DEVICE_DT_GET(DT_NODELABEL(npm1300_leds));
static const struct device *uart_dev = DEVICE_DT_GET(DT_NODELABEL(uart0));

static volatile bool led_sequence_active = true;

#define STACK_SIZE 1024
#define THREAD_PRIORITY 5
K_THREAD_STACK_DEFINE(led_stack, STACK_SIZE);
struct k_thread led_thread_data;
K_THREAD_STACK_DEFINE(uart_stack, STACK_SIZE);
struct k_thread uart_thread_data;

// LED sequence thread
void led_sequence_thread(void *arg1, void *arg2, void *arg3) {
  ARG_UNUSED(arg1);
  ARG_UNUSED(arg2);
  ARG_UNUSED(arg3);

  while (1) {
    if (led_sequence_active) {
      led_on(leds, 2U);
      LOG_INF("LED ON");
      k_sleep(K_SECONDS(2));

      led_off(leds, 2U);
      LOG_INF("LED OFF");
      k_sleep(K_SECONDS(2));
    } else {
      k_sleep(K_MSEC(100));
    }
  }
}

// UART command thread
void uart_thread(void *arg1, void *arg2, void *arg3) {
  ARG_UNUSED(arg1);
  ARG_UNUSED(arg2);
  ARG_UNUSED(arg3);

  bool console_initialized = false;

  while (1) {
    if (!device_is_ready(uart_dev)) {
      LOG_ERR("UART device not ready");
      k_sleep(K_MSEC(1000));
      return;
    }

    if (!console_initialized) {
      console_getline_init();
      console_initialized = true;
    }

    char *line = console_getline();
    if (strcmp(line, "TURN_ON") == 0) {
      led_sequence_active = true;
      LOG_INF("LED sequence activated");
    } else if (strcmp(line, "TURN_OFF") == 0) {
      led_sequence_active = false;
      led_off(leds, 2U); // ensure LED is off
      LOG_INF("LED sequence deactivated");
    } else {
      LOG_INF("Unknown command");
    }

    k_sleep(K_MSEC(10));
  }
}

int main(void) {
  LOG_INF("Starting up the app...");

  if (!device_is_ready(leds)) {
    LOG_ERR("LED device not ready. The board is FAULTY or bad firmware was "
            "loaded.");
    return -ENODEV; // <-- return an int (fixes your warning)
  }

  k_thread_create(&led_thread_data, led_stack, K_THREAD_STACK_SIZEOF(led_stack),
                  led_sequence_thread, NULL, NULL, NULL, THREAD_PRIORITY, 0,
                  K_NO_WAIT);

  k_thread_create(&uart_thread_data, uart_stack,
                  K_THREAD_STACK_SIZEOF(uart_stack), uart_thread, NULL, NULL,
                  NULL, THREAD_PRIORITY, 0, K_NO_WAIT);

  return 0;
}